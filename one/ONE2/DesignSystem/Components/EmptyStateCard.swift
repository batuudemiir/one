//
//  EmptyStateCard.swift
//  ONE 2.0
//
//  Boş durum (components/States.md, `.o-empty-cta`): 1px `line` çerçeveli
//  kart, başlık + tek cümle + tek eylem. Eylem bir buton ya da özel içerik
//  olabilir (Eğilimler'de doğrudan `ScoreScale`).
//

import SwiftUI

struct EmptyStateCard<Action: View>: View {
    let title: String
    let message: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        ONE2OutlineCard(padding: ONE2Space.s6) {
            VStack(spacing: ONE2Space.s2) {
                Text(title)
                    .one2Type(.titleSm)
                    .foregroundStyle(ONE2Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .one2Type(.body)
                    .foregroundStyle(ONE2Color.inkMuted)
                    .padding(.bottom, ONE2Space.s3)
                action()
            }
            .multilineTextAlignment(.center)
        }
    }
}

extension EmptyStateCard where Action == EmptyStateButton {
    /// Tek primary eylemli boş durum.
    init(title: String, message: String, actionTitle: String, action: @escaping () -> Void) {
        self.init(title: title, message: message) {
            EmptyStateButton(title: actionTitle, action: action)
        }
    }
}

struct EmptyStateButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).contentShape(Rectangle())
        }
        .buttonStyle(.one2(.primary, size: .compact))
    }
}

#if DEBUG
private struct EmptyStateSamples: View {
    var body: some View {
        VStack(spacing: ONE2Space.cardGap) {
            EmptyStateCard(title: "İlk sayfa bugün yazılacak", message: "Bir cümleyle başlaman yeter.", actionTitle: "Yaz") {}
            EmptyStateCard(title: "Henüz erken", message: "Birkaç check-in sonra eğilimlerin burada.") {
                HStack(spacing: ONE2Space.s2) {
                    ForEach(ONE2Score.range, id: \.self) { ScoreDisc(score: $0) }
                }
            }
        }
    }
}

#Preview("Gece") { EmptyStateSamples().one2Preview(.gece) }
#Preview("Gün") { EmptyStateSamples().one2Preview(.gun) }
#Preview("AX3") { EmptyStateSamples().one2Preview(.ax3) }
#endif
