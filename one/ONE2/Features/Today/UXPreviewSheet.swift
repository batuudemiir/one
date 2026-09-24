//
//  UXPreviewSheet.swift
//  ONE 2.0
//
//  Yalnız geliştirme ve TestFlight (Profil › geliştirici satırları): yeni
//  Bugün ekranı ve dört akış fixture verisiyle, cihazda denemek için.
//  Motor bağlaması (UX-11) gelince kalkar.
//

import SwiftUI

struct UXPreviewSheet: View {
    let onClose: () -> Void

    @State private var presentedFlow: FlowPresentation?

    var body: some View {
        VStack(spacing: 0) {
            V3TopBar(leading: .close(onClose), style: .subScreen,
                     title: NSLocalizedString("one2.debug.uxPreview", comment: "Debug: new Today preview"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: V3Tokens.spacingSM) {
                    ForEach(FlowKind.allCases) { flow in
                        V3OutlineButton(title: RitualCopy.title(flow)) {
                            presentedFlow = FlowPresentation(model: FlowFixtureModels.model(flow))
                        }
                    }
                }
                .oneScreenBody()
                .padding(.vertical, V3Tokens.spacingSM)
            }
            .fixedSize(horizontal: false, vertical: true)
            ONE2TodayView(state: .loaded(TodayFixtures.morningMissed()),
                      actions: TodayActions(flowProvider: { FlowFixtureModels.model($0) }))
        }
        .oneScreenGround()
        .fullScreenCover(item: $presentedFlow) { presentation in
            FlowShellView(model: presentation.model, onDismiss: { presentedFlow = nil })
        }
    }
}
