//
//  DiscoverPlaceholderView.swift
//  one
//
//  Keşfet sekmesi — placeholder (tam implementasyon gelecek)
//

import SwiftUI

struct DiscoverPlaceholderView: View {
    var body: some View {
        ZStack {
            ONEBrand.bone.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(NSLocalizedString("discover.title", comment: ""))
                        .font(ONETypography.displayLG)
                        .foregroundColor(V3Tokens.ink)
                    Spacer()
                }
                .padding(.top, 56)
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(V3Tokens.mutedText)

                    Text(NSLocalizedString("discover.comingSoon", comment: ""))
                        .font(ONETypography.bodyMD)
                        .foregroundColor(V3Tokens.mutedText)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                Spacer().frame(height: 100)
            }
        }
        .navigationBarHidden(true)
    }
}
