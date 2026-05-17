# SwiftLint Kurulumu — ONE

## 1. Binary kurulumu (tek seferlik, sistem-düzeyi)

```bash
brew install swiftlint
```

Doğrulama:
```bash
swiftlint version   # 0.55.0+ beklenir
```

## 2. Konfig dosyası

Proje root'unda `.swiftlint.yml` zaten hazır (Faz 1'de oluşturuldu).

## 3. Xcode Build Phase entegrasyonu

Her build'de lint çalışsın diye:

1. Xcode'da `ones.xcodeproj` aç → `one` target seç
2. **Build Phases** sekmesi
3. Sol üstten **+** → **New Run Script Phase**
4. Phase'i "Compile Sources"un **ÜSTÜNE** sürükle (kontrol önce çalışsın)
5. İsmini **"SwiftLint"** yap
6. Script kutusuna:

```bash
if which swiftlint > /dev/null; then
    swiftlint --config "${SRCROOT}/../.swiftlint.yml"
else
    echo "warning: SwiftLint not installed — run: brew install swiftlint"
fi
```

7. **Based on dependency analysis** kutusunu **kapat** (her build'de çalışsın diye)

## 4. CLI manuel çalıştırma

```bash
cd /Users/batudemir/Desktop/one/one
swiftlint lint --config .swiftlint.yml
# veya tek dosya:
swiftlint lint one/one/Features/Profile/ProfileView.swift
```

## 5. Custom Rule Özeti

ONE'a özel 4 custom rule aktif (`.swiftlint.yml` içinde):

| Rule | Yasak | Çözüm |
|---|---|---|
| `one_no_system_font_size` | `.font(.system(size: N))` | `ONETypography.<token>` |
| `one_no_inline_color_hex` | `Color(hex: "#...")` | `ONETokens.<token>` |
| `one_no_raw_animation_spring` | `Animation.spring(response:)` | `ONEAnimation.<token>` |
| `one_no_uiimpact_direct` | `UIImpactFeedbackGenerator(...)` | `ONEHaptics.<method>` |

Tüm rule'lar şu an **warning** seviyesinde. Migration tamamlandıkça severity `error`'a çıkacak (Faz 1.1 Migration cetveline bak).

## 6. Auto-fix (mümkün olduğunda)

```bash
swiftlint --fix
```

Custom rule'lar auto-fix değil — manuel migrate gerekir. Ama format/spacing default kuralları otomatik düzelir.
