//
//  ReportSheet.swift
//  one
//
//  v2.5 — Yorum / kullanıcı / paylaşım raporlama sheet'i.
//  Apple Guideline 1.2 gereği UGC olan her yerden erişilebilir olmalı.
//

import SwiftUI

struct ReportSheet: View {
    enum Target: Equatable {
        case comment(id: String, authorName: String?)
        case user(id: String, displayName: String?)
        case share(recordName: String, ownerName: String?)

        var displayTitle: String {
            switch self {
            case .comment:                  return "Yorumu rapor et"
            case .user(_, let name):        return "\(name ?? "Kullanıcıyı") rapor et"
            case .share:                    return "Paylaşımı rapor et"
            }
        }

        var cloudKitType: ReportTargetType {
            switch self {
            case .comment: return .comment
            case .user:    return .user
            case .share:   return .share
            }
        }

        var cloudKitID: String {
            switch self {
            case .comment(let id, _):        return id
            case .user(let id, _):           return id
            case .share(let recordName, _):  return recordName
            }
        }
    }

    let target: Target
    var onSubmitted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason = .spam
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(target.displayTitle)
                        .font(.headline)
                    Text("Bildirimler 24 saat içinde değerlendirilir. Yinelenen şikâyetler içeriği otomatik gizleyebilir.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Sebep") {
                    Picker("", selection: $selectedReason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.localized).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Not (opsiyonel)") {
                    TextField("Daha fazla detay ekle…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView() }
                            Text(didSubmit ? "Gönderildi ✓" : "Raporu gönder")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSubmitting || didSubmit)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .navigationTitle("Rapor et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        CloudKitManager.shared.submitReport(
            targetType: target.cloudKitType,
            targetID: target.cloudKitID,
            reason: selectedReason,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { result in
            isSubmitting = false
            switch result {
            case .success:
                didSubmit = true
                onSubmitted?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    dismiss()
                }
            case .failure(let err):
                errorMessage = err.localizedDescription
            }
        }
    }
}
