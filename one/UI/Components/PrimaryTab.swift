//
//  PrimaryTab.swift
//  one
//
//  Sekme çubuğunun tek kaynağı — v3: An · Arşiv · Çevre · Profil.
//
//  Sekme sırası üç ayrı yerde kopyalanıyordu (ONEColorPickerView.primaryTabs,
//  liquidGlassTabView'ın Tab bildirimleri, BottomNavigation.tabs). Üçü sessizce
//  ayrışabiliyordu. Artık hepsi buradan okuyor.
//
//  v3 değişiklikleri:
//  - `.entry` (An) artık ilk sekme — ritüel eskiden ortadaki "+" idi, şimdi
//    birinci sınıf sekme. Ekran arka planda hâlâ `ScreenType.today`.
//  - `.echo` (Yankı) tabbardan çıktı — Profil > Ayarlar > Aylık özet altında.
//

import SwiftUI

/// `String` rawValue explicitly declared — the SceneStorage restore key
/// (`one.scene.primaryTab`) persists these strings verbatim across launches.
/// A silent case rename would previously break restoration; now the raw
/// strings are the wire contract and a rename must be an explicit choice
/// (change the case name, keep the raw literal).
enum PrimaryTab: String, CaseIterable {
    case entry   = "entry"     // An — kayıt akışı (ScreenType.today)
    case archive = "archive"   // Arşiv — renk mozaiği
    case circle  = "circle"    // Çevre — sosyal katman
    case profile = "profile"   // Profil

    var screen: ScreenType {
        switch self {
        case .entry:   return .today       // An = TodayView
        case .archive: return .archive
        case .circle:  return .circle
        case .profile: return .profile
        }
    }

    /// Alt gezinme çubuğunun etiketi — bilerek küçük harf ("an", "arşiv").
    var title: String {
        switch self {
        case .entry:   return NSLocalizedString("nav.entry",   comment: "")
        case .archive: return NSLocalizedString("nav.archive", comment: "")
        case .circle:  return NSLocalizedString("nav.circle",  comment: "")
        case .profile: return NSLocalizedString("nav.profile", comment: "")
        }
    }

    /// Üst çubuğun taşıdığı **ekran adı** — büyük harfle başlar ("An",
    /// "Arşiv").
    ///
    /// Neden `title`'dan ayrı: alt çubuğun etiketleri 12pt küçük harf, bir
    /// gezinti dili. Üst çubuktaki ad 20pt Archivo bir masthead ve orada
    /// küçük harf bir stil tercihi değil, hata gibi okunuyor. İki kullanım
    /// tek dizeye bağlanınca birini düzeltmek diğerini bozuyordu.
    var screenTitle: String {
        switch self {
        case .entry:   return NSLocalizedString("screen.entry.title",   comment: "")
        case .archive: return NSLocalizedString("screen.archive.title", comment: "")
        case .circle:  return NSLocalizedString("screen.circle.title",  comment: "")
        case .profile: return NSLocalizedString("screen.profile.title", comment: "")
        }
    }

    /// Native `TabView`'ın `Tab(systemImage:)` API'si bir sembol adı zorunlu
    /// kılıyor. O çubuk gizli (yerine `BottomNavigation` çiziliyor), yani bu
    /// semboller **hiç görünmüyor** — sadece derleyiciyi memnun ediyorlar.
    var nativeTabSymbol: String {
        switch self {
        case .entry:   return "circle.dotted"
        case .archive: return "square.grid.3x3"
        case .circle:  return "circle.circle"
        case .profile: return "person.circle"
        }
    }

    static var screens: [ScreenType] { allCases.map(\.screen) }

    /// Hangi sekme bu ekranı barındırıyor?
    ///
    /// Kabuk `TabView(selection:)` kullanıyor ve seçim `PrimaryTab` olmak
    /// zorunda; ama `ColorPickerViewModel.currentScreen` sekme olmayan
    /// değerler de alabiliyor (`.confirm` / `.done` ritüel ekranları,
    /// `.echo` sheet'e taşındı,
    /// `.search` şarkı akışı içi). Kabuk bunların hepsini eskiden
    /// `default: entryTab` ile An sekmesine düşürüyordu — bu fonksiyon o
    /// örtük davranışı tek yerde açık hale getiriyor.
    ///
    /// `.today` / `.confirm` / `.done` eşlemesi `BottomNavigation.isSelected`
    /// ile bilinçli olarak aynı: üçü de An sekmesinin parçası.
    init(containing screen: ScreenType) {
        switch screen {
        case .archive: self = .archive
        case .circle:  self = .circle
        case .profile: self = .profile
        default:       self = .entry
        }
    }
}
