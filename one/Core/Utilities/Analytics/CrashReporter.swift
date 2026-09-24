//
//  CrashReporter.swift
//  one
//
//  Crash + non-fatal error reporting bridge. Call
//  `CrashReporter.shared.capture(error:)` from catch blocks where the
//  failure is meaningful but not crashing. Initialization happens from
//  `oneApp.init()` — default is a no-op. Sentry SPM install plugs in.
//
//  See docs/OBSERVABILITY_SETUP.md.
//

import Foundation

// MARK: - CrashReporting

protocol CrashReporting: AnyObject {
    func capture(error: Error, context: [String: Any])
    func capture(message: String, level: CrashLevel)
    func setUser(id: String?)
    func addBreadcrumb(_ message: String, category: String)
}

enum CrashLevel: String {
    case info, warning, error, fatal
}

// MARK: - CrashReporter dispatcher

final class CrashReporter: CrashReporting {
    static let shared = CrashReporter()

    private var backend: CrashReporting?

    private init() {}

    /// Wire the real backend (Sentry) from app bootstrap.
    func register(_ backend: CrashReporting) {
        self.backend = backend
    }

    // MARK: Forwarding

    func capture(error: Error, context: [String: Any] = [:]) {
        #if DEBUG
        ONELogger.error("crash: non-fatal captured", error: error)
        #endif
        backend?.capture(error: error, context: context)
    }

    func capture(message: String, level: CrashLevel = .error) {
        #if DEBUG
        ONELogger.warning("crash: \(level.rawValue) — \(message)")
        #endif
        backend?.capture(message: message, level: level)
    }

    func setUser(id: String?) {
        backend?.setUser(id: id)
    }

    func addBreadcrumb(_ message: String, category: String = "app") {
        backend?.addBreadcrumb(message, category: category)
    }
}
