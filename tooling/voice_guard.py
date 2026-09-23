#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
voice_guard.py — Marka sesi bekçisi (ONE 2.0)

font_guard gibi **eşiksiz** çalışır: bu bir borç sayacı değil, sağlanması
zorunlu bir değişmez.

ONE 2.0'da gevşeyenler (CLAUDE.md › Kopya): seri ve alışkanlık dili,
destekleyici ve rehberli dil, uygulamanın soru sorması, tek ünlem, süre
bilgisi. Kurallar docs/one2/GUARDS_TODO.md'ye göre güncellendi.

Denetlenenler:

  1. Üst üste ünlem — `!!`, `?!`, `!?`. Tek ünlem idareli serbest.
  2. Emoji — durum işaretleri (✓ ✔ ✗ ✕) muaf.
  3. Yasaklı ifadeler — yalvaran ya da suçlayan geri kazanım dili, FOMO,
     teşhis koyan dil.
  4. Başlık büyük harfle başlar — CLAUDE.md › Kopya.

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
  · `one/Core/Notifications/*.swift` ve `one/ONE2/Notifications/*.swift` —
    katalog dışında kalmış gömülü metin için aynı kurallar.

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
# ONE 2.0'da serbest kalanlar (GUARDS_TODO V3–V6): seri ve alışkanlık dili,
# "ister misin" gibi rehberli sorular, destekleyici dil, süre bilgisi.
BANNED = [
    "kaçırma", "son şans",
    "seni özledi", "özledik", "seni bekliyor", "sizi bekliyoruz",
    "bekliyoruz", "geri dön", "vibe", "mühürle",
    "yoğunsun",
]

# Üst üste ünlem ya da ünlem-soru karışımı.
STACKED_BANG = re.compile(r"!!|\?!|!\?")

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
            if STACKED_BANG.search(val):
                problems.append((rel, n, key, "üst üste ünlem", val))
            bad = [c for c in val if is_emoji(c)]
            if bad:
                problems.append((rel, n, key, "emoji " + "".join(bad), val))
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
    """Bildirim metni Swift içinde gömülü üretiliyor — aynı kurallar."""
    problems = []
    targets = [os.path.join(SRC, "Core", "Notifications"),
               os.path.join(SRC, "ONE2", "Notifications")]
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
                        if STACKED_BANG.search(val):
                            problems.append((rel, n, "", "üst üste ünlem", val))
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
    print(f"error: Marka sesi ihlali ({len(problems)}). CLAUDE.md › Kopya.")
    return 1

if __name__ == "__main__":
    sys.exit(main())
