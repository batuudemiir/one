//
//  CloudKitManager+Async.swift
//  one
//
//  Async/await wrappers around the existing completion-handler API
//  (Faz 4.1, 2026-04-26).
//
//  Apple-recommended migration pattern: keep the original completion-based
//  surface (24 callsites across the app) untouched, expose an async sibling
//  for new code. Existing callers can migrate PR-by-PR without big-bang risk.
//
//  Convention: original `foo(..., completion:)` → `fooAsync(...)` returns
//  `T` on success, throws `AppError` on failure.
//
//  Retry: wrap calls in `RetryPolicy.cloudKitRetry { ... }` for transient-aware
//  exponential backoff.
//

import Foundation
import CloudKit
import Combine

extension CloudKitManager {

    // MARK: - User Lifecycle

    /// Async wrapper for `createOrFetchUser(displayName:completion:)`.
    func createOrFetchUserAsync(displayName: String) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            createOrFetchUser(displayName: displayName) { result in
                switch result {
                case .success(let record):
                    continuation.resume(returning: record)
                case .failure(let error):
                    continuation.resume(throwing: AppError.from(cloudKitError: error))
                }
            }
        }
    }

    /// Async wrapper for `updateUserProfile(displayName:avatarColor:username:completion:)`.
    func updateUserProfileAsync(
        displayName: String,
        avatarColor: String,
        username: String? = nil
    ) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            updateUserProfile(displayName: displayName, avatarColor: avatarColor, username: username) { result in
                switch result {
                case .success(let record):
                    continuation.resume(returning: record)
                case .failure(let error):
                    continuation.resume(throwing: AppError.from(cloudKitError: error))
                }
            }
        }
    }

    // MARK: - User Lookup

    /// Async wrapper for `findUserByInviteCode(_:completion:)`.
    func findUserByInviteCodeAsync(_ code: String) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            findUserByInviteCode(code) { result in
                switch result {
                case .success(let record):
                    continuation.resume(returning: record)
                case .failure(let error):
                    continuation.resume(throwing: AppError.from(cloudKitError: error))
                }
            }
        }
    }

    /// Async wrapper for `findUserByUsername(_:completion:)`.
    func findUserByUsernameAsync(_ username: String) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            findUserByUsername(username) { result in
                switch result {
                case .success(let record):
                    continuation.resume(returning: record)
                case .failure(let error):
                    continuation.resume(throwing: AppError.from(cloudKitError: error))
                }
            }
        }
    }

    /// Async wrapper for `findUserByCodeOrUsername(_:completion:)`.
    func findUserByCodeOrUsernameAsync(_ searchText: String) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            findUserByCodeOrUsername(searchText) { result in
                switch result {
                case .success(let record):
                    continuation.resume(returning: record)
                case .failure(let error):
                    continuation.resume(throwing: AppError.from(cloudKitError: error))
                }
            }
        }
    }

    /// Async wrapper for `checkUsernameAvailability(_:excludingCurrentUser:completion:)`.
    func checkUsernameAvailabilityAsync(_ username: String, excludingCurrentUser: Bool = false) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            checkUsernameAvailability(username, excludingCurrentUser: excludingCurrentUser) { result in
                switch result {
                case .success(let available):
                    continuation.resume(returning: available)
                case .failure(let error):
                    continuation.resume(throwing: AppError.from(cloudKitError: error))
                }
            }
        }
    }

    // MARK: - Daily Shares (Circle data)

    /// Async wrapper for `fetchUserDailyShare(for:completion:)`.
    func fetchUserDailyShareAsync(for date: Date) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            fetchUserDailyShare(for: date) { result in
                switch result {
                case .success(let record):
                    continuation.resume(returning: record)
                case .failure(let error):
                    continuation.resume(throwing: AppError.from(cloudKitError: error))
                }
            }
        }
    }

    /// Async wrapper for `fetchFriendsDailyShares(for:completion:)`.
    func fetchFriendsDailySharesAsync(for date: Date) async throws -> [FriendCircleData] {
        try await withCheckedThrowingContinuation { continuation in
            fetchFriendsDailyShares(for: date) { result in
                switch result {
                case .success(let shares):
                    continuation.resume(returning: shares)
                case .failure(let error):
                    continuation.resume(throwing: AppError.from(cloudKitError: error))
                }
            }
        }
    }

    /// Async wrapper for `fetchReceivedEmojiReactions(shareRecordName:completion:)`.
    /// Returns empty array on failure (matches original API non-throwing semantic).
    @available(*, deprecated, message: "v2.5 — yorum sistemine geçildi.")
    func fetchReceivedEmojiReactionsAsync(shareRecordName: String) async -> [EmojiReactionItem] {
        await withCheckedContinuation { continuation in
            fetchReceivedEmojiReactions(shareRecordName: shareRecordName) { items in
                continuation.resume(returning: items)
            }
        }
    }

    // MARK: - Friendship

    /// Async wrapper for `fetchPendingRequestCount(completion:)`.
    /// Original is non-throwing — returns 0 on failure.
    func fetchPendingRequestCountAsync() async -> Int {
        await withCheckedContinuation { continuation in
            fetchPendingRequestCount { count in
                continuation.resume(returning: count)
            }
        }
    }

    /// Async wrapper for `removeFriend(friendUserID:completion:)`.
    func removeFriendAsync(friendUserID: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            removeFriend(friendUserID: friendUserID) { result in
                switch result {
                case .success(let removed):
                    continuation.resume(returning: removed)
                case .failure(let error):
                    continuation.resume(throwing: AppError.from(cloudKitError: error))
                }
            }
        }
    }

    /// Async wrapper for `blockUser(userID:completion:)`.
    func blockUserAsync(userID: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            blockUser(userID: userID) { result in
                switch result {
                case .success(let blocked):
                    continuation.resume(returning: blocked)
                case .failure(let error):
                    continuation.resume(throwing: AppError.from(cloudKitError: error))
                }
            }
        }
    }
}
