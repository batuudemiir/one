# Design Document: Instagram Story Cards

## Overview

Instagram Story Cards özelliği, ONE uygulamasında kullanıcıların günlük şarkı kayıtlarını Instagram story formatında paylaşılabilir görsel kartlara dönüştüren bir sistemdir. Özellik, SwiftUI tabanlı bir kart tasarım sistemi, ImageRenderer kullanarak görsel oluşturma mekanizması ve iOS paylaşım entegrasyonunu içerir.

Sistem üç ana bileşenden oluşur:
1. **StoryCardView**: SwiftUI ile tasarlanmış, 1080x1920 piksel Instagram story formatında görsel kart bileşeni
2. **StoryCardGenerator**: Kart oluşturma, render etme ve dışa aktarma işlemlerini yöneten servis katmanı
3. **ShareManager**: iOS paylaşım mekanizması ve Instagram entegrasyonunu yöneten yönetici sınıfı

Tasarım, minimalist overlay yaklaşımını benimser: tam ekran fotoğraf/kapak görseli üzerine gradient overlay ve beyaz text overlay ile temiz, profesyonel bir görünüm sağlar. Mood color ince bir accent line olarak kullanılır ve ONE branding subtle watermark olarak eklenir.

## Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Archive Preview UI                       │
│                  (ArchiveScreen/DayDetailView)               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ User taps share button
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    StoryCardGenerator                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  1. Validate DailySong data                          │  │
│  │  2. Create StoryCardView with data                   │  │
│  │  3. Render to UIImage using ImageRenderer            │  │
│  │  4. Optimize image (resize, compress)                │  │
│  │  5. Return UIImage or error                          │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ UIImage ready
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      ShareManager                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  1. Receive UIImage                                   │  │
│  │  2. Save to temporary location                        │  │
│  │  3. Create UIActivityViewController                   │  │
│  │  4. Configure for Instagram sharing                   │  │
│  │  5. Present share sheet                               │  │
│  │  6. Optional: Save to photo library                   │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Share sheet presented
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 iOS Share Sheet (System)                     │
│              Instagram / Save Image / More...                │
└─────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

```
User Action → Archive UI → StoryCardGenerator → ShareManager → iOS System
     │              │              │                  │              │
     │              │              │                  │              │
  Tap Share    Pass DailySong  Render View      Present Sheet   Instagram
     │          + Config         to Image         with Image       App
     │              │              │                  │              │
     └──────────────┴──────────────┴──────────────────┴──────────────┘
                            Error Handling
                         (Show alert/retry)
```

### Data Flow

```
DailySong (Core Data)
    │
    ├─ songName: String?
    ├─ artistName: String?
    ├─ moodWord: String?
    ├─ moodColorHex: String?
    ├─ dailyNote: String?
    ├─ photoData: Data?
    ├─ artworkURL: String?
    └─ date: Date?
         │
         ▼
StoryCardViewModel (Processed Data)
    │
    ├─ coverImage: UIImage
    ├─ songTitle: String
    ├─ artistName: String
    ├─ moodColor: Color
    ├─ userNote: String?
    └─ dateString: String
         │
         ▼
StoryCardView (SwiftUI)
    │
    └─ Rendered Layout (1080x1920)
         │
         ▼
ImageRenderer
    │
    └─ UIImage (PNG)
         │
         ▼
ShareManager
    │
    └─ UIActivityViewController
```

## Components and Interfaces

### 1. StoryCardView (SwiftUI Component)

**Purpose**: Instagram story formatında görsel kart oluşturan SwiftUI view bileşeni.

**Interface**:
```swift
struct StoryCardView: View {
    let viewModel: StoryCardViewModel
    
    var body: some View {
        // 1080x1920 layout
    }
}

struct StoryCardViewModel {
    let coverImage: UIImage
    let songTitle: String
    let artistName: String
    let moodColor: Color
    let userNote: String?
    let dateString: String
    let brandWatermark: UIImage
}
```

**Layout Structure** (1080x1920 pixels):
```
┌─────────────────────────────────────┐
│                                     │ ← Top Safe Zone (250px)
│                                     │
│         Cover Image (Full)          │
│                                     │
│                                     │
│                                     │
│                                     │
│         (Centered & Scaled)         │
│                                     │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │ Gradient Overlay (Dark→Clear) │ │
│  │                               │ │
│  │  Mood Accent Line (3px)       │ │
│  │                               │ │
│  │  Song Title (White, 48pt)     │ │
│  │  Artist Name (White, 32pt)    │ │
│  │                               │ │
│  │  User Note (White, 24pt)      │ │
│  │  [if present]                 │ │
│  │                               │ │
│  │  Date (White, 18pt)           │ │
│  │                               │ │
│  │  "ONE" Watermark (5% opacity) │ │
│  └───────────────────────────────┘ │
│                                     │ ← Bottom Safe Zone (250px)
└─────────────────────────────────────┘
```

**Responsibilities**:
- Cover image'ı tam ekran olarak gösterme (aspect fill)
- Alt kısımda gradient overlay uygulama (karanlık → şeffaf)
- Mood color'ı ince accent line olarak gösterme
- Text overlay'leri beyaz renkte ve okunabilir şekilde yerleştirme
- ONE branding watermark'ı subtle şekilde ekleme
- Instagram safe zone'lara uygun içerik yerleşimi

### 2. StoryCardGenerator (Service Layer)

**Purpose**: DailySong verisinden StoryCardView oluşturma ve UIImage'a render etme.

**Interface**:
```swift
class StoryCardGenerator {
    static let shared = StoryCardGenerator()
    
    func generateCard(
        from dailySong: DailySong,
        completion: @escaping (Result<UIImage, StoryCardError>) -> Void
    )
    
    @MainActor
    func generateCardAsync(from dailySong: DailySong) async throws -> UIImage
}

enum StoryCardError: LocalizedError {
    case missingData(String)
    case renderFailed
    case imageTooLarge
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .missingData(let field):
            return "Gerekli veri eksik: \(field)"
        case .renderFailed:
            return "Kart oluşturulamadı"
        case .imageTooLarge:
            return "Görsel boyutu çok büyük"
        case .invalidFormat:
            return "Geçersiz format"
        }
    }
}
```

**Responsibilities**:
- DailySong verisini validate etme
- Eksik verileri default değerlerle doldurma
- StoryCardViewModel oluşturma
- StoryCardView'ı ImageRenderer ile render etme
- Görsel optimizasyonu (boyut, kalite)
- Hata yönetimi ve logging

**Implementation Strategy**:
```swift
// iOS 16+ için ImageRenderer kullanımı
@MainActor
func generateCardAsync(from dailySong: DailySong) async throws -> UIImage {
    // 1. Validate and prepare data
    let viewModel = try prepareViewModel(from: dailySong)
    
    // 2. Create SwiftUI view
    let cardView = StoryCardView(viewModel: viewModel)
    
    // 3. Render using ImageRenderer
    let renderer = ImageRenderer(content: cardView)
    renderer.scale = 3.0 // For high quality
    
    guard let uiImage = renderer.uiImage else {
        throw StoryCardError.renderFailed
    }
    
    // 4. Optimize image
    let optimized = try optimizeImage(uiImage)
    
    return optimized
}
```

### 3. ShareManager (Sharing Coordinator)

**Purpose**: iOS paylaşım mekanizması ve Instagram entegrasyonunu yönetme.

**Interface**:
```swift
class ShareManager {
    static let shared = ShareManager()
    
    func shareToInstagram(
        image: UIImage,
        from viewController: UIViewController,
        completion: @escaping (Result<Void, ShareError>) -> Void
    )
    
    func saveToPhotoLibrary(
        image: UIImage,
        completion: @escaping (Result<Void, ShareError>) -> Void
    )
    
    func isInstagramInstalled() -> Bool
}

enum ShareError: LocalizedError {
    case instagramNotInstalled
    case saveFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .instagramNotInstalled:
            return "Instagram yüklü değil"
        case .saveFailed:
            return "Kaydetme başarısız"
        case .permissionDenied:
            return "İzin reddedildi"
        }
    }
}
```

**Responsibilities**:
- UIActivityViewController oluşturma ve sunma
- Instagram app'in yüklü olup olmadığını kontrol etme
- Görsel paylaşımı için geçici dosya yönetimi
- Photo library'ye kaydetme (fallback)
- Paylaşım sonucu ve hata yönetimi

### 4. UI Integration (Archive Screen Extension)

**Purpose**: Mevcut Archive ekranına share butonu ekleme.

**Interface**:
```swift
// ArchiveScreen'e ekleme
struct DayDetailView: View {
    let dailySong: DailySong
    @State private var isGeneratingCard = false
    @State private var showShareSheet = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    
    var body: some View {
        // Existing day detail UI
        // ...
        
        // Share button
        Button(action: handleShareTap) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Instagram'da Paylaş")
            }
        }
        .disabled(isGeneratingCard)
    }
    
    private func handleShareTap() {
        // Generate and share
    }
}
```

## Data Models

### StoryCardViewModel

```swift
struct StoryCardViewModel {
    // Required fields
    let coverImage: UIImage
    let songTitle: String
    let artistName: String
    let moodColor: Color
    let dateString: String
    let brandWatermark: UIImage
    
    // Optional fields
    let userNote: String?
    
    // Computed properties
    var hasNote: Bool {
        userNote != nil && !userNote!.isEmpty
    }
    
    var gradientColors: [Color] {
        [
            Color.black.opacity(0.7),
            Color.black.opacity(0.4),
            Color.clear
        ]
    }
    
    // Factory method
    static func from(
        dailySong: DailySong,
        defaultImage: UIImage,
        watermark: UIImage
    ) throws -> StoryCardViewModel {
        // Extract and validate data
        let coverImage = extractCoverImage(from: dailySong) ?? defaultImage
        let songTitle = dailySong.songName ?? "Untitled"
        let artistName = dailySong.artistName ?? "Unknown Artist"
        let moodColor = Color(hex: dailySong.moodColorHex ?? "#E8E6E0")
        let dateString = formatDate(dailySong.date)
        let userNote = dailySong.dailyNote?.isEmpty == false ? dailySong.dailyNote : nil
        
        return StoryCardViewModel(
            coverImage: coverImage,
            songTitle: songTitle,
            artistName: artistName,
            moodColor: moodColor,
            dateString: dateString,
            brandWatermark: watermark,
            userNote: userNote
        )
    }
}
```

### StoryCardConfiguration

```swift
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
```

### DailySong Extension

```swift
extension DailySong {
    var coverImage: UIImage? {
        // Priority: photoData > artworkURL > nil
        if let photoData = photoData {
            return UIImage(data: photoData)
        }
        
        if let urlString = artworkURL,
           let url = URL(string: urlString) {
            // Note: This should be cached/pre-loaded
            return loadImageSync(from: url)
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
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, I identified the following redundancies:
- Properties 1.1 and 3.1 both test exact dimensions (1080x1920) - combined into Property 1
- Property 3.2 (aspect ratio) is implied by exact dimensions - combined into Property 1
- Properties 1.8 and 8.1 both test 2-second generation time - combined into Property 2
- Multiple properties test data extraction and defaults - grouped into comprehensive properties

The following properties represent unique, non-redundant validation requirements:

### Property 1: Exact Dimensions and Aspect Ratio

*For any* valid DailySong object, the generated Story_Card image SHALL have exact dimensions of 1080 pixels width and 1920 pixels height, maintaining a 9:16 aspect ratio.

**Validates: Requirements 1.1, 3.1, 3.2**

### Property 2: Performance Guarantee

*For any* valid DailySong object, the Card_Generator SHALL complete Story_Card generation within 2 seconds.

**Validates: Requirements 1.8, 8.1**


### Property 3: Cover Image Preservation

*For any* DailySong with a cover image, the generated Story_Card SHALL include pixel data from the source cover image.

**Validates: Requirements 1.2**

### Property 4: Contrast Ratio Compliance

*For any* mood color and text color combination in the Template_System, the contrast ratio SHALL be at least 4.5:1 to ensure readability.

**Validates: Requirements 2.3, 6.4**

### Property 5: Aspect Ratio Preservation

*For any* cover image with any aspect ratio, when scaled to fit within the Story_Card, the scaled image SHALL maintain the original aspect ratio.

**Validates: Requirements 2.6**

### Property 6: File Size Optimization

*For any* generated Story_Card, the exported PNG file size SHALL be under 8MB for Instagram compatibility.

**Validates: Requirements 3.5**


### Property 7: Mood Color Extraction

*For any* DailySong object, the Template_System SHALL correctly extract the mood color from the moodColorHex field, or use a default neutral color if the field is nil or invalid.

**Validates: Requirements 6.1, 6.5**

### Property 8: Graceful Degradation

*For any* DailySong object with missing or invalid data fields (cover image, song title, artist name, note), the Card_Generator SHALL still produce a valid Story_Card with appropriate default values.

**Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**

### Property 9: Memory Management

*For any* Story_Card generation operation, all memory resources (images, views, renderers) SHALL be released immediately after completion.

**Validates: Requirements 8.2**

### Property 10: Watermark Inclusion

*For any* generated Story_Card, the Brand_Watermark SHALL be included in the view model and rendered on the card.

**Validates: Requirements 9.1**


## Error Handling

### Error Categories

**1. Data Validation Errors**
- Missing required fields (handled gracefully with defaults)
- Invalid data formats (color hex, URLs)
- Corrupted image data

**2. Rendering Errors**
- ImageRenderer failure
- Memory allocation failure
- View rendering timeout

**3. Export Errors**
- File size exceeds limit
- Disk space insufficient
- Format conversion failure

**4. Sharing Errors**
- Instagram not installed
- Photo library permission denied
- Share sheet presentation failure

### Error Handling Strategy

```swift
enum StoryCardError: LocalizedError {
    case missingData(String)
    case renderFailed
    case imageTooLarge
    case invalidFormat
    case exportFailed(Error)
    case sharingFailed(ShareError)
    
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
        case .sharingFailed(let shareError):
            return shareError.localizedDescription
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
        case .sharingFailed(.instagramNotInstalled):
            return NSLocalizedString("install_instagram", 
                comment: "Instagram uygulamasını yükleyin")
        default:
            return NSLocalizedString("try_again", 
                comment: "Lütfen tekrar deneyin")
        }
    }
}
```


### Error Recovery Mechanisms

**Graceful Degradation**:
- Missing cover image → Use default placeholder
- Missing song title → Display "Untitled"
- Missing artist → Display "Unknown Artist"
- Missing mood color → Use default neutral color
- Missing note → Omit note section

**Retry Logic**:
- Render failures: Retry once with reduced quality
- Export failures: Retry with compression
- Share failures: Offer photo library save as fallback

**User Feedback**:
- Loading indicator during generation
- Error alerts with clear messages
- Retry buttons for recoverable errors
- Success confirmation before share sheet

### Logging Strategy

```swift
enum LogLevel {
    case debug, info, warning, error
}

struct StoryCardLogger {
    static func log(_ message: String, level: LogLevel, error: Error? = nil) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [\(level)] StoryCard: \(message)"
        
        if let error = error {
            print("\(logMessage) - Error: \(error)")
        } else {
            print(logMessage)
        }
        
        // In production, send to analytics/crash reporting
        if level == .error {
            // Analytics.logError(message, error: error)
        }
    }
}
```

**Logged Events**:
- Card generation started (with DailySong ID)
- Data validation results
- Render start/completion time
- Export file size
- Share action initiated
- Errors with full context
- Performance metrics


## Testing Strategy

### Dual Testing Approach

This feature requires both unit tests and property-based tests for comprehensive coverage:

**Unit Tests** focus on:
- Specific examples and edge cases
- Integration points between components
- Error conditions and recovery
- UI state management
- Localization strings

**Property-Based Tests** focus on:
- Universal properties across all inputs
- Comprehensive input coverage through randomization
- Performance guarantees
- Data transformation correctness

### Property-Based Testing Configuration

**Framework**: We will use **Swift Testing** (iOS 16+) with custom property test helpers, or **swift-check** library for property-based testing in Swift.

**Configuration**:
- Minimum 100 iterations per property test
- Each test references its design document property
- Tag format: `// Feature: instagram-story-cards, Property {number}: {property_text}`

### Test Structure

#### 1. Unit Tests (StoryCardGeneratorTests.swift)

```swift
import XCTest
@testable import ONE

class StoryCardGeneratorTests: XCTestCase {
    var generator: StoryCardGenerator!
    var mockContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        generator = StoryCardGenerator.shared
        mockContext = PersistenceController.preview.container.viewContext
    }
    
    // MARK: - Data Validation Tests
    
    func testDefaultCoverImage() {
        // Test that missing cover image uses default
        let song = createMockSong(withCoverImage: false)
        let viewModel = try? StoryCardViewModel.from(
            dailySong: song,
            defaultImage: UIImage(),
            watermark: UIImage()
        )
        XCTAssertNotNil(viewModel?.coverImage)
    }
    
    func testDefaultSongTitle() {
        // Test that missing song title shows "Untitled"
        let song = createMockSong(songName: nil)
        let viewModel = try? StoryCardViewModel.from(
            dailySong: song,
            defaultImage: UIImage(),
            watermark: UIImage()
        )
        XCTAssertEqual(viewModel?.songTitle, "Untitled")
    }
    
    func testDefaultArtistName() {
        // Test that missing artist shows "Unknown Artist"
        let song = createMockSong(artistName: nil)
        let viewModel = try? StoryCardViewModel.from(
            dailySong: song,
            defaultImage: UIImage(),
            watermark: UIImage()
        )
        XCTAssertEqual(viewModel?.artistName, "Unknown Artist")
    }
    
    func testNoteOmission() {
        // Test that empty note is omitted
        let song = createMockSong(note: "")
        let viewModel = try? StoryCardViewModel.from(
            dailySong: song,
            defaultImage: UIImage(),
            watermark: UIImage()
        )
        XCTAssertFalse(viewModel?.hasNote ?? true)
    }
    
    // MARK: - Configuration Tests
    
    func testFontFamily() {
        // Test that Fraunces font is configured
        XCTAssertEqual(StoryCardConfiguration.fontFamily, "Fraunces")
    }
    
    func testSafeZones() {
        // Test safe zone configuration
        XCTAssertEqual(StoryCardConfiguration.topSafeZone, 250)
        XCTAssertEqual(StoryCardConfiguration.bottomSafeZone, 250)
    }
    
    func testWatermarkOpacity() {
        // Test watermark opacity is 5%
        XCTAssertEqual(StoryCardConfiguration.watermarkOpacity, 0.05)
    }
    
    func testWatermarkSize() {
        // Test watermark doesn't exceed 10% of card area
        let cardArea = StoryCardConfiguration.width * StoryCardConfiguration.height
        let watermarkArea = StoryCardConfiguration.watermarkSize * StoryCardConfiguration.watermarkSize
        let percentage = (watermarkArea / cardArea) * 100
        XCTAssertLessThanOrEqual(percentage, 10.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testInstagramNotInstalledError() {
        // Test error when Instagram is not installed
        let shareManager = ShareManager.shared
        XCTAssertFalse(shareManager.isInstagramInstalled())
        // Verify error message
    }
    
    func testRenderFailureError() {
        // Test error handling when render fails
        // Mock render failure and verify error propagation
    }
}
```


#### 2. Property-Based Tests (StoryCardPropertyTests.swift)

```swift
import XCTest
@testable import ONE

class StoryCardPropertyTests: XCTestCase {
    var generator: StoryCardGenerator!
    
    override func setUp() {
        super.setUp()
        generator = StoryCardGenerator.shared
    }
    
    // Feature: instagram-story-cards, Property 1: Exact Dimensions and Aspect Ratio
    func testProperty1_ExactDimensions() async throws {
        // For any valid DailySong, output dimensions are 1080x1920
        for _ in 0..<100 {
            let song = generateRandomDailySong()
            let image = try await generator.generateCardAsync(from: song)
            
            XCTAssertEqual(image.size.width, 1080)
            XCTAssertEqual(image.size.height, 1920)
            
            let aspectRatio = image.size.width / image.size.height
            XCTAssertEqual(aspectRatio, 9.0/16.0, accuracy: 0.001)
        }
    }
    
    // Feature: instagram-story-cards, Property 2: Performance Guarantee
    func testProperty2_PerformanceGuarantee() async throws {
        // For any valid DailySong, generation completes within 2 seconds
        for _ in 0..<100 {
            let song = generateRandomDailySong()
            let startTime = Date()
            
            _ = try await generator.generateCardAsync(from: song)
            
            let duration = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(duration, 2.0, 
                "Generation took \(duration)s, expected < 2s")
        }
    }
    
    // Feature: instagram-story-cards, Property 3: Cover Image Preservation
    func testProperty3_CoverImagePreservation() async throws {
        // For any DailySong with cover image, output contains source pixels
        for _ in 0..<100 {
            let coverImage = generateRandomImage()
            let song = generateRandomDailySong(withCoverImage: coverImage)
            let card = try await generator.generateCardAsync(from: song)
            
            // Verify card contains pixels from cover image
            // (Sample center pixel and verify it exists in output)
            XCTAssertTrue(cardContainsImageData(card, from: coverImage))
        }
    }
    
    // Feature: instagram-story-cards, Property 4: Contrast Ratio Compliance
    func testProperty4_ContrastRatioCompliance() {
        // For any mood color, text contrast ratio >= 4.5:1
        for _ in 0..<100 {
            let moodColor = generateRandomColor()
            let textColor = Color.white // Text is always white
            
            let contrastRatio = calculateContrastRatio(
                color1: moodColor,
                color2: textColor
            )
            
            XCTAssertGreaterThanOrEqual(contrastRatio, 4.5,
                "Contrast ratio \(contrastRatio) is below 4.5:1")
        }
    }
    
    // Feature: instagram-story-cards, Property 5: Aspect Ratio Preservation
    func testProperty5_AspectRatioPreservation() {
        // For any cover image aspect ratio, scaling preserves it
        for _ in 0..<100 {
            let originalAspectRatio = Double.random(in: 0.5...2.0)
            let originalImage = generateImageWithAspectRatio(originalAspectRatio)
            
            let scaledImage = scaleImageToFit(
                originalImage,
                in: CGSize(width: 1080, height: 1920)
            )
            
            let scaledAspectRatio = scaledImage.size.width / scaledImage.size.height
            XCTAssertEqual(scaledAspectRatio, originalAspectRatio, accuracy: 0.01)
        }
    }
    
    // Feature: instagram-story-cards, Property 6: File Size Optimization
    func testProperty6_FileSizeOptimization() async throws {
        // For any generated card, file size < 8MB
        for _ in 0..<100 {
            let song = generateRandomDailySong()
            let image = try await generator.generateCardAsync(from: song)
            
            guard let pngData = image.pngData() else {
                XCTFail("Failed to convert to PNG")
                continue
            }
            
            let fileSizeInMB = Double(pngData.count) / (1024 * 1024)
            XCTAssertLessThan(fileSizeInMB, 8.0,
                "File size \(fileSizeInMB)MB exceeds 8MB limit")
        }
    }
    
    // Feature: instagram-story-cards, Property 7: Mood Color Extraction
    func testProperty7_MoodColorExtraction() {
        // For any DailySong, mood color is correctly extracted or defaults
        for _ in 0..<100 {
            let song = generateRandomDailySong()
            let viewModel = try? StoryCardViewModel.from(
                dailySong: song,
                defaultImage: UIImage(),
                watermark: UIImage()
            )
            
            XCTAssertNotNil(viewModel?.moodColor)
            
            if let hex = song.moodColorHex, !hex.isEmpty {
                // Verify extracted color matches hex
                let expectedColor = Color(hex: hex)
                XCTAssertEqual(viewModel?.moodColor, expectedColor)
            } else {
                // Verify default color is used
                let defaultColor = Color(hex: "#E8E6E0")
                XCTAssertEqual(viewModel?.moodColor, defaultColor)
            }
        }
    }
    
    // Feature: instagram-story-cards, Property 8: Graceful Degradation
    func testProperty8_GracefulDegradation() async throws {
        // For any DailySong with missing data, still produces valid card
        for _ in 0..<100 {
            let song = generateRandomDailySongWithMissingFields()
            
            // Should not throw error
            let image = try await generator.generateCardAsync(from: song)
            
            // Should produce valid image
            XCTAssertEqual(image.size.width, 1080)
            XCTAssertEqual(image.size.height, 1920)
        }
    }
    
    // Feature: instagram-story-cards, Property 9: Memory Management
    func testProperty9_MemoryManagement() async throws {
        // For any generation, memory is released after completion
        weak var weakImage: UIImage?
        
        for _ in 0..<100 {
            autoreleasepool {
                let song = generateRandomDailySong()
                let image = try? await generator.generateCardAsync(from: song)
                weakImage = image
            }
            
            // After autoreleasepool, image should be deallocated
            XCTAssertNil(weakImage, "Image was not deallocated")
        }
    }
    
    // Feature: instagram-story-cards, Property 10: Watermark Inclusion
    func testProperty10_WatermarkInclusion() async throws {
        // For any generated card, watermark is included
        for _ in 0..<100 {
            let song = generateRandomDailySong()
            let viewModel = try? StoryCardViewModel.from(
                dailySong: song,
                defaultImage: UIImage(),
                watermark: UIImage(named: "ONE_Watermark")!
            )
            
            XCTAssertNotNil(viewModel?.brandWatermark)
        }
    }
    
    // MARK: - Helper Functions
    
    private func generateRandomDailySong() -> DailySong {
        // Generate random DailySong with all fields populated
        // Implementation details...
    }
    
    private func generateRandomDailySongWithMissingFields() -> DailySong {
        // Generate DailySong with randomly missing fields
        // Implementation details...
    }
    
    private func generateRandomImage() -> UIImage {
        // Generate random test image
        // Implementation details...
    }
    
    private func generateRandomColor() -> Color {
        // Generate random color
        // Implementation details...
    }
    
    private func calculateContrastRatio(color1: Color, color2: Color) -> Double {
        // Calculate WCAG contrast ratio
        // Implementation details...
    }
}
```


#### 3. UI Tests (StoryCardUITests.swift)

```swift
import XCTest

class StoryCardUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testShareButtonExists() {
        // Navigate to archive
        app.buttons["Archive"].tap()
        
        // Select a day with a song
        app.collectionViews.cells.firstMatch.tap()
        
        // Verify share button exists
        XCTAssertTrue(app.buttons["Instagram'da Paylaş"].exists)
    }
    
    func testLoadingIndicatorDuringGeneration() {
        // Navigate to archive and select a song
        app.buttons["Archive"].tap()
        app.collectionViews.cells.firstMatch.tap()
        
        // Tap share button
        app.buttons["Instagram'da Paylaş"].tap()
        
        // Verify loading indicator appears
        XCTAssertTrue(app.activityIndicators.firstMatch.exists)
    }
    
    func testErrorMessageOnFailure() {
        // Simulate generation failure
        // Verify error alert appears with retry option
        XCTAssertTrue(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.buttons["Tekrar Dene"].exists)
    }
    
    func testShareSheetPresentation() {
        // Generate card successfully
        // Verify share sheet appears
        XCTAssertTrue(app.otherElements["ActivityListView"].exists)
    }
    
    func testAccessibilityLabel() {
        // Verify share button has accessibility label
        app.buttons["Archive"].tap()
        app.collectionViews.cells.firstMatch.tap()
        
        let shareButton = app.buttons["Instagram'da Paylaş"]
        XCTAssertNotNil(shareButton.label)
    }
}
```

### Test Coverage Goals

- **Unit Tests**: 80%+ code coverage
- **Property Tests**: 100% of correctness properties
- **UI Tests**: Critical user flows
- **Integration Tests**: Component interactions

### Performance Testing

```swift
func testPerformanceMetrics() {
    measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
        let song = generateRandomDailySong()
        _ = try? await generator.generateCardAsync(from: song)
    }
}
```

### Continuous Integration

- Run unit tests on every commit
- Run property tests on every PR
- Run UI tests before release
- Monitor performance metrics over time
- Track test coverage trends


## Implementation Details

### StoryCardView Implementation

```swift
import SwiftUI

struct StoryCardView: View {
    let viewModel: StoryCardViewModel
    
    var body: some View {
        ZStack {
            // Background: Full-screen cover image
            Image(uiImage: viewModel.coverImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: StoryCardConfiguration.width,
                    height: StoryCardConfiguration.height
                )
                .clipped()
            
            // Bottom overlay section
            VStack {
                Spacer()
                
                ZStack(alignment: .bottom) {
                    // Gradient overlay (dark to clear)
                    LinearGradient(
                        gradient: Gradient(colors: viewModel.gradientColors),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: StoryCardConfiguration.overlayHeight)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 16) {
                        // Mood accent line
                        Rectangle()
                            .fill(viewModel.moodColor)
                            .frame(
                                width: StoryCardConfiguration.accentLineWidth,
                                height: StoryCardConfiguration.accentLineHeight
                            )
                        
                        // Song title
                        Text(viewModel.songTitle)
                            .font(.custom(
                                StoryCardConfiguration.fontFamily,
                                size: StoryCardConfiguration.songTitleSize
                            ))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        // Artist name
                        Text(viewModel.artistName)
                            .font(.custom(
                                StoryCardConfiguration.fontFamily,
                                size: StoryCardConfiguration.artistNameSize
                            ))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        
                        // User note (if present)
                        if viewModel.hasNote, let note = viewModel.userNote {
                            Text(note)
                                .font(.custom(
                                    StoryCardConfiguration.fontFamily,
                                    size: StoryCardConfiguration.noteSize
                                ))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(3)
                                .italic()
                                .padding(.top, 8)
                        }
                        
                        Spacer()
                            .frame(height: 24)
                        
                        // Date
                        Text(viewModel.dateString)
                            .font(.custom(
                                StoryCardConfiguration.fontFamily,
                                size: StoryCardConfiguration.dateSize
                            ))
                            .foregroundColor(.white.opacity(0.7))
                        
                        // Watermark
                        HStack {
                            Spacer()
                            Image(uiImage: viewModel.brandWatermark)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: StoryCardConfiguration.watermarkSize)
                                .opacity(StoryCardConfiguration.watermarkOpacity)
                        }
                    }
                    .padding(.horizontal, StoryCardConfiguration.contentPadding)
                    .padding(.bottom, StoryCardConfiguration.bottomSafeZone)
                }
            }
        }
        .frame(
            width: StoryCardConfiguration.width,
            height: StoryCardConfiguration.height
        )
    }
}
```


### StoryCardGenerator Implementation

```swift
import SwiftUI
import UIKit

@MainActor
class StoryCardGenerator {
    static let shared = StoryCardGenerator()
    
    private let defaultImage: UIImage
    private let watermark: UIImage
    private var isGenerating = false
    
    private init() {
        // Load default assets
        self.defaultImage = UIImage(named: "DefaultCover") ?? UIImage()
        self.watermark = UIImage(named: "ONE_Watermark") ?? UIImage()
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
            let viewModel = try prepareViewModel(from: dailySong)
            
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
    
    private func prepareViewModel(from dailySong: DailySong) throws -> StoryCardViewModel {
        // Extract cover image
        let coverImage = dailySong.coverImage ?? defaultImage
        
        // Extract or default song info
        let songTitle = dailySong.songName?.isEmpty == false 
            ? dailySong.songName! 
            : "Untitled"
        let artistName = dailySong.artistName?.isEmpty == false 
            ? dailySong.artistName! 
            : "Unknown Artist"
        
        // Extract mood color
        let moodColor: Color
        if let hex = dailySong.moodColorHex, !hex.isEmpty {
            moodColor = Color(hex: hex)
        } else {
            moodColor = Color(hex: "#E8E6E0") // Default neutral
        }
        
        // Format date
        let dateString = dailySong.formattedDate
        
        // Extract note
        let userNote = dailySong.dailyNote?.isEmpty == false 
            ? dailySong.dailyNote 
            : nil
        
        return StoryCardViewModel(
            coverImage: coverImage,
            songTitle: songTitle,
            artistName: artistName,
            moodColor: moodColor,
            dateString: dateString,
            brandWatermark: watermark,
            userNote: userNote
        )
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
}
```


### ShareManager Implementation

```swift
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
        // Check if Instagram is installed
        guard isInstagramInstalled() else {
            completion(.failure(.instagramNotInstalled))
            return
        }
        
        // Create activity items
        let activityItems: [Any] = [image]
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
                completion(.failure(.sharingFailed(error)))
            } else if success {
                completion(.success(()))
            } else {
                // User cancelled
                completion(.success(()))
            }
        }
        
        // Present
        viewController.present(activityVC, animated: true)
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
        guard let url = URL(string: "instagram://app") else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }
}

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
```


### UI Integration Implementation

```swift
import SwiftUI

// Extension to ArchiveScreen for share functionality
struct DayDetailView: View {
    let dailySong: DailySong
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var isGeneratingCard = false
    @State private var showShareSheet = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Existing day detail UI
                // ... (song info, cover, mood, note, etc.)
                
                // Share button
                Button(action: handleShareTap) {
                    HStack {
                        if isGeneratingCard {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isGeneratingCard 
                            ? "Hazırlanıyor..." 
                            : "Instagram'da Paylaş")
                    }
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Color(hex: dailySong.moodColorHex ?? "#E8E6E0")
                    )
                    .cornerRadius(12)
                }
                .disabled(isGeneratingCard)
                .accessibilityLabel("Instagram'da paylaş")
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                )
                
                // Save to library button (fallback)
                if let image = generatedImage {
                    Button(action: handleSaveToLibrary) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Fotoğraflara Kaydet")
                        }
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "#111112"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#E8E6E0"))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 40)
        }
        .alert("Hata", isPresented: $showError) {
            Button("Tamam", role: .cancel) {}
            Button("Tekrar Dene") {
                handleShareTap()
            }
        } message: {
            Text(errorMessage ?? "Bir hata oluştu")
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = generatedImage {
                ShareSheet(image: image)
            }
        }
    }
    
    private func handleShareTap() {
        isGeneratingCard = true
        errorMessage = nil
        
        Task {
            do {
                let image = try await StoryCardGenerator.shared
                    .generateCardAsync(from: dailySong)
                
                await MainActor.run {
                    generatedImage = image
                    isGeneratingCard = false
                    showShareSheet = true
                }
                
            } catch {
                await MainActor.run {
                    isGeneratingCard = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func handleSaveToLibrary() {
        guard let image = generatedImage else { return }
        
        ShareManager.shared.saveToPhotoLibrary(image: image) { result in
            switch result {
            case .success:
                // Show success message
                break
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// UIKit wrapper for share sheet
struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        return activityVC
    }
    
    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
```


## Localization

### Localizable Strings

**Turkish (tr.lproj/Localizable.strings)**:
```
/* Share button */
"share_to_instagram" = "Instagram'da Paylaş";
"save_to_library" = "Fotoğraflara Kaydet";
"generating" = "Hazırlanıyor...";

/* Default values */
"untitled_song" = "Untitled";
"unknown_artist" = "Unknown Artist";

/* Error messages */
"missing_data_coverImage" = "Kapak görseli eksik";
"missing_data_songName" = "Şarkı adı eksik";
"render_failed" = "Kart oluşturulamadı. Lütfen tekrar deneyin.";
"image_too_large" = "Görsel boyutu çok büyük. Lütfen daha küçük bir fotoğraf kullanın.";
"invalid_format" = "Geçersiz format";
"export_failed" = "Dışa aktarma başarısız";
"instagram_not_installed" = "Instagram yüklü değil. Lütfen Instagram uygulamasını yükleyin.";
"save_failed" = "Fotoğraf kaydedilemedi";
"permission_denied" = "Fotoğraf erişim izni gerekli. Lütfen Ayarlar'dan izin verin.";

/* Recovery suggestions */
"check_song_data" = "Şarkı bilgilerini kontrol edin";
"try_again" = "Lütfen tekrar deneyin";
"reduce_image_size" = "Fotoğraf boyutunu küçültün";
"check_format" = "Format uyumluluğunu kontrol edin";
"check_storage" = "Depolama alanını kontrol edin";
"install_instagram" = "Instagram uygulamasını yükleyin";

/* Success messages */
"card_generated" = "Kart hazır!";
"saved_to_library" = "Fotoğraflara kaydedildi";
```

**English (en.lproj/Localizable.strings)**:
```
/* Share button */
"share_to_instagram" = "Share on Instagram";
"save_to_library" = "Save to Photos";
"generating" = "Generating...";

/* Default values */
"untitled_song" = "Untitled";
"unknown_artist" = "Unknown Artist";

/* Error messages */
"missing_data_coverImage" = "Cover image missing";
"missing_data_songName" = "Song name missing";
"render_failed" = "Failed to create card. Please try again.";
"image_too_large" = "Image size too large. Please use a smaller photo.";
"invalid_format" = "Invalid format";
"export_failed" = "Export failed";
"instagram_not_installed" = "Instagram not installed. Please install Instagram app.";
"save_failed" = "Failed to save photo";
"permission_denied" = "Photo library access required. Please grant permission in Settings.";

/* Recovery suggestions */
"check_song_data" = "Check song information";
"try_again" = "Please try again";
"reduce_image_size" = "Reduce photo size";
"check_format" = "Check format compatibility";
"check_storage" = "Check storage space";
"install_instagram" = "Install Instagram app";

/* Success messages */
"card_generated" = "Card ready!";
"saved_to_library" = "Saved to Photos";
```


## Assets and Resources

### Required Assets

**1. Default Cover Image**
- File: `DefaultCover.png`
- Size: 1080x1080 pixels
- Format: PNG
- Purpose: Placeholder when user hasn't uploaded a photo

**2. ONE Watermark**
- File: `ONE_Watermark.png`
- Size: 240x240 pixels (will be scaled to 80x80)
- Format: PNG with transparency
- Content: "ONE" text or logo
- Color: White

**3. Fraunces Font Family**
- Files: 
  - `Fraunces-Light.ttf`
  - `Fraunces-LightItalic.ttf`
  - `Fraunces-Regular.ttf`
- Add to Xcode project
- Update Info.plist with font names

### Info.plist Configuration

```xml
<!-- Fonts -->
<key>UIAppFonts</key>
<array>
    <string>Fraunces-Light.ttf</string>
    <string>Fraunces-LightItalic.ttf</string>
    <string>Fraunces-Regular.ttf</string>
</array>

<!-- Photo Library Usage -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>ONE needs access to save your story cards to Photos.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>ONE needs access to your photos to create story cards.</string>

<!-- URL Schemes for Instagram -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>instagram</string>
    <string>instagram-stories</string>
</array>
```

## Performance Considerations

### Optimization Strategies

**1. Image Caching**
- Cache default cover image on first load
- Cache watermark on first load
- Reuse cached assets for all generations

**2. Background Processing**
- Perform image rendering on background thread
- Use `@MainActor` only for UI updates
- Leverage Swift concurrency for async operations

**3. Memory Management**
- Use `autoreleasepool` for batch operations
- Release large objects immediately after use
- Monitor memory usage during generation

**4. Render Optimization**
- Use appropriate render scale (3.0 for retina)
- Optimize gradient calculations
- Minimize view hierarchy depth

### Performance Metrics

Target metrics:
- Generation time: < 2 seconds (95th percentile)
- Memory usage: < 50MB per generation
- File size: < 8MB (Instagram limit)
- UI responsiveness: No main thread blocking

### Monitoring

```swift
struct PerformanceMetrics {
    static func track(operation: String, duration: TimeInterval) {
        // Log to analytics
        print("[\(operation)] Duration: \(duration)s")
        
        if duration > 2.0 {
            // Alert: Performance degradation
            print("⚠️ Performance warning: \(operation) took \(duration)s")
        }
    }
    
    static func trackMemory(operation: String) {
        let used = reportMemory()
        print("[\(operation)] Memory: \(used)MB")
        
        if used > 50 {
            // Alert: High memory usage
            print("⚠️ Memory warning: \(operation) used \(used)MB")
        }
    }
    
    private static func reportMemory() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size
        ) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(
                to: integer_t.self,
                capacity: 1
            ) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }
}
```


## Security and Privacy

### Data Handling

**User Data Protection**:
- Story cards are generated in-memory only
- No server upload required
- Temporary files are deleted after sharing
- User controls when to share

**Photo Library Access**:
- Request permission only when needed
- Clear explanation in permission prompt
- Graceful handling of denied permission
- Fallback to share sheet only

**Instagram Integration**:
- Use system share sheet (no direct API)
- No Instagram credentials stored
- No tracking of share actions
- User controls final share action

### Privacy Compliance

**GDPR/KVKK Compliance**:
- No personal data collection for this feature
- User-generated content stays on device
- Optional photo library save
- Clear user consent for permissions

**Data Retention**:
- Generated images not stored by app
- User can save to photo library (optional)
- Temporary files cleaned up immediately
- No analytics on shared content

## Accessibility

### VoiceOver Support

```swift
// Share button accessibility
Button(action: handleShareTap) {
    // ...
}
.accessibilityLabel(NSLocalizedString(
    "share_to_instagram",
    comment: "Share to Instagram"
))
.accessibilityHint(NSLocalizedString(
    "share_hint",
    comment: "Creates a story card and opens share options"
))
.accessibilityAddTraits(.isButton)
```

### Dynamic Type Support

- Use system font scaling where appropriate
- Test with larger text sizes
- Ensure text doesn't overflow in card layout
- Maintain readability at all sizes

### Color Contrast

- Minimum 4.5:1 contrast ratio for text
- White text on dark gradient overlay
- Mood color used as accent only
- Tested with color blindness simulators

### Haptic Feedback

```swift
// Provide tactile feedback
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.impactOccurred()
```

## Migration and Rollout

### Phased Rollout Plan

**Phase 1: Internal Testing**
- Deploy to TestFlight
- Test with team members
- Verify all device sizes
- Check performance metrics

**Phase 2: Beta Testing**
- Release to beta users
- Collect feedback
- Monitor crash reports
- Measure generation times

**Phase 3: Production Release**
- Gradual rollout (10% → 50% → 100%)
- Monitor performance
- Track usage metrics
- Respond to user feedback

### Feature Flag

```swift
struct FeatureFlags {
    static var isStoryCardEnabled: Bool {
        // Check remote config or local override
        return UserDefaults.standard.bool(forKey: "feature_story_cards")
    }
}

// Usage in UI
if FeatureFlags.isStoryCardEnabled {
    // Show share button
}
```

### Rollback Plan

If critical issues are discovered:
1. Disable feature via feature flag
2. Hide share button from UI
3. Fix issues in hotfix branch
4. Re-enable after verification


## Dependencies

### System Requirements

- iOS 16.0+ (for ImageRenderer)
- SwiftUI framework
- UIKit framework
- Photos framework
- Core Data framework

### Third-Party Dependencies

None required. Feature uses only native iOS frameworks.

### Fallback for iOS 15

If iOS 15 support is needed, implement fallback using UIHostingController:

```swift
@available(iOS, deprecated: 16.0, message: "Use ImageRenderer on iOS 16+")
func renderViewLegacy(_ view: StoryCardView) -> UIImage? {
    let controller = UIHostingController(rootView: view)
    let targetSize = CGSize(
        width: StoryCardConfiguration.width,
        height: StoryCardConfiguration.height
    )
    
    controller.view.bounds = CGRect(origin: .zero, size: targetSize)
    controller.view.backgroundColor = .clear
    
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { _ in
        controller.view.drawHierarchy(
            in: controller.view.bounds,
            afterScreenUpdates: true
        )
    }
}
```

## Future Enhancements

### Potential Features (Not in Current Scope)

**1. Multiple Card Templates**
- Different layout styles
- User-selectable templates
- Seasonal themes

**2. Custom Branding Options**
- User can toggle watermark
- Custom watermark position
- Watermark color customization

**3. Video Story Cards**
- Animated transitions
- Music preview integration
- Export as video format

**4. Batch Export**
- Export multiple days at once
- Create monthly compilations
- Automated posting

**5. Social Media Integration**
- Direct posting to Instagram
- Twitter/X card format
- Facebook story format

**6. Analytics**
- Track share frequency
- Popular songs shared
- Engagement metrics

## Conclusion

This design document provides a comprehensive blueprint for implementing the Instagram Story Cards feature in the ONE app. The architecture is modular, testable, and follows iOS best practices. The minimalist overlay design ensures aesthetic consistency while the property-based testing approach guarantees correctness across all inputs.

Key design decisions:
- SwiftUI + ImageRenderer for modern, declarative UI
- Graceful degradation for missing data
- Comprehensive error handling
- Performance-optimized rendering
- Accessibility-first approach
- Privacy-conscious implementation

The feature is ready for implementation following the task breakdown in the tasks document.

