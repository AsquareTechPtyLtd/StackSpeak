# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# StackSpeak

## Project Overview
Native iOS and Android vocabulary apps for software developers and engineers.
Delivers 5 technical words daily to help developers communicate more 
confidently in interviews, architecture discussions, and leadership contexts.

**Development Approach:** Separate native apps sharing only the word database (words.json).
- iOS: Swift + SwiftUI
- Android: Kotlin + Jetpack Compose
- Each platform follows its native patterns and conventions for best UX

## Target Users
- Mid-level developers aiming for senior/staff/architect roles
- Developers preparing for technical interviews (FAANG, top-tier companies)
- Engineers wanting to communicate more precisely and professionally

## Tech Stack

### iOS
- **Language:** Swift 6.0 (strict concurrency enabled)
- **UI Framework:** SwiftUI
- **Data:** SwiftData
- **Notifications:** UserNotifications framework
- **Architecture:** MVVM
- **Minimum Target:** iOS 17, iPadOS 17
- **Bundle ID:** `com.stackspeak.ios`
- **App Display Name:** `StackSpeak`

### Android
- **Language:** Kotlin 2.0.x (K2 compiler)
- **UI Framework:** Jetpack Compose
- **Data:** Room Database
- **Notifications:** WorkManager + NotificationManager
- **Architecture:** MVVM (ViewModel + StateFlow)
- **Minimum SDK:** Android 8.0 (API 26)
- **Target SDK:** Latest stable
- **Android Gradle Plugin:** 8.x (latest stable)
- **Package Name:** `com.stackspeak`
- **App Display Name:** `StackSpeak`

## Project Structure

### Repository Layout
```
StackSpeak/
├── ios/                    # iOS app (Xcode project)
├── android/                # Android app (Android Studio project)
└── shared/
    └── words.json         # Shared word database (identical across platforms)
```

### Organization: Feature-First
Both platforms group code by feature, not by type. Each feature folder contains its View, ViewModel, and any feature-specific models. Shared infrastructure (core models, services, database) lives in separate folders.

### iOS Project Structure
```
ios/StackSpeak/
├── App/
│   └── StackSpeakApp.swift
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   ├── WordDetail/
│   │   ├── WordDetailView.swift
│   │   └── WordDetailViewModel.swift
│   ├── Practice/
│   │   ├── PracticeView.swift
│   │   └── PracticeViewModel.swift
│   └── Progress/
│       ├── ProgressView.swift
│       └── ProgressViewModel.swift
├── Models/
│   ├── Word.swift
│   ├── DailySet.swift
│   └── UserProgress.swift
├── Services/
│   ├── WordService.swift
│   ├── NotificationService.swift
│   └── ProgressService.swift
└── Resources/
    └── words.json         # Copy of shared/words.json
```

### Android Project Structure
```
android/app/src/main/java/com/stackspeak/
├── MainActivity.kt
├── StackSpeakApplication.kt
├── features/
│   ├── home/
│   │   ├── HomeScreen.kt
│   │   └── HomeViewModel.kt
│   ├── worddetail/
│   │   ├── WordDetailScreen.kt
│   │   └── WordDetailViewModel.kt
│   ├── practice/
│   │   ├── PracticeScreen.kt
│   │   └── PracticeViewModel.kt
│   └── progress/
│       ├── ProgressScreen.kt
│       └── ProgressViewModel.kt
├── data/
│   ├── model/
│   │   ├── Word.kt
│   │   ├── DailySet.kt
│   │   └── UserProgress.kt
│   ├── local/
│   │   ├── WordDatabase.kt
│   │   ├── WordDao.kt
│   │   └── UserProgressDao.kt
│   └── repository/
│       ├── WordRepository.kt
│       └── ProgressRepository.kt
└── service/
    └── NotificationService.kt

android/app/src/main/assets/
└── words.json             # Copy of shared/words.json
```

## Word Categories (Tech Domain Only — MVP)
- System design terminology (idempotent, eventual consistency, partitioning)
- Architecture patterns (abstraction leakage, Conway's Law, orthogonality)
- Engineering culture (bikeshedding, cargo culting, yak shaving)
- Interview vocabulary (heuristic, fungible, amortized, latency vs throughput)
- Leadership/product thinking (north star, toil, technical debt, observability)

## Core Features — MVP
1. **Daily Word Set** — 5 words per day from user's unlocked pool (see Word Rotation Algorithm)
2. **Word Detail Screen** — definition, pronunciation, real-world tech context
3. **Example Sentence** — how a senior engineer/architect would use it
4. **Practice Mode** — user writes their own sentence, must use the word (non-empty)
5. **Mark as Mastered** — user can mark a word "I know this" to exclude from future daily sets; reversible from Progress screen
6. **Daily Summary** — end-of-day review of all 5 words + user's sentences
7. **Streak Tracking** — days completed consecutively
8. **Level System** — user progresses through developer career levels, unlocking more words (see Level System)
9. **Daily Notification** — configurable reminder time
10. **Offline First** — all words bundled in app, no internet required for core flow

## Word Rotation Algorithm

**Personalized queue with mastered-word filtering:**
1. At first launch, generate a stable per-user seed (UUID stored in UserProgress).
2. Use the seed to deterministically shuffle the entire word bank into the user's personal queue.
3. Each day, pick the next 5 words from the queue, **skipping:**
   - Words the user has marked as Mastered
   - Words outside the user's currently unlocked level pool
4. Aim for mixed difficulty within each day (1 beginner / 3 intermediate / 1 advanced) *when available in the unlocked pool*. If the pool lacks variety (e.g., Level 1 has only beginner words), pick whatever is available.
5. When the unlocked queue is exhausted, reshuffle non-mastered unlocked words and restart.
6. If the user has mastered every available word, show: *"You've mastered StackSpeak! Check back for new words."*

**Determinism:** Given the same seed + same date + same UserProgress state, word selection is reproducible. This makes the algorithm testable.

## Level System

Users progress through developer career-title levels. Each level unlocks more words. Level progression is based on **both** words practiced and current streak (both conditions must be met to advance).

### Level Progression

| Level | Title | Unlock Condition | Approx Words Added |
|-------|-------|------------------|--------------------|
| 1 | Intern | Default (at install) | First 30 beginner words |
| 2 | Junior Developer | 20 words practiced + 3-day streak | +30 beginner/intermediate |
| 3 | Developer | 50 words practiced + 7-day streak | +40 intermediate |
| 4 | Senior Developer | 100 words practiced + 14-day streak | +40 intermediate |
| 5 | Staff Engineer | 175 words practiced + 21-day streak | +40 advanced |
| 6 | Principal Engineer | 275 words practiced + 30-day streak | +40 advanced |
| 7 | Architect | 400 words practiced + 45-day streak | +40 advanced |
| 8 | Distinguished Engineer | 550 words practiced + 60-day streak | All remaining words |

### Rules
- **"Words practiced"** = unique words the user wrote a sentence for (not just viewed). Mastered words count toward this total.
- **System is extensible** — future versions can add Level 9+ without breaking existing progress. Levels are defined in a single config array; code must not hardcode "8 levels."
- **Streak loss does NOT drop level** — if the user loses their streak, they keep their current level but cannot advance until streak is rebuilt to meet the next threshold.
- **Level-up UX** — show a simple modal: *"You're now a Senior Developer!"* with dismiss action. No heavy animation.
- **Locked words** — visible in a separate list with *"Reach Level N: [Title] to unlock"* message. Do not hide them entirely.
- **Current level display** — show prominently on Home screen header with progress bar to next level.

## Mastered Words

Users can mark any word as mastered from the Word Detail screen.

**Behavior:**
- Mastered words are excluded from future daily sets.
- Mastered words still count toward "words practiced" for level progression.
- Progress screen has a **Mastered Words** section listing all mastered words sorted by date mastered (newest first).
- User can **unmark** any mastered word from the Mastered Words list (reversible).
- If the user masters every word in their unlocked pool, show completion message: *"You've mastered StackSpeak! Check back for new words."*

## Word Bank Target

MVP target: **~300 curated words** across beginner/intermediate/advanced difficulties. Distribution roughly:
- Beginner: ~80 words
- Intermediate: ~140 words
- Advanced: ~80 words

## Data Migration (Future words.json Updates)

**Core rule: Words are append-only.** Content can be edited; IDs never change; words are never deleted.

### Adding New Words (app update ships updated words.json)
- New words are **appended to the end** of the user's existing queue — user finishes current queue first, then encounters new words.
- New words are shuffled deterministically using the user's seed combined with a version salt (e.g., seed + "v1.1"), so ordering is reproducible.
- Do not re-seed or re-shuffle the user's existing remaining queue — that would disrupt their upcoming-word experience.

### Editing Existing Words
- Silent update. Fixing a typo or improving a definition just takes effect on next view.
- No version tracking per word, no user-facing "updated" badge.

### Removing Words
- **Never remove** words from words.json once shipped. If a word turns out to be problematic, deprecate it in an internal field but keep the entry so existing UserProgress references remain valid.
- Word IDs are stable forever — once `"id": "abc-123"` ships, that UUID must remain valid.

### Implementation Notes
- On app launch, diff the bundled words.json against the user's known word IDs. Any new IDs are appended to the queue using the versioned shuffle.
- UserProgress references words by ID only — never by index, position, or content.

## Notification Flow

Notifications must feel helpful, not naggy. Request permission only after the user has experienced the app's value.

### Permission Request Flow
1. User completes their first practice session (all 5 words).
2. After the Daily Summary screen, show a modal:
   *"Want a daily reminder? Pick a time."*
   - Time picker (default suggestion: 9:00 AM)
   - "Set reminder" button → requests OS notification permission → schedules daily notification
   - "Not now" button → dismisses modal silently

### If User Denies Permission
- App continues normally; no reminders scheduled.
- Show a dismissible banner on the Home screen: *"Enable notifications to protect your streak."*
- Do not re-prompt via the OS permission dialog (iOS/Android will block repeat requests). Tapping the banner deep-links to the OS Settings page for the app.

### Notification Preferences (Settings Screen)
Users can adjust notifications anytime from the Settings screen:
- **Toggle On/Off** — enable or disable daily notifications entirely.
- **Primary Reminder Time** — change the time of the main daily reminder.
- **Optional Second Reminder** — user can add a second daily notification (e.g., evening recap at 8:00 PM). Off by default.
- Changes take effect immediately and reschedule pending notifications.

### Notification Content
- iOS categories: Alert + Badge + Sound.
- Android: standard priority notification channel.
- Copy should vary slightly to avoid feeling robotic (e.g., rotate between: *"5 new words are waiting."*, *"Keep your streak alive — today's words are ready."*, *"Time to level up your vocabulary."*).

### Detecting OS-Level Permission Changes
- On app foreground, check current notification authorization status.
- If the user previously enabled notifications but has since disabled them in OS Settings, show a banner offering to re-enable (deep-link to Settings).

### What If User Has Never Configured Notifications?
- Do not schedule anything until the user explicitly sets a time.
- Home screen banner prompts them to set up reminders if they've never done so.

## First-Launch Experience

### Onboarding (3 screens, skippable)
1. **Value prop:** *"5 technical words every day."*
2. **Active learning:** *"Practice by writing your own sentence."*
3. **Progression hook:** *"Level up from Intern to Architect."*

Each screen has a "Next" button and a persistent "Skip" option. After screen 3 (or skip), user lands on the Home screen with their first daily set ready.

### Initial UserProgress Initialization
On first launch, create a UserProgress record with:
- `userId`: freshly generated UUID (platform-native UUID generator)
- `level`: 1 (Intern)
- `streak`: 0 — the first day is earned, not given
- `wordsPracticedIds`: empty set
- `masteredWordIds`: empty set
- `installDate`: today (device local date)
- `notificationPreferences`: null (not yet configured)
- `shuffleSeed`: derived from `userId` — used for deterministic queue shuffle

### First-Day Behavior
- Streak is 0 until the user completes their first daily set.
- No notification is scheduled until the user explicitly configures one (see Notification Flow).
- All Level 1 (Intern) words are unlocked; higher-level words are visible in the locked list.

### No Profile for MVP
- Anonymous use — no name, avatar, or profile screen.
- Optional name field may be added post-MVP based on user feedback.

## Out of Scope for MVP
- User accounts or cloud sync
- Social features or sharing
- In-app purchases or subscriptions
- AI-generated sentence validation (keep it simple — just require non-empty input)
- Words outside the tech domain
- Cross-platform code sharing frameworks (keeping it native)

## Coding Rules

### Shared Principles (Both Platforms)
- Follow MVVM strictly — no business logic in Views/Composables
- Support both light and dark mode
- All strings that appear in UI must be localized (English only for MVP)
- One type per file, file name must match type name exactly
- No files longer than 300 lines — split if needed

### Dependency Policy
Only use libraries maintained by the platform owners (Apple, Google, JetBrains). No community or third-party libraries for MVP.

**iOS — Allowed:**
- Apple frameworks only (SwiftUI, SwiftData, Foundation, UserNotifications, etc.)
- No Swift Package Manager dependencies

**Android — Allowed:**
- AndroidX libraries (Room, Compose, WorkManager, etc.)
- Hilt (Google — for DI, ViewModels only)
- kotlinx.serialization (JetBrains — for JSON parsing)
- Kotlin Coroutines / Flow (JetBrains)
- Nothing else without explicit approval

### iOS Specific
- Use SwiftUI for ALL UI — no UIKit unless absolutely unavoidable
- All views must support both iPhone and iPad layouts
- Every model must be Codable
- Write preview providers for every View
- Use Swift concurrency (async/await) — no callbacks or completion handlers
- All strings in Localizable.strings
- Do not use @ObservedObject where @StateObject is correct

### Android Specific
- Use Jetpack Compose for ALL UI — no XML layouts
- All composables must support both phone and tablet layouts
- Every model must be serializable with kotlinx.serialization
- Write @Preview functions for every Composable
- Use Kotlin Coroutines and Flow — no callbacks
- All strings in strings.xml
- Use Hilt for dependency injection (minimal scope — ViewModels only)

## Testing Strategy

### Frameworks
- **iOS:** Swift Testing (not XCTest — we're starting fresh on iOS 17+)
- **Android:** JUnit 4 + Compose UI Testing + Turbine (for Flow testing — allowed as a JetBrains-adjacent library; add to Dependency Policy if needed)

### Scope
Test ViewModels and Services. Skip UI tests for MVP — rely on SwiftUI Previews and Compose @Preview for visual verification.

### Coverage Expectations
Qualitative: all critical paths and edge cases in Services and ViewModels must be tested. No mandatory % threshold, but these specific paths MUST have tests:
- Word rotation logic (same 5 words per day, no repeats within a cycle)
- Streak calculation (consecutive days, broken streaks, edge cases across timezone/date changes)
- Daily set completion (all 5 words practiced before marking set complete)
- UserProgress persistence (survives app relaunch)

### Test File Conventions
- iOS: `ios/StackSpeakTests/` — mirror the source structure (e.g., `Features/Home/HomeViewModelTests.swift`)
- Android: `android/app/src/test/java/com/stackspeak/` — mirror the source structure

## Design Guidelines

### Shared Design Principles
- Clean, minimal design — think Linear, Craft, or Bear app aesthetic
- Avoid heavy animations — subtle transitions only
- Tablet layouts should use extra space meaningfully (split view or wider cards)
- Follow platform-specific design languages (don't make iOS look like Android or vice versa)

### iOS
- Primary font: SF Pro (system default)
- Use native iOS components and navigation patterns
- Accessibility: support Dynamic Type and VoiceOver
- Follow Human Interface Guidelines

### Android
- Primary font: Roboto (system default)
- Use Material Design 3 components
- Accessibility: support font scaling and TalkBack
- Follow Material Design Guidelines

## Word Data Format (words.json)

### Schema
```json
{
  "words": [
    {
      "id": "3f1a7c9e-8b2d-4a5f-9c3e-1d8b4a7f6e2c",
      "word": "idempotent",
      "pronunciation": "eye-DEM-po-tent",
      "partOfSpeech": "adjective",
      "definition": "Describing an operation that produces the same result regardless of how many times it is performed.",
      "techContext": "Commonly used in API design and distributed systems discussions.",
      "exampleSentence": "We need to ensure this endpoint is idempotent so retries don't cause duplicate payments.",
      "category": "system-design",
      "difficulty": "intermediate",
      "tags": ["api", "distributed-systems", "interview"]
    }
  ]
}
```

### Field Rules

| Field | Type | Notes |
|-------|------|-------|
| `id` | string (UUID v4) | Stable forever — never change once shipped |
| `word` | string | The term itself, lowercase unless it's a proper noun |
| `pronunciation` | string | **Phonetic only**, hyphenated, uppercase for stressed syllable (e.g., `eye-DEM-po-tent`). Not IPA. |
| `partOfSpeech` | string | One of: `noun`, `verb`, `adjective`, `adverb`, `phrase` |
| `definition` | string | Clear, one-sentence definition. Avoid circular definitions. |
| `techContext` | string | 1-2 sentences on where/how a developer encounters this term in real work |
| `exampleSentence` | string | A natural-sounding sentence a senior engineer/architect would say in a meeting |
| `category` | enum | See allowed values below |
| `difficulty` | enum | `beginner`, `intermediate`, or `advanced` |
| `tags` | array of strings | Free-form tags for future filtering/search. Use lowercase with hyphens. |

### Allowed Category Values
- `system-design` — System design terminology (idempotent, eventual consistency, partitioning)
- `architecture` — Architecture patterns (abstraction leakage, Conway's Law, orthogonality)
- `engineering-culture` — Engineering culture (bikeshedding, cargo culting, yak shaving)
- `interview` — Interview vocabulary (heuristic, fungible, amortized, latency vs throughput)
- `leadership` — Leadership/product thinking (north star, toil, technical debt, observability)

Do not invent new categories. If a word doesn't fit, discuss before adding.

### Allowed Difficulty Values
- `beginner` — Terms most developers encounter within their first 1-2 years (e.g., `refactor`, `regression`, `boilerplate`)
- `intermediate` — Terms common in senior-level discussions and system design interviews (e.g., `idempotent`, `eventual consistency`, `backpressure`)
- `advanced` — Terms used in staff/principal/architect discussions (e.g., `Conway's Law`, `orthogonality`, `cardinality estimation`)

## What Claude Should NOT Do
- Do not modify anything outside this project folder
- Do not add libraries beyond those listed in the Dependency Policy section
- Do not create a backend or server
- Do not add analytics or tracking
- Do not generate placeholder/lorem ipsum content — use real tech words only
- Do not skip writing preview providers (@Preview for both platforms)
- Do not try to share code between iOS and Android (separate native apps)
- Do not create cross-platform abstractions or "common" modules

## Definition of Done

### iOS
A feature is complete when:
- Compiles without warnings
- Works on iPhone and iPad simulators in both light and dark mode
- Has SwiftUI preview providers with light and dark variants
- Follows MVVM — no business logic in Views
- New ViewModels and Services have unit tests per Testing Strategy
- All user-facing strings are in `Localizable.strings`
- Accessibility verified: Dynamic Type scales correctly; VoiceOver labels present for all interactive elements
- No orphaned TODO comments or commented-out code

### Android
A feature is complete when:
- Compiles without warnings or lint errors
- Works on phone and tablet emulators in both light and dark mode
- Has `@Preview` composables with light and dark variants
- Follows MVVM — no business logic in Composables
- New ViewModels and Services have unit tests per Testing Strategy
- All user-facing strings are in `strings.xml`
- Accessibility verified: font scaling works correctly; content descriptions present for all interactive elements
- No orphaned TODO comments or commented-out code

## Development Commands

### iOS
```bash
# Build (uses any available iOS Simulator)
xcodebuild -project ios/StackSpeak.xcodeproj -scheme StackSpeak -destination 'generic/platform=iOS Simulator'

# Run tests
xcodebuild test -project ios/StackSpeak.xcodeproj -scheme StackSpeak -destination 'generic/platform=iOS Simulator'

# Build for a specific simulator (substitute with the desired device name)
xcodebuild -project ios/StackSpeak.xcodeproj -scheme StackSpeak -destination 'platform=iOS Simulator,name=iPhone 17'

# List available simulators
xcrun simctl list devices available

# Open in Xcode
open ios/StackSpeak.xcodeproj
```

### Android
```bash
# Build
cd android && ./gradlew assembleDebug

# Run tests
cd android && ./gradlew test

# Run on emulator
cd android && ./gradlew installDebug

# Open in Android Studio
open -a "Android Studio" android/
```

## Data Synchronization

`shared/words.json` is the **single source of truth**. Never edit the copies in `ios/StackSpeak/Resources/` or `android/app/src/main/assets/` directly — they are regenerated from the source.

### Workflow
1. Edit `shared/words.json`.
2. Run `./scripts/sync-words.sh` to copy it to both platform locations.
3. Commit all three files together.

### Verifying Sync
Run `./scripts/check-words-sync.sh` to confirm all three files are identical. This is suitable for CI or a pre-commit hook. Exits non-zero if any file is out of sync.

### Repository Layout
```
StackSpeak/
├── scripts/
│   ├── sync-words.sh        # Copy shared → iOS + Android
│   └── check-words-sync.sh  # Verify all three match
├── shared/
│   └── words.json           # Source of truth
├── ios/StackSpeak/Resources/words.json    # Generated copy
└── android/app/src/main/assets/words.json # Generated copy
```
