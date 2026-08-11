//
//  DiscoverScreen.swift
//  one
//
//  Prototip 23-24 — keşfet ve keşfet detayı.
//

import SwiftUI

/// Keşfet.
///
/// Prototipin alt başlığı ürünün duruşunu söylüyor: **"rengine göre
/// seçilmiş birkaç şey. algoritma değil, editör."** Eski ekran bir
/// akış motoruydu (öneri bölümleri, çapraz mood, tür çipleri, koleksiyonlar,
/// haftalık liste) — çok şey öneriyor, hiçbirini savunmuyordu.
/// Burada az sayıda kart var ve her birinin bir gerekçesi var.
///
/// Motor (`DiscoverViewModel`) aynen duruyor; yalnız sunum daraldı.
struct DiscoverScreen: View {
    @ObservedObject var vm: DiscoverViewModel
    let onBack: () -> Void

    @State private var selectedCategory: String? = nil
    @State private var detail: MoodEvent? = nil

    /// Prototip `.chips`: mood'a bağlı filtreler. Kategoriler eldeki
    /// etkinliklerden türüyor — boş bir filtre gösterilmiyor.
    private var categories: [String] {
        var seen: [String] = []
        for e in allEvents where !seen.contains(e.category.rawValue) {
            seen.append(e.category.rawValue)
        }
        return seen
    }

    private var allEvents: [MoodEvent] {
        ([vm.featuredEvent].compactMap { $0 }) + vm.upcomingEvents
    }

    private var visibleEvents: [MoodEvent] {
        guard let selectedCategory else { return allEvents }
        return allEvents.filter { $0.category.rawValue == selectedCategory }
    }

    var body: some View {
        SubScreen(
            title: NSLocalizedString("discover.title", comment: ""),
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(vm.headlineCopy.headline)
                    .displayLG()
                    .foregroundColor(V3Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(NSLocalizedString("discover.subtitle", comment: ""))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)

                if categories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            FilterChip(
                                title: NSLocalizedString("discover.all", comment: ""),
                                isSelected: selectedCategory == nil
                            ) { selectedCategory = nil }
                                .accessibilityLabel(Text(NSLocalizedString("discover.all", comment: "")))
                                .accessibilityValue(Text(selectedCategory == nil ? "seçili" : "seçili değil"))

                            ForEach(categories, id: \.self) { cat in
                                FilterChip(title: cat, isSelected: selectedCategory == cat) {
                                    selectedCategory = cat
                                }
                                .accessibilityLabel(Text(cat))
                                .accessibilityValue(Text(selectedCategory == cat ? "seçili" : "seçili değil"))
                            }
                        }
                    }
                    .padding(.top, ONETokens.spacingXL)
                    .padding(.bottom, ONETokens.spacingLG)
                }

                if visibleEvents.isEmpty {
                    Text(NSLocalizedString("discover.empty", comment: ""))
                        .bodySM()
                        .foregroundColor(V3Tokens.mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ONETokens.spacingXL3)
                } else {
                    VStack(spacing: 9) {
                        ForEach(visibleEvents) { event in
                            card(event)
                        }
                    }
                    .padding(.top, categories.count > 1 ? 0 : ONETokens.spacingXL)
                }

                Rectangle()
                    .fill(V3Tokens.ink.opacity(0.09))
                    .frame(height: 1)
                    .padding(.vertical, ONETokens.spacingXL)

                // Prototipin kapanış sözü — veri satılmıyor.
                Text(NSLocalizedString("discover.footer", comment: ""))
                    .bodyXS()
                    .multilineTextAlignment(.center)
                    .foregroundColor(V3Tokens.mutedText)
                    .frame(maxWidth: .infinity)
            }
        }
        .fullScreenCover(item: $detail) { event in
            DiscoverDetailScreen(event: event, onBack: { detail = nil })
        }
    }

    /// Prototip `.dc`: üstte renkli bant + tür etiketi, altında başlık,
    /// açıklama ve künye satırı.
    private func card(_ event: MoodEvent) -> some View {
        Button {
            ONEHaptics.feelingSelected()
            detail = event
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [accent(event), accent(event).opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 74)

                    Text(event.category.rawValue.uppercased())
                        .font(V3Typography.sans(10, weight: .semibold))
                        .tracking(1.3)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 11)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(V3Typography.sans(15, weight: .semibold))
                        .foregroundColor(V3Tokens.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(event.reason ?? "\(event.venue) · \(event.city)")
                        .font(V3Typography.sans(12.5))
                        .foregroundColor(V3Tokens.mutedText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(event.timing)
                            .font(V3Typography.sans(11))
                            .foregroundColor(V3Tokens.faintText)

                        if let source = event.sourceLabel, !source.isEmpty {
                            Text(source)
                                .font(V3Typography.sans(9))
                                .tracking(1)
                                .foregroundColor(V3Tokens.faintText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1)
                                )
                        }
                        Spacer()
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                    .stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Kategori kendi rengini taşıyor (`EventCategory.accentColor`) —
    /// mood rengiyle boyamak tüm kartları aynılaştırırdı.
    private func accent(_ event: MoodEvent) -> Color {
        event.category.accentColor
    }
}

// MARK: - 24 · Keşfet detayı

/// Bir öneri.
///
/// Prototipin en alt satırı: **"bu koleksiyon sponsorlu değil."** Sponsorlu
/// olsaydı da aynı yerde yazacaktı — asıl mesele etiketin hep aynı yerde
/// olması. Kullanıcı nereye bakacağını bilirse etikete güvenir.
struct DiscoverDetailScreen: View {
    let event: MoodEvent
    let onBack: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        SubScreen(title: event.title, onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                hero

                if let reason = event.reason, !reason.isEmpty {
                    Text(reason)
                        .bodySM()
                        .foregroundColor(V3Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, ONETokens.spacingLG)
                }

                infoRows.padding(.top, ONETokens.spacingXL)

                Rectangle()
                    .fill(V3Tokens.ink.opacity(0.09))
                    .frame(height: 1)
                    .padding(.vertical, ONETokens.spacingXL)

                if let url = event.sourceURL {
                    Button {
                        openURL(url)
                    } label: {
                        Text(NSLocalizedString("discover.open", comment: ""))
                            .bodySMMedium()
                            .foregroundColor(ONEBrand.bone)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule(style: .continuous).fill(V3Tokens.ink))
                    }
                    .buttonStyle(.plain)
                }

                Text(NSLocalizedString("discover.notSponsored", comment: ""))
                    .bodyXS()
                    .multilineTextAlignment(.center)
                    .foregroundColor(V3Tokens.mutedText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingLG)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(event.category.rawValue) · \(event.timing)")
                .monoLabel(tracking: 1.3)
                .foregroundColor(.white.opacity(0.75))

            Text(event.title)
                .font(V3Typography.sans(29, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Text("\(event.venue) · \(event.city)")
                .font(V3Typography.sans(13.5))
                .foregroundColor(.white.opacity(0.82))
                .padding(.top, 7)
        }
        .padding(ONETokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                .fill(event.category.accentColor)
        )
    }

    private var infoRows: some View {
        SettingsGroup {
            SettingsRow(
                icon: "mappin.and.ellipse",
                title: NSLocalizedString("discover.venue", comment: ""),
                value: event.venue,
                showsChevron: false
            )
            SettingsRow(
                icon: "clock",
                title: NSLocalizedString("discover.timing", comment: ""),
                value: event.timing,
                showsChevron: false
            )
            SettingsRow(
                icon: "tag",
                title: NSLocalizedString("discover.price", comment: ""),
                value: event.price,
                showsChevron: false,
                isLast: true
            )
        }
    }
}
