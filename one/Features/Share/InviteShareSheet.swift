//
//  InviteShareSheet.swift
//  one
//
//  Bottom sheet to share the generated InviteShareCard to Instagram Stories, etc.
//

import SwiftUI
import UIKit

struct InviteShareSheet: View {
    let inviteCode: String
    let userName: String
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var generatedImage: UIImage?
    @State private var isGenerating = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isSaved = false
    @State private var breathe = false
    @State private var selectedFormat: ShareFormat = .story
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            
            titleRow
            
            formatPicker
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            
            // Card preview or loading indicator
            Group {
                if isGenerating {
                    loadingView
                } else if let image = generatedImage {
                    cardPreview(image)
                }
            }
            .frame(height: 160)
            
            Spacer(minLength: 12)
            
            actionButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(ONETokens.oneCream.ignoresSafeArea())
        .presentationDetents([.height(560), .large])
        .presentationDragIndicator(.hidden)
        .task { await generateCard() }
        .alert("Hata", isPresented: $showError) {
            Button("Tamam", role: .cancel) {}
            Button("Tekrar Dene") { Task { await generateCard() } }
        } message: {
            Text(errorMessage ?? "Bir hata oluştu")
        }
        .onChange(of: selectedFormat) { _, _ in
            Task { await generateCard() }
        }
    }
    
    // MARK: - Subviews
    
    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(ONETokens.oneStone)
            .frame(width: 36, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 14)
    }
    
    private var titleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ÇEVRENE KATIL")
                    .monoLabel(tracking: 2.0)
                    .foregroundColor(ONETokens.oneAsh)
                Text("Davet Gönder")
                    .displaySM()
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ONETokens.oneAsh)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(ONETokens.oneSilver))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    private var formatPicker: some View {
        Picker("Format Seçimi", selection: $selectedFormat) {
            Text("Hikaye (9:16)").tag(ShareFormat.story)
            Text("Gönderi / X (16:9)").tag(ShareFormat.post)
        }
        .pickerStyle(.segmented)
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(ONETokens.oneInk)
                .frame(width: 8, height: 8)
                .scaleEffect(breathe ? 1.4 : 0.8)
                .opacity(breathe ? 1.0 : 0.4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        breathe = true
                    }
                }
            Text("Davet kartı hazırlanıyor...")
                .monoSM(tracking: 0.5)
                .foregroundColor(ONETokens.oneAsh)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func cardPreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(selectedFormat == .story ? 9 / 16 : 16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 6)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, selectedFormat == .story ? 120 : 60)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
    
    private var actionButtons: some View {
        VStack(spacing: 10) {
            // ── Instagram Story ──────────────────────────────
            let instaInstalled = ShareManager.shared.isInstagramInstalled()
            ActionRow(
                icon: "camera.viewfinder",
                label: "Instagram Story",
                sublabel: instaInstalled ? "Doğrudan Stories'e gönder" : "Instagram yüklü değil",
                style: .filled(ONETokens.oneInk),
                isEnabled: generatedImage != nil && instaInstalled,
                action: shareToInstagramStory
            )
            
            // ── Diğer uygulamalar ────────────────────────────
            ActionRow(
                icon: "square.and.arrow.up",
                label: "Diğer Uygulamalar",
                sublabel: "Davet linki dahil",
                style: .bordered,
                isEnabled: generatedImage != nil,
                action: shareViaSystem
            )
            
            // ── Fotoğraflara kaydet ──────────────────────────
            if isSaved {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ONETokens.oneGreen)
                    Text("Fotoğraflara kaydedildi")
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneGreen)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .transition(.opacity)
            } else {
                ActionRow(
                    icon: "square.and.arrow.down",
                    label: "Fotoğraflara Kaydet",
                    sublabel: "Galeriye PNG olarak ekle",
                    style: .ghost,
                    isEnabled: generatedImage != nil,
                    action: saveToPhotos
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSaved)
    }
    
    // MARK: - Actions
    
    private var inviteLinkURL: URL? {
        // Universal Link for the invitation
        URL(string: "https://onedaily.app/invite?code=\(inviteCode)")
    }
    
    @MainActor
    private func generateCard() async {
        isGenerating = true
        errorMessage = nil
        
        // Brief artificial delay slightly helps the UI feel more responsive when toggling
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let card = InviteShareCard(inviteCode: inviteCode, userName: userName, format: selectedFormat)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        
        if let image = renderer.uiImage {
            withAnimation { generatedImage = image }
        } else {
            errorMessage = "Davet kartı oluşturulamadı"
            showError = true
        }
        isGenerating = false
    }
    
    private func shareToInstagramStory() {
        guard let image = generatedImage else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        dismiss()
        
        DispatchQueue.main.async {
            ShareManager.shared.shareToInstagramStories(image: image) { result in
                if case .failure(let err) = result {
                    ONELogger.error("Instagram story share failed: \(err.localizedDescription)", category: .share)
                }
            }
        }
    }
    
    private func shareViaSystem() {
        guard let image = generatedImage else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        var items: [Any] = [image]
        let inviteText = "ONE'da çevreme katıl. Hisset, keşfet, paylaş.\n\(inviteLinkURL?.absoluteString ?? "")"
        items.append(inviteText)
        
        ShareManager.shared.shareViaActivityController(items: items)
    }
    
    private func saveToPhotos() {
        guard let image = generatedImage else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        ShareManager.shared.saveToPhotoLibrary(image: image) { result in
            switch result {
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation { isSaved = true }
            case .failure(let err):
                errorMessage = err.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - ActionRow

private enum ActionRowStyle {
    case filled(Color)
    case bordered
    case ghost
}

private struct ActionRow: View {
    let icon: String
    let label: String
    let sublabel: String
    let style: ActionRowStyle
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 22)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(labelColor)
                    Text(sublabel)
                        .monoSM(tracking: 0.3)
                        .foregroundColor(labelColor.opacity(0.55))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(labelColor.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(background)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.38)
    }
    
    // MARK: Style helpers
    
    private var labelColor: Color {
        switch style {
        case .filled: return .white
        case .bordered, .ghost: return ONETokens.oneInk
        }
    }
    
    private var iconColor: Color { labelColor }
    
    @ViewBuilder
    private var background: some View {
        switch style {
        case .filled(let color):
            RoundedRectangle(cornerRadius: 14).fill(color)
        case .bordered:
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneStone, lineWidth: 1))
        case .ghost:
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.oneSilver.opacity(0.6))
        }
    }
}
