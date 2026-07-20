//
//  SubScreenChrome.swift
//  one
//
//  Alt ekranların ortak dili. Prototipteki .nb / .seg / .stat / .insight /
//  .sgrp / .chip / .state karşılıkları.
//

import SwiftUI

// MARK: - Üst çubuk (.nb)

/// Alt ekran üst çubuğu: solda geri, ortada başlık, sağda opsiyonel eylem.
///
/// `NavigationStack`'in kendi bar'ı kullanılmıyor — prototipte çubuk krem
/// zeminden içeriğe doğru sönen bir gradyan, ayrı bir yüzey değil. Sistem
/// bar'ı bunu veremiyor (kendi materyali ve ayırıcı çizgisi var).
struct SubScreenNavBar: View {
    let title: String
    var actionTitle: String? = nil
    let onBack: () -> Void
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ONETokens.oneInk)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.7)))
                    .overlay(Circle().stroke(ONETokens.oneInk.opacity(0.09), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("general.back", comment: ""))

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ONETokens.oneInk)
                .lineLimit(1)

            Spacer()

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ONETokens.oneBrand)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ONETokens.spacingXL)
        .padding(.bottom, 12)
        .frame(height: 96, alignment: .bottom)
        .background(
            LinearGradient(
                stops: [
                    .init(color: ONETokens.oneCream, location: 0.62),
                    .init(color: ONETokens.oneCream.opacity(0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
}

/// Üst çubuk + kaydırılabilir gövde. Prototipteki `.scroll.sub`
/// (üstten 104pt boşluk) bu sarmalayıcıda toplanıyor ki her ekran
/// aynı sayıyı tekrar yazmasın.
struct SubScreen<Content: View>: View {
    let title: String
    var actionTitle: String? = nil
    let onBack: () -> Void
    var onAction: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            ONETokens.oneCream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                content()
                    .padding(.horizontal, ONETokens.spacingXL)
                    .padding(.top, 104)
                    .padding(.bottom, 116)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SubScreenNavBar(
                title: title,
                actionTitle: actionTitle,
                onBack: onBack,
                onAction: onAction
            )
        }
    }
}

// MARK: - Segment kontrolü (.seg)

struct SegmentedControl: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, label in
                Button {
                    ONEHaptics.tabSwitch()
                    withAnimation(.easeOut(duration: 0.16)) { selection = index }
                } label: {
                    Text(label)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(selection == index ? ONETokens.oneInk : ONETokens.oneAsh)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selection == index ? Color.white : .clear)
                                .shadow(
                                    color: selection == index
                                        ? ONETokens.oneInk.opacity(0.1) : .clear,
                                    radius: 3, y: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(ONETokens.oneInk.opacity(0.055))
        )
    }
}

// MARK: - İstatistik satırı (.stat-row)

struct StatRow: View {
    /// (değer, etiket) üçlüsü. Prototipte hep üç sütun.
    let items: [(value: String, label: String)]

    var body: some View {
        HStack(spacing: 9) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 2) {
                    Text(item.value)
                        .font(.system(size: 23, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(ONETokens.oneInk)
                    Text(item.label)
                        .font(.system(size: 10.5))
                        .foregroundColor(ONETokens.oneAsh)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .oneCardBackground(radius: ONETokens.radiusCardLg)
            }
        }
    }
}

// MARK: - İçgörü kartı (.insight)

struct InsightCard<Content: View>: View {
    var label: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let label {
                Text(label)
                    .monoLabel(tracking: 1.3)
                    .foregroundColor(ONETokens.oneStone)
            }
            content()
        }
        .padding(ONETokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .oneCardBackground(radius: ONETokens.radiusSheet)
    }
}

// MARK: - Ayar grubu (.sgrp / .prow)

/// Satırları tek bir kart içinde toplayan grup. Prototipte ayarlar
/// ekranları bu şekilde bölümlere ayrılıyor.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .oneCardBackground(radius: ONETokens.radiusCardLg)
            .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous))
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var showsChevron: Bool = true
    var isLast: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button { action?() } label: {
            VStack(spacing: 0) {
                HStack(spacing: ONETokens.spacingMD) {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(ONETokens.oneAsh)
                        .frame(width: 22)

                    Text(title)
                        .font(.system(size: 14))
                        .foregroundColor(ONETokens.oneInk)

                    Spacer()

                    if let value {
                        Text(value)
                            .font(.system(size: 13))
                            .foregroundColor(ONETokens.oneStone)
                    }
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(ONETokens.oneStone)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 14)

                if !isLast {
                    Rectangle()
                        .fill(ONETokens.oneInk.opacity(0.09))
                        .frame(height: 1)
                        .padding(.leading, 15)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Çip (.chip)

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? ONETokens.oneCream : ONETokens.oneInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? ONETokens.oneInk : Color.white.opacity(0.7))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            isSelected ? .clear : ONETokens.oneInk.opacity(0.09),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Boş / hata durumu (.state)

struct SubScreenState: View {
    let systemImage: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .light))
                .foregroundColor(ONETokens.oneStone)

            Text(title)
                .displayMD()
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneInk)

            if let message {
                Text(message)
                    .bodySM()
                    .multilineTextAlignment(.center)
                    .foregroundColor(ONETokens.oneAsh)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .bodySMMedium()
                        .foregroundColor(ONETokens.oneCream)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 44)
                        .background(Capsule(style: .continuous).fill(ONETokens.oneInk))
                }
                .buttonStyle(.plain)
                .padding(.top, 5)
            }
        }
        .padding(.horizontal, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Ortak kart zemini

extension View {
    /// Prototipin her yerde tekrarlanan kart zemini:
    /// beyaz %70-78 + 1px hairline. Tek yerde tanımlı ki opaklık
    /// ekrandan ekrana kaymasın.
    func oneCardBackground(radius: CGFloat, opacity: Double = 0.72) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(ONETokens.oneInk.opacity(0.09), lineWidth: 1)
            )
    }
}
