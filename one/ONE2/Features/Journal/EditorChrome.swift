//
//  EditorChrome.swift
//  ONE 2.0
//
//  Yazma ekranlarının ortak parçaları (07 §5.3, components/JournalEditor.md):
//  - Üst çubuk: × · mono bağlam etiketi · `Bitti`. Hiç yazı yoksa `Bitti`
//    yerine `Kapat`; girdi oluşmaz.
//  - Yazı alanı: `journal` (Literata 18/29), imleç `brand`, boşken "Yaz…".
//  - Araç hapı (`raised`): mono kelime sayısı. Biçim, Foto, Ses, Şarkı ve
//    Etiket düğmeleri depoları gelince; işlevsiz kontrol konmadı.
//  - Yükleniyor: iskelet.
//

import SwiftUI

struct EditorTopBar: View {
    let context: String?
    /// Metin var: `Bitti` kaydeder. Yoksa `Kapat` yalnız kapatır.
    let hasText: Bool
    let isSaving: Bool
    let onClose: () -> Void
    let onDone: () -> Void

    var body: some View {
        ONE2TopBar {
            ONE2RoundButton(icon: .close, accessibilityLabel: one2String("one2.action.close"), filled: false, action: onClose)
        } center: {
            if let context {
                ONE2Label(context).lineLimit(1)
            }
        } trailing: {
            Button(action: hasText ? onDone : onClose) {
                Text(hasText ? NSLocalizedString("one2.reflection.done", comment: "Finish writing")
                             : one2String("one2.action.close"))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.one2(hasText ? .secondary : .text, size: .compact))
            .disabled(isSaving)
        }
        .padding(.horizontal, ONE2Space.gutter)
    }
}

struct EditorTextArea: View {
    @Binding var text: String
    /// VoiceOver'da alanın adı (soru ya da "Yaz…").
    let accessibilityLabel: String
    var focused: FocusState<Bool>.Binding

    private var placeholder: String {
        NSLocalizedString("one2.reflection.placeholder", comment: "Empty editor placeholder")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .one2Type(.journal)
                    .foregroundStyle(ONE2Color.inkFaint)
                    .padding(.top, ONE2Space.s2)
                    .padding(.leading, ONE2Space.s1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $text)
                .one2Type(.journal)
                .foregroundStyle(ONE2Color.ink)
                .tint(ONE2Color.brand)
                .scrollContentBackground(.hidden)
                .focused(focused)
                .accessibilityLabel(Text(accessibilityLabel))
        }
        .frame(maxHeight: .infinity)
    }
}

/// Klavyenin üstüne yapışan araç hapı.
struct EditorToolbar: View {
    let wordCount: Int

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Text(JournalCopy.words(wordCount))
                .one2Type(.time)
                .foregroundStyle(ONE2Color.inkMuted)
                .padding(.horizontal, ONE2Space.s3)
        }
        .frame(minHeight: ONE2Size.minTouch)
        .padding(.horizontal, ONE2Space.s2)
        .background(ONE2Color.raised, in: Capsule())
        .padding(.horizontal, ONE2Space.gutter)
        .padding(.vertical, ONE2Space.s2)
        .background(ONE2Color.ground)
    }
}

/// Yazma ekranı yükleniyor: soru ve iki satır iskelet.
struct EditorSkeleton: View {
    var body: some View {
        Skeleton {
            VStack(alignment: .leading, spacing: ONE2Space.s4) {
                SkeletonBar(height: ONE2Size.icon)
                SkeletonLines(count: 3)
            }
        }
        .padding(.horizontal, ONE2Space.gutter)
        .padding(.top, ONE2Space.s4)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Kayıt hatası (07 §6, §8: `danger` kelime + ne yapılacağı + `Tekrar dene`).
struct EditorSaveError: View {
    let onRetry: () -> Void

    var body: some View {
        ErrorLine(
            title: one2String("one2.editor.saveFailed.title"),
            message: one2String("one2.editor.saveFailed.message"),
            retry: onRetry
        )
        .onAppear { ONE2Haptics.error() }
    }
}

#if DEBUG
private struct EditorChromeSample: View {
    @State private var text = "Durakta on iki dakika bekledim ve ilk kez telefona bakmadım."
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            EditorTopBar(context: "Haftalık tema · Yavaşlık", hasText: !text.isEmpty, isSaving: false, onClose: {}, onDone: {})
            VStack(alignment: .leading, spacing: ONE2Space.s4) {
                Text(verbatim: "Bugün seni en çok ne yavaşlattı, ve buna izin verdin mi?")
                    .one2Type(.prompt)
                    .foregroundStyle(ONE2Color.ink)
                EditorTextArea(text: $text, accessibilityLabel: "Soru", focused: $focused)
                EditorSaveError {}
            }
            .padding(.horizontal, ONE2Space.gutter)
            EditorToolbar(wordCount: 11)
        }
        .background(ONE2Color.ground.ignoresSafeArea())
    }
}

#Preview("Gece") { EditorChromeSample().preferredColorScheme(.dark) }
#Preview("Gün") { EditorChromeSample().preferredColorScheme(.light) }
#Preview("AX3") { EditorChromeSample().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#Preview("Yükleniyor") { EditorSkeleton().background(ONE2Color.ground).preferredColorScheme(.dark) }
#endif
