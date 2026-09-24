#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
catalog.py — Localizable.strings için ortak okuma ve canlı/ölü ayrımı.

`voice_guard.py` ile `dead_keys.py` aynı yöntemi kullansın diye tek kaynak:
iki araç "canlı anahtar"ı farklı tanımlarsa biri denetlemediğini sanır,
öteki kullanılan bir anahtarı siler.

**Canlı sayma kuralı bilerek geniştir.** Anahtar bir kaynak dosyada geçen
bir dize olarak görünüyorsa canlıdır — `NSLocalizedString` çağrısı olmasa
bile. Gerekçe: SwiftUI'de `Text("archive.empty.title")` da katalogdan
okur (LocalizedStringKey), storyboard/xib ve plist de anahtar taşıyabilir.
Silme aracı için yanlış "ölü" kararı geri alınması pahalı bir hata;
yanlış "canlı" kararı yalnızca birkaç satır fazladan bırakır.
"""

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Kaynak sayılan uzantılar. `.strings` yok: katalogun kendisi kullanım değil.
SOURCE_EXT = (".swift", ".plist", ".storyboard", ".xib", ".intentdefinition",
              ".json", ".m", ".h", ".stringsdict")

SKIP_DIRS = {".git", "build", "DerivedData", ".build", "Pods", ".swiftpm"}


def strings_files(root: str = ROOT) -> list[str]:
    """Tüm dillerin Localizable.strings yolları, dil koduna göre sıralı."""
    out = []
    for dirpath, dirnames, filenames in os.walk(os.path.join(root, "one")):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        if dirpath.endswith(".lproj") and "Localizable.strings" in filenames:
            out.append(os.path.join(dirpath, "Localizable.strings"))
    return sorted(out)


def language_of(path: str) -> str:
    return os.path.basename(os.path.dirname(path)).replace(".lproj", "")


def read_catalog(path: str) -> dict[str, tuple[int, str]]:
    """anahtar → (satır numarası, değer)."""
    out = {}
    with open(path, encoding="utf8") as fh:
        for n, line in enumerate(fh, 1):
            m = re.match(r'^"([^"]+)"\s*=\s*"(.*)";\s*$', line)
            if m:
                out[m.group(1)] = (n, m.group(2))
    return out


def source_blob(root: str = ROOT) -> str:
    """Bütün kaynak dosyaları tek metinde toplar."""
    chunks = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        if dirpath.endswith(".lproj"):
            continue
        for name in filenames:
            if name.endswith(SOURCE_EXT):
                try:
                    with open(os.path.join(dirpath, name), encoding="utf8",
                              errors="ignore") as fh:
                        chunks.append(fh.read())
                except OSError:
                    continue
    return "\n".join(chunks)


def dynamic_prefixes(blob: str) -> list[str]:
    """`"mood.v3.\\(rawValue).label"` gibi enterpolasyonlu anahtarların kökü."""
    prefixes = []
    for m in re.finditer(r'"([A-Za-z][A-Za-z0-9_.]*?)\\\(', blob):
        prefix = m.group(1)
        if "." in prefix:
            prefixes.append(prefix)
    return sorted(set(prefixes))


def classify(keys, blob: str) -> tuple[set[str], set[str]]:
    """(canlı, ölü). Anahtar kaynakta dize olarak geçiyorsa canlı."""
    prefixes = dynamic_prefixes(blob)
    live, dead = set(), set()
    for key in keys:
        if f'"{key}"' in blob or any(key.startswith(p) for p in prefixes):
            live.add(key)
        else:
            dead.add(key)
    return live, dead
