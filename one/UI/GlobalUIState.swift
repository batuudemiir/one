import SwiftUI
import Combine

@MainActor
final class GlobalUIState: ObservableObject {
    static let shared = GlobalUIState()
    
    @Published var isFullScreenPhotoVisible = false
    
    // Global properties for covering bottom navigation
    @Published var archivePhotoURL: URL?
    @Published var circlePhotoImage: UIImage?
    @Published var todayPhotoURL: URL?
}
