//
//  StoryCardView.swift
//  one
//
//  Instagram Story Cards - SwiftUI View Component
//

import SwiftUI

struct StoryCardView: View {
    let viewModel: StoryCardViewModel
    
    var body: some View {
        ZStack {
            // Background: Full-screen cover image
            Image(uiImage: viewModel.coverImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: StoryCardConfiguration.width,
                    height: StoryCardConfiguration.height
                )
                .clipped()
            
            // Bottom overlay section
            VStack {
                Spacer()
                
                ZStack(alignment: .bottom) {
                    // Gradient overlay (dark to clear)
                    LinearGradient(
                        gradient: Gradient(colors: viewModel.gradientColors),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: StoryCardConfiguration.overlayHeight)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 16) {
                        // Mood accent line
                        Rectangle()
                            .fill(viewModel.moodColor)
                            .frame(
                                width: StoryCardConfiguration.accentLineWidth,
                                height: StoryCardConfiguration.accentLineHeight
                            )
                        
                        // Song title
                        Text(viewModel.songTitle)
                            .font(ONETypography.displayXL)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        // Artist name
                        Text(viewModel.artistName)
                            .font(ONETypography.displayLG)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        
                        // User note (if present)
                        if viewModel.hasNote, let note = viewModel.userNote {
                            Text(note)
                                .font(ONETypography.displaySM)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(3)
                                .italic()
                                .padding(.top, 8)
                        }
                        
                        Spacer()
                            .frame(height: 24)
                        
                        // Date
                        Text(viewModel.dateString)
                            .font(ONETypography.displayXS)
                            .foregroundColor(.white.opacity(0.7))
                        
                        // Viral footer — QR + invite code + domain for organic install
                        ShareViralFooter(inviteCode: viewModel.inviteCode, qrPixelSize: 220)
                            .padding(.top, 12)

                        // Watermark
                        HStack {
                            Spacer()
                            Image(uiImage: viewModel.brandWatermark)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: StoryCardConfiguration.watermarkSize)
                                .opacity(StoryCardConfiguration.watermarkOpacity)
                        }
                    }
                    .padding(.horizontal, StoryCardConfiguration.contentPadding)
                    .padding(.bottom, StoryCardConfiguration.bottomSafeZone)
                }
            }
        }
        .frame(
            width: StoryCardConfiguration.width,
            height: StoryCardConfiguration.height
        )
    }
}

// MARK: - Preview

struct StoryCardView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = StoryCardViewModel(
            coverImage: UIImage(systemName: "music.note") ?? UIImage(),
            songTitle: "Test Song",
            artistName: "Test Artist",
            moodColor: ONETokens.oneCreamLow,
            dateString: "1 Ocak 2024",
            brandWatermark: UIImage(systemName: "circle") ?? UIImage(),
            userNote: "This is a test note",
            inviteCode: "ABC123"
        )
        
        StoryCardView(viewModel: viewModel)
            .previewLayout(.fixed(width: 1080, height: 1920))
            .scaleEffect(0.2)
    }
}
