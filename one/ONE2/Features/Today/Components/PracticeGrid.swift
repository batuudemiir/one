//
//  PracticeGrid.swift
//  ONE 2.0
//
//  "Pratiklerin" ızgarası (07 §5.1; components/PracticeTile.md zemini):
//  2 sütun (AX3 ve üstünde tek, 07 §9), `surface` karo, 72pt `raised` ikon
//  kuyusu, ad (`headline`), bugün yapıldıysa tik. Karoya dokunma o pratiği
//  bugün için işaretler (tik 180 ms, `light` haptik; 07 §7). Son karo
//  "+ Ekle": şeffaf zemin, 1px `line`. Uzun basma: başa al, sona al, kaldır.
//

import SwiftUI

struct PracticeGrid: View {
    let practices: [PracticeTileData]
    let onToggle: (PracticeTileData) -> Void
    let onAdd: () -> Void
    let onMove: (PracticeTileData, PracticeMove) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize >= .accessibility3 ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: ONE2Space.cardGap, alignment: .top), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: ONE2Space.cardGap) {
            ForEach(practices) { practice in
                PracticeTile(practice: practice) { onToggle(practice) }
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

extension PracticeTileData {
    /// Bugün işaretini çevirir.
    func toggled() -> PracticeTileData {
        PracticeTileData(id: id, title: title, icon: icon, contentID: contentID, isDoneToday: !isDoneToday)
    }
}

private struct PracticeTile: View {
    let practice: PracticeTileData
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: ONE2Space.s4) {
                practice.icon.image(size: ONE2Size.iconWellGlyph)
                    .foregroundStyle(ONE2Color.ink)
                    .frame(width: ONE2Size.iconWell, height: ONE2Size.iconWell)
                    .background(ONE2Color.raised, in: Circle())
                    .overlay(alignment: .bottomTrailing) {
                        if practice.isDoneToday {
                            DoneMark()
                                .transition(ONE2Motion.transition(.scale.combined(with: .opacity), reduceMotion: reduceMotion))
                        }
                    }
                    .animation(ONE2Motion.animation(.chip, reduceMotion: reduceMotion), value: practice.isDoneToday)
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
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(practice.isDoneToday ? one2String("one2.today.practice.done") : ""))
        .accessibilityAddTraits(practice.isDoneToday ? [.isButton, .isSelected] : .isButton)
    }
}

/// Kuyunun köşesinde `ink` disk + tik.
private struct DoneMark: View {
    var body: some View {
        ONE2Icon.check.image(size: ONE2Size.weekTick)
            .fontWeight(.semibold)
            .foregroundStyle(ONE2Color.ground)
            .frame(width: ONE2Size.weekGlyph, height: ONE2Size.weekGlyph)
            .background(ONE2Color.ink, in: Circle())
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
            PracticeGrid(
                practices: practices,
                onToggle: { item in practices = practices.map { $0.id == item.id ? $0.toggled() : $0 } },
                onAdd: {}
            ) { item, move in
                practices = move.apply(to: practices, id: item.id)
            }
            PracticeGrid(practices: [], onToggle: { _ in }, onAdd: {}, onMove: { _, _ in })
        }
    }
}

#Preview("Gece") { PracticeGridSample().one2Preview(.gece) }
#Preview("Gün") { PracticeGridSample().one2Preview(.gun) }
#Preview("AX3") { PracticeGridSample().one2Preview(.ax3) }
#endif
