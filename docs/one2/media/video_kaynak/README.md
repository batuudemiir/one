# ONE 2.0 günlük akışı videosu — kaynak

`../one2_gunluk_akisi.mp4`: 1080×1920 (Reels / TikTok / Shorts), 30 fps, 46,5 sn.
Piksel sanatı: sahne 180×320 pikselde çizilir, 6 kat büyütülür; yazılar
Pixelify Sans ile aynı ızgarada basılır. Arayüz renkleri `design-system/tokens.json` (gece).

Öykü, bir salı gününün giriş akışı (`05_ux_promptlari.md` UX-4/5/6):
kilit ekranı bildirimi → Bugün → check-in (skor, duygular, nedenler, not) →
"Kaydedildi." → gün içinde yeni anlar → akşam haftalık tema sorusuna yazı →
"Bugün kapandı." → yıl mozaiği → kapanış kartı. Gökyüzü şafaktan geceye döner.

## Yeniden üretmek

1. Font: `npm pack @fontsource/pixelify-sans`, paketi bu klasörde `fonts/` altına aç;
   `400`, `500`, `700` CSS'lerini `url(fonts/<paket>/files/…)` yoluyla birleştirip
   `fonts.css` olarak kaydet.
2. `python3 -m http.server 8767` (bu klasörde).
3. `NODE_PATH=$(npm root -g) node render.js http://localhost:8767/index.html out.mp4 <ffmpeg>`
   Tek kare önizleme: son argümana saniye listesi ver (`… prev x 6,12.6`).

Zamanlama `K` nesnesinde, anlatı cümleleri `draw()` sonundaki `caption` çağrılarında.
