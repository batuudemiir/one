#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
voice_guard.py — Marka sesi bekçisi (v4, "az konuşan kurator")

font_guard gibi **eşiksiz** çalışır: bu bir borç sayacı değil, sağlanması
zorunlu bir değişmez. Bir ünlem ya da "10 saniye" sözü ürüne girdiği anda
ses değişiyor; "iki ünlem olabilir" diye bir eşik yok.

Denetlenen üç şey:

  1. Ünlem — kullanıcıya görünen hiçbir dizede yok. (v4: ünlem yalvarmadır.)
  2. Emoji — duygu sinyali renk noktasıdır, glif değil. Durum işaretleri
     (✓ ✔) muaf: onlar duygu değil, durum.
  3. Yasaklı ifadeler — süre pazarlığı, alışkanlık/koçluk dili, özlem ve
     FOMO dili, uygulamanın kendini özne yapması. (Kaynak: marka sesi v4.)
  4. Başlık büyük harfle başlar — CLAUDE.md › Kopya kuralları.

Casing kuralı **yalnız başlıklarda** işliyor: `screen.*`, `*.title`,
`*.screenTitle`, `*.headline`, `*.heading`, `*.sectionTitle`. Kuralın
metnindeki "başlık" kelimesi bağlayıcı — uygulamanın Çevre/Gizlilik/Poster
ekranlarında bilinçli bir küçük harf dili var (`nav.*` için CLAUDE.md bunu
açıkça yazıyor: "alt gezinme dilidir (küçük harf)"), ve etiket/parça
dizeleri ("en çok %@", VoiceOver durum kelimeleri) cümle ortasına giriyor.
Kuralı hepsine açmak, denetimi ilk gün 150 yanlış pozitifle kırmızıya
boyardı — o da kural olmamasından kötü.

Kapsam:
  · `one/*.lproj/Localizable.strings` — yalnız **kodda gerçekten çağrılan**
    anahtarlar. Ölü anahtarlar ekranda görünmüyor; onları saymak bekçiyi
    gürültüye boğar ve gerçek ihlali gizler.
  · `notif.*` anahtarları — bildirim metninin tamamı katalogda, dokuz dilde.
    Orada ayrıca **soru işareti** de yasak (her dilde): bildirimde soru bir
    taleptir.
  · `one/Core/Notifications/*.swift` — katalog dışında kalmış gömülü metin
    olmadığını doğrular; aynı kurallar orada da geçerli.

Kullanım: python3 tooling/voice_guard.py   (ui_guard.sh içinden de çağrılır)
"""

import os
import re
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import catalog  # noqa: E402  — canlı/ölü ayrımının tek kaynağı

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "one")

# Durum işaretleri — duygu taşımıyorlar, muaf.
GLYPH_ALLOW = {"✓", "✔", "✗", "✕"}

# Yasaklı ifadeler (Türkçe kaynak metin). Küçük harfe indirilmiş arama.
BANNED = [
    "10 saniye", "on saniye", "30 saniye", "saniye sürer", "saniyeni",
    "tek dokunuş", "alışkanlık", "kök sal", "üst üste", "gün seri",
    "seri devam", "ritmi bozma", "kaçırma", "son şans",
    "seni özledi", "özledik", "seni bekliyor", "sizi bekliyoruz",
    "bekliyoruz", "geri dön", "vibe", "mühürle",
    "ister misin", "ne dersin", "hazır mısın", "harika",
    "kendine zaman tanı", "zor bir hafta", "yoğunsun",
]

def is_emoji(ch: str) -> bool:
    if ch in GLYPH_ALLOW:
        return False
    return ord(ch) > 0x2000 and unicodedata.category(ch) == "So"

def live_keys() -> tuple[set[str], list[str]]:
    """Canlı anahtarlar + dinamik anahtar önekleri.

    Ayrım `catalog.py`'de: `dead_keys.py` ile **aynı** yöntemi kullanmak
    zorunda. İkisi ayrı tanım kullanırsa biri denetlemediğini sanır, öteki
    kullanılan bir anahtarı siler.
    """
    blob = catalog.source_blob(ROOT)
    prefixes = catalog.dynamic_prefixes(blob)
    keys = set(re.findall(r'"([A-Za-z][A-Za-z0-9_.]*)"', blob))
    return keys, prefixes


def check_strings(keys, prefixes):
    problems = []
    lproj = sorted(
        os.path.join(SRC, d, "Localizable.strings")
        for d in os.listdir(SRC) if d.endswith(".lproj")
    )
    title_key = re.compile(
        r"(^screen\.|\.title$|\.screenTitle$|\.headline$|\.heading$|\.sectionTitle$)"
    )

    for path in lproj:
        lang = os.path.basename(os.path.dirname(path)).replace(".lproj", "")
        for n, line in enumerate(open(path, encoding="utf8"), 1):
            m = re.match(r'^"([^"]+)"\s*=\s*"(.*)";\s*$', line)
            if not m:
                continue
            key, val = m.groups()
            if key not in keys and not any(key.startswith(p) for p in prefixes if p):
                continue  # ölü anahtar
            rel = os.path.relpath(path, ROOT)
            if "!" in val:
                problems.append((rel, n, key, "ünlem", val))
            bad = [c for c in val if is_emoji(c)]
            if bad:
                problems.append((rel, n, key, "emoji " + "".join(bad), val))
            # Bildirim metni v4'te katalogda (`notif.*`). Bildirimde soru bir
            # taleptir — bu kural dokuz dilin hepsinde geçerli.
            if key.startswith("notif.") and "?" in val:
                problems.append((rel, n, key, "soru işareti (bildirimde talep)", val))
            # Başlık küçük harfle başlamaz. Biçim belirteciyle ("%@ posteri")
            # ya da noktalama ile başlayanlar muaf: cümleyi veri açıyor.
            # Marka yazımı da muaf (iCloud, iOS) — ilk kelimede büyük harf
            # varsa küçük başlangıç kasıtlıdır.
            if title_key.search(key) and not val.startswith("%"):
                first = next((c for c in val if c.isalpha()), "")
                head = val.split()[0] if val.split() else val
                if first and first.islower() and not any(c.isupper() for c in head):
                    problems.append((rel, n, key, "başlık küçük harfle başlıyor", val))

            if lang == "tr":
                low = val.lower()
                for w in BANNED:
                    if w in low:
                        problems.append((rel, n, key, f"yasaklı ifade “{w}”", val))
    return problems

def check_notification_sources():
    """Bildirim metni Swift içinde gömülü üretiliyor — orada soru da yasak."""
    problems = []
    targets = [os.path.join(SRC, "Core", "Notifications")]
    for base in targets:
        for root, _, files in os.walk(base):
            for f in sorted(files):
                if not f.endswith(".swift"):
                    continue
                path = os.path.join(root, f)
                rel = os.path.relpath(path, ROOT)
                for n, line in enumerate(open(path, encoding="utf8"), 1):
                    code = line.split("//")[0] if not line.lstrip().startswith("//") else ""
                    for m in re.finditer(r'"([^"]*)"', code):
                        # Enterpolasyon içeriği metin değil kod: `\(a ?? 0)`
                        # içindeki `?` bir soru işareti değil.
                        val = re.sub(r"\\\([^)]*\)", "", m.group(1))
                        if not re.search(r"[A-Za-zÇĞİÖŞÜçğıöşü]{3}", val):
                            continue
                        low = val.lower()
                        if "!" in val:
                            problems.append((rel, n, "", "ünlem", val))
                        if "?" in val:
                            problems.append((rel, n, "", "soru işareti (bildirimde talep)", val))
                        if any(is_emoji(c) for c in val):
                            problems.append((rel, n, "", "emoji", val))
                        for w in BANNED:
                            if w in low:
                                problems.append((rel, n, "", f"yasaklı ifade “{w}”", val))
    return problems

def main() -> int:
    keys, prefixes = live_keys()
    problems = check_strings(keys, prefixes) + check_notification_sources()
    if not problems:
        print("voice_guard: tamam")
        return 0
    for rel, n, key, why, val in problems:
        where = f"{rel}:{n}"
        label = f" [{key}]" if key else ""
        print(f"error: voice_guard — {why}{label}")
        print(f"note:  {where}: {val}")
    print(f"error: Marka sesi v4 ihlali ({len(problems)}). CLAUDE.md › Kopya kuralları.")
    return 1

if __name__ == "__main__":
    sys.exit(main())
