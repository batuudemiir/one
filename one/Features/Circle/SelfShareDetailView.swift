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
    @State private var showEchoes = false

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
            V3Tokens.paper.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    mainCard
                    echoesSection
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
        .sheet(isPresented: $showEchoes) {
            IncomingReactionsView(
                shareRecordName: share.recordID.recordName,
                myUserID: myUserID,
                accentColorHex: share["moodColor"] as? String ?? "#5B8DEF"
            )
            .v3Sheet(detents: [.large])
        }
        .onAppear {
            withAnimation(ONEAnimation.screenTransition) { appeared = true }
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
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            HStack {
                HStack(spacing: 10) {
                    V3PersonAvatar(name: displayName, colorHex: moodColorHex, size: .small)
                    Text(NSLocalizedString("circle.you", comment: "").uppercased())
                        .monoSM(tracking: 1.6)
                        .foregroundColor(V3Tokens.mutedText)
                }
                Spacer()
                Text(getRelativeTime())
                    .monoLabel(tracking: 0.6)
                    .foregroundColor(V3Tokens.faintText)
            }
            Text(NSLocalizedString("circle.todayFeeling", comment: ""))
                .displayLG()
                .foregroundColor(V3Tokens.ink)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, V3Tokens.channel)
        .padding(.top, V3Tokens.spacingXL5)
        .padding(.bottom, V3Tokens.spacingXL2)
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
                    .contentShape(Rectangle())
                    .buttonStyle(.onePressable)
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
                    .padding(.horizontal, V3Tokens.spacingMD)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    )
                    .padding(V3Tokens.spacingXL)
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
                Text(songName)
                    .displayMD()
                    .foregroundColor(V3Tokens.ink)
                    .tracking(-0.8)
                    .lineLimit(2)

                Text("\(artistName) · \(genre.isEmpty ? platform : genre)")
                    .monoBase(tracking: 0.5)
                    .foregroundColor(V3Tokens.mutedText)

                Rectangle()
                    .fill(V3Tokens.wash)
                    .frame(height: 1)
                    .padding(.vertical, V3Tokens.spacingXS)

                HStack(spacing: V3Tokens.spacingMD) {
                    if !moodWord.isEmpty {
                        HStack(spacing: 6) {
                            Circle().fill(moodColor).frame(width: 7, height: 7)
                            Text(moodWord.uppercased())
                                .monoLabel(tracking: 1.2)
                                .foregroundColor(V3Tokens.mutedText)
                        }
                        .padding(.horizontal, V3Tokens.spacingMD)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(moodColor.opacity(0.12)))
                    }
                }

                HStack(spacing: V3Tokens.spacingMD) {
                    if !weatherDesc.isEmpty {
                        HStack(spacing: 5) {
                            Text(weatherIcon).bodyMicro()
                            Text(weatherDesc).monoLabel().foregroundColor(V3Tokens.mutedText)
                        }
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundColor(V3Tokens.mutedText)
                        Text(platform).monoLabel().foregroundColor(V3Tokens.mutedText)
                    }
                }
                .padding(.top, V3Tokens.spacingXS)

                if let note = dailyNote {
                    VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
                        Text(NSLocalizedString("circle.note", comment: ""))
                            .monoLabel(tracking: 1.5)
                            .foregroundColor(V3Tokens.mutedText)
                        Text(note)
                            .bodySM()
                            .foregroundColor(V3Tokens.ink)
                            .lineSpacing(2)
                            .tracking(-0.2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(V3Tokens.spacingLG)
                    .background(RoundedRectangle(cornerRadius: V3Tokens.radiusInner).fill(moodColor.opacity(0.08)))
                    .padding(.top, V3Tokens.spacingLG)
                }
            }
            .padding(V3Tokens.spacingXL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(V3Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusPanel))
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 8)
        .padding(.horizontal, V3Tokens.spacingXL)
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .animation(ONEAnimation.panelSpring.delay(0.2), value: appeared)
    }

    // MARK: - Yankılar (kendi paylaşımına gelen efemer karşılıklar)

    private var echoesSection: some View {
        Button(action: { ONEHaptics.feelingSelected(); showEchoes = true }) {
            HStack(spacing: V3Tokens.spacingSM) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .medium))
                Text(NSLocalizedString("echoes.title", comment: ""))
                    .monoBase(tracking: 0.5)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(V3Tokens.mutedText)
            .padding(.horizontal, V3Tokens.spacingXL)
            .padding(.vertical, V3Tokens.spacingLG)
            .background(RoundedRectangle(cornerRadius: V3Tokens.radiusCard).fill(V3Tokens.wash))
        }
        .buttonStyle(.onePressable)
        .padding(.horizontal, V3Tokens.spacingXL)
        .padding(.top, V3Tokens.spacingLG)
        .padding(.bottom, V3Tokens.spacingSM)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(0.3), value: appeared)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: V3Tokens.spacingSM) {
                Image(systemName: "chevron.down").monoMicro()
                Text(NSLocalizedString("general.close", comment: ""))
                    .monoBase(tracking: 1.0)
            }
            .foregroundColor(V3Tokens.mutedText)
            .padding(.horizontal, V3Tokens.spacingXL)
            .padding(.vertical, V3Tokens.spacingMD)
            .background(Capsule().stroke(V3Tokens.faintText, lineWidth: 1.5))
        }
        .padding(.top, V3Tokens.spacingXL2)
        .padding(.bottom, V3Tokens.spacingXL4)
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
