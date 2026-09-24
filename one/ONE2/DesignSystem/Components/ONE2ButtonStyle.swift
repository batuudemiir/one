//
//  ONE2ButtonStyle.swift
//  ONE 2.0
//
//  Hap butonlar (components/Button.md): renk değil kontrast taşır.
//  - primary: açık hap + koyu metin. Ekran başına bir.
//  - secondary: raised + ink
//  - text: ink-muted, dolgusuz
//  - danger: danger metin, dolgusuz; çağıran onay sheet'i açar
//  - disabled: `.disabled(true)` → raised + ink-faint
//  52pt (kart içinde 48), pill, basışta 0.97; Reduce Motion'da basış yok.
//
//  `ONE2PressStyle`: kendi zeminini çizen kontroller (hap, yuvarlak, chip)
//  için yalnız basış ölçeği.
//

import SwiftUI

struct ONE2ButtonStyle: ButtonStyle {
    enum Kind: Sendable { case primary, secondary, text, danger }
    enum Size: Sendable { case regular, compact }

    var kind: Kind = .primary
    var size: Size = .regular
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, kind: kind, size: size, fullWidth: fullWidth)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        let kind: Kind
        let size: Size
        let fullWidth: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var isFilled: Bool { kind == .primary || kind == .secondary }

        private var background: Color {
            guard isEnabled else { return isFilled ? ONE2Color.raised : .clear }
            switch kind {
            case .primary:       return ONE2Color.primary
            case .secondary:     return ONE2Color.raised
            case .text, .danger: return .clear
            }
        }

        private var foreground: Color {
            guard isEnabled else { return ONE2Color.inkFaint }
            switch kind {
            case .primary:   return ONE2Color.onPrimary
            case .secondary: return ONE2Color.ink
            case .text:      return ONE2Color.inkMuted
            case .danger:    return ONE2Color.danger
            }
        }

        var body: some View {
            configuration.label
                .one2Type(.headline)
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, isFilled ? ONE2Space.s6 : ONE2Space.s2)
                .padding(.vertical, ONE2Space.s3)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(minHeight: size == .regular ? ONE2Size.button : ONE2Size.buttonCompact)
                .background(background, in: Capsule())
                .contentShape(Rectangle())
                .scaleEffect(ONE2Motion.pressScale(isPressed: configuration.isPressed, reduceMotion: reduceMotion))
                .animation(reduceMotion ? nil : ONE2Motion.curve(.press), value: configuration.isPressed)
        }
    }
}

/// Yalnız basış ölçeği; zemini kontrol kendisi çizer.
struct ONE2PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(ONE2Motion.pressScale(isPressed: configuration.isPressed, reduceMotion: reduceMotion))
                .animation(reduceMotion ? nil : ONE2Motion.curve(.press), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == ONE2ButtonStyle {
    static func one2(_ kind: ONE2ButtonStyle.Kind, size: ONE2ButtonStyle.Size = .regular, fullWidth: Bool = false) -> ONE2ButtonStyle {
        ONE2ButtonStyle(kind: kind, size: size, fullWidth: fullWidth)
    }
}

extension ButtonStyle where Self == ONE2PressStyle {
    static var one2Press: ONE2PressStyle { ONE2PressStyle() }
}

#if DEBUG
private struct ButtonStyleSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s3) {
            Button {} label: { Text(verbatim: "Yaz").contentShape(Rectangle()) }
                .buttonStyle(.one2(.primary, fullWidth: true))
            Button {} label: { Text(verbatim: "Devam et").contentShape(Rectangle()) }
                .buttonStyle(.one2(.secondary))
            Button {} label: {
                HStack(spacing: ONE2Space.s2) {
                    Text(verbatim: "Başla")
                    ONE2Icon.chevronRight.image(size: ONE2Size.iconSmall)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.one2(.primary, size: .compact))
            Button {} label: { Text(verbatim: "Atla").contentShape(Rectangle()) }
                .buttonStyle(.one2(.text))
            Button {} label: { Text(verbatim: "Sil").contentShape(Rectangle()) }
                .buttonStyle(.one2(.danger))
            Button {} label: { Text(verbatim: "Kaydet").contentShape(Rectangle()) }
                .buttonStyle(.one2(.primary))
                .disabled(true)
        }
    }
}

#Preview("Gece") { ButtonStyleSamples().one2Preview(.gece) }
#Preview("Gün") { ButtonStyleSamples().one2Preview(.gun) }
#Preview("AX3") { ButtonStyleSamples().one2Preview(.ax3) }
#endif
