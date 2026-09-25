//
//  QuotesScreen.swift
//  ONE 2.0
//
//  Sözler sekmesi (UX-7, ScreenSozler). Üstte mod hapı ve slayt düğmesi,
//  altında dikey sayfalı tam ekran kartlar. Her kartın görünür oranı
//  `QuoteVisibilityTracker`'a gider; "görüldü" / "atlandı" olayları
//  `QuoteFeedActions` üzerinden motora ulaşır.
//
//  Fırça (arka plan seçici) ve arama, fotoğraf seti ve arama ekranı
//  gelince eklenir; işlevsiz kontrol konmadı.
//

import SwiftUI
import UIKit

struct QuotesScreen: View {
    @Environment(\.one2) private var environment
    @Environment(Router.self) private var router
    @State private var model: QuotesViewModel?

    var body: some View {
        Group {
            if let model {
                QuotesFeedView(model: model)
            } else {
                VStack(spacing: 0) {
                    V3TopBar(style: .root, title: ONE2Tab.quotes.title)
                    V3Loading()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .oneScreenGround()
            }
        }
        .task {
            guard model == nil, let environment else { return }
            let m = QuotesViewModel.live(environment)
            m.onLocked = { router.sheet = .paywall(source: "sozler_yol") }
            m.onWrite = { router.cover = .quoteReflection(quoteID: $0.id) }
            model = m
            await m.load()
        }
    }
}

// MARK: - Akış

private struct QuotesFeedView: View {
    let model: QuotesViewModel

    @State private var tracker = QuoteVisibilityTracker()
    @State private var position: QuoteID?
    @State private var isPlaying = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Slayt modunda kart süresi (UX-7).
    private static let slideInterval: Duration = .seconds(6)
    /// Hareketsiz kartın süre kontrolü.
    private static let tickInterval: Duration = .milliseconds(400)

    var body: some View {
        VStack(spacing: 0) {
            V3TopBar(style: .root, title: ONE2Tab.quotes.title) {
                if model.phase == .feed {
                    V3TopBarIconButton(
                        systemName: isPlaying ? "pause" : "play",
                        label: isPlaying
                            ? NSLocalizedString("one2.quotes.slideshow.stop", comment: "Stop quote slideshow")
                            : NSLocalizedString("one2.quotes.slideshow.start", comment: "Start quote slideshow")
                    ) { isPlaying.toggle() }
                }
            }
            modePill
                .padding(.vertical, V3Tokens.spacingSM)
                .oneScreenBody()
            content
        }
        .oneScreenGround()
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { flushVisibility(); isPlaying = false }
        }
        .onChange(of: isPlaying) { _, playing in UIApplication.shared.isIdleTimerDisabled = playing }
        .onChange(of: model.mode) { _, _ in isPlaying = false; position = nil }
        .onDisappear {
            flushVisibility()
            isPlaying = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .task(id: isPlaying) { await runSlideshow() }
    }

    // MARK: Mod hapı

    private var modePill: some View {
        Menu {
            ForEach(model.options) { option in
                Button {
                    Task { await model.select(option) }
                } label: {
                    if option.isLocked {
                        Label(option.title, systemImage: "lock")
                    } else if option.mode == model.mode {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            HStack(spacing: V3Tokens.spacingSM) {
                Text(model.selectedOption?.title ?? "")
                    .bodyMDSemibold()
                    .foregroundColor(V3Tokens.ink)
                Image(systemName: "chevron.down")
                    .iconSM()
                    .foregroundColor(V3Tokens.mutedText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, V3Tokens.spacingLG)
            .frame(minHeight: V3Tokens.minTouchTarget)
            .oneCardBackground(radius: V3Tokens.radiusCapsule)
            .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .accessibilityLabel(NSLocalizedString("one2.quotes.mode.label", comment: "Quote source picker"))
        .accessibilityValue(model.selectedOption?.title ?? "")
    }

    // MARK: İçerik

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            V3Loading()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .locked:
            ScrollView(showsIndicators: false) { stateCard(for: .locked) }
        case .ended(let state):
            ScrollView(showsIndicators: false) { stateCard(for: state) }
        case .feed:
            pager
        }
    }

    private var pager: some View {
        GeometryReader { proxy in
            let pageHeight = proxy.size.height
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(model.items) { item in
                        QuoteCardView(
                            item: item,
                            onLike: { interacted(item.id); Task { await model.toggleLike(item.id) } },
                            onWrite: { interacted(item.id); model.write(item.id) },
                            onShare: { interacted(item.id); Task { await model.didShare(item.id) } }
                        )
                        .padding(.horizontal, V3Tokens.spacingLG)
                        .padding(.bottom, V3Tokens.spacingLG)
                        .frame(height: pageHeight)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .scrollView) } action: { frame in
                            report(item.id, fraction: QuoteCardVisibility.fraction(of: frame, viewportHeight: pageHeight))
                        }
                        .onAppear { Task { await model.cardAppeared(item.id) } }
                        .id(item.id)
                    }
                    if let footer = model.footer {
                        stateCard(for: footer)
                            .frame(height: pageHeight)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                handle(tracker.tick(at: .now))
            }
        }
    }

    // MARK: Görünürlük

    private func report(_ id: QuoteID, fraction: Double) {
        if let event = tracker.update(id, fraction: fraction, at: .now) { handle([event]) }
    }

    private func interacted(_ id: QuoteID) {
        tracker.noteInteraction(id)
    }

    private func flushVisibility() {
        handle(tracker.flush(at: .now))
    }

    private func handle(_ events: [QuoteVisibilityEvent]) {
        for event in events {
            switch event {
            case .seen(let id, let dwell): Task { await model.onSeen(id, dwell: dwell) }
            case .skipped(let id):         Task { await model.onSkipped(id) }
            }
        }
    }

    // MARK: Slayt

    private func runSlideshow() async {
        guard isPlaying else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.slideInterval)
            guard !Task.isCancelled else { return }
            let ids = model.items.map(\.id)
            let index = position.flatMap { ids.firstIndex(of: $0) } ?? 0
            guard index + 1 < ids.count else { isPlaying = false; return }
            withAnimation(reduceMotion ? nil : ONEAnimation.easing) { position = ids[index + 1] }
        }
    }

    // MARK: Durumlar

    private func stateCard(for state: QuoteFeedState) -> some View {
        let copy = QuotesStateCopy.make(state, mode: model.mode)
        return VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
            Text(copy.title)
                .bodyLGSemibold()
                .foregroundColor(V3Tokens.ink)
            Text(copy.message)
                .bodyMD()
                .foregroundColor(V3Tokens.mutedText)
            actions(for: state)
                .padding(.top, V3Tokens.spacingSM)
        }
        .padding(V3Tokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous)
                .strokeBorder(V3Tokens.hairline, lineWidth: 1)
        )
        .padding(.top, V3Tokens.spacingLG)
        .oneScreenBody()
    }

    @ViewBuilder
    private func actions(for state: QuoteFeedState) -> some View {
        switch state {
        case .locked:
            V3PrimaryButton(title: NSLocalizedString("one2.quotes.state.locked.action", comment: "Open ONE+ paywall")) {
                model.onLocked()
            }
        case .exhausted(let alternatives):
            VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
                ForEach(model.options(for: alternatives)) { option in
                    V3OutlineButton(title: option.title, isFullWidth: true) {
                        Task { await model.select(option) }
                    }
                }
            }
        case .list, .empty, .available, .revisiting:
            if model.mode != .forYou, let forYou = model.options.first(where: { $0.mode == .forYou }) {
                V3OutlineButton(title: forYou.title) { Task { await model.select(forYou) } }
            }
        }
    }
}
