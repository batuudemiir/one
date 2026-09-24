# CheckInCard

Bugün ekranının kahramanı: check-in yapıldıysa tek cümle + mood hapı; yapılmadıysa skor sorusu.

- `ground` zemin + 1px `line` çerçeve, `radius-lg`, en az 300pt, içerik ortalı.
- Cümle `affirmation` (Literata italik 26/34, `ink-muted`): check-in'e verilen kısa, yargısız yankı.
- Altta mood hapı: `raised` zemin, skor diski (`score-N`, rakamlı) + etiket.
- Check-in yoksa: "Şu an nasılsın?" (`title`) + `ScoreScale`.
- Sabah+akşam modunda iki kart yatay sayfalanır.

Tüketici sağlar: durum, cümle, skor, etiket, dokunma eylemi.
