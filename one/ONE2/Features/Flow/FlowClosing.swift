//
//  FlowClosing.swift
//  ONE 2.0
//
//  Akış sonu (07 §5.2, §5.5):
//  - Akış 1: mühürsüz yankı; affirmation ortada, 2 sn ya da dokunuşla kapanır.
//  - Diğerleri ve ilk check-in: mühür + yankı; 2,5 sn ya da dokunuşla.
//  - Akşam: sabah maddelerinden işaretlenmeyen varsa "Yarına taşıyayım mı?"
//    `Taşı` / `Bırak`; karar verilene kadar kendiliğinden kapanmaz.
//  VoiceOver açıkken kendiliğinden kapanmaz; `Kapat` görünür.
//

import SwiftUI

struct FlowClosing: View {
    let flow: FlowViewData
    let onCarryOver: (Bool) -> Void
    let onDone: () -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var carryDecided = false

    static let echoSeconds = 2.0
    static let sealSeconds = 2.5

    private var waitsForCarryOver: Bool {
        if case .seal(.dayClosed) = flow.closing { return !flow.carryOver.isEmpty && !carryDecided }
        return false
    }

    private var autoCloses: Bool { !voiceOver && !waitsForCarryOver }

    private var delay: Double {
        if case .echo = flow.closing { return Self.echoSeconds }
        return Self.sealSeconds
    }

    var body: some View {
        VStack(spacing: ONE2Space.s8) {
            Spacer(minLength: 0)
            content
            if waitsForCarryOver { carryOver }
            Spacer(minLength: 0)
            if voiceOver {
                Button(action: onDone) {
                    Text(one2String("one2.action.close")).contentShape(Rectangle())
                }
                .buttonStyle(.one2(.secondary, fullWidth: true))
            }
        }
        .padding(.horizontal, ONE2Space.gutter)
        .padding(.bottom, ONE2Space.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if !waitsForCarryOver { onDone() } }
        .task(id: carryDecided) {
            guard autoCloses else { return }
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            onDone()
        }
    }

    @ViewBuilder private var content: some View {
        switch flow.closing {
        case .echo:
            if let echo = flow.echo {
                Text(echo)
                    .one2Type(.affirmation)
                    .foregroundStyle(ONE2Color.inkMuted)
                    .multilineTextAlignment(.center)
            }
        case .seal(let kind):
            Seal(title: one2String("one2.seal.\(kind.rawValue)"), summary: flow.echo, isHalf: kind.isHalf)
        }
    }

    private var carryOver: some View {
        VStack(spacing: ONE2Space.s4) {
            Text(one2String("one2.flow.carry.question"))
                .one2Type(.headline)
                .foregroundStyle(ONE2Color.ink)
            ForEach(flow.carryOver, id: \.self) { item in
                Text(item)
                    .one2Type(.bodySm)
                    .foregroundStyle(ONE2Color.inkMuted)
            }
            HStack(spacing: ONE2Space.s2) {
                Button {
                    onCarryOver(true)
                    carryDecided = true
                } label: {
                    Text(one2String("one2.flow.carry.carry")).contentShape(Rectangle())
                }
                .buttonStyle(.one2(.secondary, size: .compact))
                Button {
                    onCarryOver(false)
                    carryDecided = true
                } label: {
                    Text(one2String("one2.flow.carry.drop")).contentShape(Rectangle())
                }
                .buttonStyle(.one2(.text, size: .compact))
            }
        }
        .multilineTextAlignment(.center)
    }
}
