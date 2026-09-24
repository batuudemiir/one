//
//  Experiment.swift
//  one
//
//  Lightweight A/B bucket system. Assigns users to experiment variants
//  deterministically via UserDefaults so the bucket survives app restarts.
//
//  Usage:
//    if Experiment.isEnabled(.colorPickerLabelDelay) { ... }
//    Experiment.variant(for: .colorPickerLabelDelay) // "control" | "treatment"
//

import Foundation

// MARK: - Experiment Keys

enum ExperimentKey: String, CaseIterable {
    /// #02 — Renk-önce: label gizleme açık mı?
    case colorPickerLabelDelay   = "exp_color_label_delay"
    /// #04 — Çevre mutual disclosure blur aktif mi?
    case mutualDisclosureBlur    = "exp_mutual_disclosure_blur"
    /// #07 — Şarkı seçimi sonrası onay mikrosu aktif mi?
    case songConfirmMicro        = "exp_song_confirm_micro"
    /// #08 — Onboarding'de ilk renk seçimi "ilk giriş" çerçevelemesi
    case onboardingFirstEntry    = "exp_onboarding_first_entry"
    /// #09 — Açılış ekranı sosyal katman (Çevre) mı, yoksa Bugün mü?
    /// Veri: Solo D30 %0 vs Sosyal D30 %20.7 — retention'ı sosyal katman taşıyor.
    case defaultLaunchScreen     = "exp_default_launch_screen"
}

// MARK: - Experiment

/// Deterministic 50/50 bucketing stored in UserDefaults.
/// Call `Experiment.assign()` once at app launch to lock all buckets.
enum Experiment {

    private static let defaults = UserDefaults.standard

    /// Assign all experiments that haven't been bucketed yet.
    /// Call from `oneApp.init()` after analytics is ready.
    static func assign() {
        for key in ExperimentKey.allCases {
            let storageKey = key.rawValue
            guard defaults.string(forKey: storageKey) == nil else { continue }
            let variant: String = Bool.random() ? "treatment" : "control"
            defaults.set(variant, forKey: storageKey)
        }
    }

    /// Returns the variant string for the given experiment ("control" | "treatment").
    /// Defaults to "control" if not yet assigned.
    static func variant(for key: ExperimentKey) -> String {
        defaults.string(forKey: key.rawValue) ?? "control"
    }

    /// Convenience: returns true when the user is in "treatment".
    static func isEnabled(_ key: ExperimentKey) -> Bool {
        variant(for: key) == "treatment"
    }

    /// Force a specific variant — for QA/testing only.
    static func override(_ key: ExperimentKey, variant: String) {
        defaults.set(variant, forKey: key.rawValue)
    }

    /// Reset all experiment buckets (for testing / re-bucketing).
    static func reset() {
        ExperimentKey.allCases.forEach {
            defaults.removeObject(forKey: $0.rawValue)
        }
    }
}

// MARK: - Derived Configuration

extension Experiment {

    /// Uygulama açılışında gösterilecek sekme.
    ///
    /// Tek kaynak: hem `ColorPickerViewModel.currentScreen` hem de
    /// `ONEColorPickerView.lastTab` bunu okur. İkisi ayrı düşerse TabView ilk
    /// `.confirm`/`.done` overlay dönüşünde yanlış sekmeye snap eder — bu yüzden
    /// ikisi de burayı kullanmalı, sabit yazılmamalı.
    static var defaultLaunchScreen: ScreenType {
        isEnabled(.defaultLaunchScreen) ? .circle : .today
    }

    /// Tüm deney kovaları, analytics `identify` için user property sözlüğü.
    ///
    /// Bu olmadan deney **okunamaz**: PostHog'da kullanıcıyı koluna göre
    /// segmentleyemezsen D7/D30 farkını değişikliğe bağlayamazsın.
    static var analyticsProperties: [String: Any] {
        ExperimentKey.allCases.reduce(into: [String: Any]()) { props, key in
            props[key.rawValue] = variant(for: key)
        }
    }
}
