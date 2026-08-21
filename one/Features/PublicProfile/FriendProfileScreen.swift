//
//  FriendProfileScreen.swift
//  one
//
//  Prototip 20 — arkadaş profili.
//

import SwiftUI
import UIKit
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
/// göstermiyordu — prototipin "ortak uyum" ve "ortak şarkılar"
/// bölümlerinin gerçek veri karşılığı bunlar.
struct FriendProfileScreen: View {
    let userID: String
    /// Bugünkü paylaşımı elde varsa kart doğrudan çizilir (Çevre'den
    /// gelindiğinde ikinci bir sorgu gerekmesin diye).
    var todayShare: CKRecord? = nil
    let onBack: () -> Void

    @StateObject private var vm: PublicProfileViewModel
    @State private var isWorking = false
    @State private var showRemoveConfirm = false
    /// Çözülmüş profil fotoğrafı.
    ///
    /// Eskiden `identity(_:)` view builder'ının içinde
    /// `UIImage(contentsOfFile:)` çağrılıyordu — yani her render'da diskten
    /// okuma + JPEG decode, main thread'de. Doğru desen zaten kod tabanında
    /// var (`PublicProfileHeroSection.loadAvatarIfNeeded`); burada
    /// uygulanmamıştı.
    @State private var avatarImage: UIImage? = nil
    @State private var avatarLoadedForPath: String? = nil

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
                V3Loading(.region)
            } else if let profile {
                VStack(alignment: .leading, spacing: 0) {
                    identity(profile)

                    if let share = todayShare {
                        todayCard(share).padding(.top, V3Tokens.spacingXL)
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
                        .padding(.top, V3Tokens.spacingMD)
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
                            .padding(.vertical, V3Tokens.spacingXL)

                        Button {
                            showRemoveConfirm = true
                        } label: {
                            Text(NSLocalizedString("friendProfile.remove", comment: ""))
                                .bodySMMedium()
                                .foregroundColor(ONEBrand.kor)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .contentShape(Rectangle())
                        .buttonStyle(.onePressable)
                        .disabled(isWorking)
                    }
                }
            } else if let error = vm.errorMessage {
                Text(error)
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, V3Tokens.spacingXL3)
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
        .task(id: profile?.profilePhotoFileURL?.path) {
            await loadAvatarIfNeeded()
        }
    }

    /// Avatarı arka planda okuyup çözer. Aynı yol için tekrar çalışmaz.
    private func loadAvatarIfNeeded() async {
        guard let path = profile?.profilePhotoFileURL?.path else {
            avatarImage = nil
            avatarLoadedForPath = nil
            return
        }
        guard avatarLoadedForPath != path else { return }
        let decoded = await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: path)
        }.value
        avatarImage = decoded
        avatarLoadedForPath = path
    }

    // MARK: Kimlik

    private func identity(_ profile: PublicUserProfile) -> some View {
        HStack(spacing: V3Tokens.spacingLG) {
            // Kişinin yüklediği profil fotoğrafı — eskiden bu ekran her zaman
            // baş harf çiziyordu, fotoğraf hiç okunmuyordu.
            Group {
                if let image = avatarImage {
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
                        .bodySMSemibold()
                        .foregroundColor(V3Tokens.ink)

                    if !moodWord.isEmpty {
                        Text(moodWord)
                            .bodyMicroSemibold()
                            .foregroundColor(Color(hex: moodHex))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: V3Tokens.radiusSwatch, style: .continuous)
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
                    .bodyMicro()
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .oneCardBackground(radius: V3Tokens.radiusPanel)
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
        HStack(spacing: V3Tokens.spacingMD) {
            RoundedRectangle(cornerRadius: V3Tokens.radiusMosaic, style: .continuous)
                .fill(accent.opacity(0.85))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.92))
                )

            Text(title)
                .bodySMSemibold()
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
            .padding(.top, V3Tokens.spacingXL)
            .padding(.bottom, V3Tokens.spacingSM)
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
