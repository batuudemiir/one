# Faz 0 — Claude Code Promptları (v2, AUDIT sonrası)

Kullanım: Claude Code'u repo kökünde (`~/Desktop/one/one`) aç. Promptları sırayla, her birinin çıktısını okuduktan sonra ver. Faz 0 boyunca Claude Code **ürün kodunu değiştirmez** (1b yalnız `CLAUDE.md` ve `.gitignore`'a dokunur).

Durum: Prompt 1 tamam (`AUDIT.md`). Sıradaki: 1b → 2 → 3.

Not: Aktif dal `tek-odak-faz1-2` ve 40+ commitlenmemiş değişiklik var. ONE 2.0 işine başlamadan önce bunları commitle ya da stash'le, sonra `git checkout -b one2/faz0`.

---

## Prompt 1b — Kurallar ve repo hijyeni (hemen)

```
docs/one2/AUDIT.md (özellikle R12 ve R13), docs/one2/00_faz0_plan.md ve docs/one2/02_veri_modeli.md dosyalarını oku.

ONE 2.0'da ürün yönü değişti: Stoic benzeri günlük + mood check-in + sabah/akşam ritüeli + haftalık tema + streak ve rozetler + geriye dönük giriş + premium. Mevcut CLAUDE.md, ui_guard ve voice_guard bunların çoğunu yasaklıyor.

Yalnız şunları yap, ürün koduna dokunma:

1. Mevcut CLAUDE.md'yi docs/archive/CLAUDE_v3.md olarak kopyala.
2. Yeni CLAUDE.md yaz (kısa, en fazla ~150 satır):
   - Ürün: ONE 2.0 tanımı ve docs/one2/ klasörünün doğruluk kaynağı olduğu.
   - Sabit kimlikler: com.batu.ones, iCloud.com.batu.ones, group.com.batudemir.ones, widget kind MoodWidget. Bunların asla değiştirilmeyeceği.
   - Veri kuralları: DailySong entity'sine ve mevcut model sürümlerine dokunulmaz; yeni entity'ler yalnız yeni model sürümüne eklenir; CloudKit uyumu (opsiyonel alanlar, ters ilişkiler, unique yok).
   - v3'ten korunan kod kuralları: V3Tokens/V3Typography kullanımı, hardcoded hex yok (UIColor dynamic provider), her Button label'ına .contentShape(Rectangle()), önce mevcut bileşenler, sormadan yeni SPM bağımlılığı yok, işlevsiz kontrol yok.
   - Kaldırılan yasaklar: streak, rozet, geriye dönük giriş, skor/ölçüm, rehberli/destekleyici dil artık serbest. Hâlâ geçerli olanlar: emoji yok, stacked ünlem yok, Türkçe kopya "sen" diliyle ve kısa.
   - Stoic'ten içerik (prompt metni, alıntı seçkisi, mentor karakteri, görsel, marka) kopyalanmaz.
3. tooling/voice_guard.py ve tooling/ui_guard.sh içinde ONE 2.0 ile çelişen kuralları LİSTELE (değiştirme); listeyi docs/one2/GUARDS_TODO.md'ye yaz.
4. .gitignore'a tooling/appusers.json, tooling/dailyshare.json, tooling/friendships.json ekle ve bu üç dosyayı `git rm --cached` ile izlemeden çıkar (dosyalar diskte kalsın). Commit etme; hangi komutları çalıştırdığını raporla.
```

---

## Prompt 2 — Eski veri ve model sürümü analizi

```
docs/one2/AUDIT.md ve docs/one2/02_veri_modeli.md (v0.2) dosyalarını oku.

HİÇBİR ürün dosyasını değiştirme. docs/one2/MIGRATION.md yaz:

1. Seçenek B' (DailySong salt okunur okunur, kopyalanmaz) için somut tasarım: v3 günlerini Yolculuk'ta ONE 2.0 kayıtlarıyla birleştirecek okuma katmanı (hangi mevcut tipler kullanılır: Moment, Day, ArchiveStore?), dayKey türetme, pas günlerinin dışlanması, yazma yollarının (insertNewMoment, savePassedDay, SaveMomentIntent, MomentWriter) nasıl kapatılacağı, v3 widget ve bildirim yan etkilerinin kapatılması.
2. B' için riskler ve B / A ile kısa karşılaştırma (iş, risk, kullanıcı deneyimi).
3. Model sürümü `one 3` planı: 02_veri_modeli.md'deki her entity ve alan için CloudKit uyumluluk kontrolü (opsiyonellik, varsayılanlar, ters ilişkiler, delete rule'lar, ordered yok, external storage). Uyumsuzluk varsa düzeltme önerisi.
4. Lightweight migration'ın `one 2` → `one 3` için çalışacağının gerekçesi; çalışmayacağı durumlar.
5. CloudKit şema deploy adımları (development'ta initializeCloudKitSchema, Dashboard'da production'a deploy, sürüm çıkmadan önce kontrol listesi).
6. İlk açılışta çalışacak temizlik işleri: emekli bildirim ID'leri (v3_daily_reminder_* prefix dahil), Live Activity, (Çevre kalkarsa) CloudKit subscription'ları, Spotify Keychain öğesi.
7. Test planı: gerçek bir v3 SQLite store'undan fixture alıp `one 3`'e açma ve B' okuma katmanını test etme.

Sonunda tek paragraf: önerin ve gerekçesi.
```

---

## Prompt 3 — Mimari kararı / ADR (taşıma kararından sonra)

```
docs/one2/ klasöründeki tüm dosyaları oku (AUDIT, MIGRATION, veri modeli v0.2, varsa ekran spesifikasyonu).

HİÇBİR ürün dosyasını değiştirme. docs/one2/ADR-001.md yaz. Her karar için bağlam, seçenekler, karar, sonuçlar:

1. Persistence: Core Data + mevcut NSPersistentCloudKitContainer, model sürümü `one 3` (kararlaştırıldı; ADR'de gerekçesiyle kayda geçir). PersistenceController'ın nasıl bölüneceği (DailySong'a özel yardımcılar ayrılır).
2. Kod yerleşimi: aynı proje ve app target (com.batu.ones). Yeni kod için klasör yapısı (ör. one/ONE2/Core, Data, Content, DesignSystem, Features/*); local SPM paketi gerekip gerekmediği (1 geliştirici, aşırı modülerlik yok). v3 kodunun geçişte izolasyonu ve silinme zamanı; derleme süresi.
3. Uygulama girişi: v3 ve ONE 2.0 arasında geçiş (feature flag ile tek build, flag kapalıyken v3). Relaunch'ta v3 feature ekranlarının silinmesi.
4. Mimari desen: Observation, NavigationStack + basit router, bağımlılık enjeksiyonu (environment), feature sınırları.
5. İçerik dağıtımı: tema/prompt/rehberli günlük/söz/katalog JSON'ları (bundle + uzak: CloudKit public DB mi statik JSON host mu; forvibe.app alanı kullanılabilir mi), sürümleme, önbellek, çevrimdışı.
6. Bildirimler: NotificationOrchestrator üzerine yeni türler (sabah, akşam, odak, içerik), 64 bekleyen bildirim sınırı, kimlik şeması, v3 ID'lerinin emekliliği.
7. Tasarım sistemi: V3Tokens/V3Typography/ONEAnimation/ONEHaptics TAŞI kararı; V3Mood'un duygu kataloğundaki rolü; yeni bileşen listesi.
8. StoreKit 2: ürün ID şeması (mevcut com.batudemir.ones.oneplus.* ONEPlus.storekit test dosyasıyla uyum), Free/Premium entitlement, ileride Premium + AI.
9. Widget, App Intents (SaveMomentIntent uyumluluğu), App Group köprüsü, deep link host'larının yeni ekranlara eşlenmesi.
10. Çevre (sosyal katman): tutulursa modül sınırı, kaldırılırsa geçiş sürümü planı (R8).
11. Test ve CI: Swift Testing ile veri katmanı, dayKey ve streak testleri; bozuk test planının düzeltilmesi; minimal CI (xcodebuild test).
12. Proje hijyeni: extension sürümlerinin app sürümüne eşitlenmesi, test bundle ID'lerindeki çift nokta, boş dosyalar, Info.plist çift izin metni.

Kısıtlar: Yeni SPM bağımlılığı önereceksen "onay gerekli" listesine koy. Sonunda Faz 1'in ilk 10 somut iş kalemini sırala (henüz kod yazma).
```

---

## Faz 0 sonrası

Faz 1 iskelet promptu ADR-001 onaylandıktan sonra yazılacak.
