//
//  DesignSystemGallery.swift
//  ONE 2.0
//
//  Yalnız DEBUG: tüm renk token'ları ve tipografi rolleri. Geliştirici
//  aracı; kullanıcıya görünmez, bu yüzden dizeler yerelleştirilmez
//  (token adları ve tokens.json'daki örnek metinler).
//

#if DEBUG
import SwiftUI

struct DesignSystemGallery: View {

    private static let colorGroups: [(String, [String])] = [
        ("NÖTRLER", ["ground", "surface", "raised", "glass", "line", "line-strong", "ink", "ink-muted", "ink-faint"]),
        ("EYLEM VE VURGU", ["primary", "on-primary", "brand", "brand-soft", "on-brand", "on-brand-soft", "focus"]),
        ("RİTÜEL VE DURUM", ["sabah", "aksam", "success", "warning", "danger"]),
        ("SKOR", (1...5).flatMap { ["score-\($0)", "on-score-\($0)"] }),
        ("DUYGU", ["nese", "huzur", "enerji", "sevgi", "kaygi", "huzun", "ofke", "yorgun"].flatMap { ["emo-\($0)", "on-emo-\($0)"] }),
    ]

    private static let samples: [ONE2Type: String] = [
        .screenTitle: "keşfet", .greeting: "iyi akşamlar", .title: "Pratiklerin",
        .titleSm: "Akşamı yavaşlat", .headline: "Mood check-in", .body: "Günü bir cümleyle kapat.",
        .bodySm: "Güne yavaş başla.", .callout: "Günlük", .caption: "Bugün",
        .prompt: "Bugün seni en çok ne yavaşlattı?", .journal: "Durakta on iki dakika bekledim.",
        .quote: "Acele eden, aynı yolu iki kez yürür.", .affirmation: "Adım adım da varılır.",
        .label: "genel içgörüler", .time: "11:39", .numeralLg: "12",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ONE2Space.sectionGap) {
                Text("tasarım sistemi").one2Type(.screenTitle).foregroundStyle(ONE2Color.ink)

                ForEach(Self.colorGroups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: ONE2Space.s3) {
                        Text(ONE2Type.uppercased(group.0)).one2Type(.label).foregroundStyle(ONE2Color.inkMuted)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: ONE2Space.s3)], spacing: ONE2Space.s3) {
                            ForEach(group.1, id: \.self) { ColorSwatch(name: $0) }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: ONE2Space.s3) {
                    Text(ONE2Type.uppercased("tipografi")).one2Type(.label).foregroundStyle(ONE2Color.inkMuted)
                    ForEach(ONE2Type.allCases, id: \.self) { style in
                        VStack(alignment: .leading, spacing: ONE2Space.s1) {
                            let sample = Self.samples[style] ?? style.rawValue
                            Text(style.spec.uppercase ? ONE2Type.uppercased(sample) : sample)
                                .one2Type(style)
                                .foregroundStyle(style == .affirmation ? ONE2Color.inkMuted : ONE2Color.ink)
                            Text("\(style.rawValue) · \(Int(style.spec.size))/\(Int(style.spec.lineHeight)) · \(style.postScriptName)")
                                .one2Type(.time)
                                .foregroundStyle(ONE2Color.inkFaint)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ONE2Space.s4)
                        .background(ONE2Color.surface, in: ONE2Radius.shape(ONE2Radius.lg))
                    }
                }
            }
            .padding(.horizontal, ONE2Space.gutter)
            .padding(.vertical, ONE2Space.s8)
        }
        .background(ONE2Color.ground.ignoresSafeArea())
    }
}

private struct ColorSwatch: View {
    let name: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s2) {
            ONE2Radius.shape(ONE2Radius.sm)
                .fill(ONE2Color.color(name))
                .frame(height: ONE2Size.control)
                .overlay(ONE2Radius.shape(ONE2Radius.sm).strokeBorder(ONE2Color.line, lineWidth: ONE2Size.hairline))
            Text(name).one2Type(.callout).foregroundStyle(ONE2Color.ink)
            Text(ONE2Palette.hex(name, dark: scheme == .dark, highContrast: contrast == .increased))
                .one2Type(.time)
                .foregroundStyle(ONE2Color.inkFaint)
        }
        .padding(ONE2Space.s3)
        .background(ONE2Color.surface, in: ONE2Radius.shape(ONE2Radius.md))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Gece") {
    DesignSystemGallery().preferredColorScheme(.dark)
}

#Preview("Gün") {
    DesignSystemGallery().preferredColorScheme(.light)
}

#Preview("Gece · AX3") {
    DesignSystemGallery().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#endif
