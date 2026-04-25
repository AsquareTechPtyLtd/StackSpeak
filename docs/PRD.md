# StackSpeak — Product Requirements

Product spec for StackSpeak. Describes intent, features, and behavior — not implementation. For architectural rules and code conventions, see `CLAUDE.md`. For authoritative implementation details, read the code in `ios/StackSpeak/`.

---

## Overview

Native iOS vocabulary app for software developers and engineers. Delivers 5 technical words daily to help developers communicate more confidently in interviews, architecture discussions, and leadership contexts.

**MVP scope:** iOS only (iPhone + iPad). Android is Phase 2.

## Target Users

- Mid-level developers aiming for senior/staff/architect roles
- Developers preparing for technical interviews (FAANG, top-tier companies)
- Engineers wanting to communicate more precisely and professionally

## Core Features — MVP

1. **Onboarding** — 3-screen skippable intro + stack selection; everyone starts at Level 1 with 4 mandatory stacks.
2. **Feynman Card Experience (Home / Today)** — 5 words per day as a horizontal swipeable card deck. Each card walks the user through staged reveals (plain-English definition → technical depth → their own explanation → everyday analogy as a takeaway). Explaining the word in their own words — typed or spoken — is what marks the card complete.
3. **Word Detail Screen** — full view: short + long definition, pronunciation, tech context, code example, etymology, example sentence. Reachable from Library and Review; the Feynman card on Today already surfaces this content inline.
4. **Self-Explanation (inside the Feynman card)** — the user types or speaks their own explanation of the word. Stored verbatim; no validation against the target word, no AI scoring. Submission makes the word eligible for assessment and completes the daily card.
5. **Assessment Quiz** — multiple-choice quiz in Review tab. Each word needs 2 correct answers to count toward level progression. 24-hour cooldown on wrong attempts.
6. **Review Flashcards** — tap-to-flip SRS flashcards for previously practiced words, scheduled by SM-2 algorithm. Optional for retention.
7. **Mark as Mastered** — user excludes a word from future daily sets; reversible. Separate from assessment progression.
8. **Bookmark / Save** — user stars a word to keep a reference list; does *not* exclude it from daily sets.
9. **Library / Search** — search past words with filters (stack, level, mastered, bookmarked).
10. **Profile (You)** — streak counter, level progress (percentage-based), assessed words count, mastered list, bookmarked list, stack management, notification settings.
11. **Streak Tracking** — consecutive days of completed daily sets. For engagement only; doesn't affect level progression.
12. **Level System** — assessment-based progression through 5 developer career levels (Intern → Staff Engineer). Each level unlocks new stacks (28 total).
13. **Stack Personalization** — 14 mandatory + 14 optional stacks. Users choose specializations at each level.
14. **Daily Notification** — configurable reminder time with optional second reminder.
15. **UI Preferences** — toggle light/dark/system theme; toggle card density (compact/roomy).
16. **Offline First** — all words bundled; no network required for core flow.

## Navigation

Tab bar with four tabs:
1. **Today** — daily 5 cards (Home)
2. **Review** — assessment quizzes + spaced-repetition flashcards
3. **Library** — search past words
4. **You** — profile, streak, mastered/bookmarked, settings

**Non-tab screens:** Onboarding (first launch only), Word Detail (pushed from Today/Library/Review), Settings (pushed from You).

## Design Philosophy

Aesthetic: **60/40 Linear → Bear blend.** Cool-neutral grays for chrome, warm-cream accents in light mode, sharp mono for code/metadata, clean sans for UI, subtle serif italic for etymology. Single indigo-ink accent.

**Typography:**
- **Inter** (400/500/600/700) — UI text, headers, body
- **JetBrains Mono** (400/500/600) — code snippets, metadata tags, level badges, pronunciation
- **Instrument Serif Italic** — etymology, editorial accents

All custom fonts must be declared in `Info.plist` under `UIAppFonts`. Fallbacks: `-apple-system`, `ui-monospace`, `Georgia`.

**Interactions:**
- **Home (Feynman) cards:** one card per word. Tap-to-advance through staged reveals inside a card; horizontal swipe to move between cards. Progress dots at the top of the deck show which card you're on; a filled dot means that word is already practiced.
- **Review flashcards:** tap to flip (front = word, back = definition + example).
- **Animations:** subtle, never distracting. No spring overshoot. No celebratory confetti (the level-up modal is the only fanfare).

**Shared Principles:**
- Clean, minimal — think Linear, Craft, Bear
- Support light and dark mode (user override or system default)
- iPad layout uses extra space meaningfully (wider cards, split-view detail)
- Accessibility: Dynamic Type, VoiceOver labels on all interactive elements
- Follow Human Interface Guidelines where they don't conflict with the custom design system

**Card Density** — user-toggleable setting with two modes (`compact` / `roomy`). Specific padding/sizing values are implemented in `DesignSystem/Tokens.swift`.

**Color tokens** — see `DesignSystem/Tokens.swift` for the full light/dark palette. Views must use `theme.colors` — never hardcoded hex.

## Word Data

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
      "simpleDefinition": "Something you can do over and over and the outcome is the same — like pressing the ground-floor button in an elevator that's already on the ground floor.",
      "longDefinition": "A property of certain operations where applying them multiple times has the same effect as applying them once. Critical for safe retries in distributed systems and HTTP methods like PUT and DELETE.",
      "techContext": "Commonly used in API design and distributed systems discussions.",
      "exampleSentence": "The retry logic is safe because the endpoint is idempotent.",
      "etymology": "from Latin idem (\"same\") + potent (\"power\") — coined 1870 in algebra.",
      "connector": "Think of idempotent like a light switch that's only labelled 'off' — flicking it ten times leaves the room just as dark as flicking it once.",
      "codeExample": {
        "language": "http",
        "code": "PUT /users/42\n{ \"name\": \"Ada\" }\n\n// Running this 1× or 100× → same final state."
      },
      "stack": "basic-system-design",
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
| `shortDefinition` | string | One-line definition — shown on flashcard front-to-back and search results. |
| `simpleDefinition` | string | Plain-English definition aimed at someone with no CS background. Avoid jargon. Shown on the Feynman card's first content reveal. |
| `longDefinition` | string | 1-2 sentence expanded definition — shown on Word Detail screen and on the Feynman card's technical reveal. |
| `techContext` | string | 1-2 sentences on where/how a developer encounters this term in real work. |
| `exampleSentence` | string | Natural-sounding sentence a senior engineer/architect would say in a meeting. |
| `etymology` | string | Brief origin note; rendered in Instrument Serif Italic. |
| `connector` | string | Everyday analogy that anchors the term to something the user already knows. Convention: *"Think of X like Y — …"*. Shown on the Feynman card's final reveal (after the user has explained it) so it sticks as a takeaway. |
| `codeExample` | object | `{ language, code }` — `language` is a lowercase slug (`http`, `yaml`, `ts`, `hs`, `swift`, `sql`, `bash`, `py`, `go`, `rust`). |
| `stack` | enum | One of the stacks defined in `Models/WordStack.swift`. |
| `unlockLevel` | integer (1–5) | Which user level must be reached to unlock this word. |
| `tags` | array of strings | Free-form tags (lowercase-with-hyphens) for filtering/search. |

All fields are **required** for MVP. No optional fields — if a word doesn't have a good code example, it doesn't belong in the bank yet.

**Backfill exception (temporary):** `simpleDefinition` and `connector` were introduced with the Feynman card. The fields default to `""` in the model so existing installs don't crash, and words that haven't been backfilled render a "coming soon" state on the Feynman card. These are required on all new and edited words going forward; all shipped words must be populated before the Feynman flow becomes the only path to day completion.

### Word Bank Target

MVP target: **~300 curated words** distributed across the 5 unlock levels.

### Data Migration (Future words.json Updates)

**Core rule: Words are append-only.** Content can be edited; IDs never change; words are never deleted.

- **Adding new words:** appended to the end of the user's existing queue. Shuffled deterministically using seed + version salt. Do not re-seed or re-shuffle the user's remaining queue.
- **Editing existing words:** silent update. No version tracking per word, no user-facing "updated" badge.
- **Removing words:** **never remove** once shipped. Deprecate via internal field if needed; keep entry so existing UserProgress references remain valid.
- **ID references:** UserProgress references words by ID only — never by index, position, or content.

## Stack System

Words are organized into **stacks** — focused learning paths that unlock progressively as users level up from Intern to Staff Engineer. Stacks mirror real career progression: beginners start with fundamentals, seniors master advanced topics.

Canonical stack list and level mappings live in `Models/WordStack.swift`. The sections below describe *behavior*; the code is authoritative for specific enum values, minimum levels, and mandatory/optional flags.

### Level-Based Stack Progression (overview)

Each level unlocks new mandatory and optional stacks. Mandatory stacks auto-add to the user's learning path; optional stacks can be selected for specialization.

- **Level 1: Intern** — 4 mandatory + 2 optional (fundamentals: programming, web, code quality, engineering culture)
- **Level 2: Junior Developer** — adds networking, version control, testing
- **Level 3: Developer** — adds architecture, system design, performance, plus advanced frontend/backend/mobile/security as optional
- **Level 4: Senior Developer** — adds advanced system design, advanced networking, interview prep
- **Level 5: Staff Engineer** — adds leadership, architecture-at-scale, plus ML/security-architecture/data-platform as optional

**Do not invent new stacks.** If a word doesn't fit existing stacks, discuss before adding.

### User Experience

**Onboarding:**
- User sees only Level 1 stacks (4 mandatory pre-checked + 2 optional toggleable)
- Simpler, less overwhelming than showing all 28 stacks upfront
- Prompt: *"Core stacks are essential fundamentals. Add optional stacks to specialize your learning."*

**Level-Up Modal:**
- Triggered when user advances to next level
- Shows newly unlocked mandatory stacks (auto-added, marked with checkmark)
- Shows newly unlocked optional stacks (user can select/deselect)
- Example: *"You're now a Developer! New stacks: Architecture, Basic System Design, Performance (core) + Advanced Frontend, Mobile, Security (optional)"*

**Stack Management (Profile → Manage Stacks):**
- Shows all mandatory stacks for current level (locked, cannot disable)
- Shows all optional stacks up to current level (user can toggle)
- Future-level stacks remain hidden until unlocked
- Changes persist immediately

### Word Level Display

Each word card displays its unlock level as `L<n> · <Career Title>` (e.g., `L3 · Developer`). The career title is derived from the Level System — so the display automatically updates if level names ever change.

## Word Rotation Algorithm

**Personalized queue with mastered-word filtering:**

1. At first launch, generate a stable per-user seed (UUID stored in UserProgress).
2. Use the seed to deterministically shuffle the entire word bank into the user's personal queue.
3. Each day, pick the next 5 words from the queue, **skipping:**
   - Words the user has marked as Mastered
   - Words whose `unlockLevel` is above the user's current level
   - Words whose `stack` is not in the user's `selectedStacks`
4. When the unlocked queue is exhausted, reshuffle non-mastered unlocked words and restart.
5. If the user has mastered every available word, show: *"You've mastered StackSpeak! Check back for new words."*

**Determinism:** Given the same seed + same date + same UserProgress state, word selection is reproducible. This makes the algorithm testable.

## Level System

Users progress through developer career-title levels by **mastering vocabulary through assessments**. Each level unlocks more words and stacks. Level progression is based on **words assessed correctly twice** — not time-based or streak-based.

### Level Progression

| Level | Title | Words Required (2× Correct Each) | Progression |
|-------|-------|-----------------------------------|-------------|
| 1 | Intern | 0 | Default at install |
| 2 | Junior Developer | 20 | Practice → Assess → Master 20 words |
| 3 | Developer | 50 | Total 50 words mastered |
| 4 | Senior Developer | 120 | Total 120 words mastered |
| 5 | Staff Engineer | 220 | Total 220 words mastered |

### Rules

- **"Words assessed correctly twice"** = words the user has answered correctly in the assessment quiz at least twice. This ensures mastery, not just exposure.
- **Progression is mastery-based** — users must prove knowledge via multiple-choice quiz, not just practice by writing sentences.
- **Streak is for engagement only** — daily streak motivates consistency but does NOT affect level progression.
- **System is extensible** — future versions can add Level 6+ (e.g., Principal Engineer, Architect, Distinguished Engineer) without breaking existing progress.
- **Level-up triggers after assessment** — when user reaches the threshold, a celebration modal appears showing newly unlocked stacks.
- **Locked words** — visible in the Library (when filter "show locked" is on) with *"Reach Level N: [Title] to unlock"* message.
- **Progress display** — shows percentage + words remaining (e.g., "67% • 10 words to level up").

## Assessment System

Users advance through levels by passing **multiple-choice quizzes** for practiced words. Each word must be answered correctly **at least twice** before it counts toward level progression.

### Assessment Flow

1. **Practice First** — user writes/speaks a sentence using the word (Today tab)
2. **Word Becomes Eligible** — practiced word unlocks for assessment
3. **Take Quiz** — Review tab → Assessment section
4. **Multiple Choice** — select the correct definition from 4 options
5. **Immediate Feedback** — green checkmark (correct) or red X (wrong)
6. **Track Progress** — shows X/2 correct attempts per word
7. **Count Toward Level** — 2 correct answers = word counts toward next level

### Quiz Format

- **Question:** "What does this word mean?"
- **Display:** word + pronunciation
- **Options:** 4 definitions (1 correct + 3 distractors from other words)
- **Feedback:** immediate visual (green/red) + explanation

### Retry Logic

- **Correct answer:** can attempt again immediately to get 2/2
- **Wrong answer:** 24-hour cooldown before retry (prevents spam)
- **No point deduction:** wrong answers don't hurt progress, just don't help

### Assessment Eligibility

Words become eligible for assessment when:
- User has practiced the word (written a sentence)
- AND word has <2 correct assessments
- AND 24 hours have passed since last wrong attempt (if applicable)

Eligible words appear in **Review tab → Assessment section**.

### Progression Tracking

**User Progress Display:**
- Home header: progress bar + "67% • 10 words to level up"
- Profile stats: "Assessed Correctly (2×): 35"
- Shows exact percentage, not abstract points

**Per-Word Tracking:**
- Each word shows "X/2 correct" during assessment
- AssessmentResult model stores: wordId, attemptedAt, isCorrect, selectedAnswer, correctAnswer
- UserProgress.wordsAssessedCorrectlyTwice counts words at 2/2 threshold

## Mastered Words (User-Marked)

Separate from assessment-based progression. Users can manually mark words as "mastered" to skip them in daily rotation.

**Behavior:**
- Mastered words are excluded from future daily sets.
- Mastered words do NOT automatically count toward level progression (must still pass assessment).
- Mastered words are still eligible for Review → Flashcards (spaced repetition).
- Profile screen has a **Mastered Words** section listing user-marked mastered words.
- User can **unmark** any mastered word from the Mastered list (reversible).
- "I know this" button on expanded Home card marks word as mastered.

## Bookmarks (Saved Words)

Separate from Mastered. Users bookmark words they want to reference again.

**Behavior:**
- Bookmarked words do NOT affect daily word selection — they can still appear in today's set.
- Profile has a **Saved** section listing bookmarks (newest first).
- A word can be both bookmarked and mastered independently.
- Tap a star/bookmark icon on Word Detail or the expanded Home card to toggle.

## Review Tab (Dual-Mode)

The Review tab has **two modes**: Assessment (for leveling up) and Flashcards (for long-term retention). Users switch between modes via tab selector at the top of the Review screen.

### Assessment Mode (Primary for Level Progression)

**Purpose:** Quiz-based assessment to prove mastery and advance levels. See the Assessment System section.

**UI:**
- Multiple-choice quiz
- Shows "X of Y" progress at top
- Shows "X/2 correct" per word
- Immediate feedback on submit
- Level up triggers modal when threshold reached

### Flashcards Mode (Spaced Repetition for Retention)

**Purpose:** Long-term retention via SRS algorithm. Optional, doesn't affect level progression.

**Algorithm: SM-2 (SuperMemo 2).** Each word has:
- `easinessFactor` (default 2.5, min 1.3)
- `interval` (days until next review)
- `repetitions` (consecutive successful recalls)

**Interaction:**
- Tap to flip card (front = word, back = definition + example)
- Two buttons: **Again** (quality = 2) and **Got it** (quality = 4)
- SM-2 formulas update interval based on performance

**Review Queue:**
- Words become eligible after being practiced once
- Shows due-today words first, then overdue words oldest-first
- Review is optional — missing reviews doesn't break streaks or affect level

**Persistence:** Each practiced word has a `ReviewState` stored in SwiftData: `{ wordId, easinessFactor, interval, repetitions, dueDate, lastReviewedAt }`.

## Feynman Card Experience

The Feynman card is the core Home/Today interaction. It replaces the older expanding-card + separate sentence-practice screen. One card per daily word; each card walks through staged reveals and culminates in the user explaining the word in their own words.

### Deck Structure

- Horizontal swipe between the 5 daily cards. Swipe respects already-completed cards (user can revisit, sees their own prior explanation).
- Progress dots at the top of the deck (5 dots, one per card). A filled dot = word practiced for the day. Tapping a dot jumps to that card.
- Header above the dots shows current level + streak, same information density as before (moved from the old HomeView header).
- When all 5 dots are filled the deck collapses to an "all done for today" state; streak and level progression have already been updated at that point.

### Card Stages (in order)

1. **Word.** The term, pronunciation, and level badge. Tap / "Next" advances.
2. **Simple definition.** `simpleDefinition` — plain English, no jargon. Tap advances.
3. **Technical depth.** `longDefinition` + `techContext` + `codeExample` + `exampleSentence` + `etymology`. The full picture — the user reads this before attempting to explain. Tap "I'm ready to explain" advances.
4. **Explain.** A prompt ("Now explain it in your own words") with a type/mic input area. The user must submit non-empty text to advance. No validation of content — any submission is accepted. Mic input uses the same `SpeechService` flow as the old sentence-practice screen (on-device, live transcript, permission request on first tap).
5. **Connector.** `connector` — everyday analogy shown *after* the user has wrestled with the word themselves. Serves as a memorable takeaway rather than a learning scaffold. Tap "Finish card" advances.
6. **Done.** Summary: the user's own explanation echoed back, plus "I know this" and "Report" actions (same semantics as the old word card).

Ordering rationale: the flow follows the real Feynman technique — learn (simple + technical), teach (explain), then anchor the memory (connector). The connector is deliberately placed *after* the explanation attempt so it reinforces the concept the user just articulated rather than priming them with the answer.

Stages within a card are local state — swiping away resets the visual to the first stage, but the submitted explanation is persisted and on return the card opens directly at **Done** with the explanation shown.

### What Marks a Card Complete

Submitting a non-empty explanation on the **Explain** stage. This is what mutates persistent state:

- Appends a `PracticedSentence { wordId, sentence: <explanation>, createdAt, inputMethod }` to `UserProgress`.
- Inserts `wordId` into `wordsPracticedIds`.
- Creates a `ReviewState` for the word if none exists (enters SRS).
- Marks the word completed in today's `DailySet`.
- If `DailySet.isComplete` afterwards, triggers the existing `completeDailySet` streak/level pipeline.

The flow is identical to the retired sentence-practice flow at the data layer — only the UI entry point changed.

### Coming-Soon Fallback

A card whose word has empty `simpleDefinition` **or** empty `connector` renders a shortened flow:

- The Simple stage swaps its usual content for a **Coming soon** panel showing `shortDefinition` and copy along the lines of *"We're still writing the simple explanation for this word — tap to mark as practiced."* The Technical stage still renders normally since those fields remain populated.
- The Connector stage is skipped entirely (nothing to show). Explain leads directly to Done.
- The Explain stage still appears but the submit button is optional; the user can also tap "Mark practiced" to complete the card without recording an explanation. This path still calls `markWordPracticed` (with an empty sentence, which `ProgressService` treats as "no sentence stored") so the day is still completable.
- Rationale: until all stacks are backfilled, users with un-backfilled stacks must not be blocked from day completion or streak continuation.

### Input Modes (Explain Stage)

- **Type** — standard text field. 500-char cap (same as old practice screen).
- **Voice** — tap mic button, dictate explanation. Uses iOS `Speech` framework via the existing `SpeechService`.
  - Request `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription` on first tap.
  - Live transcript populates the text field while recording.
  - Pulse animation on mic button while listening.
  - Tap mic again (or speech framework detects silence) to stop and finalize.
  - If permission denied, a banner on the card reads: *"Enable microphone access in Settings to speak your explanation."* Typing still works.

Unlike the retired sentence-practice flow, the explanation is **not** validated to contain the target word — the whole point is to explain in the user's own words.

### Integration with Existing Progression

- **Review:** explanation submission is the event that makes a word eligible for assessment. `wordsEligibleForAssessment()` is unchanged (uses `wordsPracticedIds`).
- **Library:** unchanged — still populated from `wordsPracticedIds`.
- **Streak/Level:** unchanged — triggered via `ProgressService.completeDailySet` when all 5 dots are filled.
- **Notifications:** first-practice notification prompt still fires after the first submitted explanation of the install's life.

### Out of Scope (Feynman card)

- No evaluation or scoring of the user's explanation (no keyword match, no LLM, no backend).
- No editing of a submitted explanation (re-practicing the same word appends a second `PracticedSentence` row rather than replacing).
- No sharing or export of explanations.

## UI Preferences

Settings screen (reachable from Profile → Settings):
- **Theme:** `system` (default), `light`, `dark`
- **Card Density:** `compact` or `roomy` (default)
- **Notifications:** see Notification Flow

Preferences persist in UserProgress.

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

### Onboarding (3 screens + stack selection, skippable)

1. **Value prop:** *"Five quiet words, every weekday."*
2. **Active learning:** *"Practice by writing — or speaking — your own sentence."*
3. **Progression hook:** *"Level up from Intern to Staff Engineer."*
4. **Stack selection:** User chooses which optional stacks to add (core stacks pre-selected and locked)

Each screen has a "Next" button and a persistent "Skip" option. After screen 3 (or skip), user sees the stack selection screen. After confirming stack choices, user lands on the Home screen with their first daily set ready. No level quiz.

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
- `selectedStacks`: set containing all mandatory stacks (user customizes during onboarding)
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

## Phase 2: Android (Deferred)

Android is planned for after iOS ships. Plan is **separate native app** (Kotlin + Jetpack Compose), not a cross-platform framework. Key parallels to iOS:
- Kotlin 2.0.x + Jetpack Compose + Room + Hilt + kotlinx.serialization
- Package: `com.stackspeak`
- Feature-first folder structure mirroring iOS
- Shared word database at `shared/words.json` (sync script already supports both)
- Same Level System, Word Rotation Algorithm, and SRS implementation
- Material Design 3 components + equivalent design tokens

Sync scripts in `scripts/` are already multi-platform aware — they will sync to Android paths when the `android/` directory exists.
