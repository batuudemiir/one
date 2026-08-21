#!/usr/bin/env python3
"""
font_guard.py — Font bütünlüğü denetimi.

Neden ayrı bir denetim: `ui_guard.sh`'ın kuralları eşikli borç sayaçları
("bugün 93 ihlal var, artmasın"). Font bütünlüğü öyle değil — ikili bir
değişmez. "Üç font eksik olabilir" diye bir eşik yok; eksikse uygulama
yanlış yüzle çizer.

Ve **sessizce** çizer. SwiftUI'de var olmayan bir fontu istemek çökme değil,
sistem yüzüne düşme demek. Bu repoda tam olarak iki kez oldu:

  1. `GeistMono-Regular` hiç bundle edilmemişti. 30 çağrı — yıllık özetin
     48pt'lik hero'su, ay hikayesi, paylaşılan poster — SF Pro çiziyordu.
     Mono rakam hizası için tasarlanmış tablolarda orantılı font vardı.
  2. DM Sans'ın 5 ttf'i diskten silindi ama Info.plist onları bildirmeye ve
     kod onlara bağlanmaya devam etti. Gövde metninin tamamı sessizce
     SF Pro'ya düştü.

İkisi de gözle bakmadan fark edilemezdi. Bu betik ikisini de yakalar.

Üç kontrol:
  A. Info.plist'te bildirilen her font dosyası diskte var mı        → HATA
  B. Koddaki her font adı, bildirilen dosyaların birinin PostScript
     adıyla karşılanıyor mu                                         → HATA
  C. Diskte olup Info.plist'te bildirilmeyen font dosyası var mı     → UYARI
     (çalışma zamanında yüklenmez; ya bildir ya sil)

`fontTools` kullanmıyor — build phase'de bir pip paketinin varlığına
güvenilemez. sfnt `name` tablosu stdlib ile ayrıştırılıyor.
"""

import plistlib
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "one"
INFO_PLIST = SRC / "Info.plist"

# Font adı literallerinin doğrudan geçtiği çağrılar.
DIRECT = re.compile(r'(?:UIFont\(name:\s*|\.custom\(\s*)"([^"]+)"')

# Yüzlerin tanımlandığı dosyalar. Font adları burada bir yardımcı fonksiyonun
# (`dmSansName`) ardında durabiliyor, yani doğrudan çağrı kalıbı onları
# görmüyor — bu dosyaların tüm dizeleri taranıyor.
FACE_FILES = ["V3Typography.swift", "ONETypography.swift", "ONEBrand.swift"]

# PostScript adı gibi görünen dize: harfle başlar, boşluk/nokta/# içermez,
# ve içinde tire ya da rakam vardır. Lokalizasyon anahtarları (nokta içerir)
# ve hex renkleri (# ile başlar) bu elekten geçmez.
FONTISH = re.compile(r'^[A-Za-z][A-Za-z0-9]*(?:[-_][A-Za-z0-9]+)+$')


def postscript_names(path: Path) -> set:
    """sfnt `name` tablosundan nameID 6 (PostScript adı) değerlerini çıkar."""
    data = path.read_bytes()
    if len(data) < 12:
        return set()

    tag = data[:4]
    if tag == b"ttcf":            # font koleksiyonu — ilk yüze bak
        offset = struct.unpack(">I", data[12:16])[0]
    else:
        offset = 0

    num_tables = struct.unpack(">H", data[offset + 4:offset + 6])[0]
    name_off = name_len = None
    for i in range(num_tables):
        rec = offset + 12 + i * 16
        t, _, off, ln = struct.unpack(">4sIII", data[rec:rec + 16])
        if t == b"name":
            name_off, name_len = off, ln
            break
    if name_off is None:
        return set()

    tbl = data[name_off:name_off + name_len]
    count, string_off = struct.unpack(">HH", tbl[2:6])
    found = set()
    for i in range(count):
        rec = 6 + i * 12
        plat, enc, _lang, name_id, ln, off = struct.unpack(">HHHHHH", tbl[rec:rec + 12])
        if name_id != 6:
            continue
        raw = tbl[string_off + off: string_off + off + ln]
        try:
            # platform 3 (Windows) UTF-16BE, platform 1 (Mac) Latin-1
            found.add(raw.decode("utf-16-be" if plat == 3 else "latin-1").strip())
        except (UnicodeDecodeError, ValueError):
            continue
    return {n for n in found if n}


def declared_fonts() -> list:
    if not INFO_PLIST.exists():
        sys.exit(f"error: font_guard — Info.plist bulunamadı: {INFO_PLIST}")
    with INFO_PLIST.open("rb") as fh:
        return plistlib.load(fh).get("UIAppFonts", [])


def find_font_file(name: str):
    matches = list(SRC.rglob(name))
    return matches[0] if matches else None


def code_font_names() -> dict:
    """{font adı: [kullanıldığı yerler]}"""
    used = {}

    def note(n, where):
        used.setdefault(n, []).append(where)

    for swift in SRC.rglob("*.swift"):
        text = swift.read_text(encoding="utf-8", errors="ignore")
        rel = swift.relative_to(ROOT)
        for i, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            for m in DIRECT.finditer(line):
                note(m.group(1), f"{rel}:{i}")
            if swift.name in FACE_FILES:
                for lit in re.findall(r'"([^"]{4,})"', line):
                    if FONTISH.match(lit):
                        note(lit, f"{rel}:{i}")
    return used


def main() -> int:
    failed = False
    declared = declared_fonts()

    # ── A. Bildirilen her dosya diskte var mı ──────────────────────────
    available, missing_files = {}, []
    for fname in declared:
        path = find_font_file(fname)
        if path is None:
            missing_files.append(fname)
            continue
        available[fname] = postscript_names(path)

    if missing_files:
        failed = True
        print("error: font_guard — Info.plist var olmayan font bildiriyor")
        for f in missing_files:
            print(f"note:  UIAppFonts › {f} — dosya yok")
        print("note:  Bu fontu isteyen her çağrı sessizce sistem yüzüne düşer.")

    # ── B. Koddaki her ad karşılanıyor mu ──────────────────────────────
    provided = set().union(*available.values()) if available else set()
    unresolved = {
        name: places for name, places in code_font_names().items()
        if name not in provided
    }
    if unresolved:
        failed = True
        print("error: font_guard — kod, bundle'da olmayan bir font adı istiyor")
        for name, places in sorted(unresolved.items()):
            print(f"note:  \"{name}\" — karşılayan dosya yok")
            for p in places[:3]:
                print(f"note:    {p}")
            if len(places) > 3:
                print(f"note:    … +{len(places) - 3} yer daha")
        print(f"note:  Bundle'ın sağladığı adlar: {', '.join(sorted(provided)) or '(yok)'}")

    # ── C. Bildirilmemiş font dosyaları ────────────────────────────────
    on_disk = {p.name for p in SRC.rglob("*.ttf")} | {p.name for p in SRC.rglob("*.otf")}
    undeclared = sorted(on_disk - set(declared))
    if undeclared:
        print("warning: font_guard — bundle'da olup Info.plist'te bildirilmeyen font:")
        for f in undeclared:
            print(f"warning:   {f} — çalışma zamanında yüklenmez; ya UIAppFonts'a ekle ya sil")

    if failed:
        print("error: font_guard başarısız. Font eksikliği sessizdir — çökme değil, yanlış yüz.")
        return 1

    print(f"font_guard: tamam ({len(declared)} font, {len(provided)} PostScript adı)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
