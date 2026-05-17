//
//  WhatsNewManager.swift
//  one
//
//  Güncelleme sonrası ilk açılışta "Yenilikler" sheet'ini tetikler.
//  Son görülen sürüm UserDefaults'a yazılır; bir sonraki major/minor sürümde tetiklenir.
//

import Foundation

final class WhatsNewManager {
    static let shared = WhatsNewManager()

    private let lastSeenVersionKey = "whatsNew_lastSeenVersion"

    var shouldShow: Bool {
        let current = currentVersion
        let lastSeen = UserDefaults.standard.string(forKey: lastSeenVersionKey) ?? ""
        return current.isNewerThan(lastSeen)
    }

    func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenVersionKey)
    }

    #if DEBUG
    func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: lastSeenVersionKey)
    }
    #endif

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private init() {}
}

private extension String {
    func isNewerThan(_ other: String) -> Bool {
        let lhs = components(separatedBy: ".").compactMap { Int($0) }
        let rhs = other.components(separatedBy: ".").compactMap { Int($0) }
        let maxLen = max(lhs.count, rhs.count)
        for i in 0..<maxLen {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
