//
//  WeeklyMoodRing.swift
//  one
//
//  Activity Ring-style 7-segment weekly mood visualization.
//  Each segment represents a day (Mon=0 … Sun=6).
//

import SwiftUI

struct WeeklyMoodRing: View {
    let entries: [(date: Date, moodColorHex: String)]
    var ringSize: CGFloat = 48

    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lineWidth: CGFloat = 5.5
    private let gapDeg: Double     = 4.5

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                let segStart = 360.0 / 7.0 * Double(i) + gapDeg / 2 - 90
                let segEnd   = segStart + 360.0 / 7.0 - gapDeg
                let entry     = entryFor(dayIndex: i)
                let rawColor  = entry.map { Color(hex: $0.moodColorHex) ?? Color.gray }
                let color: Color = rawColor ?? .clear
                let filled    = entry != nil

                ArcShape(from: .degrees(segStart), to: .degrees(segEnd))
                    .stroke(
                        filled ? color.opacity(0.16) : Color.gray.opacity(0.09),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )

                if filled {
                    ArcShape(from: .degrees(segStart), to: .degrees(segEnd))
                        .trim(from: 0, to: revealed ? 1 : 0)
                        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .shadow(color: color.opacity(0.45), radius: 2.5)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 0.45).delay(Double(i) * 0.055 + 0.15),
                            value: revealed
                        )
                }
            }
        }
        .frame(width: ringSize, height: ringSize)
        .onAppear { revealed = true }
    }

    private func entryFor(dayIndex: Int) -> (date: Date, moodColorHex: String)? {
        let cal     = Calendar.current
        let today   = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let monOffset = weekday == 1 ? -6 : 2 - weekday
        guard let monday = cal.date(byAdding: .day, value: monOffset, to: today),
              let target = cal.date(byAdding: .day, value: dayIndex, to: monday) else { return nil }
        return entries.first { cal.isDate($0.date, inSameDayAs: target) }
    }
}

private struct ArcShape: Shape {
    let from: Angle
    let to:   Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(
            center:     CGPoint(x: rect.midX, y: rect.midY),
            radius:     min(rect.width, rect.height) / 2,
            startAngle: from,
            endAngle:   to,
            clockwise:  false
        )
        return p
    }
}
