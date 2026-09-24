# ONE 2.0 — Uçtan uca elle test senaryoları

Tarih: 24 Eylül 2026 · Taslak (motor oturumu); UX-11'de ekran adımlarıyla tamamlanır (05 › UX-11).
Ortam: TestFlight ya da Xcode (DEBUG, `ONE2Flag` açık), iCloud hesaplı cihaz; ikinci cihaz 7. ve 11. senaryolar için.
Zaman atlatma: cihaz saatini ileri al (Ayarlar › Genel › Tarih ve Saat). Her senaryoda beklenen motor davranışı parantez içinde.

| # | Senaryo | Adımlar | Beklenen |
|---|---|---|---|
| 1 | İlk kurulum | Temiz kurulum, uçak modu açık, uygulamayı aç | Bugün dolu açılır: tema, günün sözü, hafta şeridi. Boş ekran yok (bundle içeriği, E1) |
| 2 | Onboarding | Odak: kaygı + uyku; yollar: Sakin, Filozof; mod: sabah-akşam; saatler 08:00 / 21:30 | Profil KVS'ye yazılır (E12); bildirim penceresi 7 gün sabah + akşam kurulur (E13) |
| 3 | İlk check-in | Sabah kartından skor 2, "Gergin", neden "Uyku" | Yankı cümlesi skor 2'ye uygun, baskı dili yok (E6). Kart yarım gün gösterir, seri 1 (E8). Widget'ta skor ve yankı (E14) |
| 4 | Yankı kalıcı | Uygulamayı kapat, aç | Aynı yankı cümlesi (echoID) |
| 5 | İlk yazı | + › Boş sayfa, 25 kelime yaz | Gün yazıyla tamam (E8). "İlk sayfa" rozeti duyurulur (E9) |
| 6 | Sözler, 30 kart | Sana özel akışında 30 kart kaydır; her kartta ≥ 2 sn dur | Tekrar yok. Aynı yazar 8 kartta en fazla 1. Her 5 kartta en az 1 kısa (E2) |
| 7 | Hızlı geçiş | 5 kartı hızla kaydır, uygulamayı arka plana al, geri dön | Hızlı geçilen kartlar görülmüş sayılmaz, sonraki oturumda döner (E2.2) |
| 8 | Söze yazı | Bir karttan "Yaz"; aynı söze ertesi gün tekrar yaz | İkinci yazışta farklı soru (E4). Sözler › Yazdıklarım'da görünür |
| 9 | Ertesi gün seri | Saati ertesi güne al, aç, akşam kartını tamamla | Seri 2. Sabah bildirimi o gün kurulmaz (açıldı) |
| 10 | Boş gün | Bir günü atla, sonraki gün aç | Seri 0, `one2_streak_broken` bir kez. Hafta şeridinde boşluk (doldurulabilir). Seri hatırlatması yalnız seri > 0 ve bugün boşken gider (açıksa) |
| 11 | Geriye dönük doldurma | Boş güne dokun, check-in yap | Gün tamamlanır ("geriye dönük"), seri onarılır. 8 gün önceki gün doldurulamaz (E8) |
| 12 | Eğilimler | 7+ check-in sonra Eğilimler'i aç | 14 gün çizgisi ve ortalama görünür. Etiket ilişkisi "Henüz erken (21)". Ücretsizde 90 gün kilitli (E10, E15) |
| 13 | İki cihaz | Cihaz B'de aynı hesapla aç | Günün sözü aynı (KVS). Seri ve rozetler aynı. Çift DayRecord yok (dedupe) |
| 14 | v3 verisi | v3 kayıtlı hesapla aç | Yolculuk'ta "ONE 1" kartları görünür. Seri ve istatistiğe girmez (B') |
| 15 | Premium | Paywall › Yıllık (Sandbox) | Deneme başlar. Tüm yollar ve Markdown dışa aktarma açılır. İade sonrası yetki düşer (E15) |
| 16 | Dışa aktarma | Profil › Dışa aktar › JSON | Dosya katalogsuz okunur; `legacyMoments` sayısı pas günleri hariç v3 kayıtları (E16) |
| 17 | Arama | Yolculuk'ta "gunluk" ara | "günlük" içeren girdiler bulunur, eşleşme vurgulu (E11) |
| 18 | İçerik güncellemesi | Uzak manifestte contentVersion 2 yayınla, ertesi gün aç | Yeni içerik yüklenir; bozuk hash'te eski içerik kalır (E1) |
