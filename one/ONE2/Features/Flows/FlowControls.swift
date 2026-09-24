//
//  FlowControls.swift
//  ONE 2.0
//
//  Akış adımlarının kontrolleri (ScoreScale.md, EmotionChip.md,
//  CauseTag.md): skor ölçeği, duygu çipi, neden etiketi, satır kıran
//  yerleşim, büyüyen serif alan.
//

import SwiftUI

// MARK: - Skor ölçeği

/// Beş 60pt disk, her biri `score-N` renginde ve rakamlı; altında etiket.
/// Seçili: zeminle boşluk + `ink` halka. VoiceOver: "4, İyi".
struct ScoreScaleView: View {
    let options: [FlowOptionViewData]
    let selected: Int?
    let onSelect: (Int) -> Void

    static let diskSize: CGFloat = 60

    var body: some View {
        HStack(alignment: .top, spacing: V3Tokens.spacingSM) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                let value = index + 1
                Button {
                    ONEHaptics.pick()
                    onSelect(value)
                } label: {
                    VStack(spacing: V3Tokens.spacingSM) {
                        ZStack {
                            Circle().fill(V3Tokens.score(value))
                            Text(verbatim: "\(value)")
                                .displaySM()
                                .foregroundColor(V3Tokens.onScore(value))
                        }
                        .frame(maxWidth: Self.diskSize)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            // Seçili: zeminle boşluk + halka; yerleşimi etkilemez.
                            if selected == value {
                                Circle()
                                    .strokeBorder(V3Tokens.ink, lineWidth: 2)
                                    .padding(-V3Tokens.spacingXS)
                            }
                        }
                        .padding(.top, V3Tokens.spacingXS)
                        Text(option.label)
                            .bodyXS()
                            .foregroundColor(selected == value ? V3Tokens.ink : V3Tokens.mutedText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.onePressable)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(value), \(option.label)")
                .accessibilityAddTraits(selected == value ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

// MARK: - Duygu çipi

/// Seçilmemiş: kuyu hap + aile noktası. Seçili: aile dolgusu + uygun metin.
struct EmotionChipView: View {
    let option: FlowOptionViewData
    let isSelected: Bool
    let onToggle: () -> Void

    static let dotSize: CGFloat = 10

    var body: some View {
        Button {
            ONEHaptics.pick()
            onToggle()
        } label: {
            HStack(spacing: V3Tokens.spacingSM) {
                if !isSelected {
                    Circle()
                        .fill(V3Tokens.emotion(option.group))
                        .frame(width: Self.dotSize, height: Self.dotSize)
                        .accessibilityHidden(true)
                }
                Text(option.label)
                    .bodyMDMedium()
                    .foregroundColor(isSelected ? V3Tokens.onEmotion(option.group) : V3Tokens.ink)
            }
            .padding(.horizontal, V3Tokens.spacingLG)
            .frame(minHeight: V3Tokens.minTouchTarget)
            .background(Capsule(style: .continuous)
                .fill(isSelected ? V3Tokens.emotion(option.group) : V3Tokens.wash))
            .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Neden etiketi

/// Çerçeveli etiket (`lineStrong`), duygu hapından bilerek farklı.
/// Seçili: `brandSoft` + `onBrandSoft`.
struct CauseTagView: View {
    let label: String
    let isSelected: Bool
    var systemImage: String?
    let onTap: () -> Void

    var body: some View {
        Button {
            ONEHaptics.pick()
            onTap()
        } label: {
            HStack(spacing: V3Tokens.spacingXS) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .iconSM()
                        .accessibilityHidden(true)
                }
                Text(label)
                    .bodyMDMedium()
            }
            .foregroundColor(isSelected ? V3Tokens.onBrandSoft : V3Tokens.ink)
            .padding(.horizontal, V3Tokens.spacingMD)
            .frame(minHeight: V3Tokens.minTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: V3Tokens.radiusChip, style: .continuous)
                    .fill(isSelected ? V3Tokens.brandSoft : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V3Tokens.radiusChip, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : V3Tokens.lineStrong, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Satır kıran yerleşim

/// Çipleri soldan sağa dizer, sığmayanı alt satıra atar.
struct WrapLayout: Layout {
    var spacing: CGFloat = V3Tokens.spacingSM

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.init(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .init(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.init(width: width, height: nil))
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}

// MARK: - Büyüyen serif alan

/// Tek satırdan büyüyen serif yazı alanı (`journal`).
struct GrowingSerifField: View {
    @Binding var text: String
    var placeholder = NSLocalizedString("one2.reflection.placeholder", comment: "Empty editor placeholder")
    var accessibilityLabel: String?
    /// "Tek satır" cevap (sabahın söz adımı): büyümez.
    var singleLine = false

    var body: some View {
        TextField(placeholder, text: $text, axis: singleLine ? .horizontal : .vertical)
            .font(V3Typography.journal())
            .foregroundColor(V3Tokens.ink)
            .tint(V3Tokens.ink)
            .lineSpacing(11)
            .lineLimit(singleLine ? 1...1 : 1...Int.max)
            .padding(.vertical, V3Tokens.spacingSM)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(V3Tokens.hairline)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(accessibilityLabel ?? placeholder)
    }
}
