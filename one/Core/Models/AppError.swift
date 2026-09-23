//
//  AppError.swift
//  one
//
//  Merkezi hata tipleri.
//  Tüm uygulama hataları bu enum altında kategorize edilir.
//  Mesajlar `Localizable.strings`'ten geliyor (`error.*`). Eskiden koda
//  gömülü Türkçe'ydi: uygulama dokuz dile çevriliydi ama hata alan bir
//  Alman kullanıcı arayüzü Almanca, hatayı Türkçe görüyordu.
//

import Foundation

// MARK: - AppError
enum AppError: LocalizedError, Identifiable {
    var id: String { localizedDescription }
    
    // Ağ hataları
    case networkUnavailable
    case networkTimeout
    case networkUnknown(underlying: Error)
    
    // CloudKit hataları
    case cloudKitNotAvailable
    case cloudKitNotAuthenticated
    case cloudKitRecordNotFound
    case cloudKitSchemaError
    case cloudKitServerConflict
    case cloudKitQuotaExceeded
    case cloudKitUnknown(underlying: Error)
    
    // Persistence hataları
    case persistenceSaveFailed(underlying: Error)
    case persistenceFetchFailed(underlying: Error)
    case persistenceDeleteFailed(underlying: Error)
    case persistenceMigrationFailed
    
    // Auth hataları
    case authAppleMusicDenied
    case authAppleMusicRestricted
    case authSpotifyFailed
    case authSpotifyTokenExpired
    case authSpotifyNotConnected
    
    // Müzik hataları
    case musicSearchFailed(underlying: Error)
    case musicNoResults
    case musicPlaybackFailed
    case musicServiceUnavailable
    
    // Kamera / Fotoğraf hataları
    case cameraDenied
    case cameraUnavailable
    case photoSaveFailed
    
    // Circle (Çevre) hataları
    case circleUserNotFound
    case circleAlreadyFriend
    case circleSelfAdd
    case circleInviteCodeInvalid
    case circleFriendRequestFailed(underlying: Error)
    
    // Genel
    case unknown(message: String)
    
    // MARK: - Kullanıcıya Gösterilecek Türkçe Mesajlar
    var errorDescription: String? {
        switch self {
        // Network
        case .networkUnavailable:
            return NSLocalizedString("error.networkUnavailable.message", comment: "AppError message")
        case .networkTimeout:
            return NSLocalizedString("error.networkTimeout.message", comment: "AppError message")
        case .networkUnknown:
            return NSLocalizedString("error.networkUnknown.message", comment: "AppError message")
            
        // CloudKit
        case .cloudKitNotAvailable:
            return NSLocalizedString("error.cloudKitNotAvailable.message", comment: "AppError message")
        case .cloudKitNotAuthenticated:
            return NSLocalizedString("error.cloudKitNotAuthenticated.message", comment: "AppError message")
        case .cloudKitRecordNotFound:
            return NSLocalizedString("error.cloudKitRecordNotFound.message", comment: "AppError message")
        case .cloudKitSchemaError:
            return NSLocalizedString("error.cloudKitSchemaError.message", comment: "AppError message")
        case .cloudKitServerConflict:
            return NSLocalizedString("error.cloudKitServerConflict.message", comment: "AppError message")
        case .cloudKitQuotaExceeded:
            return NSLocalizedString("error.cloudKitQuotaExceeded.message", comment: "AppError message")
        case .cloudKitUnknown:
            return NSLocalizedString("error.cloudKitUnknown.message", comment: "AppError message")
            
        // Persistence
        case .persistenceSaveFailed:
            return NSLocalizedString("error.persistenceSaveFailed.message", comment: "AppError message")
        case .persistenceFetchFailed:
            return NSLocalizedString("error.persistenceFetchFailed.message", comment: "AppError message")
        case .persistenceDeleteFailed:
            return NSLocalizedString("error.persistenceDeleteFailed.message", comment: "AppError message")
        case .persistenceMigrationFailed:
            return NSLocalizedString("error.persistenceMigrationFailed.message", comment: "AppError message")
            
        // Auth
        case .authAppleMusicDenied:
            return NSLocalizedString("error.authAppleMusicDenied.message", comment: "AppError message")
        case .authAppleMusicRestricted:
            return NSLocalizedString("error.authAppleMusicRestricted.message", comment: "AppError message")
        case .authSpotifyFailed:
            return NSLocalizedString("error.authSpotifyFailed.message", comment: "AppError message")
        case .authSpotifyTokenExpired:
            return NSLocalizedString("error.authSpotifyTokenExpired.message", comment: "AppError message")
        case .authSpotifyNotConnected:
            return NSLocalizedString("error.authSpotifyNotConnected.message", comment: "AppError message")
            
        // Music
        case .musicSearchFailed:
            return NSLocalizedString("error.musicSearchFailed.message", comment: "AppError message")
        case .musicNoResults:
            return NSLocalizedString("error.musicNoResults.message", comment: "AppError message")
        case .musicPlaybackFailed:
            return NSLocalizedString("error.musicPlaybackFailed.message", comment: "AppError message")
        case .musicServiceUnavailable:
            return NSLocalizedString("error.musicServiceUnavailable.message", comment: "AppError message")
            
        // Camera
        case .cameraDenied:
            return NSLocalizedString("error.cameraDenied.message", comment: "AppError message")
        case .cameraUnavailable:
            return NSLocalizedString("error.cameraUnavailable.message", comment: "AppError message")
        case .photoSaveFailed:
            return NSLocalizedString("error.photoSaveFailed.message", comment: "AppError message")
            
        // Circle
        case .circleUserNotFound:
            return NSLocalizedString("error.circleUserNotFound.message", comment: "AppError message")
        case .circleAlreadyFriend:
            return NSLocalizedString("error.circleAlreadyFriend.message", comment: "AppError message")
        case .circleSelfAdd:
            return NSLocalizedString("error.circleSelfAdd.message", comment: "AppError message")
        case .circleInviteCodeInvalid:
            return NSLocalizedString("error.circleInviteCodeInvalid.message", comment: "AppError message")
        case .circleFriendRequestFailed:
            return NSLocalizedString("error.circleFriendRequestFailed.message", comment: "AppError message")
            
        // General
        case .unknown(let message):
            return message
        }
    }
    
    // MARK: - Kısa Başlık
    var title: String {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkUnknown:
            return NSLocalizedString("error.title.network", comment: "AppError title")
        case .cloudKitNotAvailable, .cloudKitNotAuthenticated, .cloudKitRecordNotFound,
             .cloudKitSchemaError, .cloudKitServerConflict, .cloudKitQuotaExceeded, .cloudKitUnknown:
            return NSLocalizedString("error.title.cloudKit", comment: "AppError title")
        case .persistenceSaveFailed, .persistenceFetchFailed, .persistenceDeleteFailed, .persistenceMigrationFailed:
            return NSLocalizedString("error.title.persistence", comment: "AppError title")
        case .authAppleMusicDenied, .authAppleMusicRestricted, .authSpotifyFailed,
             .authSpotifyTokenExpired, .authSpotifyNotConnected:
            return NSLocalizedString("error.title.auth", comment: "AppError title")
        case .musicSearchFailed, .musicNoResults, .musicPlaybackFailed, .musicServiceUnavailable:
            return NSLocalizedString("error.title.music", comment: "AppError title")
        case .cameraDenied, .cameraUnavailable, .photoSaveFailed:
            return NSLocalizedString("error.title.camera", comment: "AppError title")
        case .circleUserNotFound, .circleAlreadyFriend, .circleSelfAdd,
             .circleInviteCodeInvalid, .circleFriendRequestFailed:
            return NSLocalizedString("error.title.circle", comment: "AppError title")
        case .unknown:
            return NSLocalizedString("error.title.unknown", comment: "AppError title")
        }
    }
    
    // MARK: - Retry Edilebilir mi?
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkUnknown,
             .cloudKitServerConflict, .cloudKitUnknown,
             .musicSearchFailed, .circleFriendRequestFailed,
             // .unknown ile birlikte retry closure verilmişse (örn.
             // poster render fail), toast retry button'u göstermeli.
             // Toast zaten `isRetryable && retry != nil` kontrolü yaptığı
             // için closure verilmeyen çağrılar etkilenmez.
             .unknown:
            return true
        default:
            return false
        }
    }
    
    // MARK: - CKError'dan dönüştürme
    static func from(cloudKitError: Error) -> AppError {
        let nsError = cloudKitError as NSError
        guard nsError.domain == "CKErrorDomain" else {
            return .cloudKitUnknown(underlying: cloudKitError)
        }
        switch nsError.code {
        case 1:  return .cloudKitNotAuthenticated
        case 11: return .cloudKitRecordNotFound
        case 12, 26: return .cloudKitSchemaError
        case 14: return .cloudKitServerConflict
        case 25: return .cloudKitQuotaExceeded
        default: return .cloudKitUnknown(underlying: cloudKitError)
        }
    }
}
