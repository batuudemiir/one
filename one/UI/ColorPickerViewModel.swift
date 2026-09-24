//
//  ColorPickerViewModel.swift
//  one
//
//  Kabuğun ekran yönlendiricisi.
//
//  Adı v2'den kalma: bu tip bir zamanlar "renk seç → şarkı ara → onayla →
//  bitti" akışının tamamını taşıyordu (arama, Spotify auth, kayıt, arşiv
//  fetch'leri, seçili mood/şarkı state'i). O akış v3'te `V3EntryContainer`'a
//  taşındı ve eski ekranlar (`ConfirmScreen` / `DoneScreen`) ulaşılamaz hale
//  geldi: `currentScreen` hiçbir yerde `.confirm`'e atanmıyordu, dolayısıyla
//  `.search` ve `.done` de yalnızca o ekranların kendi içinden erişilebiliyordu.
//
//  Geriye tek iş kaldı: hangi sekmedeyiz. `ONEColorPickerView` bunu
//  `TabView(selection:)`'a köprülüyor, deep-link ve SceneStorage restorasyonu
//  da buradan geçiyor.
//
//  Silinenler arasında `loadArchiveData` / `loadPatternData` da vardı: açılışta
//  `.task` içinde senkron Core Data fetch'i yapıyor, sonucu (`archiveData`,
//  `songPatterns`, `currentMonthSongs`, `mostFrequentSong`) hiçbir view
//  okumuyordu. Arşiv kendi verisini `ArchiveStore` üzerinden çekiyor.
//

import SwiftUI
import Combine

/// Kabuğun aktif ekranı. Tek sorumluluk.
final class ColorPickerViewModel: ObservableObject {
    @Published var currentScreen: ScreenType = Experiment.defaultLaunchScreen
}
