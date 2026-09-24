# WeekStrip

Bugün ekranının üstündeki hafta: gün kısaltması + tarih; tamamlanan günlerde tarih yerine tik.

- Tamam: `ink` tik. Bugün: `line-strong` 1px çerçeveli `radius-md` kutu, kalın. Boş kalmış geçmiş gün: `ink-faint` tarih; dokununca "Dün boş kaldı. İstersen şimdi doldurabilirsin." Gelecek: `ink-faint`, dokunulamaz.
- Gün kısaltmaları: Pzt, Sal, Çar, Per, Cum, Cmt, Paz.
- Yatay kaydırınca önceki haftalar; bir güne dokununca Bugün o günü gösterir.

Tüketici sağlar: 7 günün durumu, seçili gün, seçim geri çağrısı.
