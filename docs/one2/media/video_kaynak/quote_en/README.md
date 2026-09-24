# ONE 2.0 — Sözler / Söze yazı (kısa, EN + TR)

`../../one2_quote_reflection_en.mp4` (İngilizce) ve `../../one2_soze_yazi_tr.mp4` (Türkçe):
1080×1920, 30 fps, 19,5 sn. Tek kaynak; dil `?lang=tr` ile seçilir, metinler `STR` tablosunda.
Türkçe günlük akışı videosuyla aynı piksel dil: şehir silueti, akşamdan geceye dönen gökyüzü, koyu telefon.

Akış (`05_ux_promptlari.md` UX-7, `design-system/components/QuoteCard.md`, `QuoteReflection.md`):
Sözler sekmesi (Quotes, "For you") → dikey kaydırmayla söz kartı → "Write about this" →
QuoteReflection (söz künyesi, soru, yazı, "Last time" satırı) → "Done" →
"Your entry is saved." → Journey'de söze yazı kartı → kapanış.

Söz: `quotes.tr.json` `q_000039` (ONE'ın kendi "reflection" metni), İngilizce çevirisi.
Sekme adları `one2.tab.*` İngilizce karşılıklarıyla aynı (Journey).

Üretim: bir üst klasördeki README ile aynı; font Pixelify Sans, port serbest.
Türkçe için adres: `http://localhost:<port>/index.html?lang=tr`.
