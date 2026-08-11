//
//  ProfileSettingsSection.swift
//  one
//
//  Feature: ui-consistency-and-accessibility-sweep (Task 3.3)
//
//  Full-screen settings overlay extracted from `ProfileDashboardView`. Slides
//  in from the trailing edge and contains the consolidated setting groups:
//  music services, general preferences, notifications, privacy, data export,
//  danger (delete account). Alerts and export share-sheet presentation stay
//  local to the settings screen, matching the pre-decomposition behavior.
//

import SwiftUI
import CoreData
import MusicKit

/// Right-hand slide-in settings screen. Its own ZStack sibling in the parent
/// dashboard allows non-system slide transitions + a custom header (back chip
/// + centered title) that the native sheet presentation can't provide.
struct ProfileSettingsSection: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.profilePalette) private var palette

    var context: NSManagedObjectContext

    /// Two-way binding owned by `ProfileDashboardView`. Set to `false` to
    /// dismiss the overlay via the back button.
    @Binding var showSettings: Bool

    // MARK: - Local state (self-contained to this screen)

    @State private var showAppleMusicInfoAlert = false
    @State private var showDeleteAccountAlert = false

    @State private var showExportFormatPicker = false
    @State private var exportItems: [Any] = []
    @State private var showExportShareSheet = false

    private var profileColor: Color { Color(hex: vm.selectedAvatarColor) }

    private var chevronRight: some View {
        Image(systemName: "chevron.right").bodyXSMedium().foregroundColor(palette.tertiaryText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header — geri butonu + başlık
            HStack {
                Button(action: {
                    ONEHaptics.tabSwitch()
                    showSettings = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .bodyXSMedium()
                        Text(NSLocalizedString("general.back", comment: ""))
                            .bodySMMedium()
                    }
                    .foregroundColor(palette.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .liquidGlass(
                        tint: profileColor.opacity(0.06),
                        interactive: true,
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("general.back", comment: ""))
                Spacer()
                Text(NSLocalizedString("profile.settings.title", comment: ""))
                    .bodyMD()
                    .foregroundColor(palette.primaryText)
                Spacer()
                // Sağ taraf placeholder — başlığı ortalamak için
                Color.clear.frame(width: 60, height: 1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 56)
            .padding(.bottom, 14)
            .background(palette.screenBG)

            // İçerik
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    v3YankiSection
                    consolidatedMusicSection
                    consolidatedGeneralSection
                    consolidatedNotificationsSection
                    consolidatedPrivacySection
                    consolidatedDataSection
                    consolidatedDangerSection

                    // Footer
                    ProfileFooterSection(vm: vm)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(palette.screenBG.ignoresSafeArea())
        .alert(NSLocalizedString("profile.appleMusicTitle", comment: ""), isPresented: $showAppleMusicInfoAlert) {
            Button(NSLocalizedString("profile.openSettings", comment: "")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(NSLocalizedString("addFriend.ok", comment: ""), role: .cancel) { }
        } message: { Text(NSLocalizedString("profile.appleMusicMsg", comment: "")) }
        .alert(NSLocalizedString("profile.deleteAccountTitle", comment: ""), isPresented: $showDeleteAccountAlert) {
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("profile.deleteAccount", comment: ""), role: .destructive) {
                vm.deleteAccount()
            }
        } message: { Text(NSLocalizedString("profile.deleteAccountMsg", comment: "")) }
        .sheet(isPresented: $showExportShareSheet) {
            if !exportItems.isEmpty {
                ShareSheet(items: exportItems)
            }
        }
    }

    // MARK: - Consolidated Sections
    // Müzik — sadece çalışan: Apple Music. Spotify "yakında" satırı kaldırıldı.

    private var consolidatedMusicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("profile.musicServices", comment: ""))
                .monoBase(tracking: 1.5)
                .foregroundColor(palette.sectionHeader)
                .padding(.leading, 4)
            Button(action: {
                ONEHaptics.tabSwitch()
                if vm.appleMusicStatus == .authorized {
                    showAppleMusicInfoAlert = true
                } else {
                    Task {
                        let status = await MusicAuthorization.request()
                        vm.appleMusicStatus = status
                        if status == .authorized {
                            NotificationCenter.default.post(name: NSNotification.Name("AppleMusicAuthenticationChanged"), object: nil)
                        }
                    }
                }
            }) {
                settingsRow(
                    icon: "applelogo", iconColor: ONETokens.appleMusicRed, title: "Apple Music",
                    trailing: {
                        connectionDot(
                            connected: vm.appleMusicStatus == .authorized,
                            color: ONETokens.appleMusicRed,
                            text: vm.appleMusicStatus == .authorized
                                ? NSLocalizedString("profile.appleMusicConnected", comment: "")
                                : NSLocalizedString("profile.appleMusicConnect", comment: "")
                        )
                    },
                    showDivider: false
                )
            }
            .background(palette.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
        }
    }

    private var consolidatedGeneralSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("profile.general", comment: ""))
                .monoBase(tracking: 1.5)
                .foregroundColor(palette.sectionHeader)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                settingsToggleRow(icon: "moon", title: NSLocalizedString("profile.darkMode", comment: ""), isOn: $vm.isDarkMode)
                Rectangle().fill(palette.dividerColor).frame(height: 1).padding(.horizontal, 16)
                settingsToggleRow(icon: "hand.tap", title: NSLocalizedString("profile.haptics", comment: ""), isOn: $vm.hapticFeedbackEnabled)
                    .onChange(of: vm.hapticFeedbackEnabled) { _, newValue in
                        if newValue {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { ONEHaptics.songSaved() }
                        }
                    }
                Rectangle().fill(palette.dividerColor).frame(height: 1).padding(.horizontal, 16)
                Menu {
                    ForEach(ONETokens.availableCities, id: \.self) { city in
                        Button(action: { vm.preferredCity = city }) {
                            HStack { Text(city); if city == vm.preferredCity { Image(systemName: "checkmark") } }
                        }
                    }
                } label: {
                    settingsRow(
                        icon: "mappin.circle", iconColor: palette.rowIcon, title: NSLocalizedString("profile.city", comment: ""),
                        trailing: {
                            HStack(spacing: 4) {
                                Text(vm.preferredCity).monoSM(tracking: 0).foregroundColor(palette.secondaryText)
                                Image(systemName: "chevron.up.chevron.down").monoMicro().foregroundColor(palette.tertiaryText)
                            }
                        },
                        showDivider: false
                    )
                }
            }
            .background(palette.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
        }
    }

    private var consolidatedNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("profile.notificationsHeader", comment: ""))
                .monoBase(tracking: 1.5)
                .foregroundColor(palette.sectionHeader)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                settingsToggleRow(icon: "bell", title: NSLocalizedString("profile.notifications", comment: ""), isOn: $vm.notificationsEnabled)
                    .onChange(of: vm.notificationsEnabled) { _, newValue in
                        if newValue {
                            vm.notificationManager.requestAuthorization { granted in
                                if granted {
                                    vm.notificationManager.scheduleDailyReminder(at: vm.dailyReminderTime)
                                    if vm.weeklySummaryEnabled { vm.notificationManager.scheduleWeeklySummary() }
                                } else {
                                    DispatchQueue.main.async { vm.notificationsEnabled = false }
                                }
                            }
                        } else {
                            vm.notificationManager.disableDailyReminder()
                            vm.notificationManager.disableWeeklySummary()
                            vm.notificationManager.cancelStreakWarning()
                        }
                    }
                if vm.notificationsEnabled {
                    Rectangle().fill(palette.dividerColor).frame(height: 1).padding(.horizontal, 16)
                    HStack(spacing: 12) {
                        Image(systemName: "clock").bodySM().foregroundColor(palette.secondaryText).frame(width: 20)
                        Text(NSLocalizedString("profile.reminderTime", comment: "")).bodySM().foregroundColor(palette.primaryText)
                        Spacer()
                        DatePicker("", selection: $vm.dailyReminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden().tint(profileColor).colorScheme(vm.isDarkMode ? .dark : .light)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    Rectangle().fill(palette.dividerColor).frame(height: 1).padding(.horizontal, 16)
                    settingsToggleRow(icon: "flame", title: NSLocalizedString("profile.streakAlert", comment: ""), isOn: $vm.streakNotificationsEnabled)
                    Rectangle().fill(palette.dividerColor).frame(height: 1).padding(.horizontal, 16)
                    settingsToggleRow(icon: "chart.bar", title: NSLocalizedString("profile.weeklySummary", comment: ""), isOn: $vm.weeklySummaryEnabled)
                }
            }
            .background(palette.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
        }
    }

    /// v2.6 — Profilimde arkadaşlara hangi aggregate veri görünsün?
    private var consolidatedPrivacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gizlilik")
                .monoBase(tracking: 1.5)
                .foregroundColor(palette.sectionHeader)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                settingsToggleRow(
                    icon: "music.note",
                    title: "Müzik zevkim arkadaşlarda görünsün",
                    isOn: $vm.musicTasteVisibleToFriends
                )
                Rectangle().fill(palette.dividerColor).frame(height: 1).padding(.horizontal, 16)
                settingsToggleRow(
                    icon: "calendar",
                    title: "Mood geçmişim arkadaşlarda görünsün",
                    isOn: $vm.moodHistoryVisibleToFriends
                )
            }
            .background(palette.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
        }
    }

    @State private var iCloudSyncDone = false

    private var consolidatedDataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("profile.other", comment: ""))
                .monoBase(tracking: 1.5)
                .foregroundColor(palette.sectionHeader)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                Button(action: {
                    vm.syncAllSettingsToICloud()
                    ONEHaptics.songSaved()
                    iCloudSyncDone = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { iCloudSyncDone = false }
                }) {
                    settingsRow(
                        icon: "icloud.and.arrow.up",
                        iconColor: palette.rowIcon,
                        title: "iCloud ile Senkronize Et",
                        trailing: {
                            if iCloudSyncDone {
                                Image(systemName: "checkmark.circle.fill")
                                    .bodyXSMedium()
                                    .foregroundColor(ONETokens.oneGreen)
                            } else {
                                chevronRight
                            }
                        },
                        showDivider: true
                    )
                }
                Button(action: { showExportFormatPicker = true }) {
                    settingsRow(icon: "square.and.arrow.up", iconColor: palette.rowIcon, title: NSLocalizedString("profile.exportData", comment: ""), trailing: { chevronRight }, showDivider: true)
                }
                .confirmationDialog(NSLocalizedString("profile.exportFormat", comment: ""), isPresented: $showExportFormatPicker) {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.rawValue) {
                            do {
                                let url = try ExportManager.shared.exportAll(format: format, context: context)
                                exportItems = [url]
                                showExportShareSheet = true
                            } catch {
                                ONELogger.error("Dışa aktarma hatası: \(error.localizedDescription)", category: .profile)
                            }
                        }
                    }
                    Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) {}
                }
                Button(action: { AppReviewManager.shared.openAppStorePage() }) {
                    settingsRow(icon: "star", iconColor: palette.rowIcon, title: NSLocalizedString("profile.rateApp", comment: ""), trailing: { chevronRight }, showDivider: false)
                }
            }
            .background(palette.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
        }
    }

    /// v3: Yankı (aylık özet) artık sekme değil — Profil > Ayarlar altında.
    private var v3YankiSection: some View {
        Button(action: {
            ONEHaptics.tabSwitch()
            NotificationCenter.default.post(name: .init("switchToEchoTab"), object: nil)
        }) {
            settingsRow(
                icon: "waveform.path.ecg",
                iconColor: palette.rowIcon,
                title: "Aylık özet · Yankı",
                trailing: { chevronRight },
                showDivider: false
            )
        }
        .background(palette.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
    }

    private var consolidatedDangerSection: some View {
        Button(action: {
            ONEHaptics.error()
            showDeleteAccountAlert = true
        }) {
            settingsRow(
                icon: "trash", iconColor: ONETokens.oneRed,
                title: NSLocalizedString("profile.deleteAccount", comment: ""),
                trailing: { chevronRight },
                showDivider: false
            )
        }
        .background(palette.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneRed.opacity(vm.isDarkMode ? 0.40 : 0.25), lineWidth: 1))
    }

    // MARK: - Reusable Row Components

    private func settingsRow<Trailing: View>(icon: String, iconColor: Color, title: String, @ViewBuilder trailing: () -> Trailing, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon).bodySM().foregroundColor(iconColor).frame(width: 20)
                Text(title).bodySM().foregroundColor(palette.primaryText)
                Spacer()
                trailing()
            }.padding(.horizontal, 16).padding(.vertical, 14)
            if showDivider { Rectangle().fill(palette.dividerColor).frame(height: 1).padding(.horizontal, 16) }
        }
    }

    private func settingsToggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon).bodySM().foregroundColor(palette.rowIcon).frame(width: 20)
                Toggle(title, isOn: isOn)
                    .font(ONETypography.bodySM)
                    .foregroundColor(palette.primaryText)
                    .tint(profileColor)
            }.padding(.horizontal, 16).padding(.vertical, 8)
            Rectangle().fill(palette.dividerColor).frame(height: 1).padding(.horizontal, 16)
        }
    }

    private func connectionDot(connected: Bool, color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(connected ? color : palette.tertiaryText).frame(width: 6, height: 6)
            Text(text).monoSM(tracking: 0).foregroundColor(connected ? color : palette.tertiaryText)
        }
    }
}

/// Shared footer used at the bottom of the dashboard and the settings screen.
/// Renders the ONE watermark, version string, and "made with love" credit.
struct ProfileFooterSection: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.profilePalette) private var palette

    private var profileColor: Color { Color(hex: vm.selectedAvatarColor) }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .monoLabel(tracking: 0.8)
                    .foregroundColor(palette.secondaryText)
                Text(NSLocalizedString("profile.madeWithLove", comment: ""))
                    .monoSM()
                    .foregroundColor(palette.tertiaryText)
            }

            // ONE marka logosu — en altta, büyük, belirgin
            Image("ONE_Watermark")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .foregroundStyle(palette.primaryText)
                .opacity(vm.isDarkMode ? 0.90 : 0.82)
                .shadow(color: profileColor.opacity(0.22), radius: 16, x: 0, y: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}
