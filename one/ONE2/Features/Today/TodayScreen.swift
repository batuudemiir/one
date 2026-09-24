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
    @State private var pickerItems: [PracticePickerItem]?

    var body: some View {
        ONE2TodayView(state: state, actions: actions)
            // Her görünüşte: akıştan ya da söze yazıdan dönünce güncel.
            .task { await reload() }
            .onChange(of: router.notice) { _, _ in Task { await reload() } }
            .sheet(isPresented: Binding(get: { pickerItems != nil }, set: { if !$0 { pickerItems = nil } })) {
                PracticePickerSheet(items: pickerItems ?? [], onAdd: addPractice, onLocked: {
                    pickerItems = nil
                    router.sheet = .paywall
                }, onClose: { pickerItems = nil })
            }
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
            practiceFlow: { practice in
                let id = GuidedFlows.id(from: practice.id)
                guard let journal = env.content.catalog.guided.first(where: { $0.id == id }) else { return nil }
                return GuidedFlows.model(journal, on: today, env: env)
            },
            removePractice: { practice in
                try? env.library.removePractice(practice.id)
                Task { await reload() }
            },
            addPractice: { showPicker(env) },
            openTheme: {
                guard let theme = WriteContexts.todayTheme(env) else { return }
                router.push(.newEntry(prompt: theme.ref), on: .today)
            },
            openProfile: { router.tab = .profile },
            dismissNotice: { router.notice = nil },
            flowDismissed: { Task { await reload() } },
            flowProvider: { kind in LiveFlows.model(kind, on: today, env: env, seed: seed) }
        )
    }

    private func showPicker(_ env: AppEnvironment) {
        let added = Set(((try? env.library.practices()) ?? []).map(\.contentRef))
        // Premium: EntitlementStore gelene kadar kapalı (ADR §8).
        pickerItems = GuidedFlows.pickerItems(env.content.catalog.guided, added: added,
                                              lang: env.profile.profile.contentLang, hasPremium: false)
    }

    private func addPractice(_ item: PracticePickerItem) {
        guard let env = environment else { return }
        _ = try? env.library.addPractice(item.id)
        pickerItems = nil
        Task { await reload() }
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
