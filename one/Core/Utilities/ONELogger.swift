//
//  ONELogger.swift
//  one
//
//  Merkezi loglama altyapısı.
//  • Debug modda logları konsola yazar (os_log veya print).
//  • Release modda sessizdir — production'da sıfır gürültü.
//
//  Kullanım:
//    ONELogger.debug("Veri yüklendi")
//    ONELogger.info("Kullanıcı giriş yaptı", category: .auth)
//    ONELogger.error("CloudKit hatası", error: someError, category: .cloudkit)
//

import Foundation
import os.log

// MARK: - Log Kategorileri
enum ONELogCategory: String {
    case general     = "General"
    case cloudkit    = "CloudKit"
    case spotify     = "Spotify"
    case music       = "Music"
    case persistence = "Persistence"
    case auth        = "Auth"
    case circle      = "Circle"
    case camera      = "Camera"
    case profile     = "Profile"
    case discovery   = "Discovery"
    case ui          = "UI"
    case notification = "Notification"
    case calendar    = "Calendar"
    case share       = "Share"
    
    var logger: Logger {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.batu.ones", category: rawValue)
    }
}

// MARK: - ONELogger
enum ONELogger {
    
    // MARK: — Debug (sadece DEBUG modda görünür)
    /// Geliştirme sırasında detaylı bilgi logları.
    /// Release'de tamamen sessiz.
    static func debug(_ message: String, category: ONELogCategory = .general) {
        #if DEBUG
        category.logger.debug("🔹 \(message, privacy: .private)")
        #endif
    }
    
    // MARK: — Info
    /// Önemli ama kritik olmayan bilgiler.
    /// Başarılı operasyonlar, durum değişiklikleri.
    static func info(_ message: String, category: ONELogCategory = .general) {
        #if DEBUG
        category.logger.info("✅ \(message, privacy: .private)")
        #endif
    }
    
    // MARK: — Warning
    /// Potansiyel sorunlar, beklenmeyen ama yönetilebilir durumlar.
    static func warning(_ message: String, category: ONELogCategory = .general) {
        #if DEBUG
        category.logger.warning("⚠️ \(message, privacy: .private)")
        #endif
    }
    
    // MARK: — Error
    /// Hatalar. Opsiyonel Error nesnesi ile detay eklenebilir.
    static func error(_ message: String, error: Error? = nil, category: ONELogCategory = .general) {
        #if DEBUG
        if let error {
            category.logger.error("❌ \(message, privacy: .private) — \(error.localizedDescription, privacy: .private)")
        } else {
            category.logger.error("❌ \(message, privacy: .private)")
        }
        #endif
    }
    
    // MARK: — Success (kısa yol)
    /// Başarılı işlem bildirimi.
    static func success(_ message: String, category: ONELogCategory = .general) {
        #if DEBUG
        category.logger.info("✅ \(message, privacy: .private)")
        #endif
    }
    
    // MARK: — Network / API
    /// Ağ istekleri ve API yanıtları için özel log.
    static func network(_ message: String, category: ONELogCategory = .general) {
        #if DEBUG
        category.logger.debug("🌐 \(message, privacy: .private)")
        #endif
    }
}
