//
//  PrimaryTab.swift
//  one
//
//  Sekme çubuğunun tek kaynağı.
//
//  Daha önce sekme sırası üç ayrı yerde kopyalanıyordu (ONEColorPickerView.primaryTabs,
//  liquidGlassTabView'ın Tab bildirimleri, BottomNavigation.tabs). Üçü sessizce
//  ayrışabiliyordu. Artık hepsi buradan okuyor.
//
//  Bugün (ritüel) bilerek burada yok: o bir yer değil, bir eylem — ortadaki
//  "+" butonu. Keşfet de burada değil; Frekans başlığından giriliyor.
//

import SwiftUI

enum PrimaryTab: CaseIterable {
    case circle    // Frekans — sosyal katman, açılış ekranı
    case archive   // Arşiv — renk mozaiği
    case echo      // Yankı — içgörü
    case profile   // Profil

    var screen: ScreenType {
        switch self {
        case .circle:  return .circle
        case .archive: return .archive
        case .echo:    return .echo
        case .profile: return .profile
        }
    }

    var title: String {
        switch self {
        case .circle:  return NSLocalizedString("nav.circle",  comment: "")
        case .archive: return NSLocalizedString("nav.archive", comment: "")
        case .echo:    return NSLocalizedString("nav.echo",    comment: "")
        case .profile: return NSLocalizedString("nav.profile", comment: "")
        }
    }

    /// Prototipteki glif: ◎ frekans · ▦ arşiv · ◠ yankı · ◍ profil.
    ///
    /// SF Symbols kullanılmıyor — denenen karşılıklar
    /// (`dot.radiowaves.left.and.right`, `waveform`, `person.crop.circle`)
    /// prototipin soyut geometrisi yerine wifi dalgası, ses çubuğu ve
    /// insan silüeti çiziyordu. Glifler `TabGlyphView` ile çiziliyor.
    var glyph: TabGlyph {
        switch self {
        case .circle:  return .frequency
        case .archive: return .archive
        case .echo:    return .echo
        case .profile: return .profile
        }
    }

    /// Native `TabView`'ın `Tab(systemImage:)` API'si bir sembol adı zorunlu
    /// kılıyor. O çubuk gizli (yerine `BottomNavigation` çiziliyor), yani bu
    /// semboller **hiç görünmüyor** — sadece derleyiciyi memnun ediyorlar.
    /// Görünen simgeler için `glyph`'e bak.
    var nativeTabSymbol: String {
        switch self {
        case .circle:  return "circle.circle"
        case .archive: return "square.grid.3x3"
        case .echo:    return "waveform"
        case .profile: return "person.circle"
        }
    }

    static var screens: [ScreenType] { allCases.map(\.screen) }
}
