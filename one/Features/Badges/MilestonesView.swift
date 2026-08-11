//
//  MilestonesView.swift
//  one
//
//  Prototipteki "kilometre taşları" — kilitli olan da görünür.
//

import SwiftUI

/// Kilometre taşları listesi.
///
/// Tasarımın tek fikri prototipin alt başlığında: **"kilitliyken de görünür.
/// beklenti de bir ödül."** Kilitli rozeti gizlemek ödülü sürpriz yapar ama
/// beklentiyi yok eder; göstermek ise bir sonraki adımı görünür kılar.
/// Bu yüzden kilitli kartlar soluk ama okunur — silik değil, sessiz.
///
/// `BadgeGalleryView` (2 sütunlu grid) bu ekranın öncülüydü ama hiçbir yerden
/// açılmıyordu. Grid rozetleri eşit ve sırasız gösteriyor; prototip ise
/// **sıralı bir yol** çiziyor: ne açıldı, sırada ne var, ona ne kadar kaldı.
struct MilestonesView: View {
    @ObservedObject private var badges = BadgeManager.shared

    /// Kaç kayıt / kaç günlük seri olduğunu bilmeden "ne kadar kaldı"
    /// yazılamaz — ikisi de dışarıdan verilir.
    let totalEntries: Int
    let streakDays: Int

    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            ONEBrand.bone.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: ONETokens.spacingMD) {
                    Text(NSLocalizedString("milestones.title", comment: ""))
                        .displayLG()
                        .foregroundColor(V3Tokens.ink)

                    Text(NSLocalizedString("milestones.subtitle", comment: ""))
                        .bodySM()
                        .foregroundColor(V3Tokens.mutedText)
                        .padding(.top, -5)

                    ForEach(orderedBadges) { badge in
                        card(for: badge)
                    }
                    .padding(.top, ONETokens.spacingSM)
                }
                .padding(.horizontal, ONETokens.spacingXL)
                .padding(.top, onDismiss != nil ? 90 : ONETokens.spacingXL3)
                .padding(.bottom, 116)
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text(NSLocalizedString("general.back", comment: ""))
                            .bodySMMedium()
                    }
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.horizontal, ONETokens.spacingXL)
                    .padding(.top, ONETokens.spacingXL3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Ordering

    /// Açılanlar önce (en son açılan en üstte), sonra kilitliler yakınlık
    /// sırasına göre. Kullanıcının bir sonraki hedefi hep listenin
    /// kilitli kısmının başında durur.
    private var orderedBadges: [Badge] {
        let unlocked = BadgeCatalog.all
            .filter { badges.isUnlocked($0.id) }
            .sorted { (badges.unlockedAt($0.id) ?? .distantPast) > (badges.unlockedAt($1.id) ?? .distantPast) }

        let locked = BadgeCatalog.all
            .filter { !badges.isUnlocked($0.id) }
            .sorted { (remaining(for: $0) ?? .max) < (remaining(for: $1) ?? .max) }

        return unlocked + locked
    }

    // MARK: Card

    private func card(for badge: Badge) -> some View {
        let isUnlocked = badges.isUnlocked(badge.id)
        let accent = accentColor(for: badge)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: isUnlocked ? badge.iconSystemName : "lock")
                    .font(.system(size: 11, weight: .medium))
                Text(labelText(for: badge, isUnlocked: isUnlocked))
                    .monoLabel(tracking: 1.3)
            }
            .foregroundColor(isUnlocked ? accent : V3Tokens.faintText)

            Text(badge.title)
                .displayMD()
                .foregroundColor(V3Tokens.ink)

            Text(isUnlocked ? badge.description : lockedHint(for: badge))
                .bodySM()
                .foregroundColor(V3Tokens.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ONETokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                .fill(Color.white.opacity(isUnlocked ? 0.80 : 0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                .stroke(
                    isUnlocked ? accent.opacity(0.35) : V3Tokens.ink.opacity(0.07),
                    lineWidth: 1
                )
        )
        // Kilitli kart soluk ama okunur — silinmiş değil, henüz sırası gelmemiş.
        .opacity(isUnlocked ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(badge, isUnlocked: isUnlocked))
    }

    // MARK: Copy

    private func labelText(for badge: Badge, isUnlocked: Bool) -> String {
        guard isUnlocked else { return thresholdText(for: badge) }
        return NSLocalizedString("milestones.unlocked", comment: "")
    }

    /// "7. kayıt", "14 günlük seri" gibi eşiğin kendisi.
    private func thresholdText(for badge: Badge) -> String {
        switch badge.id {
        case .firstShare:   return String(format: NSLocalizedString("milestones.entryThreshold", comment: ""), 1)
        case .totalEntry7:  return String(format: NSLocalizedString("milestones.entryThreshold", comment: ""), 7)
        case .totalEntry30: return String(format: NSLocalizedString("milestones.entryThreshold", comment: ""), 30)
        case .streak3:      return String(format: NSLocalizedString("milestones.streakThreshold", comment: ""), 3)
        case .streak7:      return String(format: NSLocalizedString("milestones.streakThreshold", comment: ""), 7)
        case .streak14:     return String(format: NSLocalizedString("milestones.streakThreshold", comment: ""), 14)
        case .streak30:     return String(format: NSLocalizedString("milestones.streakThreshold", comment: ""), 30)
        case .streak100:    return String(format: NSLocalizedString("milestones.streakThreshold", comment: ""), 100)
        case .firstFriend:  return String(format: NSLocalizedString("milestones.friendThreshold", comment: ""), 1)
        case .fiveFriends:  return String(format: NSLocalizedString("milestones.friendThreshold", comment: ""), 5)
        default:            return NSLocalizedString("milestones.hidden", comment: "")
        }
    }

    /// "23 kayıt sonra açılıyor" — sayılabilen eşikler için mesafe,
    /// sayılamayanlar (gece kuşu, erken kuş) için koşulun kendisi.
    private func lockedHint(for badge: Badge) -> String {
        guard let left = remaining(for: badge) else { return badge.description }

        switch badge.id {
        case .firstShare, .totalEntry7, .totalEntry30:
            return String(format: NSLocalizedString("milestones.entriesLeft", comment: ""), left)
        case .streak3, .streak7, .streak14, .streak30, .streak100:
            return String(format: NSLocalizedString("milestones.daysLeft", comment: ""), left)
        default:
            return badge.description
        }
    }

    /// Eşiğe kalan miktar. nil = sayılamaz (koşullu rozet).
    private func remaining(for badge: Badge) -> Int? {
        switch badge.id {
        case .firstShare:   return max(1 - totalEntries, 0)
        case .totalEntry7:  return max(7 - totalEntries, 0)
        case .totalEntry30: return max(30 - totalEntries, 0)
        case .streak3:      return max(3 - streakDays, 0)
        case .streak7:      return max(7 - streakDays, 0)
        case .streak14:     return max(14 - streakDays, 0)
        case .streak30:     return max(30 - streakDays, 0)
        case .streak100:    return max(100 - streakDays, 0)
        default:            return nil
        }
    }

    /// Açılmış kart eşiğin türüne göre renklenir — seri yeşil-mavi,
    /// kayıt marka rengi, sosyal olanlar mor.
    private func accentColor(for badge: Badge) -> Color {
        switch badge.id {
        case .streak3, .streak7, .streak14, .streak30, .streak100:
            return ONEMood.ozgur.color
        case .firstFriend, .fiveFriends, .monthlyPoster:
            return ONEMood.nostaljik.color
        default:
            return ONETokens.oneBrand
        }
    }

    private func accessibilityLabel(_ badge: Badge, isUnlocked: Bool) -> String {
        let state = isUnlocked
            ? NSLocalizedString("milestones.unlocked", comment: "")
            : NSLocalizedString("milestones.locked", comment: "")
        return "\(badge.title), \(state). \(isUnlocked ? badge.description : lockedHint(for: badge))"
    }
}
