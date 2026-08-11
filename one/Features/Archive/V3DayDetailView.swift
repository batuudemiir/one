//
//  V3DayDetailView.swift
//  one
//
//  v3 gün detayı — bir gündeki TÜM anları listeler.
//
//  Header collapse davranışı: scroll ilerledikçe hero şerit + büyük başlık
//  yukarı kayar; üst kısımda 44pt kompakt sticky bar (mini stripe + tarih·N an)
//  fade in olur. Kapat butonu her zaman erişilebilir.
//
//  Kural: "Bu güne an ekle" CTA yalnızca BUGÜN için gösterilir. Geçmiş
//  günlere retroaktif an eklenmez.
//

import SwiftUI

struct V3DayDetailView: View {
    let day: Day
    let onBack: () -> Void
    /// "Bu güne an ekle" — yalnızca bugün için anlamlı. Container geçse bile
    /// isToday=false ise CTA render edilmez.
    var onAddMoment: (() -> Void)? = nil

    /// Grid'den gelen hero morph namespace'i.
    @Environment(\.archiveDayNamespace) private var envDayNS
    @Namespace private var localDayNS
    private var dayNS: Namespace.ID { envDayNS ?? localDayNS }
    /// Foto viewer için ortak namespace (an fotoğrafı → tam ekran).
    @Environment(\.archivePhotoNamespace) private var envPhotoNS
    @Namespace private var localPhotoNS
    private var photoNS: Namespace.ID { envPhotoNS ?? localPhotoNS }
    @StateObject private var globalUI = GlobalUIState.shared

    @State private var scrollOffset: CGFloat = 0

    private var count: Int { day.moments.count }
    private var countLabel: String { count == 1 ? "1 an" : "\(count) an" }
    private var heroHexes: [String] {
        day.moments.map { $0.moodColorHex }
    }
    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }
    private var canAddMoment: Bool {
        isToday && onAddMoment != nil
    }

    // MARK: - Collapse

    private static let collapseThreshold: CGFloat = 40
    /// 0 → header genişletilmiş, 1 → tamamen kollapse.
    private var collapseProgress: CGFloat {
        let scrolled = max(0, -scrollOffset)
        return min(1, scrolled / Self.collapseThreshold)
    }

    var body: some View {
        ZStack(alignment: .top) {
            V3Tokens.paper.ignoresSafeArea()

            scrollContent

            stickyTopBar

            if canAddMoment, let onAddMoment {
                VStack {
                    Spacer()
                    Button(action: onAddMoment) {
                        Text("Bu güne an ekle")
                            .font(V3Typography.sans(16, weight: .semibold))
                            .foregroundColor(V3Tokens.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                Capsule(style: .continuous).fill(V3Tokens.ink)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: DayDetailScrollOffsetKey.self,
                        value: geo.frame(in: .named("dayDetailScroll")).minY
                    )
            }
            .frame(height: 0)

            VStack(alignment: .leading, spacing: 0) {
                // Hero — grid hücresinden matched-geometry ile gelir.
                // Sticky bar üst-sağda 48pt yer kaplıyor — hero'ya nefes payı
                // ver ki Kapat butonu mood şeridinin üstüne düşmesin.
                DayFill(hexes: heroHexes, cornerRadius: 18)
                    .frame(height: 96)
                    .matchedGeometryEffect(
                        id: V3ArchiveView.cellMorphID(for: day.date),
                        in: dayNS,
                        isSource: true
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 56)

                expandedHeader
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                if day.isEmpty {
                    emptyDayContent
                        .padding(.horizontal, 24)
                        .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(day.moments) { moment in
                            momentCard(moment)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                }
            }
            .padding(.bottom, canAddMoment ? 110 : 32)
        }
        .coordinateSpace(name: "dayDetailScroll")
        .onPreferenceChange(DayDetailScrollOffsetKey.self) { offset in
            scrollOffset = offset
        }
    }

    // MARK: - Sticky top bar (Kapat her zaman erişilebilir)

    private var stickyTopBar: some View {
        HStack(spacing: 12) {
            // Kompakt gün özeti — sadece kollapse'de görünür.
            HStack(spacing: 10) {
                DayFill(hexes: heroHexes, cornerRadius: 2)
                    .frame(width: 32, height: 5)
                Text("\(dateLabel) · \(countLabel.uppercased())")
                    .font(V3Typography.mono(11, weight: .regular))
                    .tracking(1.4)
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(1)
            }
            .opacity(collapseProgress)

            Spacer(minLength: 8)

            Button(action: {
                ONEHaptics.nudge()
                onBack()
            }) {
                Text("Kapat")
                    .font(V3Typography.sans(14, weight: .semibold))
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        ZStack {
                            Capsule(style: .continuous)
                                .fill(V3Tokens.paper)
                            Capsule(style: .continuous)
                                .strokeBorder(V3Tokens.hairline, lineWidth: 1)
                        }
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Arşive geri dön")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            V3Tokens.paper
                .opacity(collapseProgress)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(V3Tokens.hairline)
                        .frame(height: 0.5)
                        .opacity(collapseProgress)
                }
                .ignoresSafeArea(edges: .top)
        )
        .animation(.easeOut(duration: 0.22), value: collapseProgress >= 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(dateLabel), \(countLabel)")
    }

    // MARK: - Expanded header (scroll'la kaybolur)

    private var expandedHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateLabel)
                .font(V3Typography.mono(11, weight: .regular))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.faintText)
            Text(countLabel)
                .font(V3Typography.display(28, weight: .semibold))
                .tracking(-0.8)
                .foregroundColor(V3Tokens.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty day

    private var emptyDayContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(V3Tokens.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(V3Tokens.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 60, height: 60)
            }
            .frame(height: 140)

            Text(emptyTitle)
                .font(ONEBrand.display(30))
                .tracking(-0.8)
                .foregroundColor(V3Tokens.ink)

            if let subtitle = emptySubtitle {
                Text(subtitle)
                    .font(V3Typography.sans(15))
                    .foregroundColor(V3Tokens.mutedText)
            }

            if canAddMoment {
                Button {
                    onAddMoment?()
                } label: {
                    Text("Şimdi ekle")
                        .font(V3Typography.sans(16, weight: .semibold))
                        .foregroundColor(V3Tokens.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule(style: .continuous).fill(V3Tokens.ink))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
    }

    private var emptyTitle: String {
        isToday ? "Bugün henüz bir an yok." : "O gün boş."
    }

    private var emptySubtitle: String? {
        isToday ? "İlk anını şimdi bırak." : nil
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: day.date).uppercased()
    }

    // MARK: - Moment card

    private func momentCard(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill((V3Mood.fromHex(moment.moodColorHex)?.color ?? Color(hex: moment.moodColorHex)))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(timeString(moment.time))
                        .font(V3Typography.mono(11, weight: .regular))
                        .tracking(1.2)
                        .foregroundColor(V3Tokens.faintText)
                    if let label = V3Mood.fromHex(moment.moodColorHex)?.label {
                        Text(label)
                            .font(V3Typography.display(18, weight: .semibold))
                            .tracking(-0.4)
                            .foregroundColor(V3Tokens.ink)
                    }
                }
                Spacer()
            }

            if moment.hasNote {
                Text(moment.note ?? "")
                    .font(V3Typography.sans(15))
                    .foregroundColor(V3Tokens.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            momentPhoto(moment)

            if moment.hasSong, let song = moment.songName, !song.isEmpty {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((V3Mood.fromHex(moment.moodColorHex)?.color ?? Color(hex: moment.moodColorHex)).opacity(0.6))
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song)
                            .font(V3Typography.sans(14, weight: .semibold))
                            .foregroundColor(V3Tokens.ink)
                        if let artist = moment.songArtist {
                            Text(artist)
                                .font(V3Typography.sans(12))
                                .foregroundColor(V3Tokens.mutedText)
                        }
                    }
                    Spacer()
                }
            }

            if moment.scope == .private {
                Text("ARŞİV")
                    .font(V3Typography.mono(10, weight: .regular))
                    .tracking(1.4)
                    .foregroundColor(V3Tokens.ghostText)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        )
    }

    // Local UIImage → archiveMomentImage; URL → archivePhotoURL (mevcut viewer).
    @ViewBuilder
    private func momentPhoto(_ moment: Moment) -> some View {
        if let data = moment.photoData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Fotoğrafı tam ekran aç")
                .onTapGesture {
                    ONEHaptics.moodSelected()
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
                        globalUI.archiveMomentImage = ui
                    }
                }
        } else if let ref = moment.photoRef, let url = URL(string: ref) {
            let isViewerActive = globalUI.archivePhotoURL == url
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(V3Tokens.hairline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .matchedGeometryEffect(id: "archivePhoto", in: photoNS, isSource: !isViewerActive)
            .opacity(isViewerActive ? 0 : 1)
            .contentShape(Rectangle())
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Fotoğrafı tam ekran aç")
            .onTapGesture {
                ONEHaptics.moodSelected()
                withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
                    globalUI.archivePhotoURL = url
                }
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Scroll offset probe

private struct DayDetailScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
