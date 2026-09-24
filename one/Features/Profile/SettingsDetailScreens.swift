//
//  SettingsDetailScreens.swift
//  one
//
//  Prototip 30-31 — müzik kaynağı ve gizlilik & hesap.
//

import SwiftUI
import MusicKit

// MARK: - 30 · Müzik kaynağı

/// Hangi servisle arama yapılacağı.
///
/// Prototipin üçüncü seçeneği önemli: **"yalnızca arama — hiçbir hesap
/// bağlama, çalma yok."** Servis bağlamak istemeyen kullanıcıyı kapıda
/// bırakmıyor; ONE'ın çekirdeği (renk + şarkı adı) hesap gerektirmiyor,
/// ekran da bunu bir seçenek olarak söylüyor.
struct MusicSourceSettingsView: View {
    @ObservedObject var vm: ProfileViewModel
    @ObservedObject private var spotify = SpotifyManager.shared
    let onBack: () -> Void

    @AppStorage("preferredMusicService") private var preferred = "AppleMusic"
    /// Prototipteki "çalan şarkıyı öner" anahtarı.

    var body: some View {
        SubScreen(
            title: NSLocalizedString("profile.row.musicSource", comment: ""),
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(NSLocalizedString("music.intro", comment: ""))
                    .bodyXS()
                    .foregroundColor(V3Tokens.mutedText)
                    .fixedSize(horizontal: false, vertical: true)

                SettingsGroup {
                    serviceRow(
                        logo: "music.note",
                        logoColor: ExternalBrand.appleMusic,
                        name: "Apple Music",
                        status: appleMusicStatusText,
                        isActive: preferred == "AppleMusic",
                        action: {
                            AppAnalytics.shared.track(.platformSelected(platform: "apple"))
                            selectAppleMusic()
                        }
                    )
                    serviceRow(
                        logo: "waveform.circle.fill",
                        logoColor: ExternalBrand.spotify,
                        name: "Spotify",
                        status: spotify.isAuthenticated
                            ? NSLocalizedString("music.connected", comment: "")
                            : NSLocalizedString("music.notConnected", comment: ""),
                        isActive: preferred == "Spotify",
                        action: {
                            AppAnalytics.shared.track(.platformSelected(platform: "spotify"))
                            preferred = "Spotify"
                        }
                    )
                    serviceRow(
                        logo: "magnifyingglass",
                        logoColor: V3Tokens.faintText,
                        name: NSLocalizedString("music.searchOnly", comment: ""),
                        status: NSLocalizedString("music.searchOnlySub", comment: ""),
                        isActive: preferred == "SearchOnly",
                        isLast: true,
                        action: {
                            AppAnalytics.shared.track(.platformSelected(platform: "search_only"))
                            preferred = "SearchOnly"
                        }
                    )
                }
                .padding(.top, V3Tokens.spacingLG)

                // "Çalan şarkıyı öner" anahtarı kaldırıldı: hiçbir yer
                // okumuyordu. `SpotifyManager.getNowPlaying` duruyor — özellik
                // gerçekten istenirse önce o bağlanır, anahtar sonra gelir.
            }
        }
    }

    private var appleMusicStatusText: String {
        vm.appleMusicStatus == .authorized
            ? NSLocalizedString("music.connected", comment: "")
            : NSLocalizedString("music.notConnected", comment: "")
    }

    private func selectAppleMusic() {
        preferred = "AppleMusic"
        guard vm.appleMusicStatus != .authorized else { return }
        Task { vm.appleMusicStatus = await MusicAuthorization.request() }
    }

    private func serviceRow(
        logo: String,
        logoColor: Color,
        name: String,
        status: String,
        isActive: Bool,
        isLast: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: V3Tokens.spacingMD) {
                    RoundedRectangle(cornerRadius: V3Tokens.radiusMosaic, style: .continuous)
                        .fill(logoColor)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: logo)
                                .iconMD()
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .bodySMSemibold()
                            .foregroundColor(V3Tokens.ink)
                        Text(status)
                            .bodyMicro()
                            .foregroundColor(V3Tokens.mutedText)
                    }

                    Spacer()

                    // Seçili servis bir onay işaretiyle belli oluyor;
                    // prototipteki "bağla/seç/çıkış" butonları yerine tek
                    // dokunuşla seçim — üç ayrı eylem kelimesi yerine
                    // tutarlı bir liste davranışı.
                    if isActive {
                        Image(systemName: "checkmark")
                            .iconSM(weight: .semibold)
                            .foregroundColor(V3Tokens.ink)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 14)

                if !isLast {
                    Rectangle()
                        .fill(V3Tokens.ink.opacity(0.09))
                        .frame(height: 1)
                        .padding(.leading, 15)
                }
            }
        }
        .buttonStyle(.onePressable)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - 31 · Gizlilik & hesap

/// Gizlilik.
///
/// Prototipin en net duruşu burada: arşiv ve notlar için **ayar yok**.
/// "Yalnızca ben" bir tercih değil, değiştirilemez bir gerçek — ve ekran
/// bunu açıkça yazıyor ("ayarı bile yok"). Kapatılabilir bir gizlilik
/// ayarı, kullanıcıya sürekli "acaba açık mı kaldı" diye düşündürür;
/// olmayan ayar en güçlü güvencedir.
struct PrivacySettingsView: View {
    let onBack: () -> Void

    /// Tercih hem cihazda (anahtarın hâli) hem kayıtta duruyor: arayan başka
    /// bir cihaz, aranan kişinin tercihine ancak `AppUser` kaydından bakabilir.
    /// `onChange` ikisini birlikte yürütüyor.
    @AppStorage("findableByUsername") private var findableByUsername = true

    var body: some View {
        SubScreen(
            title: NSLocalizedString("settings.privacyAccount", comment: ""),
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(NSLocalizedString("privacy.whoCanSee", comment: ""))
                    .monoLabel(tracking: 1.3)
                    .foregroundColor(V3Tokens.faintText)
                    .padding(.bottom, V3Tokens.spacingSM)

                SettingsGroup {
                    SettingsRow(
                        icon: "circle.circle",
                        title: NSLocalizedString("privacy.todayColour", comment: ""),
                        value: NSLocalizedString("privacy.friends", comment: ""),
                        showsChevron: false
                    )
                    SettingsRow(
                        icon: "music.note",
                        title: NSLocalizedString("privacy.todaySong", comment: ""),
                        value: NSLocalizedString("privacy.friends", comment: ""),
                        showsChevron: false
                    )
                    SettingsRow(
                        icon: "square.grid.3x3",
                        title: NSLocalizedString("privacy.archive", comment: ""),
                        value: NSLocalizedString("privacy.onlyMe", comment: ""),
                        showsChevron: false
                    )
                    SettingsRow(
                        icon: "pencil",
                        title: NSLocalizedString("privacy.notes", comment: ""),
                        value: NSLocalizedString("privacy.onlyMe", comment: ""),
                        showsChevron: false,
                        isLast: true
                    )
                }

                Text(NSLocalizedString("privacy.neverShared", comment: ""))
                    .bodyXS()
                    .foregroundColor(V3Tokens.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, V3Tokens.spacingMD)

                Text(NSLocalizedString("privacy.discoverability", comment: ""))
                    .monoLabel(tracking: 1.3)
                    .foregroundColor(V3Tokens.faintText)
                    .padding(.top, V3Tokens.spacingXL)
                    .padding(.bottom, V3Tokens.spacingSM)

                // "Rehberimdekiler beni bulsun" anahtarı kaldırıldı: rehberle
                // eşleştirme diye bir özellik yok (ContactsInviteView yalnız
                // davet mesajı gönderiyor, sunucuda numara eşleştirme yapmıyor).
                // Hiçbir şeyi açıp kapatmayan bir gizlilik anahtarı, gizliliğin
                // kendisinden daha kötü — CLAUDE.md › Sahte kontrol.
                SettingsGroup {
                    SettingsToggleRow(
                        title: NSLocalizedString("privacy.byUsername", comment: ""),
                        subtitle: NSLocalizedString("privacy.byUsernameSub", comment: ""),
                        isOn: $findableByUsername,
                        isLast: true
                    )
                }
                .onChange(of: findableByUsername) { _, newValue in
                    CloudKitManager.shared.updateFindability(byUsername: newValue)
                }
            }
        }
    }
}
