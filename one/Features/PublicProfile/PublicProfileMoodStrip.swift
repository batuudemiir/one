//
//  PublicProfileMoodStrip.swift
//  one
//
//  Son 7 günün mood renk strip'i. Gizlilik ayarına göre placeholder gösterir.
//

import SwiftUI

struct PublicProfileMoodStrip: View {
    /// Son 7 günün hex renkleri, en eskiden en yeniye. nil = giriş yok.
    let colorHexes: [String?]
    let isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Son 7 gün")
                .monoSM(tracking: 1.2)
                .foregroundStyle(ONETokens.oneAsh)

            if isVisible {
                let allNil = colorHexes.allSatisfy { $0 == nil }
                if allNil {
                    noSharesPlaceholder
                } else {
                    moodCells
                }
            } else {
                privacyPlaceholder
            }
        }
    }

    // MARK: - Mood cells

    private var moodCells: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { idx in
                let hexOrNil = idx < colorHexes.count ? colorHexes[idx] : nil
                RoundedRectangle(cornerRadius: 8)
                    .fill(hexOrNil.map { Color(hex: $0) } ?? ONETokens.oneCreamMid)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
        }
    }

    // MARK: - No shares placeholder

    private var noSharesPlaceholder: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon")
                .font(.system(size: 12))
            Text("Henüz paylaşım yok")
                .monoSM(tracking: 0)
        }
        .foregroundStyle(ONETokens.oneAsh)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(ONETokens.oneCreamMid))
    }

    // MARK: - Privacy placeholder

    private var privacyPlaceholder: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock")
                .font(.system(size: 12))
            Text("Mood geçmişi paylaşılmıyor")
                .monoSM(tracking: 0)
        }
        .foregroundStyle(ONETokens.oneAsh)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(ONETokens.oneCreamMid))
    }
}
