//
//  RecommendationsSection.swift
//  one
//
//  Container view for displaying song recommendations
//

import SwiftUI
import MusicKit

struct RecommendationsSection: View {
    @ObservedObject var engine: RecommendationEngine
    let onSelectSong: (SongRecommendation) -> Void
    
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with refresh button
            HStack {
                Text(NSLocalizedString("discover.ourPicks", comment: ""))
                    .monoBase(tracking: 2.0)
                    .foregroundColor(ONETokens.oneAsh)
                
                Spacer()
                
                if !engine.isLoading && !engine.recommendations.isEmpty {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        
                        isRefreshing = true
                        Task {
                            await engine.refreshRecommendations()
                            await MainActor.run {
                                isRefreshing = false
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .semibold))
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                            Text(NSLocalizedString("discover.refresh", comment: ""))
                                .monoSM(tracking: 0.8)
                        }
                        .foregroundColor(ONETokens.oneCharcoal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(ONETokens.oneSilver)
                        )
                    }
                    .disabled(isRefreshing)
                }
            }
            .padding(.top, 28)
            
            // Content
            if engine.isLoading {
                loadingView
            } else if let error = engine.error {
                errorView(error)
            } else if !engine.recommendations.isEmpty {
                recommendationsGridView
            }
        }
        .onAppear {
            if engine.recommendations.isEmpty && !engine.isLoading {
                Task { await engine.fetchRecommendations() }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ONETokens.oneSilver)
                        .aspectRatio(1, contentMode: .fit)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ONETokens.oneSilver)
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ONETokens.oneSilver)
                            .frame(height: 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 30)
                    }
                }
            }
        }
    }
    
    // MARK: - Recommendations Grid View
    
    private var recommendationsGridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 16) {
            ForEach(engine.recommendations) { recommendation in
                RecommendationCardView(
                    recommendation: recommendation,
                    onTap: {
                        AppAnalytics.shared.track(.recommendationTapped(source: recommendation.source == .spotify ? "spotify" : "apple"))
                        onSelectSong(recommendation)
                    }
                )
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: RecommendationError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                OneMascotView(pose: .error, size: 40)

                Text(errorMessage(for: error))
                    .font(.custom("GeistMono-Regular", size: 11))
                    .foregroundColor(ONETokens.oneCharcoal)
                    .lineLimit(3)
            }
            
            #if DEBUG
            if case .spotifyAPIError(let message) = error {
                Text("Debug: \(message)")
                    .font(.custom("GeistMono-Regular", size: 9))
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.top, 4)
            }
            #endif
            
            if case .notAuthenticated = error {
                HStack(spacing: 8) {
                    // Apple Music login button
                    Button(action: {
                        Task {
                            _ = await MusicAuthorization.request()
                            await engine.fetchRecommendations()
                        }
                    }) {
                        Text("Apple Music")
                            .font(.custom("GeistMono-Regular", size: 10))
                            .tracking(0.6)
                            .foregroundColor(ONETokens.oneCream)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(ONETokens.appleMusicRed)
                            )
                    }
                }
                .padding(.top, 4)
            } else if case .networkError = error {
                Button(action: {
                    Task {
                        await engine.fetchRecommendations()
                    }
                }) {
                    Text(NSLocalizedString("general.retry", comment: ""))
                        .font(.custom("GeistMono-Regular", size: 10))
                        .tracking(0.6)
                        .foregroundColor(ONETokens.oneCharcoal)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .stroke(ONETokens.oneCreamMid, lineWidth: 1)
                        )
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Error Helpers

    private func errorMessage(for error: RecommendationError) -> String {
        switch error {
        case .notAuthenticated:
            return NSLocalizedString("discover.notAuthenticated", comment: "")
        case .insufficientHistory:
            return NSLocalizedString("discover.insufficientHistory", comment: "")
        case .networkError:
            return NSLocalizedString("discover.noInternet", comment: "")
        case .spotifyAPIError(let message):
            if message.contains("Rate limit") {
                return NSLocalizedString("discover.rateLimit", comment: "")
            }
            return NSLocalizedString("discover.loadFailed", comment: "")
        case .cacheError:
            return NSLocalizedString("discover.cacheError", comment: "")
        }
    }
}
