//
//  CommentsIntroBanner.swift
//  one
//
//  v2.5 — Yorum özelliği ilk açıldığında bir kez gösterilen bilgi şeridi.
//  FriendShareDetailView'da thread'in üstüne koy; `CommentsFeatureFlag.markIntroSeen()`
//  sonrası görünmez olur.
//

import SwiftUI

struct CommentsIntroBanner: View {
    @State private var visible: Bool = !CommentsFeatureFlag.hasSeenIntro

    var body: some View {
        if visible {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yorumlar")
                        .font(.subheadline).fontWeight(.semibold)
                    Text("Emoji yerine 280 karakterlik yorumlar. Saygılı ol — rapor & engelle her yerde.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation { visible = false }
                    CommentsFeatureFlag.markIntroSeen()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
