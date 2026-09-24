# Design Document: Circle Gradient Backgrounds

## Overview

This feature enhances the Circle friend preview screen with dual background modes: photo backgrounds when users share photos, and mood color gradient backgrounds when no photo is shared. The implementation follows wabi-sabi philosophy where both presentations have equal aesthetic value.

The design introduces a reusable background component that intelligently switches between photo and gradient modes based on data availability, ensuring every friend card has a beautiful, intentional appearance. The gradient implementation uses a 3-stop formula that creates deep, dark gradients with subtle mood color traces, matching the aesthetic quality of photo backgrounds.

### Key Design Goals

1. **Aesthetic Equality**: Both photo and gradient backgrounds must appear equally intentional and beautiful
2. **Performance**: Smooth scrolling with mixed background types and efficient gradient rendering
3. **Consistency**: Seamless transition from card to detail view maintaining background appearance
4. **Simplicity**: Clean component architecture with clear separation of concerns

## Architecture

### Component Hierarchy

```
CircleView
├── FriendShareCard
│   ├── BackgroundLayer (new)
│   │   ├── PhotoBackground (conditional)
│   │   └── GradientBackground (conditional)
│   └── ContentOverlay
│       ├── Avatar
│       ├── UserInfo
│       └── SongDetails
└── FriendShareDetailView
    ├── BackgroundLayer (expanded)
    │   ├── PhotoBackground (full-screen)
    │   └── GradientBackground (full-screen)
    └── ContentOverlay
        ├── Header (back button)
        └── BottomPanel (song info)
```

### Data Flow

```
DailySong/CKRecord
    ├── photoData: Data? ──────────┐
    └── moodColorHex: String ──────┤
                                   ▼
                    BackgroundPriorityLogic
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
            photoData exists?              photoData nil?
                    │                             │
                    ▼                             ▼
            PhotoBackground                GradientBackground
            (use photoData)            (use moodColorHex)
```

### Background Priority Logic

The system determines background type using a simple priority check:

1. Check if `photoData` exists and is non-empty
2. If yes → render `PhotoBackground`
3. If no → render `GradientBackground` using `moodColorHex`
4. Fallback: If `moodColorHex` is also missing, use default color `#5B8DEF` (Derin/Deep blue)

## Components and Interfaces

### 1. BackgroundLayer Component

A new reusable SwiftUI view that encapsulates background rendering logic.

```swift
struct BackgroundLayer: View {
    let photoData: Data?
    let moodColorHex: String
    let isFullScreen: Bool
    
    var body: some View {
        if let photoData = photoData, !photoData.isEmpty,
           let uiImage = UIImage(data: photoData) {
            PhotoBackground(image: uiImage, isFullScreen: isFullScreen)
        } else {
            GradientBackground(moodColorHex: moodColorHex, isFullScreen: isFullScreen)
        }
    }
}
```

**Responsibilities:**
- Determine which background type to render
- Pass appropriate data to child components
- Handle nil/empty data gracefully

**Interface:**
- `photoData: Data?` - Optional photo data from DailySong
- `moodColorHex: String` - Mood color hex string (e.g., "#5B8DEF")
- `isFullScreen: Bool` - Whether to render for card or detail view

### 2. PhotoBackground Component

Renders photo backgrounds with appropriate aspect ratio and clipping.

```swift
struct PhotoBackground: View {
    let image: UIImage
    let isFullScreen: Bool
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: isFullScreen ? .fill : .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}
```

**Responsibilities:**
- Display photo with correct aspect ratio
- Handle card vs full-screen sizing
- Clip overflow appropriately

### 3. GradientBackground Component

Renders 3-stop mood color gradients following the wabi-sabi aesthetic.

```swift
struct GradientBackground: View {
    let moodColorHex: String
    let isFullScreen: Bool
    
    private var gradientColors: [Color] {
        Color.moodToGradient(hex: moodColorHex)
    }
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea(edges: isFullScreen ? .all : [])
    }
}
```

**Responsibilities:**
- Calculate 3-stop gradient from mood color
- Render gradient with correct direction
- Handle card vs full-screen rendering

### 4. Color Extension: Gradient Calculation

A Color extension that implements the 3-stop gradient formula.

```swift
extension Color {
    static func moodToGradient(hex: String) -> [Color] {
        let moodColor = Color(hex: hex)
        let darkBase = Color(hex: "#0D0D0E")
        let intermediate = moodColor.opacity(0.4)
        
        return [moodColor, intermediate, darkBase]
    }
}
```

**Gradient Formula:**
- **Stop 1 (0%)**: Pure mood color (e.g., `#5B8DEF`)
- **Stop 2 (50%)**: Mood color at 40% opacity blended with dark base
- **Stop 3 (100%)**: Dark base `#0D0D0E`

This creates a deep, dark gradient with a subtle trace of the mood color visible at the top.

### 5. Updated FriendShareCard

Modified to use the new BackgroundLayer component.

```swift
struct FriendShareCard: View {
    let share: CKRecord
    @State private var showDetail = false
    
    var body: some View {
        Button(action: { showDetail = true }) {
            ZStack(alignment: .topLeading) {
                // Background layer
                BackgroundLayer(
                    photoData: share["photoData"] as? Data,
                    moodColorHex: share["moodColor"] as? String ?? "#5B8DEF",
                    isFullScreen: false
                )
                .frame(height: 200)
                .cornerRadius(12)
                
                // Dark overlay for text readability
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.black.opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .cornerRadius(12)
                
                // Content overlay
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()
                    
                    // User info and song details
                    // ... existing content ...
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .sheet(isPresented: $showDetail) {
            FriendShareDetailView(share: share)
        }
    }
}
```

### 6. Updated FriendShareDetailView

Modified to use BackgroundLayer for full-screen backgrounds.

```swift
struct FriendShareDetailView: View {
    @Environment(\.dismiss) var dismiss
    let share: CKRecord
    @State private var backgroundOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Full-screen background
            BackgroundLayer(
                photoData: share["photoData"] as? Data,
                moodColorHex: share["moodColor"] as? String ?? "#5B8DEF",
                isFullScreen: true
            )
            .opacity(backgroundOpacity)
            
            // Dark overlay for readability
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color(hex: "#0D0D0E").opacity(0.6),
                    Color(hex: "#0D0D0E")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Content overlay
            // ... existing content ...
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                backgroundOpacity = 1
            }
        }
    }
}
```

## Data Models

### DailySong Entity (Core Data)

Existing entity with relevant attributes:

```swift
class DailySong: NSManagedObject {
    @NSManaged var photoData: Data?           // Photo background data
    @NSManaged var moodColorHex: String?      // Mood color for gradient
    @NSManaged var moodWord: String?          // Mood name (e.g., "Derin")
    @NSManaged var isSharedWithCircle: Bool   // Whether shared with friends
    // ... other attributes
}
```

### CKRecord (CloudKit)

Friend shares fetched from CloudKit contain:

```swift
record["photoData"] as? Data              // Optional photo
record["moodColor"] as? String            // Mood color hex
record["moodWord"] as? String             // Mood name
record["songName"] as? String             // Song title
record["artistName"] as? String           // Artist name
record["dailyNote"] as? String            // User note
```

### Gradient Configuration

```swift
struct GradientConfig {
    let stops: [GradientStop]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    
    static func forMood(hex: String) -> GradientConfig {
        let colors = Color.moodToGradient(hex: hex)
        return GradientConfig(
            stops: [
                GradientStop(color: colors[0], location: 0.0),
                GradientStop(color: colors[1], location: 0.5),
                GradientStop(color: colors[2], location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
```


## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: Background Type Selection

For any friend card, if photoData exists and is non-empty, the system shall render PhotoBackground; otherwise, the system shall render GradientBackground using moodColorHex. No card shall ever render without a background.

**Validates: Requirements 1.1, 1.2, 1.4**

### Property 2: Layout Consistency Across Background Types

For any two friend cards where one has PhotoBackground and one has GradientBackground, both cards shall have identical layout properties including frame dimensions, corner radius, and clipping behavior.

**Validates: Requirements 1.3**

### Property 3: Gradient Structure Invariant

For any mood color hex value, the generated gradient shall contain exactly 3 color stops where the first stop is the mood color, the third stop is #0D0D0E, and the intermediate stop is a blend of the two.

**Validates: Requirements 2.1, 2.2**

### Property 4: Detail View Background Preservation

For any friend card with either PhotoBackground or GradientBackground, when navigating to the detail view, the detail view shall use the exact same background data (photo or gradient colors) as the card.

**Validates: Requirements 3.1, 3.2, 3.4**

### Property 5: Detail View Layout Structure

For any detail view, the song information and mood display shall be positioned in the bottom region of the screen, regardless of background type.

**Validates: Requirements 3.3**

### Property 6: No Inferiority Indicators

For any friend card with GradientBackground, the card shall not display any UI elements (badges, labels, icons, or text) that indicate the gradient is a fallback or inferior to PhotoBackground.

**Validates: Requirements 4.3**

### Property 7: Animation Timing Constraint

For any transition from friend card to detail view, the background expansion animation duration shall be configured to 300ms or less.

**Validates: Requirements 5.3**

### Example Test Cases

**Example 1: Blue Mood Gradient (Derin)**
- Input: moodColorHex = "#5B8DEF"
- Expected: Gradient with stops [#5B8DEF, intermediate blend, #0D0D0E]
- Visual reference: Should match DERİN mood aesthetic

**Validates: Requirements 2.4**

**Example 2: Red Mood Gradient (Ateşli)**
- Input: moodColorHex = "#E84040"
- Expected: Gradient with stops [#E84040, intermediate blend, #0D0D0E]
- Visual reference: Should match ATEŞLİ mood aesthetic

**Validates: Requirements 2.5**

## Error Handling

### Missing or Invalid Data

**Scenario 1: Missing photoData and moodColorHex**
- Condition: Both `photoData` and `moodColorHex` are nil or empty
- Handling: Use default mood color `#5B8DEF` (Derin blue) for gradient
- User Impact: Card displays with default gradient, no error shown
- Rationale: Graceful degradation maintains aesthetic consistency

**Scenario 2: Corrupted photoData**
- Condition: `photoData` exists but `UIImage(data:)` returns nil
- Handling: Fall back to GradientBackground using moodColorHex
- User Impact: Card displays gradient instead of broken image
- Logging: Log warning for debugging purposes
- Rationale: Prevents blank cards, maintains user experience

**Scenario 3: Invalid moodColorHex format**
- Condition: `moodColorHex` is not a valid hex color string
- Handling: Use default color `#5B8DEF` for gradient calculation
- User Impact: Card displays with default gradient
- Logging: Log warning with invalid value
- Rationale: Prevents rendering failures

**Scenario 4: Empty photoData**
- Condition: `photoData` exists but has zero bytes
- Handling: Treat as nil, render GradientBackground
- User Impact: Card displays gradient
- Rationale: Empty data is equivalent to missing data

### Performance Degradation

**Scenario 5: Large photoData files**
- Condition: Photo data exceeds reasonable size (e.g., >5MB)
- Handling: Load photo asynchronously, show gradient placeholder during load
- User Impact: Brief gradient display before photo appears
- Rationale: Prevents UI blocking and maintains smooth scrolling

**Scenario 6: Memory pressure**
- Condition: System reports memory warnings
- Handling: Release cached photo images, rely on SwiftUI's image caching
- User Impact: Possible brief re-loading of images
- Rationale: Prevents app termination

### Edge Cases

**Scenario 7: Rapid card-to-detail transitions**
- Condition: User taps card before previous detail view dismisses
- Handling: Cancel previous transition, start new one
- User Impact: Smooth transition to new detail view
- Rationale: Prevents animation conflicts

**Scenario 8: Missing mood color in detail view**
- Condition: Card has gradient but moodColorHex becomes unavailable
- Handling: Use last known color or default color
- User Impact: Detail view displays with fallback gradient
- Rationale: Maintains visual consistency

## Testing Strategy

### Dual Testing Approach

This feature requires both unit tests and property-based tests to ensure comprehensive coverage:

**Unit Tests** focus on:
- Specific example cases (blue gradient, red gradient)
- Edge cases (nil data, corrupted data, empty data)
- Integration points (BackgroundLayer component selection logic)
- Error conditions (invalid hex colors, missing data)

**Property-Based Tests** focus on:
- Universal properties across all mood colors
- Background type selection for all data combinations
- Layout consistency across all card types
- Gradient structure for all valid hex inputs

Together, these approaches provide comprehensive coverage where unit tests catch concrete bugs and property tests verify general correctness.

### Property-Based Testing Configuration

**Framework**: Use Swift's built-in testing with custom property test helpers, or integrate a Swift property testing library such as SwiftCheck.

**Test Configuration**:
- Minimum 100 iterations per property test
- Each test tagged with feature name and property reference
- Tag format: `// Feature: circle-gradient-backgrounds, Property {number}: {property_text}`

**Example Property Test Structure**:

```swift
func testProperty1_BackgroundTypeSelection() {
    // Feature: circle-gradient-backgrounds, Property 1: Background type selection
    
    for _ in 0..<100 {
        let hasPhoto = Bool.random()
        let photoData = hasPhoto ? generateRandomPhotoData() : nil
        let moodColorHex = generateRandomMoodColor()
        
        let backgroundType = BackgroundLayer.determineType(
            photoData: photoData,
            moodColorHex: moodColorHex
        )
        
        if hasPhoto {
            XCTAssertEqual(backgroundType, .photo)
        } else {
            XCTAssertEqual(backgroundType, .gradient)
        }
    }
}
```

### Unit Test Coverage

**Component Tests**:
1. `BackgroundLayer` - background type selection logic
2. `PhotoBackground` - image rendering and aspect ratio
3. `GradientBackground` - gradient calculation and rendering
4. `Color.moodToGradient()` - gradient formula implementation
5. `FriendShareCard` - background integration
6. `FriendShareDetailView` - full-screen background expansion

**Example Tests**:
1. Blue mood gradient matches expected colors
2. Red mood gradient matches expected colors
3. Nil photoData renders gradient
4. Valid photoData renders photo
5. Invalid hex color uses default
6. Empty photoData treated as nil

**Edge Case Tests**:
1. Corrupted photo data falls back to gradient
2. Missing moodColorHex uses default color
3. Both photoData and moodColorHex missing uses default
4. Large photo data loads asynchronously
5. Rapid transitions handled gracefully

### Integration Testing

**Manual Testing Checklist**:
1. Scroll through Circle with mixed photo/gradient cards
2. Verify smooth scrolling performance
3. Tap cards with photos, verify full-screen expansion
4. Tap cards with gradients, verify full-screen expansion
5. Verify no visual indicators of inferiority on gradient cards
6. Test with all 8 mood colors
7. Test with various photo aspect ratios
8. Test transition animations (should be ≤300ms)

**Visual Regression Testing**:
1. Capture screenshots of gradient cards for each mood color
2. Compare against reference images
3. Verify gradients appear dark and deep with mood color trace
4. Verify photo and gradient cards have equal visual weight

### Performance Testing

**Metrics to Monitor**:
1. Scrolling frame rate with 20+ cards (target: 60fps)
2. Gradient rendering time (target: <16ms)
3. Photo loading time (target: <100ms)
4. Memory usage with 50+ cards (target: <100MB)
5. Transition animation duration (target: ≤300ms)

**Performance Test Scenarios**:
1. Scroll through 50 gradient cards
2. Scroll through 50 photo cards
3. Scroll through mixed 50 cards (25 photo, 25 gradient)
4. Rapidly open/close 10 detail views
5. Test on older devices (iPhone 8 or equivalent)

### Accessibility Testing

**VoiceOver Testing**:
1. Verify background type is not announced (implementation detail)
2. Verify card content is properly announced
3. Verify detail view content is accessible
4. Test navigation between cards and detail views

**Visual Accessibility**:
1. Verify text readability on all gradient backgrounds
2. Verify text readability on various photo backgrounds
3. Test with increased text size settings
4. Test with reduced transparency settings

## Implementation Notes

### Gradient Direction Rationale

The gradient uses `startPoint: .topLeading` and `endPoint: .bottomTrailing` (diagonal) rather than vertical for several reasons:

1. **Visual Interest**: Diagonal gradients create more dynamic, interesting backgrounds
2. **Wabi-Sabi Aesthetic**: Asymmetry (fukinsei) is a core wabi-sabi principle
3. **Depth Perception**: Diagonal gradients create better sense of depth
4. **Differentiation**: Distinguishes gradient cards from simple solid colors

### Opacity Strategy

The intermediate gradient stop uses 40% opacity to create the "trace of mood color" effect:

- Too high (>60%): Gradient appears too bright, not "deep and dark"
- Too low (<20%): Mood color becomes imperceptible
- 40%: Optimal balance of visibility and darkness

This value may need fine-tuning based on visual testing with all 8 mood colors.

### Performance Optimization

**Gradient Caching**: SwiftUI's `LinearGradient` is already optimized and doesn't require manual caching. The gradient calculation is lightweight (3 color stops) and can be computed on-demand.

**Photo Caching**: SwiftUI's `Image` view automatically caches decoded images. No additional caching layer is needed unless performance testing reveals issues.

**Lazy Loading**: The `ScrollView` in `CircleView` already uses lazy loading through `ForEach`, so cards are only rendered when visible.

### Animation Considerations

The 300ms animation duration for card-to-detail transition is chosen to:
- Feel responsive (not sluggish)
- Allow smooth visual tracking
- Match iOS standard animation durations
- Provide enough time for background expansion to be perceived

The animation uses `.easeInOut` curve for natural, organic motion aligned with wabi-sabi principles.

### Color Space Considerations

All colors use sRGB color space (SwiftUI default). The gradient interpolation happens in sRGB space, which may produce slightly different results than other color spaces (like Display P3). This is acceptable as:
- sRGB is universally supported
- Differences are subtle for these dark gradients
- Consistency across devices is more important than perfect color science

### Future Enhancements

Potential improvements for future iterations:

1. **Animated Gradients**: Subtle animation of gradient colors for living, breathing effect
2. **Gradient Presets**: Pre-computed gradients for each mood color to ensure perfect consistency
3. **Custom Gradient Angles**: Allow users to customize gradient direction
4. **Gradient Complexity**: Add 4th or 5th stop for more nuanced transitions
5. **Photo Filters**: Apply subtle filters to photos to match gradient aesthetic
6. **Adaptive Overlays**: Adjust overlay darkness based on background brightness
7. **Blur Effects**: Add subtle blur to backgrounds for depth of field effect

