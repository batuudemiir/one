//
//  WrapLayout.swift
//  ONE 2.0
//
//  Satıra sığmayan öğeyi alt satıra sarar (duygu hapları, neden etiketleri,
//  odak seçenekleri). Sıra korunur; satırlar sola hizalı.
//

import SwiftUI

struct WrapLayout: Layout {
    var spacing: CGFloat = ONE2Space.s2
    var lineSpacing: CGFloat = ONE2Space.s2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#if DEBUG
private struct WrapLayoutSample: View {
    var body: some View {
        WrapLayout {
            ForEach(EmotionCatalogFixture.all.prefix(12)) { item in
                EmotionChip(title: item.name, family: item.family, isSelected: item.id.hasPrefix("huzur")) {}
            }
        }
    }
}

#Preview("Gece") { WrapLayoutSample().one2Preview(.gece) }
#Preview("Gün") { WrapLayoutSample().one2Preview(.gun) }
#Preview("AX3") { WrapLayoutSample().one2Preview(.ax3) }
#endif
