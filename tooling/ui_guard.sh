#!/bin/bash
#
# ui_guard.sh — Ekran Sözleşmesi bekçisi
#
# Tutarlılık kurallarını sayarak zorlar. Her kural bir sayaç; sayaç
# `ui_guard_baseline.txt`'teki eşiği AŞARSA build hata verir.
#
# Neden eşik, neden sıfır değil: kuralların çoğu bugün ihlal ediliyor ve
# hepsini aynı anda sıfırlamak tek bir dev commit demek. Eşik mandalı tek
# yönlü çeviriyor — borç azalabilir, artamaz. Bir faz bitince
# `--update` ile eşikler o günkü sayıya çekilir ve bir daha yukarı çıkamaz.
#
# Kullanım:
#   tooling/ui_guard.sh            # denetle (CI / build phase)
#   tooling/ui_guard.sh --update   # eşikleri bugünkü sayılara çek
#   tooling/ui_guard.sh --report   # sayıları ve dosya kırılımını göster
#
# Font bütünlüğü (`tooling/font_guard.py`) buradan da çalışır ama eşiksizdir:
# ikili bir değişmez, borç sayacı değil. "İki font eksik olabilir" diye bir
# eşik yok — eksikse uygulama sessizce sistem yüzüne düşer. Bu repoda iki kez
# oldu (bundle edilmemiş GeistMono; silinen DM Sans dosyaları), ikisi de
# çökme üretmedi, ikisi de gözle bakılana dek fark edilmedi.
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/one"
BASELINE="$ROOT/tooling/ui_guard_baseline.txt"

MODE="check"
case "${1:-}" in
  --update) MODE="update" ;;
  --report) MODE="report" ;;
  "")       MODE="check" ;;
  *) echo "bilinmeyen argüman: $1"; exit 2 ;;
esac

if [[ ! -d "$SRC" ]]; then
  echo "kaynak bulunamadı: $SRC"; exit 2
fi

# Yalnız ekran katmanı taranır. Tasarım sistemi kendi ham sayılarını
# tanımlamak zorunda — kural onu çağıranlar için.
SCAN=(-name "*.swift")
# ONE 2.0 kodu `one/ONE2/` altında (ADR-001 §2); aynı kurallar onu da kapsar.
scan_dirs() {
  local dirs=("$SRC/Features" "$SRC/UI")
  [[ -d "$SRC/ONE2" ]] && dirs+=("$SRC/ONE2")
  find "${dirs[@]}" "${SCAN[@]}" -not -path "*/UI/DesignSystem/*"
}

# Paylaşılan kabuk ve bileşen dosyaları ham sayı yazmak zorunda olduğu için
# bazı kurallarda hariç tutuluyor.
CHROME_EXCLUDE='UI/Components/V3TopBar.swift|UI/Components/SubScreenChrome.swift|UI/Components/V3Sheet.swift|UI/Components/BottomNavigation.swift'

count() { grep -rEl "$1" $(scan_dirs) 2>/dev/null | wc -l | tr -d ' '; }

# `hits <regex> [ek_dışlama_regex]`
#
# İkinci argüman kural başına: bazı kuralların meşru istisnaları var ve
# onları ana regex'e gömmek regex'i okunmaz hale getiriyor (ERE'de negatif
# lookahead yok). Boş bırakılırsa hiçbir şey elenmez.
hits()  {
  local out
  out=$(grep -rEn "$1" $(scan_dirs) 2>/dev/null | grep -vE "$CHROME_EXCLUDE")
  if [[ -n "${2:-}" ]]; then out=$(printf '%s\n' "$out" | grep -vE "$2"); fi
  printf '%s\n' "$out" | grep -v '^$'
}
hitcount() { hits "$1" "${2:-}" | wc -l | tr -d ' '; }

# ── Kurallar ────────────────────────────────────────────────────────────
#
# Her kural: ad | açıklama | regex
# Sayım satır bazlı; `CHROME_EXCLUDE` dosyaları düşülür.

RULE_NAMES=(
  system_nav
  system_font
  raw_screen_padding
  hardcoded_tr
  white_on_color
  plain_button
  raw_hex
  adhoc_card
  raw_type_scale
  one2_imports_v3
)

RULE_DESC=(
  "Sistem navigationTitle / toolbar / NavigationView (NavigationStack serbest: ADR-001 §4)"
  "Ham punto — metin: ONETypography rolü · ikon: ONEIcon rolü (11-18pt bandı)"
  "Ham ekran kenar payı — V3Tokens.channel kullan"
  "Sabit Türkçe dize — NSLocalizedString kullan (parametreler dahil)"
  "Renk zemin üstünde .white / .black — mood ink eşi kullan"
  ".buttonStyle(.plain) — .onePressable kullan"
  "Ham hex rengi — V3Tokens / V3Mood kullan"
  "Ad-hoc kart zemini — .oneCardBackground(radius:) kullan"
  "Ham punto — ONETypography rolü kullan (bodyLG/bodySM/displayMD…)"
  "ONE2 kodu v3 ekran/servis tipine dokunuyor (ADR-001 §2 izolasyon kuralı)"
)

# Kural başına ek dışlama (indeks sırası RULE_NAMES ile aynı; boş = yok).
#
# `hardcoded_tr` için gerekli: kural artık `Text("…")` değil **her** Türkçe
# diyakritikli literal'i sayıyor, çünkü eski hâli yalnız doğrudan `Text("…")`
# biçimini görüyordu ve `statRow(label: "Sessiz gün")` gibi parametre yoluyla
# geçen sabit dizeler kuralın altından geçiyordu — eşik 0 görünürken dosyalar
# Türkçe doluydu. Genişletince iki meşru kaynak elenmeli:
#   • `NSLocalizedString(..., comment: "Türkçe açıklama")` — comment zaten
#     çevirmene not, kullanıcıya gitmiyor.
#   • `//` ile başlayan yorum satırları — bu depoda yorumlar Türkçe.
#   • `ONELogger.…("…")` — log mesajı, kullanıcıya gitmiyor.
#   • Tek karakterlik `case "ş":` dalları — arama katlama tablosu gibi
#     harf eşlemeleri; metin değil, veri.
RULE_EXCLUDE=(
  ""
  ""
  ""
  "NSLocalizedString|^[^:]*:[0-9]+: *//|LocalizedString|ONELogger\\.|^[^:]*:[0-9]+: *case \"[^\" ]{1,2}\"[,:]"
  ""
  ""
  ""
  ""
  ""
  "^[^:]*/one/(Features|UI)/"
)

RULE_REGEX=(
  'NavigationView|\.navigationTitle|navigationBarTitleDisplayMode|ToolbarItem'
  '\.font\(\.system\(size:'
  '\.padding\(\.horizontal, (1[4-9]|2[0-9]|3[0-9])\)'
  '"[^"]*(ç|ğ|ı|ö|ş|ü|Ç|Ğ|İ|Ö|Ş|Ü)[^"]*"'
  'foregroundColor\(\.white\)|foregroundStyle\(\.white\)|foregroundColor\(\.black\)'
  '\.buttonStyle\(\.plain\)'
  'Color\(hex: "#'
  '\.fill\(V3Tokens\.surface\)'
  '\.font\(V3Typography\.(sans|display|mono)\('
  '\b(CloudKitManager|TodayViewModel|ArchiveStore|DailyEntry|MomentWriter|MonthSummary|EchoViewModel|ProfileViewModel|GlobalUIState|V3ReminderScheduler|insertNewMoment|savePassedDay)\b'
)

declare -a CURRENT
for i in "${!RULE_NAMES[@]}"; do
  CURRENT[$i]=$(hitcount "${RULE_REGEX[$i]}" "${RULE_EXCLUDE[$i]:-}")
done

# ── Rapor ───────────────────────────────────────────────────────────────

if [[ "$MODE" == "report" ]]; then
  for i in "${!RULE_NAMES[@]}"; do
    printf '\n── %s  (%s)\n   %s\n' "${RULE_NAMES[$i]}" "${CURRENT[$i]}" "${RULE_DESC[$i]}"
    hits "${RULE_REGEX[$i]}" "${RULE_EXCLUDE[$i]:-}" | awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -8 | sed 's/^/     /'
  done
  echo
  printf '\n── font bütünlüğü (eşiksiz)\n'
  python3 "$ROOT/tooling/font_guard.py" | sed 's/^/     /'
  printf '\n── marka sesi (eşiksiz)\n'
  python3 "$ROOT/tooling/voice_guard.py" | sed 's/^/     /'
  echo
  exit 0
fi

# ── Eşik yazımı ─────────────────────────────────────────────────────────

if [[ "$MODE" == "update" ]]; then
  {
    echo "# ui_guard eşikleri — $(date '+%Y-%m-%d')"
    echo "# Bu sayılar yalnız AZALIR. Artıran değişiklik build'i kırar."
    for i in "${!RULE_NAMES[@]}"; do
      echo "${RULE_NAMES[$i]}=${CURRENT[$i]}"
    done
  } > "$BASELINE"
  echo "eşikler güncellendi → $BASELINE"
  cat "$BASELINE"
  exit 0
fi

# ── Denetim ─────────────────────────────────────────────────────────────

if [[ ! -f "$BASELINE" ]]; then
  echo "eşik dosyası yok. Önce: tooling/ui_guard.sh --update"; exit 2
fi

FAILED=0
for i in "${!RULE_NAMES[@]}"; do
  name="${RULE_NAMES[$i]}"
  now="${CURRENT[$i]}"
  want=$(grep -E "^${name}=" "$BASELINE" | cut -d= -f2)
  want="${want:-0}"

  if (( now > want )); then
    echo "error: ui_guard — ${RULE_DESC[$i]}"
    echo "note:  ${name}: ${now} ihlal, eşik ${want}. Yeni ihlal eklenmiş."
    hits "${RULE_REGEX[$i]}" "${RULE_EXCLUDE[$i]:-}" | head -5 | sed 's/^/note:  /'
    FAILED=1
  elif (( now < want )); then
    echo "note: ui_guard — ${name}: ${now} (eşik ${want}). Eşiği düşür: tooling/ui_guard.sh --update"
  fi
done

# ── Font bütünlüğü ──────────────────────────────────────────────────────
#
# Eşiksiz, çünkü kuralın doğası farklı: yukarıdakiler "borç artmasın"
# sayaçları, bu ise sağlanması zorunlu bir değişmez. Info.plist'te bildirilen
# her font diskte olmalı ve koddaki her font adı bunlardan birinin PostScript
# adıyla karşılanmalı.
#
# `python3` yoksa denetim ATLANMAZ, hata verir. Sessizce atlamak tam da bu
# bekçinin engellemeye çalıştığı şey.

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: ui_guard — font ve ses denetimi için python3 gerekli, bulunamadı."
  echo "note:  Atlanmadı: font eksikliği sessiz bir hata, denetimi de sessiz olamaz."
  FAILED=1
else
  if ! python3 "$ROOT/tooling/font_guard.py"; then
    FAILED=1
  fi

  # ── Marka sesi (eşiksiz) ────────────────────────────────────────────
  #
  # Font gibi ikili bir değişmez: bir ünlem ya da "10 saniye" ürüne
  # girdiği anda ses değişiyor, "iki tane olabilir" diye bir eşik yok.
  if ! python3 "$ROOT/tooling/voice_guard.py"; then
    FAILED=1
  fi
fi

if (( FAILED )); then
  echo "error: Ekran kuralı ihlali. CLAUDE.md › v3'ten korunan kod kuralları."
  exit 1
fi

echo "ui_guard: tamam"
