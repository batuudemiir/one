//
//  ONE2Type.swift
//  ONE 2.0
//
//  Tipografi rolleri (tokens.json › type.groups). Üç yüz:
//  - Plus Jakarta Sans: arayüz ve başlıklar
//  - Literata: yalnız yazının kendisi (soru, kullanıcı metni, söz, yankı)
//  - IBM Plex Mono: saat, geniş aralıklı etiket, büyük sayı
//
//  Dynamic Type `UIFontMetrics` ile. 24pt üstü stiller (screenTitle, greeting,
//  quote, affirmation, numeralLg) en fazla ×1.25 büyür; ekranı dolduran
//  başlıkların altındaki kontrolleri ekran dışına itmesin diye. Diğerleri
//  serbest. Ölçek görünümün `dynamicTypeSize` ortamından okunur, yani
//  önizlemedeki `.dynamicTypeSize(.accessibility3)` gerçekten işler.
//
//  Kullanım: `Text("…").one2Type(.body)`. `label` büyük harftir; metni
//  `ONE2Type.uppercased(_:)` ile Türkçe kurala göre büyüt ("İÇGÖRÜLER").
//

import SwiftUI
import UIKit

enum ONE2Type: String, CaseIterable, Sendable {
    // Başlık
    case screenTitle, greeting, title, titleSm
    // Arayüz
    case headline, body, bodySm, callout, caption
    // Yazı
    case prompt, journal, quote, affirmation
    // Veri
    case label, time, numeralLg

    enum Family: Sendable { case sans, serif, mono }

    struct Spec: Sendable {
        let family: Family
        let size: CGFloat
        let lineHeight: CGFloat
        let weight: Int
        /// em cinsinden (tokens.json `letterSpacing`).
        let tracking: CGFloat
        let italic: Bool
        let uppercase: Bool
        let tabularDigits: Bool
        let textStyle: UIFont.TextStyle
    }

    var spec: Spec {
        switch self {
        case .screenTitle: return Spec(family: .sans, size: 44, lineHeight: 48, weight: 700, tracking: -0.025, italic: false, uppercase: false, tabularDigits: false, textStyle: .largeTitle)
        case .greeting:    return Spec(family: .sans, size: 28, lineHeight: 34, weight: 700, tracking: -0.02, italic: false, uppercase: false, tabularDigits: false, textStyle: .title1)
        case .title:       return Spec(family: .sans, size: 24, lineHeight: 30, weight: 700, tracking: -0.01, italic: false, uppercase: false, tabularDigits: false, textStyle: .title2)
        case .titleSm:     return Spec(family: .sans, size: 20, lineHeight: 26, weight: 700, tracking: 0, italic: false, uppercase: false, tabularDigits: false, textStyle: .title3)
        case .headline:    return Spec(family: .sans, size: 17, lineHeight: 24, weight: 600, tracking: 0, italic: false, uppercase: false, tabularDigits: false, textStyle: .headline)
        case .body:        return Spec(family: .sans, size: 16, lineHeight: 24, weight: 500, tracking: 0, italic: false, uppercase: false, tabularDigits: false, textStyle: .body)
        case .bodySm:      return Spec(family: .sans, size: 15, lineHeight: 22, weight: 500, tracking: 0, italic: false, uppercase: false, tabularDigits: false, textStyle: .subheadline)
        case .callout:     return Spec(family: .sans, size: 14, lineHeight: 20, weight: 600, tracking: 0, italic: false, uppercase: false, tabularDigits: false, textStyle: .callout)
        case .caption:     return Spec(family: .sans, size: 12, lineHeight: 16, weight: 600, tracking: 0, italic: false, uppercase: false, tabularDigits: false, textStyle: .caption1)
        case .prompt:      return Spec(family: .serif, size: 22, lineHeight: 30, weight: 400, tracking: 0, italic: false, uppercase: false, tabularDigits: false, textStyle: .title3)
        case .journal:     return Spec(family: .serif, size: 18, lineHeight: 29, weight: 400, tracking: 0, italic: false, uppercase: false, tabularDigits: false, textStyle: .body)
        case .quote:       return Spec(family: .serif, size: 28, lineHeight: 36, weight: 400, tracking: 0, italic: false, uppercase: false, tabularDigits: false, textStyle: .title1)
        case .affirmation: return Spec(family: .serif, size: 26, lineHeight: 34, weight: 400, tracking: 0, italic: true, uppercase: false, tabularDigits: false, textStyle: .title2)
        case .label:       return Spec(family: .mono, size: 11, lineHeight: 14, weight: 500, tracking: 0.2, italic: false, uppercase: true, tabularDigits: false, textStyle: .caption2)
        case .time:        return Spec(family: .mono, size: 14, lineHeight: 18, weight: 500, tracking: 0.08, italic: false, uppercase: false, tabularDigits: true, textStyle: .footnote)
        case .numeralLg:   return Spec(family: .mono, size: 28, lineHeight: 32, weight: 500, tracking: 0, italic: false, uppercase: false, tabularDigits: true, textStyle: .title1)
        }
    }

    /// 24pt üstü stillerin Dynamic Type tavanı.
    static let largeStyleMaxScale: CGFloat = 1.25
    static let largeStyleThreshold: CGFloat = 24

    var maximumPointSize: CGFloat? {
        spec.size > Self.largeStyleThreshold ? spec.size * Self.largeStyleMaxScale : nil
    }

    // MARK: - Yüzler

    /// Bundle'daki PostScript adı (one/ONE2/Resources/Fonts, Info.plist UIAppFonts).
    var postScriptName: String {
        let s = spec
        switch s.family {
        case .sans:
            switch s.weight {
            case ..<600: return "PlusJakartaSans-Medium"
            case 600:    return "PlusJakartaSans-SemiBold"
            default:     return "PlusJakartaSans-Bold"
            }
        case .serif:
            return s.italic ? "Literata-Italic" : "Literata-Regular"
        case .mono:
            return s.weight >= 500 ? "IBMPlexMono-Medium" : "IBMPlexMono-Regular"
        }
    }

    private var fallbackFont: UIFont {
        let s = spec
        let weight: UIFont.Weight = s.weight >= 700 ? .bold : s.weight >= 600 ? .semibold : s.weight >= 500 ? .medium : .regular
        let base: UIFont
        switch s.family {
        case .sans:  base = .systemFont(ofSize: s.size, weight: weight)
        case .mono:  base = .monospacedSystemFont(ofSize: s.size, weight: weight)
        case .serif:
            let d = UIFont.systemFont(ofSize: s.size, weight: weight).fontDescriptor
            base = UIFont(descriptor: d.withDesign(.serif) ?? d, size: s.size)
        }
        guard s.italic, let d = base.fontDescriptor.withSymbolicTraits(.traitItalic) else { return base }
        return UIFont(descriptor: d, size: s.size)
    }

    /// Ölçeklenmemiş taban yüz.
    var baseFont: UIFont {
        var font = UIFont(name: postScriptName, size: spec.size) ?? fallbackFont
        if spec.tabularDigits {
            let d = font.fontDescriptor.addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
                ]]
            ])
            font = UIFont(descriptor: d, size: spec.size)
        }
        return font
    }

    /// Verilen içerik boyutunda ölçeklenmiş yüz (UIKit yüzeyleri de kullanır).
    func uiFont(for category: UIContentSizeCategory) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let metrics = UIFontMetrics(forTextStyle: spec.textStyle)
        if let max = maximumPointSize {
            return metrics.scaledFont(for: baseFont, maximumPointSize: max, compatibleWith: traits)
        }
        return metrics.scaledFont(for: baseFont, compatibleWith: traits)
    }

    /// Ölçeklenmiş satır yüksekliği (tokens.json `lineHeight`, yüzle aynı oranda).
    func lineHeight(for font: UIFont) -> CGFloat {
        spec.lineHeight * font.pointSize / spec.size
    }

    // MARK: - Metin

    /// Türkçe büyük harf: i → İ, ı → I.
    static func uppercased(_ text: String) -> String {
        text.uppercased(with: Locale(identifier: "tr"))
    }
}

// MARK: - SwiftUI

private struct ONE2TypeModifier: ViewModifier {
    let style: ONE2Type
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let font = style.uiFont(for: UIContentSizeCategory(dynamicTypeSize))
        let spacing = max(0, style.lineHeight(for: font) - font.lineHeight)
        content
            .font(Font(font))
            .tracking(style.spec.tracking * font.pointSize)
            .lineSpacing(spacing)
            // Büyük harf dönüşümü `ONE2Type.uppercased` ile metnin kendisinde
            // yapılır; sistem `textCase` Türkçe İ kuralını garanti etmiyor.
            .textCase(nil)
    }
}

extension View {
    /// ONE2 tipografi rolünü uygular: yüz, Dynamic Type, satır aralığı, harf aralığı.
    func one2Type(_ style: ONE2Type) -> some View {
        modifier(ONE2TypeModifier(style: style))
    }
}
