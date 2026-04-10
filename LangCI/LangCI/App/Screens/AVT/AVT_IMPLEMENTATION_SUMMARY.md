# AVT (Auditory Verbal Therapy) Tab Implementation

## Overview
Complete UIKit Swift implementation of the AVT tab for the LangCI cochlear implant language learning app. Four production-quality view controllers supporting auditory verbal therapy with hierarchical listening levels.

## Files Created

### 1. AVTViewController.swift
**Home screen for AVT module**

**Features:**
- Hero header with indigo/violet gradient and ear icon
- Today's focus strip showing 3 active target sounds (sh, ush, mm) as colour-coded pills
- "Start Today's Drill" quick-action button
- Listening Hierarchy progress card (4 levels: detection, discrimination, identification, comprehension) with progress bars
- Sound Wall navigation button
- Recent sessions table (3 most recent with sound pill, level, accuracy %, date)
- Audiologist notes strip with latest note summary and "Add Note" button

**Data loading:**
- `getHomeStats()` - aggregate statistics
- `getActiveTargets()` - current targets with levels
- `getRecentSessions(count: 3)` - recent drill sessions
- `getLatestNote()` - most recent audiologist note

**Navigation:**
- Tapping a target sound pill pushes AVTDrillViewController
- "Start Today's Drill" starts with first active target
- "View Sound Wall" pushes AVTSoundWallViewController
- "Add Note" pushes AVTAudiologistNoteViewController

### 2. AVTDrillViewController.swift
**Core interactive drill screen with level-adaptive UI**

**Init params:**
- `sound: String` - current sound being trained
- `level: ListeningHierarchy` - current level (detection, discrimination, identification, comprehension)
- `targetId: Int` - target ID for progress updates

**Features:**
- Navigation bar with "Switch Level" action sheet
- Level badge strip (4 pills showing current level highlighted)
- 10-dot progress tracker (current dot pulses with animation)
- Adaptive main card based on hierarchy level:

  **Detection Level:**
  - "Did you hear a sound?" title
  - Large ear icon (60pt)
  - Play button (80pt circle)
  - "Yes, I heard it" (green) and "No sound" (red) answer buttons

  **Discrimination Level:**
  - "Are these the same or different?" title
  - Two side-by-side play buttons (Play A | Play B)
  - "Same" (blue) and "Different" (orange) answer buttons

  **Identification Level:**
  - "Which word did you hear?" title
  - Single play button
  - 4 answer choice buttons (2x2 grid with word + IPA)

  **Comprehension Level:**
  - "What does this word mean?" title
  - Single play button
  - 4 answer choice buttons (meaning descriptions)

- Feedback overlay animation on answers:
  - Green flash + "✓ Correct!" for correct answers
  - Red flash + "✗ Try again" + hint (IPA) for incorrect answers
  - Auto-dismisses after 1.2 seconds

- Session complete screen (10 items):
  - Trophy animation (🏆)
  - Large accuracy % (e.g., "85%")
  - "Level up?" suggestion if accuracy ≥ 80%
  - "Practice Again" and "Done" buttons

**Audio:**
- Uses `AVAudioPlayer` for playback
- Graceful fallback to visual cue ("🔊 [sound]") if audio file not found
- Loads from Bundle.main (try .mp3 then .wav)

**Data flow:**
1. Load drill items via `getDrillItems(sound:level:)` (shuffle, take 10)
2. Call `startSession()` to get sessionId
3. On each answer: `recordAttempt()` records response
4. After 10 items: show complete screen
5. On Done: `completeSession()` and `setTargetLevel()` if accuracy ≥ 80%

**Level progression:**
- Detection → Discrimination → Identification → Comprehension
- Auto-upgrade on 80%+ accuracy

### 3. AVTSoundWallViewController.swift
**Visual phoneme wall showing all assigned targets and progress**

**Features:**
- Hero header with square.grid.3x3 icon
- 2-column compositional collection view layout
- Each sound card displays:
  - Large IPA phoneme (32pt, bold)
  - Sound name (22pt)
  - Frequency range (12pt, secondary)
  - Hierarchy level badge (colour-coded, bottom)
  - Progress bar showing level progression (0-4)
  - Subtle gradient background matching level colour
  - Inactive targets appear greyed out (50% alpha)

- Floating "+" add button (bottom right, indigo, 56pt diameter)
  - Opens alert with fields: sound, IPA, frequency range, description
  - Creates new AVTTarget via `saveTarget()`

- Tap a card to launch AVTDrillViewController for that sound

**Data:**
- `getAllTargets()` - all AVT targets (active and inactive)

**Colours by level:**
- Detection: gray
- Discrimination: orange
- Identification: blue
- Comprehension: green

### 4. AVTAudiologistNoteViewController.swift
**Log notes from audiologist sessions**

**Features:**
- Hero header with stethoscope icon
- Date card with UIDatePicker (compact, defaults to today)
- Target sounds card:
  - Pre-populated with active targets (sh, ush, mm)
  - Each sound is a toggleable pill (green highlight when selected)
  - Custom sound text field + "Add" button for new sounds
- Notes card:
  - UITextView (200pt min height)
  - Character counter (0 / 1000)
  - Placeholder text
- Next appointment card:
  - Toggle switch "Next appointment scheduled"
  - UIDatePicker (date + time) visible when toggle on
- Save button (full width, indigo):
  - Validates and saves note via `saveNote()`
  - Creates new AVTTarget for any custom sounds added
  - Shows success toast and pops
- Past notes section:
  - UITableView showing all past notes (most recent first)
  - Each cell: date + target sounds pills + note preview (60 chars)
  - Swipe to delete (with service call)

**Data loading:**
- `getActiveTargets()` - pre-populate selected sounds
- `getAllNotes()` - load past notes history

## Key Design Patterns

### MVVM Integration
- No ViewModels needed; direct service calls via `ServiceLocator`
- `@MainActor.run` for all UI updates from async tasks
- Error handling with `UIAlertController`

### Colours & Styling
```swift
let avtColor = UIColor(red: 0.35, green: 0.25, blue: 0.80, alpha: 1) // Deep indigo
```

**Level colours:**
- Detection: `UIColor.systemGray`
- Discrimination: `UIColor.lcOrange`
- Identification: `UIColor.lcBlue`
- Comprehension: `UIColor.lcGreen`

**Shared components:**
- `HeroHeaderView(title:subtitle:systemIcon:color:)`
- `LCButton(title:color:)`
- `LCCard()`
- `SectionHeaderView(title:)`
- `ProgressBarView()`
- `UIFont.lcHeroTitle()`, `lcSectionTitle()`, `lcBodyBold()`, `lcBody()`, `lcCaption()`
- `UIColor.lcBlue`, `lcGreen`, `lcOrange`, `lcRed`, `lcCard`, `lcBackground`
- `LC.cornerRadius = 16`, `LC.cardPadding = 16`

### Async/Await
- All service calls wrapped in `Task { }`
- Error handling in catch blocks
- `await MainActor.run` for UI updates
- No force-unwraps; safe optionals throughout

### Animation
- Pulsing dots for current progress indicator
- Trophy scale-in animation on session complete
- Feedback overlay fade in/out on answers
- Card gradient overlays for visual feedback

## Service Interface Requirements

The implementation expects these methods on `ServiceLocator.shared.avtService`:

```swift
// Home stats
func getHomeStats() async throws -> AVTHomeStats
func getActiveTargets() async throws -> [AVTTarget]
func getRecentSessions(count: Int) async throws -> [AVTSession]
func getLatestNote() async throws -> AVTAudiologistNote?

// Drill
func getDrillItems(sound: String, level: ListeningHierarchy) async throws -> [AVTDrillItem]
func startSession(targetSound: String, level: ListeningHierarchy) async throws -> Int
func recordAttempt(sessionId: Int, targetSound: String, presentedSound: String, userResponse: String, isCorrect: Bool, level: ListeningHierarchy) async throws -> Void
func completeSession(sessionId: Int) async throws -> Void
func setTargetLevel(targetId: Int, newLevel: ListeningHierarchy) async throws -> Void

// Sound Wall
func getAllTargets() async throws -> [AVTTarget]
func saveTarget(_ target: AVTTarget) async throws -> Void

// Audiologist Notes
func getAllNotes() async throws -> [AVTAudiologistNote]
func saveNote(_ note: AVTAudiologistNote) async throws -> Void
func deleteNote(noteId: Int) async throws -> Void
```

## Model Types Expected

```swift
struct AVTTarget {
    let id: Int
    let sound: String
    let ipa: String
    let frequencyRange: String
    let description: String
    let currentLevel: ListeningHierarchy
    let isActive: Bool
}

struct AVTSession {
    let id: Int
    let targetSound: String
    let level: ListeningHierarchy
    let accuracy: Double // 0.0-1.0
    let date: Date
}

struct AVTHomeStats {
    let totalSessions: Int
    let averageAccuracy: Double
    let targetCount: Int
}

struct AVTDrillItem {
    let sound: String
    let displayText: String
    let audioFileName: String
    let distractors: [AVTDistractor]
    let level: ListeningHierarchy
    let correctAnswer: String
}

struct AVTDistractor {
    let text: String
    let audioFileName: String
    let isCorrect: Bool
}

struct AVTAudiologistNote {
    let id: Int
    let date: Date
    let targetSounds: [String]
    let notes: String
    let nextAppointment: Date?
}

enum ListeningHierarchy: Int, CaseIterable {
    case detection = 0
    case discrimination = 1
    case identification = 2
    case comprehension = 3
}
```

## iOS Requirements

- **Minimum iOS:** 17+
- **Swift:** 5.9+
- **Dependencies:** UIKit, AVFoundation (built-in)
- **No external pods required** — uses shared LangCI UI component library

## Testing Checklist

- [ ] Load AVTViewController and verify data displays correctly
- [ ] Tap a target sound pill and verify AVTDrillViewController opens with correct sound/level
- [ ] Start detection level drill and verify UI shows ear icon + play button + yes/no answers
- [ ] Start discrimination level and verify two play buttons + same/different answers
- [ ] Start identification level and verify play button + 4 word choices
- [ ] Start comprehension level and verify play button + 4 meaning choices
- [ ] Answer questions and verify feedback overlay animates correctly
- [ ] Complete 10 items and verify session complete screen shows trophy animation
- [ ] Test level upgrade suggestion (80%+ accuracy)
- [ ] Test "Switch Level" action sheet
- [ ] Navigate to Sound Wall and verify 2-column layout
- [ ] Add a new target sound via floating button
- [ ] Tap a sound card and verify drill launches for that sound
- [ ] Navigate to Audiologist Note and verify date picker works
- [ ] Add custom sounds in note and verify they're saved as new targets
- [ ] Test swipe-to-delete on past notes
- [ ] Verify all async data loads handle errors gracefully

## Notes for Integration

1. **ServiceLocator pattern:** Ensure `ServiceLocator.shared.avtService` is properly registered in DI container
2. **Audio files:** Place audio assets in `Assets.xcassets` or app bundle with naming pattern: `{sound}_{level}.mp3` or similar
3. **Haptic feedback:** Consider adding `UIImpactFeedbackGenerator` for answer submissions
4. **Accessibility:** All interactive elements have proper `accessibilityLabel` and `accessibilityHint`
5. **No storyboards:** All layouts programmatic (UIKit constraints)
6. **Safe area handling:** All layouts respect safe area insets for notch/home indicator

## Production Quality Checklist

- [x] No force-unwraps
- [x] Comprehensive error handling
- [x] Proper async/await with Main thread safety
- [x] Memory-safe (no retain cycles, proper weak self if needed)
- [x] Accessibility labels on all interactive elements
- [x] Localization-ready (all strings in code, can be moved to Localizable.strings)
- [x] No debug prints (production ready)
- [x] Proper separation of concerns (UI, data loading, actions)
- [x] Reusable cell classes with proper configuration methods
- [x] Responsive layouts (work on multiple screen sizes)
- [x] Dark mode support (uses semantic colors)
- [x] Animation performance (GPU-accelerated layers where applicable)
