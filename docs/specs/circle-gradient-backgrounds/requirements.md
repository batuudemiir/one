# Requirements Document

## Introduction

This feature enhances the Circle friend preview screen to support dual background modes: photo backgrounds when users share photos, and mood color gradient backgrounds when no photo is shared. The design follows wabi-sabi philosophy where both presentations have equal aesthetic value, ensuring users who don't share photos are not penalized with empty or inferior visuals.

## Glossary

- **Circle_View**: The friend preview screen showing daily songs from friends
- **Friend_Card**: The card component displaying a friend's daily song entry
- **Photo_Background**: A background using the user's shared photo (photoData)
- **Gradient_Background**: A 3-stop gradient background using mood color when no photo exists
- **Mood_Color**: The color associated with the user's selected mood for the day
- **Detail_View**: The expanded full-screen view shown when user taps a Friend_Card
- **Background_Priority_Logic**: The decision logic determining whether to show photo or gradient

## Requirements

### Requirement 1: Background Display Priority

**User Story:** As a user viewing my Circle, I want to see either my friend's photo or a beautiful mood gradient, so that every card has an aesthetically pleasing background.

#### Acceptance Criteria

1. WHEN photoData exists for a Friend_Card, THE Circle_View SHALL display the photo as Photo_Background
2. WHEN photoData does not exist for a Friend_Card, THE Circle_View SHALL display the Gradient_Background using Mood_Color
3. THE Circle_View SHALL apply the same card layout and shape to both Photo_Background and Gradient_Background
4. FOR ALL Friend_Cards, the background SHALL be either Photo_Background or Gradient_Background with no empty or default state

### Requirement 2: Mood Color Gradient Formula

**User Story:** As a user who doesn't share photos, I want my mood to be represented with a beautiful dark gradient, so that my card looks intentional and aesthetically valuable.

#### Acceptance Criteria

1. THE Gradient_Background SHALL use a 3-stop gradient formula
2. THE Gradient_Background SHALL transition from Mood_Color to #0D0D0E
3. THE Gradient_Background SHALL display a dark, deep gradient with a trace of Mood_Color visible
4. WHEN Mood_Color is blue, THE Gradient_Background SHALL produce a gradient similar to the DERİN mood reference
5. WHEN Mood_Color is red, THE Gradient_Background SHALL produce a gradient similar to the ATEŞLİ mood reference

### Requirement 3: Detail View Background Consistency

**User Story:** As a user tapping on a friend's card, I want the same background to expand to full screen, so that the transition feels natural and continuous.

#### Acceptance Criteria

1. WHEN a user taps on a Friend_Card with Photo_Background, THE Detail_View SHALL expand the Photo_Background to full screen
2. WHEN a user taps on a Friend_Card with Gradient_Background, THE Detail_View SHALL expand the Gradient_Background to full screen
3. THE Detail_View SHALL maintain song info and mood display at the bottom
4. THE Detail_View SHALL preserve the exact background appearance from the Friend_Card during expansion

### Requirement 4: Wabi-Sabi Aesthetic Equality

**User Story:** As a designer implementing wabi-sabi philosophy, I want both photo and gradient backgrounds to have equal aesthetic value, so that users feel no pressure to share photos.

#### Acceptance Criteria

1. THE Gradient_Background SHALL be visually beautiful and intentional, not appearing as a fallback or empty state
2. THE Circle_View SHALL present Photo_Background and Gradient_Background with equal visual weight and quality
3. THE Friend_Card SHALL not display any indicators suggesting Gradient_Background is inferior to Photo_Background
4. FOR ALL users viewing Circle_View, both background types SHALL contribute equally to the overall aesthetic experience

### Requirement 5: Gradient Rendering Performance

**User Story:** As a user scrolling through my Circle, I want smooth performance regardless of background type, so that the experience feels fluid.

#### Acceptance Criteria

1. WHEN Circle_View displays multiple Friend_Cards with Gradient_Background, THE Circle_View SHALL maintain smooth scrolling performance
2. THE Gradient_Background SHALL render without visible delay or flicker
3. WHEN transitioning from Friend_Card to Detail_View, THE background expansion SHALL animate smoothly within 300ms
4. THE Circle_View SHALL handle mixed Photo_Background and Gradient_Background cards with consistent performance
