//
//  RecommendationCardView.swift
//  one
//
//  UI component for displaying a single song recommendation
//

import SwiftUI

struct RecommendationCardView: View {
    let recommendation: SongRecommendation
    let onTap: () -> Void
    var onDismiss: (() -> Void)? = nil
    
    @ObservedObject private var savedManager = SavedItemManager.shared
    
    var body: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Album artwork
                Group {
                    if let url = recommendation.coverURL {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            SerenitySkeleton()
                        }
                    } else {
                        ZStack {
                            ONETokens.oneSilver
                            Image(systemName: "music.note")
                                .font(.system(size: 24))
                                .foregroundColor(ONETokens.oneCreamLow)
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ONETokens.oneInk.opacity(0.05), lineWidth: 1)
                )
                
                // Song info
                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.name)
                        .bodyXS()
                        .fontWeight(.semibold)
                        .foregroundColor(ONETokens.oneShadow)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)

                    Text(recommendation.artist)
                        .monoSM(tracking: 0.4)
                        .foregroundColor(ONETokens.oneAsh)
                        .lineLimit(1)

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(RecommendationCardButtonStyle())
        .contextMenu {
            Button {
                ONEHaptics.feelingSelected()
                if savedManager.isSongSaved(recommendation.id) {
                    savedManager.removeSong(recommendation.id)
                } else {
                    savedManager.saveSong(recommendation)
                }
            } label: {
                Label(
                    savedManager.isSongSaved(recommendation.id) ? "Kaydedilenlerden Çıkar" : "Sonra Dinle'ye Kaydet",
                    systemImage: savedManager.isSongSaved(recommendation.id) ? "bookmark.fill" : "bookmark"
                )
            }
            
            Button(role: .destructive, action: { onDismiss?() }) {
                Label("İlginç değil", systemImage: "hand.thumbsdown")
            }
        }
    }
}

// MARK: - Button Style

struct RecommendationCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
