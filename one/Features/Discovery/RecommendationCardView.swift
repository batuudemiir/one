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
    
    var body: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Album artwork
                Group {
                    if let url = recommendation.coverURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ZStack {
                                ONETokens.oneSilver
                                ProgressView()
                                    .tint(ONETokens.oneMist)
                            }
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

                    if let reason = recommendation.recommendationReason {
                        Text(reason)
                            .monoMicro(tracking: 0.6)
                            .foregroundColor(ONETokens.oneMist)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(ONETokens.oneCream)
                            )
                            .padding(.top, 2)
                    }

                    // Platform attribution (required by Spotify & Apple guidelines)
                    HStack(spacing: 3) {
                        Image(systemName: recommendation.source == .spotify ? "music.note" : "applelogo")
                            .font(.system(size: 8, weight: .medium))
                        Text(recommendation.source == .spotify ? "Spotify" : "Apple Music")
                            .monoLabel()
                    }
                    .foregroundColor(ONETokens.oneMist)
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(RecommendationCardButtonStyle())
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
