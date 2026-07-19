//
//  SelfShareDetailView.swift
//  one
//
//  Detail view for the user's own daily share in Circle.
//  Same card layout as FriendShareDetailView, no remove/block actions.
//

import SwiftUI
import CloudKit

struct SelfShareDetailView: View {
    @Environment(\.dismiss) var dismiss
    let share: CKRecord
    @State private var appeared = false
    @State private var showPhotoViewer = false
    @State private var loadedPhotoData: Data? = nil
    @State private var loadedPhotoImage: UIImage? = nil
    @State private var showCommentSheet = false
    @State private var commentCount: Int? = nil

    private var moodColorHex: String { share["moodColor"] as? String ?? "#5B8DEF" }
    private var moodColor: Color { Color(hex: moodColorHex) }
    private var songName: String { share["songName"] as? String ?? "" }
    private var artistName: String { share["artistName"] as? String ?? "" }
    private var moodWord: String { share["moodWord"] as? String ?? "" }
    private var genre: String { share["genre"] as? String ?? "" }
    private var platform: String { share["platform"] as? String ?? "Spotify" }
    private var dailyNote: String? {
        let note = share["dailyNote"] as? String ?? ""
        return note.isEmpty ? nil : note
    }
    private var feeling: FeelingType {
        FeelingType(rawValue: share["feeling"] as? String ?? "calm") ?? .calm
    }
    private var feelingLabel: String {
        let label = share["feelingLabel"] as? String ?? ""
        return label.isEmpty ? FeelingOption.all.first { $0.type == feeling }?.label ?? "" : label
    }
    private var weatherIcon: String {
        let icon = share["weatherIcon"] as? String ?? ""
        return icon.isEmpty ? "☀️" : icon
    }
    private var weatherDesc: String { share["weatherDesc"] as? String ?? "" }
    private var displayName: String {
        CloudKitManager.shared.currentUser?["displayName"] as? String ?? "Sen"
    }
    private var myUserID: String {
        CloudKitManager.shared.currentUser?["userID"] as? String ?? ""
    }

    var body: some View {
        ZStack {
            ONETokens.oneCream.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    mainCard
                    commentThreadSection
                    closeButton
                }
            }
            .scrollDismissesKeyboard(.interactively)

            if showPhotoViewer, let img = loadedPhotoImage {
                PhotoDataViewerSheet(image: img, isPresented: $showPhotoViewer)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .liquidGlassSheetBackground()
        .sheet(isPresented: $showCommentSheet) {
            CommentThreadView(
                shareRecordName: share.recordID.recordName,
                shareOwnerID: myUserID,
                showComposer: false
            )
            .id(share.recordID.recordName)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .onAppear {
            withAnimation(ONEAnimation.screenTransition) { appeared = true }
            CloudKitManager.shared.fetchCommentCount(shareRecordName: share.recordID.recordName) { count in
                self.commentCount = count
            }
        }
        .task {
            guard loadedPhotoData == nil else { return }
            await Task.detached(priority: .userInitiated) {
                if let asset = share["photoAsset"] as? CKAsset,
                   let url = asset.fileURL,
                   let data = try? Data(contentsOf: url) {
                    let decoded = UIImage(data: data)
                    await MainActor.run {
                        loadedPhotoData = data
                        loadedPhotoImage = decoded
                    }
                } else if let data = share["photoData"] as? Data {
                    let decoded = UIImage(data: data)
                    await MainActor.run {
                        loadedPhotoData = data
                        loadedPhotoImage = decoded
                    }
                }
            }.value
        }
        .onReceive(NotificationCenter.default.publisher(for: .commentCountChanged)) { notif in
            guard let name = notif.object as? String,
                  name == share.recordID.recordName else { return }
            CloudKitManager.shared.commentCountCache.removeValue(forKey: name)
            CloudKitManager.shared.fetchCommentCount(shareRecordName: share.recordID.recordName) { count in
                self.commentCount = count
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 10) {
                    Circle()
                        .fill(moodColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(displayName.prefix(1)).uppercased())
                                .monoSM(tracking: 0)
                                .foregroundColor(.white.opacity(0.9))
                        )
                    Text(NSLocalizedString("circle.you", comment: "").uppercased())
                        .monoSM(tracking: 1.6)
                        .foregroundColor(ONETokens.oneAsh)
                }
                Spacer()
                Text(getRelativeTime())
                    .monoLabel(tracking: 0.6)
                    .foregroundColor(ONETokens.oneStone)
            }
            Text(NSLocalizedString("circle.todayFeeling", comment: ""))
                .displayLG()
                .foregroundColor(ONETokens.oneInk)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ONETokens.spacingXL2)
        .padding(.top, ONETokens.spacingXL4)
        .padding(.bottom, 24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
        .animation(ONEAnimation.screenTransition.delay(0.1), value: appeared)
    }

    // MARK: - Main Card

    private var mainCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let data = loadedPhotoData, !data.isEmpty, let uiImage = UIImage(data: data) {
                    Button(action: {
                        withAnimation(ONEAnimation.panelSpring) { showPhotoViewer = true }
                    }) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                            .overlay(
                                ZStack {
                                    Color.black.opacity(0.02)
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .bodySM()
                                        .fontWeight(.medium)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    LinearGradient(
                        stops: [
                            .init(color: moodColor.opacity(0.65), location: 0.0),
                            .init(color: moodColor.opacity(0.35), location: 0.5),
                            .init(color: moodColor.opacity(0.15), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                if let createdAt = share["createdAt"] as? Date {
                    let timeString = formatTime(createdAt)
                    HStack(spacing: 6) {
                        Circle().fill(Color.white.opacity(0.9)).frame(width: 6, height: 6)
                        Text(String(format: NSLocalizedString("today.timeSelected", comment: ""), timeString))
                            .monoLabel(tracking: 1.0)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, ONETokens.spacingMD)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    )
                    .padding(20)
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: ONETokens.spacingLG) {
                Text(songName)
                    .displayMD()
                    .foregroundColor(ONETokens.oneInk)
                    .tracking(-0.8)
                    .lineLimit(2)

                Text("\(artistName) · \(genre.isEmpty ? platform : genre)")
                    .monoBase(tracking: 0.5)
                    .foregroundColor(ONETokens.oneCharcoal)

                Rectangle()
                    .fill(ONETokens.oneCreamLow)
                    .frame(height: 1)
                    .padding(.vertical, 4)

                HStack(spacing: ONETokens.spacingMD) {
                    if !moodWord.isEmpty {
                        HStack(spacing: 6) {
                            Circle().fill(moodColor).frame(width: 7, height: 7)
                            Text(moodWord.uppercased())
                                .monoLabel(tracking: 1.2)
                                .foregroundColor(ONETokens.oneCharcoal)
                        }
                        .padding(.horizontal, ONETokens.spacingMD)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(moodColor.opacity(0.12)))
                    }
                }

                HStack(spacing: ONETokens.spacingMD) {
                    if !weatherDesc.isEmpty {
                        HStack(spacing: 5) {
                            Text(weatherIcon).font(.system(size: 11))
                            Text(weatherDesc).monoLabel().foregroundColor(ONETokens.oneCharcoal)
                        }
                    }
                    HStack(spacing: 5) {
                        Text("🎵").font(.system(size: 11))
                        Text(platform).monoLabel().foregroundColor(ONETokens.oneCharcoal)
                    }
                }
                .padding(.top, 4)

                if let note = dailyNote {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("circle.note", comment: ""))
                            .monoLabel(tracking: 1.5)
                            .foregroundColor(ONETokens.oneAsh)
                        Text(note)
                            .bodySM()
                            .foregroundColor(ONETokens.oneInk)
                            .lineSpacing(2)
                            .tracking(-0.2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ONETokens.spacingLG)
                    .background(RoundedRectangle(cornerRadius: 12).fill(moodColor.opacity(0.08)))
                    .padding(.top, ONETokens.spacingLG)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ONETokens.onePaper)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 20)
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .animation(ONEAnimation.panelSpring.delay(0.2), value: appeared)
    }

    // MARK: - Comment Thread

    private var commentThreadSection: some View {
        Button(action: { showCommentSheet = true }) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill").bodySM()
                Text(commentCount.map { "\($0) Yorum" } ?? "Yorumlar")
                    .monoBase(tracking: 0.5)
                Spacer()
                Image(systemName: "chevron.up").monoBase().fontWeight(.semibold)
            }
            .foregroundColor(ONETokens.oneCharcoal)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(ONETokens.oneCreamLow))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(0.3), value: appeared)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.down").monoMicro()
                Text(NSLocalizedString("general.close", comment: ""))
                    .monoBase(tracking: 1.0)
            }
            .foregroundColor(ONETokens.oneCharcoal)
            .padding(.horizontal, 20)
            .padding(.vertical, ONETokens.spacingMD)
            .background(Capsule().stroke(ONETokens.oneStone, lineWidth: 1.5))
        }
        .padding(.top, 24)
        .padding(.bottom, 40)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: ONEAnimation.durationLong).delay(0.4), value: appeared)
    }

    // MARK: - Helpers

    private func getRelativeTime() -> String {
        guard let createdAt = share["createdAt"] as? Date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = LanguageManager.shared.currentLocale
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
