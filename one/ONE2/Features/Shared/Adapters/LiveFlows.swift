//
//  LiveFlows.swift
//  ONE 2.0
//
//  Akışların motora bağlanması (UX-11, UX_istekleri.md › 1–8).
//
//  - Adım seed'i `FlowFixtures.steps` ile aynı şablon; içerik canlı:
//    duygu/neden katalogları, günün sorusu ve önceki cevap, günün sözü,
//    sabahın odağı, pratikler (`FlowSeedContent`).
//  - Taslak cihazda, gün başına (`DefaultsFlowDraftStore`).
//  - Son adımda kayıt: mood check-in, girdi, odak, söze yazı, ritüel
//    tamamlama; yankı `EchoEngine`'den. Bugün kartının "tamam" hâli için
//    yankı ve mood cihazda saklanır (`FlowCompletionStore`).
//  - Taşınan maddeler için veri yok (karar gerekli): canlıda soru çıkmaz.
//

import Foundation

// MARK: - Canlı akış

enum LiveFlows {

    /// Günün değişmeyen içeriği; Bugün yüklenirken bir kez hazırlanır.
    static func seed(_ env: AppEnvironment, on day: DayKey) async -> FlowSeedContent {
        var c = FlowSeedContent()
        let catalog = env.content.catalog
        let lang = env.profile.profile.contentLang
        c.emotions = catalog.emotions.filter { $0.active && $0.lang == lang }
            .map { FlowOptionViewData(id: $0.id, label: $0.label, group: $0.family) }
        c.causes = catalog.causes.filter { $0.active && $0.lang == lang }
            .map { FlowOptionViewData(id: $0.id, label: $0.label, group: $0.icon) }
        if let prompt = await env.prompts.dailyPrompt(for: day) {
            c.dailyPrompts = [prompt.text]
            c.previousAnswer = previousAnswer(to: prompt.text, env: env)
        }
        if let quote = await env.quotes.dailyQuote(for: day) {
            c.quote = .init(id: quote.id, text: quote.text, attribution: quote.attribution)
        }
        c.morningFocus = (try? env.day.focus(on: day)) ?? ""
        c.practices = practices(env)
        return c
    }

    /// Aynı soruya günlük check-in'de verilen son cevap.
    static func previousAnswer(to prompt: String, env: AppEnvironment) -> String? {
        let entries = (try? env.journal.entries(kind: .dailyCheckIn)) ?? []
        for entry in entries.reversed() {
            if let answer = entry.answers.first(where: { $0.stepRef == "daily.question" && $0.questionSnapshot == prompt }),
               let text = answer.text, !text.isEmpty {
                return text
            }
        }
        return nil
    }

    static func practices(_ env: AppEnvironment) -> [FlowOptionViewData] {
        let catalog = env.content.catalog
        return ((try? env.library.practices()) ?? []).map { item in
            let id = item.contentRef.hasPrefix("guided:") ? String(item.contentRef.dropFirst("guided:".count)) : item.contentRef
            let title = catalog.guided.first { $0.id == id }?.title ?? item.contentRef
            return FlowOptionViewData(id: item.contentRef, label: title, group: "book")
        }
    }

    static func steps(_ kind: FlowKind, on day: DayKey, env: AppEnvironment, seed: FlowSeedContent) -> [FlowStepViewData] {
        // Niyet adımı sabah yapıldıysa ve bir odak seçildiyse.
        let morningDone = (try? env.day.completion(on: day))?.morningCompletedAt != nil
        let hasFocus = !seed.morningFocus.trimmingCharacters(in: .whitespaces).isEmpty
        let variant: FlowFixtureVariant = kind == .evening && !(morningDone && hasFocus) ? .withoutMorning : .standard
        return FlowFixtures.steps(kind, variant: variant, content: seed)
    }

    /// Akışın view modeli; son adımda kayıt yapar, `onSaved` Bugün'ü tazeler.
    static func model(_ kind: FlowKind, on day: DayKey, env: AppEnvironment, seed: FlowSeedContent,
                      onSaved: @escaping () -> Void = {}) -> FlowViewModel {
        let steps = steps(kind, on: day, env: env, seed: seed)
        let flow = FlowViewData(kind: kind, steps: steps,
                                closing: FlowClosingViewData(seal: FlowEntryMapping.seal(kind), echo: ""))
        let model = FlowViewModel(flow: flow, drafts: DefaultsFlowDraftStore(day: day))
        model.onFinish = { result in
            let closing = try save(result, steps: steps, on: day, env: env)
            onSaved()
            return closing
        }
        return model
    }

    /// Sonucu kaydeder ve kapanışı döndürür.
    static func save(_ result: FlowResult, steps: [FlowStepViewData], on day: DayKey,
                     env: AppEnvironment) throws -> FlowClosingViewData {
        let target: DayKey? = day == env.clock.today ? nil : day
        let answers = FlowEntryMapping.answers(result, steps: steps)
        var entryID: UUID?
        if !answers.isEmpty {
            let entry = try env.journal.create(EntryDraft(kind: FlowEntryMapping.entryKind(result.flow),
                                                          body: FlowEntryMapping.body(answers), answers: answers),
                                               on: target)
            entryID = entry.id
        }
        var checkIn: MoodCheckIn?
        if let mood = FlowEntryMapping.mood(result, steps: steps) {
            checkIn = try env.mood.log(score: mood.score, emotionIDs: mood.emotionIDs, causeIDs: mood.causeIDs,
                                       source: .checkIn, on: target, linkedTo: entryID)
        }
        if let focus = FlowEntryMapping.focus(result, steps: steps) {
            try env.day.setFocus(focus, on: day)
        }
        if let reflection = FlowEntryMapping.quoteReflection(result, steps: steps) {
            let answer = EntryAnswer(kind: .text, stepRef: "\(result.flow.rawValue).quote",
                                     questionSnapshot: reflection.prompt)
            let entry = try env.journal.create(EntryDraft(kind: .quoteReflection, body: reflection.text,
                                                          contentRef: reflection.quote.id,
                                                          contentSnapshot: reflection.prompt,
                                                          answers: [answer], sourceContext: .quote),
                                               on: target)
            try env.exposure.recordWritten(reflection.quote.id, kind: .quote, entryID: entry.id)
        }
        if let card = FlowEntryMapping.ritualCard(result.flow) {
            _ = try env.day.markCompleted(card, on: day)
        }

        let echo = checkIn.flatMap {
            env.echoes.echo(for: EchoInput(score: $0.score, emotionIDs: $0.emotionIDs, causeIDs: $0.causeIDs,
                                           checkInID: $0.id.uuidString))?.text
        } ?? ""
        let labels = (checkIn?.emotionIDs ?? []).compactMap { id in env.content.catalog.emotions.first { $0.id == id }?.label }
        FlowCompletionStore().save(FlowCompletionRecord(echo: echo, score: checkIn?.score, emotionLabels: labels,
                                                        practicesDone: FlowEntryMapping.practicesDone(result, steps: steps)),
                                   result.flow, on: day)
        return FlowClosingViewData(seal: FlowEntryMapping.seal(result.flow), echo: echo,
                                   week: WeekStripAdapter.viewData(WeekStripModel.load(env)))
    }
}
