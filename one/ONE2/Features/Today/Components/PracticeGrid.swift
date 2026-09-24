//
//  PracticeGrid.swift
//  ONE 2.0
//
//  "Pratiklerin" ızgarası (components/PracticeTile.md, `.o-tiles`): 2 sütun,
//  `surface` karo, ortada 72pt `raised` ikon kuyusu, altında ad (`headline`).
//  Son karo "+ Ekle": şeffaf zemin, 1px `line`. Uzun basma: öne al, sona
//  al, kaldır.
//  Başlıktaki "düzenle" (sliders) ikonu çizilmedi: uzun basma menüsünden
//  başka işi yok; işlevsiz kontrol olmasın diye.
//

import SwiftUI

struct PracticeGrid: View {
    let practices: [PracticeTileData]
    let onOpen: (PracticeTileData) -> Void
    let onAdd: () -> Void
    let onMove: (PracticeTileData, PracticeMove) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: ONE2Space.cardGap, alignment: .top),
        GridItem(.flexible(), spacing: ONE2Space.cardGap, alignment: .top),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: ONE2Space.cardGap) {
            ForEach(practices) { practice in
                PracticeTile(practice: practice) { onOpen(practice) }
                    .contextMenu {
                        if practice.id != practices.first?.id {
                            Button(one2String("one2.today.practice.moveFirst")) { onMove(practice, .first) }
                        }
                        if practice.id != practices.last?.id {
                            Button(one2String("one2.today.practice.moveLast")) { onMove(practice, .last) }
                        }
                        Button(one2String("one2.today.practice.remove"), role: .destructive) { onMove(practice, .remove) }
                    }
            }
            AddPracticeTile(action: onAdd)
        }
    }
}

nonisolated enum PracticeMove: Sendable {
    case first, last, remove

    /// Yerel sıralama (fixture modunda; UX-11'de kalıcı sıra motorda).
    func apply(to list: [PracticeTileData], id: String) -> [PracticeTileData] {
        guard let index = list.firstIndex(where: { $0.id == id }) else { return list }
        var result = list
        let item = result.remove(at: index)
        switch self {
        case .first:  result.insert(item, at: 0)
        case .last:   result.append(item)
        case .remove: break
        }
        return result
    }
}

private struct PracticeTile: View {
    let practice: PracticeTileData
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: ONE2Space.s4) {
                practice.icon.image(size: ONE2Size.iconWellGlyph)
                    .foregroundStyle(ONE2Color.ink)
                    .frame(width: ONE2Size.iconWell, height: ONE2Size.iconWell)
                    .background(ONE2Color.raised, in: Circle())
                    .accessibilityHidden(true)
                Text(practice.title)
                    .one2Type(.headline)
                    .foregroundStyle(ONE2Color.ink)
                    .multilineTextAlignment(.center)
            }
            .tileFrame()
            .background(ONE2Color.surface, in: ONE2Radius.shape(ONE2Radius.lg))
            .contentShape(Rectangle())
        }
        .buttonStyle(.one2Press)
    }
}

private struct AddPracticeTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: ONE2Space.s2) {
                ONE2Icon.add.image().accessibilityHidden(true)
                Text(one2String("one2.today.practice.add")).one2Type(.headline)
            }
            .foregroundStyle(ONE2Color.inkMuted)
            .tileFrame()
            .overlay {
                ONE2Radius.shape(ONE2Radius.lg)
                    .strokeBorder(ONE2Color.line, lineWidth: ONE2Size.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.one2Press)
    }
}

private extension View {
    /// `.o-tile`: dolgu 20/16, en az 200pt, içerik ortada.
    func tileFrame() -> some View {
        padding(.vertical, ONE2Space.s5)
            .padding(.horizontal, ONE2Space.s4)
            .frame(maxWidth: .infinity, minHeight: ONE2Size.practiceTileMin)
    }
}

#if DEBUG
private struct PracticeGridSample: View {
    @State private var practices = TodayFixture.practices

    var body: some View {
        VStack(spacing: ONE2Space.s8) {
            PracticeGrid(practices: practices, onOpen: { _ in }, onAdd: {}) { item, move in
                practices = move.apply(to: practices, id: item.id)
            }
            PracticeGrid(practices: [], onOpen: { _ in }, onAdd: {}, onMove: { _, _ in })
        }
    }
}

#Preview("Gece") { PracticeGridSample().one2Preview(.gece) }
#Preview("Gün") { PracticeGridSample().one2Preview(.gun) }
#Preview("AX3") { PracticeGridSample().one2Preview(.ax3) }
#endif
