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

extension Notification.Name {
    /// Kullanıcıyı giriş ritüeline getir. Yayınlayanlar: `ones://today`
    /// widget/kilit ekranı deep link'i ve `/event/mood` universal link'i.
    /// Dinleyen: `ONEColorPickerView`.
    static let openMoodPicker = Notification.Name("OpenMoodPicker")
}
