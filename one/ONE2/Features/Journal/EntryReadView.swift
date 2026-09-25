//
//  EntryReadView.swift
//  ONE 2.0
//
//  Girdinin okunur hâli: söze yazıdaki "Geçen sefer" sayfası ve Bugün'den
//  açılan girdi detayı (`Route.entry`) bunu kullanır. Mono tarih, varsa
//  söz künyesi ya da soru (`prompt`), gövde `journal`.
//

import Foundation
import SwiftUI

struct EntryReadContent: View {
    let entry: JournalEntry
    let quote: Quote?

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s5) {
            ONE2Label(entry.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
            if let quote {
                QuoteCitation(quote: quote)
            }
            if let prompt = entry.contentSnapshot {
                Text(prompt)
                    .one2Type(.prompt)
                    .foregroundStyle(ONE2Color.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(entry.body ?? "")
                .one2Type(.journal)
                .foregroundStyle(ONE2Color.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: ONE2Size.readingColumn, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `Route.entry(id)`: girdi detayı (push).
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
        ScreenScaffold {
            ONE2RoundButton(icon: .back, accessibilityLabel: one2String("one2.action.back")) { router.pop() }
        } center: {
            if case .loaded(let entry, _) = state {
                ONE2Label(JournalCopy.kindTitle(entry.kind))
            }
        } trailing: {
            EmptyView()
        } content: {
            switch state {
            case .loading:
                Skeleton { SkeletonLines(count: 4) }
            case .missing:
                Text(NSLocalizedString("one2.entry.missing", comment: "Entry not found"))
                    .one2Type(.body)
                    .foregroundStyle(ONE2Color.inkMuted)
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
}
