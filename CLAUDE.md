# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# StackSpeak

## Project Overview
Native iOS vocabulary app for software developers and engineers.
Delivers 5 technical words daily to help developers communicate more
confidently in interviews, architecture discussions, and leadership contexts.

**MVP Scope:** iOS only (iPhone + iPad). Android is a **Phase 2 goal**, deferred until after iOS ships — see "Phase 2: Android" at the end of this document.

## Target Users
- Mid-level developers aiming for senior/staff/architect roles
- Developers preparing for technical interviews (FAANG, top-tier companies)
- Engineers wanting to communicate more precisely and professionally

## Tech Stack

- **Language:** Swift 6.0 (strict concurrency enabled)
- **UI Framework:** SwiftUI
- **Data:** SwiftData
- **Notifications:** UserNotifications framework
- **Speech:** Speech framework (for voice input on sentence practice)
- **Architecture:** MVVM
- **Minimum Target:** iOS 17, iPadOS 17
- **Bundle ID:** `com.stackspeak.ios`
- **App Display Name:** `StackSpeak`

## Project Structure

### Repository Layout
```
StackSpeak/
├── ios/                    # iOS app (Xcode project)
├── shared/
│   └── words.json         # Source-of-truth word database
└── scripts/
    ├── sync-words.sh
    └── check-words-sync.sh
```

### iOS Project Structure (Feature-First)
Code is organized by feature, not by type. Each feature folder contains its View, ViewModel, and any feature-specific helpers. Shared infrastructure (core models, services, design tokens) lives in separate folders.

```
ios/StackSpeak/
├── App/
│   └── StackSpeakApp.swift
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   └── WordCardView.swift
│   ├── WordDetail/
│   │   ├── WordDetailView.swift
│   │   └── WordDetailViewModel.swift
│   ├── Practice/
│   │   ├── SentencePracticeView.swift
│   │   └── SentencePracticeViewModel.swift
│   ├── Review/
│   │   ├── ReviewView.swift
│   │   ├── ReviewViewModel.swift
│   │   └── FlashcardView.swift
│   ├── Library/
│   │   ├── LibraryView.swift
│   │   └── LibraryViewModel.swift
│   └── Profile/
│       ├── ProfileView.swift
│       └── ProfileViewModel.swift
├── Models/
│   ├── Word.swift
│   ├── DailySet.swift
│   ├── UserProgress.swift
│   └── Level.swift
├── Services/
│   ├── WordService.swift
│   ├── NotificationService.swift
│   ├── ProgressService.swift
│   ├── SpeechService.swift
│   └── ReviewSchedulerService.swift
├── DesignSystem/
│   ├── Tokens.swift          # Colors, typography, spacing
│   ├── Theme.swift           # Light/dark theme selection
│   └── Components/           # Reusable UI primitives
└── Resources/
    ├── words.json            # Copy of shared/words.json
    └── Fonts/                # Inter, JetBrains Mono, Instrument Serif
```

## Core Features — MVP
1. **Onboarding** — 3-screen skippable intro; everyone starts at Level 1.
2. **Daily Word Set (Home / Today)** — 5 words per day as tap-to-expand cards with progress ring for the day's completion.
3. **Word Detail Screen** — full view: short + long definition, pronunciation, tech context, code example, etymology, example sentence.
4. **Sentence Practice** — user writes (or speaks via mic) their own sentence using the word. Non-empty + must contain the word.
5. **Mark as Mastered** — user excludes a word from future daily sets; reversible.
6. **Bookmark / Save** — user stars a word to keep a reference list; does *not* exclude it from daily sets.
7. **Review (Spaced Repetition)** — tap-to-flip flashcards for previously practiced words, scheduled by the SRS algorithm.
8. **Library / Search** — search past words with filters (category, difficulty, level, mastered, bookmarked).
9. **Profile (You)** — streak counter, activity overview, mastered list, bookmarked list, notification settings.
10. **Streak Tracking** — consecutive days of completed daily sets.
11. **Level System** — progression through developer career levels; unlocks more words.
12. **Daily Notification** — configurable reminder time with optional second reminder.
13. **UI Preferences** — toggle light/dark/system theme; toggle card density (compact/roomy).
14. **Offline First** — all words bundled; no network required for core flow.

## Navigation Structure

Tab bar with four tabs (bottom navigation):
1. **Today** — daily 5 cards (Home)
2. **Review** — spaced-repetition flashcards
3. **Library** — search past words
4. **You** — profile, streak, mastered/bookmarked, settings

**Non-tab screens:** Onboarding (first launch only), Word Detail (pushed from Today/Library/Review), Settings (pushed from You).

## Design System

Aesthetic: **60/40 Linear → Bear blend.** Cool-neutral grays for chrome, warm-cream accents in light mode, sharp mono for code/metadata, clean sans for UI, subtle serif italic for etymology. Single indigo-ink accent.

### Typography
Custom fonts are bundled in `Resources/Fonts/`:
- **Inter** (400/500/600/700) — UI text, headers, body
- **JetBrains Mono** (400/500/600) — code snippets, metadata tags, level badges, pronunciation
- **Instrument Serif Italic** — etymology, editorial accents

Fallbacks: `-apple-system`, `ui-monospace`, `Georgia` respectively. All custom fonts must be declared in `Info.plist` under `UIAppFonts`.

### Color Tokens

**Light theme:**
| Token | Value | Use |
|-------|-------|-----|
| `bg` | `#F6F5F2` | Root background (warm paper) |
| `surface` | `#FFFFFF` | Cards, sheets |
| `surfaceAlt` | `#FBFAF7` | Elevated secondary surfaces |
| `ink` | `#15161A` | Primary text |
| `inkMuted` | `#5B5E66` | Secondary text |
| `inkFaint` | `#9A9CA3` | Tertiary text, placeholders |
| `line` | `rgba(20,22,28,0.08)` | Hairline dividers |
| `lineStrong` | `rgba(20,22,28,0.14)` | Stronger dividers |
| `accent` | `#3E4BDB` | Primary accent (indigo ink) |
| `accentBg` | `rgba(62,75,219,0.08)` | Accent background fills |
| `codeBg` | `#F2F1EC` | Code block background |
| `codeInk` | `#15161A` | Code base text |
| `codeKey` | `#8B2F7A` | Code keywords (magenta) |
| `codeStr` | `#2F6F47` | Code strings (green) |
| `codeCom` | `#8A8A7F` | Code comments (olive-gray) |
| `codeNum` | `#B5651D` | Code numbers |
| `good` | `#2F6F47` | Success state |
| `warn` | `#B5651D` | Warning state |

**Dark theme:**
| Token | Value | Use |
|-------|-------|-----|
| `bg` | `#0B0C0E` | Root background (near-black cool) |
| `surface` | `#141519` | Cards, sheets |
| `surfaceAlt` | `#0F1013` | Elevated secondary surfaces |
| `ink` | `#F2F2F4` | Primary text |
| `inkMuted` | `#A4A7B0` | Secondary text |
| `inkFaint` | `#6B6E77` | Tertiary text, placeholders |
| `line` | `rgba(255,255,255,0.06)` | Hairline dividers |
| `lineStrong` | `rgba(255,255,255,0.12)` | Stronger dividers |
| `accent` | `#8B93FF` | Primary accent (lifted indigo) |
| `accentBg` | `rgba(139,147,255,0.12)` | Accent background fills |
| `codeBg` | `#0F1013` | Code block background |
| `codeInk` | `#E6E6EA` | Code base text |
| `codeKey` | `#D291E7` | Code keywords |
| `codeStr` | `#7FCF99` | Code strings |
| `codeCom` | `#6B6E77` | Code comments |
| `codeNum` | `#E0A878` | Code numbers |
| `good` | `#7FCF99` | Success state |
| `warn` | `#E0A878` | Warning state |

All color tokens must be declared in `DesignSystem/Tokens.swift` as a `Theme` value; views must never hardcode hex values.

### Card Density

User-toggleable setting in UI Preferences. Two modes:

| Metric | Compact | Roomy |
|--------|---------|-------|
| Card vertical padding | 16 | 22 |
| Card horizontal padding | 18 | 22 |
| Card gap | 10 | 14 |
| Row padding | 12 | 16 |
| Title size | 22 | 26 |

### Interactions
- **Home cards:** tap to expand in place (smooth reveal, Linear-style). Expanded card shows short definition + practice input + "I know this" pill + "Open" action.
- **Review flashcards:** tap to flip (front = word, back = definition + example).
- **Animations:** subtle, never distracting. No spring overshoot. No celebratory confetti (the level-up modal is the only fanfare).

### Shared Design Principles
- Clean, minimal — think Linear, Craft, Bear
- Support light and dark mode (user override or system default)
- iPad layout uses extra space meaningfully (wider cards, split-view detail)
- Accessibility: Dynamic Type, VoiceOver labels on all interactive elements
- Follow Human Interface Guidelines where they don't conflict with the custom design system

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
      "shortDefinition": "An operation that produces the same result no matter how many times it runs.",
      "longDefinition": "A property of certain operations where applying them multiple times has the same effect as applying them once. Critical for safe retries in distributed systems and HTTP methods like PUT and DELETE.",
      "techContext": "Commonly used in API design and distributed systems discussions.",
      "exampleSentence": "The retry logic is safe because the endpoint is idempotent.",
      "etymology": "from Latin idem (\"same\") + potent (\"power\") — coined 1870 in algebra.",
      "codeExample": {
        "language": "http",
        "code": "PUT /users/42\n{ \"name\": \"Ada\" }\n\n// Running this 1× or 100× → same final state."
      },
      "category": "system-design",
      "unlockLevel": 3,
      "tags": ["api", "distributed-systems", "interview"]
    }
  ]
}
```

### Field Rules

| Field | Type | Notes |
|-------|------|-------|
| `id` | string (UUID v4) | Stable forever — never change once shipped |
| `word` | string | The term itself, lowercase unless a proper noun or acronym |
| `pronunciation` | string | Phonetic only, hyphenated, uppercase stressed syllable (e.g., `eye-DEM-po-tent`). Not IPA. |
| `partOfSpeech` | string | `noun`, `verb`, `adjective`, `adverb`, `phrase`, `acronym` |
| `shortDefinition` | string | One-line definition — shown on Home cards, flashcard front-to-back, search results. |
| `longDefinition` | string | 1-2 sentence expanded definition — shown on Word Detail screen. |
| `techContext` | string | 1-2 sentences on where/how a developer encounters this term in real work. |
| `exampleSentence` | string | Natural-sounding sentence a senior engineer/architect would say in a meeting. |
| `etymology` | string | Brief origin note; rendered in Instrument Serif Italic. |
| `codeExample` | object | `{ language, code }` — `language` is a lowercase slug (`http`, `yaml`, `ts`, `hs`, `swift`, `sql`, `bash`, `py`, `go`, `rust`). |
| `category` | enum | See allowed values below |
| `unlockLevel` | integer (1–5) | Which user level must be reached to unlock this word. Ties directly to the Level System. |
| `tags` | array of strings | Free-form tags (lowercase-with-hyphens) for filtering/search. |

All fields are **required** for MVP. No optional fields — if a word doesn't have a good code example, it doesn't belong in the bank yet.

### Allowed Category Values
- `system-design` — System design terminology (idempotent, eventual consistency, partitioning)
- `architecture` — Architecture patterns (abstraction leakage, Conway's Law, orthogonality)
- `engineering-culture` — Engineering culture (bikeshedding, cargo culting, yak shaving)
- `interview` — Interview vocabulary (heuristic, fungible, amortized, latency vs throughput)
- `leadership` — Leadership/product thinking (north star, toil, technical debt, observability)

Do not invent new categories. If a word doesn't fit, discuss before adding.

### Word Level Display
Each word card displays its unlock level as `L<n> · <Career Title>` (e.g., `L3 · Developer`). The career title is derived from the Level System table — so the display automatically updates if level names ever change.

## Word Rotation Algorithm

**Personalized queue with mastered-word filtering:**
1. At first launch, generate a stable per-user seed (UUID stored in UserProgress).
2. Use the seed to deterministically shuffle the entire word bank into the user's personal queue.
3. Each day, pick the next 5 words from the queue, **skipping:**
   - Words the user has marked as Mastered
   - Words whose `unlockLevel` is above the user's current level
4. When the unlocked queue is exhausted, reshuffle non-mastered unlocked words and restart.
5. If the user has mastered every available word, show: *"You've mastered StackSpeak! Check back for new words."*

**Determinism:** Given the same seed + same date + same UserProgress state, word selection is reproducible. This makes the algorithm testable.

## Level System

Users progress through developer career-title levels. Each level unlocks more words. Level progression is based on **both** words practiced and current streak (both conditions must be met to advance).

### Level Progression

| Level | Title | Unlock Condition | Approx Words Added |
|-------|-------|------------------|--------------------|
| 1 | Intern | Default (at install) | First ~40 words |
| 2 | Junior Developer | 20 words practiced + 3-day streak | +60 words |
| 3 | Developer | 50 words practiced + 7-day streak | +80 words |
| 4 | Senior Developer | 120 words practiced + 14-day streak | +70 words |
| 5 | Staff Engineer | 220 words practiced + 21-day streak | Remaining ~50 words |

### Rules
- **"Words practiced"** = unique words the user wrote a sentence for (not just viewed). Mastered words count toward this total.
- **System is extensible** — future versions can add Level 6+ (e.g., Principal Engineer, Architect, Distinguished Engineer) without breaking existing progress. Levels are defined in a single config array; code must not hardcode "5 levels."
- **Streak loss does NOT drop level** — if the user loses their streak, they keep their current level but cannot advance until streak is rebuilt to meet the next threshold.
- **Level-up UX** — show a simple modal: *"You're now a Senior Developer!"* with dismiss action. No heavy animation.
- **Locked words** — visible in the Library (when filter "show locked" is on) with *"Reach Level N: [Title] to unlock"* message. Do not hide them entirely.
- **Current level display** — show prominently on Home screen header with progress bar to next level.

## Mastered Words

Users can mark any word as mastered from the Word Detail screen or the expanded Home card.

**Behavior:**
- Mastered words are excluded from future daily sets.
- Mastered words still count toward "words practiced" for level progression.
- Mastered words are still eligible for Review screen rotation (spaced repetition doesn't "forget" mastered words — they just aren't delivered daily).
- Profile screen has a **Mastered Words** section listing all mastered words sorted by date mastered (newest first).
- User can **unmark** any mastered word from the Mastered list (reversible).
- If the user masters every word in their unlocked pool, show completion message: *"You've mastered StackSpeak! Check back for new words."*

## Bookmarks (Saved Words)

Separate from Mastered. Users bookmark words they want to reference again.

**Behavior:**
- Bookmarked words do NOT affect daily word selection — they can still appear in today's set.
- Profile has a **Saved** section listing bookmarks (newest first).
- A word can be both bookmarked and mastered independently.
- Tap a star/bookmark icon on Word Detail or the expanded Home card to toggle.

## Review Screen (Spaced Repetition)

Flashcard-style review of previously practiced words. Tap to flip.

### Algorithm: SM-2 (SuperMemo 2)
Standard, well-tested SRS algorithm. Each word has:
- `easinessFactor` (default 2.5, min 1.3)
- `interval` (days until next review)
- `repetitions` (consecutive successful recalls)

On each review, user self-rates recall quality 0-5:
- 0-2 (fail): reset `repetitions` to 0, interval to 1 day
- 3-5 (pass): apply SM-2 formulas to update EF, interval, repetitions

### MVP Simplification
User sees two buttons only: **Again** (quality = 2) and **Got it** (quality = 4). No five-point self-rating — keep it frictionless. Under the hood, we use SM-2 with those two quality values.

### Review Queue
- Words become eligible for review after the user has practiced them once (written a sentence).
- Review screen shows due-today words first, then overdue words oldest-first.
- Review is optional — missing reviews doesn't break streaks.

### Persistence
Each practiced word has a `ReviewState` stored in SwiftData: `{ wordId, easinessFactor, interval, repetitions, dueDate, lastReviewedAt }`.

## Sentence Practice

Users prove engagement with a word by writing or speaking a sentence using it.

### Input Modes
1. **Type** — standard text field.
2. **Voice** — tap mic button, dictate sentence. Uses iOS `Speech` framework.

### Validation
- Non-empty after trim.
- Must contain the target word (case-insensitive, whole-word match — allow common inflections like plural `-s`, past tense `-ed`).
- No AI-based semantic validation for MVP.

### Voice Input
- Tap mic → request `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription` permission on first use.
- Show live transcription in the input field while recording.
- Pulse animation on mic button while listening.
- Tap mic again to stop and finalize.
- If permission denied, show a banner on the practice UI: *"Enable microphone access in Settings to speak your sentence."*

### What Gets Saved
On successful submission, store `{ wordId, sentence, createdAt, inputMethod }` in UserProgress. This powers the Daily Summary and unlocks the word for Review scheduling.

## UI Preferences

Settings screen (reachable from Profile → Settings):
- **Theme:** `system` (default), `light`, `dark`
- **Card Density:** `compact` or `roomy` (default)
- **Notifications:** see Notification Flow section

Preferences persist in UserProgress.

## Word Bank Target

MVP target: **~300 curated words** distributed across the 5 unlock levels (see Level Progression table for the per-level breakdown).

## Data Migration (Future words.json Updates)

**Core rule: Words are append-only.** Content can be edited; IDs never change; words are never deleted.

### Adding New Words (app update ships updated words.json)
- New words are **appended to the end** of the user's existing queue — user finishes current queue first, then encounters new words.
- New words are shuffled deterministically using the user's seed combined with a version salt (e.g., seed + "v1.1"), so ordering is reproducible.
- Do not re-seed or re-shuffle the user's existing remaining queue.

### Editing Existing Words
- Silent update. Fixing a typo or improving a definition just takes effect on next view.
- No version tracking per word, no user-facing "updated" badge.

### Removing Words
- **Never remove** words from words.json once shipped. Deprecate via an internal field if needed; keep the entry so existing UserProgress references remain valid.
- Word IDs are stable forever.

### Implementation Notes
- On app launch, diff the bundled words.json against the user's known word IDs. Any new IDs are appended using the versioned shuffle.
- UserProgress references words by ID only — never by index, position, or content.

## Notification Flow

Notifications must feel helpful, not naggy. Request permission only after the user has experienced the app's value.

### Permission Request Flow
1. User completes their first practice session (all 5 words).
2. After the Daily Summary screen, show a modal:
   *"Want a daily reminder? Pick a time."*
   - Time picker (default suggestion: 9:00 AM)
   - "Set reminder" → requests OS notification permission → schedules daily notification
   - "Not now" → dismisses silently

### If User Denies Permission
- App continues normally; no reminders scheduled.
- Show a dismissible banner on Home: *"Enable notifications to protect your streak."*
- Do not re-prompt via the OS permission dialog (iOS blocks repeat requests). Tapping the banner deep-links to the iOS Settings page for the app.

### Notification Preferences (Settings Screen)
- **Toggle On/Off** — enable or disable daily notifications entirely.
- **Primary Reminder Time** — change the time of the main daily reminder.
- **Optional Second Reminder** — add a second daily notification (e.g., evening recap at 8:00 PM). Off by default.
- Changes take effect immediately and reschedule pending notifications.

### Notification Content
- iOS categories: Alert + Badge + Sound.
- Copy should vary slightly to avoid feeling robotic (rotate: *"5 new words are waiting."*, *"Keep your streak alive — today's words are ready."*, *"Time to level up your vocabulary."*).

### Detecting OS-Level Permission Changes
- On app foreground, check current notification authorization status.
- If the user previously enabled notifications but has since disabled them in OS Settings, show a banner offering to re-enable (deep-link to Settings).

### What If User Has Never Configured Notifications?
- Do not schedule anything until the user explicitly sets a time.
- Home screen banner prompts them to set up reminders if they've never done so.

## First-Launch Experience

### Onboarding (3 screens, skippable)
1. **Value prop:** *"Five quiet words, every weekday."*
2. **Active learning:** *"Practice by writing — or speaking — your own sentence."*
3. **Progression hook:** *"Level up from Intern to Staff Engineer."*

Each screen has a "Next" button and a persistent "Skip" option. After screen 3 (or skip), user lands on the Home screen with their first daily set ready. No level quiz.

### Initial UserProgress Initialization
On first launch, create a UserProgress record with:
- `userId`: freshly generated UUID
- `level`: 1 (Intern)
- `streak`: 0
- `wordsPracticedIds`: empty set
- `masteredWordIds`: empty set
- `bookmarkedWordIds`: empty set
- `installDate`: today (device local date)
- `notificationPreferences`: null
- `uiPreferences`: `{ theme: "system", density: "roomy" }`
- `shuffleSeed`: derived from `userId`

### First-Day Behavior
- Streak is 0 until the user completes their first daily set.
- No notification scheduled until user explicitly configures one.
- All Level 1 (Intern) words are unlocked; higher-level words visible in Library with a lock badge.

### No Profile for MVP
- Anonymous use — no name, avatar, or profile screen.
- Optional name field may be added post-MVP.

## Out of Scope for MVP
- User accounts or cloud sync
- Social features or sharing
- In-app purchases or subscriptions
- AI-generated sentence validation (just non-empty + contains-word check)
- Words outside the tech domain
- Android version (Phase 2 goal)

## Coding Rules

### Core Principles
- Follow MVVM strictly — no business logic in Views.
- Support light and dark mode via Theme tokens, never hardcoded colors.
- All user-facing strings in `Localizable.strings` (English only for MVP).
- One type per file, file name must match type name exactly.
- No files longer than 300 lines — split if needed.

### Swift/SwiftUI Specific
- Use SwiftUI for ALL UI — no UIKit unless absolutely unavoidable (e.g., `SFSpeechRecognizer` bridging).
- All views must support both iPhone and iPad layouts.
- Every model must be `Codable`.
- Write preview providers for every View (light + dark variants, compact + roomy where relevant).
- Use Swift concurrency (`async/await`) — no callbacks or completion handlers.
- Do not use `@ObservedObject` where `@StateObject` is correct.

### Dependency Policy
Apple frameworks only. No Swift Package Manager dependencies for MVP.

**Allowed:**
- SwiftUI, SwiftData, Foundation, UserNotifications, Speech, Combine

**Not allowed:** Any third-party package, including Alamofire, SnapKit, Lottie, etc. If something feels like it needs a library, discuss first.

## Testing Strategy

### Framework
**Swift Testing** (not XCTest — starting fresh on iOS 17+).

### Scope
Test ViewModels and Services. Skip UI tests for MVP — rely on SwiftUI Previews for visual verification.

### Coverage Expectations
Qualitative: all critical paths and edge cases in Services and ViewModels must be tested. Specific paths that MUST have tests:
- Word rotation logic (same 5 words per day, no repeats within a cycle, mastered exclusion, locked exclusion)
- Streak calculation (consecutive days, broken streaks, timezone/date edge cases)
- Daily set completion (all 5 words practiced before marking set complete)
- Level progression (both thresholds met before advancing; streak break does not drop level)
- SRS scheduling (SM-2 formulas produce expected intervals)
- Sentence validation (contains-word with inflection handling)
- UserProgress persistence (survives app relaunch)

### Test File Conventions
`ios/StackSpeakTests/` mirrors the source structure (e.g., `Features/Home/HomeViewModelTests.swift`).

## Definition of Done

A feature is complete when:
- Compiles without warnings
- Works on iPhone and iPad simulators in light + dark mode, both density modes
- Has SwiftUI preview providers with light + dark variants
- Follows MVVM — no business logic in Views
- New ViewModels and Services have unit tests per Testing Strategy
- All user-facing strings in `Localizable.strings`
- Uses design tokens (no hardcoded colors, fonts, or spacing)
- Accessibility verified: Dynamic Type scales correctly; VoiceOver labels present on all interactive elements
- No orphaned TODO comments or commented-out code

## Development Commands

```bash
# Build (any available iOS Simulator)
xcodebuild -project ios/StackSpeak.xcodeproj -scheme StackSpeak -destination 'generic/platform=iOS Simulator'

# Run tests
xcodebuild test -project ios/StackSpeak.xcodeproj -scheme StackSpeak -destination 'generic/platform=iOS Simulator'

# Build for a specific simulator
xcodebuild -project ios/StackSpeak.xcodeproj -scheme StackSpeak -destination 'platform=iOS Simulator,name=iPhone 17'

# List available simulators
xcrun simctl list devices available

# Open in Xcode
open ios/StackSpeak.xcodeproj

# Sync words.json from shared/ to iOS bundle
./scripts/sync-words.sh

# Verify words.json is in sync
./scripts/check-words-sync.sh
```

## Data Synchronization

`shared/words.json` is the **single source of truth**. Never edit the copy in `ios/StackSpeak/Resources/words.json` directly — it is regenerated from the source.

### Workflow
1. Edit `shared/words.json`.
2. Run `./scripts/sync-words.sh` to copy it to the iOS bundle.
3. Commit both files together.

### Verifying Sync
Run `./scripts/check-words-sync.sh` to confirm the files are identical. Suitable for CI or a pre-commit hook.

## What Claude Should NOT Do
- Do not modify anything outside this project folder
- Do not add Swift Package Manager dependencies
- Do not create a backend or server
- Do not add analytics or tracking
- Do not generate placeholder/lorem ipsum content — use real tech words only
- Do not skip writing preview providers
- Do not hardcode colors, fonts, or spacing — always use design tokens
- Do not start Android work — it's deferred to Phase 2

---

## Phase 2: Android (Deferred)

Android is planned for after iOS ships. When we get there, the plan is **separate native app** (Kotlin + Jetpack Compose), not a cross-platform framework. Key parallels to iOS:
- Kotlin 2.0.x + Jetpack Compose + Room + Hilt + kotlinx.serialization
- Package: `com.stackspeak`
- Feature-first folder structure mirroring iOS
- Shared word database at `shared/words.json` (sync script already supports both)
- Same Level System, Word Rotation Algorithm, and SRS implementation
- Material Design 3 components + equivalent design tokens

Sync scripts in `scripts/` are already multi-platform aware — they will sync to Android paths when the `android/` directory exists.
