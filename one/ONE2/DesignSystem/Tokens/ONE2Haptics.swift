//
//  ONE2Haptics.swift
//  ONE 2.0
//
//  07 §7 tablosu, `ONEHaptics` deseniyle (üreteç hazırlanır, sonra
//  ateşlenir; kullanıcının `hapticFeedbackEnabled` ayarına uyulur).
//  - selection: sekme, skor, duygu/etiket, kalp
//  - light: pratik işaretleme
//  - soft: mühür (Seal)
//  - warning: silme onayı
//  - error: hata
//

import UIKit

enum ONE2Haptics {

    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
    }

    static func selection() {
        guard isEnabled else { return }
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }

    static func light() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }

    static func warning() {
        guard isEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.warning)
    }

    static func error() {
        guard isEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.error)
    }

    static func soft() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        gen.impactOccurred()
    }
}
