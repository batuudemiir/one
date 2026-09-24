//
//  ONEConfig.swift
//  one
//
//  Uygulama sabitleri — App Store kimliği, varsayılanlar, UserDefaults
//  anahtarları.
//
//  Bunlar `ONETokens` içinde duruyordu. Orada yanlış yerdeydiler: bir
//  tasarım token dosyası "hangi renk, hangi boşluk" sorusunun tek cevabı
//  olmalı. App Store ID'si ya da tercih anahtarı bir tasarım kararı değil
//  ve o dosyayı okuyan kimse orada bunları aramıyordu — token dosyasını
//  emekliye ayırmayı da zorlaştırıyorlardı.
//

import Foundation

enum ONEConfig {

    // MARK: - App Store

    static let appStoreID  = "6759794739"
    static let appStoreURL = "https://apps.apple.com/us/app/one/id6759794739"

    // MARK: - Varsayılanlar

    static let defaultCity = "İstanbul"

    // MARK: - UserDefaults anahtarları
    //
    // String literal olarak tanımlılar çünkü **kalıcı sözleşme**: değeri
    // değiştirmek kullanıcının kayıtlı tercihini kaybettirir.

    static let cityPreferenceKey     = "preferredCity"
    static let languagePreferenceKey = "appLanguage"
}
