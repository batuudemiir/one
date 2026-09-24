//
//  FlowShapeTests.swift
//  oneTests
//
//  06_giris_akislari.md › Akış 1–4: adım sırası, zorunluluk, kapanış.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

@MainActor
struct FlowShapeTests {

    static func kinds(_ kind: FlowKind, variant: FlowFixtureVariant = .standard) -> [FlowStepKind] {
        FlowFixtures.steps(kind, variant: variant).filter(\.isEnabled).map(\.kind)
    }

    @Test("Akış 1 · mood check-in: skor → duygular → nedenler → not; mühürsüz yankı")
    func moodCheckIn() {
        #expect(Self.kinds(.moodCheckIn) == [.score, .emotions, .causes, .text])
        let steps = FlowFixtures.steps(.moodCheckIn)
        #expect(steps.map(\.optional) == [false, true, true, true])
        #expect(steps[0].options?.count == 5)
        #expect(!(steps[1].options ?? []).isEmpty && !(steps[2].options ?? []).isEmpty)
        #expect(steps[3].prompt != nil)
        let closing = FlowFixtures.flow(.moodCheckIn).closing
        #expect(closing.seal == .none && !closing.echo.isEmpty && closing.week.isEmpty)
    }

    @Test("Duygular aile sırasıyla gelir")
    func emotionsByFamily() {
        let families = (FlowFixtures.steps(.moodCheckIn)[1].options ?? []).compactMap(\.group)
        var seen: [String] = []
        for family in families where seen.last != family { seen.append(family) }
        #expect(seen.count == Set(families).count) // her aile tek blok
    }
}
