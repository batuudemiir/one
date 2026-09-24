# ONE 2.0 — Faz 0: Temel

Başlangıç: 23 Eylül 2026 · Hedef bitiş: 6 Ekim 2026 (2 hafta)
Çıkış kriteri: Ekran-ekran spesifikasyon, onaylı veri modeli, taşıma kararı ve mimari kararı (ADR) hazır; Faz 1 kodlamasına başlanabilir.

## İş kalemleri

| # | İş | Kim / nerede | Gün | Çıktı |
|---|---|---|---|---|
| 1 | Stoic'i 7 gün elle kullan, her ekranı kaydet | Batuhan, telefonda | 1–7 | Ekran kayıtları + doldurulmuş `01_stoic_teardown.md` |
| 2 | v3 kod tabanı denetimi (salt okuma) | Claude Code, Prompt 1 | 1–2 | `docs/one2/AUDIT.md` |
| 3 | Veri modeli taslağını gözden geçir | Batuhan + Claude (burada) | 3 | `02_veri_modeli.md` v1 onaylı |
| 4 | v3 → v2 veri taşıma analizi | Claude Code, Prompt 2 | 3–4 | `docs/one2/MIGRATION.md` |
| 5 | Taşıma kararı (A/B/C) | Batuhan | 5 | Karar satırı `02_veri_modeli.md` içinde |
| 6 | Ekran-ekran spesifikasyon | Claude (burada), teardown notlarından | 7–10 | `03_ekran_spesifikasyonu.md` |
| 7 | Mimari kararı (persistence, modüller, navigasyon, içerik dağıtımı) | Claude Code, Prompt 3 | 8–10 | `docs/one2/ADR-001.md` |
| 8 | İçerik planı başlangıcı: 12 haftalık tema başlıkları | Görkem | 5–12 | Tema listesi |
| 8a | `CLAUDE.md`'yi ONE 2.0 için yeniden yaz, eskisini arşivle (AUDIT R12) | Claude Code, Prompt 1b | 3–4 | Yeni `CLAUDE.md` |
| 8b | Kullanıcı verisi dökümlerini (`tooling/*.json`) git'ten çıkar; push etmeden önce (AUDIT R13) | Batuhan | 1 | `.gitignore` + `git rm --cached` |
| 9 | Faz 0 kapanış | Batuhan | 13–14 | Faz 1 backlog |

## Faz 0'da kilitlenecek kararlar

| Karar | Seçenekler | Varsayılan öneri |
|---|---|---|
| Persistence | Core Data + NSPersistentCloudKitContainer / SwiftData | **Karar: Core Data**, mevcut container, yeni model sürümü `one 3` (AUDIT R2, R3) |
| Min iOS | 17 / 18 | 17 (Stoic de 17) |
| Eski veri | A: tam taşı · B: arşiv olarak kopyala · B': `DailySong`'u salt okunur oku · C: taşıma | B' (kopyalama yok) |
| Kod yerleşimi | Aynı proje, yeni `ONE2/` klasörü + `one2` branch / tamamen yeni proje | Aynı proje ve target (bundle ID **`com.batu.ones`** korunur; App Group `group.com.batudemir.ones`), yeni klasör, yeni branch |
| AI | Relaunch'a dahil / Faz 7 | Faz 7 (bekliyor) |
| Günde çoklu mood | Evet (Stoic gibi her açılışta) | Evet |

## Kurallar (Faz 0 boyunca)

- Faz 0'da ürün kodu yazılmaz; yalnız denetim, doküman ve karar.
- Stoic'ten içerik (prompt metni, alıntı seçkisi, mentor karakteri, görsel) kopyalanmaz. Sistem ve akış referans alınır.
- Yeni SPM bağımlılığı sormadan eklenmez.
