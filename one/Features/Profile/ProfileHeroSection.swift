//
//  ProfileHeroSection.swift
//  one
//
//  Feature: ui-consistency-and-accessibility-sweep (Task 3.3)
//
//  BeReal-style stretchy profile hero extracted from `ProfileDashboardView`.
//  Contains the full-bleed photo/gradient background, scrim overlay, display
//  name + @username labels, and the fallback gradient used when no profile
//  photo is set. Behavior is preserved byte-for-byte from the pre-decomposition
//  implementation so the extraction is visually neutral (Req 4.4, Req 4.5).
//

import SwiftUI

/// Full-bleed hero section at the top of the profile dashboard.
///
/// Hosts the profile photo (or a mood-aware fallback gradient) with a stretchy
/// pull-down behavior matching BeReal-style headers. The display name and
/// @username are laid out over a bottom scrim so they remain readable over
/// any photograph.
struct ProfileHeroSection: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.profilePalette) private var palette

    /// Week of recent mood colors (nil = no entry that day). Used by the
    /// fallback gradient to blend today's mood color into the avatar
    /// placeholder.
    let recentMoodColors: [Color?]

    // Avatar initial glyph size — token kullanılmaz (metin değil glyph),
    // Dynamic Type ile ölçeklenir (design.md Component 2a).
    @ScaledMetric(relativeTo: .largeTitle) private var avatarInitialSizeLarge: CGFloat = 96

    private var profileColor: Color { Color(hex: vm.selectedAvatarColor) }

    var body: some View {
        GeometryReader { proxy in
            let baseHeight: CGFloat = 420
            let minY = proxy.frame(in: .global).minY
            // Pull-down stretch
            let extra = max(0, minY)
            let stretchedHeight = baseHeight + extra

            ZStack(alignment: .bottomLeading) {
                // Arka plan: foto veya gradient
                if let img = vm.profileImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: stretchedHeight)
                        .clipped()
                } else {
                    heroFallbackGradient
                        .frame(width: proxy.size.width, height: stretchedHeight)
                }

                // Alt scrim — isim okunabilir kalsın
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
                VStack(alignment: .leading, spacing: 4) {
                    // Dynamic Type: 2 satır'a sar, font küçültme kullanma (Req 5.1-5.8,
                    // design.md Component 6). Accessibility sizes'ta tail ellipsis.
                    Text(vm.displayName.isEmpty ? " " : vm.displayName)
                        .displayLG()
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .allowsTightening(false)
                        .minimumScaleFactor(1.0)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)

                    if !vm.username.isEmpty {
                        Text("@\(vm.username)")
                            .bodyXSMedium()
                            .tracking(0.2)
                            .foregroundColor(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.30), radius: 6, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
            .frame(width: proxy.size.width, height: stretchedHeight)
            // Üst köşeler düz (ekran kenarına yapışık), alt köşeler yuvarlak
            .clipShape(
                UnevenRoundedRectangle(cornerRadii: .init(
                    topLeading: 0,
                    bottomLeading: 28,
                    bottomTrailing: 28,
                    topTrailing: 0
                ))
            )
            // Pull-down anında üste yapış
            .offset(y: -extra)
            .onTapGesture {
                guard vm.profileImage != nil else { return }
                ONEHaptics.feelingSelected()
                withAnimation(ONEAnimation.tabSwitch) {
                    vm.profilePhotoZoomed = true
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(NSLocalizedString("accessibility.profile.avatar", comment: ""))
            .accessibilityAddTraits(.isImage)
        }
        .frame(height: 420)
    }

    /// Fotoğraf yoksa: profileColor + bugünün mood'u (varsa) birleşen
    /// soft gradient + ortada büyük italik baş harfi.
    private var heroFallbackGradient: some View {
        let initial = String(vm.displayName.prefix(1)).uppercased()
        let recent = recentMoodColors.compactMap { $0 }.last ?? profileColor
        return ZStack {
            LinearGradient(
                colors: [
                    profileColor.opacity(0.92),
                    profileColor.opacity(0.55),
                    recent.opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft blurred orbs — yumuşak doku
            Circle()
                .fill(profileColor.opacity(0.45))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: -90, y: -120)
            Circle()
                .fill(recent.opacity(0.35))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 100, y: 60)

            Text(initial.isEmpty ? "•" : initial)
                .font(Font.system(size: avatarInitialSizeLarge, weight: .semibold, design: .serif))
                .italic()
                .foregroundColor(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
        }
    }
}
