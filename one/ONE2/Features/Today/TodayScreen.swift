//
//  TodayScreen.swift
//  ONE 2.0
//
//  Bugün sekmesi. Hafta şeridi → günün sözü (yazma kapısı) → bugün
//  yazdıkların. Yazı bitince kapanış buraya döner ve yeni girdi listede
//  görünür. Check-in kartı, Pratiklerin ve Haftalık tema UX-4/UX-5 ile gelir.
//

import Foundation
import SwiftUI

struct TodayScreen: View {
    @Environment(\.one2) private var environment
    @Environment(Router.self) private var router
    @State private var model: TodayModel?

    var body: some View {
        VStack(spacing: 0) {
            V3TopBar(style: .root, title: ONE2Tab.today.title)
            content
        }
        .oneScreenGround()
        .task {
            // Her görünüşte: yazıdan dönünce yeni girdi görünsün.
            if model == nil, let environment { model = TodayModel(services: .live(environment)) }
            await model?.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model?.phase ?? .loading {
        case .loading:
            V3Loading()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ONEErrorView(message: NSLocalizedString("one2.today.failed", comment: "Today could not load"),
                         onRetry: { Task { await model?.load() } })
        case .ready:
            if let model { ready(model) }
        }
    }

    private func ready(_ model: TodayModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: V3Tokens.spacingXL3) {
                if router.notice == .circleUnavailable {
                    CircleNoticeCard { router.notice = nil }
                }
                WeekStripView(days: WeekStripAdapter.viewData(model.week))
                if let quote = model.dailyQuote {
                    dailyQuoteCard(quote, written: model.wroteAboutDailyQuote)
                }
                writtenSection(model.entries)
            }
            .padding(.top, V3Tokens.spacingLG)
            .padding(.bottom, V3Tokens.spacingXL3)
            .oneScreenBody()
        }
    }

    // MARK: Günün sözü

    private func dailyQuoteCard(_ quote: Quote, written: Bool) -> some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
            Text(NSLocalizedString("one2.quotes.daily", comment: "Label on the quote of the day card"))
                .v3MicroLabel()
                .foregroundColor(V3Tokens.mutedText)
            Text(quote.text)
                .font(V3Typography.quote(22))
                .foregroundColor(V3Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let attribution = quote.attribution {
                Text(attribution)
                    .monoSM()
                    .foregroundColor(V3Tokens.mutedText)
            }
            V3PrimaryButton(title: written
                            ? NSLocalizedString("one2.today.writeAgain", comment: "Write about the daily quote again")
                            : NSLocalizedString("one2.quotes.write", comment: "Write about this quote")) {
                router.push(.quoteReflection(quote.id), on: .today)
            }
            .padding(.top, V3Tokens.spacingSM)
        }
        .padding(V3Tokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .oneCardBackground(radius: V3Tokens.radiusTile)
    }

    // MARK: Bugün yazdıkların

    private func writtenSection(_ entries: [TodayEntryItem]) -> some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
            Text(NSLocalizedString("one2.today.written.title", comment: "Section: what you wrote today"))
                .bodyLGSemibold()
                .foregroundColor(V3Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            if entries.isEmpty {
                Text(NSLocalizedString("one2.today.written.empty", comment: "Nothing written today yet"))
                    .bodyMD()
                    .foregroundColor(V3Tokens.mutedText)
            } else {
                ForEach(entries) { item in
                    Button {
                        router.push(.entry(item.id), on: .today)
                    } label: {
                        TodayEntryCard(item: item)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.onePressable)
                }
            }
        }
    }
}

/// "Bugün yazdıkların" kartı (HistoryCard.md'nin söze yazı biçimi).
private struct TodayEntryCard: View {
    let item: TodayEntryItem

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            HStack {
                Text(JournalCopy.kindTitle(item.kind))
                    .v3MicroLabel()
                    .foregroundColor(V3Tokens.mutedText)
                Spacer(minLength: 0)
                Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                    .monoSM()
                    .foregroundColor(V3Tokens.mutedText)
            }
            if let quoteText = item.quoteText {
                HStack(spacing: V3Tokens.spacingSM) {
                    Rectangle()
                        .fill(V3Tokens.hairline)
                        .frame(width: 2)
                        .accessibilityHidden(true)
                    Text(quoteText)
                        .font(V3Typography.quote(15))
                        .italic()
                        .foregroundColor(V3Tokens.mutedText)
                        .lineLimit(2)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            Text(item.body)
                .font(V3Typography.journal(16))
                .foregroundColor(V3Tokens.ink)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(V3Tokens.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .oneCardBackground(radius: V3Tokens.radiusTile)
        .accessibilityElement(children: .combine)
    }
}

/// Eski bir Çevre/davet bağlantısı açıldığında Bugün'ün üstündeki not.
struct CircleNoticeCard: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: V3Tokens.spacingMD) {
            Text(NSLocalizedString("one2.notice.circleUnavailable", comment: "Old Circle/invite link opened in ONE 2.0"))
                .bodySM()
                .foregroundColor(V3Tokens.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .iconSM()
                    .foregroundColor(V3Tokens.mutedText)
                    .frame(width: V3Tokens.minTouchTarget, height: V3Tokens.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.onePressable)
            .accessibilityLabel(NSLocalizedString("one2.action.dismiss", comment: "Dismiss notice"))
        }
        .padding(V3Tokens.spacingMD)
        .oneCardBackground()
    }
}
