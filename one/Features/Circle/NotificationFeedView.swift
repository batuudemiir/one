//
//  NotificationFeedView.swift
//  one
//
//  Prototip 22 — bildirimler. Günlere bölünmüş sade bir akış.
//

import SwiftUI

/// Bildirim akışı.
///
/// Prototipin en anlamlı satırı en altta duruyor: **"ONE günde en fazla bir
/// kez hatırlatır. Beğeni ya da yorum bildirimi yok."** Bu bir özellik
/// listesi değil, bir söz — ekranın altında durması da bilinçli: kullanıcı
/// akışın sonuna geldiğinde neden bu kadar az şey olduğunu anlıyor.
struct NotificationFeedView: View {
    @ObservedObject private var store = CircleNotificationStore.shared
    let onBack: () -> Void
    /// Bir bildirime dokunulunca ilgili kişiye götürür.
    var onOpenUser: ((String) -> Void)? = nil

    private var feed: [CircleNotification] { store.unifiedFeed }

    /// Bugün / bu hafta / daha eski. Prototipte ilk iki grup var;
    /// üçüncüsü gerçek veride kaçınılmaz — 30 günlük geçmiş tutuluyor.
    private var groups: [(label: String, items: [CircleNotification])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekAgo = cal.date(byAdding: .day, value: -7, to: today) else { return [] }

        let todayItems = feed.filter { $0.date >= today }
        let weekItems = feed.filter { $0.date < today && $0.date >= weekAgo }
        let older = feed.filter { $0.date < weekAgo }

        return [
            (NSLocalizedString("notif.today", comment: ""), todayItems),
            (NSLocalizedString("notif.thisWeek", comment: ""), weekItems),
            (NSLocalizedString("notif.earlier", comment: ""), older)
        ].filter { !$0.items.isEmpty }
    }

    var body: some View {
        SubScreen(
            title: NSLocalizedString("notif.title", comment: ""),
            actionTitle: store.unreadCount > 0
                ? NSLocalizedString("notif.markAllRead", comment: "") : nil,
            onBack: onBack,
            onAction: { withAnimation { store.markAllRead() } }
        ) {
            if feed.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                        Text(group.label)
                            .monoLabel(tracking: 1.3)
                            .foregroundColor(V3Tokens.faintText)
                            .padding(.top, index == 0 ? 0 : V3Tokens.spacingXL)
                            .padding(.bottom, V3Tokens.spacingSM)

                        ForEach(group.items) { item in
                            row(item)
                        }
                    }

                    Rectangle()
                        .fill(V3Tokens.ink.opacity(0.09))
                        .frame(height: 1)
                        .padding(.vertical, V3Tokens.spacingXL)

                    Text(NSLocalizedString("notif.promise", comment: ""))
                        .bodyXS()
                        .multilineTextAlignment(.center)
                        .foregroundColor(V3Tokens.mutedText)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Satır

    private func row(_ item: CircleNotification) -> some View {
        Button {
            if let uid = item.relatedUserID, !uid.isEmpty {
                onOpenUser?(uid)
            }
            if !item.isRead {
                store.update(id: item.id) { $0.isRead = true }
            }
        } label: {
            HStack(alignment: .top, spacing: V3Tokens.spacingMD) {
                // Okunmamış işareti solda, satırın dışında — prototipteki
                // `.unread::before`. İçeride bir rozet olsaydı metni iterdi.
                Circle()
                    .fill(item.isRead ? .clear : ONEBrand.kor)
                    .frame(width: 5, height: 5)
                    .padding(.top, 7)

                avatar(item)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .bodyXSSemibold()
                        .foregroundColor(V3Tokens.ink)
                        .multilineTextAlignment(.leading)

                    if !item.body.isEmpty {
                        Text(item.body)
                            .bodyXS()
                            .foregroundColor(V3Tokens.mutedText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 6)

                Text(relativeTime(item.date))
                    .monoLabel(tracking: 0.4)
                    .foregroundColor(V3Tokens.faintText)
                    .padding(.top, 2)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(V3Tokens.ink.opacity(0.09))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.onePressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(item.isRead ? "" : NSLocalizedString("notif.unread", comment: "") + ", ")"
            + "\(item.title). \(item.body)"
        )
    }

    @ViewBuilder
    private func avatar(_ item: CircleNotification) -> some View {
        let color = item.moodColorHex.map { Color(hex: $0) } ?? V3Tokens.hairline

        Circle()
            .fill(color)
            .frame(width: 30, height: 30)
            .overlay(
                Text(item.emoji ?? "")
                    .bodyXS()
            )
    }

    // MARK: Boş durum

    private var emptyState: some View {
        VStack(spacing: 11) {
            SubScreenState(
                systemImage: "bell",
                title: NSLocalizedString("notif.emptyTitle", comment: ""),
                message: NSLocalizedString("notif.promise", comment: "")
            )
        }
        .frame(minHeight: 420)
    }

    // MARK: Zaman

    /// "3sa" / "2g" — mono ve kısa. Tam tarih satırı uzatır, akışta
    /// önemli olan sıra, kesin an değil.
    private func relativeTime(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return NSLocalizedString("notif.now", comment: "") }
        if seconds < 3600 { return "\(Int(seconds / 60))d" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))sa" }
        return "\(Int(seconds / 86_400))g"
    }
}
