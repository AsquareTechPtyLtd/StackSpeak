# UI/UX Implementation Log

Tracks every change made against `UI-UX-findings.md`. Branch: `feynman-card-experience`. Started 2026-04-25.

Build verified after every functional batch via `xcodegen generate` + `xcodebuild ... build` against the iOS 18 simulator.

---

## Phase 0 — Setup

### iOS minimum bumped 17 → 18
**Files:** `ios/project.yml` (×3 deployment targets), `CLAUDE.md`. Baseline build green. Note discovered later: `.navigationSubtitle` is iOS **26+**, not iOS 18 — the audit mis-cited the version. WR1's intended subtitle was replaced with an inline subheadline below the nav title.

---

## Phase 1 — Foundations

### F3 — Tighter radius scale
Added `RadiusTokens` enum (`inline=8`, `card=12`, `pill=999`). Existing call sites migrated as the screens were rewritten. **Files:** `DesignSystem/Tokens.swift`.

### F5 — Adaptive `accentText`
Dark mode `accentText` now `#0B0C0E` (the bg color) instead of `.white`, since the lighter dark-mode accent (`#8B93FF`) is borderline against pure white. **Files:** `DesignSystem/Tokens.swift`.

### FL3 — `bad` semantic color
Added `bad` (`#C0392B` light / `#FF6B6B` dark) for "Again" on flashcards and incorrect feedback. **Files:** `DesignSystem/Tokens.swift`.

### T6 — Streak warm color
Added `streak` token (`#E08A1E` light / `#F2A65A` dark) so the flame stays warm. The previous indigo flame was semantically off. **Files:** `DesignSystem/Tokens.swift`.

### F10 — Density preference removed
Per-feature density was a preference most users never touched. Replaced `cardPadding(density:)`, `rowPadding(density:)`, `cardGap(density:)`, and `cardTitle(density:)` with single tuned defaults. Removed `DensityPreference` enum, the `densityPreference` SwiftData field, `DensitySettingsView`, all density localized strings, and the density nav row in Profile. **Files:** `DesignSystem/Tokens.swift`, `DesignSystem/Theme.swift`, `Models/UserProgress.swift`, `Features/Profile/DensitySettingsView.swift` (deleted), `Features/Profile/ProfileView.swift`, `App/StackSpeakApp.swift`, `Resources/Localizable.strings`, plus rolling call-site fixes via `sed`.

**Deviation note:** This is a `@Model` schema change that wipes the SwiftData store on next launch (per the existing migration handler). Acceptable on this pre-launch branch.

### Motion tokens
Added `MotionTokens.standard` / `.snappy` / `.bounce` so animations across the app share a single language. **Files:** `DesignSystem/Tokens.swift`.

### F9 — Shared component primitives
Three new files:
- `DesignSystem/PrimaryCTAButton.swift` — replaces ~6 hand-rolled accent-button variants. Carries `isLoading` for spinner state.
- `DesignSystem/SelectableRow.swift` — picker / multiselect / nav row used by Theme settings, Word Report reasons, and (where it fits) Stack Management. Single selection signal: `accentBg` fill + 1.5pt accent border. No triple-stacked icon-plus-border-plus-fill.
- `DesignSystem/MetaCaption.swift` — the "L3 · Junior Band 1" pattern unified.

### CC3 — Empty-state primitive
`DesignSystem/EmptyStateView.swift`. Used by Library, Review, and Today's all-mastered state. Optional `actionTitle` / `action` so empty states can launch users toward useful next steps.

### F4 — Sentence-case section labels
Strings updated: feynman stage labels, wordDetail sections, level-up titles, onboarding stack sections, stack management sections, word-report title. Style: `.font(.subheadline.weight(.medium))` + `.foregroundColor(.inkMuted)`. The previous `textCase(.uppercase) + tracking(0.5)` is gone. **Files:** `Resources/Localizable.strings`, `Features/WordDetail/WordDetailView.swift` (`SectionHeader`), all consumers.

### F2 — Hairline borders, no shadow
`FeynmanCardView` and `FlashcardView` no longer drop an 8% black shadow. Both now use a 0.5pt `theme.colors.line` overlay on the card surface.

### F8 — Cross-fade for stage transitions
`FeynmanCardView`: removed `rotation3DEffect`, `flipRotation` `@State`, and the chained `DispatchQueue.main.asyncAfter` 90° flips. Stages now swap via `.transition(.opacity.combined(with: .offset))` with `.id(stage)` driving identity changes. Reduce-motion users get instant swaps.

`FlashcardView`: removed the 3-D rotation + `scaleEffect(x: -1, y: 1)` mirror hack. Front/back swap via opacity with a subtle 1° tilt.

### F6 — Haptics
- `.sensoryFeedback(.selection, trigger: advanceTrigger)` on Feynman advance.
- `.sensoryFeedback(.success / .error)` on assessment submit.
- `.sensoryFeedback(.success, trigger: hasAppeared)` on level-up appear.
- `.sensoryFeedback(.impact(weight: .light))` on flashcard flip and CTA loading state.

### F7 — Symbol effects
- Streak flame: `.symbolEffect(.bounce, value: progress.displayedCurrentStreak)` in HomeView and Profile streak cells.
- Level-up star: `.symbolEffect(.bounce.up.byLayer, value: hasAppeared)`.
- Done-stage seal in Feynman card: `.symbolEffect(.bounce, value: stage)`.
- Mic recording: `.symbolEffect(.pulse, isActive: isRecording)`.

### F11 — Reduced `accentBg` usage
Removed accent-tinted backgrounds from: stage indicator chip (the chip is gone), partOfSpeech chip in WordDetail (chip removed), mic button idle state, REQUIRED badge styling. Kept on: notification banner, info banner in Stack Management, selected `SelectableRow` / `StackCard` state, optional drilling rows.

### F12 — `cornerRadius` → `clipShape(.rect(cornerRadius:))`
All call sites migrated. The deprecated `cornerRadius(_:)` is gone from the codebase. **Files:** every refactored screen.

---

## Phase 2 — Per-screen P0 + P1

### Today (HomeView)
- **T1** — header card collapsed to a single quiet status line: `Intern Band 2 · 🔥 day 7`. Three-element bordered card removed.
- **T2** — five-capsule progress dots replaced with `2 / 5 today` mono caption + native page indicator (the deck's `.tabViewStyle(.page(indexDisplayMode: .always))` provides the dots).
- **T6** — flame uses `theme.colors.streak` (warm) and bounces on streak-value changes.
- All-mastered empty state now uses `EmptyStateView`.
- Notification banner uses `clipShape(.rect)` and the new RadiusTokens.

### Feynman card (FeynmanCardView)
- **T3** — header reduced to word + pronunciation only. Per-card level meta (`L1 · Intern Band 1`) removed; CC2 ensures it lives only in the Today status line and Profile.
- **T3** — stage counter chip replaced with a 2pt hairline progress bar at the top of the card body.
- **T4** — Skip / Report-and-skip / Open Detail consolidated into a single `Menu` triggered by `ellipsis.circle` in the card header. The word stage now has exactly one primary CTA.
- **F2** — surface shadow → 0.5pt hairline.
- **F8** — 3-D rotation flip → cross-fade.
- **FC1** — `TextEditor` placeholder via `ZStack` overlay with `Text("Try: a way to remember it…").allowsHitTesting(false)`.
- **FC2** — mic button now visually distinct: idle = outlined `mic` on `surfaceAlt`; recording = filled `mic.fill` on red `bad` background, white tint, pulsing.
- **F4** — `stageLabel(_:)` swapped to subheadline-medium muted, no uppercase.
- **F6/F7** — selection haptic on advance, symbol bounce on done-stage seal.
- **CC5** — `accessibilityReduceMotion` short-circuits all transitions.

### Word Detail (WordDetailView)
- **WD1** — five stacked cards → single typography-led reader. Sections separated by whitespace + small `SectionHeader` labels. Code block keeps a hairline-bordered surface; example sentence uses `instrumentSerif` for a pull-quote feel.
- **WD2** — twin bookmark/master toolbar buttons → single `ellipsis.circle` `Menu` with both actions plus their inverse states. Status indicators (`bookmark.fill`, `checkmark.seal.fill`) appear inline next to the pronunciation when active.
- **F11** — partOfSpeech chip replaced by `MetaCaption(level:secondary:)`.
- Tech context now indented behind a 2pt accent line — quote-block feel without a card.
- **F4** — section labels sentence-case.

### Word Report (WordReportSheet)
- **WR1** — duplicate word-info card removed. The word goes in the nav title; the short definition goes in a small subheadline at the top of the form.
- **WR2** — `ReasonButton` deleted; reasons use the shared `SelectableRow` with multiselect role.
- **F4** — sentence-case title.
- Notes editor gets a placeholder via `ZStack` overlay (same pattern as Feynman).
- Submit button is now `PrimaryCTAButton` with a built-in loading state.

**Deviation:** The audit suggested using `.navigationSubtitle`. iOS 18 doesn't ship that — it's iOS 26+. Used a small subheadline below the form title instead. Logged in Phase 0.

### Review (ReviewView)
- **R1** — custom `TabButton` deleted. Native `Picker(.segmented)` lives in `.toolbar(.principal)`.
- **R2** — surface-tinted stats card-bar → quiet mono caption above each deck.
- **R3** — empty states use `EmptyStateView`. (Action launcher TODO — see "Items deferred" below.)
- All review animations honor `MotionTokens.standard`.

### Assessment (AssessmentView)
- **A1** — "What does this word mean?" prompt removed.
- **A2** — `OptionButton` reduced to two signals (background fill + border). Filled-circle selection icon and check/x icons are gone; correctness color carries the message.
- **A3** — correct answers auto-advance after 900ms via `Task.sleep`. Incorrect answers stay on screen with a Continue CTA so the user can read the right answer at their pace.
- **A4** — `.sensoryFeedback` `.success`/`.error` on submit.
- **F11** — selected idle state uses `accentBg` fill (small accent budget); correct uses `good.opacity(0.10)`; incorrect uses `bad.opacity(0.10)`.

### Flashcard (FlashcardView)
- **FL1** — "Tap to flip" hint hidden after first ever flip via `@AppStorage("hasFlippedFlashcard")`.
- **FL2** — 3-D rotation removed. Front/back swap via opacity transition; subtle 1° tilt during the swap so it still feels physical.
- **FL3** — "Again" uses the new `bad` color (red), "Got it" stays `good` (green). Honest negative signal for self-grading.
- **F2** — hairline border replaces shadow.
- **F6** — light impact haptic on flip.

### Library (LibraryView)
- **L1** — `LazyVStack` of cards → `List(.insetGrouped)` with `scrollContentBackground(.hidden)` to keep the cream bg.
- **L2** — leading swipe toggles mastered, trailing swipe toggles bookmark.
- **L3** — horizontal-scroll filter chip strip → `Menu` in the toolbar with checkmark indicators. Active filter shows a removable row at the top of the list.
- **L4** — nav title "Library" (was "My Words").
- Empty states use `EmptyStateView` with a separate state for "no matches found".

### Profile (ProfileView)
- **P1** — six full-width cards → native `Form` with grouped sections (Level, Streak, Stats, Collection, Settings).
- **P2** — Mastered / Bookmarked are now real `NavigationLink`s into a new `WordListView` that shows the actual matching words. They were count-only ornament rows before.
- **P3** — level *description* removed; just the level title plus the progress bar.
- Streak cells use `.symbolEffect(.bounce, value: streak)` and `.contentTransition(.numericText())`.

### Stack Management (StackManagementView) + Stack Selection (onboarding)
- **SM1** — optional stacks grouped by category (Foundations / Intermediate / Advanced) derived from id prefix (`basic-` / `intermediate-` / `advanced-`). New `Models/StackCategory.swift`.
- **SM2** — `StackUnlockCard` deleted; `StackCard` is the single source. Used by Stack Selection (onboarding), Stack Management, and the Level-Up optional picker.
- **SM3** — onboarding pre-selects three popular optionals (`basic-api-design`, `basic-testing`, `basic-system-design`) so new users don't have to choose with no information.

### Theme Settings (ThemeSettingsView) + Density Settings (deleted)
- **TS1** — full-width radio cards → `Form` with `Section` and inline check rows. Density settings file removed entirely (F10).

### Notification Settings (NotificationSettingsView)
- **NS1** — three nested cards → native `Form` with `Section`s and `Toggle` + `DatePicker` directly. Permission-denied banner pinned above the form.

### Onboarding (OnboardingView)
- **O1** — system page-indicator dots replaced with a hairline 3-segment progress bar at the top of the screen.
- **CC1** — added a 4th onboarding page: a non-interactive sample Feynman card teaser. Tap to step through `word → plain → technical` stages so new users see the product before reading about it. Hard-coded "Idempotent" sample so we don't depend on catalog being loaded.
- Primary button uses `PrimaryCTAButton`.

### Level-Up (LevelUpView)
- **LU1** — celebration and stack-picker split into two beats. The first sheet is purely celebratory (bouncing star + level title + description + Continue). If new optional stacks unlocked, Continue triggers a second `LevelUpStackPickerSheet`. Admin never contaminates the celebration.
- **LU2** — `.sensoryFeedback(.success)` + `.symbolEffect(.bounce.up.byLayer)` on appear. Confetti deferred (Canvas particle work; logged below).
- The mandatory-stacks section is now a single line ("X new core stack(s) added") instead of a list — they're auto-added regardless.

---

## Phase 3 — Cross-cutting

### CC1 — Sample Feynman card on onboarding
See Onboarding entry above.

### CC2 — Single level + streak status line
Achieved by removing the per-card meta from `FeynmanCardView` (T3), removing the redundant level/streak header card from HomeView (T1), and centralizing the level/progress detail in Profile (P1). The streak/level appear in exactly one place each.

### CC3 — Global empty-state component
`EmptyStateView` used by Library, Review (assessment + flashcard empty/done-for-today states), Today (all-mastered), and the new `WordListView` for empty mastered/bookmarked.

### CC4 — `NavigationSplitView` on iPad
Used the iOS 18-native `TabView` with `Tab { ... }` initializers and `.tabViewStyle(.sidebarAdaptable)`. Same code on iPhone (tab bar) and iPad (sidebar) without per-platform branches.

### CC5 — Reduce-motion compliance
`@Environment(\.accessibilityReduceMotion)` consulted in `FeynmanCardView`, `FlashcardView`, and `AssessmentView` to skip animations. Cross-fade transitions degrade to instant.

---

## Phase 4 — P2 + delight

### F12 — `cornerRadius` migration
All `cornerRadius(_:)` calls migrated to `clipShape(.rect(cornerRadius:))`. Only one remaining was the error view's small inline mono block.

### Already covered in Phase 2:
- **FL1** — Tap-to-flip hint (in Flashcard entry)
- **L4** — Library title rename (in Library entry)
- **P3** — Level description removal (in Profile entry)
- **SM2** — StackCard merge (in Stack Management entry)
- **WR1** — Word-info card removal (in Word Report entry)
- **O1** — Onboarding hairline progress (in Onboarding entry)
- **D1** — Streak heartbeat (`.contentTransition(.numericText())` + bounce) — landed in Profile + Home
- **D3** — Pull-quote in Word Detail (`exampleBlock` uses `etymologyLarge` serif)
- **D4** — Etymology serif italic flourish (already styled with `etymology` font)
- **D6** — Symbol effects on numeric transitions (Profile stats use `.contentTransition(.numericText())`)

---

## Items deferred

These were P2 or marked low-priority; deferring keeps the scope honest.

- **FC3 — Persist explanation across stage navigation.** Verified at runtime: existing SwiftUI `@State` already persists `explanation` while the `FeynmanCardView` instance lives. No code change needed.
- **O2 — Custom onboarding illustrations.** Marked L effort, requires asset creation. Out of scope for this audit pass.
- **LU2 (confetti) — `Canvas` confetti burst.** Skipped; the bouncing star + success haptic + level-up sheet sequence already lands the moment. Confetti would be additive but not load-bearing.
- **D2 — End-of-day summary card.** Product-level addition (new screen + share image). Defer to a separate ticket.
- **D5 — First-time bookmark inline toast.** Needs UX design pass for toast placement. Deferred.
- **D7 — Long-press a Library row to speak the word.** Adds a new affordance with discoverability concerns. Deferred.
- **D8 — iPad hover preview on Library.** Depended on the dedicated NavigationSplitView design — current `.sidebarAdaptable` covers most of the value. Deferred.
- **R3 (action launchers in empty states).** `EmptyStateView` accepts `actionTitle`/`action` but Library/Review don't currently pass them. Easy follow-up; left as a one-line improvement.

---

## New issues discovered & fixed

1. **`.navigationSubtitle` is iOS 26+, not iOS 18+.** The audit cited the wrong version. Used a small subheadline above the form content as the audit's stated fallback. WordReportSheet only.
2. **`SelectableRow` default `@ViewBuilder` parameters generated a Swift 7 warning.** Refactored to use explicit overload extensions for the `Leading == EmptyView` and `Trailing == EmptyView` cases.
3. **Pre-existing test failures** (six in `LevelDefinitionTests`, `SentenceValidationTests`, `UserProgressTests`) — these reference an older 5-level model and a removed sentence-validation utility from before the Feynman card refactor on this branch. Unrelated to UI work; flagged as a separate cleanup task.

---

## Build status

`xcodegen generate` + `xcodebuild ... build` against `generic/platform=iOS Simulator`, Debug, iOS 18 deployment target: ✅ green at end of Phase 4.

`xcodebuild build-for-testing`: ✅ green.

`xcodebuild test`: 51/57 pass; the 6 failing tests are pre-existing and unrelated to this audit pass.
