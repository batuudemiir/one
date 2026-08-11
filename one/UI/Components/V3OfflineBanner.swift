//
//  V3OfflineBanner.swift
//  one
//
//  v3 spec: ekranın en üstünde tam-genişlik ink şerit.
//  "BAĞLANTI YOK · ANLARIN CİHAZINDA BEKLİYOR"
//  DM Mono 10pt uppercase, letter-spacing 1.4.
//
//  z-index önemli — sekme çubuğunun (z 12) altında ama içeriğin üstünde
//  kalması için Splash (z 40) ve Toast (z 20) ile çakışmasın.
//  Prototipteki değer: Offline z 19 / Toast z 20 / Splash z 40.
//

import SwiftUI

struct V3OfflineBanner: View {
    /// `true` iken görünür; parent NetworkMonitor'dan bağlar.
    let isVisible: Bool

    var body: some View {
        if isVisible {
            Text("BAĞLANTI YOK · ANLARIN CİHAZINDA BEKLİYOR")
                .font(V3Typography.mono(10, weight: .regular))
                .tracking(1.4)
                .foregroundColor(ONEBrand.bone)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(ONEBrand.ink)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(19)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        V3OfflineBanner(isVisible: true)
        Spacer()
    }
}
