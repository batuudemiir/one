//
//  FlowPreviews.swift
//  ONE 2.0
//
//  Her akışın her adımı: gece, gün ve AX3 (06 › Önizlemeler). Galeri,
//  akışın adımlarını ve kapanışını telefon boyunda alt alta çizer.
//

import SwiftUI

struct FlowStepGallery: View {
    let kind: FlowKind
    var variant: FlowFixtureVariant = .standard

    static let frameSize = CGSize(width: 390, height: 780)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V3Tokens.spacingXL3) {
                // Ek adımlar (sabahta duygular) açılmış hâliyle de çizilir.
                ForEach(FlowFixtures.flow(kind, variant: variant).steps) { step in
                    card(label: step.id) {
                        FlowShellView(model: FlowFixtureModels.model(kind, at: step.id, variant: variant), onDismiss: {})
                    }
                }
                card(label: "\(kind.rawValue).closing") {
                    FlowClosingView(closing: FlowFixtures.flow(kind, variant: variant).closing) { _ in }
                        .oneScreenGround()
                }
            }
            .padding(V3Tokens.spacingLG)
        }
        .background(V3Tokens.wash)
    }

    private func card<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            Text(verbatim: label)
                .monoSM()
                .foregroundColor(V3Tokens.mutedText)
            content()
                .frame(width: Self.frameSize.width, height: Self.frameSize.height)
                .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous))
        }
    }
}

// MARK: - Akış 1: Mood check-in

#Preview("Mood check-in · dark") {
    FlowStepGallery(kind: .moodCheckIn).preferredColorScheme(.dark)
}

#Preview("Mood check-in · light") {
    FlowStepGallery(kind: .moodCheckIn).preferredColorScheme(.light)
}

#Preview("Mood check-in · AX3") {
    FlowStepGallery(kind: .moodCheckIn).dynamicTypeSize(.accessibility3)
}

// MARK: - Akış 2: Günlük check-in

#Preview("Daily · dark") {
    FlowStepGallery(kind: .daily).preferredColorScheme(.dark)
}

#Preview("Daily · light") {
    FlowStepGallery(kind: .daily).preferredColorScheme(.light)
}

#Preview("Daily · AX3") {
    FlowStepGallery(kind: .daily).dynamicTypeSize(.accessibility3)
}
