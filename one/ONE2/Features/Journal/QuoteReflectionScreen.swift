//
//  QuoteReflectionScreen.swift
//  ONE 2.0
//
//  Söze yazı ekranı (QuoteReflection.md, JournalEditor.md, UX-6). Tam ekran,
//  tab bar gizli. Üstte bağlam etiketi ve "Bitti"; söz künyesi (yazarken
//  küçülür), dönen soru + "Başka soru", serif gövde, en altta "Geçen sefer"
//  satırı ve kelime sayısı. "Bitti" → Seal → Bugün.
//
//  Araç hapının Biçim, Foto, Ses, Şarkı ve Etiket düğmeleri, arkalarındaki
//  depolar (medya, etiket) ve seçiciler gelince eklenir; işlevsiz kontrol
//  konmadı.
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
                V3Loading()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .oneScreenGround()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            guard model == nil, let environment else { return }
            let m = QuoteReflectionModel(quoteID: quoteID, services: .live(environment))
            model = m
            await m.load()
        }
    }

    /// Kaydetmeden çıkış: taslak cihazda kalır.
    private func close() {
        var path = router.path(for: router.tab)
        guard !path.isEmpty else { return }
        path.removeLast()
        router.setPath(path, for: router.tab)
    }
}

private struct QuoteReflectionEditor: View {
    @Bindable var model: QuoteReflectionModel
    let onClose: () -> Void
    let onFinish: () -> Void

    @FocusState private var focused: Bool
    @State private var showPrevious = false

    /// Satır genişliği ~65 karakter (iPad'de ortalı sütun).
    private static let columnWidth: CGFloat = 640

    var body: some View {
        VStack(spacing: 0) {
            V3TopBar(leading: .back(onClose), style: .subScreen,
                     context: JournalCopy.kindTitle(.quoteReflection)) {
                doneButton
            }
            switch model.phase {
            case .loading:
                V3Loading()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .missing:
                ONEErrorView(message: NSLocalizedString("one2.reflection.missing", comment: "Quote no longer available"))
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
                V3SheetScreen(title: JournalCopy.kindTitle(.quoteReflection), onClose: { showPrevious = false }) {
                    EntryReadContent(entry: previous, quote: model.quote)
                }
            }
        }
    }

    // MARK: Bitti

    private var doneButton: some View {
        Button {
            focused = false
            Task { await model.save() }
        } label: {
            Text(NSLocalizedString("one2.reflection.done", comment: "Finish writing"))
                .bodyXSSemibold()
                .foregroundColor(model.canSave ? V3Tokens.korText : V3Tokens.faintText)
                .padding(.horizontal, V3Tokens.spacingXS)
                .frame(minWidth: V3Tokens.minTouchTarget, minHeight: V3Tokens.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .disabled(!model.canSave)
    }

    // MARK: Editör

    private var editor: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
            if let quote = model.quote {
                QuoteCitation(quote: quote, compact: focused)
            }
            if let prompt = model.prompt {
                promptRow(prompt)
            }
            writingArea(prompt: model.prompt?.text)
            if model.saveFailed {
                Text(NSLocalizedString("one2.reflection.saveFailed", comment: "Saving the entry failed"))
                    .bodySMMedium()
                    .foregroundColor(V3Tokens.korText)
            }
            if let previous = model.previous {
                Button { showPrevious = true } label: {
                    Text(JournalCopy.previousLine(previous))
                        .bodySM()
                        .foregroundColor(V3Tokens.mutedText)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: V3Tokens.minTouchTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.onePressable)
            }
        }
        .frame(maxWidth: Self.columnWidth)
        .frame(maxWidth: .infinity)
        .padding(.top, V3Tokens.spacingSM)
        .oneScreenBody()
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Text(JournalCopy.words(model.wordCount))
                    .monoSM()
                    .foregroundColor(V3Tokens.mutedText)
            }
            .padding(.vertical, V3Tokens.spacingSM)
            .oneScreenBody()
            .background(V3Tokens.paper)
        }
    }

    private func promptRow(_ prompt: PromptSuggestion) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: V3Tokens.spacingMD) {
            Text(prompt.text)
                .font(V3Typography.quote(22))
                .foregroundColor(V3Tokens.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button {
                Task { await model.anotherPrompt() }
            } label: {
                Text(NSLocalizedString("one2.reflection.anotherPrompt", comment: "Show a different prompt"))
                    .bodySMMedium()
                    .foregroundColor(V3Tokens.mutedText)
                    .frame(minHeight: V3Tokens.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.onePressable)
        }
    }

    private func writingArea(prompt: String?) -> some View {
        ZStack(alignment: .topLeading) {
            if model.text.isEmpty {
                Text(NSLocalizedString("one2.reflection.placeholder", comment: "Empty editor placeholder"))
                    .font(V3Typography.journal())
                    .foregroundColor(V3Tokens.faintText)
                    .padding(.top, V3Tokens.spacingSM)
                    .padding(.leading, V3Tokens.spacingXS)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $model.text)
                .font(V3Typography.journal())
                .foregroundColor(V3Tokens.ink)
                .lineSpacing(11)
                .tint(V3Tokens.ink)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .accessibilityLabel(prompt ?? NSLocalizedString("one2.reflection.placeholder", comment: "Empty editor placeholder"))
        }
        .frame(maxHeight: .infinity)
    }
}
