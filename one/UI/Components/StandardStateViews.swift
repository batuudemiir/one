//
//  StandardStateViews.swift
//  one
//
//  Light Serenity standart state görünümleri (Faz 4.2, 2026-04-26):
//  • ErrorState  — bir işlem başarısız olduğunda
//  • EmptyState  — veri yok / sonuç bulunamadı
//  • OfflineState — internet bağlantısı yok
//
//  Bu üç view tüm uygulamada tutarlı bir "boşluk dili" sağlar.
//  Light Serenity'ye uygun: warm off-white zemin, ince typography,
//  bol nefes alanı, retry CTA opsiyonel.
//
//  Kullanım:
//    if let error = vm.error {
//        ErrorState(error: error, onRetry: vm.refresh)
//    } else if vm.items.isEmpty {
//        EmptyState(
//            icon: "music.note.list",
//            title: "Henüz şarkı yok",
//            message: "Bugün bir mood kaydet, burada görünsün."
//        )
//    }
//

import SwiftUI

// MARK: - ErrorState

struct ErrorState: View {
    let error: AppError
    var onRetry: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: ONETokens.spacingXL) {
            Spacer()

            VStack(spacing: ONETokens.spacingLG) {
                Image(systemName: iconName)
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(ONETokens.oneAsh)
                    .accessibilityHidden(true)

                VStack(spacing: ONETokens.spacingSM) {
                    Text(error.title)
                        .displayMD()
                        .foregroundColor(ONETokens.oneInk)

                    Text(error.errorDescription ?? NSLocalizedString("error.generic", comment: ""))
                        .bodyMD()
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneCharcoal)
                        .padding(.horizontal, ONETokens.spacingXL2)
                }
            }

            Spacer()

            VStack(spacing: ONETokens.spacingMD) {
                if let onRetry, error.isRetryable {
                    Button(action: onRetry) {
                        Text(NSLocalizedString("common.retry", comment: "Tekrar Dene"))
                            .monoBase(tracking: 1.0)
                            .foregroundColor(ONETokens.oneCream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ONETokens.spacingMD)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ONETokens.oneInk)
                            )
                    }
                    .accessibilityLabel(NSLocalizedString("common.retry", comment: ""))
                }

                if let onDismiss {
                    Button(action: onDismiss) {
                        Text(NSLocalizedString("common.dismiss", comment: "Kapat"))
                            .monoBase(tracking: 1.0)
                            .foregroundColor(ONETokens.oneAsh)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ONETokens.spacingMD)
                    }
                }
            }
            .padding(.horizontal, ONETokens.spacingXL)
            .padding(.bottom, ONETokens.spacingXL3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ONETokens.oneCream.ignoresSafeArea())
    }

    private var iconName: String {
        switch error {
        case .networkUnavailable, .networkTimeout, .networkUnknown: return "wifi.slash"
        case .cloudKitNotAvailable, .cloudKitNotAuthenticated, .cloudKitRecordNotFound,
             .cloudKitSchemaError, .cloudKitServerConflict, .cloudKitQuotaExceeded, .cloudKitUnknown:
            return "icloud.slash"
        case .musicSearchFailed, .musicNoResults, .musicPlaybackFailed, .musicServiceUnavailable:
            return "music.note.list"
        case .cameraDenied, .cameraUnavailable, .photoSaveFailed:
            return "camera.fill"
        default:
            return "exclamationmark.circle"
        }
    }
}

// MARK: - EmptyState

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String?
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil

    init(
        icon: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    var body: some View {
        VStack(spacing: ONETokens.spacingXL) {
            Spacer()

            VStack(spacing: ONETokens.spacingLG) {
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundColor(ONETokens.oneStone)
                    .accessibilityHidden(true)

                VStack(spacing: ONETokens.spacingSM) {
                    Text(title)
                        .displaySM()
                        .foregroundColor(ONETokens.oneInk)
                        .multilineTextAlignment(.center)

                    if let message {
                        Text(message)
                            .bodySM()
                            .multilineTextAlignment(.center)
                            .foregroundColor(ONETokens.oneAsh)
                            .padding(.horizontal, ONETokens.spacingXL2)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title)\(message.map { ". \($0)" } ?? "")")

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .monoBase(tracking: 1.0)
                        .foregroundColor(ONETokens.oneInk)
                        .padding(.vertical, ONETokens.spacingMD)
                        .padding(.horizontal, ONETokens.spacingXL2)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ONETokens.oneAsh, lineWidth: 1)
                        )
                }
            }

            Spacer()
            Spacer() // double spacer — content sits slightly above center
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - OfflineState

struct OfflineState: View {
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: ONETokens.spacingLG) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundColor(ONETokens.oneAsh)
                .accessibilityHidden(true)

            VStack(spacing: ONETokens.spacingSM) {
                Text(NSLocalizedString("offline.title", comment: "Bağlantı yok"))
                    .displaySM()
                    .foregroundColor(ONETokens.oneInk)

                Text(NSLocalizedString("offline.message", comment: "İnternet bağlantını kontrol et"))
                    .bodySM()
                    .multilineTextAlignment(.center)
                    .foregroundColor(ONETokens.oneCharcoal)
                    .padding(.horizontal, ONETokens.spacingXL2)
            }
            .accessibilityElement(children: .combine)

            if let onRetry {
                Button(action: onRetry) {
                    Text(NSLocalizedString("common.retry", comment: "Tekrar Dene"))
                        .monoBase(tracking: 1.0)
                        .foregroundColor(ONETokens.oneInk)
                        .padding(.vertical, ONETokens.spacingMD)
                        .padding(.horizontal, ONETokens.spacingXL2)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ONETokens.oneInk, lineWidth: 1)
                        )
                }
                .padding(.top, ONETokens.spacingSM)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ONETokens.oneCream.ignoresSafeArea())
    }
}

// MARK: - Previews

#if DEBUG
#Preview("ErrorState — network") {
    ErrorState(
        error: .networkUnavailable,
        onRetry: { print("retry") }
    )
}

#Preview("EmptyState — no songs") {
    EmptyState(
        icon: "music.note.list",
        title: "Henüz şarkı yok",
        message: "Bugün bir mood kaydet, burada görünsün.",
        actionTitle: "Bugün'e git",
        onAction: { print("nav") }
    )
}

#Preview("OfflineState") {
    OfflineState(onRetry: { print("retry") })
}
#endif
