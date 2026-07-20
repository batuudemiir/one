//
//  OnboardingEntryPages.swift
//  one
//
//  Onboarding'in gerçek ilk kaydı aldığı sayfalar: renk → şarkı → onay → davet.
//

import SwiftUI
import MusicKit

// MARK: - Renk seçimi

/// Prototipteki "1 / 3 · ilk kaydın". Ritüeldeki kadran yerine 4 sütunlu
/// grid: onboarding'de amaç keşif değil hız — kullanıcı henüz 12 mood'un
/// ne demek olduğunu bilmiyor, kadranın dairesel keşfi burada yavaşlatır.
struct OnboardingMoodPage: View {
    @Binding var selection: ONEMood?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("onboarding.entry.step1", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(ONETokens.oneStone)

            Text(NSLocalizedString("onboarding.entry.moodTitle", comment: ""))
                .displayMD()
                .foregroundColor(ONETokens.oneInk)
                .padding(.top, 11)

            // Prototipin en önemli cümlesi: bunun bir tur değil, gerçek
            // olduğunu söylüyor. Simülasyonda kullanıcı dikkatini vermiyordu.
            Text(NSLocalizedString("onboarding.entry.realNotDemo", comment: ""))
                .bodyXS()
                .foregroundColor(ONETokens.oneAsh)
                .padding(.top, 7)

            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(ONEMood.allCases, id: \.self) { mood in
                    swatch(mood)
                }
            }
            .padding(.top, ONETokens.spacingXL)
        }
    }

    private func swatch(_ mood: ONEMood) -> some View {
        let isSelected = selection == mood

        return Button {
            ONEHaptics.feelingSelected()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = mood
            }
        } label: {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(mood.color)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .bottom) {
                    Text(mood.label)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.28), radius: 1, y: 1)
                        .padding(.bottom, 5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(ONETokens.oneCream, lineWidth: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(ONETokens.oneInk, lineWidth: 2)
                                    .padding(-2)
                            )
                    }
                }
                .scaleEffect(isSelected ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Şarkı seçimi

/// Prototipteki "2 / 3 · ilk kaydın".
///
/// `SongStepView` burada kullanılamıyor: `TodayCoordinator`'a bağlı ve kendi
/// alt çubuğu seçimi anında commit ediyor — onboarding'in ortak alt barıyla
/// çakışır. Arama yine `TodayViewModel.search(_:)` üzerinden.
struct OnboardingSongPage: View {
    @ObservedObject var vm: TodayViewModel
    @Binding var selection: SongResult?

    @State private var query = ""
    @State private var musicDenied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("onboarding.entry.step2", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(ONETokens.oneStone)

            Text(NSLocalizedString("onboarding.entry.songTitle", comment: ""))
                .displayMD()
                .foregroundColor(ONETokens.oneInk)
                .padding(.top, 11)

            searchField
                .padding(.top, ONETokens.spacingLG)

            if musicDenied {
                Text(NSLocalizedString("onboarding.entry.musicDenied", comment: ""))
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.top, ONETokens.spacingLG)
            } else if vm.isSearching {
                ProgressView()
                    .padding(.top, ONETokens.spacingXL)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 3) {
                    ForEach(vm.searchResults) { song in
                        row(song)
                    }
                }
                .padding(.top, ONETokens.spacingSM)
            }
        }
        .task {
            // Müzik izni burada isteniyor — ayrı bir izin sayfası yerine
            // ihtiyaç anında sormak kabul oranını yükseltir.
            if MusicAuthorization.currentStatus == .notDetermined {
                let status = await MusicAuthorization.request()
                musicDenied = (status != .authorized)
                AppAnalytics.shared.track(
                    .onboardingMusicConnected(granted: status == .authorized)
                )
            } else {
                musicDenied = MusicAuthorization.currentStatus != .authorized
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ONETokens.oneStone)

            TextField(
                NSLocalizedString("onboarding.entry.searchPlaceholder", comment: ""),
                text: $query
            )
            .textFieldStyle(.plain)
            .submitLabel(.search)
            .onChange(of: query) { _, q in vm.search(q) }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ONETokens.oneInk.opacity(0.09), lineWidth: 1)
        )
    }

    private func row(_ song: SongResult) -> some View {
        let isSelected = selection?.id == song.id

        return Button {
            ONEHaptics.feelingSelected()
            selection = song
        } label: {
            HStack(spacing: 12) {
                artwork(song)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: 12))
                        .foregroundColor(ONETokens.oneAsh)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundColor(isSelected ? ONETokens.oneInk : ONETokens.oneSilver)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.95) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func artwork(_ song: SongResult) -> some View {
        if let urlString = song.artworkURLString, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 9).fill(ONETokens.oneSilver)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(ONETokens.oneSilver)
                .frame(width: 44, height: 44)
        }
    }
}

// MARK: - Onay

/// Prototipteki mühür sayfası. Kayıt bu sayfaya GELMEDEN önce yapılmış
/// oluyor — burada kutlanan şey tamamlanmış bir eylem, bir vaat değil.
struct OnboardingConfirmPage: View {
    let mood: ONEMood
    let song: SongResult?

    @State private var sealed = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(mood.color, lineWidth: 1.5)
                        .frame(width: 104, height: 104)
                        .scaleEffect(sealed ? 2.8 : 0.6)
                        .opacity(sealed ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 1.5)
                                .delay(Double(i) * 0.28)
                                .repeatForever(autoreverses: false),
                            value: sealed
                        )
                }

                Circle()
                    .fill(mood.color)
                    .frame(width: 104, height: 104)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .scaleEffect(sealed ? 1 : 0.3)
                    .opacity(sealed ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.6), value: sealed)
            }
            .frame(height: 200)

            (
                Text(NSLocalizedString("onboarding.entry.yourColourToday", comment: ""))
                    .foregroundColor(ONETokens.oneInk)
                + Text(mood.label)
                    .foregroundColor(mood.color)
            )
            .displayLG()
            .multilineTextAlignment(.center)
            .padding(.top, ONETokens.spacingLG)

            Text(NSLocalizedString("today.seeYouTomorrow", comment: ""))
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)
                .padding(.top, 11)

            if let song {
                Text("\(song.name) — \(song.artist)")
                    .bodyXS()
                    .foregroundColor(ONETokens.oneStone)
                    .padding(.top, ONETokens.spacingMD)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            ONEHaptics.saveRitual(mood: mood)
            sealed = true
        }
    }
}

// MARK: - Davet

/// Prototipteki "son adım". Retention verisi bu sayfanın gerekçesi:
/// Solo D30 %0'a karşı Sosyal D30 %20.7 — tek başına kalan kullanıcı gidiyor.
struct OnboardingInvitePage: View {
    /// CloudKit profili henüz hazır değilse paylaşım butonu gizlenir.
    let inviteCode: String?
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("onboarding.entry.lastStep", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(ONETokens.oneStone)

            Text(NSLocalizedString("onboarding.entry.inviteTitle", comment: ""))
                .displayMD()
                .foregroundColor(ONETokens.oneInk)
                .padding(.top, 11)

            Text(NSLocalizedString("onboarding.entry.inviteBody", comment: ""))
                .bodyXS()
                .foregroundColor(ONETokens.oneAsh)
                .padding(.top, 7)

            // İki kesişen halka — "çevre" fikrinin en sade hâli.
            HStack(spacing: -18) {
                Circle().fill(ONEMood.sakin.color.opacity(0.85)).frame(width: 54, height: 54)
                Circle().fill(ONEMood.nostaljik.color.opacity(0.85)).frame(width: 54, height: 54)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ONETokens.spacingXL3)
            .accessibilityHidden(true)

            if inviteCode != nil {
                Button(action: onShare) {
                    Text(NSLocalizedString("onboarding.entry.shareLink", comment: ""))
                        .bodySMMedium()
                        .foregroundColor(ONETokens.oneInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule(style: .continuous)
                                .stroke(ONETokens.oneInk.opacity(0.14), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            } else {
                // Kod yoksa sessizce gizle — "------" göstermek güven kırar.
                Text(NSLocalizedString("onboarding.entry.inviteLater", comment: ""))
                    .bodyXS()
                    .foregroundColor(ONETokens.oneStone)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Marka

/// Prototipin ilk sayfası. Tek iş: ne olduğunu üç kelimeyle söylemek.
/// Eski akıştaki `WelcomePage` + `PromisePage` + `TutorialIntroPage`
/// üçlüsü aynı şeyi üç ekrana yayıyordu.
struct OnboardingBrandPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("one")
                .monoLabel(tracking: 1.3)
                .foregroundColor(ONETokens.oneStone)

            Text(NSLocalizedString("onboarding.entry.brandTitle", comment: ""))
                .displayLG()
                .foregroundColor(ONETokens.oneInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text(NSLocalizedString("onboarding.entry.brandBody", comment: ""))
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, ONETokens.spacingLG)
        }
        .padding(.top, ONETokens.spacingXL4)
    }
}

// MARK: - Hatırlatma

/// Push izni burada İSTENMİYOR — yalnızca niyet toplanıyor. Sistem
/// prompt'u `completeOnboarding()` içinde, kullanıcı "evet" dediyse çıkıyor.
struct OnboardingNotifPage: View {
    @Binding var optIn: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "bell")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(ONETokens.oneAsh)
                .padding(.top, ONETokens.spacingXL4)

            Text(NSLocalizedString("onboarding.entry.notifTitle", comment: ""))
                .displayMD()
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneInk)
                .padding(.top, ONETokens.spacingXL)

            Text(NSLocalizedString("onboarding.entry.notifBody", comment: ""))
                .bodyXS()
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneAsh)
                .padding(.top, 9)
                .padding(.horizontal, ONETokens.spacingXL)
        }
        .frame(maxWidth: .infinity)
        .onAppear { optIn = true }
    }
}
