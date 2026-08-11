//
//  FriendProfileScreen.swift
//  one
//
//  Prototip 20 — arkadaş profili.
//

import SwiftUI
import CloudKit

/// Bir arkadaşın profili.
///
/// Prototipte bu ekran bir vitrin değil, bir **ilişki özeti**: kim,
/// ne zamandır arkadaşsınız, bugün ne bıraktı, nerede örtüşüyorsunuz.
/// Sonda "arkadaşlıktan çıkar" var — gizlenmiş bir menüde değil, açıkta;
/// ilişkiyi bitirmek de ilişkinin bir parçası.
///
/// `PublicUserProfile` modeli `totalShareDays`, `currentStreak`,
/// `dominantMoodWord`, `topTracks` taşıyor ama eski ekran bunları hiç
/// göstermiyordu — prototipin "ortak frekans" ve "ortak şarkılar"
/// bölümlerinin gerçek veri karşılığı bunlar.
struct FriendProfileScreen: View {
    let userID: String
    /// Bugünkü paylaşımı elde varsa kart doğrudan çizilir (Frekans'tan
    /// gelindiğinde ikinci bir sorgu gerekmesin diye).
    var todayShare: CKRecord? = nil
    let onBack: () -> Void

    @StateObject private var vm: PublicProfileViewModel
    @State private var isWorking = false
    @State private var showRemoveConfirm = false

    init(userID: String, todayShare: CKRecord? = nil, onBack: @escaping () -> Void) {
        self.userID = userID
        self.todayShare = todayShare
        self.onBack = onBack
        _vm = StateObject(wrappedValue: PublicProfileViewModel(userID: userID))
    }

    private var profile: PublicUserProfile? { vm.profile }
    private var accent: Color {
        Color(hex: profile?.avatarColorHex ?? "#5B8DEF")
    }

    var body: some View {
        SubScreen(
            title: profile?.displayName ?? "",
            onBack: onBack
        ) {
            if vm.isLoading && profile == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingXL4)
            } else if let profile {
                VStack(alignment: .leading, spacing: 0) {
                    identity(profile)

                    if let share = todayShare {
                        todayCard(share).padding(.top, ONETokens.spacingXL)
                    }

                    if hasStats(profile) {
                        sectionLabel(NSLocalizedString("friendProfile.theirRhythm", comment: ""))
                        statRow(profile)
                    }

                    if let mood = profile.dominantMoodWord, !mood.isEmpty {
                        InsightCard(label: NSLocalizedString("friendProfile.commonFrequency", comment: "")) {
                            (
                                Text(NSLocalizedString("friendProfile.mostlyPrefix", comment: ""))
                                    .foregroundColor(V3Tokens.ink)
                                + Text(mood)
                                    .foregroundColor(Color(hex: profile.dominantMoodColor ?? "#5B8DEF"))
                                    .fontWeight(.semibold)
                                + Text(NSLocalizedString("friendProfile.mostlySuffix", comment: ""))
                                    .foregroundColor(V3Tokens.ink)
                            )
                            .bodySM()
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, ONETokens.spacingMD)
                    }

                    if let tracks = profile.topTracks, !tracks.isEmpty {
                        sectionLabel(NSLocalizedString("friendProfile.commonSongs", comment: ""))
                        VStack(spacing: 3) {
                            ForEach(Array(tracks.prefix(5).enumerated()), id: \.offset) { _, track in
                                trackRow(track)
                            }
                        }
                    }

                    if vm.relationship == .friend {
                        Rectangle()
                            .fill(V3Tokens.ink.opacity(0.09))
                            .frame(height: 1)
                            .padding(.vertical, ONETokens.spacingXL)

                        Button {
                            showRemoveConfirm = true
                        } label: {
                            Text(NSLocalizedString("friendProfile.remove", comment: ""))
                                .bodySMMedium()
                                .foregroundColor(ONEBrand.kor)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                    }
                }
            } else if let error = vm.errorMessage {
                Text(error)
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingXL3)
            }
        }
        .confirmationDialog(
            NSLocalizedString("circle.removeFriend", comment: ""),
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("circle.removeAction", comment: ""), role: .destructive) {
                remove()
            }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) {}
        }
        .task { vm.load() }
    }

    // MARK: Kimlik

    private func identity(_ profile: PublicUserProfile) -> some View {
        HStack(spacing: ONETokens.spacingLG) {
            // Kişinin yüklediği profil fotoğrafı — eskiden bu ekran her zaman
            // baş harf çiziyordu, fotoğraf hiç okunmuyordu.
            Group {
                if let url = profile.profilePhotoFileURL,
                   let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(accent)
                        .overlay(
                            Text(String(profile.displayName.prefix(1)).uppercased())
                                .font(V3Typography.sans(21, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.displayName)
                    .displayMD()
                    .foregroundColor(V3Tokens.ink)

                Text(subtitle(profile))
                    .bodyXS()
                    .foregroundColor(V3Tokens.mutedText)
            }

            Spacer()
        }
    }

    /// "@zeynepk · 4 aydır arkadaşsınız" — süre `joinedAt`'ten değil,
    /// arkadaşlığın kendisinden gelmeli; o veri yoksa yalnız kullanıcı adı.
    private func subtitle(_ profile: PublicUserProfile) -> String {
        var parts: [String] = []
        if let uname = profile.username, !uname.isEmpty { parts.append("@\(uname)") }
        if vm.mutualFriendCount > 0 {
            parts.append(String(
                format: NSLocalizedString("friendProfile.mutualCount", comment: ""),
                vm.mutualFriendCount
            ))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Bugün

    private func todayCard(_ share: CKRecord) -> some View {
        let moodHex = share["moodColor"] as? String ?? "#888888"
        let moodWord = (share["moodWord"] as? String ?? "").lowercased()
        let song = share["songName"] as? String ?? ""
        let artist = share["artistName"] as? String ?? ""
        let time: String = {
            guard let d = share["createdAt"] as? Date else { return "" }
            let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
        }()

        return HStack(spacing: 13) {
            Circle()
                .fill(Color(hex: moodHex))
                .frame(width: 46, height: 46)
                .overlay(
                    Circle().stroke(Color(hex: moodHex), lineWidth: 1.5)
                        .opacity(0.22).padding(-4)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(NSLocalizedString("friendProfile.today", comment: ""))
                        .font(V3Typography.sans(14.5, weight: .semibold))
                        .foregroundColor(V3Tokens.ink)

                    if !moodWord.isEmpty {
                        Text(moodWord)
                            .font(V3Typography.sans(10.5, weight: .semibold))
                            .foregroundColor(Color(hex: moodHex))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color(hex: moodHex).opacity(0.14))
                            )
                    }
                    Spacer(minLength: 4)

                    if !time.isEmpty {
                        Text(time)
                            .monoLabel(tracking: 0.5)
                            .foregroundColor(V3Tokens.faintText)
                    }
                }

                Text("\(song) — \(artist)")
                    .font(V3Typography.sans(12.5))
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .oneCardBackground(radius: ONETokens.radiusFriend, opacity: 0.78)
    }

    // MARK: İstatistik

    private func hasStats(_ p: PublicUserProfile) -> Bool {
        // v3: streak/sayaç yasak — sadece toplam an ve peak saat.
        (p.totalShareDays ?? 0) > 0
    }

    private func statRow(_ p: PublicUserProfile) -> some View {
        StatRow(items: [
            ("\(p.totalShareDays ?? 0)", NSLocalizedString("profile.stat.entries", comment: "")),
            (p.peakActivityHour.map { String(format: "%02d:00", $0) } ?? "—",
             NSLocalizedString("friendProfile.peakHour", comment: ""))
        ])
    }

    private func trackRow(_ title: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(accent.opacity(0.85))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.92))
                )

            Text(title)
                .font(V3Typography.sans(14, weight: .semibold))
                .foregroundColor(V3Tokens.ink)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .monoLabel(tracking: 1.3)
            .foregroundColor(V3Tokens.faintText)
            .padding(.top, ONETokens.spacingXL)
            .padding(.bottom, ONETokens.spacingSM)
    }

    // MARK: Actions

    private func remove() {
        isWorking = true
        CloudKitManager.shared.removeFriend(friendUserID: userID) { _ in
            DispatchQueue.main.async {
                isWorking = false
                onBack()
            }
        }
    }
}
