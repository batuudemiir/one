//
//  CommentEntryButton.swift
//  one
//
//  Bir günlük entry kartına eklenecek "Yorumlar" butonu.
//  - shareRecordName verilirse hemen sayıyı çeker
//  - asyncShareRecordNameProvider verilirse (kendi entry'lerimiz için)
//    on-demand olarak shareRecordName'i çözer
//  - Tap → CommentThreadView sheet açar
//
//  v3 — kendi paylaşımlarımıza gelen yorumları Bugün, Arşiv ve Çevre
//  sekmelerinde görebilmek için ortak yüzey.
//

import SwiftUI

struct CommentEntryButton: View {
    /// Önceden bilinen shareRecordName (Circle akışında doğrudan elimizde olur).
    let knownShareRecordName: String?

    /// Şarkı paylaşıldıysa ama recordName önceden bilinmiyorsa lazy resolve eden closure.
    /// Today / Archive akışında kendi DailyShare kaydını lookup eder.
    let resolveShareRecordName: ((@escaping (String?) -> Void) -> Void)?

    /// Paylaşım sahibinin userID'si — sheet açılırken CommentThreadView'a verilir.
    let shareOwnerID: String

    /// Buton vurgu rengi (mood/aksent).
    let accentColorHex: String

    @State private var resolvedShareRecordName: String? = nil
    @State private var commentCount: Int? = nil
    @State private var isResolvingShare = false
    @State private var showThread = false

    /// Önceden bilinen recordName ile init.
    init(shareRecordName: String,
         shareOwnerID: String,
         accentColorHex: String = "#888888") {
        self.knownShareRecordName = shareRecordName
        self.resolveShareRecordName = nil
        self.shareOwnerID = shareOwnerID
        self.accentColorHex = accentColorHex
    }

    /// Lazy resolve ile init — kendi entry'lerimizde share record adını
    /// CloudKit'ten çekmek gerektiğinde.
    init(shareOwnerID: String,
         accentColorHex: String = "#888888",
         resolveShareRecordName: @escaping (@escaping (String?) -> Void) -> Void) {
        self.knownShareRecordName = nil
        self.resolveShareRecordName = resolveShareRecordName
        self.shareOwnerID = shareOwnerID
        self.accentColorHex = accentColorHex
    }

    private var effectiveRecordName: String? {
        knownShareRecordName ?? resolvedShareRecordName
    }

    private var label: String {
        if let count = commentCount, count > 0 { return "\(count) Yorum" }
        return "Yorumlar"
    }

    private var accentColor: Color { Color(hex: accentColorHex) }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 13))
                Text(label)
                    .monoBase(tracking: 0.5)
                Spacer()
                if isResolvingShare {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundColor(ONETokens.oneCharcoal)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ONETokens.oneCreamLow)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .onAppear { loadCountIfPossible() }
        .onChange(of: effectiveRecordName) { _, name in
            guard let name, !name.isEmpty else { return }
            CloudKitManager.shared.fetchCommentCount(shareRecordName: name) { count in
                self.commentCount = count
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .commentCountChanged)) { notif in
            guard let name = notif.object as? String,
                  let mine = effectiveRecordName,
                  name == mine else { return }
            CloudKitManager.shared.commentCountCache.removeValue(forKey: mine)
            CloudKitManager.shared.fetchCommentCount(shareRecordName: mine) { count in
                self.commentCount = count
            }
        }
        .sheet(isPresented: $showThread) {
            if let name = effectiveRecordName {
                CommentThreadView(
                    shareRecordName: name,
                    shareOwnerID: shareOwnerID,
                    showComposer: true
                )
                .id(name)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }

    // MARK: - Actions

    private func handleTap() {
        if let name = effectiveRecordName, !name.isEmpty {
            showThread = true
            return
        }
        // Lazy resolve gerekiyor (kendi entry akışı)
        guard !isResolvingShare, let resolver = resolveShareRecordName else { return }
        isResolvingShare = true
        resolver { name in
            DispatchQueue.main.async {
                isResolvingShare = false
                guard let name = name, !name.isEmpty else { return }
                resolvedShareRecordName = name
                showThread = true
            }
        }
    }

    private func loadCountIfPossible() {
        if let name = knownShareRecordName, !name.isEmpty {
            CloudKitManager.shared.fetchCommentCount(shareRecordName: name) { count in
                self.commentCount = count
            }
            return
        }
        // Kendi entry akışı — recordName önceden çözülmüşse sayıyı zaten yüklemiş oluruz.
        // Çözülmediyse tap anına kadar resolve geciktirilir; rozet "Yorumlar" olarak kalır.
        guard let resolver = resolveShareRecordName, resolvedShareRecordName == nil else { return }
        resolver { name in
            DispatchQueue.main.async {
                guard let name = name, !name.isEmpty else { return }
                resolvedShareRecordName = name
                CloudKitManager.shared.fetchCommentCount(shareRecordName: name) { count in
                    self.commentCount = count
                }
            }
        }
    }
}
