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
            case .comment:
                return NSLocalizedString("report.target.comment", comment: "")
            case .user(_, let name):
                return String(
                    format: NSLocalizedString("report.target.user", comment: ""),
                    name ?? NSLocalizedString("report.target.userFallback", comment: "")
                )
            case .share:
                return NSLocalizedString("report.target.share", comment: "")
            }
        }

        /// Üst çubuğun mono bağlam etiketi — hangi yüzeyden gelindiği.
        /// Başlık neyi rapor ettiğini söylüyor, bu satır nereden geldiğini.
        var contextLabel: String {
            switch self {
            case .comment: return NSLocalizedString("report.context.comment", comment: "")
            case .user:    return NSLocalizedString("report.context.user", comment: "")
            case .share:   return NSLocalizedString("report.context.share", comment: "")
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
        // `Form` kalktı: sistem formu kendi zeminini, kendi satır yüksekliğini
        // ve kendi bölüm başlığı tipografisini getiriyordu — uygulamanın geri
        // kalanında olmayan bir dil. Bölümler artık ONE'ın kart yüzeyi.
        V3SheetScreen(
            title: NSLocalizedString("report.title", comment: ""),
            context: target.contextLabel,
            onClose: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
                header
                reasonSection
                noteSection
                if let errorMessage { errorRow(errorMessage) }
                submitButton
            }
        }
    }

    // MARK: - Bölümler

    private var header: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            Text(target.displayTitle)
                .onePageTitle()
            Text(NSLocalizedString("report.notice", comment: ""))
                .bodyXS()
                .foregroundColor(V3Tokens.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
            Text(NSLocalizedString("report.reason", comment: ""))
                .oneEyebrow()

            SettingsGroup {
                ForEach(Array(ReportReason.allCases.enumerated()), id: \.element.id) { index, reason in
                    ReasonRow(
                        reason: reason,
                        isSelected: selectedReason == reason,
                        isLast: index == ReportReason.allCases.count - 1
                    ) {
                        ONEHaptics.pick()
                        selectedReason = reason
                    }
                }
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
            Text(NSLocalizedString("report.noteOptional", comment: ""))
                .oneEyebrow()

            TextField(
                NSLocalizedString("report.notePlaceholder", comment: ""),
                text: $note,
                axis: .vertical
            )
            .font(V3Typography.sans(15, relativeTo: .callout))
            .foregroundColor(V3Tokens.ink)
            .lineLimit(3...6)
            .padding(V3Tokens.spacingLG)
            .oneCardBackground()
        }
    }

    private func errorRow(_ message: String) -> some View {
        Text(message)
            .bodyXS()
            .foregroundColor(V3Tokens.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(V3Tokens.spacingLG)
            .oneCardBackground()
    }

    private var submitButton: some View {
        // v3 birincil buton. Eskiden `.borderedProminent` + `.tint(.red)`
        // idi — uygulamadaki tek sistem-görünümlü buton, hem kapsül
        // biçimi hem rengi kendi dilinden geliyordu.
        ZStack {
            V3PrimaryButton(
                title: didSubmit
                    ? NSLocalizedString("report.submitted", comment: "")
                    : NSLocalizedString("report.submit", comment: ""),
                isEnabled: !(isSubmitting || didSubmit),
                isFullWidth: true,
                action: submit
            )
            if isSubmitting {
                ProgressView()
                    .tint(V3Tokens.paper)
            }
        }
        .padding(.top, V3Tokens.spacingXS)
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

// MARK: - Sebep satırı

/// Rapor sebebi seçimi. `SettingsRow` bir hedefe götürür, bu satır bir
/// seçim yapar — o yüzden chevron yok, sağda işaret var.
///
/// Seçim işareti tek başına renk değil bir glif: "renk tek başına anlam
/// taşıyamaz" kuralı, VoiceOver `isSelected` özelliğiyle birlikte.
private struct ReasonRow: View {
    let reason: ReportReason
    let isSelected: Bool
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: V3Tokens.spacingMD) {
                    Text(reason.localized)
                        .bodySM()
                        .foregroundColor(V3Tokens.ink)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: V3Tokens.spacingSM)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .iconLG()
                        .foregroundColor(isSelected ? ONEBrand.kor : V3Tokens.hairline)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 14)
                .frame(minHeight: V3Tokens.minTouchTarget)
                .contentShape(Rectangle())

                if !isLast {
                    Rectangle()
                        .fill(V3Tokens.hairline)
                        .frame(height: 1)
                        .padding(.leading, 15)
                }
            }
        }
        .buttonStyle(.onePressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
