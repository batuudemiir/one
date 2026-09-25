# UX-4b / UX-5b: Bugün ekranı ve giriş akışları

UX-4 ve UX-5'in yerine bu metin geçerli. Fixture ile çalış, motor tiplerini import etme.

## Bugün ekranı (yukarıdan aşağı)
1. TopBar: solda seri hapı (mono sayı brand renginde), ortada saate göre selamlama ("günaydın" 05–12, "iyi günler" 12–18, "iyi akşamlar" 18–05), sağda profil.
2. WeekStrip: gün durumları done / half / gap / today / future. half = sabah ya da akşamdan yalnız biri yapıldı. gap güne dokununca doldurma sheet'i açılır (7 gün sınırı).
3. Ritüel alanı, moda göre:
   a) Günlük mod: tek CheckInCard.
   b) Sabah+akşam modu: iki kart yatay sayfalı; sağdaki kartın 16pt'si görünür. 05–14 arası sabah kartı önde, 14 sonrası akşam kartı önde.
   Her kartın dört durumu var:
   - Başlamadı: başlık + tahmini süre (mono, "2 dk") + birincil "Başla".
   - Yarıda: "Devam et · 3/6" + ilerleme çizgisi.
   - Tamam: yankı cümlesi (affirmation) + MoodPill + bir satırlık özet (sabah: seçilen odak; akşam: tamamlanan pratik sayısı).
   - Kaçırıldı: sabah kartı 14:00 sonrası yapılmadıysa sönük görünür, "Yine de yap" bağlantısı.
4. "Pratiklerin": PracticeTile ızgarası, 2 sütun, son karo "+ Ekle".
5. "Haftalık tema": WeeklyThemeCard (günün sorusu, Literata).
6. Dock boşluğu.
Brand rengi ekranda yalnız seri sayısında görünür.

## Akış kabuğu (tüm akışlar için ortak)
fullScreenCover. Üstte adım sayısı kadar ince ilerleme çizgisi, solda kapat, sağda "Atla" (yalnız isteğe bağlı adımlarda).
- Her adımın başlığı screen-title değil title; soru metinleri Literata "prompt".
- Yazı adımları tek satırdan büyüyen serif alan; klavye açıkken alt butonun konumu korunur.
- Her adım bitince taslak kaydedilir; kapatıp açınca kaldığı adımdan devam eder.
- Kapanış ekranı: Seal (0.9 → 1.0 + opaklık, 320 ms, .soft haptik) + yankı cümlesi + "Bitti". Hafta şeridinde gün tike döner.
- Adım tanımları veriyle gelir: FlowStepViewData { id, kind, title, prompt?, optional, options? }. kind: score, emotions, causes, sleep, focus, text, list3, quote, practices, intentionReview.
  Ekran adımları sabit kodlamaz; fixture'daki listeyi çizer. Kişiselleştirmede adımlar kapatılıp sıralanabilir (Profil › Günlük akışı; bu ekran UX-10'da).

## Akış 1: Mood check-in (açılışta, ~30 sn)
1. score: "Şu an nasılsın?" ScoreScale 1–5 (Çok zor, Zor, İdare eder, İyi, Çok iyi). Seçince 300 ms sonra otomatik ileri.
2. emotions: "Hangi duygular?" EmotionChip, aile sırasıyla. İsteğe bağlı.
3. causes: "Ne etkiliyor?" CauseTag + "+ Ekle". İsteğe bağlı.
4. text: "Eklemek istediğin bir şey var mı?" İsteğe bağlı.
→ Kapanış: yankı cümlesi (mühürsüz, 2 sn ya da dokunuşla kapanır).

## Akış 2: Günlük check-in (tek mod, ~2 dk)
1. score: "Bugün nasılsın?"
2. emotions (isteğe bağlı)
3. causes (isteğe bağlı)
4. text: günün sorusu (motordan gelir; fixture'da 3 örnek). Önceki cevap varsa altında ink-muted kutu: "Geçen sefer şöyle yazmıştın: …" (ilk 2 satır).
5. list3: "Bugün neye minnettarsın?" 1–3 madde. İsteğe bağlı.
→ Kapanış: Seal + yankı. Gün "done".

## Akış 3: Sabah hazırlığı (~2 dk)
1. sleep: "Nasıl uyudun?" 1–5 (Çok kötü … Çok iyi) + isteğe bağlı saat seçici (4–12 saat, 0.5 adım).
2. score: "Güne nasıl başlıyorsun?" (emotions bu akışta tek dokunuşla açılan ek adım; varsayılan kapalı).
3. focus: "Bugün neye odaklanıyorsun?" Tek seçim. Seçenekler: Sakinlik, Sabır, Disiplin, Cesaret, Nezaket, Minnet, Odak, Kendine iyi davran, + Kendi kelimen.
4. quote: günün sözü (QuoteCard küçük varyant) + "Bu söz bugün sana ne söylüyor?" (isteğe bağlı tek satır). Buradan yazılan cevap QuoteReflection olarak da kaydedilir.
5. list3: "Bugünün en önemli bir, iki, üç şeyi?"
6. text: "Bugün seni ne zorlayabilir, nasıl karşılarsın?" (isteğe bağlı)
→ Kapanış: yarım mühür + "gün hazır." Gün "half" olur. Akşam da yapılırsa "done".

## Akış 4: Akşam değerlendirmesi (~3 dk)
1. score: "Günün nasıldı?" + emotions + causes (sabahtan farklı olarak ikisi de açık, isteğe bağlı).
2. intentionReview: "Sabah '{odak}' demiştin. Nasıl gitti?" Üç seçenek: Tuttum / Yarım / Olmadı. Sabah yapılmadıysa bu adım görünmez.
3. practices: bugünkü pratikler checklist; toggle'lar, "Hepsi tamam" yok.
4. text: "Bugün iyi giden bir şey?"
5. text: "Tekrar yaşasan neyi farklı yapardın?"
6. list3: "Neye minnettarsın?" (isteğe bağlı)
7. text: "Eklemek istediğin bir şey?" (isteğe bağlı)
→ Kapanış: tam mühür + yankı + sabah maddelerinden işaretlenmeyenler için tek satır: "Yarına taşıyayım mı?" (Taşı / Bırak).

## Kurallar
- En kısa tamamlama yalnız skor adımıdır; yazı adımlarının hepsi atlanabilir ve kimse cezalandırılmaz. Atlanan adım için "boş kaldı" dili kullanma.
- Sorular dönen havuzdan gelir; sabit olanlar yalnız score, sleep, focus, intentionReview. Metinleri Localizable'a tr olarak ekle.
- Süre etiketleri adım sayısından hesaplanır (skor adımları 10 sn, yazı adımları 30 sn).
- Erişilebilirlik: her adım başlığı ilk odak; VoiceOver'da otomatik ileri yerine "Devam" görünür.

## Fixture ve view data
Features/Shared/ViewData/FlowViewData.swift (FlowKind: moodCheckIn, daily, morning, evening; FlowStepViewData; FlowProgress).
Fixtures: her akış için boş / yarıda / tamam, sabah yapılmamış akşam, pratiksiz akşam.
Motorun sağlaması gerekenleri UX_istekleri.md'ye yaz: akış şablonlarının seed'i, günün sorusu, önceki cevap, odak listesi, taslak saklama, taşınan maddeler.

## Önizlemeler
Bugün: günlük mod başlamadı; sabah+akşam modu sabah tamam / akşam başlamadı; ikisi tamam; yükleniyor.
Her akışın her adımı: gece, gün ve AX3 önizlemesi.

Adım başına commit (Bugün, kabuk, akış 1–4). Sonunda rapor ver, dur.
