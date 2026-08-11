//
//  AppError.swift
//  one
//
//  Merkezi hata tipleri.
//  Tüm uygulama hataları bu enum altında kategorize edilir.
//  Her hata tipi kullanıcıya gösterilecek Türkçe mesaj içerir.
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
            return "İnternet bağlantısı yok. Lütfen bağlantını kontrol et."
        case .networkTimeout:
            return "İstek zaman aşımına uğradı. Tekrar dene."
        case .networkUnknown:
            return "Bağlantı hatası oluştu. Lütfen tekrar dene."
            
        // CloudKit
        case .cloudKitNotAvailable:
            return "iCloud kullanılamıyor. Ayarlar'dan iCloud'u kontrol et."
        case .cloudKitNotAuthenticated:
            return "iCloud hesabına giriş yapmamışsın."
        case .cloudKitRecordNotFound:
            return "Kayıt bulunamadı."
        case .cloudKitSchemaError:
            return "Sunucu yapılandırma hatası. Lütfen daha sonra tekrar dene."
        case .cloudKitServerConflict:
            return "Sunucu çakışması oluştu. Veriler senkronize ediliyor."
        case .cloudKitQuotaExceeded:
            return "iCloud depolama alanın dolu."
        case .cloudKitUnknown:
            return "iCloud hatası oluştu. Lütfen tekrar dene."
            
        // Persistence
        case .persistenceSaveFailed:
            return "Kayıt sırasında bir hata oluştu."
        case .persistenceFetchFailed:
            return "Veriler yüklenirken bir hata oluştu."
        case .persistenceDeleteFailed:
            return "Silme işlemi başarısız oldu."
        case .persistenceMigrationFailed:
            return "Veri tabanı güncellemesi başarısız oldu."
            
        // Auth
        case .authAppleMusicDenied:
            return "Apple Music izni gerekli. Ayarlar > Gizlilik'ten izin ver."
        case .authAppleMusicRestricted:
            return "Apple Music bu cihazda kısıtlanmış."
        case .authSpotifyFailed:
            return "Spotify bağlantısı başarısız oldu."
        case .authSpotifyTokenExpired:
            return "Spotify oturumun sona erdi. Tekrar bağlan."
        case .authSpotifyNotConnected:
            return "Spotify hesabı bağlı değil."
            
        // Music
        case .musicSearchFailed:
            return "Arama sırasında bir hata oluştu."
        case .musicNoResults:
            return "Sonuç bulunamadı."
        case .musicPlaybackFailed:
            return "Şarkı çalınamadı."
        case .musicServiceUnavailable:
            return "Müzik servisi kullanılamıyor."
            
        // Camera
        case .cameraDenied:
            return "Kamera izni gerekli. Ayarlar'dan izin ver."
        case .cameraUnavailable:
            return "Kamera kullanılamıyor."
        case .photoSaveFailed:
            return "Fotoğraf kaydedilemedi."
            
        // Circle
        case .circleUserNotFound:
            return "Kullanıcı bulunamadı. Kodu kontrol et."
        case .circleAlreadyFriend:
            return "Bu kullanıcı zaten çevrende."
        case .circleSelfAdd:
            return "Kendi kendini ekleyemezsin."
        case .circleInviteCodeInvalid:
            return "Geçersiz davet kodu."
        case .circleFriendRequestFailed:
            return "Arkadaşlık isteği gönderilemedi."
            
        // General
        case .unknown(let message):
            return message
        }
    }
    
    // MARK: - Kısa Başlık
    var title: String {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkUnknown:
            return "Bağlantı Hatası"
        case .cloudKitNotAvailable, .cloudKitNotAuthenticated, .cloudKitRecordNotFound,
             .cloudKitSchemaError, .cloudKitServerConflict, .cloudKitQuotaExceeded, .cloudKitUnknown:
            return "iCloud Hatası"
        case .persistenceSaveFailed, .persistenceFetchFailed, .persistenceDeleteFailed, .persistenceMigrationFailed:
            return "Kayıt Hatası"
        case .authAppleMusicDenied, .authAppleMusicRestricted, .authSpotifyFailed,
             .authSpotifyTokenExpired, .authSpotifyNotConnected:
            return "Yetkilendirme"
        case .musicSearchFailed, .musicNoResults, .musicPlaybackFailed, .musicServiceUnavailable:
            return "Müzik Hatası"
        case .cameraDenied, .cameraUnavailable, .photoSaveFailed:
            return "Kamera Hatası"
        case .circleUserNotFound, .circleAlreadyFriend, .circleSelfAdd,
             .circleInviteCodeInvalid, .circleFriendRequestFailed:
            return "Çevre Hatası"
        case .unknown:
            return "Hata"
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
