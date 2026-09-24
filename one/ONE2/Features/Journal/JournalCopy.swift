//
//  JournalCopy.swift
//  ONE 2.0
//
//  Yazı ekranlarının saf metin kararları: girdi türü adı, kelime sayısı,
//  "Geçen sefer" satırı.
//

import Foundation

nonisolated enum JournalCopy {

    static func kindTitle(_ kind: EntryKind) -> String {
        switch kind {
        case .quoteReflection: return NSLocalizedString("one2.entry.kind.quoteReflection", comment: "Entry kind: writing about a quote")
        case .prompt:          return NSLocalizedString("one2.entry.kind.prompt", comment: "Entry kind: answer to a prompt")
        default:               return NSLocalizedString("one2.entry.kind.journal", comment: "Entry kind: journal entry")
        }
    }

    static func words(_ count: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString("one2.words", comment: "Word count"), count)
    }

    /// İlk satır, en fazla `limit` karakter.
    static func firstLine(_ text: String?, limit: Int = 80) -> String {
        let line = (text ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count > limit ? String(trimmed.prefix(limit - 1)) + "…" : trimmed
    }

    /// "Geçen sefer (12 Eyl): …"
    static func previousLine(_ entry: JournalEntry) -> String {
        String(format: NSLocalizedString("one2.reflection.previous", comment: "Last time you wrote about this quote: (date): first line"),
               entry.createdAt.formatted(.dateTime.day().month(.abbreviated)), firstLine(entry.body))
    }

    /// Kapanış başlığı: gün bu yazıyla kapandıysa onu söyler.
    static func sealTitle(completedDay: Bool) -> String {
        completedDay
            ? NSLocalizedString("one2.seal.dayClosed", comment: "Seal title: the day is complete")
            : NSLocalizedString("one2.seal.saved", comment: "Seal title: writing saved")
    }
}
