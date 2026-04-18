# Implementation Plan: Instagram Story Cards

## Overview

Bu implementation plan, ONE uygulamasına Instagram Story Cards özelliğini eklemek için gerekli tüm adımları içerir. Plan, core functionality (kart oluşturma) ile başlar, UI entegrasyonuna geçer ve polish/testing ile tamamlanır. Tüm implementasyon Swift ve SwiftUI kullanarak iOS 16+ için yapılacaktır.

## Tasks

- [ ] 1. Core data model ve configuration setup
  - DailySong extension'ları oluştur (coverImage, formattedDate, isValidForCard computed properties)
  - StoryCardConfiguration struct'ını oluştur (dimensions, safe zones, typography, branding constants)
  - StoryCardError enum'ını oluştur (error types ve localized descriptions)
  - _Requirements: 1.1, 3.1, 3.2, 7.1-7.5_

- [ ] 2. StoryCardViewModel ve view model logic
  - [ ] 2.1 StoryCardViewModel struct'ını implement et
    - Required ve optional fields tanımla
    - Computed properties ekle (hasNote, gradientColors)
    - Factory method implement et (DailySong'dan ViewModel'e dönüşüm)
    - Default değerler ve graceful degradation logic
    - _Requirements: 1.2-1.7, 7.1-7.5_
  
  - [ ]* 2.2 Write property test for StoryCardViewModel
    - **Property 7: Mood Color Extraction**
    - **Validates: Requirements 6.1, 6.5**
    - Test mood color extraction ve default color fallback
  
  - [ ]* 2.3 Write property test for graceful degradation
    - **Property 8: Graceful Degradation**
    - **Validates: Requirements 7.1-7.5**
    - Test missing data handling ve default values

- [ ] 3. StoryCardView SwiftUI component
  - [ ] 3.1 StoryCardView temel layout'unu oluştur
    - 1080x1920 frame setup
    - Cover image layer (full screen, aspect fill)
    - Gradient overlay layer (bottom to top)
    - _Requirements: 1.2, 2.4, 2.6, 3.1, 3.2_
  
  - [ ] 3.2 Text overlay ve content positioning
    - Mood accent line (3px, 120px width)
    - Song title (Fraunces, 48pt, white)
    - Artist name (Fraunces, 32pt, white)
    - User note (Fraunces, 24pt, white, conditional)
    - Date (Fraunces, 18pt, white)
    - Safe zone compliance (top 250px, bottom 250px)
    - _Requirements: 1.3-1.5, 2.1, 2.3, 2.5, 3.4_
  
  - [ ] 3.3 Brand watermark integration
    - ONE logo/text watermark
    - 5% opacity
    - Bottom corner positioning
    - Size constraint (max 10% of card area)
    - _Requirements: 1.7, 9.1-9.4_
  
  - [ ]* 3.4 Write property test for dimensions
    - **Property 1: Exact Dimensions and Aspect Ratio**
    - **Validates: Requirements 1.1, 3.1, 3.2**
    - Test output dimensions 1080x1920 ve 9:16 aspect ratio
  
  - [ ]* 3.5 Write property test for contrast ratio
    - **Property 4: Contrast Ratio Compliance**
    - **Validates: Requirements 2.3, 6.4**
    - Test text contrast ratio >= 4.5:1

- [ ] 4. Checkpoint - Core view rendering testi
  - StoryCardView'ı preview'da test et
  - Farklı data kombinasyonları ile görsel kontrol
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. StoryCardGenerator service layer
  - [ ] 5.1 StoryCardGenerator class'ını implement et
    - Singleton pattern setup
    - prepareViewModel method (data validation ve transformation)
    - generateCardAsync method (ImageRenderer kullanarak render)
    - optimizeImage method (compression ve size optimization)
    - Error handling ve logging
    - _Requirements: 1.8, 3.3, 3.5, 7.6, 8.1-8.4_
  
  - [ ]* 5.2 Write property test for performance
    - **Property 2: Performance Guarantee**
    - **Validates: Requirements 1.8, 8.1**
    - Test generation time < 2 seconds
  
  - [ ]* 5.3 Write property test for cover image preservation
    - **Property 3: Cover Image Preservation**
    - **Validates: Requirements 1.2**
    - Test cover image pixel data preservation
  
  - [ ]* 5.4 Write property test for file size
    - **Property 6: File Size Optimization**
    - **Validates: Requirements 3.5**
    - Test PNG file size < 8MB
  
  - [ ]* 5.5 Write property test for aspect ratio preservation
    - **Property 5: Aspect Ratio Preservation**
    - **Validates: Requirements 2.6**
    - Test cover image aspect ratio preservation during scaling

- [ ] 6. ShareManager ve iOS sharing integration
  - [ ] 6.1 ShareManager class'ını implement et
    - Singleton pattern setup
    - shareToInstagram method (UIActivityViewController)
    - saveToPhotoLibrary method (fallback)
    - isInstagramInstalled method (URL scheme check)
    - Temporary file management
    - Error handling (ShareError enum)
    - _Requirements: 4.1-4.6_
  
  - [ ]* 6.2 Write unit tests for ShareManager
    - Test Instagram detection
    - Test photo library save
    - Test error scenarios

- [ ] 7. UI Integration - Archive screen extension
  - [ ] 7.1 Archive preview'a share button ekle
    - Button UI design (icon + text)
    - Button positioning ve accessibility
    - Loading state management (@State variables)
    - Error alert presentation
    - Success feedback
    - _Requirements: 5.1-5.5_
  
  - [ ] 7.2 Share button action handler
    - handleShareTap method implement et
    - StoryCardGenerator.generateCardAsync çağrısı
    - ShareManager.shareToInstagram çağrısı
    - Error handling ve user feedback
    - Loading indicator control
    - _Requirements: 4.1-4.2, 5.3-5.5_
  
  - [ ]* 7.3 Write integration tests
    - Test end-to-end flow (button tap → card generation → share sheet)
    - Test error scenarios ve recovery

- [ ] 8. Checkpoint - Integration testing
  - Archive screen'den share flow'unu test et
  - Farklı DailySong records ile test et
  - Error scenarios'ları test et (missing data, Instagram not installed)
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. Localization ve accessibility
  - [ ] 9.1 Localizable strings ekle
    - Turkish ve English translations
    - Error messages
    - Button labels
    - Success messages
    - _Requirements: 10.1-10.2_
  
  - [ ] 9.2 Accessibility improvements
    - VoiceOver labels ekle
    - Haptic feedback ekle (button tap)
    - Dynamic type support
    - _Requirements: 10.4-10.5_

- [ ] 10. Memory management ve performance optimization
  - [ ] 10.1 Memory leak kontrolü
    - ImageRenderer cleanup
    - Temporary file cleanup
    - Image cache management
    - _Requirements: 8.2_
  
  - [ ]* 10.2 Write property test for memory management
    - **Property 9: Memory Management**
    - **Validates: Requirements 8.2**
    - Test resource cleanup after generation
  
  - [ ] 10.3 Background thread optimization
    - Image processing'i background thread'e taşı
    - Main thread blocking'i önle
    - _Requirements: 8.3_

- [ ] 11. Brand assets ve watermark
  - [ ] 11.1 ONE logo/watermark asset'ini ekle
    - Assets.xcassets'e watermark image ekle
    - Watermark loading logic
    - Fallback handling (asset missing)
    - _Requirements: 9.1-9.5_

- [ ] 12. Final polish ve edge case handling
  - [ ] 12.1 Edge case testing
    - Very long song titles (truncation)
    - Very long notes (truncation/wrapping)
    - Missing Fraunces font fallback
    - Network image loading timeout
    - _Requirements: 2.1, 7.1-7.5_
  
  - [ ] 12.2 Error message refinement
    - User-friendly error messages
    - Retry mechanisms
    - Recovery suggestions
    - _Requirements: 7.6_
  
  - [ ] 12.3 Visual polish
    - Gradient tuning
    - Spacing adjustments
    - Typography fine-tuning
    - _Requirements: 2.2, 2.5_

- [ ] 13. Final checkpoint - Comprehensive testing
  - Test tüm user flows
  - Test tüm error scenarios
  - Performance testing (generation time, memory usage)
  - Visual quality check
  - Instagram compatibility check
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from design document
- Unit tests validate specific examples and edge cases
- Implementation uses Swift + SwiftUI + ImageRenderer (iOS 16+)
- All code integrates with existing ONE app structure (Core Data, CloudKit, etc.)
