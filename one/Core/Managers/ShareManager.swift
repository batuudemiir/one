//
//  ShareManager.swift
//  one
//
//  Instagram Story Cards - Share Manager
//

import UIKit
import Photos

class ShareManager {
    static let shared = ShareManager()
    
    private init() {}
    
    func shareToInstagram(
        image: UIImage,
        from viewController: UIViewController,
        completion: @escaping (Result<Void, ShareError>) -> Void
    ) {
        // Optimize image for sharing (max 1080x1920 for Instagram Stories)
        let optimizedImage: UIImage
        let maxSize: CGFloat = 1920
        if image.size.width > maxSize || image.size.height > maxSize {
            let scale = min(maxSize / image.size.width, maxSize / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            optimizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            optimizedImage = image
        }
        
        // Create activity items
        let activityItems: [Any] = [optimizedImage]
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        // Completion handler
        activityVC.completionWithItemsHandler = { activity, success, items, error in
            if let error = error {
                ONELogger.error("Share error: \(error.localizedDescription)", category: .share)
                completion(.failure(.sharingFailed(error)))
            } else if success {
                ONELogger.success("Share successful", category: .share)
                completion(.success(()))
            } else {
                // User cancelled
                ONELogger.info("Share cancelled", category: .share)
                completion(.success(()))
            }
        }
        
        // Present
        DispatchQueue.main.async {
            viewController.present(activityVC, animated: true)
        }
    }
    
    func saveToPhotoLibrary(
        image: UIImage,
        completion: @escaping (Result<Void, ShareError>) -> Void
    ) {
        // Check permission
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion(.failure(.permissionDenied))
                }
                return
            }
            
            // Save image
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success(()))
                    } else {
                        completion(.failure(.saveFailed))
                    }
                }
            }
        }
    }
    
    func isInstagramInstalled() -> Bool {
        // Check the actual URL scheme used for sharing
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - Instagram Stories Direct Share
    /// Writes the image to UIPasteboard FIRST, then immediately opens Instagram Stories.
    /// The image must be written before the URL open call — order is critical.
    /// - Parameter contentURL: Optional Universal Link / web URL — Instagram Story'nin üstüne
    ///   "Uygulamada aç" attribution sticker'ı olarak yapıştırılır. Tıklanınca uygulamayı (varsa)
    ///   veya web fallback'ı açar.
    func shareToInstagramStories(
        image: UIImage,
        contentURL: URL? = nil,
        completion: @escaping (Result<Void, ShareError>) -> Void
    ) {
        // Use the instagram-stories:// scheme (requires LSApplicationQueriesSchemes in Info.plist)
        guard let storiesURL = URL(string: "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "one")"),
              UIApplication.shared.canOpenURL(URL(string: "instagram-stories://share")!) else {
            completion(.failure(.instagramNotInstalled))
            return
        }

        // Prefer PNG — Instagram handles it better than JPEG for Story backgrounds
        guard let imageData = image.pngData() ?? image.jpegData(compressionQuality: 0.95) else {
            completion(.failure(.sharingFailed(
                NSError(domain: "ShareManager", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Görsel oluşturulamadı"])
            )))
            return
        }

        // 1. Write to pasteboard BEFORE opening Instagram — this is the critical step.
        //    Using "com.instagram.sharedSticker.backgroundImage" pastes into the background layer.
        //    contentURL eklenince Instagram otomatik olarak "Uygulamada aç" sticker'ı yerleştirir.
        var item: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": imageData
        ]
        if let contentURL {
            item["com.instagram.sharedSticker.contentURL"] = contentURL.absoluteString
        }
        let pasteboardItems: [[String: Any]] = [item]
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60)   // 60 seconds
        ]
        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)

        // 2. Open Instagram immediately (no delay) — pasteboard is already populated.
        UIApplication.shared.open(storiesURL, options: [:]) { success in
            DispatchQueue.main.async {
                if success {
                    ONELogger.success("Opened Instagram Stories with background image", category: .share)
                    completion(.success(()))
                } else {
                    completion(.failure(.sharingFailed(
                        NSError(domain: "ShareManager", code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "Instagram açılamadı"])
                    )))
                }
            }
        }
    }

    // MARK: - TikTok Direct Share (Workaround)
    /// Since TikTok doesn't have an official direct image share URL scheme like Instagram,
    /// we save the image to the photo library and open the TikTok app directly.
    func shareToTikTok(
        image: UIImage,
        completion: @escaping (Result<Void, ShareError>) -> Void
    ) {
        // TikTok direct sharing without SDK is not officially supported via URL schemes.
        // Opening snssdk1180:// just launches the app without the image.
        // Therefore, we must use the system share sheet.
        DispatchQueue.main.async {
            self.shareViaActivityController(items: [image])
            completion(.success(()))
        }
    }

    // MARK: - System Share Sheet (topmost VC aware)
    /// Presents UIActivityViewController from the topmost presented view controller,
    /// so it works correctly even when called from within a SwiftUI sheet.
    func shareViaActivityController(items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        // Walk up to the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX, y: topVC.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        activityVC.completionWithItemsHandler = { _, success, _, error in
            if let error = error {
                ONELogger.error("System share error", error: error, category: .share)
            } else if success {
                ONELogger.success("System share successful", category: .share)
            }
        }

        DispatchQueue.main.async {
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Adaptive System Share (X-aware)
    /// System share sheet that automatically uses xPostImage + xText when the user picks X,
    /// and storyImage for all other destinations.
    func shareViaActivityControllerAdaptive(
        storyImage: UIImage,
        xPostImage: UIImage,
        xText: String,
        platformURL: URL?
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let imageProvider = ONEShareItemProvider(storyImage: storyImage, xPostImage: xPostImage)
        let textProvider = ONEShareTextProvider(xText: xText)
        var items: [Any] = [imageProvider, textProvider]
        if let url = platformURL { items.append(url) }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX, y: topVC.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        activityVC.completionWithItemsHandler = { _, success, _, error in
            if let error = error {
                ONELogger.error("Adaptive share error", error: error, category: .share)
            } else if success {
                ONELogger.success("Adaptive share successful", category: .share)
            }
        }

        DispatchQueue.main.async {
            topVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Adaptive Share Item Providers

/// Returns xPostImage when sharing to X/Twitter, storyImage for everything else.
final class ONEShareItemProvider: UIActivityItemProvider, @unchecked Sendable {
    private let storyImage: UIImage
    private let xPostImage: UIImage

    init(storyImage: UIImage, xPostImage: UIImage) {
        self.storyImage = storyImage
        self.xPostImage = xPostImage
        super.init(placeholderItem: storyImage)
    }

    override var item: Any {
        guard let type = activityType else { return storyImage }
        let raw = type.rawValue.lowercased()
        let isX = raw.contains("twitter") || raw.contains("tweetie")
        return isX ? xPostImage : storyImage
    }
}

/// Returns xText only when sharing to X/Twitter, empty string for everything else.
final class ONEShareTextProvider: UIActivityItemProvider, @unchecked Sendable {
    private let xText: String

    init(xText: String) {
        self.xText = xText
        super.init(placeholderItem: "")
    }

    override var item: Any {
        guard let type = activityType else { return "" }
        let raw = type.rawValue.lowercased()
        let isX = raw.contains("twitter") || raw.contains("tweetie")
        return isX ? xText : ""
    }
}

// MARK: - ShareError

enum ShareError: LocalizedError {
    case instagramNotInstalled
    case saveFailed
    case permissionDenied
    case sharingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .instagramNotInstalled:
            return NSLocalizedString(
                "instagram_not_installed",
                comment: "Instagram yüklü değil"
            )
        case .saveFailed:
            return NSLocalizedString(
                "save_failed",
                comment: "Fotoğraf kaydedilemedi"
            )
        case .permissionDenied:
            return NSLocalizedString(
                "permission_denied",
                comment: "Fotoğraf erişim izni gerekli"
            )
        case .sharingFailed(let error):
            return error.localizedDescription
        }
    }
}
