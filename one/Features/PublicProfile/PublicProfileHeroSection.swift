//
//  PublicProfileHeroSection.swift
//  one
//
//  v3.1 — Kendi profil sekmesi (`ProfileHeroSection`) ile aynı dile geçti:
//  full-bleed 420pt foto / mood gradient hero, alt scrim, isim + @username overlay.
//  Avatar fotoğrafı arka planda yüklenir; yoksa avatarColor + dominantMood birleşen
//  yumuşak gradient ve büyük italic baş harfi gösterilir.
//

import SwiftUI

struct PublicProfileHeroSection: View {
    let profile: PublicUserProfile?

    @State private var avatarImage: UIImage? = nil
    @State private var lastLoadedURL: URL? = nil

    /// İlk harf büyütmesi — kendi ProfileHeroSection ile birebir.
    @ScaledMetric(relativeTo: .largeTitle) private var avatarInitialSize: CGFloat = 96

    private var avatarColor: Color {
        Color(hex: profile?.avatarColorHex ?? "#8888CC")
    }

    private var moodColor: Color {
        Color(hex: profile?.dominantMoodColor ?? "#9B7FD4")
    }

    private var initial: String {
        String((profile?.displayName ?? "?").prefix(1)).uppercased()
    }

    var body: some View {
        GeometryReader { proxy in
            let baseHeight: CGFloat = 420
            let minY = proxy.frame(in: .global).minY
            let extra = max(0, minY)
            let stretchedHeight = baseHeight + extra

            ZStack(alignment: .bottomLeading) {
                // Arka plan: foto > gradient
                if let img = avatarImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: stretchedHeight)
                        .clipped()
                } else {
                    fallbackGradient
                        .frame(width: proxy.size.width, height: stretchedHeight)
                }

                // Alt scrim — isim okunaklı kalsın
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.10), location: 0.50),
                        .init(color: .black.opacity(0.65), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: stretchedHeight)
                .allowsHitTesting(false)

                // İsim + @username overlay
                if let p = profile {
                    VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
                        Text(p.displayName)
                            .displayLG()
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .allowsTightening(false)
                            .minimumScaleFactor(1.0)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)

                        if let username = p.username, !username.isEmpty {
                            Text("@\(username)")
                                .bodyXSMedium()
                                .tracking(0.2)
                                .foregroundColor(.white.opacity(0.92))
                                .shadow(color: .black.opacity(0.30), radius: 6, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal, V3Tokens.spacingXL)
                    .padding(.bottom, V3Tokens.spacingXL)
                } else {
                    // Yükleme iskeleti
                    VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
                        RoundedRectangle(cornerRadius: V3Tokens.radiusSwatch)
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 160, height: 24)
                        RoundedRectangle(cornerRadius: V3Tokens.radiusSwatch)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 100, height: 14)
                    }
                    .padding(.horizontal, V3Tokens.spacingXL)
                    .padding(.bottom, V3Tokens.spacingXL)
                }
            }
            .frame(width: proxy.size.width, height: stretchedHeight)
            // Üst köşeler düz (ekran kenarına yapışık), alt köşeler yumuşak
            .clipShape(
                UnevenRoundedRectangle(cornerRadii: .init(
                    topLeading: 0,
                    bottomLeading: 28,
                    bottomTrailing: 28,
                    topTrailing: 0
                ))
            )
            .offset(y: -extra)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(profile?.displayName ?? "")
            .accessibilityAddTraits(.isImage)
        }
        .frame(height: 420)
        .onChange(of: profile?.profilePhotoFileURL) { _, newURL in
            loadAvatarIfNeeded(url: newURL)
        }
        .onAppear {
            loadAvatarIfNeeded(url: profile?.profilePhotoFileURL)
        }
    }

    // MARK: - Fallback gradient

    /// Foto yoksa: avatarColor + dominantMood birleşen soft gradient + büyük italic baş harfi.
    private var fallbackGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    avatarColor.opacity(0.92),
                    avatarColor.opacity(0.55),
                    moodColor.opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Yumuşak blur orb'lar
            Circle()
                .fill(avatarColor.opacity(0.45))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: -90, y: -120)
            Circle()
                .fill(moodColor.opacity(0.35))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 100, y: 60)

            Text(initial)
                .font(.system(size: avatarInitialSize, weight: .semibold, design: .serif))
                .italic()
                .foregroundColor(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
        }
    }

    // MARK: - Avatar loader

    /// Profil fotoğrafını background thread'de yükler ve cache'ler.
    /// View her recompute'ta sync I/O olmasın; aynı URL ikinci kez yüklenmesin.
    private func loadAvatarIfNeeded(url: URL?) {
        guard let url = url else { avatarImage = nil; lastLoadedURL = nil; return }
        guard url != lastLoadedURL else { return }
        lastLoadedURL = url
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data) else { return }
            DispatchQueue.main.async { avatarImage = img }
        }
    }
}
