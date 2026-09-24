//
//  JournalWriteScreen.swift
//  ONE 2.0
//
//  Soruya ya da boş sayfaya yazı (JournalEditor.md, UX-6; Route.newEntry).
//  Tam ekran, tab bar gizli. Üstte bağlam etiketi ("Haftalık tema ·
//  Yavaşlık", "Boş sayfa") ve "Bitti"; soru serif `prompt`; gövde serif;
//  kelime sayısı. "Bitti" → Seal → Bugün.
//
//  Araç hapının Biçim, Foto, Ses, Şarkı ve Etiket düğmeleri depoları ve
//  seçicileri gelince (söze yazıdaki gibi); işlevsiz kontrol konmadı.
//

import Foundation
import SwiftUI

struct JournalWriteScreen: View {
    let ref: String?

    @Environment(\.one2) private var environment
    @Environment(Router.self) private var router
    @State private var model: JournalWriteModel?

    var body: some View {
        Group {
            if let model {
                JournalWriteEditor(model: model, onClose: close, onFinish: { router.finishWriting() })
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
            let m = JournalWriteModel(ref: ref, services: .live(environment))
            m.load()
            model = m
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

private struct JournalWriteEditor: View {
    @Bindable var model: JournalWriteModel
    let onClose: () -> Void
    let onFinish: () -> Void

    @FocusState private var focused: Bool

    private static let columnWidth: CGFloat = 640

    var body: some View {
        VStack(spacing: 0) {
            V3TopBar(leading: .back(onClose), style: .subScreen, context: model.context?.label) {
                Button {
                    focused = false
                    model.save()
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
            if model.phase == .loading {
                V3Loading()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                editor
            }
        }
        .overlay {
            if case .sealed(let seal) = model.phase {
                SealView(seal: seal, onDone: onFinish)
                    .transition(.opacity)
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
            if let prompt = model.context?.prompt {
                Text(prompt)
                    .font(V3Typography.quote(22))
                    .foregroundColor(V3Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
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
                    .accessibilityLabel(model.context?.prompt
                                        ?? NSLocalizedString("one2.reflection.placeholder", comment: "Empty editor placeholder"))
            }
            .frame(maxHeight: .infinity)
            if model.saveFailed {
                Text(NSLocalizedString("one2.reflection.saveFailed", comment: "Saving the entry failed"))
                    .bodySMMedium()
                    .foregroundColor(V3Tokens.korText)
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
        .task {
            // Boş sayfada klavye hemen açılır.
            if model.text.isEmpty { focused = true }
        }
    }
}
