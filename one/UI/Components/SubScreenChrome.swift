//
//  SubScreenChrome.swift
//  one
//
//  Alt ekranların ortak dili. Prototipteki .nb / .seg / .stat / .insight /
//  .sgrp / .chip / .state karşılıkları.
//

import SwiftUI

// MARK: - Üst çubuk (.nb)

/// Alt ekran üst çubuğu: solda geri, yanında başlık, sağda opsiyonel eylem.
///
/// Artık `V3TopBar`'ın ince bir sarmalayıcısı. Eskiden kendi çubuğunu
/// çiziyordu ve iki sorunu vardı: 96pt yüksekliğiyle sekme köklerinin
/// çubuğundan iki kat kalındı (aynı uygulamada iki farklı header dili), ve
/// zemini `ONEBrand.bone` + `Color.white.opacity(0.7)` ile **sabit açık
/// temaydı** — koyu temada krem bir şerit olarak duruyordu.
struct SubScreenNavBar: View {
    let title: String
    var actionTitle: String? = nil
    let onBack: () -> Void
    var onAction: (() -> Void)? = nil
    /// Zemin opaklığı. Kendi scroll'u olmayan çağrılarda 1 (düz `paper`);
    /// `SubScreen` bunu kendi scroll offset'inden besliyor.
    var progress: CGFloat = 1

    var body: some View {
        V3TopBar(
            leading: .back(onBack),
            title: title,
            titleMode: .always,
            progress: progress
        ) {
            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .bodyXSSemibold()
                        .foregroundColor(ONEBrand.kor)
                        .padding(.horizontal, 4)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.onePressable)
            }
        }
    }
}

/// Üst çubuk + kaydırılabilir gövde. Alt ekranların tamamı bunu kullanıyor,
/// yani buradaki her karar on bir ekrana birden iniyor.
///
/// Üstten boşluk artık elle yazılan bir sayı değil (`.padding(.top, 104)`),
/// `safeAreaInset`: çubuk gövdeye kendi yüksekliği kadar pay bıraktırıyor ve
/// içerik kaydırılırken **altından geçiyor** — kök sekmelerdeki davranışın
/// aynısı.
struct SubScreen<Content: View>: View {
    let title: String
    var actionTitle: String? = nil
    let onBack: () -> Void
    var onAction: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    /// Bu ekrana özgü scroll uzayı — aynı anda birden fazla alt ekran
    /// yığında canlı olabiliyor, isim çakışırsa offset'ler karışır.
    @State private var spaceName = "one.scroll.sub.\(UUID().uuidString)"
    @State private var progress: CGFloat = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            Color.clear.frame(height: 0)
                .scrollOffsetSensor(spaceName: spaceName)

            content()
                // Üst çubukla aynı hat. Eskiden `V3Tokens.spacingXL` (22)
                // idi ve başlık ile gövde her alt ekranda 2pt kaçıktı.
                .padding(.horizontal, V3Tokens.channel)
                .padding(.top, 8)
                .padding(.bottom, 116)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(V3Tokens.paper.ignoresSafeArea())
        .topBarProgress($progress, spaceName: spaceName)
        .safeAreaInset(edge: .top, spacing: 0) {
            SubScreenNavBar(
                title: title,
                actionTitle: actionTitle,
                onBack: onBack,
                onAction: onAction,
                progress: progress
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
                    withAnimation(ONEAnimation.easingChip) { selection = index }
                } label: {
                    Text(label)
                        .bodyMicroSemibold()
                        .foregroundColor(selection == index ? V3Tokens.ink : V3Tokens.mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selection == index ? V3Tokens.surface : .clear)
                                .shadow(
                                    color: selection == index
                                        ? V3Tokens.ink.opacity(0.1) : .clear,
                                    radius: 3, y: 1
                                )
                        )
                }
                .buttonStyle(.onePressable)
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(V3Tokens.ink.opacity(0.055))
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
                        .font(V3Typography.sans(23, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(V3Tokens.ink)
                    Text(item.label)
                        .bodyMicro()
                        .foregroundColor(V3Tokens.mutedText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .oneCardBackground(radius: V3Tokens.radiusCard)
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
                    .foregroundColor(V3Tokens.faintText)
            }
            content()
        }
        .padding(V3Tokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .oneCardBackground(radius: V3Tokens.radiusPanel)
    }
}

// MARK: - Ayar grubu (.sgrp / .prow)

/// Satırları tek bir kart içinde toplayan grup. Prototipte ayarlar
/// ekranları bu şekilde bölümlere ayrılıyor.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .oneCardBackground(radius: V3Tokens.radiusCard)
            .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous))
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
                HStack(spacing: V3Tokens.spacingMD) {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(V3Tokens.mutedText)
                        .frame(width: 22)

                    Text(title)
                        .bodySM()
                        .foregroundColor(V3Tokens.ink)

                    Spacer()

                    if let value {
                        Text(value)
                            .bodyXS()
                            .foregroundColor(V3Tokens.faintText)
                    }
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(V3Tokens.faintText)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 14)

                if !isLast {
                    Rectangle()
                        .fill(V3Tokens.hairline)
                        .frame(height: 1)
                        .padding(.leading, 15)
                }
            }
        }
        .buttonStyle(.onePressable)
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
                .bodyMicroSemibold()
                .foregroundColor(isSelected ? ONEBrand.bone : V3Tokens.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? V3Tokens.ink : V3Tokens.surface)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            isSelected ? .clear : V3Tokens.hairline,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.onePressable)
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
                .foregroundColor(V3Tokens.faintText)

            Text(title)
                .displayMD()
                .multilineTextAlignment(.center)
                .foregroundColor(V3Tokens.ink)

            if let message {
                Text(message)
                    .bodySM()
                    .multilineTextAlignment(.center)
                    .foregroundColor(V3Tokens.mutedText)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .bodySMMedium()
                        .foregroundColor(ONEBrand.bone)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 44)
                        .background(Capsule(style: .continuous).fill(V3Tokens.ink))
                }
                .buttonStyle(.onePressable)
                .padding(.top, 5)
            }
        }
        .padding(.horizontal, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Kart zemini burada değil — `View+ONE.swift`'te `oneCardBackground(radius:)`.
//
// Bir ara ikisi de vardı: buradaki `opacity:` parametresi alıyordu ama onu
// hiç kullanmıyordu (yorumunda "kullanılmıyor" yazılıydı), ve altı çağrı
// noktası o ölü parametreyi geçiyordu. İki aşırı yükleme aynı isimde
// durduğu sürece hangi çağrının hangisine gittiği okunarak anlaşılamıyordu.
// Ölü parametre çağrı yerlerinden düştü, tanım tek yere indi.

// MARK: - Anahtarlı satır

/// Açma/kapama satırı. `SettingsRow` bir hedefe götürür, bu satır yerinde
/// bir durumu değiştirir — o yüzden ayrı: chevron yok, dokunulacak şey
/// satırın tamamı değil anahtarın kendisi.
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .bodySMSemibold()
                        .foregroundColor(V3Tokens.ink)
                    Text(subtitle)
                        .bodyXS()
                        .foregroundColor(V3Tokens.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(V3Tokens.ink)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)

            if !isLast {
                Rectangle()
                    .fill(V3Tokens.hairline)
                    .frame(height: 1)
                    .padding(.leading, 15)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
