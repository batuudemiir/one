//
//  StoryCardModels.swift
//  one
//
//  Instagram Story Cards - Core Models and Configuration
//

import SwiftUI
import CoreData

// MARK: - StoryCardConfiguration

struct StoryCardConfiguration {
    // Dimensions
    static let width: CGFloat = 1080
    static let height: CGFloat = 1920
    static let aspectRatio: CGFloat = 9.0 / 16.0
    
    // Safe zones
    static let topSafeZone: CGFloat = 250
    static let bottomSafeZone: CGFloat = 250
    
    // Layout
    static let overlayHeight: CGFloat = 600
    static let contentPadding: CGFloat = 60
    static let accentLineHeight: CGFloat = 3
    static let accentLineWidth: CGFloat = 120
    
    // Typography
    static let songTitleSize: CGFloat = 48
    static let artistNameSize: CGFloat = 32
    static let noteSize: CGFloat = 24
    static let dateSize: CGFloat = 18
    static let fontFamily = "Fraunces"
    
    // Branding
    static let watermarkOpacity: Double = 0.05
    static let watermarkSize: CGFloat = 80
    static let watermarkPadding: CGFloat = 40
    
    // Export
    static let maxFileSize: Int = 8 * 1024 * 1024 // 8MB
    static let imageQuality: CGFloat = 0.9
    static let renderScale: CGFloat = 3.0
}

// MARK: - StoryCardError

enum StoryCardError: LocalizedError {
    case missingData(String)
    case renderFailed
    case imageTooLarge
    case invalidFormat
    case exportFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingData(let field):
            return NSLocalizedString("missing_data_\(field)", 
                comment: "Gerekli veri eksik: \(field)")
        case .renderFailed:
            return NSLocalizedString("render_failed", 
                comment: "Kart oluşturulamadı")
        case .imageTooLarge:
            return NSLocalizedString("image_too_large", 
                comment: "Görsel boyutu çok büyük")
        case .invalidFormat:
            return NSLocalizedString("invalid_format", 
                comment: "Geçersiz format")
        case .exportFailed(let error):
            return NSLocalizedString("export_failed", 
                comment: "Dışa aktarma başarısız: \(error.localizedDescription)")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingData:
            return NSLocalizedString("check_song_data", 
                comment: "Şarkı bilgilerini kontrol edin")
        case .renderFailed:
            return NSLocalizedString("try_again", 
                comment: "Lütfen tekrar deneyin")
        case .imageTooLarge:
            return NSLocalizedString("reduce_image_size", 
                comment: "Fotoğraf boyutunu küçültün")
        case .invalidFormat:
            return NSLocalizedString("check_format", 
                comment: "Format uyumluluğunu kontrol edin")
        case .exportFailed:
            return NSLocalizedString("check_storage", 
                comment: "Depolama alanını kontrol edin")
        }
    }
}

// MARK: - DailySong Extension

extension DailySong {
    var coverImage: UIImage? {
        // Priority: photoData > artworkURL > nil
        if let photoData = photoData {
            return UIImage(data: photoData)
        }
        
        if let urlString = artworkURL,
           let _ = URL(string: urlString) {
            // Note: This should be cached/pre-loaded
            // For now, return nil and let the generator use default
            return nil
        }
        
        return nil
    }
    
    var formattedDate: String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
    
    var isValidForCard: Bool {
        // At minimum, we need a song name
        return songName != nil && !songName!.isEmpty
    }
}

// MARK: - StoryCardLogger

enum LogLevel {
    case debug, info, warning, error
}

struct StoryCardLogger {
    static func log(_ message: String, level: LogLevel, error: Error? = nil) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [\(level)] StoryCard: \(message)"
        
        if let error = error {
            ONELogger.debug("\(logMessage) - Error: \(error)", category: .share)
        } else {
            print(logMessage)
        }
        
        // In production, send to analytics/crash reporting
        if level == .error {
            // Analytics.logError(message, error: error)
        }
    }
}
