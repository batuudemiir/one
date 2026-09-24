#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dead_keys.py — kodda çağrılmayan katalog anahtarlarını listeler ve siler.

Neden: Türkçe katalogda anahtarların yarıya yakını ölü. Ölü anahtar zararsız
görünüyor ama v4'ün reddettiği metinleri saklıyor (`milestones.*` kilitli–açık
ödül dili, `comeback.*` "istersen doldur", `echo.stats.streakDays` "gün seri").
Biri onları yeniden bağladığı gün ses geri geliyor. `voice_guard.py` ölü
anahtarları bilerek denetlemiyor — o yüzden temizlik ayrı bir işin konusu.

Canlı/ölü ayrımı `catalog.py`'de, `voice_guard.py` ile ortak.

    python3 tooling/dead_keys.py --dry-run     # ne silinecek (varsayılan)
    python3 tooling/dead_keys.py --dry-run --all   # tam liste
    python3 tooling/dead_keys.py --apply       # dokuz dilden sil
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import catalog  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true",
                    help="ölü anahtarları dokuz dilden sil")
    ap.add_argument("--dry-run", action="store_true",
                    help="yalnız listele (varsayılan)")
    ap.add_argument("--all", action="store_true",
                    help="listeyi kısaltma")
    args = ap.parse_args()
    apply = args.apply and not args.dry_run

    files = catalog.strings_files()
    if not files:
        print("katalog bulunamadı"); return 2

    blob = catalog.source_blob()

    # Referans dil: tr. Diğer diller aynı anahtar kümesini taşıyor; bir dilde
    # olup tr'de olmayan anahtar da ölü sayılır (aşağıda ayrıca raporlanıyor).
    base = next(f for f in files if catalog.language_of(f) == "tr")
    base_keys = catalog.read_catalog(base)
    live, dead = catalog.classify(set(base_keys), blob)

    print(f"kaynak taraması: {len(blob)//1024} KB")
    print(f"tr katalog: {len(base_keys)} anahtar · canlı {len(live)} · "
          f"ölü {len(dead)} (%{100*len(dead)//max(1,len(base_keys))})")
    print()

    # Öncelikli gruplar — görev dosyasının işaret ettiği v4 karşıtı metinler.
    watch = ("milestones.", "comeback.", "onboarding.slogan",
             "onboarding.notif.freezeHint", "echo.stats.streakDays",
             "today.title")
    flagged = sorted(k for k in dead if k.startswith(watch))
    if flagged:
        print("v4'ün reddettiği mekanikleri anlatan ölü anahtarlar:")
        for k in flagged:
            print(f"   {k:34s} {base_keys[k][1][:52]}")
        print()

    shown = sorted(dead) if args.all else sorted(dead)[:40]
    print(f"silinecek anahtarlar ({len(dead)}){'' if args.all else ' — ilk 40'}:")
    for k in shown:
        print(f"   {k:34s} {base_keys[k][1][:52]}")
    if not args.all and len(dead) > 40:
        print(f"   … {len(dead)-40} tane daha (--all ile tümü)")
    print()

    # Dil başına sayım: bir dilde fazladan duran anahtarlar da temizlenir.
    total = 0
    for path in files:
        keys = catalog.read_catalog(path)
        drop = {k for k in keys if k in dead or k not in base_keys}
        extra = {k for k in keys if k not in base_keys}
        total += len(drop)
        note = f" (+{len(extra)} tr'de olmayan)" if extra else ""
        print(f"   {catalog.language_of(path):8s} {len(keys):5d} anahtar → "
              f"{len(drop):4d} silinecek{note}")
        if apply:
            lines = open(path, encoding="utf8").read().split("\n")
            kept = []
            for line in lines:
                m = catalog.re.match(r'^"([^"]+)"\s*=', line)
                if m and m.group(1) in drop:
                    continue
                kept.append(line)
            open(path, "w", encoding="utf8").write("\n".join(kept))

    print()
    if apply:
        print(f"silindi: dokuz dilde toplam {total} satır")
    else:
        print(f"dry-run — hiçbir şey silinmedi. Uygulamak için: "
              f"python3 tooling/dead_keys.py --apply")
    return 0


if __name__ == "__main__":
    sys.exit(main())
