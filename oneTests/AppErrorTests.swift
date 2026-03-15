//
//  AppErrorTests.swift
//  oneTests
//
//  Tests for AppError — error descriptions, titles, retry flags, CKError conversion.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

// MARK: - AppError Tests

struct AppErrorTests {

    // MARK: - Error Description Tests

    @Test("All errors produce non-empty error descriptions (Turkish messages)")
    func testAllErrorDescriptionsNonEmpty() {
        let allErrors: [AppError] = [
            .networkUnavailable,
            .networkTimeout,
            .networkUnknown(underlying: NSError(domain: "test", code: 0)),
            .cloudKitNotAvailable,
            .cloudKitNotAuthenticated,
            .cloudKitRecordNotFound,
            .cloudKitSchemaError,
            .cloudKitServerConflict,
            .cloudKitQuotaExceeded,
            .cloudKitUnknown(underlying: NSError(domain: "test", code: 0)),
            .persistenceSaveFailed(underlying: NSError(domain: "test", code: 0)),
            .persistenceFetchFailed(underlying: NSError(domain: "test", code: 0)),
            .persistenceDeleteFailed(underlying: NSError(domain: "test", code: 0)),
            .persistenceMigrationFailed,
            .authAppleMusicDenied,
            .authAppleMusicRestricted,
            .authSpotifyFailed,
            .authSpotifyTokenExpired,
            .authSpotifyNotConnected,
            .musicSearchFailed(underlying: NSError(domain: "test", code: 0)),
            .musicNoResults,
            .musicPlaybackFailed,
            .musicServiceUnavailable,
            .cameraDenied,
            .cameraUnavailable,
            .photoSaveFailed,
            .circleUserNotFound,
            .circleAlreadyFriend,
            .circleSelfAdd,
            .circleInviteCodeInvalid,
            .circleFriendRequestFailed(underlying: NSError(domain: "test", code: 0)),
            .unknown(message: "Test error")
        ]

        for error in allErrors {
            let desc = error.errorDescription
            #expect(desc != nil, "Error \(error) should have a description")
            #expect(!desc!.isEmpty, "Error \(error) should have a non-empty description")
        }
    }

    // MARK: - Specific Descriptions

    @Test("Network unavailable returns Turkish internet message")
    func testNetworkUnavailableDescription() {
        let desc = AppError.networkUnavailable.errorDescription!
        #expect(desc.contains("İnternet") || desc.contains("internet") || desc.contains("bağlantı"))
    }

    @Test("CloudKit not authenticated returns login message")
    func testCloudKitNotAuthenticatedDescription() {
        let desc = AppError.cloudKitNotAuthenticated.errorDescription!
        #expect(desc.contains("iCloud") || desc.contains("giriş"))
    }

    @Test("Music no results returns appropriate message")
    func testMusicNoResultsDescription() {
        let desc = AppError.musicNoResults.errorDescription!
        #expect(desc.contains("bulunamadı") || desc.contains("Sonuç"))
    }

    @Test("Circle self-add returns appropriate message")
    func testCircleSelfAddDescription() {
        let desc = AppError.circleSelfAdd.errorDescription!
        #expect(desc.contains("kendi"))
    }

    @Test("Unknown error passes custom message")
    func testUnknownErrorMessage() {
        let customMessage = "Özel bir hata mesajı"
        let desc = AppError.unknown(message: customMessage).errorDescription
        #expect(desc == customMessage)
    }

    // MARK: - Title Tests

    @Test("All errors produce non-empty titles")
    func testAllErrorTitlesNonEmpty() {
        let sampleErrors: [AppError] = [
            .networkUnavailable,
            .cloudKitNotAvailable,
            .persistenceSaveFailed(underlying: NSError(domain: "t", code: 0)),
            .authSpotifyFailed,
            .musicNoResults,
            .cameraDenied,
            .circleUserNotFound,
            .unknown(message: "x")
        ]

        for error in sampleErrors {
            let title = error.title
            #expect(!title.isEmpty, "Error \(error) should have a non-empty title")
        }
    }

    @Test("Network errors return 'Bağlantı Hatası' title")
    func testNetworkErrorTitle() {
        #expect(AppError.networkUnavailable.title == "Bağlantı Hatası")
        #expect(AppError.networkTimeout.title == "Bağlantı Hatası")
        #expect(AppError.networkUnknown(underlying: NSError(domain: "t", code: 0)).title == "Bağlantı Hatası")
    }

    @Test("CloudKit errors return 'iCloud Hatası' title")
    func testCloudKitErrorTitle() {
        #expect(AppError.cloudKitNotAvailable.title == "iCloud Hatası")
        #expect(AppError.cloudKitNotAuthenticated.title == "iCloud Hatası")
        #expect(AppError.cloudKitRecordNotFound.title == "iCloud Hatası")
    }

    @Test("Persistence errors return 'Kayıt Hatası' title")
    func testPersistenceErrorTitle() {
        let err = NSError(domain: "test", code: 1)
        #expect(AppError.persistenceSaveFailed(underlying: err).title == "Kayıt Hatası")
        #expect(AppError.persistenceFetchFailed(underlying: err).title == "Kayıt Hatası")
        #expect(AppError.persistenceDeleteFailed(underlying: err).title == "Kayıt Hatası")
        #expect(AppError.persistenceMigrationFailed.title == "Kayıt Hatası")
    }

    @Test("Auth errors return 'Yetkilendirme' title")
    func testAuthErrorTitle() {
        #expect(AppError.authSpotifyFailed.title == "Yetkilendirme")
        #expect(AppError.authAppleMusicDenied.title == "Yetkilendirme")
    }

    @Test("Music errors return 'Müzik Hatası' title")
    func testMusicErrorTitle() {
        #expect(AppError.musicNoResults.title == "Müzik Hatası")
        #expect(AppError.musicPlaybackFailed.title == "Müzik Hatası")
    }

    @Test("Camera errors return 'Kamera Hatası' title")
    func testCameraErrorTitle() {
        #expect(AppError.cameraDenied.title == "Kamera Hatası")
        #expect(AppError.cameraUnavailable.title == "Kamera Hatası")
        #expect(AppError.photoSaveFailed.title == "Kamera Hatası")
    }

    @Test("Circle errors return 'Çevre Hatası' title")
    func testCircleErrorTitle() {
        #expect(AppError.circleUserNotFound.title == "Çevre Hatası")
        #expect(AppError.circleAlreadyFriend.title == "Çevre Hatası")
        #expect(AppError.circleSelfAdd.title == "Çevre Hatası")
    }

    @Test("Unknown error returns 'Hata' title")
    func testUnknownErrorTitle() {
        #expect(AppError.unknown(message: "xyz").title == "Hata")
    }

    // MARK: - Retry Tests

    @Test("Retryable errors are correctly flagged")
    func testRetryableErrors() {
        let retryable: [AppError] = [
            .networkUnavailable,
            .networkTimeout,
            .networkUnknown(underlying: NSError(domain: "t", code: 0)),
            .cloudKitServerConflict,
            .cloudKitUnknown(underlying: NSError(domain: "t", code: 0)),
            .musicSearchFailed(underlying: NSError(domain: "t", code: 0)),
            .circleFriendRequestFailed(underlying: NSError(domain: "t", code: 0)),
        ]

        for error in retryable {
            #expect(error.isRetryable == true, "\(error) should be retryable")
        }
    }

    @Test("Non-retryable errors are correctly flagged")
    func testNonRetryableErrors() {
        let nonRetryable: [AppError] = [
            .cloudKitNotAvailable,
            .cloudKitNotAuthenticated,
            .cloudKitRecordNotFound,
            .cloudKitSchemaError,
            .cloudKitQuotaExceeded,
            .persistenceSaveFailed(underlying: NSError(domain: "t", code: 0)),
            .persistenceFetchFailed(underlying: NSError(domain: "t", code: 0)),
            .persistenceDeleteFailed(underlying: NSError(domain: "t", code: 0)),
            .persistenceMigrationFailed,
            .authAppleMusicDenied,
            .authAppleMusicRestricted,
            .authSpotifyFailed,
            .authSpotifyTokenExpired,
            .authSpotifyNotConnected,
            .musicNoResults,
            .musicPlaybackFailed,
            .musicServiceUnavailable,
            .cameraDenied,
            .cameraUnavailable,
            .photoSaveFailed,
            .circleUserNotFound,
            .circleAlreadyFriend,
            .circleSelfAdd,
            .circleInviteCodeInvalid,
            .unknown(message: "x"),
        ]

        for error in nonRetryable {
            #expect(error.isRetryable == false, "\(error) should NOT be retryable")
        }
    }

    // MARK: - CKError Conversion Tests

    @Test("CKError code 1 maps to cloudKitNotAuthenticated")
    func testCKError1() {
        let ckError = NSError(domain: "CKErrorDomain", code: 1)
        let appError = AppError.from(cloudKitError: ckError)
        if case .cloudKitNotAuthenticated = appError {
            // pass
        } else {
            Issue.record("CKError code 1 should map to .cloudKitNotAuthenticated, got \(appError)")
        }
    }

    @Test("CKError code 11 maps to cloudKitRecordNotFound")
    func testCKError11() {
        let ckError = NSError(domain: "CKErrorDomain", code: 11)
        let appError = AppError.from(cloudKitError: ckError)
        if case .cloudKitRecordNotFound = appError {
            // pass
        } else {
            Issue.record("CKError code 11 should map to .cloudKitRecordNotFound, got \(appError)")
        }
    }

    @Test("CKError codes 12 and 26 map to cloudKitSchemaError")
    func testCKErrorSchemaErrors() {
        for code in [12, 26] {
            let ckError = NSError(domain: "CKErrorDomain", code: code)
            let appError = AppError.from(cloudKitError: ckError)
            if case .cloudKitSchemaError = appError {
                // pass
            } else {
                Issue.record("CKError code \(code) should map to .cloudKitSchemaError, got \(appError)")
            }
        }
    }

    @Test("CKError code 14 maps to cloudKitServerConflict")
    func testCKError14() {
        let ckError = NSError(domain: "CKErrorDomain", code: 14)
        let appError = AppError.from(cloudKitError: ckError)
        if case .cloudKitServerConflict = appError {
            // pass
        } else {
            Issue.record("CKError code 14 should map to .cloudKitServerConflict, got \(appError)")
        }
    }

    @Test("CKError code 25 maps to cloudKitQuotaExceeded")
    func testCKError25() {
        let ckError = NSError(domain: "CKErrorDomain", code: 25)
        let appError = AppError.from(cloudKitError: ckError)
        if case .cloudKitQuotaExceeded = appError {
            // pass
        } else {
            Issue.record("CKError code 25 should map to .cloudKitQuotaExceeded, got \(appError)")
        }
    }

    @Test("Unknown CKError code maps to cloudKitUnknown")
    func testCKErrorUnknown() {
        let ckError = NSError(domain: "CKErrorDomain", code: 999)
        let appError = AppError.from(cloudKitError: ckError)
        if case .cloudKitUnknown = appError {
            // pass
        } else {
            Issue.record("CKError code 999 should map to .cloudKitUnknown, got \(appError)")
        }
    }

    @Test("Non-CKError domain returns cloudKitUnknown")
    func testNonCKErrorDomain() {
        let genericError = NSError(domain: "SomeOtherDomain", code: 1)
        let appError = AppError.from(cloudKitError: genericError)
        if case .cloudKitUnknown = appError {
            // pass
        } else {
            Issue.record("Non-CKErrorDomain should map to .cloudKitUnknown, got \(appError)")
        }
    }

    // MARK: - Identifiable Tests

    @Test("AppError id matches localizedDescription")
    func testIdentifiable() {
        let error = AppError.networkUnavailable
        #expect(error.id == error.localizedDescription)
    }
}
