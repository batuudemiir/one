//
//  ONEIcon.swift
//  one
//
//  Design System — SF Symbol ölçeği.
//
//  Neden var: ONE'ın tipografi ölçeği vardı, **ikon ölçeği yoktu.** 79 ikon
//  çağrısı `.font(.system(size:))` yazıyordu ve aralarında 22 ayrı boyut,
//  6 ayrı ağırlık, 39 ayrı kombinasyon çıkmıştı (9 / 10 / 11 / 12 / 13 / 14 /
//  15 / 16 / 17 / 18 / 20 / 22 / 24 / 26 / 28 / 34 / 38 / 40 / 44 / 48 / 56 / 64).
//
//  Bu, tipografideki kaymanın birebir aynısı ve sebebi de aynı: rol yoksa
//  herkes sayı yazar, sayı yazan herkes kendi sayısını seçer. Satır ikonları
//  ekranlar arasında yan yana görünüyor — biri 13, diğeri 15 olduğunda
//  tek tek fark edilmez, sekme değiştirirken fark edilir.
//
//  **Kapsam: yoğun bant (11–18pt).** Satır ikonu, çip glifi, buton ikonu —
//  yani tekrar eden, karşılaştırılan ikonlar. Boş durum kahraman glifleri
//  (28–64pt) bilinçli olarak dışarıda: her biri tek bir ekrana ait, yan
//  yana görünmüyorlar ve bir ölçeğe zorlanmaları görsel kazanç sağlamıyor.
//
//  Ağırlık çağıranda kalıyor: ikonun ağırlığı yanındaki metnin ağırlığıyla
//  eşleşmeli, tek bir varsayılana indirilemez.
//

import SwiftUI

extension View {

    /// 11pt — mikro glif (rozet içi, sayaç yanı).
    func iconXS(weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: 11, weight: weight))
    }

    /// 13pt — küçük satır ikonu, çip glifi.
    func iconSM(weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: 13, weight: weight))
    }

    /// 15pt — **varsayılan.** Liste satırı, buton ikonu.
    func iconMD(weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: 15, weight: weight))
    }

    /// 18pt — vurgulu ikon, üst çubuk eylemi.
    func iconLG(weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: 18, weight: weight))
    }
}
