//
//  RetryPolicyTests.swift
//  oneTests
//
//  Tests for RetryPolicy — exponential backoff, attempt cap, predicate filtering,
//  CloudKit-aware retry, and successful result short-circuit.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

// MARK: - Test Helpers

/// Tiny actor counter to make attempt-count assertions safe across continuations.
private actor AttemptCounter {
    private(set) var count: Int = 0
    func increment() -> Int {
        count += 1
        return count
    }
}

private struct DummyError: Error, Equatable {
    let label: String
}

// MARK: - RetryPolicy Tests

struct RetryPolicyTests {

    // MARK: - Success Paths

    @Test("Successful operation completes on first attempt without retry")
    func testSuccessOnFirstAttempt() async throws {
        let counter = AttemptCounter()
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.05, jitterFraction: 0)

        let result: String = try await policy.run {
            _ = await counter.increment()
            return "ok"
        }

        let attempts = await counter.count
        #expect(result == "ok")
        #expect(attempts == 1)
    }

    @Test("Recovers on second attempt when first throws transient error")
    func testRecoversOnSecondAttempt() async throws {
        let counter = AttemptCounter()
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.05, jitterFraction: 0)

        let result: Int = try await policy.run {
            let n = await counter.increment()
            if n < 2 { throw DummyError(label: "transient") }
            return 42
        }

        let attempts = await counter.count
        #expect(result == 42)
        #expect(attempts == 2)
    }

    // MARK: - Failure Paths

    @Test("Throws last error after exhausting maxAttempts")
    func testFailsAfterExhaustingAttempts() async {
        let counter = AttemptCounter()
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.05, jitterFraction: 0)

        await #expect(throws: DummyError.self) {
            try await policy.run {
                _ = await counter.increment()
                throw DummyError(label: "always-fails")
            }
        }

        let attempts = await counter.count
        #expect(attempts == 3, "Should attempt exactly maxAttempts times before throwing")
    }

    @Test("Override maxAttempts at call site is respected")
    func testOverrideMaxAttempts() async {
        let counter = AttemptCounter()
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 0.01, maxDelay: 0.05, jitterFraction: 0)

        await #expect(throws: DummyError.self) {
            try await policy.run(maxAttempts: 2) {
                _ = await counter.increment()
                throw DummyError(label: "fail")
            }
        }

        let attempts = await counter.count
        #expect(attempts == 2, "Override should cap at 2 even though policy default is 5")
    }

    // MARK: - Predicate Filtering

    @Test("shouldRetry=false short-circuits and throws immediately on permanent error")
    func testShouldRetryFalseStopsRetrying() async {
        let counter = AttemptCounter()
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 0.01, maxDelay: 0.05, jitterFraction: 0)

        await #expect(throws: DummyError.self) {
            try await policy.run(
                shouldRetry: { _ in false },
                operation: {
                    _ = await counter.increment()
                    throw DummyError(label: "permanent")
                }
            )
        }

        let attempts = await counter.count
        #expect(attempts == 1, "shouldRetry=false should stop after first attempt")
    }

    @Test("Predicate can filter by error type")
    func testPredicateFiltersByErrorType() async {
        let counter = AttemptCounter()
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 0.01, maxDelay: 0.05, jitterFraction: 0)

        await #expect(throws: DummyError.self) {
            try await policy.run(
                shouldRetry: { error in
                    // Only retry transient errors
                    (error as? DummyError)?.label == "transient"
                },
                operation: {
                    let n = await counter.increment()
                    throw DummyError(label: n < 2 ? "transient" : "permanent")
                }
            )
        }

        let attempts = await counter.count
        // First throws transient → retried; second throws permanent → not retried
        #expect(attempts == 2)
    }

    // MARK: - Initialization Bounds

    @Test("maxAttempts is clamped to minimum 1")
    func testMaxAttemptsClampedToOne() async {
        let counter = AttemptCounter()
        let policy = RetryPolicy(maxAttempts: 0, baseDelay: 0.01, maxDelay: 0.05, jitterFraction: 0)

        await #expect(throws: DummyError.self) {
            try await policy.run {
                _ = await counter.increment()
                throw DummyError(label: "fail")
            }
        }

        let attempts = await counter.count
        #expect(attempts == 1, "maxAttempts=0 should be clamped to 1")
    }

    @Test("Jitter fraction is clamped to 0...1 range")
    func testJitterFractionClamped() async {
        let policyHigh = RetryPolicy(jitterFraction: 5.0)
        let policyLow = RetryPolicy(jitterFraction: -1.0)
        let high = await policyHigh.jitterFraction
        let low = await policyLow.jitterFraction
        #expect(high == 1.0)
        #expect(low == 0.0)
    }

    @Test("maxDelay never less than baseDelay")
    func testMaxDelayClampedToBase() async {
        let policy = RetryPolicy(baseDelay: 1.0, maxDelay: 0.1)
        let maxDelay = await policy.maxDelay
        let baseDelay = await policy.baseDelay
        #expect(maxDelay >= baseDelay)
    }

    // MARK: - CloudKit-Aware Retry

    @Test("cloudKitRetry retries transient CKError")
    func testCloudKitRetryRetriesTransient() async throws {
        let counter = AttemptCounter()

        // CKErrorDomain code 14 = networkFailure → maps to .cloudKitServerConflict (retryable)
        let transientError = NSError(domain: "CKErrorDomain", code: 14, userInfo: nil)

        let result: String = try await RetryPolicy.cloudKitRetry {
            let n = await counter.increment()
            if n < 2 { throw transientError }
            return "recovered"
        }

        let attempts = await counter.count
        #expect(result == "recovered")
        #expect(attempts == 2)
    }

    @Test("cloudKitRetry does NOT retry permanent CKError (quotaExceeded)")
    func testCloudKitRetryDoesNotRetryPermanent() async {
        let counter = AttemptCounter()

        // CKErrorDomain code 25 = quotaExceeded → maps to .cloudKitQuotaExceeded (NOT retryable)
        let permanentError = NSError(domain: "CKErrorDomain", code: 25, userInfo: nil)

        await #expect(throws: AppError.self) {
            try await RetryPolicy.cloudKitRetry {
                _ = await counter.increment()
                throw permanentError
            }
        }

        let attempts = await counter.count
        #expect(attempts == 1, "Quota exceeded is permanent — should not retry")
    }

    // MARK: - Timing Sanity (loose — just ensure backoff actually waits)

    @Test("Multiple retries take at least baseDelay between attempts")
    func testBackoffIntroducesDelay() async {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0.05, maxDelay: 0.2, jitterFraction: 0)
        let start = Date()

        _ = try? await policy.run {
            throw DummyError(label: "fail")
        }

        let elapsed = Date().timeIntervalSince(start)
        // 2 retries × at least baseDelay=0.05s each = 0.1s minimum
        // (no jitter, exponential: 0.05 + 0.10 = 0.15s)
        #expect(elapsed >= 0.1, "Backoff should introduce noticeable delay (got \(elapsed)s)")
    }
}
