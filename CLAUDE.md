# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository. **Rules and conventions only** — product spec lives in `docs/PRD.md`, and code is authoritative for implementation details.

## Where to look

- **Product spec** (features, algorithms, level/stack system, notifications, onboarding, UX behavior) → `docs/PRD.md`
- **Design tokens** (colors, typography, spacing, density) → `ios/StackSpeak/DesignSystem/Tokens.swift`
- **Data models** (Word schema, UserProgress, DailySet, ReviewState, WordStack enum, Level definitions) → `ios/StackSpeak/Models/`
- **Services** (word rotation, progress, SRS scheduling, notifications, speech) → `ios/StackSpeak/Services/`
- **Word data** — source of truth is `shared/words-index.json` (master index) and `shared/stacks/*.json` (one file per stack); iOS bundle copy at `ios/StackSpeak/Resources/` is synced via `scripts/sync-words.sh`

If you need to know *what* a feature does, read the PRD. If you need to know *how* it's implemented, read the code. Do not duplicate either into this file.

## StackSpeak — one-liner

Native iOS vocabulary app for developers. Delivers 5 technical words daily. MVP: iOS only (iPhone + iPad). Android is Phase 2.

## Tech Stack

- **Language:** Swift 6.0 (strict concurrency enabled)
- **UI:** SwiftUI
- **Data:** SwiftData
- **Notifications:** UserNotifications
- **Speech:** Speech framework (voice input on sentence practice)
- **Architecture:** MVVM
- **Minimum Target:** iOS 18, iPadOS 18
- **Bundle ID:** `com.stackspeak.ios`
- **App Display Name:** `StackSpeak`

## Repository Layout

```
StackSpeak/
├── CLAUDE.md               # This file — rules for Claude
├── docs/
│   └── PRD.md              # Product spec
├── ios/
│   ├── project.yml         # XcodeGen config → generates StackSpeak.xcodeproj
│   ├── StackSpeak/         # iOS app source (feature-first, see below)
│   └── StackSpeakTests/    # Unit tests (Swift Testing)
├── shared/
│   ├── words-index.json    # Master index listing all stacks
│   └── stacks/             # One JSON file per stack (basic-web, backend, etc.)
└── scripts/
    ├── sync-words.sh
    ├── check-words-sync.sh
    └── download-fonts.sh
```

iOS source is organized **feature-first** under `ios/StackSpeak/Features/` (Onboarding, Home, WordDetail, Practice, Review, Library, Profile). Shared infrastructure lives in `Models/`, `Services/`, `DesignSystem/`, `Extensions/`, `Resources/`. Run `ls ios/StackSpeak/` to see the current tree.

## One-Time Setup (new clone)

```bash
brew install xcodegen
./scripts/download-fonts.sh       # Inter, JetBrains Mono, Instrument Serif
cd ios && xcodegen generate       # generates StackSpeak.xcodeproj
open StackSpeak.xcodeproj         # set Development Team in Signing & Capabilities
```

The generated `.xcodeproj` is git-ignored. Re-run `xcodegen generate` after pulling if project structure changes.

## Coding Rules

### Core Principles
- Follow MVVM strictly — no business logic in Views.
- Support light and dark mode via `theme.colors` tokens. **Never hardcode colors, fonts, or spacing.**
- All user-facing strings in `Localizable.strings` (English only for MVP).
- One type per file, file name must match type name exactly.
- No files longer than 300 lines — split if needed.

### Swift / SwiftUI
- SwiftUI for ALL UI — no UIKit unless absolutely unavoidable (e.g., `SFSpeechRecognizer` bridging).
- Every view must support both iPhone and iPad layouts.
- Every model must be `Codable`.
- Every view has preview providers with light + dark variants (compact + roomy where relevant).
- Use Swift concurrency (`async/await`) — no callbacks or completion handlers.
- Use `@Observable` (Swift 6 Observation framework) for ViewModels, not `ObservableObject`.
- Do not use `@ObservedObject` where `@StateObject` is correct.

### Dependencies
Apple frameworks only. **No Swift Package Manager dependencies.**

**Allowed:** SwiftUI, SwiftData, Foundation, UserNotifications, Speech, Combine.

**Not allowed:** Any third-party package (Alamofire, SnapKit, Lottie, etc.). If something feels like it needs a library, discuss first.

## Testing

- **Framework:** Swift Testing (not XCTest).
- **Scope:** ViewModels and Services. Skip UI tests for MVP — rely on SwiftUI Previews for visual verification.
- **Test files** live in `ios/StackSpeakTests/` mirroring the source structure (e.g., `Features/Home/HomeViewModelTests.swift`).

**Critical paths that MUST have tests:**
- Word rotation (deterministic shuffle, mastered/locked exclusion, stack filtering)
- Streak calculation (consecutive days, broken streaks, timezone/date edges)
- Daily set completion (all 5 words practiced before marking complete)
- Level progression (threshold met before advancing; streak break does not drop level)
- SRS scheduling (SM-2 formulas produce expected intervals)
- Sentence validation (whole-word match with inflection handling)
- UserProgress persistence (survives app relaunch)

## Definition of Done

A feature is complete when:
- Compiles without warnings
- Works on iPhone and iPad simulators in light + dark mode, both density modes
- Has SwiftUI preview providers with light + dark variants
- Follows MVVM — no business logic in Views
- New ViewModels and Services have unit tests per Testing rules above
- All user-facing strings in `Localizable.strings`
- Uses design tokens (no hardcoded colors, fonts, or spacing)
- Accessibility verified: Dynamic Type scales correctly; VoiceOver labels on all interactive elements
- No orphaned TODO comments or commented-out code

## Development Commands

```bash
# Generate Xcode project (run after adding/removing files)
cd ios && xcodegen generate && cd ..

# Build (any available iOS Simulator)
xcodebuild -project ios/StackSpeak/StackSpeak.xcodeproj -scheme StackSpeak -destination 'generic/platform=iOS Simulator'

# Run tests
xcodebuild test -project ios/StackSpeak/StackSpeak.xcodeproj -scheme StackSpeak -destination 'generic/platform=iOS Simulator'

# Build for a specific simulator
xcodebuild -project ios/StackSpeak/StackSpeak.xcodeproj -scheme StackSpeak -destination 'platform=iOS Simulator,name=iPhone 17'

# List available simulators
xcrun simctl list devices available

# Open in Xcode
open ios/StackSpeak/StackSpeak.xcodeproj

# Sync word data from shared/ to iOS bundle (index + stack files)
./scripts/sync-words.sh

# Verify word data is in sync
./scripts/check-words-sync.sh
```

## Data Synchronization

**Word data is split by stack to reduce token usage.** The source of truth lives in `shared/`:
- `shared/words-index.json` — master index listing all available stacks
- `shared/stacks/*.json` — one file per stack (e.g., `basic-web.json`, `backend.json`)

**Never edit files in `ios/StackSpeak/Resources/` directly** — they are synced from `shared/`.

**Workflow:**
1. Edit stack files in `shared/stacks/` or add new ones.
2. Update `shared/words-index.json` if adding/removing stacks.
3. Run `./scripts/sync-words.sh` to copy everything to the iOS bundle.
4. Commit both `shared/` and `ios/StackSpeak/Resources/` together.

Run `./scripts/check-words-sync.sh` to verify sync. Suitable for CI or a pre-commit hook.

**Why split by stack?**
- Only loads relevant words for active stacks (token efficiency)
- Easier to maintain (work on one domain at a time)
- Scales to 500+ words without bloating context

## Agent Task Routing

When delegating work to subagents, point them at the minimal context they need rather than dumping this file:

- **UI / theming tasks** → read `ios/StackSpeak/DesignSystem/Tokens.swift` and `Theme.swift`
- **Data model / schema tasks** → read `ios/StackSpeak/Models/`
- **Business logic (rotation, progression, SRS)** → read the relevant service in `ios/StackSpeak/Services/` + related section in `docs/PRD.md`
- **Feature behavior / product questions** → read `docs/PRD.md`
- **New feature work** → read `docs/PRD.md` for intent, then relevant files under `Features/` for patterns

## What Claude Should NOT Do

- Do not modify anything outside this project folder
- Do not add Swift Package Manager dependencies
- Do not create a backend or server
- Do not add analytics or tracking
- Do not generate placeholder / lorem ipsum content — use real tech words only
- Do not skip writing preview providers
- Do not hardcode colors, fonts, or spacing — always use design tokens
- Do not start Android work — it's deferred to Phase 2
- Do not duplicate product spec or implementation details into this file — link to `docs/PRD.md` or the relevant code
