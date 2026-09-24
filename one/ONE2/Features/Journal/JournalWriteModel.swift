//
//  JournalWriteModel.swift
//  ONE 2.0
//
//  Soruya ya da boş sayfaya yazı (JournalEditor.md, UX-6): `Route.newEntry`.
//  Haftalık temanın günü ("Yaz" / "Devam et"), katalog sorusu ya da boş
//  sayfa. Bugün aynı soruya yazılmışsa "Devam et" o girdiyi düzenler.
//
//  Kayıt: soru varsa `kind = prompt`, `contentRef` = soru referansı
//  (`theme:2026-w40:d3` ya da `p_…`), `contentSnapshot` = soru metni;
//  yoksa `freeform`. Taslak cihazda, kayıtla silinir.
//

import Foundation
import Observation

/// Yazının bağlamı: soru, bağlam etiketi, kaynak.
nonisolated struct WriteContext: Hashable, Sendable {
    let ref: String?
    let prompt: String?
    /// Üstteki mono etiket: "Haftalık tema · Yavaşlık", "Boş sayfa".
    let label: String
    let source: EntrySource
    var kind: EntryKind { prompt == nil ? .freeform : .prompt }
}

struct JournalWriteServices {
    var context: (String?) -> WriteContext
    /// Bugün bu referansa yazılmış girdi ("Devam et").
    var existing: (String) -> JournalEntry?
    var save: (EntryDraft) throws -> WritingOutcome
    var update: (UUID, String) throws -> WritingOutcome
    var week: () -> [WeekDayCell]
    var drafts: KeyValueBacking
}

@Observable
final class JournalWriteModel {
    let ref: String?

    private(set) var phase: ReflectionPhase = .loading
    private(set) var context: WriteContext?
    /// Düzenlenen girdi ("Devam et"); yoksa yeni girdi.
    private(set) var editingID: UUID?
    private(set) var isSaving = false
    private(set) var saveFailed = false
    var text = "" {
        didSet { if text != oldValue { services.drafts.set(trimmed.isEmpty ? nil : text, forKey: draftKey) } }
    }

    @ObservationIgnored private let services: JournalWriteServices

    init(ref: String?, services: JournalWriteServices) {
        self.ref = ref
        self.services = services
    }

    var wordCount: Int { WordCounter.count(text) }
    var canSave: Bool { !trimmed.isEmpty && !isSaving && phase == .writing }
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var draftKey: String { "draft.write.\(ref ?? "blank")" }

    func load() {
        let context = services.context(ref)
        self.context = context
        if let ref, let entry = services.existing(ref) {
            editingID = entry.id
            text = services.drafts.object(forKey: draftKey) as? String ?? (entry.body ?? "")
        } else {
            text = services.drafts.object(forKey: draftKey) as? String ?? ""
        }
        phase = .writing
    }

    func save() {
        guard canSave, let context else { return }
        isSaving = true
        saveFailed = false
        defer { isSaving = false }
        do {
            let outcome: WritingOutcome
            if let editingID {
                outcome = try services.update(editingID, trimmed)
            } else {
                outcome = try services.save(EntryDraft(kind: context.kind, body: trimmed, contentRef: context.ref,
                                                       contentSnapshot: context.prompt, sourceContext: context.source))
            }
            services.drafts.set(nil, forKey: draftKey)
            phase = .sealed(ReflectionSeal(entryID: outcome.entry.id, completedDay: outcome.completedDay,
                                           wordCount: outcome.entry.wordCount, badges: outcome.badges.map(\.title),
                                           week: services.week(), kind: context.kind))
        } catch {
            saveFailed = true
        }
    }
}

extension JournalWriteServices {
    static func live(_ env: AppEnvironment) -> JournalWriteServices {
        func outcome(_ entry: JournalEntry) -> WritingOutcome {
            if let o = env.lastWriting, o.entry.id == entry.id { return o }
            return WritingOutcome(entry: entry, completedDay: false, badges: [])
        }
        return JournalWriteServices(
            context: { ref in WriteContexts.resolve(ref, env: env) },
            existing: { ref in ((try? env.journal.entries(on: env.clock.today)) ?? []).last { $0.contentRef == ref } },
            save: { draft in outcome(try env.journal.create(draft)) },
            update: { id, body in outcome(try env.journal.update(id, title: nil, body: body)) },
            week: { WeekStripModel.load(env) },
            drafts: FlowStorage.backing
        )
    }
}

enum WriteContexts {
    /// Bugünün tema günü referansı ve sorusu.
    static func todayTheme(_ env: AppEnvironment) -> (ref: String, prompt: String, name: String)? {
        let today = env.clock.today
        guard let week = ThemeCalendar.theme(for: today, catalog: env.content.catalog, salt: env.profile.profile.userSalt),
              let prompt = week.prompt(on: today) else { return nil }
        return (PromptSuggestion.themeRef(week: week.week, weekday: today.isoWeekday), prompt, week.theme.title)
    }

    static func resolve(_ ref: String?, env: AppEnvironment) -> WriteContext {
        let blank = WriteContext(ref: nil, prompt: nil,
                                 label: NSLocalizedString("one2.write.context.blank", comment: "Editor context: blank page"),
                                 source: .free)
        guard let ref, !ref.isEmpty else { return blank }
        if let theme = todayTheme(env), theme.ref == ref {
            return WriteContext(ref: ref, prompt: theme.prompt,
                                label: String(format: NSLocalizedString("one2.write.context.theme",
                                                                        comment: "Editor context: weekly theme · name"), theme.name),
                                source: .theme)
        }
        if let prompt = env.content.catalog.prompt(ref) {
            return WriteContext(ref: ref, prompt: prompt.text, label: JournalCopy.kindTitle(.prompt), source: .suggestion)
        }
        // Geçmiş bir tema günü: sorunun metni daha önceki girdiden.
        if let snapshot = ((try? env.journal.entries(kind: .prompt, contentRef: ref)) ?? []).last?.contentSnapshot {
            return WriteContext(ref: ref, prompt: snapshot, label: JournalCopy.kindTitle(.prompt),
                                source: ref.hasPrefix("theme:") ? .theme : .suggestion)
        }
        return blank
    }
}
