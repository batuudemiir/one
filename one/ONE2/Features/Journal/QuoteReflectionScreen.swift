//
//  QuoteReflectionScreen.swift
//  ONE 2.0
//
//  Söze yazı (07 §5.4, components/QuoteReflection.md; `CoverRoute.quoteReflection`).
//  Editör + üstte söz künyesi (yazarken tek satıra küçülür). Soru söze özel;
//  sağda "başka soru". Aynı söze daha önce yazıldıysa en altta soluk satır
//  "Geçen sefer (12 Eyl): …" → önceki yazı sayfası. `Bitti` → mühür → Bugün.
//

import SwiftUI

struct QuoteReflectionScreen: View {
    let quoteID: QuoteID

    @Environment(\.one2) private var environment
    @Environment(Router.self) private var router
    @State private var model: QuoteReflectionModel?

    var body: some View {
        Group {
            if let model {
                QuoteReflectionEditor(model: model, onClose: close, onFinish: { router.finishWriting() })
            } else {
                VStack(spacing: 0) {
                    EditorTopBar(context: JournalCopy.kindTitle(.quoteReflection), hasText: false,
                                 isSaving: false, onClose: close, onDone: {})
                    EditorSkeleton()
                }
            }
        }
        .background(ONE2Color.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard model == nil, let environment else { return }
            let m = QuoteReflectionModel(quoteID: quoteID, services: .live(environment))
            model = m
            await m.load()
        }
    }

    /// Kaydetmeden çıkış: taslak cihazda kalır; uyarı yok.
    private func close() {
        router.cover = nil
    }
}

private struct QuoteReflectionEditor: View {
    @Bindable var model: QuoteReflectionModel
    let onClose: () -> Void
    let onFinish: () -> Void

    @FocusState private var focused: Bool
    @State private var showPrevious = false

    private var hasText: Bool { !model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            EditorTopBar(
                context: JournalCopy.kindTitle(.quoteReflection),
                hasText: hasText,
                isSaving: !model.canSave && hasText,
                onClose: onClose,
                onDone: save
            )
            switch model.phase {
            case .loading:
                EditorSkeleton()
            case .missing:
                Text(NSLocalizedString("one2.reflection.missing", comment: "Quote no longer available"))
                    .one2Type(.body)
                    .foregroundStyle(ONE2Color.inkMuted)
                    .padding(.horizontal, ONE2Space.gutter)
                    .padding(.top, ONE2Space.s6)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .writing, .sealed:
                editor
            }
        }
        .overlay {
            if case .sealed(let seal) = model.phase {
                SealView(seal: seal, onDone: onFinish)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showPrevious) {
            if let previous = model.previous {
                ScrollView {
                    EntryReadContent(entry: previous, quote: model.quote)
                        .padding(.horizontal, ONE2Space.gutter)
                        .padding(.vertical, ONE2Space.s8)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(ONE2Radius.xl)
                .presentationBackground(ONE2Color.surface)
            }
        }
    }

    private func save() {
        focused = false
        Task { await model.save() }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s4) {
            if let quote = model.quote {
                QuoteCitation(quote: quote, compact: focused)
            }
            if let prompt = model.prompt {
                promptRow(prompt)
            }
            EditorTextArea(
                text: $model.text,
                accessibilityLabel: model.prompt?.text
                    ?? NSLocalizedString("one2.reflection.placeholder", comment: "Empty editor placeholder"),
                focused: $focused
            )
            if model.saveFailed {
                EditorSaveError(onRetry: save)
            }
            if let previous = model.previous {
                Button { showPrevious = true } label: {
                    Text(JournalCopy.previousLine(previous))
                        .one2Type(.bodySm)
                        .foregroundStyle(ONE2Color.inkMuted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: ONE2Size.minTouch, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.one2Press)
            }
        }
        .frame(maxWidth: ONE2Size.readingColumn)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ONE2Space.gutter)
        .padding(.top, ONE2Space.s2)
        .safeAreaInset(edge: .bottom) {
            EditorToolbar(wordCount: model.wordCount)
        }
    }

    private func promptRow(_ prompt: PromptSuggestion) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ONE2Space.s3) {
            Text(prompt.text)
                .one2Type(.prompt)
                .foregroundStyle(ONE2Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button {
                Task { await model.anotherPrompt() }
            } label: {
                Text(NSLocalizedString("one2.reflection.anotherPrompt", comment: "Show a different prompt"))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.one2(.text, size: .compact))
        }
    }
}
