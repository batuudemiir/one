//
//  RetryPolicy.swift
//  one
//
//  Generic exponential-backoff retry actor (Faz 4.1, 2026-04-26).
//
//  Tek bir merkezi retry poliçesi → CloudKit, network, ve diğer transient failure
//  noktalarında kullanılabilir. Eski elle-yazılmış DispatchGroup + manuel
//  retry'ları yerini alır.
//
//  Kullanım:
//    let result: CKRecord = try await RetryPolicy.shared.run {
//        try await ckManager.fetchUserAsync()
//    }
//

import Foundation

actor RetryPolicy {
    static let shared = RetryPolicy()

    /// Defaults — uçtan uca güvenli, network operasyonları için makul.
    /// Override gerekirse `init(...)`/`run(maxAttempts:...)` ile özelleştir.
    let maxAttempts: Int
    let baseDelay: TimeInterval     // ilk retry öncesi bekleme
    let maxDelay: TimeInterval      // backoff tavanı
    let jitterFraction: Double      // 0...1, [base * (1 - j), base * (1 + j)] aralığında rastgele

    init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 8.0,
        jitterFraction: Double = 0.25
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.jitterFraction = max(0, min(1, jitterFraction))
    }

    /// Çalıştırır, transient hata olursa exponential backoff ile tekrar dener.
    /// `shouldRetry` predicate'i ile hata-tipine göre karar ver (default: tüm hatalar retry).
    func run<T: Sendable>(
        maxAttempts overrideMax: Int? = nil,
        shouldRetry: @Sendable (Error) -> Bool = { _ in true },
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let attempts = overrideMax ?? maxAttempts
        var lastError: Error?

        for attempt in 0..<attempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard attempt < attempts - 1, shouldRetry(error) else {
                    throw error
                }
                let delay = backoffDelay(for: attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // Defensive — yukarıdaki for'dan throw olmadan çıkmamalıyız
        throw lastError ?? CancellationError()
    }

    private func backoffDelay(for attempt: Int) -> TimeInterval {
        // Exponential: base * 2^attempt, capped at maxDelay
        let exp = baseDelay * pow(2.0, Double(attempt))
        let capped = min(exp, maxDelay)
        // Jitter: [capped * (1 - j), capped * (1 + j)]
        let lower = capped * (1 - jitterFraction)
        let upper = capped * (1 + jitterFraction)
        return Double.random(in: lower...upper)
    }
}

// MARK: - CloudKit-specific helpers

extension RetryPolicy {
    /// CloudKit-aware retry: sadece transient hatalarda tekrar dener.
    /// Quota / not-authenticated / not-found gibi kalıcı hatalarda anında throw eder.
    static func cloudKitRetry<T: Sendable>(
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        try await shared.run(
            shouldRetry: { error in
                let appError = AppError.from(cloudKitError: error)
                return appError.isRetryable
            },
            operation: operation
        )
    }
}
