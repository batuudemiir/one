//
//  StoryCardGenerator.swift
//  one
//
//  Instagram Story Cards - Generator Service
//

import SwiftUI
import UIKit
import CloudKit

@MainActor
class StoryCardGenerator {
    static let shared = StoryCardGenerator()
    
    private let defaultImage: UIImage
    private let watermark: UIImage
    private var isGenerating = false
    
    private init() {
        // Load default assets
        self.defaultImage = UIImage(named: "DefaultCover") ?? Self.createDefaultImage()
        self.watermark = UIImage(named: "ONE_Watermark") ?? Self.createDefaultWatermark()
    }
    
    func generateCardAsync(from dailySong: DailySong) async throws -> UIImage {
        // Prevent concurrent generation
        guard !isGenerating else {
            throw StoryCardError.renderFailed
        }

        isGenerating = true
        defer { isGenerating = false }

        StoryCardLogger.log("Starting card generation", level: .info)
        let startTime = Date()

        do {
            // 1. Prepare view model
            let viewModel = try prepareViewModel(from: dailySong, inviteCode: Self.currentInviteCode())
            
            // 2. Create SwiftUI view
            let cardView = StoryCardView(viewModel: viewModel)
            
            // 3. Render to image
            let image = try await renderView(cardView)
            
            // 4. Optimize
            let optimized = try optimizeImage(image)
            
            let duration = Date().timeIntervalSince(startTime)
            StoryCardLogger.log(
                "Card generated successfully in \(duration)s",
                level: .info
            )
            
            return optimized
            
        } catch {
            StoryCardLogger.log(
                "Card generation failed",
                level: .error,
                error: error
            )
            throw error
        }
    }
    
    func generateCardAsync(from dailyEntry: DailyEntry) async throws -> UIImage {
        // Prevent concurrent generation
        guard !isGenerating else {
            throw StoryCardError.renderFailed
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        StoryCardLogger.log("Starting card generation from DailyEntry", level: .info)
        let startTime = Date()
        
        do {
            // 1. Prepare view model from DailyEntry
            let viewModel = try StoryCardViewModel.from(
                dailyEntry: dailyEntry,
                defaultImage: defaultImage,
                watermark: watermark,
                inviteCode: Self.currentInviteCode()
            )
            
            // 2. Create SwiftUI view
            let cardView = StoryCardView(viewModel: viewModel)
            
            // 3. Render to image
            let image = try await renderView(cardView)
            
            // 4. Optimize
            let optimized = try optimizeImage(image)
            
            let duration = Date().timeIntervalSince(startTime)
            StoryCardLogger.log(
                "Card generated successfully in \(duration)s",
                level: .info
            )
            
            return optimized
            
        } catch {
            StoryCardLogger.log(
                "Card generation failed",
                level: .error,
                error: error
            )
            throw error
        }
    }
    
    private func prepareViewModel(from dailySong: DailySong, inviteCode: String?) throws -> StoryCardViewModel {
        return try StoryCardViewModel.from(
            dailySong: dailySong,
            defaultImage: defaultImage,
            watermark: watermark,
            inviteCode: inviteCode
        )
    }

    /// Current user's invite code from CloudKit, or nil before login.
    static func currentInviteCode() -> String? {
        CloudKitManager.shared.currentUser?["inviteCode"] as? String
    }
    
    private func renderView(_ view: StoryCardView) async throws -> UIImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = StoryCardConfiguration.renderScale
        
        guard let image = renderer.uiImage else {
            throw StoryCardError.renderFailed
        }
        
        return image
    }
    
    private func optimizeImage(_ image: UIImage) throws -> UIImage {
        // Ensure correct size
        guard image.size.width == StoryCardConfiguration.width,
              image.size.height == StoryCardConfiguration.height else {
            throw StoryCardError.invalidFormat
        }
        
        // Convert to PNG and check size
        guard let pngData = image.pngData() else {
            throw StoryCardError.invalidFormat
        }
        
        let fileSizeInMB = Double(pngData.count) / (1024 * 1024)
        
        if fileSizeInMB > 8.0 {
            // Try compression
            guard let jpegData = image.jpegData(
                compressionQuality: StoryCardConfiguration.imageQuality
            ),
            let compressed = UIImage(data: jpegData) else {
                throw StoryCardError.imageTooLarge
            }
            
            return compressed
        }
        
        return image
    }
    
    // Helper: Create default cover image if asset is missing
    private static func createDefaultImage() -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Create a simple gradient background
            let colors = [UIColor(red: 0.91, green: 0.90, blue: 0.88, alpha: 1.0).cgColor,
                         UIColor(red: 0.85, green: 0.84, blue: 0.82, alpha: 1.0).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray,
                                     locations: [0.0, 1.0])!
            context.cgContext.drawLinearGradient(gradient,
                                                 start: CGPoint(x: 0, y: 0),
                                                 end: CGPoint(x: size.width, y: size.height),
                                                 options: [])
        }
    }
    
    // Helper: Create default watermark if asset is missing
    private static func createDefaultWatermark() -> UIImage {
        let size = CGSize(width: 240, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let text = "ONE"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 80, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}
