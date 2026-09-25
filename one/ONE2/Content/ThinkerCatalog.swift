//
//  ThinkerCatalog.swift
//  ONE 2.0
//
//  Düşünür kataloğu (08 §4.7). `ContentCatalog` uygular; düşünür sayfası,
//  "benzer düşünürler" ve tükenmiş mod önerileri buradan okur.
//
//  Benzerlik = 2 × ortak yol sayısı + tema kosinüsü (düşünürün aktif
//  sözlerindeki tema sıklıkları). Eşitlikte ad sırası; kendisi ve pasif
//  düşünürler hariç.
//

import Foundation

nonisolated protocol ThinkerCatalog {
    func thinker(_ id: ThinkerID) -> Thinker?
    func thinkers(in path: PathID) -> [Thinker]
    func similar(to id: ThinkerID, limit: Int) -> [Thinker]
}

extension ContentCatalog: ThinkerCatalog {

    /// Yoldaki aktif düşünürler, ada göre.
    func thinkers(in path: PathID) -> [Thinker] {
        thinkers.filter { $0.active && $0.pathIDs.contains(path) }.sorted(by: Self.byName)
    }

    func similar(to id: ThinkerID, limit: Int) -> [Thinker] {
        guard let target = thinker(id), limit > 0 else { return [] }
        let profiles = themeProfiles()
        let targetProfile = profiles[id] ?? [:]
        return thinkers
            .filter { $0.active && $0.id != id }
            .map { ($0, Self.similarity(target, $0, targetProfile, profiles[$0.id] ?? [:])) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : Self.byName($0.0, $1.0) }
            .prefix(limit)
            .map(\.0)
    }

    /// Düşünür başına aktif `quote` sözlerindeki tema sıklığı.
    func themeProfiles() -> [ThinkerID: [String: Double]] {
        var out: [ThinkerID: [String: Double]] = [:]
        for q in quotes where q.active && q.kind == .quote {
            guard let id = q.authorID else { continue }
            for t in q.themes { out[id, default: [:]][t, default: 0] += 1 }
        }
        return out
    }

    static func similarity(_ a: Thinker, _ b: Thinker, _ pa: [String: Double], _ pb: [String: Double]) -> Double {
        let sharedPaths = Set(a.pathIDs).intersection(b.pathIDs).count
        return 2 * Double(sharedPaths) + cosine(pa, pb)
    }

    static func cosine(_ a: [String: Double], _ b: [String: Double]) -> Double {
        let dot = a.reduce(0) { $0 + $1.value * (b[$1.key] ?? 0) }
        let na = a.values.reduce(0) { $0 + $1 * $1 }.squareRoot()
        let nb = b.values.reduce(0) { $0 + $1 * $1 }.squareRoot()
        return na > 0 && nb > 0 ? dot / (na * nb) : 0
    }

    private static func byName(_ a: Thinker, _ b: Thinker) -> Bool {
        let (ka, kb) = (ThinkerNames.key(a.displayName), ThinkerNames.key(b.displayName))
        return ka != kb ? ka < kb : a.id < b.id
    }
}
