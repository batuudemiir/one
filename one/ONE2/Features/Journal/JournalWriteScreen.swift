//
//  JournalWriteScreen.swift
//  ONE 2.0
//
//  Soruya ya da boş sayfaya yazı (07 §5.3, JournalEditor.md;
//  `CoverRoute.journalEditor`). Tam ekran, `ground` zemin. Üstte mono bağlam
//  etiketi ("HAFTALIK TEMA · YAVAŞLIK", "BOŞ SAYFA") ve `Bitti`; soru
//  Literata `prompt`; gövde `journal`; araç hapında kelime sayısı.
//  `Bitti` → mühür → Bugün. Hiç yazı yoksa `Kapat`, girdi oluşmaz.
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
                VStack(spacing: 0) {
                    EditorTopBar(context: nil, hasText: false, isSaving: false, onClose: close, onDone: {})
                    EditorSkeleton()
                }
            }
        }
        .background(ONE2Color.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard model == nil, let environment else { return }
            let m = JournalWriteModel(ref: ref, services: .live(environment))
            m.load()
            model = m
        }
    }

    /// Kaydetmeden çıkış: taslak cihazda kalır; uyarı yok.
    private func close() {
        router.cover = nil
    }
}

private struct JournalWriteEditor: View {
    @Bindable var model: JournalWriteModel
    let onClose: () -> Void
    let onFinish: () -> Void

    @FocusState private var focused: Bool

    private var hasText: Bool { !model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            EditorTopBar(
                context: model.context?.label,
                hasText: hasText,
                isSaving: !model.canSave && hasText,
                onClose: onClose,
                onDone: save
            )
            if model.phase == .loading {
                EditorSkeleton()
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

    private func save() {
        focused = false
        model.save()
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s4) {
            if let prompt = model.context?.prompt {
                Text(prompt)
                    .one2Type(.prompt)
                    .foregroundStyle(ONE2Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            EditorTextArea(
                text: $model.text,
                accessibilityLabel: model.context?.prompt
                    ?? NSLocalizedString("one2.reflection.placeholder", comment: "Empty editor placeholder"),
                focused: $focused
            )
            if model.saveFailed {
                EditorSaveError(onRetry: save)
            }
        }
        .frame(maxWidth: ONE2Size.readingColumn)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ONE2Space.gutter)
        .padding(.top, ONE2Space.s2)
        .safeAreaInset(edge: .bottom) {
            EditorToolbar(wordCount: model.wordCount)
        }
        .task {
            // Boş sayfada klavye hemen açılır.
            if model.text.isEmpty { focused = true }
        }
    }
}
