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

    /// SF Symbol — prototipteki glif karşılıkları.
    /// ◎ frekans dalgası · ▦ mozaik ızgara · ◠ yankı dalgası · ◍ avatar
    var icon: String {
        switch self {
        case .circle:  return "dot.radiowaves.left.and.right"
        case .archive: return "square.grid.3x3.fill"
        case .echo:    return "waveform"
        case .profile: return "person.crop.circle"
        }
    }

    static var screens: [ScreenType] { allCases.map(\.screen) }
}
