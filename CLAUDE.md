# CLAUDE.md

Rules and conventions for Claude Code in this repo. The product spec (the *what*) lives in `docs/PRD.md`; the code is authoritative for *how*. Don't duplicate either here.

## Where to look

- **Product spec** (features, algorithms, level/stack system, notifications, onboarding, UX) → `docs/PRD.md`
- **Design tokens** (colors, typography, spacing, density) → `ios/StackSpeak/DesignSystem/Tokens.swift` + `Theme.swift`
- **Data models** (Word schema, UserProgress, DailySet, ReviewState, WordStack enum, Level definitions) → `ios/StackSpeak/Models/`
- **Services** (word rotation, progress, SRS, notifications, speech, sync) → `ios/StackSpeak/Services/`
- **Words** — source of truth is `shared/stacks/*.json` (one file per stack) + `shared/words-index.json`; bundle copy at `ios/StackSpeak/Resources/` is generated (see Content data).
- **Books / learning content** — authored in `content/books/`, compiled to `shared/books/` + `shared/books-catalog.json`; app code in `ios/StackSpeak/Features/Books/`.

## One-liner

Native iOS vocabulary app for developers. Delivers 5 technical words daily. MVP: iOS only (iPhone + iPad). Android is Phase 2.

## Tech Stack

- **Language:** Swift 6.0 (strict concurrency enabled)
- **UI:** SwiftUI · **Data:** SwiftData · **Architecture:** MVVM
- **Notifications:** UserNotifications · **Speech:** Speech framework (voice input via `SpeechService`) · **Purchases:** StoreKit
- **Minimum target:** iOS / iPadOS 18

## Repository Layout

Top-level only (run `ls ios/StackSpeak/` for the app tree — it's feature-first and drifts):

```
StackSpeak/
├── docs/PRD.md          # product spec (the "what")
├── ios/                 # XcodeGen project: project.yml → StackSpeak.xcodeproj (git-ignored)
│   └── StackSpeak/       # app source (Features/, Models/, Services/, DesignSystem/, App/, …)
├── shared/              # generated content the app bundles: stacks/, words-index.json, books/
├── content/books/       # book authoring source → compiled into shared/books/
├── supabase/migrations/ # SQL schema + RLS policies
└── scripts/             # content sync + lint tooling
```

## One-Time Setup (new clone)

```bash
brew install xcodegen
./scripts/download-fonts.sh       # Inter, JetBrains Mono, Instrument Serif
cd ios && xcodegen generate       # generates StackSpeak.xcodeproj (git-ignored)
open StackSpeak.xcodeproj          # set Development Team in Signing & Capabilities
```

Re-run `xcodegen generate` after pulling if project structure changes.

## Coding Rules

These are the canonical rules — the Definition of Done checks completion, it doesn't restate them.

### Core principles
- MVVM — no business logic in Views.
- Light + dark via `theme.colors` tokens; **never hardcode colors, fonts, or spacing.**
- User-facing strings in `Localizable.strings` (English only for MVP).
- One type per file, filename = type name. **Exception:** large SwiftUI views with shared `@State` split via `<TypeName>+<Concern>.swift` extensions (e.g. `FeynmanCardView+Stages.swift`); keep stored properties + `init` + `body` in the primary file.
- No file over 300 lines — split if needed.

### Swift / SwiftUI
- SwiftUI for all UI; UIKit only when unavoidable (e.g. `SFSpeechRecognizer` bridging).
- Every view supports iPhone + iPad and ships preview providers with light + dark variants (compact + roomy where relevant).
- Every model is `Codable` (content ships as JSON).
- `async/await` only — no completion handlers.
- `@Observable` (Observation framework) for ViewModels — not `ObservableObject`.

### Dependencies
Apple frameworks only — **no Swift Package Manager dependencies** (incl. the Supabase Swift SDK; see Backend & Sync). Allowed: SwiftUI, SwiftData, Foundation, UserNotifications, Speech, StoreKit. If something feels like it needs a library, discuss first.

### Backend & Sync (Supabase)
Cross-platform progress sync (iPhone ↔ iPad ↔ Android) uses **Supabase** over its **REST API** (PostgREST + GoTrue Auth) with plain **`URLSession`** — *not* the Supabase Swift SDK (it's SPM). No other backend, and never a custom server.

- **All backend access goes behind the `BackendService` protocol.** Only `SupabaseBackendService` (the one production conformer; `NoOpBackendService` is the null object) knows it's Supabase — never call vendor endpoints from ViewModels/services/views. Switching backends = one new conformer.
- The synced record is a **platform-neutral `ProgressSnapshot`** (compact, versioned JSON blob, one row per user) so iOS and Android serialize the *identical* shape. Entitlement fields (`isPro`/`proExpiryDate`/`isLifetimePro`) are **not** synced — each device derives Pro from its own store.
- **Tiering:** within-ecosystem backup is free; **cross-platform sync is Pro-gated** (`isProActive`) and is the only path that touches the backend. Sync runs only once a real account is linked (Apple/email).
- **No anonymous sessions.** A backend session is created *only* on a real sign-in (Apple/email). There is no anonymous bootstrap — `ensureSession` resumes a stored session or throws `.notAuthenticated`. (An anonymous user could never sync — it's account-linked + Pro-gated — and would just litter the DB.) "Allow anonymous sign-ins" is **disabled** in the Supabase project; keep it off, and don't reintroduce anonymous sign-in on either platform.
- **Login is optional — never a startup wall.** The app is fully usable signed-out (local-only); sign-in is offered in Profile, not required (a mandatory login risks App Store rejection under 5.1.1). Identity (login) and entitlement (Pro) are independent: show sign-in regardless of Pro, gate *syncing* on Pro.
- `DailySet` (today's 5-word set + completion) is **per-day and intentionally NOT synced** — it regenerates each day/device, so "0/5" after a restore is expected, not data loss.
- **Secrets:** the anon/publishable key + project URL may ship in the client (safe only because Row Level Security restricts each user to their own row); they load from a **git-ignored config**, never hardcoded. The service_role key and DB password never touch the app, repo, or any commit.
- SQL schema + RLS policies live in `supabase/migrations/`.

## Content data (words & books)

Two pipelines feed the iOS bundle. **Never edit `ios/StackSpeak/Resources/` directly** — it's generated. Commit `shared/` + `Resources/` together.

- **Words** — edit `shared/stacks/*.json` (source of truth, named `<domain>-<tier>`, e.g. `api-basic.json`, `gcp-basic.json`) and `shared/words-index.json`, then `./scripts/sync-words.sh`. Stacks are split per-file for token efficiency.
- **Books** — author in `content/books/` (custom `@chapter`/`@card`/`@explanation`/`@feynman` format), compile with `node scripts/build-books.js` → `shared/books/` + `shared/books-catalog.json`, then `./scripts/sync-books.sh`.

## Testing

- **Framework:** Swift Testing (not XCTest). Tests live in `ios/StackSpeakTests/` mirroring source (e.g. `Features/Home/HomeViewModelTests.swift`).
- **Scope:** ViewModels and Services. Skip UI tests for MVP — rely on SwiftUI Previews.
- **Critical paths that MUST have tests:** word rotation (deterministic shuffle, mastered/locked exclusion, stack filtering); streak calculation (consecutive/broken streaks, timezone edges); daily-set completion (all 5 practiced before complete); level progression (threshold before advancing; streak break doesn't drop level); SRS scheduling (SM-2 intervals); UserProgress persistence (survives relaunch).

## Definition of Done

Beyond the Coding Rules above, a feature is done when:
- Compiles without warnings; verified on iPhone + iPad simulators, light + dark, both density modes.
- New ViewModels/Services have unit tests (see Testing).
- Accessibility: Dynamic Type scales correctly; VoiceOver labels on all interactive elements.
- No orphaned TODOs or commented-out code.
- Word-data changes pass `scripts/check-words-content.py` — no stubs, no index drift, no unintended cross-stack duplicate terms, and a `shortDefinition` never contains its own term (it's the multiple-choice quiz answer).

## Development Commands

```bash
# Generate Xcode project (after adding/removing files)
cd ios && xcodegen generate && cd ..

# Build (any available simulator)
xcodebuild -project ios/StackSpeak.xcodeproj -scheme StackSpeak -destination 'generic/platform=iOS Simulator'

# Compile-check fast (no booted simulator — useful headless/CI)
xcodebuild build-for-testing -project ios/StackSpeak.xcodeproj -scheme StackSpeak -destination 'generic/platform=iOS Simulator' -quiet

# Run tests
xcodebuild test -project ios/StackSpeak.xcodeproj -scheme StackSpeak -destination 'generic/platform=iOS Simulator'

# Sync content to the iOS bundle (after editing shared/ or content/books/)
./scripts/sync-words.sh
node scripts/build-books.js && ./scripts/sync-books.sh

# Verify sync + lint content
./scripts/check-words-sync.sh
./scripts/check-books-sync.sh
python3 scripts/check-words-content.py
```

## Workflow Conventions

- **Git cadence:** batch pushes after ~5 file-changing commits, not per-fix. Commit/push only when asked; if on `main`, branch first.
- **Feature branches:** major multi-commit work lands on a feature branch, merged with `--no-ff`. Open a PR when ready; if a branch is *stacked* on another open PR, merge the base PR first so the new PR diffs cleanly against `main`.
- **Planning docs:** plans, roadmaps, review write-ups go in `.planning/` as dated files (e.g. `feature-x-2026-06-13.md`). `.planning/` is **git-ignored** (local scratch) — durable cross-session state also belongs in auto-memory.
- **Confirm scope before building:** a screenshot or hint is not approval — confirm placement/scope first.
- **Verify before claiming done:** compile with `build-for-testing`; cross-file SourceKit "cannot find type" errors are usually a missing build index, not real — trust a clean build over the editor.
- **Delegating to subagents:** point them at the minimal context they need (the relevant file/dir + the related `docs/PRD.md` section), not this whole file.

## What Claude should NOT do

- Modify anything outside this project folder.
- Add analytics or tracking.
- Generate placeholder / lorem-ipsum content — real tech words only.

(No SPM deps, no custom server, no committed secrets, design tokens over hardcoding, always write previews, and "don't duplicate PRD/code here" are covered by the rules above.)
