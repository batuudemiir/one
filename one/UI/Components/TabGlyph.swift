//
//  TabGlyph.swift
//  one
//
//  Sekme simgeleri — prototipteki Unicode gliflerin BİREBİR aynısı.
//

import SwiftUI

/// Prototipin sekme glifleri: ◎ ▦ ◠ ◍
///
/// Prototip bu dört karakteri düz metin olarak, sistem fontunda 16pt
/// basıyor (`.tab .gl{font-size:16px}`). Önceki sürümde Canvas ile
/// "benzerlerini" çiziyordum — kullanıcı birebir aynısını istedi. En
/// sadık yol prototiple tıpatıp aynı şeyi yapmak: aynı Unicode karakteri,
/// aynı sistem fontu. iOS'ta SF Pro prototipteki `-apple-system` ile aynı
/// glifleri çizer.
enum TabGlyph {
    case frequency   // ◎  U+25CE bullseye
    case archive     // ▦  U+25A6 square with vertical fill
    case echo        // ◠  U+25E0 upper half circle
    case profile     // ◍  U+25CD circle with vertical fill

    var character: String {
        switch self {
        case .frequency: return "\u{25CE}"   // ◎
        case .archive:   return "\u{25A6}"   // ▦
        case .echo:      return "\u{25E0}"   // ◠
        case .profile:   return "\u{25CD}"   // ◍
        }
    }
}

struct TabGlyphView: View {
    let glyph: TabGlyph
    /// Prototipte 16pt. Seçili sekmede boyut değil renk/ağırlık değişiyor;
    /// bunu çağıran taraf (`NavItem`) yönetiyor.
    var size: CGFloat = 16
    var isSelected: Bool = false

    var body: some View {
        Text(glyph.character)
            .font(.system(size: size, weight: isSelected ? .semibold : .regular))
            .accessibilityHidden(true)
    }
}

extension TabGlyph: Hashable {}
