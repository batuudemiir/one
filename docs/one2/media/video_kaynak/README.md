# ONE 2.0 hikâye videosu — kaynak

`../one2_hikaye.mp4`: 1080×1080, 30 fps, 67,5 sn. Anlatı tarzı: krem zemin,
elle çizilmiş gibi beliren çizgiler (saniyede 8 kez hafif titreşim), serif
anlatı cümleleri kelime kelime. Kahraman "gün = kare".

Bölümler: 1 her gün bir kare · 2 çoğu geçip gider · 3 ONE doğdu (v3) ·
4 günün tamamı (sabah, check-in, günlük, akşam) · 5 eski anılar güvende ·
6 Faz 0 planı · 7 temel: 14 motor · 8 seri ve rozet · 9 hikâye yeni başlıyor.

## Yeniden üretmek

1. Fontlar (Lora, Poppins): `npm pack @fontsource/lora @fontsource/poppins`,
   paketleri bu klasörde `fonts/` altına aç; ağırlık CSS'lerini
   (Lora `400`, `400-italic`, `500`; Poppins `400`–`700`) `url(fonts/<paket>/files/…)`
   yoluyla birleştirip `fonts.css` olarak kaydet.
2. `python3 -m http.server 8766` (bu klasörde).
3. `NODE_PATH=$(npm root -g) node render.js http://localhost:8766/index.html out.mp4 <ffmpeg>`
   Tek kare önizleme: son argümana saniye listesi ver (`… prev x 5.5,12`).

Durum değişince (ADR-001 iş listesi, motor sayısı, "Sırada" satırı) metinleri güncelle.
