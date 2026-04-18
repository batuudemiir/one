# ONETypography Migration Status

## Completed Files ✅

### 1. DayPreviewCard.swift
**Status:** ✅ Complete  
**Changes:**
- Song name: `.displayXS()` (was 17pt serif)
- Artist name: `.monoSM(tracking: 0.4)` (was GeistMono 10pt)
- Mood/feeling labels: `.monoMicro(tracking: 0.8)` (was GeistMono 7.5pt)
- Time label: `.monoLabel(tracking: 0.5)` (was GeistMono 9pt)
- Button text: `.monoLabel()` and `.monoBase()` (was GeistMono 9-11pt)
- Instagram story: `.displayXL()` and `.displayXS()` (was 48pt and 18pt serif)

## In Progress 🔄

### 2. RecommendationCardView.swift
**Priority:** High  
**Reason:** User-facing, frequently used

### 3. TodayEmptyView.swift
**Priority:** High  
**Reason:** Main user interaction screen

### 4. MonthArchiveView.swift
**Priority:** High  
**Reason:** Archive navigation

## Pending ⏳

### Phase 1: Core Views
- [ ] YearArchiveView.swift
- [ ] ProfileView.swift
- [ ] CircleView.swift
- [ ] ArchiveView.swift

### Phase 2: Onboarding
- [ ] OnboardingView.swift
- [ ] SplashScreen.swift
- [ ] AddFriendView.swift

### Phase 3: Components
- [ ] RecommendationsSection.swift
- [ ] StoryCardView.swift
- [ ] StoryCardShareView.swift
- [ ] ONEColorPickerView.swift
- [ ] WaveStrip.swift

### Phase 4: Supporting
- [ ] PhotoPickerView.swift
- [ ] CircleShareToggle.swift
- [ ] Other utility views

## Migration Guidelines

### Display Scale (Serif)
Use for emotional, expressive content:
- Hero text, main headings → `.displayXL()` or `.displayLG()`
- Subheadings → `.displayMD()`
- Card titles → `.displaySM()` or `.displayXS()`
- Body text → `.displayBody()`

### Mono Scale (Technical)
Use for labels, metadata, technical info:
- Buttons, primary labels → `.monoBase(tracking:)`
- Metadata, timestamps → `.monoSM(tracking:)`
- Small labels, tags → `.monoLabel(tracking:)`
- Micro text, captions → `.monoMicro(tracking:)`

## Benefits Achieved

✅ Consistent typography across migrated files  
✅ Easier to maintain and update  
✅ Better semantic meaning  
✅ Reduced code duplication  
✅ Design system adherence  

## Next Steps

1. Continue migrating high-priority files
2. Test visual consistency across screens
3. Update any custom tracking values
4. Document any edge cases or exceptions
5. Create before/after screenshots for documentation

## Notes

- Some custom sizes (like 17pt) map to closest match (displayXS = 18pt)
- Custom tracking values are preserved where specified
- Icon sizes remain unchanged (they use `.font(.system(size:))` for icons)
- Some monospaced fonts at 28pt remain unchanged (no exact match in system)
