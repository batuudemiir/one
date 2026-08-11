//
//  SubCircleManagerView.swift
//  one
//
//  Alt-çevre yönetimi: grupları listele, oluştur, düzenle, sil. Üyeler
//  yalnız mevcut arkadaşlardan seçilir. Oluştur/düzenle tek bir editör
//  sheet'inde; silme de editörün içinde (ScrollView'da swipe yerine).
//

import SwiftUI
import CloudKit

struct SubCircleManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ck = CloudKitManager.shared

    @State private var circles: [SubCircle] = []
    @State private var friends: [FriendLite] = []
    @State private var isLoading = true

    /// Editör: nil = kapalı, .some(nil) = yeni, .some(circle) = düzenle.
    @State private var editorTarget: EditorTarget? = nil

    /// Üye seçici için sadeleştirilmiş arkadaş.
    struct FriendLite: Identifiable, Equatable {
        let id: String
        let name: String
        let colorHex: String
    }

    /// `.sheet(item:)` için sarmalayıcı — yeni grupta circle nil olur.
    struct EditorTarget: Identifiable {
        let id: String
        let circle: SubCircle?
        init(_ circle: SubCircle?) {
            self.circle = circle
            self.id = circle?.id ?? "new"
        }
    }

    var body: some View {
        SubScreen(
            title: NSLocalizedString("subcircle.title", comment: ""),
            actionTitle: NSLocalizedString("subcircle.new", comment: ""),
            onBack: { dismiss() },
            onAction: { editorTarget = EditorTarget(nil) }
        ) {
            VStack(alignment: .leading, spacing: ONETokens.spacingMD) {
                Text(NSLocalizedString("subcircle.subtitle", comment: ""))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, ONETokens.spacingSM)

                if isLoading && circles.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if circles.isEmpty {
                    emptyState
                } else {
                    ForEach(circles) { circle in
                        Button {
                            editorTarget = EditorTarget(circle)
                        } label: {
                            SubCircleRow(circle: circle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $editorTarget, onDismiss: { load() }) { target in
            SubCircleEditorSheet(circle: target.circle, friends: friends)
        }
        .onAppear { load() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(V3Tokens.faintText)
            Text(NSLocalizedString("subcircle.emptyTitle", comment: ""))
                .bodyMD()
                .fontWeight(.medium)
                .foregroundColor(V3Tokens.ink)
            Text(NSLocalizedString("subcircle.emptyBody", comment: ""))
                .bodyXS()
                .multilineTextAlignment(.center)
                .foregroundColor(V3Tokens.mutedText)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    // MARK: - Yükle

    private func load() {
        isLoading = true
        ck.fetchMySubCircles { list in
            circles = list
            isLoading = false
        }
        ck.fetchFriendsDailyShares(for: Date()) { result in
            DispatchQueue.main.async {
                if case .success(let data) = result {
                    friends = data.compactMap { item in
                        guard let uid = item.user["userID"] as? String else { return nil }
                        return FriendLite(
                            id: uid,
                            name: item.user["displayName"] as? String ?? "?",
                            colorHex: item.user["avatarColor"] as? String ?? "#5B8DEF"
                        )
                    }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                }
            }
        }
    }
}

// MARK: - Grup satırı

private struct SubCircleRow: View {
    let circle: SubCircle

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: circle.colorHex))
                    .frame(width: 40, height: 40)
                Text(circle.emoji.isEmpty ? String(circle.name.prefix(1)).uppercased() : circle.emoji)
                    .font(.system(size: circle.emoji.isEmpty ? 16 : 18, weight: .semibold))
                    .foregroundColor(V3Tokens.ink.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(circle.name)
                    .font(V3Typography.sans(15, weight: .semibold))
                    .foregroundColor(V3Tokens.ink)
                Text(String(format: NSLocalizedString("subcircle.memberCount", comment: ""), circle.memberIDs.count))
                    .bodyXS()
                    .foregroundColor(V3Tokens.mutedText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(V3Tokens.faintText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .oneCardBackground(radius: 14, opacity: 0.75)
    }
}
