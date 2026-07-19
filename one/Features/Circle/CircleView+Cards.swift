//
//  CircleView+Cards.swift
//  one
//
//  Card builders extracted from CircleView in Faz 3.1 (2026-04-26):
//  - senCard (user's own daily share card)
//  - friendCard(data:index:) (per-friend share card)
//  - skeletonCards / skeletonCard (loading state)
//  - resonancePill, streakBadge (small inline UI helpers)
//
//  Kept as `extension CircleView` so SwiftUI state remains accessible.
//

import SwiftUI
import CloudKit

extension CircleView {

    // MARK: - Sen Card
    
    @ViewBuilder
    var senCard: some View {
        let hasSong = userHasSharedToday
        let moodColorHex = userShare?["moodColor"] as? String ?? "#5B8DEF"

        senCardCore(hasSong: hasSong, moodColorHex: moodColorHex)
    }

    /// Senin kart'ının ana içeriği — yorum butonundan ayrı, eski tek-kart layout.
    @ViewBuilder
    private func senCardCore(hasSong: Bool, moodColorHex: String) -> some View {
        let songName = userShare?["songName"] as? String ?? ""
        let artistName = userShare?["artistName"] as? String ?? ""
        let moodWord = (userShare?["moodWord"] as? String ?? "").uppercased()
        let time: String = {
            if let d = userShare?["createdAt"] as? Date {
                let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
            }
            return ""
        }()
        let displayName = cloudKitManager.currentUser?["displayName"] as? String ?? "S"
        let initial = String(displayName.prefix(1)).uppercased()
        
        HStack(spacing: ONETokens.spacingLG) {
            // Avatar — profil fotoğrafı > mood rengi > initial
            ZStack {
                if let profilePhoto = ProfileViewModel.loadProfilePhotoFromDisk() {
                    Image(uiImage: profilePhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    hasSong ? Color(hex: moodColorHex).opacity(0.5) : ONETokens.oneCreamLow,
                                    lineWidth: hasSong ? 2 : 1
                                )
                        )
                    if !hasSong {
                        Circle()
                            .stroke(ONETokens.oneAsh,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: 52, height: 52)
                            .opacity(selfPulseOpacity)
                    }
                } else {
                    Circle()
                        .fill(hasSong ? Color(hex: moodColorHex) : ONETokens.oneCreamLow)
                        .frame(width: 52, height: 52)
                    if hasSong {
                        Text(initial)
                            .displaySM()
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        Circle()
                            .stroke(ONETokens.oneAsh,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: 52, height: 52)
                            .opacity(selfPulseOpacity)
                        Text(initial)
                            .displayXS()
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(NSLocalizedString("circle.you", comment: ""))
                        .monoSM(tracking: 1.6)
                        .foregroundColor(ONETokens.oneCharcoal)
                    if hasSong && !moodWord.isEmpty {
                        Circle()
                            .fill(Color(hex: moodColorHex))
                            .frame(width: 6, height: 6)
                        Text(moodWord)
                            .monoSM(tracking: 1.2)
                            .foregroundColor(Color(hex: moodColorHex))
                    }
                    Spacer()
                    streakBadge(days: localCurrentStreak, colorHex: moodColorHex)
                    if !time.isEmpty {
                        Text(time)
                            .monoLabel(tracking: 0.5)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
                if hasSong {
                    Text(songName)
                        .bodySM()
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(artistName)
                        .monoBase()
                        .foregroundColor(ONETokens.oneAsh)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let recordName = userShare?.recordID.recordName {
                        CommentCountPill(shareRecordName: recordName, moodColorHex: moodColorHex)
                            .padding(.top, 2)
                    }
                } else {
                    Text(NSLocalizedString("circle.shareToday", comment: ""))
                        .bodySM()
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.top, 2)
                }
            }
        }
        .padding(ONETokens.spacingLG)
        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            ONEHaptics.feelingSelected()
            if hasSong {
                showSelfDetail = true
            } else {
                onNavigateToToday?()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            if hasSong {
                return String(format: NSLocalizedString("accessibility.circle.senCardShared", comment: ""), songName, artistName, moodWord)
            } else {
                return NSLocalizedString("accessibility.circle.senCardEmpty", comment: "")
            }
        }())
        .accessibilityHint(hasSong ? "" : NSLocalizedString("accessibility.circle.senCardHint", comment: ""))
    }
    
    // MARK: - Friend Card

    func friendCard(data: CloudKitManager.FriendCircleData, index: Int) -> some View {
        let hasSong = data.share != nil && !(data.share!["songName"] as? String ?? "").isEmpty
        let moodColorHex = data.share?["moodColor"] as? String ?? data.user["avatarColor"] as? String ?? "#888888"
        let songName = data.share?["songName"] as? String ?? ""
        let artistName = data.share?["artistName"] as? String ?? ""
        let moodWord = (data.share?["moodWord"] as? String ?? "").uppercased()
        let name = data.user["displayName"] as? String ?? "?"
        let initial = String(name.prefix(1)).uppercased()

        // Çevre Yankısı — kullanıcının bugünkü rengiyle karşılaştır
        let myMoodColorHex = userShare?["moodColor"] as? String ?? ""
        let isResonant = hasSong && !myMoodColorHex.isEmpty
            && Color.hsbHueDifference(hex1: myMoodColorHex, hex2: moodColorHex) <= 20.0
        let time = getTimeString(from: data.share?["createdAt"] as? Date)
        let friendStreak = data.share?["currentStreak"] as? Int ?? 0
        let photoAsset = data.share?["photoAsset"] as? CKAsset
        let photoFileURL = photoAsset?.fileURL
        let profilePhotoAsset = data.user["profilePhoto"] as? CKAsset
        let profilePhotoURL = profilePhotoAsset?.fileURL

        let isUnseen = isUnseenShare(data)
        let friendIsPremium = data.user["isPremium"] as? Int64 == 1

        return HStack(spacing: ONETokens.spacingLG) {
            // Avatar: daily photo > profile photo > mood color circle
            Group {
                if let photoURL = photoFileURL,
                   let uiImg = UIImage(contentsOfFile: photoURL.path) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: moodColorHex).opacity(0.5), lineWidth: 1.5)
                        )
                } else if let profileURL = profilePhotoURL,
                          let uiImg = UIImage(contentsOfFile: profileURL.path) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: moodColorHex).opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Circle()
                        .fill(hasSong ? Color(hex: moodColorHex) : ONETokens.oneStone)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(initial)
                                .displayXS()
                                .foregroundColor(.white.opacity(hasSong ? 0.9 : 0.5))
                        )
                }
            }
            .onTapGesture {
                ONEHaptics.feelingSelected()
                AppAnalytics.shared.track(.friendShareViewed)
                if let uid = data.user["userID"] as? String, !uid.isEmpty {
                    selectedPublicProfileUserID = uid
                } else {
                    selectedFriendData = data
                }
            }
            .overlay(alignment: .topTrailing) {
                if isUnseen {
                    Circle()
                        .fill(Color(hex: moodColorHex))
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(ONETokens.oneCream, lineWidth: 2))
                        .offset(x: 2, y: -2)
                        .accessibilityHidden(true) // Okunmamış nokta — metin label'da belirtiliyor
                } else if friendIsPremium {
                    // ONE+ premium crown badge
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [ONETokens.oneBrand, ONETokens.oneBrandLight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(Circle().stroke(ONETokens.oneCream, lineWidth: 1.5))
                        .offset(x: 3, y: -3)
                        .accessibilityHidden(true) // Premium rozeti — metin label'da belirtiliyor
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name.uppercased())
                        .monoSM(tracking: 1.4)
                        .foregroundColor(ONETokens.oneCharcoal)
                    if hasSong && !moodWord.isEmpty {
                        Circle()
                            .fill(Color(hex: moodColorHex))
                            .frame(width: 5, height: 5)
                        Text(moodWord)
                            .monoSM(tracking: 1.0)
                            .foregroundColor(Color(hex: moodColorHex).opacity(0.85))
                    }
                    // Çevre Yankısı rozeti
                    if isResonant {
                        resonancePill(myHex: myMoodColorHex, friendHex: moodColorHex)
                    }
                    Spacer()
                    if hasSong { streakBadge(days: friendStreak, colorHex: moodColorHex) }
                    if !time.isEmpty {
                        Text(time)
                            .monoLabel(tracking: 0.5)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
                if hasSong {
                    Text(songName)
                        .bodyMD()
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(artistName)
                        .monoSM()
                        .foregroundColor(ONETokens.oneAsh)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let shareRecordName = data.share?.recordID.recordName {
                        CommentCountPill(shareRecordName: shareRecordName, moodColorHex: moodColorHex)
                            .padding(.top, 2)
                    }
                } else {
                    Text(NSLocalizedString("circle.notSharedYet", comment: ""))
                        .bodySM()
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.top, 1)
                }
            }
        }
        .padding(14)
        .opacity(hasSong ? 1.0 : 0.75)
        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            ONEHaptics.feelingSelected()
            if let share = data.share,
               !((share["songName"] as? String) ?? "").isEmpty {
                // Arkadaş bugün paylaşım yapmış → yorum + rezonans içeren detay view
                let profileImg = profilePhotoURL.flatMap { UIImage(contentsOfFile: $0.path) }
                selectedShareItem = IdentifiableCKRecord(share, displayName: name, profilePhoto: profileImg)
            } else {
                // Henüz paylaşım yok → bekleme durumunu gösteren view
                selectedFriendData = data
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            var parts: [String] = [name]
            if hasSong {
                if !moodWord.isEmpty { parts.append(moodWord) }
                parts.append(songName)
                parts.append(artistName)
                if !time.isEmpty { parts.append(time) }
                if isUnseen { parts.append(NSLocalizedString("accessibility.circle.unseen", comment: "")) }
                if isResonant { parts.append(NSLocalizedString("accessibility.circle.resonant", comment: "")) }
                if friendIsPremium { parts.append(NSLocalizedString("accessibility.circle.premium", comment: "")) }
            } else {
                parts.append(NSLocalizedString("circle.notSharedYet", comment: ""))
            }
            return parts.joined(separator: ", ")
        }())
        .accessibilityHint(NSLocalizedString("accessibility.circle.friendCardHint", comment: ""))
        .contextMenu {
            Button(role: .destructive) {
                friendToRemove = data
                showRemoveConfirmation = true
            } label: {
                Label(NSLocalizedString("circle.removeAction", comment: ""), systemImage: "person.badge.minus")
            }
            Button(role: .destructive) {
                friendToBlock = data
                showBlockConfirmation = true
            } label: {
                Label(NSLocalizedString("circle.blockAction", comment: ""), systemImage: "nosign")
            }
        }
    }
    
    // MARK: - Invite Row (inside scroll list)

    // MARK: - Skeleton Loading Cards
    var skeletonCards: some View {
        let count = max(friendsShares.isEmpty ? 3 : min(friendsShares.count + 1, 6), 2)
        let allWidths: [(name: CGFloat, sub: CGFloat)] = [
            (140, 90), (120, 110), (160, 70), (130, 100), (150, 80), (115, 120)
        ]
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(0..<count, id: \.self) { index in
                    skeletonCard(widths: allWidths[index % allWidths.count])
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(
                            ONEAnimation.cardSpring.delay(Double(index) * 0.08),
                            value: isLoading
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, ONETokens.spacingLG)
            .padding(.bottom, 100)
        }
    }

    func skeletonCard(widths: (name: CGFloat, sub: CGFloat)) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(ONETokens.oneCreamMid)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ONETokens.oneCreamMid)
                    .frame(width: widths.name, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(ONETokens.oneSilver)
                    .frame(width: widths.sub, height: 10)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 6)
                .fill(ONETokens.oneSilver)
                .frame(width: 48, height: 48)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusFriend)
                .fill(ONETokens.onePaper)
        )
        .shimmeringCircle()
    }

    var inviteRow: some View {
        Button(action: { showAddFriend = true }) {
            HStack(spacing: 14) {
                // İkon
                ZStack {
                    Circle()
                        .fill(friendsShares.isEmpty ? ONETokens.oneInk.opacity(0.06) : Color.clear)
                        .frame(width: 44, height: 44)
                    Circle()
                        .strokeBorder(
                            friendsShares.isEmpty ? ONETokens.oneInk.opacity(0.18) : ONETokens.oneStone,
                            style: StrokeStyle(lineWidth: 1.5, dash: [2, 3])
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: friendsShares.isEmpty ? "person.badge.plus.fill" : "plus")
                        .font(.system(size: friendsShares.isEmpty ? 15 : 16, weight: .light))
                        .foregroundColor(friendsShares.isEmpty ? ONETokens.oneInk : ONETokens.oneAsh)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("circle.addFriend", comment: ""))
                        .bodySM()
                        .foregroundColor(friendsShares.isEmpty ? ONETokens.oneInk : ONETokens.oneAsh)
                    if friendsShares.isEmpty {
                        Text(NSLocalizedString("circle.inviteHint", comment: ""))
                            .monoLabel(tracking: 0.3)
                            .foregroundColor(ONETokens.oneMist)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ONETokens.oneMist)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(friendsShares.isEmpty
                          ? ONETokens.onePaper.opacity(0.7)
                          : ONETokens.onePaper.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                friendsShares.isEmpty
                                    ? ONETokens.oneInk.opacity(0.1)
                                    : ONETokens.oneCreamLow.opacity(0.8),
                                lineWidth: friendsShares.isEmpty ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(NSLocalizedString("accessibility.circle.addFriend", comment: ""))
        .accessibilityHint(NSLocalizedString("accessibility.circle.addFriendHint", comment: ""))
    }
    
    // CircleEmptyState + CircleCloudKitUnavailableState moved to CircleEmptyStates.swift (Faz 3.1).
    
    // MARK: - Resonance Pill

    @ViewBuilder
    func resonancePill(myHex: String, friendHex: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(Color(hex: myHex)).frame(width: 5, height: 5)
            Circle().fill(Color(hex: friendHex)).frame(width: 5, height: 5)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: myHex).opacity(0.12),
                            Color(hex: friendHex).opacity(0.12)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: myHex).opacity(0.3),
                                    Color(hex: friendHex).opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 0.75
                        )
                )
        )
    }

    // MARK: - Streak Badge

    @ViewBuilder
    func streakBadge(days: Int, colorHex: String) -> some View {
        if days >= 2 {
            HStack(spacing: 3) {
                Text("🔥")
                    .font(.system(size: 9))
                Text("\(days)")
                    .monoMicro(tracking: 0.4)
                    .foregroundColor(Color(hex: colorHex))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color(hex: colorHex).opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: colorHex).opacity(0.3), lineWidth: 0.75)
                    )
            )
        }
    }

}

// MARK: - CircleRhythmStrip

/// Çevrenin günlük streak ritmi — yatay scroll, sıralama yok, giriş sırası korunur.
struct CircleRhythmStrip: View {
    struct Entry {
        let name: String
        let streakDays: Int
        let avatarColorHex: String
        let isSelf: Bool
    }

    let entries: [Entry]

    private let maxBarHeight: CGFloat = 60
    private let minBarHeight: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ÇEVRENİN RİTMİ")
                .monoBase(tracking: 1.5)
                .foregroundColor(ONETokens.oneAsh)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        rhythmBar(entry: entry)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .liquidGlass(.clear, in: RoundedRectangle(cornerRadius: 16))
    }

    private func barHeight(for days: Int) -> CGFloat {
        guard days > 0 else { return minBarHeight }
        let maxDays: CGFloat = 30
        let ratio = min(CGFloat(days) / maxDays, 1.0)
        return minBarHeight + ratio * (maxBarHeight - minBarHeight)
    }

    @ViewBuilder
    private func rhythmBar(entry: Entry) -> some View {
        let color = Color(hex: entry.avatarColorHex)
        VStack(spacing: 4) {
            Text(String(entry.name.prefix(4)).uppercased())
                .monoMicro(tracking: 0.3)
                .foregroundColor(ONETokens.oneAsh)
                .lineLimit(1)

            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(entry.isSelf ? 1.0 : 0.55))
                .frame(width: 22, height: barHeight(for: entry.streakDays))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(entry.isSelf ? color : Color.clear, lineWidth: 1.5)
                )

            Text("\(entry.streakDays)g")
                .monoMicro(tracking: 0.2)
                .foregroundColor(ONETokens.oneStone)
        }
        .frame(width: 28)
    }
}

// MARK: - Comment Count Pill
// BeReal gibi her kart üzerinde speech bubble + sayı gösterir.
// İlk görünümde sayıyı CloudKit'ten çeker; 0 ise gizlenir.

struct CommentCountPill: View {
    let shareRecordName: String
    let moodColorHex: String

    @State private var count: Int = 0
    @State private var loaded = false
    @State private var refreshTrigger = UUID()

    var body: some View {
        Group {
            if loaded && count > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 10, weight: .medium))
                    Text("\(count)")
                        .monoLabel()
                }
                .foregroundColor(Color(hex: moodColorHex).opacity(0.75))
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: loaded)
        .task(id: refreshTrigger) {
            guard !loaded else { return }
            CloudKitManager.shared.fetchCommentCount(shareRecordName: shareRecordName) { n in
                count = n
                loaded = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .commentCountChanged)) { notif in
            guard let name = notif.object as? String, name == shareRecordName else { return }
            loaded = false
            refreshTrigger = UUID()
        }
    }
}
