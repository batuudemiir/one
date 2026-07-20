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

    var body: some View {
        SubScreen(title: NSLocalizedString("settings.title", comment: ""), onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                accountCard

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
                    .foregroundColor(ONETokens.oneStone)
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
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.displayName.isEmpty ? "—" : vm.displayName)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(ONETokens.oneInk)
                Text("@\(vm.username) · \(NSLocalizedString("settings.freeTier", comment: ""))")
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
            }

            Spacer()

            if let onPaywall {
                Button(action: onPaywall) {
                    Text("ONE+")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 34)
                        .background(Capsule(style: .continuous).fill(ONETokens.oneBrand))
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
            .foregroundColor(ONETokens.oneStone)
            .padding(.top, ONETokens.spacingXL)
            .padding(.bottom, ONETokens.spacingSM)
    }

    private var reminderText: String {
        String(format: "%02d:%02d", vm.dailyReminderHour, vm.dailyReminderMinute)
    }

    private var musicPlatform: String {
        UserDefaults.standard.string(forKey: "preferredMusicService") ?? "Apple Music"
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
                        .foregroundColor(ONETokens.oneInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(NSLocalizedString("reminder.hour", comment: ""))
                    .monoLabel(tracking: 1.3)
                    .foregroundColor(ONETokens.oneStone)
                    .padding(.top, ONETokens.spacingXL)
                    .padding(.bottom, ONETokens.spacingSM)

                VStack(spacing: ONETokens.spacingLG) {
                    Text(String(format: "%02d:%02d", vm.dailyReminderHour, vm.dailyReminderMinute))
                        .font(.system(size: 46, weight: .ultraLight))
                        .monospacedDigit()
                        .foregroundColor(ONETokens.oneInk)

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
                    toggleRow(
                        title: NSLocalizedString("reminder.evening", comment: ""),
                        subtitle: NSLocalizedString("reminder.eveningSub", comment: ""),
                        isOn: $vm.notificationsEnabled
                    )
                    toggleRow(
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

    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        isLast: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ONETokens.oneInk)
                    Text(subtitle)
                        .bodyXS()
                        .foregroundColor(ONETokens.oneAsh)
                }
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(ONETokens.oneInk)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)

            if !isLast {
                Rectangle()
                    .fill(ONETokens.oneInk.opacity(0.09))
                    .frame(height: 1)
                    .padding(.leading, 15)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
