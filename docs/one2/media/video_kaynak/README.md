# ONE 2.0 özet videosu — kaynak

`../one2_ozet.mp4`: 1080×1080, 30 fps, 47 sn. Kare kare canvas'ta çizilir,
ffmpeg ile H.264'e kodlanır. Renkler `design-system/tokens.json` (gece teması).

Sahneler: açılış · ne yapıyoruz · Faz 0 · veri (`one 3`) · Faz 1 ilk 10 iş ·
arka plan motorları E1–E14 · seri ve rozet · kapanış.

## Yeniden üretmek

1. Fontlar: `npm pack @fontsource/plus-jakarta-sans @fontsource/ibm-plex-mono`,
   paketleri açıp bu klasörde `fonts/` altına koy; ağırlık CSS'lerini
   (`400`–`800`, mono `400`–`600`) `url(fonts/<paket>/files/…)` yoluyla
   birleştirip `fonts.css` olarak kaydet.
2. `python3 -m http.server 8765` (bu klasörde).
3. `NODE_PATH=$(npm root -g) node render.js http://localhost:8765/index.html out.mp4 <ffmpeg>`
   Tek kare önizleme: son argümana saniye listesi ver (`… prev x 2,8.5,13`).

Metin ve sayılar değişince (`ADR-001.md` durum satırı, motor listesi) sahneleri güncelle.
