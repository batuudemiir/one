//
//  ProfileOverviewSection.swift
//  one
//
//  Prototipteki profil gövdesi: kimlik, üç sayı, renk karnesi, ayar satırları.
//

import SwiftUI
import CoreData

/// Profilin prototipteki hali.
///
/// Eski gövde bir vitrindi — hero foto, özellik kartları, sadakat kartı.
/// Prototip bunu bir **karneye** çeviriyor: kim olduğun, ne biriktirdiğin,
/// hangi renk olduğun. Kartlar yerine satırlar; süs yerine sayı.
struct ProfileOverviewSection: View {
    @ObservedObject var vm: ProfileViewModel
    let context: NSManagedObjectContext

    @Binding var showFriendsList: Bool
    @Binding var showSettings: Bool

    @State private var showMilestones = false
    /// Prototip 28-29. Eski ayarlar sağdan kayan bir overlay'di
    /// (`ProfileSettingsSection`); prototipte kendi ekranı.
    @State private var showSettingsScreen = false
    @State private var showReminder = false

    @State private var stats: ProfileStats = .empty

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            identityRow

            statRow
                .padding(.top, ONETokens.spacingXL)

            Text(NSLocalizedString("profile.colorReport", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(ONETokens.oneStone)
                .padding(.top, ONETokens.spacingLG)
                .padding(.bottom, ONETokens.spacingSM)

            colorReport

            settingsRows
                .padding(.top, ONETokens.spacingXL)
        }
        .padding(.horizontal, ONETokens.spacingXL)
        .task { stats = await ProfileStats.load(context: context) }
        .fullScreenCover(isPresented: $showSettingsScreen) {
            SettingsRootView(
                vm: vm,
                onBack: { showSettingsScreen = false },
                onReminder: {
                    showSettingsScreen = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showReminder = true }
                },
                onMusic: { showSettingsScreen = false; showSettings = true },
                onPrivacy: { showSettingsScreen = false; showSettings = true },
                onMilestones: {
                    showSettingsScreen = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showMilestones = true }
                }
            )
        }
        .fullScreenCover(isPresented: $showReminder) {
            ReminderSettingsView(vm: vm, onBack: { showReminder = false })
        }
        .sheet(isPresented: $showMilestones) {
            MilestonesView(
                totalEntries: stats.totalEntries,
                streakDays: stats.currentStreak
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: Identity

    private var identityRow: some View {
        HStack(spacing: ONETokens.spacingLG) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(vm.displayName.isEmpty ? "—" : vm.displayName)
                    .displayMD()
                    .foregroundColor(ONETokens.oneInk)

                Text(subtitleText)
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
            }

            Spacer()
        }
    }

    private var subtitleText: String {
        let handle = vm.username.isEmpty ? "" : "@\(vm.username) · "
        let friends = String(
            format: NSLocalizedString("profile.friendCountFormat", comment: ""),
            vm.friendCount
        )
        return handle + friends
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let img = vm.profileImage {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(hex: vm.selectedAvatarColor)
                    .overlay(
                        Text(initial)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }

    private var initial: String {
        String(vm.displayName.prefix(1)).uppercased()
    }

    // MARK: Stats

    /// Prototipteki üç sayı: kayıt, tam hafta, farklı renk.
    private var statRow: some View {
        HStack(spacing: 9) {
            statCard(stats.totalEntries, NSLocalizedString("profile.stat.entries", comment: ""))
            statCard(stats.fullWeeks, NSLocalizedString("profile.stat.fullWeeks", comment: ""))
            statCard(stats.distinctColors, NSLocalizedString("profile.stat.colors", comment: ""))
        }
    }

    private func statCard(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 23, weight: .bold))
                .monospacedDigit()
                .foregroundColor(ONETokens.oneInk)
            Text(label)
                .bodyXS()
                .foregroundColor(ONETokens.oneAsh)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(cardBackground)
    }

    // MARK: Colour report

    /// Ritim satırıyla aynı kabuk: noktalar solda, öne çıkan sağda.
    private var colorReport: some View {
        HStack(spacing: 9) {
            HStack(spacing: 6) {
                ForEach(Array(stats.recentColors.enumerated()), id: \.offset) { _, hex in
                    Circle()
                        .fill(hex.map { Color(hex: $0) } ?? ONETokens.oneInk.opacity(0.14))
                        .frame(width: 19, height: 19)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                Text(NSLocalizedString("profile.mostFrequent", comment: ""))
                    .monoLabel(tracking: 0.2)
                    .foregroundColor(ONETokens.oneAsh)
                Text(stats.topMoodLabel ?? "—")
                    .monoLabel(tracking: 0.2)
                    .foregroundColor(ONETokens.oneInk)
            }
        }
        .padding(.horizontal, ONETokens.spacingLG)
        .padding(.vertical, 13)
        .background(cardBackground)
    }

    // MARK: Settings rows

    private var settingsRows: some View {
        VStack(spacing: 7) {
            row("bell", NSLocalizedString("profile.row.reminder", comment: ""), reminderText) {
                showReminder = true
            }
            row("music.note", NSLocalizedString("profile.row.musicSource", comment: ""), musicPlatform) {
                showSettings = true
            }
            // Kilometre taşları satırı kaldırıldı — prototip 26'da profil
            // dört satır: hatırlatma, müzik kaynağı, arkadaşlar, ayarlar.
            // MilestonesView'a giriş ayarların içine taşındı.
            row("person.2", NSLocalizedString("profile.row.friends", comment: ""), "\(vm.friendCount)") {
                showFriendsList = true
            }
            row("gearshape", NSLocalizedString("profile.row.settings", comment: ""), nil) {
                showSettingsScreen = true
            }
        }
    }

    private func row(
        _ icon: String,
        _ title: String,
        _ value: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: ONETokens.spacingMD) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(ONETokens.oneAsh)
                    .frame(width: 22)

                Text(title)
                    .bodySM()
                    .foregroundColor(ONETokens.oneInk)

                Spacer()

                if let value {
                    Text(value)
                        .bodySM()
                        .foregroundColor(ONETokens.oneStone)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(ONETokens.oneStone)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private var reminderText: String {
        String(format: "%02d:%02d", vm.dailyReminderHour, vm.dailyReminderMinute)
    }

    private var musicPlatform: String {
        UserDefaults.standard.string(forKey: "selectedMusicPlatform") ?? "Apple Music"
    }

    // MARK: Shared chrome

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
            .fill(Color.white.opacity(0.70))
            .overlay(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                    .stroke(ONETokens.oneInk.opacity(0.09), lineWidth: 1)
            )
    }
}

// MARK: - Stats

/// Profil sayıları. Hepsi tek geçişte hesaplanır — üç ayrı fetch yerine
/// bir fetch, çünkü üçü de aynı kayıt kümesinden türüyor.
struct ProfileStats {
    let totalEntries: Int
    let fullWeeks: Int
    let distinctColors: Int
    let topMoodLabel: String?
    /// Son 7 gün, en eskiden yeniye. Boş günler nil.
    let recentColors: [String?]
    /// Kilometre taşlarında "N gün sonra açılıyor" için gereken güncel seri.
    let currentStreak: Int

    static let empty = ProfileStats(
        totalEntries: 0, fullWeeks: 0, distinctColors: 0,
        topMoodLabel: nil, recentColors: Array(repeating: nil, count: 7),
        currentStreak: 0
    )

    static func load(context: NSManagedObjectContext) async -> ProfileStats {
        let bg = PersistenceController.shared.container.newBackgroundContext()
        return await bg.perform {
            let request: NSFetchRequest<DailySong> = DailySong.fetchRequest()
            guard let items = try? bg.fetch(request) else { return .empty }

            let calendar = Calendar.current
            let byDay = Dictionary(
                grouping: items.compactMap { item -> (Date, DailySong)? in
                    guard let date = item.date else { return nil }
                    return (calendar.startOfDay(for: date), item)
                },
                by: { $0.0 }
            )

            // Tam hafta: o haftanın 7 gününün hepsi dolu.
            let weeks = Dictionary(grouping: byDay.keys) { date -> DateComponents in
                calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            }
            let fullWeeks = weeks.values.filter { $0.count == 7 }.count

            let hexes = items.compactMap { $0.moodColorHex }
            let labels = items.compactMap { $0.moodLabel }
            let topLabel = Dictionary(grouping: labels, by: { $0 })
                .max { $0.value.count < $1.value.count }?.key

            let today = calendar.startOfDay(for: Date())
            let recent: [String?] = (0..<7).reversed().map { offset in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                    return nil
                }
                return byDay[day]?.last?.1.moodColorHex
            }

            // Güncel seri: bugünden (ya da dünden) geriye kesintisiz gün.
            // Bugün henüz boşsa dünden başlamak seriyi gün ortasında
            // sıfırlamamak için — gün bitmeden kaybedilmiş sayılmaz.
            let filledDays = Set(byDay.keys)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            var streak = 0
            if filledDays.contains(today) || filledDays.contains(yesterday) {
                var cursor = filledDays.contains(today) ? today : yesterday
                while filledDays.contains(cursor) {
                    streak += 1
                    guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                    cursor = prev
                }
            }

            return ProfileStats(
                totalEntries: byDay.count,
                fullWeeks: fullWeeks,
                distinctColors: Set(hexes).count,
                topMoodLabel: topLabel,
                recentColors: recent,
                currentStreak: streak
            )
        }
    }
}
