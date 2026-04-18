# ONE: Hisset. Kesfet. Paylas. 

ONE, kullanicinin bugunku sarkisini, mood'unu ve fotografini kaydettigi; arsivine donup baktigi; cevresindeki arkadaslarinin bugunku paylasimlarini gordugu sosyal bir muzik uygulamasidir.

## Urun Vaatleri

- `Hisset` — bugunun sarkisini sec, mood'unu ve kisa notunu birak
- `Kesfet` — mood'una gore etkinlik onerileri ve yeni muzik akislarini gor
- `Paylas` — fotografini, sarkini ve bugunku halini cevrende paylas

## Cekirdek Deneyim

1. Kullanici bugunun sarkisini secer
2. Mood ve feeling secimini yapar
3. Isterse fotograf ve not ekler
4. Mood'una gore etkinlik onerileri gorur
5. Kaydini cevrede paylasir
6. Gecmisteki gunlerine Arsiv'den, kendi istatistiklerine Yanki'dan bakar

## Ekranlar

- `Bugun` — sarki secimi, mood secimi, fotograf ekleme, etkinlik kesfi
- `Cevre` — arkadaslarin bugunku mood, sarki ve fotograf paylasimlari
- `Arsiv` — kullanicinin kendi gunluk birikimi
- `Yanki` — tekrar eden sarkilar, mood egilimleri, cevre eslesmeleri, aylik ozetler
- `Profil` — hesap, sehir tercihi, baglantilar ve ayarlar

## Ozellikler

- Apple Music ve Spotify entegrasyonu
- gunde bir sarki kaydi
- mood ve feeling sistemi
- fotografli gunluk kayit
- Circle/Cevre ile arkadas ekleme ve gunluk paylasim
- mood bazli etkinlik onerileri
- aylik ozet ve paylasim kartlari
- Core Data tabanli arsiv
- CloudKit tabanli sosyal veri akisi

## Teknik Yapi

- `Platform`: iOS 16+
- `UI`: SwiftUI
- `Mimari`: MVVM
- `Veri`: Core Data
- `Bulut`: CloudKit
- `Muzik`: MusicKit + Spotify Web API

## Marka Dili

ONE artik sessiz bir muzik gunlugu degil; sosyal, gunluk ve paylasilabilir bir muzik-mood platformudur.

- slogan: `Hisset. Kesfet. Paylas.`
- ton: sicak, guncel, davetkar
- odak: bugun, bag kurma, kendini ifade etme
- urun hissi: muzik + mood + fotograf + cevre

## Gelistirme Oncelikleri

- Today akisini sosyal marka diliyle guclendirmek
- mood sonrasi etkinlik kesfini one cikarmak
- Cevre ekranini canli bir gunluk feed'e donusturmek
- Yanki ekranini kisisel istatistik merkezi olarak buyutmek
- davet ve paylasim kartlarini organik buyume kanali yapmak

## Build

```bash
xcodebuild -project one/ones.xcodeproj -scheme one -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Test

```bash
xcodebuild test -project one/ones.xcodeproj -scheme one -destination 'platform=iOS Simulator,name=iPhone 16'
```
