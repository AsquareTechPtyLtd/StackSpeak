# StackSpeak — UI/UX Findings

_Audit date: 2026-04-25 · Audited branch: `feynman-card-experience` · Source of truth: `ios/StackSpeak/`_

This is a deep-read audit of every screen, modal, sheet, and state in the StackSpeak iOS app, evaluated against contemporary native-iOS taste (2025–2026). The aim is not to "modernize" cosmetically but to make every pixel earn its place — a quieter, tighter, more confident interface that lets the words be the thing the user notices.

The audit is structured in four phases: **Discovery → Critique → Recommendations → Vision**, ending with a single prioritized backlog you can convert into tickets.

---

## Phase 1 — Discovery

### 1.1 Screen inventory

| # | Screen / surface | File | Type |
|---|---|---|---|
| 1 | App-launch loader | `StackSpeakApp.swift` | Loading state |
| 2 | DB-init failure screen | `StackSpeakApp.swift` (`ErrorView`) | Error state |
| 3 | Onboarding pages (×3) | `OnboardingView.swift` | Full screen, paged |
| 4 | Stack selection (post-onboarding) | `StackSelectionView.swift` | Full screen |
| 5 | Today (Home) — header + dots + deck | `HomeView.swift` | Tab root |
| 5a | Notification banner (denied) | `HomeView.swift` | Inline banner |
| 5b | Notification permission alert | `HomeView.swift` | System alert |
| 5c | All-mastered empty state | `HomeView.swift` | Empty state |
| 5d | Feynman card — `word` stage | `FeynmanCardView.swift` | Stage |
| 5e | Feynman card — `simple` stage | `FeynmanCardView.swift` | Stage |
| 5f | Feynman card — `technical` stage | `FeynmanCardView.swift` | Stage |
| 5g | Feynman card — `explain` stage | `FeynmanCardView.swift` | Stage |
| 5h | Feynman card — `connector` stage | `FeynmanCardView.swift` | Stage |
| 5i | Feynman card — `done` stage | `FeynmanCardView.swift` | Stage |
| 5j | Feynman card — coming-soon body | `FeynmanCardView.swift` | Variant |
| 6 | Word Report sheet | `WordReportSheet.swift` | Sheet |
| 7 | Word Detail | `WordDetailView.swift` | Sheet (from Today) / push (from Library) |
| 8 | Level-Up sheet | `LevelUpView.swift` | Sheet |
| 9 | Review — sub-tabs (Assessment / Flashcards) | `ReviewView.swift` | Tab root |
| 9a | Assessment empty state | `ReviewView.swift` | Empty state |
| 9b | Assessment "done for today" | `ReviewView.swift` | Empty state |
| 9c | Assessment card | `AssessmentView.swift` | Card |
| 9d | Assessment feedback (correct / incorrect) | `AssessmentView.swift` | Card variant |
| 9e | Flashcards empty state | `ReviewView.swift` | Empty state |
| 9f | Flashcard front | `FlashcardView.swift` | Card |
| 9g | Flashcard back + actions | `FlashcardView.swift` | Card variant |
| 10 | Library | `LibraryView.swift` | Tab root |
| 10a | Library empty state | `LibraryView.swift` | Empty state |
| 11 | Profile (You) | `ProfileView.swift` | Tab root |
| 12 | Stack Management | `StackManagementView.swift` | Pushed from Profile |
| 13 | Notification Settings | `NotificationSettingsView.swift` | Pushed from Profile |
| 13a | Permission-denied banner | `NotificationSettingsView.swift` | Inline banner |
| 14 | Theme Settings | `ThemeSettingsView.swift` | Pushed from Profile |
| 15 | Density Settings | `DensitySettingsView.swift` | Pushed from Profile |

**Total: 15 distinct destinations, 9 stage/variant states, 6 empty/error/banner states = 30 surfaces.**

### 1.2 Per-screen documentation

#### Today (Home)
- **Purpose:** Deliver today's 5 words and walk the user through Feynman practice.
- **Mental state:** "I have 5 minutes. Show me what's left." Returning users want speed; new users want orientation.
- **Interactive elements:** Header (informational), 5 progress dots (tappable to jump), Feynman card deck (swipeable + per-stage tap), notification banner CTA (Settings deep-link + dismiss).
- **Hierarchy as it exists:** 1) Large nav title "Today" 2) Header card (level title + bar + streak) 3) Five progress dots 4) Feynman card body. Eye lands on the nav title first, then the streak number (because of the colored flame), then the card title.
- **Density:** Cluttered. The header card alone has six text elements (level title, %, words remaining, streak number, "day streak", flame icon). The Feynman card adds another 6–8 elements above the body content.
- **Entry/exit:** Entry from tab bar, app launch, notification tap. Exit to Word Detail (sheet), Word Report (sheet), Level-Up (sheet), Settings (deep-link from banner).

#### Feynman card — across stages
- **Purpose:** Single-word focused practice using a 6-stage Feynman flow.
- **Mental state:** Focused; each stage is a small commitment.
- **Hierarchy:** Word + pronunciation + level chip + stage counter compete at the top. Then a stage label (`THE WORD` etc., uppercase tracked), then body, then a primary button. On the `word` stage there is also a secondary `Report issue & skip` pill plus a tertiary `Skip & mark finished` button. Three buttons in the same view = three competing decisions.
- **Density:** Sparse on stages 1–2, dense on stage 3 (technical) which crams definition + tech context + example + code block + etymology into a scrolling region inside a card with shadow + corner radius. The card-inside-scroll feels claustrophobic on iPhone.
- **Motion:** A 90° 3-D rotation flip on every advance. Six stages × ~300ms = an animation budget the screen cannot afford. Visually disorienting at scale.

#### Word Detail
- **Purpose:** Reference view for any word.
- **Mental state:** Reading; no commitment expected.
- **Hierarchy:** Large nav title (the word) → meta block (pronunciation, partOfSpeech chip, level caption) → 5 stacked cards. The eye must traverse three meta lines before reaching content.
- **Density:** Each card has its own padding, corner radius, and gray background. With 5 cards the screen reads like a stack of receipts.

#### Word Report sheet
- **Purpose:** User flags a problematic word.
- **Mental state:** Mildly annoyed; wants quick exit.
- **Density:** Word card + 4 reason rows + conditional notes editor. Reasonable, but the word-info card duplicates information already in the card the user came from.

#### Review (Assessment + Flashcards)
- **Purpose:** Test recall and schedule reviews.
- **Mental state:** Quiz-readiness; expects rapid feedback.
- **Hierarchy:** Nav title "Review" → custom segmented tab strip (Assessment | Flashcards) → stats header bar ("3 of 8" + "1/2 correct") → card. **Three layers of chrome above the actual question.**
- **Affordance:** The custom `TabButton` is a hand-rolled segmented control with an underline; iOS already ships `Picker(.segmented)` and `.toolbar(.hidden, for: .tabBar)` patterns that are familiar. The hand-rolled version is functional but visually heavier than necessary.
- **Density:** Stats header (a card-tinted bar) + AssessmentView's own ScrollView padding makes the question itself sit very low.

#### Assessment card
- **Purpose:** Multiple-choice; 2 correct on different days = mastered.
- **Hierarchy:** "What does this word mean?" (callout, muted) → big word (title1) → pronunciation (mono, muted) → 4 option cards → submit. The kicker label "What does this word mean?" is redundant — the four definition options answer that question implicitly.
- **Affordance:** Selected state uses border + background + filled circle on the right; correct/incorrect uses border + background + checkmark/x. Three layered signals where one (background change) would suffice.
- **Feedback:** A green/red tinted card slides in below options with icon + label + Continue. Continue is full-width, accentText on accent — fine, but the colored card persists past the moment the user has parsed the result.

#### Flashcard
- **Purpose:** SRS recall practice.
- **Hierarchy:** Word + pronunciation centered on a 400pt-tall card with 32pt padding. "Tap to flip" instruction below.
- **Motion:** 90° 3-D rotation flip on tap; back side uses `scaleEffect(x: -1, y: 1)` to compensate for the mirror — a working hack, but conceptually fragile.
- **Color semantics:** "Again" is `theme.colors.warn` (orange `#B5651D`) and "Got it" is `theme.colors.good` (forest green `#2F6F47`). Standard SRS apps use red for "Again". Orange reads as caution, not failure, blunting the recall signal.

#### Library
- **Purpose:** Search/browse practiced words.
- **Mental state:** "I half-remember a word about caching…"
- **Hierarchy:** Large nav title "My Words" → search bar → horizontal scrolling filter chips → list of word cards.
- **Density:** Each row is a small card (corner radius 8, surface bg) showing word title + 2-line definition + stack name + level. With 12 practiced words, the screen is 12 cards stacked — feels like a Trello board, not a reference list.
- **Affordance:** Filter chips scroll horizontally with no edge fade or "+N more" hint; users may not realize there are more chips off-screen.

#### Profile (You)
- **Purpose:** Stats, mastered/bookmarked rollup, settings entry points.
- **Hierarchy:** 6 stacked cards: level, streak, stats (4 rows), mastered, bookmarked, settings (4 rows). The settings card is internally a list with dividers; the stats card is the same — but they're framed as cards, not as iOS grouped lists.
- **Density:** Heavy. Six full-width cards with their own padding ranges, all on a tinted bg.
- **Affordance:** The mastered and bookmarked cards display only a count (e.g. "5 words mastered") and are *not* tappable to drill into the list. Looks tappable, isn't.

#### Stack Management / Stack Selection (onboarding)
- **Purpose:** Choose optional stacks (mandatory ones are pinned).
- **Hierarchy:** Info banner → CORE STACKS section header → mandatory stack cards (locked) → OPTIONAL STACKS section header → optional stack cards.
- **Density:** Each stack card is icon + title + REQUIRED chip (sometimes) + 1–2 line description + selection circle. Stacking 12+ such cards results in a lot of visual repetition without grouping.

#### Notification Settings
- **Purpose:** Toggle reminders, set times.
- **Density:** Three conditional cards: master toggle → primary time picker → second reminder card (with embedded toggle and conditionally-revealed second time picker). This is `Form`-shaped data presented as floating cards.

#### Theme / Density Settings
- **Purpose:** Single-choice picker.
- **Hierarchy:** Three (Theme) or two (Density) full-width radio cards with title + description + selection icon + selection border.
- **Affordance:** Visually heavy for a "pick one" decision. Native equivalent: `Picker(.inline)` or `List(.insetGrouped)` rows.

#### Onboarding
- **Hierarchy:** SF Symbol (72pt, light weight) → headline (with `\n` line break for poetic effect) → description → page indicator → primary button → skip text button.
- **Density:** Sparse, appropriate. The hero copy works.

#### Level-Up sheet
- **Hierarchy:** 80pt star icon → "Congratulations! You have been promoted to" → level title (largeTitle) → level description → mandatory stacks list → optional stacks list (toggleable) → Continue.
- **Tonal mismatch:** The first half is celebration; the second half is administration (stack-picking). The transition is jarring.

### 1.3 Core user journeys

1. **First-launch onboarding:** Loader → 3 onboarding pages → Stack selection → Today (Home) → first Feynman card. **5 screens before the user sees a single word.** Skipping is supported but not obvious.
2. **Daily ritual (returning user):** Notification tap → Today → Feynman card stage 1 → 2 → 3 → 4 → 5 → 6 → swipe to next word. Repeat 4 more times. **30+ taps to complete a day.**
3. **Reinforcement:** Review tab → tap Assessment subtab → answer → Continue → next → … or → Flashcards subtab → tap to flip → Again/Got it → next.
4. **Lookup:** Library tab → search → tap row → Word Detail → bookmark or mark mastered.
5. **Maintenance:** Profile tab → Notifications/Theme/Density/Stacks → adjust → back.

### 1.4 Design system as it exists today

| Axis | Current state | Notes |
|---|---|---|
| Type families | Inter (UI), JetBrains Mono (code/metadata), Instrument Serif Italic (etymology) | Excellent, considered choice; rare and tasteful. |
| Type scale | 12, 13, 15, 16, 17, 20, 22, 26, 28, 34 | 10 sizes, all manually defined. Mostly aligns to iOS Dynamic Type but the 15/16/17 cluster is muddled. |
| Caption styling | UPPERCASE + `tracking(0.5)` for stage labels and section headers; sentence case elsewhere | Inconsistent. Used in: stage labels, section headers, "YOUR EXPLANATION" / "TAKEAWAY". Not used in: meta lines, timestamp captions, profile labels. |
| Color palette | bg `#F6F5F2` (cream) · ink `#15161A` · inkMuted/inkFaint · accent `#3E4BDB` (indigo) · accentBg (8% accent) · good (forest) · warn (terracotta) · code colors | Strong, opinionated. Main risk: accent overuse. |
| Surface depth | `surface` color + `cornerRadius` 8/12/16 + black 8% shadow on Feynman/Flashcard | Shadow is the strongest 2017-era tell. Most modern iOS surfaces use hairlines or no separator at all. |
| Corner radii | 4 (stage chip, code blocks), 6 (icon tiles), 8 (cards, code), 12 (cards, buttons), 16 (Feynman card), 20 (filter pills) | Six radii. Three would do. |
| Spacing | xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32 | Reasonable. Density modes (compact/roomy) layered on top. |
| Iconography | SF Symbols throughout (`fill` variants on tab bar, `regular` elsewhere) | Generally consistent. `flame.fill` tinted accent indigo is unusual semantics. |
| Motion | 3-D rotation flip on Feynman advance and Flashcard flip; spring on review handoff; no symbol effects, no haptics | Heavy use of literal flip metaphor; no use of iOS 17 `.symbolEffect`, `.sensoryFeedback`, or matched-geometry. |
| Components | One-off implementations: `FilterChip`, `TabButton`, `StackCard`, `OptionButton`, `ReasonButton`, `SettingsRowContent`, `StatRow`, `WordRowView`, `SectionHeader`, `StackUnlockCard` | No shared button or row primitives — each surface re-implements from raw SwiftUI. |

---

## Phase 2 — Critique

Each screen is evaluated below against clarity, hierarchy, density, consistency, affordance, feedback, typography, color, motion, accessibility, cognitive load, and emotional tone. Where something is working, it is called out so the redesign protects it.

### What's working — protect this

1. **The font stack is genuinely beautiful.** Inter + JetBrains Mono + Instrument Serif Italic is a tasteful, distinctive trio. The italic serif on etymology is delightful.
2. **The cream light-mode background `#F6F5F2`** is a confident departure from default white and gives the app a Bear/Things-like editorial feel. Keep this.
3. **Indigo accent `#3E4BDB`** is a defensible single-brand color. Don't broaden the palette.
4. **Onboarding copy** is poetic and restrained — "Five quiet words, every weekday." Protect this voice.
5. **The Feynman flow as a *concept*** is the product's differentiator. The staging is correct; only the chrome around it needs work.
6. **Empty-state copy and structure** (icon + title + body) is consistent across Library/Review.
7. **Dynamic Type wiring** is correct — every custom font uses `relativeTo:` so it scales.
8. **VoiceOver labels** are present on virtually every interactive element. Real, audited a11y work.

### Today (Home)

| Dimension | Issue |
|---|---|
| Clarity | Three competing focal points: the streak flame, the level title, the card title. None wins decisively. |
| Hierarchy | Header card uses `.headline` for level title and `.headline` for the streak number. Same weight, same emphasis, opposite meanings. |
| Density | Above the fold: nav title + 6-element header card + 5 progress dots + Feynman card header (5 elements) + stage indicator + stage label + body. ~14 distinct text/visual blocks. |
| Consistency | Streak flame uses `accent` (indigo) — semantically conflicts with the universal warm-color flame metaphor. |
| Affordance | Progress dots are tappable but indistinguishable from page-indicator decoration. |
| Feedback | Submitting an explanation triggers a 3-D flip + a state change; no haptic, no symbol bounce. |
| Cognitive load | Three buttons on the `word` stage (`Next`, `Skip & mark finished`, `Report issue & skip`) — three escape hatches before the user has even read the word. |
| Emotional tone | Crowded. Not "five quiet words." |

### Feynman card

| Dimension | Issue |
|---|---|
| Clarity | The `word` stage is asking the user to "say it out loud" but presents the word, pronunciation, level chip, stage counter, stage label, prompt, *and* a "Report issue & skip" pill. Six elements where one should dominate. |
| Hierarchy | The word itself uses `cardTitle` (22/26pt) but the stage counter chip in the corner is the same visual weight (caption + accent-tinted background). The chip steals attention. |
| Density | `technical` stage stuffs 5 sections (definition, tech context, example sentence, code block, etymology) into a vertical scroll *inside* a card with `cornerRadius 16` and a shadow. A card containing a scroll containing more cards. |
| Consistency | "L1 · Intern Band 1" is repeated on the Feynman card header *and* on Word Detail header *and* on Word Report card. Three different visual treatments of the same fact. |
| Affordance | The `Skip & mark finished` button uses `theme.colors.good` (green) — looks confirmatory, but the action is destructive (skips practice, jumps to mastered). Color is misleading. |
| Feedback | After submission, the card flips and replays the user's explanation in the `done` stage — this *is* working well; protect it. |
| Motion | 90° 3-D Y-axis rotation on every Next. Across 6 stages this is six full flips per word, 30 per day. Heavy. |
| Cognitive load | Two ways to advance, two ways to bail (mastered or report-and-skip), and on `done` two more (open detail or report). Eight possible exits. |

### Word Detail

| Dimension | Issue |
|---|---|
| Hierarchy | Large nav title (the word) → 3-line meta block (pronunciation, partOfSpeech chip, level caption) → 5 cards. The chip-then-caption-then-cards rhythm is tiring. |
| Density | Five separate cards mean five corner radii, five inner paddings, five surface fills. The screen looks like a deck of receipts. |
| Consistency | Section headers ("DEFINITION", "TECH CONTEXT") use the same uppercase tracked caption pattern as the Feynman stage labels. The pattern is overused — every label in the app is shouting in caps. |
| Affordance | Toolbar bookmark and mastered toggles are two adjacent SF Symbol buttons. They visually rhyme but mean different things; users frequently confuse "save for later" with "I know this." |

### Review (tabs + headers)

| Dimension | Issue |
|---|---|
| Hierarchy | Nav title + custom segmented control + stats card-bar + actual card. Four chrome layers before content. |
| Consistency | Custom `TabButton` reinvents what `Picker(.segmented)` or `.tabViewStyle(.page)` would do natively. |
| Density | Stats header (`1 of 8 · 0/2 correct` or `5 reviewed today`) is information that's only relevant *between* questions, not during them. |
| Cognitive load | The user has to mentally swap models between Assessment (multiple choice + cooldown) and Flashcards (binary self-grading + SRS). Putting them behind subtabs makes both feel half-baked rather than two purposeful surfaces. |

### Assessment card

| Dimension | Issue |
|---|---|
| Clarity | "What does this word mean?" prompt is redundant — four definition options answer that question. |
| Affordance | Selected/correct/incorrect uses three concurrent signals (border + background + circle/check/x icon). Two would do. |
| Feedback | Tinted feedback card persists below the answer until Continue is tapped; the user reads the result then sits with it. |
| Motion | None. A correct answer should bounce; an incorrect answer should shake gently. Currently silent. |

### Flashcard

| Dimension | Issue |
|---|---|
| Affordance | "Tap to flip" hint is a permanent label; on first launch it's helpful, after that it's chrome. |
| Color semantics | "Again" tinted orange (`warn`), "Got it" tinted green (`good`). Standard SRS uses red for Again — the orange softens the negative signal and reduces honest self-grading. |
| Motion | The mirror compensation (`scaleEffect(x: -1, y: 1)`) is a fragile hack. iOS 18+ has `.rotation3DEffect` matched against `transform3DEffect` and `Transition` APIs that handle this without scale tricks. |
| Density | 400pt fixed card height with 32pt internal padding pushes content; on small screens the action buttons ride near the keyboard or tab bar. |

### Library

| Dimension | Issue |
|---|---|
| Clarity | Title says "My Words" but the rest of the app uses "Today" / "Review" / "You" — varying register (literal vs. possessive). |
| Hierarchy | The most-frequent action is search, but it's secondary to the filter chips by virtue of being inside the system's `.searchable` API. |
| Density | Each word is a card. With 30+ practiced words the page becomes a wall of cards. A grouped list with hairlines would scan in half the time. |
| Affordance | Horizontal-scrolling filter chips with no edge fade hide content. |
| Cognitive load | Three independent filter axes: search query, stack chip, and (implicit) "practiced words only". The implicit filter isn't surfaced. |

### Profile (You)

| Dimension | Issue |
|---|---|
| Hierarchy | Six full-width cards. The level card and stats card are the most informative; mastered and bookmarked are vestigial (count-only, not tappable). |
| Density | Heavy. iOS-native `Form { Section { ... } }` would shrink this by 30%. |
| Affordance | Mastered and Bookmarked cards look tappable but aren't. Settings rows look like rows but are wrapped in a card with internal dividers — visually the divider rhythm fights the card edge. |
| Consistency | Settings card mixes two patterns: navigation rows and a "subtitle" suffix that overlaps with iOS's standard "secondary text" idiom. |

### Stack Management / Stack Selection

| Dimension | Issue |
|---|---|
| Density | 12+ stack cards stacked is visually monotonous. No grouping, no search. |
| Consistency | Three subtly different cards — `StackCard` (onboarding/management) and `StackUnlockCard` (level-up) — implement near-identical UI. The world's smallest design-system fork. |
| Affordance | Mandatory stack cards are still rendered as full pressable cards but `onToggle: {}`. Users can tap and feel nothing. |
| Cognitive load | "REQUIRED" badge + checkmark + lighter background — three signals to say "you can't deselect this." One would do. |

### Notification Settings

| Dimension | Issue |
|---|---|
| Hierarchy | Three conditional cards. The relationship between primary toggle, primary time, and second reminder is form-shaped but rendered as floating panels. |
| Consistency | This is the only place in the app where a `Toggle` is used. It's the right native primitive — but it lives inside a custom card instead of a `Form`. |
| Affordance | The denied banner is a tappable button that opens system Settings, but its visual rhythm matches the static cards above. |

### Theme / Density Settings

| Dimension | Issue |
|---|---|
| Density | Three radio cards (Theme) or two (Density), each ~80pt tall. A "pick one of three" decision shouldn't take a half screen. |
| Consistency | These two screens are functionally identical — same code-shape with different content. They should share one component. |

### Onboarding pages

| Dimension | Issue |
|---|---|
| Hierarchy | Working well. SF Symbol + title + description is the canonical iOS pattern. |
| Motion | No transition delight between pages — just the system page swipe. |
| Cognitive load | Skip is a tertiary text button; works. |

### Stack Selection (post-onboarding)

| Dimension | Issue |
|---|---|
| Cognitive load | First task in the app is to pick from a long list. New users have no basis to choose between, e.g., "API Design" and "Middleware". |
| Affordance | "REQUIRED" pinned cards are visually similar to selectable ones; the user has to read the chip to know they can't deselect. |

### Level-Up

| Dimension | Issue |
|---|---|
| Tonal mismatch | Celebratory header → admin task in the same modal. The user just leveled up; making them pick optional stacks immediately interrupts the rush. |
| Motion | Static icon. No bounce, no symbol effect, no haptic — the most celebratory moment in the app passes silently. |

### Word Report

| Dimension | Issue |
|---|---|
| Density | Word info card duplicates information from the screen the user came from. |
| Affordance | Reasons use the same border + bg + checkmark trio. Same notes as Assessment options. |

### Cross-cutting issues

1. **Cards as the universal container.** Almost every section in the app is a `surface` card with a corner radius. Modern iOS reserves "card" for things that meaningfully float (Now Playing widget, focus modes). Section grouping should mostly be done with whitespace, hairlines, and section headers — not surface fills.
2. **Three layers of indicator on selection.** Across `OptionButton`, `ReasonButton`, `StackCard`, `ThemeSettingsView`, and `DensitySettingsView`, selection state uses border + background + filled circle. One signal would suffice. The repetition makes the app feel like it's compensating for poor contrast.
3. **No haptics anywhere.** Searched the codebase — no `UIImpactFeedbackGenerator`, no `.sensoryFeedback`. The app feels mute. Submitting a correct assessment, completing a card, breaking a streak, leveling up — all should have purposeful haptics.
4. **No symbol effects.** iOS 17 ships `.symbolEffect(.bounce)`, `.symbolEffect(.pulse)`, `.symbolEffect(.replace)` — perfect for the streak flame, the level star, the checkmark on done. Currently nothing.
5. **Deprecated `cornerRadius` everywhere.** `cornerRadius(_:)` was deprecated in favor of `clipShape(RoundedRectangle(cornerRadius:))` / `containerShape`. Not a behavioral bug today, but a smell.
6. **Custom segmented control + custom radio cards + custom toggles** — every input is hand-rolled. iOS native `Form`, `Picker`, `Toggle`, `Stepper`, `DatePicker` are right there.
7. **`accentText` is hardcoded white** in both light and dark. WCAG-borderline against the dark-mode accent `#8B93FF`. Should adapt.
8. **iPad gets a wider-single-column layout** at 720pt max-width. No use of `NavigationSplitView`, sidebar, or two-column reading layouts on a device that begs for them.
9. **Density preference (compact/roomy)** is a personalization knob most users won't ever flip. The best apps make one well-tuned default.
10. **`L1 · Intern Band 1` redundancy.** Levels are surfaced 4 different ways: nav-bar streak, header card, Feynman card meta, Word Detail meta, Profile level card. Pick one place.

---

## Phase 3 — Recommendations

Each recommendation includes **What · Why · Reference · Effort · Impact · Priority**. Effort is engineering effort, not design effort. Impact is the user-experience consequence.

### 3.1 Foundational (design system) — these ripple across every screen

#### F1. Replace card-as-default with grouped lists + hairlines
**What:** Convert Profile, Word Detail, Stack Management, Notification Settings, Theme/Density Settings to native `List(.insetGrouped)` (or `Form { Section { ... } }`) with section headers, hairlines, and `theme.colors.surface` row backgrounds. Keep the cream `bg` token.
**Why:** The current "stack of cards on a tinted bg" pattern reads as a 2017 Material translation of iOS. Native grouped lists reduce visual noise dramatically and ride iOS's first-class scrolling/dynamic-type/swipe-action behavior for free.
**Reference:** Apple Settings, Things 3 (settings), Linear iOS settings, Dieter Rams' "less but better".
**Effort:** L · **Impact:** high · **Priority:** P0

#### F2. Drop the surface shadow; use a 1pt hairline border
**What:** On Feynman card, Flashcard, and any remaining card surfaces, replace `.shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)` with `.overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.colors.line, lineWidth: 0.5))`.
**Why:** The shadow is the single strongest "looks dated" tell. Modern iOS surfaces (Notes, Mail, Linear, Things) use hairlines or no separation. A hairline preserves grouping without adding depth.
**Reference:** Apple Notes attachments, Linear iOS task cards.
**Effort:** S · **Impact:** medium · **Priority:** P0

#### F3. Tighten the corner-radius scale to 3 values
**What:** Standardize on 8 (inline chips, code blocks), 12 (cards, buttons), 999 (pills/circles). Remove 4, 6, 16, 20 from surface code.
**Why:** Six radii feel arbitrary. Three feel intentional.
**Reference:** Linear's design tokens, GitHub Primer mobile.
**Effort:** S · **Impact:** low · **Priority:** P1

#### F4. Sentence-case all section headers; reserve UPPERCASE for code/metadata
**What:** Convert `wordDetail.section.*` ("DEFINITION" → "Definition"), Feynman stage labels ("THE WORD" → "The word" or remove entirely), and "YOUR EXPLANATION" / "TAKEAWAY" headings. Keep mono uppercase only for code/level metadata like `L3` and tags.
**Why:** All-caps tracked captions are the second-strongest "dated" tell after card-shadow. Sentence case is calmer, easier to read, and reads as more confident.
**Reference:** Bear, Things 3, Apple Reminders.
**Effort:** S · **Impact:** medium · **Priority:** P0

#### F5. Make `accentText` adaptive
**What:** In `ColorTokens.dark`, set `accentText: Color(hex: "0B0C0E")` (near-black) instead of `.white`. White on `#8B93FF` is borderline contrast; near-black is WCAG-safe and visually crisper.
**Why:** Accessibility + a tighter look.
**Reference:** Apple HIG color contrast guidance.
**Effort:** S · **Impact:** medium · **Priority:** P0

#### F6. Add haptics
**What:** Use SwiftUI's `.sensoryFeedback`:
- `.success` on assessment-correct, daily-set-complete, level-up
- `.error` on assessment-incorrect
- `.selection` on Feynman stage advance and tab swipe
- `.impact(.soft)` on Flashcard tap-to-flip
- `.impact(.heavy)` once per level-up (paired with bounce)

**Why:** Without haptics, success and failure feel identical. A correct answer should *feel* right. This is the single highest-impact polish lever in the app.
**Reference:** Things 3 task-complete haptic, Duolingo answer feedback.
**Effort:** S · **Impact:** high · **Priority:** P0

#### F7. Use SF Symbol effects for moments of state change
**What:**
- Streak flame: `.symbolEffect(.bounce, value: progress.displayedCurrentStreak)` whenever the streak increments.
- Level-up star: `.symbolEffect(.bounce.up.byLayer)` on appear.
- Checkmark seal on assessment-correct: `.symbolEffect(.scale.up.byLayer)` then settle.
- `done` stage badge: `.contentTransition(.symbolEffect(.replace))` from the active stage indicator.

**Why:** Native iOS 17 motion language; signals "this is alive" without custom code.
**Reference:** Apple Calendar, iOS 17 Settings page on first open.
**Effort:** S · **Impact:** medium · **Priority:** P1

#### F8. Replace the 3-D rotation flips with cross-fade or push transitions
**What:** Replace `rotation3DEffect` on Feynman advance and Flashcard flip with either a cross-fade (`.transition(.opacity.combined(with: .move(edge: .leading)))`) or a `.contentTransition(.numericText())` style. For the Flashcard specifically, keep a *subtle* flip — clip to the front/back faces using `.opacity` switch at the 50% mark and ditch the `scaleEffect(x: -1, y: 1)` mirror.
**Why:** 30 full 3-D flips per day is a motion budget overdraft. A 200ms cross-fade reads as "this changed" without inducing motion fatigue. Reduces motion-sickness risk and respects `Reduce Motion` correctly.
**Reference:** Linear's command palette stage changes; Things 3 task add/remove.
**Effort:** M · **Impact:** high · **Priority:** P0

#### F9. Build a tiny shared component layer
**What:** Extract three primitives:
- `PrimaryCTAButton(titleKey:isEnabled:action:)` — used by every accent-on-accent submit button.
- `SelectableRow(title:subtitle:isSelected:action:)` — used by Theme, Density, Stack, Reason, Option pickers.
- `MetaCaption(level:stack:)` — the "L3 · Junior Band 1" pattern.

Replace the ~7 duplicated implementations with these.
**Why:** Drift between OptionButton, ReasonButton, StackCard, theme rows and density rows is already real. A shared primitive locks the rhythm and halves the maintenance surface.
**Effort:** M · **Impact:** medium · **Priority:** P1

#### F10. Remove density preference (or hide behind an "Advanced" disclosure)
**What:** Delete `DensitySettingsView`, `DensityPreference`, and the related `cardPadding(density:)` / `rowPadding(density:)` helpers. Pick one well-tuned default (lean toward `roomy`; collapse compact spacing toward it).
**Why:** Density toggles are the kind of feature where the *feature itself* costs more attention than it gives back. Most users never find it; it adds testing surface and visual variance to every screen. Modern apps commit to a default.
**Reference:** Things 3 has no density toggle. Linear has no density toggle. Apple Notes has no density toggle.
**Effort:** S · **Impact:** medium (reduces complexity) · **Priority:** P1

#### F11. Lean harder into the cream + indigo restraint
**What:** Audit usages of `accentBg` (8% indigo tint). Currently used on: stage indicator chip, mic button bg, info banners, accent icon tile, REQUIRED badge, partOfSpeech chip. **Reduce to two uses max:** info banners and the active state of selectable rows. Remove from chips/badges/icons (use `surfaceAlt` or no fill).
**Why:** A single brand color earns its weight by being scarce. The current spread of accentBg dilutes the indigo from "moment of meaning" to "another tinted surface."
**Effort:** S · **Impact:** medium · **Priority:** P1

#### F12. Migrate `cornerRadius` → `clipShape(.rect(cornerRadius:))`
**What:** Wholesale find/replace; behavior identical, deprecation gone, and `clipShape` plays nicer with `.containerShape` for hit-testing.
**Why:** Future-proofing.
**Effort:** S · **Impact:** low · **Priority:** P2

### 3.2 Per-screen recommendations

#### Today (Home)

**T1. Collapse the header card into a single line.**
- *What:* Replace the two-column header (level + progress + streak) with a single line under the nav title: `Intern Band 1 · 7 day streak 🔥` rendered as small mono caption + `flame.fill`. Move the level *progress bar* below the deck (or remove from Today entirely; surface in Profile).
- *Why:* The header card is doing three jobs (level ID, progress, streak); none well. A single status line returns focus to the cards.
- *Reference:* Things 3 today header, Linear focus mode header.
- *Effort:* M · *Impact:* high · *Priority:* P0

**T2. Replace progress dots with a simple `n / 5` counter.**
- *What:* Above the deck, render `2 / 5 today` (mono caption); use the system `.tabViewStyle(.page(indexDisplayMode: .always))` for navigation. Keep the dots-as-jumper logic for VoiceOver only.
- *Why:* Two indicators (custom dots + page indicator) compete. Plain text is calmer and more accessible.
- *Effort:* S · *Impact:* medium · *Priority:* P1

**T3. Reduce stage chrome on the Feynman card header.**
- *What:* Show only the word + pronunciation. Move stage counter to a hairline progress bar at the top of the card body (`Capsule().frame(height: 2)` filled to `progress`). Remove the level meta from the per-card header (it's redundant with T1).
- *Why:* The word should be the loudest thing on the card. Currently four typographic elements compete.
- *Reference:* Duolingo lesson card header (just lesson name + tiny progress bar).
- *Effort:* M · *Impact:* high · *Priority:* P0

**T4. Resolve the three-button overload on the `word` stage.**
- *What:* Keep `Next` as the only primary. Move "Skip & mark finished" and "Report issue & skip" into a single `Menu` triggered by an `ellipsis.circle` button in the card's top-right corner. (Or pull "Skip" out entirely — if a user wants to mark mastered, they can do it from Word Detail.)
- *Why:* Three escape hatches before the user has read the word is the literal opposite of focus.
- *Reference:* iOS Mail message actions menu.
- *Effort:* S · *Impact:* high · *Priority:* P0

**T5. Replace the 3-D rotation flip with a cross-fade.**
- *Already covered in F8.* Specifically for Feynman: `.transition(.opacity.animation(.easeInOut(duration: 0.18)))` on `stageContent`.
- *Effort:* S · *Impact:* high · *Priority:* P0

**T6. Use accent only for "you did it" moments; flame stays warm.**
- *What:* Tint `flame.fill` with `theme.colors.warn` (terracotta) or a dedicated `streakColor` token (orange `#E08A1E`). Reserve indigo for primary actions and the active state.
- *Why:* The flame's universal warmth is part of its meaning. Recoloring it indigo is unusual and works against the streak's emotional cue.
- *Effort:* S · *Impact:* medium · *Priority:* P1

#### Feynman card details

**FC1. Add a placeholder to the explanation editor.**
- *What:* `TextEditor` doesn't show a placeholder by default. Use a `ZStack` with a `Text("Try: a way to remember it…")` overlay that hides on focus or non-empty.
- *Why:* Empty editors are unfriendly; first-time users stare at a blank box.
- *Effort:* S · *Impact:* medium · *Priority:* P0

**FC2. Make the mic button visually distinct between idle and recording.**
- *What:* Idle: `mic` outlined, `inkMuted` color, no background. Recording: `mic.fill`, accent bg + accent text, plus a subtle `.symbolEffect(.pulse)` and a recording dot.
- *Why:* Currently the only signal is `mic` vs. `mic.fill` on the same accent-tinted circle. Easy to miss in a glance.
- *Reference:* Apple Voice Memos record button.
- *Effort:* S · *Impact:* medium · *Priority:* P1

**FC3. Persist the user's explanation across stages within a card.**
- *What:* When the user types/speaks then advances back to `simple` to re-read, their text should still be there on return.
- *Why:* Stage navigation should not destroy in-progress input. (Today's behavior depends on view lifecycle; verify before fixing.)
- *Effort:* S · *Impact:* low · *Priority:* P2

**FC4. The `technical` stage should not be a card-inside-card.**
- *What:* When entering the technical stage, expand the card to a sheet or full-screen reading mode (`fullScreenCover` or a `.sheet(detents: [.large])`). The card → sheet motion can be `matchedGeometryEffect` for continuity.
- *Why:* A nested ScrollView inside a card with shadow + corner radius is the most claustrophobic surface in the app, and the technical stage is the one with the most content.
- *Effort:* M · *Impact:* high · *Priority:* P1

#### Word Detail

**WD1. Convert to a native scrolling reader, no cards.**
- *What:* Replace the 5 cards with a single `ScrollView` containing typography only: short definition (body, prominent), then long definition (callout, muted), tech context as a quote-style indented paragraph, code in a hairline-bordered mono block (no card), example sentence in a serif italic centered pull-quote, etymology as the closer.
- *Why:* The word is content; this should read like a great article, not a settings page.
- *Reference:* Things 3 task detail, Bear's note view, Apple Books footnote treatment.
- *Effort:* M · *Impact:* high · *Priority:* P0

**WD2. Combine bookmark and mastered toolbar buttons into a single menu.**
- *What:* Replace two adjacent toolbar buttons with one `ellipsis.circle` `Menu` containing `Bookmark`, `Mark as mastered`, `Report issue`. State indicator (filled bookmark / mastered seal) appears next to the title instead of the toolbar.
- *Why:* Two SF Symbols in the toolbar look identical at a glance and have very different effects.
- *Effort:* S · *Impact:* medium · *Priority:* P1

#### Review

**R1. Replace the custom segmented control with `Picker(.segmented)` in the toolbar.**
- *What:* Move `Assessment | Flashcards` to a `Picker` placed in the navigation bar (or below the title using `.toolbar(.principal)`).
- *Why:* Native segmented control is familiar, accessible, and removes ~30 lines of custom view code.
- *Effort:* S · *Impact:* medium · *Priority:* P1

**R2. Move the stats header into the navigation bar subtitle (iOS 18+) or remove during practice.**
- *What:* Show "1 of 8 · 0/2 correct" inside `.navigationSubtitle` (iOS 18+) or as a tiny mono caption above the card. Remove the surface-tinted stats card-bar.
- *Why:* The stats card-bar creates visual noise during the moment the user wants to focus on a question.
- *Effort:* S · *Impact:* medium · *Priority:* P1

**R3. Consolidate the four review empty states into two.**
- *What:* "No assessments available" / "All done for today!" / "No flashcards due today" all use the same icon-title-message pattern. Add a small actionable footer to each ("← Back to Today" or "Open Library") so the empty state is a launchpad, not a dead end.
- *Why:* Empty states are opportunities. Currently they apologize.
- *Reference:* Things 3 empty states have a "next thing to do" link.
- *Effort:* S · *Impact:* medium · *Priority:* P1

#### Assessment card

**A1. Drop the redundant "What does this word mean?" prompt.**
- *What:* Remove `review.assessment.question`. Show only the word + pronunciation; the four definition options are self-evidently the question.
- *Why:* Less is more; users will not be confused.
- *Effort:* S · *Impact:* low · *Priority:* P1

**A2. Single-signal selection on `OptionButton`.**
- *What:* Selected state = surfaceAlt fill + accent border. No filled-circle icon. Correct = good fill + good border. Incorrect = warn fill + warn border, no x icon (the persisting border tells the story).
- *Why:* Three concurrent signals (border + bg + icon) reads as compensating for poor contrast. One does it.
- *Effort:* S · *Impact:* medium · *Priority:* P1

**A3. Replace the persistent feedback card with an inline result + auto-advance.**
- *What:* On submit, the chosen option turns green/red, an icon appears next to it, and after ~700ms the card auto-advances to the next question. Add a `Continue` floating button only on incorrect answers (so the user can read the right answer at their own pace).
- *Why:* The current flow forces a Continue tap even when the answer is right — friction without payoff.
- *Reference:* Duolingo answer flow.
- *Effort:* M · *Impact:* high · *Priority:* P0

**A4. Add `.sensoryFeedback(.success)` / `.error` on submit.**
- *Already in F6.*
- *Priority:* P0

#### Flashcard

**FL1. Remove "Tap to flip" after first interaction.**
- *What:* `@AppStorage("hasFlippedFlashcard")` flag. Show the hint only until first flip ever.
- *Why:* The hint becomes chrome.
- *Effort:* S · *Impact:* low · *Priority:* P2

**FL2. Tighten the flip; use a fade-through, not a 3-D rotation.**
- *Same approach as F8.* For Flashcard specifically, `.transition(.opacity)` is sufficient. Optional: subtle 12° tilt on tap so it feels like *something* happened.
- *Effort:* S · *Impact:* medium · *Priority:* P1

**FL3. Use red for "Again", green for "Got it".**
- *What:* Add a semantic `bad` token (`#C0392B` light, `#FF6B6B` dark). Use it for "Again" and for incorrect answers.
- *Why:* Orange softens the negative; red tells the truth, which is the whole point of self-grading.
- *Effort:* S · *Impact:* medium · *Priority:* P1

#### Library

**L1. Convert word list to a `List(.insetGrouped)` with hairlines.**
- *What:* Drop `LazyVStack` of cards in favor of `List`. Each row uses `Text(word.word).font(.headline)` + `Text(shortDefinition).font(.subheadline).foregroundStyle(.secondary)` and a meta line. Trailing chevron is automatic.
- *Why:* `List` is faster, more accessible, supports swipe actions natively, scans much better.
- *Effort:* M · *Impact:* high · *Priority:* P0

**L2. Add swipe actions to rows.**
- *What:* Trailing swipe → bookmark / unbookmark. Leading swipe → mark mastered.
- *Why:* Power users will use this all the time; it converts a tedious "tap row → tap toolbar" into one motion.
- *Reference:* Apple Mail swipe actions.
- *Effort:* S · *Impact:* medium · *Priority:* P1

**L3. Filter chips: replace with a `Menu` next to search.**
- *What:* A single `filter` button next to the search field opens a menu with stack toggles. Active filters show as a small mono caption under the search bar ("Showing: web, networking · 23 words").
- *Why:* Horizontal-scroll chip rows hide content. A menu is two taps but always shows everything.
- *Reference:* Apple Mail filters; GitHub mobile.
- *Effort:* M · *Impact:* medium · *Priority:* P1

**L4. Rename "My Words" to "Library" and align all four tab nav titles.**
- *What:* "Today" / "Review" / "Library" / "You" — drop the possessive in the nav title.
- *Why:* Mixed register feels accidental.
- *Effort:* S · *Impact:* low · *Priority:* P2

#### Profile (You)

**P1. Convert the entire screen to a `Form` with grouped sections.**
- *What:* Section 1: Level (cell with title + progress bar). Section 2: Streak (current + longest, two cells). Section 3: Stats (4 native rows with secondary text). Section 4: My collection — Mastered (tappable, drills into a list), Bookmarked (tappable, drills into a list). Section 5: Settings — Stacks, Notifications, Theme, Density.
- *Why:* iOS-native settings/profile pattern; gets free Dynamic Type, free a11y, free keyboard navigation, and the screen feels like *a screen*, not six floating panels.
- *Reference:* Apple Settings, Things 3 settings, GitHub profile mobile.
- *Effort:* M · *Impact:* high · *Priority:* P0

**P2. Make the mastered and bookmarked sections actually tappable into lists.**
- *What:* Each row drills into a filtered Library view scoped to that subset.
- *Why:* Right now a user can see they have 5 mastered words but cannot see *which* words. The data exists, the navigation does not.
- *Effort:* S · *Impact:* medium · *Priority:* P0

**P3. Remove the level *description* line from the level section.**
- *What:* Show "Intern Band 2" and the progress bar. Drop "Building foundational technical vocabulary" — the user has seen this and it's chrome.
- *Why:* The description is meaningful at level-up; it's noise on every other view.
- *Effort:* S · *Impact:* low · *Priority:* P2

#### Stack Management & Stack Selection (onboarding)

**SM1. Group stacks by category.**
- *What:* Grouped list with section headers: "Foundations" (programming, web, networking, …) / "Practices" (testing, agile, …) / "Specialties" (cryptography, ML, …). Mandatory sit pinned in their natural section with a small `Required` text suffix (no chip + checkmark + lighter bg).
- *Why:* 12+ flat options is a wall. Grouping turns it into a menu.
- *Effort:* M · *Impact:* medium · *Priority:* P1

**SM2. Remove `StackCard` / `StackUnlockCard` divergence.**
- *What:* Single component, single source of truth.
- *Effort:* S · *Impact:* low · *Priority:* P2

**SM3. Onboarding stack-selection: provide smart defaults.**
- *What:* Pre-select the 3 most popular optional stacks ("API Design", "Testing", "System Design") with a "tap to deselect" hint. Add a "Skip — pick later" option.
- *Why:* New users have no basis to choose; making them choose is a friction tax. A sensible default that's easily reversible respects the user's time.
- *Effort:* S · *Impact:* medium · *Priority:* P1

#### Notification Settings

**NS1. Convert to a `Form`.**
- *What:* Section 1: Daily reminder (Toggle). Section 2: Reminder time (DatePicker). Section 3: Second reminder (Toggle + conditional DatePicker). Permission denied banner pinned above the form.
- *Why:* This is the most form-shaped data in the app. Use the form primitive.
- *Effort:* S · *Impact:* medium · *Priority:* P1

#### Theme / Density Settings

**TS1. Inline pickers, not full-screen radio cards.**
- *What:* On the Profile form, the Theme cell is a `Picker(.menu)` (or `.navigationLink`) with three options. No separate screen. Same for Density (assuming F10 doesn't remove it).
- *Why:* A "pick one of three" decision should be one tap, not a full screen.
- *Reference:* iOS Settings → Display & Brightness → Appearance.
- *Effort:* S · *Impact:* medium · *Priority:* P1

#### Onboarding

**O1. Hairline page indicator using accent.**
- *What:* Replace the system page-indicator dots with a 3-segment thin progress bar at the top of the screen (each segment = one onboarding page; segments fill as the user advances).
- *Why:* The native page-indicator dots get lost on the cream background. A progress bar reads as "you're almost there", which is the right onboarding message.
- *Reference:* Linear onboarding.
- *Effort:* S · *Impact:* low · *Priority:* P2

**O2. Add a tasteful accent illustration on each onboarding page.**
- *What:* Replace the generic 72pt SF Symbols with three commissioned (or hand-built) line illustrations using only the cream + indigo palette. Animate the active page's illustration with `.symbolEffect(.bounce)` if SF-Symbol-based, or a `Canvas` reveal if custom.
- *Why:* Onboarding is the user's first impression; SF Symbols are functional but generic. The current copy is poetic — the art should match.
- *Reference:* Linear onboarding, Things 3 first-launch.
- *Effort:* L · *Impact:* high · *Priority:* P2

#### Level-Up

**LU1. Split into two beats: celebrate, then choose.**
- *What:* The first sheet is purely celebratory — `.symbolEffect(.bounce.up.byLayer)` star + level title + level description + a *single* "Continue" CTA. Tapping Continue dismisses, then if there are new optional stacks, opens a *second* sheet for stack selection. The celebration never gets contaminated by admin.
- *Why:* Mixing emotion with administration drains both. A Things-3-style celebration sheet first, then a quiet picker, respects the user's moment.
- *Reference:* Apple Fitness ring close animation, Things 3 task-complete moment.
- *Effort:* M · *Impact:* high · *Priority:* P1

**LU2. Add a haptic + subtle confetti on appear.**
- *What:* `.sensoryFeedback(.success)` on appear plus a one-time `Canvas`-based confetti burst (no third-party deps; ~30 lines of SwiftUI).
- *Why:* Level-up is the most rewarding moment in the app. Currently silent.
- *Effort:* M · *Impact:* medium · *Priority:* P2

#### Word Report

**WR1. Drop the word-info card; rely on the navigation title.**
- *What:* Set `navigationTitle(word.word)` and `navigationSubtitle(word.shortDefinition)`. Remove the duplicate top card.
- *Why:* The user came from the card displaying the word; reminding them is overkill.
- *Effort:* S · *Impact:* low · *Priority:* P2

**WR2. Single-signal reason rows (same as A2).**

### 3.3 Cross-cutting flow recommendations

#### CC1. Restructure first-launch onboarding to lead with a sample card.
- *What:* Onboarding page 2 (or page 3) presents a **live, working Feynman card** with a sample word ("idempotent"). The user *plays* the flow before being asked to choose stacks. Stack selection comes after.
- *Why:* Demonstrating the value beats describing it. The current sequence is: tell, tell, tell, configure, then finally show. Reverse it.
- *Reference:* Linear onboarding, Things 3 Quick Find tutorial.
- *Effort:* L · *Impact:* high · *Priority:* P1

#### CC2. Establish a single "level + streak" status line.
- *What:* Across Today, Profile, and the Feynman card meta line, surface level/streak in **one place** consistently. Today: a thin status line under the nav title. Profile: the level section. Feynman card: not at all (remove from per-card meta).
- *Why:* The same fact appearing on three screens with three treatments creates redundancy and makes the app feel anxious.
- *Effort:* M · *Impact:* medium · *Priority:* P1

#### CC3. Introduce a global empty-state component with an action.
- *What:* `EmptyStateView(icon:, title:, message:, action:)` used by Library, both Review subtabs, and any future surface. Always include a primary action (`Open Today`, `Browse Library`).
- *Why:* Empty states should redirect, not apologize.
- *Effort:* S · *Impact:* medium · *Priority:* P1

#### CC4. Adopt `NavigationSplitView` on iPad.
- *What:* On iPad, present a sidebar with the four tabs as the primary column, and the active tab's content in the secondary column. For Library specifically, use master-detail: list on the left, Word Detail on the right.
- *Why:* The current 720pt-max-width single-column on iPad wastes the device. iPad users expect master-detail.
- *Effort:* L · *Impact:* high (for iPad users) · *Priority:* P1

#### CC5. Reduce-motion compliance audit.
- *What:* Wrap all 3-D rotations and the spring transitions with `@Environment(\.accessibilityReduceMotion)` checks. With reduce-motion on, all cross-fade and rotation effects fall back to instant.
- *Why:* Accessibility correctness; some users get vestibular discomfort from rotations.
- *Effort:* S · *Impact:* low (for most users), high (for affected users) · *Priority:* P0

### 3.4 Delight moments — small additions that elevate the app

#### D1. Streak heartbeat.
On Today, when the streak number first appears, animate it in with a `numericTransition`. If the user broke their streak overnight, a subtle inkMuted "0" appears; tapping it shows a gentle "starts again today" message. **Effort: S. Priority: P2.**

#### D2. End-of-day summary card.
After completing the 5th word of the day, replace the deck with a one-screen summary: "Five words. Done. See you tomorrow." Optional `Share` button generates a small image (the day's words on a cream background). **Effort: M. Priority: P2.**

#### D3. Word-of-the-day pull-quote on Word Detail.
A serif italic pull-quote between sections, surfacing the example sentence as a hero element. **Effort: S. Priority: P2.**

#### D4. Etymology as a closing flourish.
Style the etymology section as a hand-set serif italic right-aligned closer (`Instrument Serif Italic` is already in the design system — use it more). Currently it's just a section in a card. **Effort: S. Priority: P2.**

#### D5. First-time bookmark celebration.
When the user bookmarks their first word, a brief inline toast: "Saved. Find it in Library." (no third-party toast lib — use a SwiftUI `.overlay` with `.transition(.move(edge: .top))`). **Effort: S. Priority: P2.**

#### D6. Symbol-effect on tab badge transitions.
When `todayBadge` ticks down (user just completed a card), the badge digit `.contentTransition(.numericText())` instead of snap-replacing. **Effort: S. Priority: P2.**

#### D7. Long-press a Library row for "speak the word."
Use the existing `SpeechService` (or `AVSpeechSynthesizer`) to pronounce the word on long-press. Discoverable via a hint on first launch. **Effort: M. Priority: P2.**

#### D8. Subtle hover-state preview on iPad.
With keyboard/trackpad attached on iPad, hovering a Library row shows a Word Detail preview in the secondary column without commit. **Effort: M. Priority: P2 (depends on CC4).**

---

## Phase 4 — North-star vision

If every recommendation here landed, the app would feel like *a quiet text editor that delivers five words*. Cream paper, a single indigo accent reserved for the moment of action, sentence-case section headers, generous whitespace, and a typeface trio (Inter / JetBrains Mono / Instrument Serif) doing most of the work. Cards would mostly disappear; native iOS list and form patterns would replace the floating-panel chrome. Motion would be restrained — a cross-fade between Feynman stages, a haptic tick on submit, a star bouncing on level-up — rather than constant 3-D flips. The Feynman card would stop competing with itself: one word, one prompt, one primary action; everything else recedes.

The feeling: **calm, confident, and quietly serious.** Not gamified, not noisy, not generic. The kind of app a senior engineer keeps installed because it respects their time and their taste.

**One-sentence design philosophy to commit to:**
> Five quiet words. The interface gets out of the way.

---

## Prioritized backlog

Sorted by Priority × Impact. Use this as your ticket source.

### P0 — Ship this week / sprint

| ID | Title | Effort | Impact |
|---|---|---|---|
| F1 | Replace card-as-default with grouped lists + hairlines | L | high |
| F2 | Drop surface shadow; use 1pt hairline border | S | medium |
| F4 | Sentence-case section headers; reserve UPPERCASE for code/metadata | S | medium |
| F5 | Make `accentText` adaptive in dark mode | S | medium |
| F6 | Add haptics across submit / correct / incorrect / level-up / advance | S | high |
| F8 | Replace 3-D rotation flips with cross-fade transitions | M | high |
| T1 | Collapse Today header card into a single status line | M | high |
| T3 | Reduce stage chrome on Feynman card header (only word + pronunciation) | M | high |
| T4 | Resolve three-button overload on `word` stage (move secondary to ⋯ menu) | S | high |
| FC1 | Add placeholder to explanation editor | S | medium |
| WD1 | Convert Word Detail to a native scrolling reader (no cards) | M | high |
| A3 | Inline result + auto-advance on assessment correct | M | high |
| L1 | Convert Library word list to `List(.insetGrouped)` | M | high |
| P1 | Convert Profile to a `Form` with grouped sections | M | high |
| P2 | Make Mastered / Bookmarked sections drill into actual lists | S | medium |
| CC5 | Reduce-motion compliance audit | S | high (for affected users) |

### P1 — Next sprint

| ID | Title | Effort | Impact |
|---|---|---|---|
| F3 | Tighten corner-radius scale to 3 values (8/12/999) | S | low |
| F7 | SF Symbol effects on streak / level-up / done | S | medium |
| F9 | Build shared component primitives (PrimaryCTAButton, SelectableRow, MetaCaption) | M | medium |
| F10 | Remove density preference (commit to one default) | S | medium |
| F11 | Reduce `accentBg` to two uses; let cream do the work | S | medium |
| T2 | Replace progress dots with `n / 5` counter | S | medium |
| T6 | Tint streak flame warm (not indigo) | S | medium |
| FC2 | Mic button: distinct idle / recording visuals + pulse | S | medium |
| FC4 | `technical` stage: open as sheet, not nested scroll | M | high |
| WD2 | Combine bookmark + mastered into a `Menu` | S | medium |
| R1 | Replace custom segmented control with `Picker(.segmented)` | S | medium |
| R2 | Move stats into nav subtitle / mono caption | S | medium |
| R3 | Make empty states actionable (back-to-Today / open Library) | S | medium |
| A1 | Drop redundant "What does this word mean?" prompt | S | low |
| A2 | Single-signal selection on `OptionButton` | S | medium |
| FL2 | Tighten Flashcard flip to fade-through | S | medium |
| FL3 | Use red for "Again" (add `bad` semantic token) | S | medium |
| L2 | Add swipe actions to Library rows | S | medium |
| L3 | Filter `Menu` next to search; replace chip strip | M | medium |
| SM1 | Group stacks by category | M | medium |
| SM3 | Pre-select smart-default optional stacks in onboarding | S | medium |
| NS1 | Convert Notification Settings to `Form` | S | medium |
| TS1 | Inline pickers for Theme / Density on Profile | S | medium |
| LU1 | Split level-up into celebrate-then-choose | M | high |
| CC1 | Lead onboarding with a live sample Feynman card | L | high |
| CC2 | Single "level + streak" status line across the app | M | medium |
| CC3 | Global empty-state component with action | S | medium |
| CC4 | `NavigationSplitView` on iPad | L | high (iPad) |

### P2 — Someday / maybe

| ID | Title | Effort | Impact |
|---|---|---|---|
| F12 | Migrate `cornerRadius` → `clipShape(.rect(cornerRadius:))` | S | low |
| FC3 | Persist explanation across stage navigation | S | low |
| FL1 | Hide "Tap to flip" hint after first interaction | S | low |
| L4 | Rename "My Words" → "Library" | S | low |
| P3 | Remove level *description* line from Profile | S | low |
| SM2 | Merge `StackCard` and `StackUnlockCard` | S | low |
| WR1 | Drop word-info card on Word Report | S | low |
| O1 | Hairline page indicator on onboarding | S | low |
| O2 | Custom illustrations on onboarding (replace SF Symbols) | L | high |
| LU2 | Confetti + haptic on level-up | M | medium |
| D1 | Streak heartbeat (numericTransition + 0-streak hint) | S | low |
| D2 | End-of-day summary card | M | medium |
| D3 | Pull-quote in Word Detail | S | low |
| D4 | Etymology as serif-italic closing flourish | S | low |
| D5 | First-time bookmark inline toast | S | low |
| D6 | Symbol effect on tab badge transitions | S | low |
| D7 | Long-press a Library row to speak the word | M | low |
| D8 | iPad hover-state preview on Library | M | low |

---

## Counts

- **Surfaces audited:** 30 (15 destinations + 9 stage variants + 6 banners/empty/loading)
- **P0 recommendations:** 16
- **P1 recommendations:** 28
- **P2 recommendations:** 18
- **Total:** 62 recommendations

## Top 3 highest-impact

1. **F1 — Replace card-as-default with grouped lists + hairlines.** This is the single change that will most immediately make the app feel like 2026 native iOS rather than 2017 Material.
2. **T3 + T4 — Reduce Feynman card chrome and consolidate the secondary buttons into a ⋯ menu.** The Feynman card is the product; making it focused makes the product feel focused.
3. **F6 — Add haptics.** A quiet correct-answer haptic and a single-pulse level-up haptic transform the perceived quality of the app for the cost of a `.sensoryFeedback` modifier per surface.
