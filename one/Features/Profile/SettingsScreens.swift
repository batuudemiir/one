//
//  SettingsScreens.swift
//  one
//
//  Prototip 28-29 — ayarlar ve hatırlatma.
//

import SwiftUI

// MARK: - 28 · Ayarlar

/// Ayarlar kökü.
///
/// Prototipte ayarlar bir liste değil, **gruplanmış bir kart yığını**:
/// hesap üstte, sonra "günlük ritüel", sonra gizlilik. Gruplama işlevsel
/// değil anlamsal — kullanıcı ne aradığını "hangi menüde" diye değil
/// "hayatımın hangi parçası" diye düşünüyor.
struct SettingsRootView: View {
    @ObservedObject var vm: ProfileViewModel
    let onBack: () -> Void
    var onReminder: (() -> Void)? = nil
    var onMusic: (() -> Void)? = nil
    var onPrivacy: (() -> Void)? = nil
    var onPaywall: (() -> Void)? = nil
    /// Kilometre taşları profil listesinden çıktı (prototip 26'da profil
    /// dört satır) — girişi artık burada.
    var onMilestones: (() -> Void)? = nil

    var body: some View {
        SubScreen(title: NSLocalizedString("settings.title", comment: ""), onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                accountCard

                sectionLabel(NSLocalizedString("settings.account",
                                               value: "Hesap",
                                               comment: ""))
                SettingsGroup {
                    SettingsRow(
                        icon: "applelogo",
                        title: NSLocalizedString("settings.appleSignIn",
                                                 value: "Apple ile giriş",
                                                 comment: ""),
                        value: appleAccountValue,
                        showsChevron: false,
                        isLast: true
                    )
                }

                sectionLabel(NSLocalizedString("settings.dailyRitual", comment: ""))
                SettingsGroup {
                    SettingsRow(
                        icon: "bell",
                        title: NSLocalizedString("profile.row.reminder", comment: ""),
                        value: reminderText,
                        action: onReminder
                    )
                    SettingsRow(
                        icon: "music.note",
                        title: NSLocalizedString("profile.row.musicSource", comment: ""),
                        value: musicPlatform,
                        action: onMusic
                    )
                    SettingsRow(
                        icon: "target",
                        title: NSLocalizedString("settings.weeklyGoal", comment: ""),
                        value: "\(WeekRhythm.completionTarget)/7",
                        showsChevron: false,
                        isLast: true
                    )
                }

                if let onMilestones {
                    sectionLabel(NSLocalizedString("milestones.title", comment: ""))
                    SettingsGroup {
                        SettingsRow(
                            icon: "flag",
                            title: NSLocalizedString("milestones.title", comment: ""),
                            value: "\(BadgeManager.shared.unlocked.count)",
                            isLast: true,
                            action: onMilestones
                        )
                    }
                }

                sectionLabel(NSLocalizedString("settings.privacy", comment: ""))
                SettingsGroup {
                    SettingsRow(
                        icon: "lock",
                        title: NSLocalizedString("settings.privacyAccount", comment: ""),
                        action: onPrivacy
                    )
                    SettingsRow(
                        icon: "square.and.arrow.up",
                        title: NSLocalizedString("settings.exportData", comment: ""),
                        isLast: true,
                        action: nil
                    )
                }

                Text(versionText)
                    .bodyXS()
                    .foregroundColor(V3Tokens.faintText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingXL3)
            }
        }
    }

    // MARK: Hesap

    private var accountCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: vm.selectedAvatarColor))
                .frame(width: 46, height: 46)
                .overlay(
                    Text(String(vm.displayName.prefix(1)).uppercased())
                        .font(V3Typography.sans(15, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.displayName.isEmpty ? "—" : vm.displayName)
                    .font(V3Typography.sans(14.5, weight: .semibold))
                    .foregroundColor(V3Tokens.ink)
                Text("@\(vm.username) · \(NSLocalizedString("settings.freeTier", comment: ""))")
                    .bodyXS()
                    .foregroundColor(V3Tokens.mutedText)
            }

            Spacer()

            if let onPaywall {
                Button(action: onPaywall) {
                    Text("ONE+")
                        .font(V3Typography.sans(12.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 34)
                        .background(Capsule(style: .continuous).fill(ONEBrand.kor))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .oneCardBackground(radius: ONETokens.radiusCardLg)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .monoLabel(tracking: 1.3)
            .foregroundColor(V3Tokens.faintText)
            .padding(.top, ONETokens.spacingXL)
            .padding(.bottom, ONETokens.spacingSM)
    }

    private var reminderText: String {
        String(format: "%02d:%02d", vm.dailyReminderHour, vm.dailyReminderMinute)
    }

    private var musicPlatform: String {
        UserDefaults.standard.string(forKey: "preferredMusicService") ?? "Apple Music"
    }

    /// Apple sign-in durumu — email varsa göster, yoksa "Bağlı" fallback.
    /// Email yalnız İLK sign-in'de gelir (Apple gizlilik kontratı), sonraki
    /// oturumlarda nil — bu yüzden değeri Keychain'den okuyoruz.
    private var appleAccountValue: String {
        if let email = KeychainHelper.string(forKey: "appleSignInEmail"),
           !email.isEmpty {
            return email
        }
        return NSLocalizedString("settings.appleSignIn.connected",
                                 value: "Bağlı",
                                 comment: "")
    }

    private var versionText: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return "v\(v)"
    }
}

// MARK: - 29 · Hatırlatma

/// Hatırlatma ayarı.
///
/// Ekranın üstündeki içgörü kartı bir ayar değil, bir **taahhüt**:
/// "ONE seni günde yalnızca bir kez dürter. Kaydını zaten yaptıysan o gün
/// hiç dürtmez." Kullanıcı saati değiştirmeden önce bunu okuyor — bildirim
/// ayarına girerken beklenen kaygıyı baştan karşılıyor.
struct ReminderSettingsView: View {
    @ObservedObject var vm: ProfileViewModel
    let onBack: () -> Void

    /// Prototipteki hazır saatler. Serbest seçici de var ama çoğu kullanıcı
    /// bunlardan birini seçiyor; iki dokunuşu bire indiriyor.
    private let presets = [19, 20, 21, 22]

    var body: some View {
        SubScreen(title: NSLocalizedString("profile.row.reminder", comment: ""), onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                InsightCard(label: NSLocalizedString("reminder.onceADay", comment: "")) {
                    Text(NSLocalizedString("reminder.promise", comment: ""))
                        .bodySM()
                        .foregroundColor(V3Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(NSLocalizedString("reminder.hour", comment: ""))
                    .monoLabel(tracking: 1.3)
                    .foregroundColor(V3Tokens.faintText)
                    .padding(.top, ONETokens.spacingXL)
                    .padding(.bottom, ONETokens.spacingSM)

                VStack(spacing: ONETokens.spacingLG) {
                    Text(String(format: "%02d:%02d", vm.dailyReminderHour, vm.dailyReminderMinute))
                        .font(V3Typography.sans(46, weight: .ultraLight))
                        .monospacedDigit()
                        .foregroundColor(V3Tokens.ink)

                    HStack(spacing: 6) {
                        ForEach(presets, id: \.self) { hour in
                            FilterChip(
                                title: String(format: "%02d:00", hour),
                                isSelected: vm.dailyReminderHour == hour && vm.dailyReminderMinute == 0
                            ) {
                                ONEHaptics.feelingSelected()
                                vm.dailyReminderHour = hour
                                vm.dailyReminderMinute = 0
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ONETokens.spacingXL)
                .oneCardBackground(radius: ONETokens.radiusCardLg)

                SettingsGroup {
                    SettingsToggleRow(
                        title: NSLocalizedString("reminder.evening", comment: ""),
                        subtitle: NSLocalizedString("reminder.eveningSub", comment: ""),
                        isOn: $vm.notificationsEnabled
                    )
                    SettingsToggleRow(
                        title: NSLocalizedString("reminder.streak", comment: ""),
                        subtitle: NSLocalizedString("reminder.streakSub", comment: ""),
                        isOn: $vm.streakNotificationsEnabled,
                        isLast: true
                    )
                }
                .padding(.top, ONETokens.spacingLG)
            }
        }
    }

}
