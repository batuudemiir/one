//
//  ExternalBrand.swift
//  one
//
//  **ONE'ın paleti değil.** Başka şirketlerin marka renkleri.
//
//  Neden ayrı bir dosya: bu değerler ekranların içinde ham hex olarak
//  duruyordu (`Color(hex: "#1DB954")`) ve oradan bakınca ONE'ın bir rengiyle
//  başkasının rengi arasında hiçbir fark yoktu. İkisi de "ekranda uydurulmuş
//  bir hex" gibi görünüyordu — biri gerçekten öyleyken diğeri sabit bir dış
//  gerçek.
//
//  Buradaki renkler **değiştirilemez**: Spotify'ın yeşili Spotify'ın malı.
//  Tema uyarlaması yok, kontrast ayarı yok, ONE'ın koyu/açık temasıyla
//  ilişkisi yok. Yalnız o servisi *temsil ettikleri* yerde kullanılırlar —
//  logo yanında, paylaş hedefinde. ONE'ın kendi arayüzünde vurgu rengi
//  olarak asla.
//

import SwiftUI

enum ExternalBrand {

    /// Spotify yeşili.
    static let spotify = Color(hex: "#1DB954")

    /// Apple Music kırmızısı.
    static let appleMusic = Color(hex: "#FA243C")

    /// Instagram — tek renkli kullanım (küçük rozet, satır ikonu).
    static let instagram = Color(hex: "#E1306C")

    /// Instagram degradesi — hikaye paylaş hedefi gibi büyük yüzeylerde.
    /// Sıra korunmalı: sarı-turuncu → macenta → mor.
    static let instagramGradient: [Color] = [
        Color(hex: "#F58529"),
        Color(hex: "#DD2A7B"),
        Color(hex: "#8134AF")
    ]
}
