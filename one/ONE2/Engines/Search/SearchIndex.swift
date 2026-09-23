//
//  SearchIndex.swift
//  ONE 2.0
//
//  Arama (04_arka_plan_motorlari.md › E11).
//
//  - `Entry.searchText`: başlık + gövde + soru/söz snapshot'ı + etiket adları;
//    Türkçe küçük harf + aksansız kopya (ş→s, ı→i, ğ→g…), ki "gunluk"
//    araması "günlük"ü bulsun. Kayıtta `JournalStore` yazar.
//  - Girdi araması: `searchText CONTAINS` + tarih/tür/etiket/skor filtreleri;
//    sonuç yeniden eskiye, eşleşen parça vurgulu.
//  - Sözler sekmesi: katalogda bellek içi indeks (metin + yazar + tema).
//  - Spotlight ve App Intents relaunch sonrasına.
//

import Foundation
import CoreData

nonisolated enum SearchText {
    private static let turkish = Locale(identifier: "tr_TR")

    /// Türkçe kurallarıyla küçük harf: "İ" → "i", "I" → "ı".
    static func lowered(_ text: String) -> String {
        text.lowercased(with: turkish)
    }

    /// Aksansız, karakter başına 1:1 (vurgulama aralıkları korunur).
    static func folded(_ text: String) -> String {
        String(lowered(text).map { fold($0) })
    }

    private static func fold(_ c: Character) -> Character {
        switch c {
        case "ş": return "s"
        case "ı", "î", "ï", "í", "ì": return "i"
        case "ğ": return "g"
        case "ü", "û", "ú", "ù": return "u"
        case "ö", "ô", "ó", "ò": return "o"
        case "ç": return "c"
        case "â", "á", "à", "ä": return "a"
        case "é", "è", "ê", "ë": return "e"
        default:
            // "i̇" gibi birleşik işaretli harfler ilk skalerine indirgenir.
            if c.unicodeScalars.count > 1, let first = c.unicodeScalars.first { return Character(first) }
            return c
        }
    }

    /// `Entry.searchText` içeriği: küçük harf metin + aksansız kopya.
    static func make(title: String?, body: String?, snapshot: String?, tagNames: [String]) -> String? {
        let parts = [title, body, snapshot].compactMap { $0 } + tagNames
        let joined = parts.filter { !$0.isEmpty }.joined(separator: "\n")
        guard !joined.isEmpty else { return nil }
        let low = lowered(joined), flat = folded(joined)
        return low == flat ? low : low + "\n" + flat
    }

    /// Aranan ifadenin metindeki aralıkları (aksansız karşılaştırma).
    static func highlights(of query: String, in text: String) -> [Range<String.Index>] {
        let q = folded(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !q.isEmpty else { return [] }
        let original = Array(text)
        let flat = Array(folded(text))
        // folded() 1:1 olduğu sürece indeksler örtüşür; değilse vurgu yok.
        guard flat.count == original.count else { return [] }
        let needle = Array(q)
        var result: [Range<String.Index>] = []
        var i = 0
        while i + needle.count <= flat.count {
            if Array(flat[i..<(i + needle.count)]) == needle {
                let start = text.index(text.startIndex, offsetBy: i)
                result.append(start..<text.index(start, offsetBy: needle.count))
                i += needle.count
            } else { i += 1 }
        }
        return result
    }
}

nonisolated struct EntrySearchFilter: Sendable {
    var from: DayKey?
    var through: DayKey?
    var kinds: Set<EntryKind> = []
    var tagID: UUID?
    /// Bağlı check-in skoru.
    var scores: Set<Int> = []
}

nonisolated struct EntrySearchResult: Sendable, Equatable {
    let entry: JournalEntry
    /// Eşleşen parçayı içeren kısa alıntı ve içindeki vurgu aralıkları.
    let snippet: String
    let highlights: [Range<String.Index>]
}

/// Sözler sekmesi için bellek içi indeks.
nonisolated struct QuoteSearchIndex: Sendable {
    private let rows: [(quote: Quote, text: String)]

    init(_ quotes: [Quote]) {
        rows = quotes.filter(\.active).map { q in
            (q, SearchText.folded(([q.text, q.author ?? ""] + q.themes).joined(separator: " ")))
        }
    }

    /// Tüm kelimeler geçmeli (VE). Katalog sırası korunur.
    func search(_ query: String, hasPremium: Bool = true) -> [Quote] {
        let words = SearchText.folded(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        return rows.filter { row in
            (hasPremium || !row.quote.premium) && words.allSatisfy { row.text.contains($0) }
        }.map(\.quote)
    }
}

final class SearchIndex {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func search(_ query: String, filter: EntrySearchFilter = EntrySearchFilter(), limit: Int = 100) throws -> [EntrySearchResult] {
        let q = SearchText.folded(query.trimmingCharacters(in: .whitespacesAndNewlines))
        var predicates: [NSPredicate] = []
        for word in q.split(whereSeparator: \.isWhitespace) {
            predicates.append(NSPredicate(format: "searchText CONTAINS %@", String(word)))
        }
        if let from = filter.from { predicates.append(NSPredicate(format: "dayKey >= %@", from.string)) }
        if let through = filter.through { predicates.append(NSPredicate(format: "dayKey <= %@", through.string)) }
        if !filter.kinds.isEmpty { predicates.append(NSPredicate(format: "kind IN %@", filter.kinds.map(\.rawValue))) }
        if let tag = filter.tagID { predicates.append(NSPredicate(format: "ANY tags.id == %@", tag as CVarArg)) }
        if !filter.scores.isEmpty { predicates.append(NSPredicate(format: "mood.score IN %@", Array(filter.scores))) }
        guard !predicates.isEmpty else { return [] }

        let request = NSFetchRequest<EntryMO>(entityName: ONE2Entity.entry)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "dayKey", ascending: false),
                                   NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit
        return try context.fetch(request).compactMap(\.value).map { entry in
            Self.result(for: entry, query: query)
        }
    }

    /// Eski girdilere `searchText` yazar (ilk açılış / sürüm geçişi).
    @discardableResult
    func rebuildMissing() throws -> Int {
        let rows: [EntryMO] = try context.fetchAll(ONE2Entity.entry, where: NSPredicate(format: "searchText == nil"))
        for row in rows { row.refreshSearchText() }
        try context.saveIfNeeded()
        return rows.count
    }

    static func result(for entry: JournalEntry, query: String, radius: Int = 40) -> EntrySearchResult {
        let source = [entry.title, entry.body, entry.contentSnapshot].compactMap { $0 }
            .first { !SearchText.highlights(of: query, in: $0).isEmpty } ?? entry.body ?? entry.title ?? ""
        guard let first = SearchText.highlights(of: query, in: source).first else {
            return EntrySearchResult(entry: entry, snippet: String(source.prefix(2 * radius)), highlights: [])
        }
        let start = source.index(first.lowerBound, offsetBy: -radius, limitedBy: source.startIndex) ?? source.startIndex
        let end = source.index(first.upperBound, offsetBy: radius, limitedBy: source.endIndex) ?? source.endIndex
        let snippet = String(source[start..<end])
        return EntrySearchResult(entry: entry, snippet: snippet, highlights: SearchText.highlights(of: query, in: snippet))
    }
}

extension EntryMO {
    func refreshSearchText() {
        let names = ((tags as? Set<TagMO>) ?? []).compactMap(\.name).sorted()
        searchText = SearchText.make(title: title, body: body, snapshot: contentSnapshot, tagNames: names)
    }
}
