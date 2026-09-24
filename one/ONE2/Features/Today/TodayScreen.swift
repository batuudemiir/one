//
//  TodayScreen.swift
//  ONE 2.0
//
//  Bugün sekmesi: 06_giris_akislari.md'deki ekran (ONE2TodayView), gerçek
//  veriyle (TodayLive). Akışlar tam ekran açılır; kapanınca ekran tazelenir.
//  Söze yazı kapanışı da buraya döner (Router.finishWriting).
//

import Foundation
import SwiftUI

struct TodayScreen: View {
    @Environment(\.one2) private var environment
    @Environment(Router.self) private var router

    @State private var state: TodayViewState = .loading
    @State private var seed = FlowSeedContent()

    var body: some View {
        ONE2TodayView(state: state, actions: actions)
            // Her görünüşte: akıştan ya da söze yazıdan dönünce güncel.
            .task { await reload() }
            .onChange(of: router.notice) { _, _ in Task { await reload() } }
    }

    private var actions: TodayActions {
        guard let env = environment else { return TodayActions() }
        let today = env.clock.today
        let backfillKind: FlowKind = env.profile.profile.ritualMode == .daily ? .daily : .evening
        return TodayActions(
            backfillFlow: { day in
                guard let key = DayKey(day.id) else { return nil }
                return LiveFlows.model(backfillKind, on: key, env: env, seed: seed)
            },
            openProfile: { router.tab = .profile },
            dismissNotice: { router.notice = nil },
            flowDismissed: { Task { await reload() } },
            flowProvider: { kind in LiveFlows.model(kind, on: today, env: env, seed: seed) }
        )
    }

    private func reload() async {
        guard let env = environment else { return }
        let notice = router.notice == .circleUnavailable
            ? NSLocalizedString("one2.notice.circleUnavailable", comment: "Old Circle/invite link opened in ONE 2.0")
            : nil
        let loaded = await TodayLive.load(env, notice: notice)
        seed = loaded.seed
        state = .loaded(loaded.data)
    }
}
