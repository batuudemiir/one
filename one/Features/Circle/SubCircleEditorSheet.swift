//
//  SubCircleEditorSheet.swift
//  one
//
//  Alt-çevre oluştur/düzenle. Ad + renk + emoji + üye seçimi (arkadaşlardan
//  çoklu). Düzenleme modunda silme de burada. Kaydetme create/update
//  servisine gider; hata kullanıcıya gösterilir.
//

import SwiftUI

struct SubCircleEditorSheet: View {
    /// nil = yeni grup, dolu = düzenleme.
    let circle: SubCircle?
    let friends: [SubCircleManagerView.FriendLite]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var ck = CloudKitManager.shared

    @State private var name: String
    @State private var colorHex: String
    @State private var emoji: String
    @State private var selectedIDs: Set<String>
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorText: String? = nil

    private let palette = ["#FFCDD2", "#FFE0B2", "#FFF9C4", "#C8E6C9",
                           "#BBDEFB", "#C5CAE9", "#D4B8F0", "#FCE4EC"]
    private let emojiPresets = ["", "🤍", "💛", "👥", "🎧", "✨", "🔥", "🌙", "☕️"]

    init(circle: SubCircle?, friends: [SubCircleManagerView.FriendLite]) {
        self.circle = circle
        self.friends = friends
        _name        = State(initialValue: circle?.name ?? "")
        _colorHex    = State(initialValue: circle?.colorHex ?? "#BBDEFB")
        _emoji       = State(initialValue: circle?.emoji ?? "")
        _selectedIDs = State(initialValue: Set(circle?.memberIDs ?? []))
    }

    private var isEditing: Bool { circle != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: ONETokens.spacingXL) {
                    nameField
                    colorRow
                    emojiRow
                    memberSection

                    if let errorText {
                        Text(errorText)
                            .bodyXS()
                            .foregroundColor(ONETokens.moodOrange)
                            .frame(maxWidth: .infinity)
                    }

                    if isEditing {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text(NSLocalizedString("subcircle.delete", comment: ""))
                                .bodySMMedium()
                                .foregroundColor(ONETokens.moodOrange)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(ONETokens.spacingXL)
            }
            .background(ONETokens.oneCream.ignoresSafeArea())
            .navigationTitle(isEditing
                ? NSLocalizedString("subcircle.editTitle", comment: "")
                : NSLocalizedString("subcircle.new", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("general.cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(NSLocalizedString("general.save", comment: "")) { save() }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .alert(NSLocalizedString("subcircle.deleteConfirm", comment: ""), isPresented: $showDeleteConfirm) {
                Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("subcircle.delete", comment: ""), role: .destructive) { performDelete() }
            }
        }
    }

    // MARK: - Ad

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(NSLocalizedString("subcircle.nameLabel", comment: ""))
            TextField(NSLocalizedString("subcircle.namePlaceholder", comment: ""), text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ONETokens.oneInk.opacity(0.09), lineWidth: 1)
                )
                .onChange(of: name) { _, new in
                    if new.count > SubCircle.maxNameLength {
                        name = String(new.prefix(SubCircle.maxNameLength))
                    }
                }
        }
    }

    // MARK: - Renk

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(NSLocalizedString("subcircle.colorLabel", comment: ""))
            HStack(spacing: 10) {
                ForEach(palette, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle().stroke(ONETokens.oneInk,
                                            lineWidth: colorHex == hex ? 2 : 0)
                        )
                        .onTapGesture {
                            ONEHaptics.feelingSelected()
                            colorHex = hex
                        }
                }
            }
        }
    }

    // MARK: - Emoji

    private var emojiRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(NSLocalizedString("subcircle.emojiLabel", comment: ""))
            HStack(spacing: 8) {
                ForEach(emojiPresets, id: \.self) { e in
                    Text(e.isEmpty ? "∅" : e)
                        .font(.system(size: 18))
                        .foregroundColor(e.isEmpty ? ONETokens.oneStone : nil)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(emoji == e ? ONETokens.oneInk.opacity(0.1) : Color.white.opacity(0.6))
                        )
                        .overlay(
                            Circle().stroke(ONETokens.oneInk, lineWidth: emoji == e ? 1.5 : 0)
                        )
                        .onTapGesture {
                            ONEHaptics.feelingSelected()
                            emoji = e
                        }
                }
            }
        }
    }

    // MARK: - Üyeler

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(String(format: NSLocalizedString("subcircle.membersLabel", comment: ""), selectedIDs.count))

            if friends.isEmpty {
                Text(NSLocalizedString("subcircle.noFriends", comment: ""))
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(friends) { friend in
                        memberRow(friend)
                        if friend.id != friends.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
                .oneCardBackground(radius: 14, opacity: 0.75)
            }
        }
    }

    private func memberRow(_ friend: SubCircleManagerView.FriendLite) -> some View {
        let isOn = selectedIDs.contains(friend.id)
        return Button {
            ONEHaptics.feelingSelected()
            if isOn { selectedIDs.remove(friend.id) } else { selectedIDs.insert(friend.id) }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: friend.colorHex))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(String(friend.name.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    )
                Text(friend.name)
                    .font(.system(size: 14))
                    .foregroundColor(ONETokens.oneInk)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isOn ? ONETokens.oneBrand : ONETokens.oneStone.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Yardımcı

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .monoLabel(tracking: 1.3)
            .foregroundColor(ONETokens.oneStone)
    }

    // MARK: - Aksiyonlar

    private func save() {
        isSaving = true
        errorText = nil
        let members = Array(selectedIDs)
        let handler: (Result<SubCircle, SubCircleServiceError>) -> Void = { result in
            isSaving = false
            switch result {
            case .success:
                ONEHaptics.songSaved()
                dismiss()
            case .failure(let err):
                ONEHaptics.error()
                errorText = err.localizedDescription
            }
        }

        if let circle {
            ck.updateSubCircle(id: circle.id, name: name, colorHex: colorHex,
                               emoji: emoji, memberIDs: members, completion: handler)
        } else {
            ck.createSubCircle(name: name, colorHex: colorHex, emoji: emoji,
                               memberIDs: members, completion: handler)
        }
    }

    private func performDelete() {
        guard let circle else { return }
        isSaving = true
        ck.deleteSubCircle(id: circle.id) { result in
            isSaving = false
            switch result {
            case .success:
                ONEHaptics.songSaved()
                dismiss()
            case .failure(let err):
                ONEHaptics.error()
                errorText = err.localizedDescription
            }
        }
    }
}
