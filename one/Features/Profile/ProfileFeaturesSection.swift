//
//  ProfileFeaturesSection.swift
//  one
//
//  Feature: ui-consistency-and-accessibility-sweep (Task 3.3)
//
//  Mid-page content extracted from `ProfileDashboardView`:
//
//  - `ProfileFeaturesSection`: Echo + Monthly/Yearly summary feature rows
//    with progressive-disclosure lock state when < 3 entries.
//  - `ProfileRecentMoodStripSection`: 7-day color strip preserving today's
//    highlighted border treatment.
//  - `ProfileLoyaltyCard`: memory counter ("kaç gün ONE'la, kaç kayıt").
//
//  CoreData dependencies are injected via `context` so the parent dashboard
//  keeps a single source of truth. Behavior is preserved byte-for-byte.
//

import SwiftUI
import CoreData

/// Features card (Echo + Monthly + Yearly summary rows) with a locked
/// progressive-disclosure state when the user has fewer than 3 entries.
struct ProfileFeaturesSection: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.profilePalette) private var palette

    var context: NSManagedObjectContext

    @Binding var showEcho: Bool
    @Binding var showMonthlySummary: Bool
    @Binding var showYearlySummary: Bool

    @State private var totalDaysCount: Int = 0
    @State private var showPinnedSongPicker = false

    private var chevronRight: some View {
        Image(systemName: "chevron.right").bodyXSMedium().foregroundColor(palette.tertiaryText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("profile.features", comment: ""))
                .bodySMMedium()
                .foregroundColor(palette.primaryText)
                .padding(.leading, 4)

            if totalDaysCount >= 3 {
                ProfilePinnedSongCard(vm: vm, showPicker: $showPinnedSongPicker)

                VStack(spacing: 0) {
                    Button(action: { showEcho = true }) {
                        featureRow(
                            icon: "waveform",
                            iconColor: ONETokens.moodTeal,
                            title: NSLocalizedString("profile.echoTitle", comment: ""),
                            subtitle: NSLocalizedString("profile.echoDesc", comment: ""),
                            showDivider: true,
                            trailing: { chevronRight }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(NSLocalizedString("profile.echoTitle", comment: ""))

                    Button(action: {
                        guard isMonthlySummaryAvailable else { return }
                        showMonthlySummary = true
                    }) {
                        featureRow(
                            icon: isMonthlySummaryAvailable ? "calendar.badge.checkmark" : "lock",
                            iconColor: ONETokens.moodPurple,
                            title: NSLocalizedString("premium.monthlySummary.title", comment: ""),
                            subtitle: isMonthlySummaryAvailable
                                ? NSLocalizedString("premium.feature.monthlySummary.desc", comment: "")
                                : monthlySummaryLockedSubtitle,
                            showDivider: false,
                            trailing: {
                                Image(systemName: isMonthlySummaryAvailable ? "chevron.right" : "lock")
                                    .bodyXSMedium()
                                    .foregroundColor(palette.tertiaryText)
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!isMonthlySummaryAvailable)
                    .opacity(isMonthlySummaryAvailable ? 1.0 : 0.65)
                    .accessibilityLabel(NSLocalizedString("premium.monthlySummary.title", comment: ""))
                }
                .background(palette.cardBG)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.cardBorder, lineWidth: 1))

                // Yıllık Özet — daha küçük satır (yıl sonuna kadar locked)
                Button(action: {
                    guard isYearlySummaryAvailable else { return }
                    showYearlySummary = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: isYearlySummaryAvailable ? "calendar" : "lock")
                            .bodySM()
                            .foregroundColor(ONETokens.moodTeal)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(ONETokens.moodTeal.opacity(0.10)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("yearly.title", comment: ""))
                                .bodySMMedium()
                                .foregroundColor(palette.primaryText)
                            Text(isYearlySummaryAvailable
                                 ? NSLocalizedString("yearly.subtitle", comment: "")
                                 : NSLocalizedString("yearly.availableInDecember", comment: ""))
                                .monoLabel(tracking: 0.5)
                                .foregroundColor(palette.secondaryText)
                        }

                        Spacer()

                        Image(systemName: isYearlySummaryAvailable ? "chevron.right" : "lock")
                            .monoBase()
                            .foregroundColor(ONETokens.oneStone)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(palette.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
                    .opacity(isYearlySummaryAvailable ? 1.0 : 0.7)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isYearlySummaryAvailable)
            } else {
                // Progressive Disclosure (Kilitli Durum)
                let remaining = 3 - totalDaysCount
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "lock.fill")
                        .displayMD()
                        .foregroundColor(ONETokens.oneBrand.opacity(0.8))
                        .padding(.top, 12)

                    Text(NSLocalizedString("profile.features.lockedTitle", comment: ""))
                        .bodyLG()
                        .foregroundColor(palette.primaryText)

                    Text(String(format: NSLocalizedString("profile.features.lockedDesc", comment: ""), remaining))
                        .bodySM()
                        .foregroundColor(palette.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(palette.cardBG)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
            }
        }
        .onAppear { refreshDaysCount() }
        .sheet(isPresented: $showPinnedSongPicker) {
            PinnedSongPickerView { selected in
                vm.setPinnedSong(selected)
            }
        }
    }

    // MARK: - Helpers

    private func featureRow<Trailing: View>(icon: String, iconColor: Color, title: String, subtitle: String, showDivider: Bool, @ViewBuilder trailing: () -> Trailing) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.12)).frame(width: 34, height: 34)
                    Image(systemName: icon).bodyMDMedium().foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).bodySMMedium().foregroundColor(palette.primaryText)
                    Text(subtitle).monoSM().foregroundColor(palette.secondaryText)
                }
                Spacer()
                trailing()
            }.padding(.horizontal, 16).padding(.vertical, 14)
            if showDivider { Rectangle().fill(palette.dividerColor).frame(height: 1).padding(.horizontal, 16) }
        }
    }

    // MARK: - Derived data

    private func refreshDaysCount() {
        let request = NSFetchRequest<DailySong>(entityName: "DailySong")
        totalDaysCount = (try? context.count(for: request)) ?? 0
    }

    private var isYearlySummaryAvailable: Bool {
        Calendar.current.component(.month, from: Date()) == 12
    }

    private var isMonthlySummaryAvailable: Bool {
        let cal = Calendar.current
        let now = Date()
        let day = cal.component(.day, from: now)
        let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        return day >= 25 && day <= daysInMonth
    }

    private var monthlySummaryLockedSubtitle: String {
        let cal = Calendar.current
        let now = Date()
        let daysLeft = 25 - cal.component(.day, from: now)
        if daysLeft <= 0 { return "" }
        return String(format: NSLocalizedString("profile.monthlySummary.lockedDesc", comment: "Her ayın 25'inde açılır"), daysLeft)
    }
}

/// Last 7 days as a mood color strip. Today is highlighted with a stronger
/// outline so users can read "this is where I am" at a glance.
struct ProfileRecentMoodStripSection: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.profilePalette) private var palette

    /// Per-day mood colors (oldest → newest, 7 entries). `nil` for days with
    /// no entry so the caller can render an empty bar.
    let recentMoodColors: [Color?]

    var body: some View {
        let colors = recentMoodColors
        let weekdayLabels = recentWeekdayLabels()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(NSLocalizedString("profile.recentWeek.title", comment: ""))
                    .monoBase(tracking: 1.5)
                    .foregroundColor(palette.sectionHeader)
                Spacer()
                Text(NSLocalizedString("profile.recentWeek.subtitle", comment: ""))
                    .monoLabel(tracking: 0.6)
                    .foregroundColor(palette.secondaryText)
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { idx in
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colors[idx] ?? ONETokens.oneSilver.opacity(0.45))
                            if colors[idx] == nil {
                                Image(systemName: "minus")
                                    .monoMicro()
                                    .foregroundColor(palette.tertiaryText)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    idx == 6 ? palette.primaryText.opacity(vm.isDarkMode ? 0.5 : 0.3) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )

                        Text(weekdayLabels[idx])
                            .monoLabel(tracking: 0.4)
                            .foregroundColor(idx == 6 ? palette.primaryText : palette.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(palette.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.cardBorder, lineWidth: 1))
        }
    }

    /// Son 7 günün haftaiçi kısa etiketleri (Pzt, Sal, …, Bugün).
    private func recentWeekdayLabels() -> [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EE"  // kısa: Pzt, Sal...
        return (0..<7).reversed().map { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return "·" }
            if offset == 0 { return NSLocalizedString("profile.recentWeek.todayShort", comment: "") }
            return formatter.string(from: day).prefix(3).description
        }
    }
}

/// Loss-aversion stats card — the user's accumulated memories.
/// Renders 4 metrics (days with ONE, entries, streak, badges) separated by
/// thin dividers, wrapped in a mood-tinted soft card.
struct ProfileLoyaltyCard: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.profilePalette) private var palette

    var context: NSManagedObjectContext

    private var profileColor: Color { Color(hex: vm.selectedAvatarColor) }

    var body: some View {
        let days     = daysSinceJoin
        let entries  = totalDaysCount
        let unlocked = BadgeManager.shared.unlocked.count
        let streak   = currentStreak
        let nextMilestone = StreakEngine.milestones.first { $0 > streak }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "infinity")
                    .bodyXS()
                    .foregroundColor(profileColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("profile.loyalty.title", comment: ""))
                        .monoBase(tracking: 1.5)
                        .foregroundColor(palette.sectionHeader)
                    Text(NSLocalizedString("profile.loyalty.subtitle", comment: ""))
                        .monoLabel(tracking: 0.4)
                        .foregroundColor(palette.secondaryText)
                }
                Spacer()
            }

            // Streak hero
            VStack(alignment: .center, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(streak)")
                        .displayMD()
                        .foregroundColor(palette.primaryText)
                    Text("🔥")
                        .font(.system(size: 22))
                }
                Text("günlük seri")
                    .monoLabel(tracking: 0.7)
                    .foregroundColor(palette.secondaryText)

                if let next = nextMilestone {
                    let remaining = next - streak
                    Text("Sonraki rozete \(remaining) gün")
                        .monoMicro(tracking: 0.5)
                        .foregroundColor(palette.tertiaryText)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            Rectangle().fill(palette.statDivider).frame(height: 1)

            // Alt 3'lü metrik
            HStack(alignment: .top, spacing: 0) {
                loyaltyMetric(value: "\(days)", label: NSLocalizedString("profile.loyalty.daysWithONE", comment: ""))
                Rectangle().fill(palette.statDivider).frame(width: 1, height: 30).accessibilityHidden(true)
                loyaltyMetric(value: "\(entries)", label: NSLocalizedString("profile.loyalty.entries", comment: ""))
                Rectangle().fill(palette.statDivider).frame(width: 1, height: 30).accessibilityHidden(true)
                loyaltyMetric(value: "\(unlocked)", label: NSLocalizedString("profile.loyalty.badges", comment: ""))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(profileColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(profileColor.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func loyaltyMetric(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .bodyLG()
                .italic()
                .foregroundColor(palette.primaryText)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .monoLabel(tracking: 0.7)
                .foregroundColor(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Derived CoreData stats

    private var daysSinceJoin: Int {
        let request = NSFetchRequest<DailySong>(entityName: "DailySong")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        request.fetchLimit = 1
        guard let firstEntry = try? context.fetch(request).first,
              let firstDate  = firstEntry.date else { return 0 }
        let cal   = Calendar.current
        let start = cal.startOfDay(for: firstDate)
        let today = cal.startOfDay(for: Date())
        return max(1, (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1)
    }

    private var totalDaysCount: Int {
        let request = NSFetchRequest<DailySong>(entityName: "DailySong")
        return (try? context.count(for: request)) ?? 0
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let request = NSFetchRequest<DailySong>(entityName: "DailySong")
        let songs = (try? context.fetch(request)) ?? []
        let filledDates = Set(songs.compactMap { s -> Date? in
            guard let d = s.date else { return nil }
            return cal.startOfDay(for: d)
        })
        return StreakEngine.compute(
            filledDates: filledDates,
            today: today,
            includeToday: false
        ).count
    }
}
