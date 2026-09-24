# Guard'lar — ONE 2.0 ile çelişen kurallar

Tarih: 23 Eylül 2026 · Prompt 1b.

**Durum: uygulandı** (Faz 1, madde 4, 23 Eylül 2026). V1–V7 ve U1–U3, U5 guard dosyalarında yapıldı; V6 kararı: süre vaadi yasağı kaldırıldı. U2 kapsamında `one/ONE2/` taramaya eklendi. ADR-001 §2'deki `one2_imports_v3` sayacı eklendi (eşik 0). U4 için eşikler 23 Eylül'de `--update` ile çekildi; v3 silinince tekrar çekilecek.
Ölçüt: yeni `CLAUDE.md` (ONE 2.0). v3 kuralları: `docs/archive/CLAUDE_v3.md`.

## tooling/voice_guard.py

| # | Kural | Yer | Çelişki | Öneri |
|---|---|---|---|---|
| V1 | Kullanıcıya görünen hiçbir dizede ünlem yok | `check_strings` (satır 104), `check_notification_sources` (150) | Yeni kural yalnız **üst üste** ünlemi (`!!`, `?!`) yasaklıyor; tek ünlem idareli serbest | Regex'i `!{2,}` ve `[!?]{2,}` olarak daralt |
| V2 | `notif.*` anahtarlarında ve `Core/Notifications/*.swift`'te soru işareti yasak | 111, 152 | Uygulamanın soru sorması serbest ("Bugün nasılsın?" hatırlatması, akşam ritüeli daveti) | Kuralı kaldır |
| V3 | Yasaklı: `alışkanlık`, `üst üste`, `gün seri`, `seri devam`, `ritmi bozma`, `kök sal` | `BANNED` (56–64) | Seri, alışkanlık ve "N gün üst üste" dili artık serbest | Listeden çıkar |
| V4 | Yasaklı: `ister misin`, `ne dersin`, `hazır mısın` | `BANNED` | Rehberli akış ve soru serbest | Listeden çıkar |
| V5 | Yasaklı: `harika`, `kendine zaman tanı`, `zor bir hafta` | `BANNED` | Destekleyici dil serbest | Çıkar. `yoğunsun` teşhis dili sayıldığı için kalsın |
| V6 | Yasaklı: `10 saniye`, `on saniye`, `30 saniye`, `saniye sürer`, `saniyeni`, `tek dokunuş` (süre vaadi) | `BANNED` | Yeni `CLAUDE.md` bu konuda sessiz. Rehberli günlüklerde süre ("2 dakika") olağan | **Karar gerekli (Batuhan).** Kaldırılırsa `CLAUDE.md`'ye de yazılmalı |
| V7 | Başlık metinleri: modül açıklaması "v4 az konuşan kurator", hata mesajında "Marka sesi v4 ihlali … CLAUDE.md › Kopya kuralları" | 4–17, 172 | Bölüm adları ve ses tanımı değişti | Metni ONE 2.0'a ve yeni `CLAUDE.md` › Kopya bölümüne çevir |

Değişmeden kalabilecekler: emoji yasağı (✓ ✔ ✗ ✕ muaf), başlığın büyük harfle başlaması, `özledik`, `seni özledi`, `seni bekliyor`, `bekliyoruz`, `geri dön`, `kaçırma`, `son şans` (yalvaran ya da suçlayan geri kazanım dili), `yoğunsun`. `vibe` ve `mühürle` marka tercihi; tutulabilir (tahmin).

## tooling/ui_guard.sh

| # | Kural | Yer | Çelişki | Öneri |
|---|---|---|---|---|
| U1 | `system_nav` regex'i `NavigationStack` ve `NavigationView`'u da sayıyor | `RULE_REGEX[0]` (118) | v3 `CLAUDE.md` bile yığın için `NavigationStack`'e izin veriyordu. ONE 2.0'da NavigationStack + router planlanıyor (ADR-001 madde 4) | `NavigationStack`'i regex'ten çıkar; `navigationTitle`, `navigationBarTitleDisplayMode` ve `ToolbarItem` kalsın |
| U2 | Tarama yalnız `one/Features` ve `one/UI` altında | `scan_dirs` (45) | Yeni kod başka bir klasöre (ör. `one/ONE2/`) yazılırsa hiç denetlenmez | Kod yerleşimi ADR'de kesinleşince kapsamı genişlet |
| U3 | Hata mesajı "CLAUDE.md › Ekran Sözleşmesi" bölümüne yönlendiriyor | 217 | Yeni `CLAUDE.md`'de o bölüm yok ("v3'ten korunan kod kuralları") | Metni güncelle |
| U4 | Eşik mandalı tek `ui_guard_baseline.txt` dosyasında | 150–186 | Çelişki değil ama geçiş riski: v3 ekranları silindikçe sayılar düşer, eşik güncellenmezse ONE 2.0 kodu aynı "borç" payını sessizce doldurabilir | v3 silinince `--update` çalıştır. ONE 2.0 klasörü için eşiği 0 olan ayrı bir sayaç düşünülebilir |
| U5 | `CHROME_EXCLUDE`'da `UI/Components/V3Skeleton.swift` var | 49 | Dosya repoda yok (ölü referans) | Temizle |

Çelişmeyen kurallar (korunur): `system_font`, `raw_screen_padding`, `hardcoded_tr`, `white_on_color`, `plain_button`, `raw_hex`, `adhoc_card`, `raw_type_scale`, font bütünlüğü (`font_guard.py`).
