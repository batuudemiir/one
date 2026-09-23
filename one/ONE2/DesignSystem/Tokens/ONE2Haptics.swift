//
//  ONE2Haptics.swift
//  ONE 2.0
//
//  Üç haptik, `ONEHaptics` deseniyle (üreteç hazırlanır, sonra ateşlenir;
//  kullanıcının `hapticFeedbackEnabled` ayarına uyulur).
//  - selection: sekme, skor, chip, beğeni
//  - soft: mühür (Seal)
//  - success: kaydın tamamlanması
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

    static func soft() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        gen.impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }
}
