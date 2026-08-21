//
//  LanguageManager.swift
//  one
//
//  Manages in-app language selection and propagates changes to the full SwiftUI tree.
//

import SwiftUI
import Combine

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable, Identifiable {
    case system  = "system"
    case tr      = "tr"
    case en      = "en"
    case de      = "de"
    case fr      = "fr"
    case es      = "es"
    case ru      = "ru"
    case ja      = "ja"
    case ko      = "ko"
    case zhHans  = "zh-Hans"

    var id: String { rawValue }

    /// Human-readable name always shown in the language itself (for the picker list).
    var displayName: String {
        switch self {
        case .system:  return "Sistem Dili"
        case .tr:      return "Türkçe"
        case .en:      return "English"
        case .de:      return "Deutsch"
        case .fr:      return "Français"
        case .es:      return "Español"
        case .ru:      return "Русский"
        case .ja:      return "日本語"
        case .ko:      return "한국어"
        case .zhHans:  return "简体中文"
        }
    }

    /// The lproj folder name to look up in Bundle.main.
    var bundleCode: String {
        switch self {
        case .system:
            // Locale.preferredLanguages is the most reliable cross-version API.
            // It returns BCP-47 tags like "tr-TR", "en-US", "zh-Hans-CN".
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh-Hans") { return "zh-Hans" }
            return String(preferred.prefix(2))
        default:
            return rawValue
        }
    }

    /// BCP-47 locale identifier for date / number formatters.
    var localeIdentifier: String {
        switch self {
        case .system:  return Locale.current.identifier
        case .tr:      return "tr_TR"
        case .en:      return "en_US"
        case .de:      return "de_DE"
        case .fr:      return "fr_FR"
        case .es:      return "es_ES"
        case .ru:      return "ru_RU"
        case .ja:      return "ja_JP"
        case .ko:      return "ko_KR"
        case .zhHans:  return "zh_Hans_CN"
        }
    }
}

// MARK: - LanguageManager

/// Singleton that drives runtime language switching.
/// Inject as `@EnvironmentObject` from the root scene and apply
/// `.id(languageManager.refreshToken)` to the root view so the entire
/// SwiftUI tree rebuilds when the language changes.
final class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    /// Changing this token triggers a full SwiftUI tree rebuild via `.id(refreshToken)`.
    @Published private(set) var refreshToken = UUID()
    @Published private(set) var currentLanguage: AppLanguage

    private init() {
        let saved = UserDefaults.standard.string(forKey: ONEConfig.languagePreferenceKey)
        let lang  = AppLanguage(rawValue: saved ?? "") ?? .system
        self.currentLanguage = lang
        Bundle.setLanguage(lang.bundleCode)
    }

    /// Apply a new language. Persists the choice and forces a full UI rebuild.
    func setLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: ONEConfig.languagePreferenceKey)
        Bundle.setLanguage(language.bundleCode)
        currentLanguage = language
        refreshToken    = UUID()
    }

    /// Convenience locale for date / number formatters.
    var currentLocale: Locale {
        currentLanguage == .system
            ? Locale.current
            : Locale(identifier: currentLanguage.localeIdentifier)
    }
}
