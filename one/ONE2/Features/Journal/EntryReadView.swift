//
//  EntryReadView.swift
//  ONE 2.0
//
//  Bir girdiyi okuma: tarih, söz künyesi, soru, yazı. "Geçen sefer"
//  sheet'i ve Bugün'den açılan girdi detayı (Route.entry) bunu kullanır.
//  Düzenle / sil, Yolculuk'un girdi detayıyla (UX-9) gelir.
//

import Foundation
import SwiftUI

struct EntryReadContent: View {
    let entry: JournalEntry
    let quote: Quote?

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
            Text(entry.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                .monoSM()
                .foregroundColor(V3Tokens.mutedText)
            if let quote {
                QuoteCitation(quote: quote)
            }
            if let prompt = entry.contentSnapshot {
                Text(prompt)
                    .font(V3Typography.quote(20))
                    .foregroundColor(V3Tokens.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(entry.body ?? "")
                .font(V3Typography.journal())
                .foregroundColor(V3Tokens.ink)
                .lineSpacing(11)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `Route.entry(id)`: girdi detayı.
struct EntryDetailScreen: View {
    let entryID: UUID

    @Environment(\.one2) private var environment
    @Environment(Router.self) private var router
    @State private var state: LoadState = .loading

    private enum LoadState {
        case loading, missing
        case loaded(JournalEntry, Quote?)
    }

    var body: some View {
        SubScreen(title: title, onBack: popOne) {
            switch state {
            case .loading:
                V3Loading()
            case .missing:
                Text(NSLocalizedString("one2.entry.missing", comment: "Entry not found"))
                    .bodyMD()
                    .foregroundColor(V3Tokens.mutedText)
            case .loaded(let entry, let quote):
                EntryReadContent(entry: entry, quote: quote)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard case .loading = state, let environment else { return }
            guard let entry = try? environment.journal.entry(entryID) else { state = .missing; return }
            let quote = entry.kind == .quoteReflection ? entry.contentRef.flatMap { environment.content.catalog.quote($0) } : nil
            state = .loaded(entry, quote)
        }
    }

    private var title: String {
        if case .loaded(let entry, _) = state { return JournalCopy.kindTitle(entry.kind) }
        return ONE2Tab.today.title
    }

    private func popOne() {
        var path = router.path(for: router.tab)
        guard !path.isEmpty else { return }
        path.removeLast()
        router.setPath(path, for: router.tab)
    }
}
