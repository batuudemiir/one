//
//  StoryCardShareView.swift
//  one
//
//  Instagram Story Cards - Share UI Integration
//

import SwiftUI

// MARK: - UIKit Share Sheet Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    /// Convenience init for sharing a single image
    init(image: UIImage) {
        self.items = [image]
    }
    
    /// General init for sharing any content
    init(items: [Any]) {
        self.items = items
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return activityVC
    }
    
    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
