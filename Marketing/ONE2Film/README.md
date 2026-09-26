# ONE 2.0 tanıtım filmi

30 saniye, 72 BPM, iki kesim: `ONE2_film_16x9.mp4` (site) ve
`ONE2_film_9x16.mp4` (sosyal). Kurgu, müzik ve ses kuralları:
`docs/one2/06_premium_his.md` › "Tanıtım filmi".

## Fikir

Filmi tek bir çizgi taşır. Açılışta wordmark'ın altındaki ufuk yayı, sonra
sırayla sabah ufku, yazı satırı, skor ölçeğinin rayı, sözün altındaki
çizgi, yolculuk yolu, akşam ufku ve en sonda mührün halkası olur. Kesme
yerine bu çizginin biçim değiştirmesi kullanılır. Düz kesme yalnızca açılış
ve kapanışta, vuruşa denk gelir.

| # | Süre | Kare | Cümle |
|---|---|---|---|
| 1 | 0–3.3s | Wordmark ve ufuk yayı | — |
| 2 | 3.3–6.7s | Güneş doğar, niyet yazılır | Sabah niyetini koy. |
| 3 | 6.7–10s | Haftanın teması kartı, cevap yazılır | Her gün bir soru. Cevap senin. |
| 4 | 10–13.3s | Skor 4, "Huzurlu" seçilir | Nasıl olduğunu sen adlandır. |
| 5 | 13.3–16.7s | Söz ve akan ırmak | Bir söz, bir sayfa. |
| 6 | 16.7–21.7s | Aynı soruya Mart ve Eylül cevabı | Aynı soru, farklı zamanlar. |
| 7 | 21.7–27.5s | "Günü kapat", mühür, hafta şeridi; sonra durgunluk | Akşam günü kapat. → Bugün kapandı. |
| 8 | 27.5–30s | Wordmark | App Store'da |

- Renkler yalnız token'lardan (`design-system/tokens.json`, gece teması).
  `brand` bir karede en fazla bir yerde: imleç, tırnak ya da mühür.
  `sabah` ve `aksam` yalnız güneş ve ay; skor ve duygu renkleri yalnız
  4. karede, veri olarak.
- Tüm hareket tek eğride: `cubic-bezier(0.2, 0.8, 0.2, 1)`. Basış 0.97,
  mühür 0.9 → 1.0 ve 320ms, skor seçiminden sonra 300ms bekleme.
- İçerik ONE'ın kendi içeriği: W39 teması "Yavaşlamak", `quotes.tr.json`
  içindeki Herakleitos sözü.
- Ses: 72 BPM, Re majör, piyano benzeri ton ve pad. Akorlar kesmelerle
  birlikte değişir; mühür anında A7sus4 Re'ye çözülür. Ses efekti üç
  aile: tuş, kâğıt, mühür.

## Ekran filmleri (9:16)

Her ekran için bir film: Bugün, Sözler, Keşfet, Yolculuk ve Eğilimler.
Stil kuralları `STYLE.md` dosyasında, ortak çekirdek `kit/` klasöründe.
Her filmin sahnesi `screens/<ad>.html`, partisyonu `screens/<ad>.score.json`.

| Film | Dosya |
|---|---|
| Bugün | `ONE2_bugun_9x16.mp4` |
| Sözler | `ONE2_sozler_9x16.mp4` |

```bash
cd Marketing/ONE2Film
FF=$(python3 -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())")
node kit/render.js screens/bugun.html 1080 1920 v.mp4 "$FF" events.json
python3 kit/synth.py screens/bugun.score.json events.json audio.wav
"$FF" -y -i v.mp4 -i audio.wav -c:v copy -c:a aac -b:a 192k -shortest ONE2_bugun_9x16.mp4
node kit/render.js screens/bugun.html 1080 1920 --snap 5 9.3 26   # tek tek kare
```

## Yeniden üretmek

Gerekenler: Node 18+, Python 3 + `numpy`, ffmpeg (`imageio-ffmpeg`
paketindeki sürüm de olur).

```bash
cd Marketing/ONE2Film
npm install                      # fontlar ve Playwright
FF=$(python3 -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())")
node render.js 1920 1080 v_16x9.mp4 "$FF"   # events.json da buradan çıkar
node render.js 1080 1920 v_9x16.mp4 "$FF"
python3 synth.py                            # audio.wav
for f in 16x9 9x16; do
  "$FF" -y -i v_$f.mp4 -i audio.wav -c:v copy -c:a aac -b:a 192k -shortest ONE2_film_$f.mp4
done
node snap.js 1920 1080 5.5 12.6 25.5        # tek tek kare kontrolü
```

`film.html` tarayıcıda da açılır: `render(t)` her kareyi zamandan saf
olarak çizer, yani çıktı her seferinde aynıdır.

## Yayından önce

- Müzik sentezlenmiş bir yer tutucudur. Yayın için lisanslı bir parça
  seç: 60–80 BPM, vokalsiz, tek enstrüman öne. Kesmeler 72 BPM'e göre
  kurulu; tempo değişirse `film.html` › `BEAT` ve `synth.py` › `BEAT`
  birlikte güncellenir.
- Uygulama kareleri tasarım sistemi önizlemelerinden türetildi. Gerçek
  ekranlar bittiğinde App Store önizlemesi için ekran kaydıyla yeniden
  kurulur (06_premium_his.md § 6).
- Kopya yalnız Türkçe. Diğer sekiz dil için cümleler çevrilir,
  `headline(...)` metinleri dile göre değiştirilerek render alınır.
