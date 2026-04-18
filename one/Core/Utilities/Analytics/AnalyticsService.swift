//
//  AnalyticsService.swift
//  one
//
//  Product analytics bridge. `AppAnalytics.shared` is the call-site API;
//  behind it a list of registered `AnalyticsService` conformers fan out
//  the event. Default registry is empty — on DEBUG a console logger
//  is attached. Production SDKs (PostHog, Mixpanel) register themselves
//  from `oneApp.init()` once their SPM packages are wired in.
//
//  See docs/OBSERVABILITY_SETUP.md for SDK wiring instructions.
//

import Foundation

// MARK: - AnalyticsService

protocol AnalyticsService: AnyObject {
    func track(event: AnalyticsEvent)
    func identify(userID: String, properties: [String: Any])
    func reset()
}

// MARK: - AppAnalytics

/// Fan-out dispatcher. Thread-safe for registration + tracking.
final class AppAnalytics {
    static let shared = AppAnalytics()

    private let queue = DispatchQueue(label: "app.analytics.dispatch", qos: .utility)
    private var services: [AnalyticsService] = []

    private init() {}

    // MARK: Registration

    /// Register a backend. Called from `oneApp.init()`.
    func register(_ service: AnalyticsService) {
        queue.sync { services.append(service) }
    }

    /// Remove all services — used by tests.
    func unregisterAll() {
        queue.sync { services.removeAll() }
    }

    // MARK: Tracking

    func track(_ event: AnalyticsEvent) {
        queue.async { [services] in
            services.forEach { $0.track(event: event) }
        }
    }

    func identify(userID: String, properties: [String: Any] = [:]) {
        queue.async { [services] in
            services.forEach { $0.identify(userID: userID, properties: properties) }
        }
    }

    func reset() {
        queue.async { [services] in
            services.forEach { $0.reset() }
        }
    }
}

// MARK: - ConsoleAnalyticsService

/// DEBUG-only analytics sink. Routes every event through `ONELogger`
/// so developers can watch the funnel in Console.app without a backend.
final class ConsoleAnalyticsService: AnalyticsService {
    func track(event: AnalyticsEvent) {
        #if DEBUG
        let props = event.properties.isEmpty
            ? ""
            : " \(event.properties)"
        ONELogger.info("analytics: \(event.name)\(props)", category: .general)
        #endif
    }

    func identify(userID: String, properties: [String: Any]) {
        #if DEBUG
        ONELogger.info("analytics: identify \(userID.prefix(8))…", category: .general)
        #endif
    }

    func reset() {
        #if DEBUG
        ONELogger.info("analytics: reset", category: .general)
        #endif
    }
}
