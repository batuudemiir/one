# ONETypography Migration Plan

## Overview
Migrate all manual font definitions to use the ONETypography design system.

## Typography System

### Display Scale (Serif - Emotional)
- `displayXL()` - 48pt Serif Regular Italic - Hero text, splash screens
- `displayLG()` - 34pt Serif Medium Italic - Main headings
- `displayMD()` - 26pt Serif Medium Italic - Subheadings
- `displaySM()` - 22pt Serif Semibold - Card titles
- `displayXS()` - 18pt Serif Medium Italic - Small headings
- `displayBody()` - 16pt Serif Regular Italic - Body text

### Mono Scale (Technical)
- `monoBase(tracking:)` - 11pt Mono Semibold - Buttons, labels
- `monoSM(tracking:)` - 10pt Mono Semibold - Metadata, timestamps
- `monoLabel(tracking:)` - 9pt Mono Semibold - Small labels, tags
- `monoMicro(tracking:)` - 8pt Mono Semibold - Micro text, captions

## Migration Priority

### Phase 1: Core Views (High Priority)
1. ✅ TodayEmptyView.swift - Main user interaction
2. ✅ DayPreviewCard.swift - Archive detail view
3. ✅ MonthArchiveView.swift - Archive month view
4. ✅ YearArchiveView.swift - Archive year view
5. ✅ ProfileView.swift - User profile
6. ✅ CircleView.swift - Social feature

### Phase 2: Onboarding & Setup
7. ⏳ OnboardingView.swift
8. ⏳ SplashScreen.swift
9. ⏳ AddFriendView.swift

### Phase 3: Components
10. ⏳ RecommendationsSection.swift
11. ⏳ RecommendationCardView.swift
12. ⏳ StoryCardView.swift
13. ⏳ StoryCardShareView.swift
14. ⏳ ONEColorPickerView.swift

### Phase 4: Supporting Views
15. ⏳ WaveStrip.swift
16. ⏳ PhotoPickerView.swift
17. ⏳ Other utility views

## Migration Rules

### Serif Fonts → Display Scale
```swift
// Before
.font(.system(size: 48, design: .serif))
.italic()

// After
.displayXL()
```

### Monospaced Fonts → Mono Scale
```swift
// Before
.font(.custom("GeistMono-Regular", size: 11))
.tracking(1.8)

// After
.monoBase(tracking: 1.8)
```

### Size Mapping
- 48pt serif → displayXL()
- 34pt serif → displayLG()
- 26pt serif → displayMD()
- 22pt serif → displaySM()
- 18pt serif → displayXS()
- 16pt serif → displayBody()
- 11pt mono → monoBase()
- 10pt mono → monoSM()
- 9pt mono → monoLabel()
- 8pt mono → monoMicro()

## Benefits
- Consistent typography across the app
- Easier maintenance and updates
- Better design system adherence
- Reduced code duplication
- Clearer semantic meaning
