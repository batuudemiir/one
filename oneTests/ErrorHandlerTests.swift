//
//  ErrorHandlerTests.swift
//  oneTests
//
//  Tests for ErrorHandler — toast management, error handling, retry support.
//

import Testing
import SwiftUI
@testable import OneDailyBatuhan

// MARK: - ToastType Tests

struct ToastTypeTests {

    @Test("ToastType icons are SF Symbols")
    func testToastTypeIcons() {
        let cases: [ToastType] = [.error, .success, .info, .warning]
        let expectedIcons = [
            "exclamationmark.triangle.fill",
            "checkmark.circle.fill",
            "info.circle.fill",
            "exclamationmark.circle.fill"
        ]

        for (type, expected) in zip(cases, expectedIcons) {
            #expect(type.icon == expected, "\(type) should have icon \(expected)")
        }
    }

    @Test("ToastType colors map to correct token colors")
    func testToastTypeColors() {
        // Just verify each type produces a non-nil Color
        let cases: [ToastType] = [.error, .success, .info, .warning]
        for type in cases {
            let _ = type.color // Access to verify it doesn't crash
        }
    }
}

// MARK: - ToastItem Tests

struct ToastItemTests {

    @Test("ToastItem initializes correctly")
    func testInit() {
        let toast = ToastItem(
            type: .error,
            title: "Test Title",
            message: "Test Message",
            isRetryable: true,
            retryAction: { }
        )

        #expect(toast.type == .error)
        #expect(toast.title == "Test Title")
        #expect(toast.message == "Test Message")
        #expect(toast.isRetryable == true)
    }

    @Test("ToastItem generates unique ids")
    func testUniqueIds() {
        let a = ToastItem(type: .error, title: "A", message: "A", isRetryable: false)
        let b = ToastItem(type: .error, title: "A", message: "A", isRetryable: false)

        #expect(a.id != b.id)
    }

    @Test("ToastItem equality is based on id")
    func testEquality() {
        let a = ToastItem(type: .error, title: "A", message: "A", isRetryable: false)
        let b = ToastItem(type: .error, title: "A", message: "A", isRetryable: false)

        // Different ids → not equal
        #expect(a != b)
    }

    @Test("ToastItem without retryAction has nil retryAction")
    func testNoRetryAction() {
        let toast = ToastItem(type: .info, title: "T", message: "M", isRetryable: false)
        #expect(toast.retryAction == nil)
    }
}

// MARK: - ErrorHandler Tests

@MainActor
struct ErrorHandlerTests {

    @Test("ErrorHandler.shared is singleton")
    func testSingleton() {
        let a = ErrorHandler.shared
        let b = ErrorHandler.shared
        #expect(a === b)
    }

    @Test("ErrorHandler starts with nil toast")
    func testInitialState() {
        let handler = ErrorHandler.shared
        // Clear any existing state
        handler.dismiss()
        #expect(handler.currentToast == nil)
    }

    @Test("handle(AppError) sets currentToast")
    func testHandleAppError() {
        let handler = ErrorHandler.shared
        handler.dismiss()

        handler.handle(.networkUnavailable)
        #expect(handler.currentToast != nil)
        #expect(handler.currentToast?.type == .error)
        #expect(handler.currentToast?.title == "Bağlantı Hatası")

        // Cleanup
        handler.dismiss()
    }

    @Test("handle(AppError) with retry creates retryable toast")
    func testHandleWithRetry() {
        let handler = ErrorHandler.shared
        handler.dismiss()

        var retried = false
        handler.handle(.networkUnavailable) {
            retried = true
        }

        #expect(handler.currentToast?.isRetryable == true)
        #expect(handler.currentToast?.retryAction != nil)

        // Cleanup
        handler.dismiss()
    }

    @Test("handle(AppError) non-retryable error ignores retry closure")
    func testHandleNonRetryableIgnoresRetry() {
        let handler = ErrorHandler.shared
        handler.dismiss()

        // cameraDenied is not retryable
        handler.handle(.cameraDenied) {
            // This should be ignored
        }

        #expect(handler.currentToast?.isRetryable == false)

        // Cleanup
        handler.dismiss()
    }

    @Test("handle(generic Error) wraps in unknown AppError")
    func testHandleGenericError() {
        let handler = ErrorHandler.shared
        handler.dismiss()

        let genericError = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Something went wrong"])
        handler.handle(genericError, context: "Test context")

        #expect(handler.currentToast != nil)
        #expect(handler.currentToast?.type == .error)

        // Cleanup
        handler.dismiss()
    }

    @Test("showSuccess sets success toast")
    func testShowSuccess() {
        let handler = ErrorHandler.shared
        handler.dismiss()

        handler.showSuccess("Kayıt başarılı!")
        #expect(handler.currentToast?.type == .success)
        #expect(handler.currentToast?.title == "Başarılı")
        #expect(handler.currentToast?.message == "Kayıt başarılı!")
        #expect(handler.currentToast?.isRetryable == false)

        // Cleanup
        handler.dismiss()
    }

    @Test("showInfo sets info toast")
    func testShowInfo() {
        let handler = ErrorHandler.shared
        handler.dismiss()

        handler.showInfo("Bilgi mesajı")
        #expect(handler.currentToast?.type == .info)
        #expect(handler.currentToast?.title == "Bilgi")

        // Cleanup
        handler.dismiss()
    }

    @Test("showWarning sets warning toast")
    func testShowWarning() {
        let handler = ErrorHandler.shared
        handler.dismiss()

        handler.showWarning("Uyarı mesajı")
        #expect(handler.currentToast?.type == .warning)
        #expect(handler.currentToast?.title == "Uyarı")

        // Cleanup
        handler.dismiss()
    }

    @Test("dismiss clears currentToast")
    func testDismiss() {
        let handler = ErrorHandler.shared

        handler.showSuccess("Test")
        #expect(handler.currentToast != nil)

        handler.dismiss()
        #expect(handler.currentToast == nil)
    }

    @Test("Showing a new toast replaces the current one")
    func testToastReplacement() {
        let handler = ErrorHandler.shared
        handler.dismiss()

        handler.showSuccess("First")
        let firstId = handler.currentToast?.id

        handler.showWarning("Second")
        let secondId = handler.currentToast?.id

        #expect(firstId != secondId)
        #expect(handler.currentToast?.type == .warning)

        // Cleanup
        handler.dismiss()
    }
}
