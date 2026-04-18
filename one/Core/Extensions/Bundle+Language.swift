//
//  Bundle+Language.swift
//  one
//
//  Runtime language switching without app restart.
//  Uses objc runtime to replace Bundle.main's localization lookup.
//

import Foundation

private var bundleKey: UInt8 = 0

/// A Bundle subclass that overrides localizedString to serve the user-selected language.
final class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Swaps the active language bundle at runtime. Call before any UI is rendered.
    static func setLanguage(_ language: String) {
        defer {
            // Replace Bundle.main's class so all subsequent NSLocalizedString calls go through LanguageBundle
            object_setClass(Bundle.main, LanguageBundle.self)
        }
        guard
            let path = Bundle.main.path(forResource: language, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            // Language bundle not found — fall back to system behaviour
            objc_setAssociatedObject(Bundle.main, &bundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }
        objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
