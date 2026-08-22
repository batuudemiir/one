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
    @State private var isCopied = false
    @State private var breathe = false
    @State private var selectedFormat: ShareFormat = .story
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            
            titleRow
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: V3Tokens.spacingXL2) {
                    
                    formatPicker
                        .padding(.horizontal, V3Tokens.spacingXL4)
                        .padding(.top, V3Tokens.spacingSM)
                    
                    // Card preview or loading indicator
                    Group {
                        if isGenerating {
                            loadingView
                        } else if let image = generatedImage {
                            cardPreview(image)
                        }
                    }
                    .frame(height: 400)
                    
                    actionButtons
                        .padding(.top, V3Tokens.spacingMD)
                    
                    shareLinkView
                        .padding(.horizontal, V3Tokens.channel)
                        .padding(.bottom, V3Tokens.spacingXL4)
                }
            }
        }
        .background(V3Tokens.paper.ignoresSafeArea())
        .v3Sheet(detents: [.fraction(0.9), .large])
        .task { await generateCard() }
        .alert(NSLocalizedString("general.error", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("general.ok", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("general.retry", comment: "")) { Task { await generateCard() } }
        } message: {
            Text(errorMessage ?? NSLocalizedString("general.error", comment: ""))
        }
        .onChange(of: selectedFormat) { _, _ in
            Task { await generateCard() }
        }
    }
    
    // MARK: - Subviews
    
    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: V3Tokens.radiusMicro)
            .fill(V3Tokens.faintText)
            .frame(width: 36, height: 4)
            .padding(.top, V3Tokens.spacingMD)
            .padding(.bottom, 14)
    }
    
    private var titleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
                Text(NSLocalizedString("invite.sendInvite", comment: "Profili Paylaş"))
                    // Sheet başlığı — Archivo. Kardeş sheet (`V3StoryComposer`)
                    // zaten display çiziyordu; bu ikisi aynı registerda iki
                    // farklı yüzle duruyordu.
                    .displayMD()
                    .foregroundColor(V3Tokens.ink)
                Text(NSLocalizedString("invite.shareSubtitle", comment: "Davet kodun veya link ile seni ekleyebilirler"))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
            }
            Spacer()
            V3TopBarIconButton(
                systemName: "xmark",
                label: NSLocalizedString("general.close", comment: "")
            ) { dismiss() }
        }
        .padding(.horizontal, V3Tokens.channel)
        .padding(.bottom, V3Tokens.spacingLG)
    }
    
    private var formatPicker: some View {
        Picker(NSLocalizedString("invite.formatPicker", comment: ""), selection: $selectedFormat) {
            Text(NSLocalizedString("invite.story", comment: "Hikaye")).tag(ShareFormat.story)
            Text(NSLocalizedString("invite.post", comment: "Gönderi")).tag(ShareFormat.post)
        }
        .pickerStyle(.segmented)
    }
    
    private var loadingView: some View {
        VStack(spacing: V3Tokens.spacingMD) {
            Circle()
                .fill(V3Tokens.ink)
                .frame(width: 8, height: 8)
                .scaleEffect(breathe ? 1.4 : 0.8)
                .opacity(breathe ? 1.0 : 0.4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        breathe = true
                    }
                }
            Text(NSLocalizedString("invite.preparing", comment: "Hazırlanıyor..."))
                .font(V3Typography.mono(13, weight: .medium))
                .foregroundColor(V3Tokens.mutedText)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func cardPreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(selectedFormat == .story ? 9 / 16 : 16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusPanel))
            .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, selectedFormat == .story ? 70 : 20)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
    
    private var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: V3Tokens.spacingXL2) {
                
                let instaInstalled = ShareManager.shared.isInstagramInstalled()
                ShareAppIcon(
                    iconName: "camera.viewfinder",
                    title: "Instagram",
                    color: Color(hex: "#E1306C"),
                    isEnabled: generatedImage != nil && instaInstalled,
                    action: shareToInstagramStory
                )
                
                ShareAppIcon(
                    iconName: "square.and.arrow.up",
                    title: "Diğer",
                    color: V3Tokens.ink,
                    isEnabled: generatedImage != nil,
                    action: shareViaSystem
                )
                
                ShareAppIcon(
                    iconName: "arrow.down",
                    title: "Kaydet",
                    color: V3Tokens.mutedText,
                    isEnabled: generatedImage != nil,
                    action: saveToPhotos
                )
                
                ShareAppIcon(
                    iconName: "link",
                    title: "Kopyala",
                    color: V3Tokens.mutedText,
                    isEnabled: true,
                    action: copyLink
                )
            }
            .padding(.horizontal, 28)
        }
    }
    
    private var shareLinkView: some View {
        HStack {
            Text(inviteLinkURL?.absoluteString ?? "")
                .font(V3Typography.mono(14, weight: .medium))
                .foregroundColor(V3Tokens.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Button(action: copyLink) {
                Text(isCopied ? NSLocalizedString("general.copied", comment: "Kopyalandı") : NSLocalizedString("general.copy", comment: "Kopyala"))
                    .font(V3Typography.sans(13, weight: .bold))
                    .foregroundColor(isCopied ? .white : V3Tokens.ink)
                    .padding(.horizontal, V3Tokens.spacingLG)
                    .padding(.vertical, V3Tokens.spacingSM)
                    .background(RoundedRectangle(cornerRadius: V3Tokens.radiusInner).fill(isCopied ? V3Tokens.success : V3Tokens.hairline.opacity(0.8)))
            }
        }
        .padding(V3Tokens.spacingMD)
        .background(RoundedRectangle(cornerRadius: V3Tokens.radiusCard).fill(V3Tokens.hairline.opacity(0.3)))
    }
    
    // MARK: - Actions
    
    private var inviteLinkURL: URL? {
        // Universal Link for the invitation
        URL(string: "https://one.forvibe.app/invite/\(inviteCode)")
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
            errorMessage = NSLocalizedString("invite.generateFailed", comment: "")
            showError = true
        }
        isGenerating = false
    }
    
    private func shareToInstagramStory() {
        guard let image = generatedImage else { return }
        ONEHaptics.feelingSelected()

        dismiss()

        DispatchQueue.main.async {
            // v2.6 — Attribution sticker: Universal Link path'i ile davet kodu doğrudan açılır.
            let attributionURL = URL(string: "https://one.forvibe.app/invite/\(self.inviteCode)")
            ShareManager.shared.shareToInstagramStories(image: image, contentURL: attributionURL) { result in
                if case .failure(let err) = result {
                    ONELogger.error("Instagram story share failed: \(err.localizedDescription)", category: .share)
                }
            }
        }
    }
    
    private func shareViaSystem() {
        guard let image = generatedImage else { return }
        ONEHaptics.moodSelected()
        
        var items: [Any] = [image]
        let inviteText = String(format: NSLocalizedString("invite.shareText", comment: ""), inviteLinkURL?.absoluteString ?? "")
        items.append(inviteText)
        
        ShareManager.shared.shareViaActivityController(items: items)
    }
    
    private func saveToPhotos() {
        guard let image = generatedImage else { return }
        ONEHaptics.moodSelected()
        ShareManager.shared.saveToPhotoLibrary(image: image) { result in
            switch result {
            case .success:
                ONEHaptics.songSaved()
                withAnimation { isSaved = true }
            case .failure(let err):
                errorMessage = err.localizedDescription
                showError = true
            }
        }
    }
    
    private func copyLink() {
        ONEHaptics.moodSelected()
        UIPasteboard.general.string = inviteLinkURL?.absoluteString ?? ""
        withAnimation { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { isCopied = false }
        }
    }
}

// MARK: - ShareAppIcon

private struct ShareAppIcon: View {
    let iconName: String
    let title: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 60, height: 60)
                    Image(systemName: iconName)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .bodyMicroSemibold()
                    .foregroundColor(V3Tokens.ink)
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
    }
}
