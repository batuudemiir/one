# QuoteReflection

Bir söz veya olumlamanın üzerine yazma ekranı; ONE'ın yazma ve kendini geliştirme çekirdeği.

- Sözler'de "Bunun hakkında yaz", Bugün'deki günün sözü ve Keşfet'teki söz koleksiyonlarından açılır.
- Üstte söz künyesi: `raised` kutu, serif italik söz + mono kaynak. Yazarken sabit kalır, kaydırınca küçülür.
- Altında yönlendirici soru (`prompt`): "Bu söz bugün sana ne söylüyor?", "Buna katılıyor musun?", "Bu hafta bunu nasıl uygularsın?" — soru döner, kullanıcı değiştirebilir.
- Gövde `journal`; araç hapı `JournalEditor` ile aynı.
- En altta aynı söze daha önce yazdıysa soluk tek satır: tarih + ilk cümle. Zaman içinde aynı söze verilen cevaplar karşılaştırılabilir; kendini geliştirme burada görünür olur.
- Kaydedilen girdi Yolculuk'ta "Söze yazı" kartı olarak, sözün kısa hali ile görünür.

Tüketici sağlar: söz (metin, kaynak, id), soru, metin, önceki yazılar.
