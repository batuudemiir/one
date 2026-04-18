//
//  ErrorHandler.swift
//  one
//
//  Merkezi hata yönetimi.
//  • Hataları loglar (ONELogger)
//  • Toast / banner olarak kullanıcıya gösterir
//  • Retry mekanizması sağlar
//
//  Kullanım:
//    ErrorHandler.shared.handle(.networkUnavailable)
//    ErrorHandler.shared.handle(.cloudKitUnknown(underlying: error), retry: { ... })
//

import SwiftUI
import Combine

// MARK: - Toast Tipi
enum ToastType {
    case error
    case success
    case info
    case warning
    
    var icon: String {
        switch self {
        case .error:   return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .error:   return ONETokens.oneRed
        case .success: return ONETokens.oneGreen
        case .info:    return ONETokens.oneBlue
        case .warning: return ONETokens.moodOrange
        }
    }
}

// MARK: - Toast Modeli
struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let title: String
    let message: String
    let isRetryable: Bool
    var retryAction: (() -> Void)?
    
    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ErrorHandler
@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentToast: ToastItem? = nil
    @Published var toastQueue: [ToastItem] = []
    
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - Ana Handle Fonksiyonu
    func handle(_ error: AppError, retry: (() -> Void)? = nil) {
        // Log the error
        ONELogger.error(error.localizedDescription, category: .general)
        
        // Create toast
        let toast = ToastItem(
            type: .error,
            title: error.title,
            message: error.localizedDescription,
            isRetryable: error.isRetryable && retry != nil,
            retryAction: retry
        )
        
        show(toast)
    }
    
    // MARK: - Generic Error Handle
    func handle(_ error: Error, context: String = "", retry: (() -> Void)? = nil) {
        if let appError = error as? AppError {
            handle(appError, retry: retry)
        } else {
            let appError = AppError.unknown(message: context.isEmpty ? error.localizedDescription : context)
            handle(appError, retry: retry)
        }
    }
    
    // MARK: - Başarı Bildirimi
    func showSuccess(_ message: String) {
        let toast = ToastItem(
            type: .success,
            title: NSLocalizedString("general.success", comment: ""),
            message: message,
            isRetryable: false
        )
        show(toast)
    }
    
    // MARK: - Info Bildirimi
    func showInfo(_ message: String) {
        let toast = ToastItem(
            type: .info,
            title: NSLocalizedString("general.info", comment: ""),
            message: message,
            isRetryable: false
        )
        show(toast)
    }
    
    // MARK: - Warning Bildirimi
    func showWarning(_ message: String) {
        let toast = ToastItem(
            type: .warning,
            title: NSLocalizedString("general.warning", comment: ""),
            message: message,
            isRetryable: false
        )
        show(toast)
    }
    
    // MARK: - Toast Yönetimi
    private func show(_ toast: ToastItem) {
        dismissTask?.cancel()
        
        withAnimation(ONEAnimation.micro) {
            currentToast = toast
        }
        
        // Auto-dismiss after delay
        let duration: Double = toast.isRetryable ? 5.0 : 3.0
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }
    
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(ONEAnimation.micro) {
            currentToast = nil
        }
    }
    
    func retry() {
        guard let toast = currentToast, let action = toast.retryAction else { return }
        dismiss()
        // Delay retry slightly so toast dismisses
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            action()
        }
    }
}
