//
//  JournalWriteTests.swift
//  oneTests
//
//  UX-6 JournalEditor: soruya / boş sayfaya yazı; "Devam et" düzenler.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

@MainActor
final class WriteFakes {
    var existing: JournalEntry?
    var saved: [EntryDraft] = []
    var updated: [(UUID, String)] = []
    let drafts = MemoryKeyValueStore()

    static func entry(kind: EntryKind, body: String, ref: String?) -> JournalEntry {
        JournalEntry(id: UUID(), day: DayKey("2026-09-24")!, timeZoneID: nil, createdAt: Date(), updatedAt: Date(),
                     kind: kind, title: nil, body: body, wordCount: WordCounter.count(body), contentRef: ref,
                     contentSnapshot: nil, isBackfilled: false, sourceContext: nil, comparedEntryID: nil, moodID: nil,
                     tagIDs: [], answers: [])
    }

    var services: JournalWriteServices {
        JournalWriteServices(
            context: { ref in
                ref == nil
                    ? WriteContext(ref: nil, prompt: nil, label: "Boş", source: .free)
                    : WriteContext(ref: ref, prompt: "Bugün neyi acele etmeden yaptın?", label: "Tema", source: .theme)
            },
            existing: { [unowned self] _ in existing },
            save: { [unowned self] draft in
                saved.append(draft)
                return WritingOutcome(entry: Self.entry(kind: draft.kind, body: draft.body ?? "", ref: draft.contentRef),
                                      completedDay: true, badges: [])
            },
            update: { [unowned self] id, body in
                updated.append((id, body))
                return WritingOutcome(entry: Self.entry(kind: .prompt, body: body, ref: nil), completedDay: false, badges: [])
            },
            week: { [] },
            drafts: drafts)
    }
}

@MainActor
struct JournalWriteTests {

    @Test("Tema sorusu: prompt girdisi, contentRef tema günü, kaynak tema; kapanış türü")
    func themeEntry() {
        let fakes = WriteFakes()
        let model = JournalWriteModel(ref: "theme:2026-w39:d4", services: fakes.services)
        model.load()
        #expect(model.phase == .writing && model.editingID == nil && !model.canSave)
        model.text = "  Kahvemi oturarak içtim.  "
        model.save()
        let draft = fakes.saved.first
        #expect(draft?.kind == .prompt && draft?.contentRef == "theme:2026-w39:d4" && draft?.sourceContext == .theme)
        #expect(draft?.body == "Kahvemi oturarak içtim." && draft?.contentSnapshot == "Bugün neyi acele etmeden yaptın?")
        guard case .sealed(let seal) = model.phase else { Issue.record("kapanış yok"); return }
        #expect(seal.kind == .prompt && seal.completedDay)
    }

    @Test("Boş sayfa: freeform, soru ve referans yok")
    func blankPage() {
        let fakes = WriteFakes()
        let model = JournalWriteModel(ref: nil, services: fakes.services)
        model.load()
        model.text = "Serbest"
        model.save()
        #expect(fakes.saved.first?.kind == .freeform && fakes.saved.first?.contentRef == nil)
    }

    @Test("Devam et: bugünkü girdi açılır ve düzenlenir; taslak öncelikli ve kayıtla silinir")
    func continueEntry() {
        let fakes = WriteFakes()
        fakes.existing = WriteFakes.entry(kind: .prompt, body: "İlk satır", ref: "theme:2026-w39:d4")
        let model = JournalWriteModel(ref: "theme:2026-w39:d4", services: fakes.services)
        model.load()
        #expect(model.editingID == fakes.existing?.id && model.text == "İlk satır")
        model.text = "İlk satır ve devamı"
        #expect(fakes.drafts.object(forKey: "draft.write.theme:2026-w39:d4") as? String == "İlk satır ve devamı")
        let reopened = JournalWriteModel(ref: "theme:2026-w39:d4", services: fakes.services)
        reopened.load()
        #expect(reopened.text == "İlk satır ve devamı")
        reopened.save()
        #expect(fakes.updated.map(\.1) == ["İlk satır ve devamı"] && fakes.saved.isEmpty)
        #expect(fakes.drafts.object(forKey: "draft.write.theme:2026-w39:d4") == nil)
    }
}
