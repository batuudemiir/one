//
//  StoryCardShareView.swift
//  one
//
//  Instagram Story Cards - Share UI Integration
//

import SwiftUI

// MARK: - Share Button View (Wabi-Sabi Minimalist)

struct StoryCardShareButton: View {
    let dailySong: DailySong
    @State private var isGeneratingCard = false
    @State private var showShareSheet = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var breathe = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main share button - Minimalist design
            Button(action: handleShareTap) {
                HStack(spacing: 8) {
                    if isGeneratingCard {
                        // Breathing dot animation
                        Circle()
                            .fill(ONETokens.oneInk)
                            .frame(width: 6, height: 6)
                            .scaleEffect(breathe ? 1.2 : 0.8)
                            .opacity(breathe ? 1.0 : 0.4)
                    } else {
                        // Minimal arrow icon
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 16, weight: .light))
                    }
                    
                    Text(isGeneratingCard 
                        ? NSLocalizedString("generating", comment: "Hazırlanıyor...") 
                        : NSLocalizedString("share_to_instagram", comment: "Paylaş"))
                        .monoBase(tracking: 0.5)
                }
                .foregroundColor(ONETokens.oneInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(ONETokens.oneInk.opacity(0.2), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ONETokens.oneCream)
                        )
                )
            }
            .disabled(isGeneratingCard)
            .opacity(isGeneratingCard ? 0.6 : 1.0)
            .accessibilityLabel(NSLocalizedString("share_to_instagram", comment: "Instagram'da paylaş"))
            .simultaneousGesture(
                TapGesture().onEnded { _ in
                    // Subtle haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            )
            
            // Save to library button (fallback) - minimal secondary action
            if generatedImage != nil {
                Button(action: handleSaveToLibrary) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12, weight: .light))
                        Text(NSLocalizedString("save_to_library", comment: "Kaydet"))
                            .monoBase(tracking: 0.5)
                    }
                    .foregroundColor(ONETokens.oneAsh)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .alert(NSLocalizedString("general.error", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("general.ok", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("general.retry", comment: "")) {
                handleShareTap()
            }
        } message: {
            Text(errorMessage ?? NSLocalizedString("general.error", comment: ""))
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = generatedImage {
                ShareSheet(image: image)
            }
        }
        .onChange(of: isGeneratingCard) { oldValue, newValue in
            if newValue {
                // Start breathing animation
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            } else {
                breathe = false
            }
        }
    }
    
    private func handleShareTap() {
        isGeneratingCard = true
        errorMessage = nil
        
        Task {
            do {
                let image = try await StoryCardGenerator.shared
                    .generateCardAsync(from: dailySong)
                
                await MainActor.run {
                    generatedImage = image
                    isGeneratingCard = false
                    showShareSheet = true
                    AppAnalytics.shared.track(.storyCardShared(surface: "system_sheet"))
                    BadgeManager.shared.unlock(.firstShare)
                }
                
            } catch {
                await MainActor.run {
                    isGeneratingCard = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func handleSaveToLibrary() {
        guard let image = generatedImage else { return }
        
        ShareManager.shared.saveToPhotoLibrary(image: image) { result in
            switch result {
            case .success:
                // Show success message (could add a toast here)
                ONELogger.debug("Image saved successfully", category: .share)
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - UIKit Share Sheet Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    /// Convenience init for sharing a single image
    init(image: UIImage) {
        self.items = [image]
    }
    
    /// General init for sharing any content
    init(items: [Any]) {
        self.items = items
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return activityVC
    }
    
    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
