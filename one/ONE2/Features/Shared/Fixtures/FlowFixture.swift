//
//  FlowFixture.swift
//  ONE 2.0
//
//  ÖRNEK VERİ (ID'ler `fx_` önekli). Dört giriş akışı (07 §5.2), adım sırası
//  ve türleri belgeyle birebir. Sabit sorular (skor, uyku, odak, niyet) ve
//  adım başlıkları dize tablosundan; havuzdan gelen sorular (E4) burada
//  örnek metin. UX-11'de motor adaptörü aynı `FlowViewData`'yı doldurur.
//

import Foundation

nonisolated enum FlowFixture {

    // MARK: - Seçenekler

    /// 07 §5.2 Akış 1: neden etiketleri (motor kataloğunda `c_*`).
    static let causes: [FlowOptionData] = [
        ("c_is", "İş"), ("c_okul", "Okul"), ("c_aile", "Aile"), ("c_iliski", "İlişki"),
        ("c_arkadaslar", "Arkadaşlar"), ("c_uyku", "Uyku"), ("c_saglik", "Sağlık"),
        ("c_spor", "Spor"), ("c_hava", "Hava"), ("c_para", "Para"), ("c_kendim", "Kendim"),
    ].map { FlowOptionData(id: $0.0, title: $0.1) }
        + [FlowOptionData(id: "c_custom", title: one2String("one2.flow.causes.add"), isCustomEntry: true)]

    /// 07 §5.2 Akış 3: odak seçenekleri, sonda "Kendi kelimen".
    static let focusOptions: [FlowOptionData] = [
        "calm", "patience", "discipline", "courage", "kindness", "gratitude", "focus", "selfCare",
    ].map { FlowOptionData(id: $0, title: one2String("one2.flow.focus.\($0)")) }
        + [FlowOptionData(id: "custom", title: one2String("one2.flow.focus.custom"), isCustomEntry: true)]

    // MARK: - Adımlar

    private static func score(_ id: String, _ titleKey: String) -> FlowStepViewData {
        FlowStepViewData(id: id, kind: .score, title: one2String(titleKey), prompt: nil, optional: false, options: nil)
    }

    private static func emotions(_ id: String) -> FlowStepViewData {
        FlowStepViewData(id: id, kind: .emotions, title: one2String("one2.flow.q.emotions"), prompt: nil,
                         optional: true, options: nil, emotions: EmotionCatalogFixture.all)
    }

    private static func causes(_ id: String) -> FlowStepViewData {
        FlowStepViewData(id: id, kind: .causes, title: one2String("one2.flow.q.causes"), prompt: nil,
                         optional: true, options: causes)
    }

    private static func text(_ id: String, _ labelKey: String, _ prompt: String, optional: Bool,
                             previous: PreviousAnswerData? = nil) -> FlowStepViewData {
        FlowStepViewData(id: id, kind: .text, title: one2String(labelKey), prompt: prompt,
                         optional: optional, options: nil, previous: previous)
    }

    private static func list3(_ id: String, _ labelKey: String, _ prompt: String, optional: Bool) -> FlowStepViewData {
        FlowStepViewData(id: id, kind: .list3, title: one2String(labelKey), prompt: prompt, optional: optional, options: nil)
    }

    static let previousAnswer = PreviousAnswerData(
        date: FixtureClock.daysAgo(34, 21, 30),
        text: "Otobüste yanımdaki çocuğun kitabını yüksek sesle okuması. Kimse rahatsız olmadı, herkes biraz dinledi. Ben de indiğim durağı kaçırdım."
    )

    // MARK: - Akışlar

    /// Akış 1: mood check-in (~30 sn). `first`: ilk check-in, mühürlü kapanış.
    static func moodCheckIn(day: DayKey = FixtureClock.today, draft: FlowDraftData? = nil, first: Bool = false) -> FlowViewData {
        FlowViewData(
            id: "fx_flow_mood",
            kind: .moodCheckIn,
            day: day,
            steps: [
                score("mood.score", "one2.flow.q.nowFeeling"),
                emotions("mood.emotions"),
                causes("mood.causes"),
                text("mood.note", "one2.flow.label.note", one2String("one2.flow.q.anythingElse"), optional: true),
            ],
            closing: first ? .seal(.firstDay) : .echo,
            minutes: 1,
            draft: draft,
            echo: "Yorgunluğunu fark etmek, onu taşımayı biraz kolaylaştırır."
        )
    }

    /// Akış 2: günlük check-in (~2 dk).
    static func dailyCheckIn(day: DayKey = FixtureClock.today, draft: FlowDraftData? = nil) -> FlowViewData {
        FlowViewData(
            id: "fx_flow_daily",
            kind: .dailyCheckIn,
            day: day,
            steps: [
                score("daily.score", "one2.flow.q.todayFeeling"),
                emotions("daily.emotions"),
                causes("daily.causes"),
                text("daily.question", "one2.flow.label.dailyQuestion",
                     "Bugün seni küçük de olsa ne şaşırttı?", optional: false, previous: previousAnswer),
                list3("daily.gratitude", "one2.flow.label.gratitude", "Bugün neye minnettarsın?", optional: true),
            ],
            closing: .seal(.dayClosed),
            minutes: 2,
            draft: draft,
            echo: "Şaşırmak, günün hâlâ açık olduğunu gösterir."
        )
    }

    /// Akış 3: sabah hazırlığı (~2 dk). Duygular bu akışta varsayılan kapalı.
    static func morning(day: DayKey = FixtureClock.today, draft: FlowDraftData? = nil) -> FlowViewData {
        FlowViewData(
            id: "fx_flow_morning",
            kind: .morning,
            day: day,
            steps: [
                FlowStepViewData(id: "morning.sleep", kind: .sleep, title: one2String("one2.flow.q.sleep"),
                                 prompt: nil, optional: false, options: nil),
                score("morning.score", "one2.flow.q.startingDay"),
                FlowStepViewData(id: "morning.focus", kind: .focus, title: one2String("one2.flow.q.focus"),
                                 prompt: nil, optional: false, options: focusOptions),
                FlowStepViewData(id: "morning.quote", kind: .quote, title: one2String("one2.flow.label.quote"),
                                 prompt: "Bu söz bugün sana ne söylüyor?", optional: true, options: nil,
                                 quote: QuotesFixture.many[4]),
                list3("morning.top3", "one2.flow.label.topThree", "Bugünün en önemli bir, iki, üç şeyi?", optional: false),
                text("morning.challenge", "one2.flow.label.challenge",
                     "Bugün seni ne zorlayabilir, nasıl karşılarsın?", optional: true),
            ],
            closing: .seal(.dayReady),
            minutes: 2,
            draft: draft,
            echo: "Sabır bugün senin kelimen."
        )
    }

    /// Akış 4: akşam değerlendirmesi (~3 dk). `morningFocus` yoksa niyet adımı yok.
    static func evening(day: DayKey = FixtureClock.today, draft: FlowDraftData? = nil,
                        morningFocus: String? = one2String("one2.flow.focus.patience")) -> FlowViewData {
        var steps: [FlowStepViewData] = [
            score("evening.score", "one2.flow.q.dayWas"),
            emotions("evening.emotions"),
            causes("evening.causes"),
        ]
        if let morningFocus {
            steps.append(FlowStepViewData(
                id: "evening.intention", kind: .intentionReview,
                title: String(format: one2String("one2.flow.q.intention"), morningFocus),
                prompt: nil, optional: false, options: nil))
        }
        steps += [
            FlowStepViewData(id: "evening.practices", kind: .practices, title: one2String("one2.flow.q.practices"),
                             prompt: nil, optional: false, options: nil, practices: TodayFixture.practices),
            text("evening.good", "one2.flow.label.goodThing", "Bugün iyi giden bir şey?", optional: false),
            text("evening.different", "one2.flow.label.different", "Tekrar yaşasan neyi farklı yapardın?", optional: false),
            list3("evening.gratitude", "one2.flow.label.gratitude", "Neye minnettarsın?", optional: true),
            text("evening.note", "one2.flow.label.note", one2String("one2.flow.q.anythingElseShort"), optional: true),
        ]
        return FlowViewData(
            id: "fx_flow_evening",
            kind: .evening,
            day: day,
            steps: steps,
            closing: .seal(.dayClosed),
            minutes: 3,
            draft: draft,
            echo: "Yarım kalan da bir şey söyler; bugün dinledin.",
            carryOver: morningFocus == nil ? [] : ["Sunumun son iki sayfası"]
        )
    }

    static func flow(_ kind: FlowKind, day: DayKey = FixtureClock.today, draft: FlowDraftData? = nil) -> FlowViewData {
        switch kind {
        case .moodCheckIn:  return moodCheckIn(day: day, draft: draft)
        case .dailyCheckIn: return dailyCheckIn(day: day, draft: draft)
        case .morning:      return morning(day: day, draft: draft)
        case .evening:      return evening(day: day, draft: draft)
        }
    }

    /// Taslak devam senaryosu: günlük check-in 3. adımda (nedenler) kaldı.
    static var dailyResumed: FlowViewData {
        dailyCheckIn(draft: FlowDraftData(
            day: FixtureClock.today,
            stepIndex: 2,
            answers: ["daily.score": .score(3), "daily.emotions": .emotions(["yorgun.yorgun", "huzur.sakin"])],
            updatedAt: FixtureClock.daysAgo(0, 19, 10)
        ))
    }
}
