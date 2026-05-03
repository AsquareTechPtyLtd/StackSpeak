@chapter
id: aicr-ch09-case-studies-and-patterns
order: 9
title: Case Studies and Patterns
summary: Five reference patterns — API migration, framework upgrade, dependency replacement, dead-code elimination, type-system migration — cover most real-world AI-assisted refactoring campaigns and let new ones be planned by analogy.

@card
id: aicr-ch09-c001
order: 1
title: Patterns as Planning Tools
teaser: Most refactoring campaigns rhyme with a campaign someone else has already run — and recognizing which pattern you're in tells you the tooling, the failure modes, and the review strategy before you write a single prompt.

@explanation

Before you pick a tool or draft a prompt, ask: "which campaign is this?" Most large refactoring efforts fall into a small number of recurring shapes. An API migration has a different structure than a type-system migration; a dependency replacement has different failure modes than dead-code elimination. The pattern tells you what the mechanical work looks like, what the judgment-heavy residual looks like, and where LLMs tend to break down.

This chapter covers twelve patterns drawn from real campaigns:

- API migration (Stripe, payment API versioning)
- Framework upgrade (Spring Boot 2 → 3, Rails 6 → 7, Next.js 13 → 14)
- Dependency replacement (Moment.js → date-fns, Lodash → native, Enzyme → React Testing Library)
- Dead-code elimination at scale
- Type-system migration (JS → TS, Flow → TS)
- Comment translation and improvement
- Test-suite modernization (Jest → Vitest, JUnit 4 → JUnit 5)
- Naming convention migration
- License/header insertion
- Multi-language migration (Python 2 → 3, CoffeeScript → TS)
- Campaigns that don't fit a pattern

The planning shortcut: once you recognize the pattern, you inherit its tooling recommendation, its sequencing, and its list of known failure modes. You're not starting from scratch — you're applying a blueprint to your specific codebase.

> [!info] Patterns are not guarantees. They tell you the likely shape of the work and the likely places it breaks down. They do not substitute for reading the actual code before committing to an approach.

@feynman

Using campaign patterns is like consulting a building code before designing a structure — you're not copying someone else's blueprint, you're inheriting decades of accumulated failure modes so you don't have to rediscover them yourself.

@card
id: aicr-ch09-c002
order: 2
title: API Migration at Scale
teaser: The shape of an API migration is always the same — find every call site, rewrite it to the new contract, and prove correctness with a typed build — but the bottleneck shifts depending on whether the API change is additive or breaking.

@explanation

The canonical example: Stripe's API versioning model, where major version upgrades (v1 → v2 payment intent signatures, webhook payload changes) touch hundreds of call sites spread across service layers. Payment API v1 → v2 migrations at mid-size companies often involve 80–200 files, 3–6 weeks of campaign work, and significant risk if a single call site is missed.

The pattern:

```text
Pattern: API Migration

Discovery  → ast-grep (or ts-morph) for old API identifiers, import paths, method names
Sample     → manually migrate 5 representative call sites (simple, complex, edge case)
Transform  → LLM with sample-derived prompt; batch by module or service boundary
Validate   → typed build catches wrong shapes; unit tests catch semantic errors
Review     → 5 % random sample + auto-flag any file where the LLM added new imports
Land       → PRs grouped by service or module; never one PR for the whole campaign
```

What goes wrong: the LLM assumes the new API signature from training data rather than from the actual SDK you're using. If you upgraded to a beta version or a fork, the model's knowledge is wrong and the typed build is the only net. Skipping the typed build and trusting unit tests alone catches shape errors late, after review, not before.

The tooling combination that works: ast-grep for deterministic discovery, LLM for per-call-site rewriting, the TypeScript compiler or a typed language's build for validation. Manual sampling before the batch run calibrates whether the prompt is accurate.

> [!warning] Never run the batch rewrite before validating the prompt on 5 representative files. A wrong prompt applied to 200 files produces 200 wrong diffs — and review becomes damage assessment, not quality control.

@feynman

An API migration campaign is like updating all the phone numbers in a contacts list after a company changes its area code — the pattern is identical for every entry, but you still need to check the edge cases before you automate the rest.

@card
id: aicr-ch09-c003
order: 3
title: Framework Upgrade Campaigns
teaser: Spring Boot 2 → 3, Rails 6 → 7, Next.js 13 → 14 all follow the same shape — use the framework's own codemod or migration recipe for the 70 % it can handle deterministically, then use an LLM for the residual.

@explanation

Framework upgrades are the clearest case for the hybrid approach. Every major framework ships migration tooling because the authors know exactly what changed and what needs to be rewritten:

- Spring Boot 3 ships OpenRewrite recipes (`org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_0`) that handle annotation renames, dependency changes, and configuration key migrations deterministically.
- Rails 7 ships upgrade notes and a `rails app:update` task that rewrites config files.
- Next.js 13 → 14 ships a codemod (`npx @next/codemod`) that handles app directory conventions, metadata API changes, and `next/link` behavioral updates.

The pattern:

```text
Pattern: Framework Upgrade

Codemods   → run the framework's own migration tooling first, commit the result
Audit      → review the list of files the codemod flagged as needing manual attention
Residual   → pass flagged files to an LLM with the upgrade guide as context
Validate   → full test suite; look for runtime behavior changes the typed build won't catch
Review     → manual review of LLM-touched files only; codemod-touched files get lighter scrutiny
```

What goes wrong: running the LLM first and the codemod second. The LLM produces plausible-looking output that overlaps with what the codemod would have done — but differently. You end up with two incompatible half-migrations applied to the same file and no clear winner. Always run the codemod first; the LLM handles only what the codemod left unresolved.

A second failure mode: treating the codemod's output as correct without running the test suite. Spring Boot 3 migrations break on classpath resolution and configuration property renames that OpenRewrite recipes do not cover.

> [!tip] Read the framework's official migration guide before writing any LLM prompt. The guide's list of breaking changes is better prompt context than your own summary of what you think changed.

@feynman

A framework upgrade campaign is like renovating a house with a contractor who gives you a standard renovation checklist — they handle the structural work that follows the building code exactly, and you call in a specialist only for the custom features that don't fit the standard plan.

@card
id: aicr-ch09-c004
order: 4
title: Dependency Replacement
teaser: Replacing Moment.js with date-fns, Lodash with native ES, or Enzyme with React Testing Library is harder than a find-and-replace because the replacement is rarely 1:1 and needs semantic understanding of what the old call was actually doing.

@explanation

The canonical examples: Moment.js was formally sunset in September 2020 and the ecosystem's migration to date-fns, Luxon, and Day.js has been running ever since. Lodash's migration to native array and object methods accelerated with ES2019+. Enzyme → React Testing Library has been the standard React test migration since enzyme's maintenance stalled in 2022.

What makes these hard: the replacement library does not expose the same surface. `moment(date).add(1, 'days').format('YYYY-MM-DD')` doesn't map to a single date-fns function call — it maps to `format(addDays(parseISO(date), 1), 'yyyy-MM-dd')`, and the format string tokens are different (lowercase `yyyy` not uppercase `YYYY`). An LLM can handle this; a text replacement tool cannot.

The pattern:

```text
Pattern: Dependency Replacement

Inventory  → find all imports of the old dependency; group by usage pattern
Map        → build a mapping of old-to-new idioms (5–10 common patterns, manually)
Transform  → LLM with the mapping as context; one file at a time for complex logic
Validate   → unit tests are the primary net; typed builds catch shape errors
Audit      → diff the old and new behavior on date/timezone edge cases specifically
Remove     → delete the old dependency from package.json only after zero remaining imports
```

What goes wrong: the LLM knows the target library's API from training data but doesn't know which version your project is using. date-fns v2 and v3 have breaking API changes. Pass the version explicitly in the prompt and verify the generated imports against the installed version.

A second failure mode for Enzyme → React Testing Library: LLMs default to `getByTestId` as a crutch. The RTL philosophy is `getByRole` and `getByLabelText` first. A migration that passes tests but uses `getByTestId` everywhere has technically landed but missed the point of the migration.

> [!warning] Validate date and timezone handling manually after any Moment.js migration. Format token differences (YYYY vs yyyy), timezone offset behavior, and locale handling are categories where LLM-generated replacements look correct but are semantically wrong.

@feynman

Replacing one dependency with another is like substituting one ingredient for another in a recipe — sometimes it's a 1:1 swap, but often the cooking time, the ratios, and the technique all need to change alongside it.

@card
id: aicr-ch09-c005
order: 5
title: Dead-Code Elimination at Scale
teaser: AST tools can prove a symbol is unreferenced; LLMs can understand whether a comment says "this is deliberately unused" or "we forgot about this" — you need both to eliminate dead code safely.

@explanation

Dead-code elimination at scale is the one pattern where combining AST tools and LLMs in sequence — rather than as a hybrid — is the right call. The two tools answer different questions.

AST tools (TypeScript's `noUnusedLocals` / `noUnusedParameters`, `knip`, `ts-prune`, Python's `vulture`, Java's IntelliJ "unused declaration" inspections) can prove a symbol has no call sites within the analyzed scope. They cannot tell you whether the symbol is an intentional public API kept for external consumers, a legacy shim kept for backward compatibility, or genuinely dead.

LLMs, given the code and its surrounding comments, can read intent — "this was kept for the v2 client migration that shipped in 2023; safe to remove now" is a judgment call an AST tool cannot make.

The pattern:

```text
Pattern: Dead-Code Elimination

Detect     → AST tool generates a list of unreferenced symbols
Filter     → remove symbols that are public API, exported, or marked @deprecated-but-keep
Contextualize → for each candidate, pass the symbol + its comments + git log to an LLM
Classify   → LLM classifies: safe-to-remove / needs-human-review / intentionally-kept
Remove     → apply removals in small batches; re-run the AST tool after each batch
Validate   → full test suite + integration tests; dead code that was secretly reachable will fail
```

The scale this applies to: companies with large, long-lived codebases — a 5-year-old TypeScript monorepo at a Series B startup can have 15–25 % of its symbols unreferenced according to static analysis. Eliminating it safely without an LLM to read context is possible but slow; teams often skip it entirely.

> [!info] "Safe to remove" and "unreferenced" are not the same thing. A symbol can be unreferenced in static analysis but used via dynamic dispatch, eval, or reflection. The LLM classification step should include a check for these patterns.

@feynman

Dead-code elimination is like clearing out a storage unit — a checklist tells you what's in the boxes, but only someone who remembers why things were put there can tell you whether to keep them or throw them away.

@card
id: aicr-ch09-c006
order: 6
title: Type-System Migration (JS to TS)
teaser: The Twitter/X JS-to-TS migration is the reference case for type-system adoption at scale — and the hard part isn't adding types, it's handling the inference where neither AST tools nor LLMs can be fully trusted.

@explanation

Twitter/X's migration of its large JavaScript codebase to TypeScript, and Microsoft's internal TS adoption programs, are the public reference cases. The shape: 10,000+ `.js` files, a years-long campaign, and a pattern that teams at 1/100th the scale repeat monthly.

The fundamental problem: TypeScript cannot always infer the right type from JavaScript code. The LLM can make a reasonable guess based on usage patterns and variable names, but inference-based guesses produce `any` propagation when the LLM is uncertain — which defeats the purpose.

The pattern:

```text
Pattern: JS → TS Migration

Rename     → rename all .js → .ts (or .jsx → .tsx); fix immediate compilation errors
Strict-off → set "strict": false initially to get a working baseline
LLM pass   → pass each file to an LLM to add types based on usage evidence in the file
any-audit  → grep for 'any'; each 'any' is a debt ticket, not an acceptable final state
Strict-on  → enable strict flags one at a time (strictNullChecks first)
Review     → 10 % sample; specifically look for inferred types that are wrong but pass tests
```

The partial-typing pattern: some teams adopt TypeScript incrementally using `// @ts-check` in JS files or `allowJs: true` in tsconfig. LLMs can annotate one file at a time without requiring the whole codebase to compile first. This is slower but more reviewable than a bulk migration.

What goes wrong: the LLM annotates function signatures based on what seems right from training data, not from your actual runtime behavior. A function that returns `string | null` in practice gets annotated as `string` because the null path is in a rarely-exercised branch. The type passes the compiler and fails in production.

> [!warning] Every `any` added during a JS → TS migration is a type debt item, not a resolved item. Track the count over time and treat it as a metric. A migration that completes with 800 `any` annotations has reduced noise but not gained safety.

@feynman

Migrating JavaScript to TypeScript is like converting a handwritten recipe into a standardized one — you can infer most of the measurements from the original text, but some amounts require you to cook it and measure what you actually used.

@card
id: aicr-ch09-c007
order: 7
title: Comment Translation and Improvement
teaser: LLMs are better at improving and translating comments than at almost any other refactoring task — because comments are natural language, and natural language is where LLMs have the clearest advantage over AST tools.

@explanation

Comment improvement is the most underrated campaign pattern. It doesn't ship features, but it removes the most common form of technical debt that slows onboarding and code review: comments that are wrong, outdated, or written in a language the current team doesn't read.

Three sub-patterns:

**Outdated comment cleanup:** A function comment written in 2018 describes behavior that was refactored in 2021. The LLM, given the comment and the current function body, can identify the mismatch and propose an updated comment. This is high-confidence LLM territory — the input and the correct output are both in context.

**Non-English comment translation at scale:** Companies that have acquired teams, offshored development, or gone through international mergers often have a significant percentage of comments in languages other than the codebase's working language. LLMs translate with high accuracy at the comment level, where the domain vocabulary is narrow and the stakes of mistranslation are low compared to translated function names.

**Comment density campaigns:** Some teams run a "comment the top 500 most-read functions" campaign before a major onboarding push. LLMs generate a first-pass JSDoc, RST, or docstring comment for each function, then engineers review before merging.

The pattern:

```text
Pattern: Comment Translation / Improvement

Identify   → find comments by age, language (langdetect), or absence of docstring
Generate   → LLM pass: produce updated or translated comment for each candidate
Review     → mandatory human review; LLM-generated technical comments must be verified
Land       → small, focused PRs; "update comments in auth module" not "update all comments"
```

What goes wrong: LLMs hallucinate function behavior when generating docstrings. A generated `@param` description that says "the user's email address" for a parameter that actually receives a user ID is worse than no comment — it actively misleads the next reader.

> [!tip] For docstring generation, always include the function's test cases in the LLM prompt context. Tests describe expected behavior more precisely than the function body alone, and they reduce hallucinated parameter descriptions significantly.

@feynman

Improving code comments with an LLM is like hiring a technical editor to review a manual — they can catch where the documentation no longer matches the product, but someone who built the product still has to verify every correction.

@card
id: aicr-ch09-c008
order: 8
title: Test-Suite Modernization
teaser: Jest → Vitest, RSpec Shoulda → RSpec expect syntax, JUnit 4 → JUnit 5 — test-suite migrations follow the same pattern as dependency replacement but with a narrower risk profile, because the test suite itself is the validation net.

@explanation

Test-suite modernization is dependency replacement applied to test infrastructure. The canonical examples:

- **Jest → Vitest:** Adopted heavily in Vite-based projects from 2023 onward. The API surface is nearly identical (`describe`, `it`, `expect`) but the module mocking APIs differ, ESM handling differs, and the configuration file format differs. A 500-test Jest suite typically takes 2–4 days of migration work with LLM assistance.
- **JUnit 4 → JUnit 5:** `@Test` becomes `@Test` (same name, different package import), `@Before` becomes `@BeforeEach`, `@RunWith` becomes `@ExtendWith`, and the assertion library often changes from Hamcrest to AssertJ. OpenRewrite ships a JUnit 5 recipe that handles the mechanical parts; LLM handles the complex Hamcrest → AssertJ rewrites.
- **RSpec syntax migrations:** Moving from `should` syntax to `expect` syntax (RSpec 3+) and from `stub` to `allow/expect(...).to receive` is a pattern that appeared in millions of Ruby projects between 2014 and 2020 and is still appearing in legacy codebases.

The unique property of test migrations: the test suite is both the subject of the migration and the validation net. You can run a subset of migrated tests as part of the batch to confirm they still pass. This makes the validation loop tighter than in production code migrations.

```text
Pattern: Test-Suite Modernization

Batch      → migrate one test file at a time, run it after each migration
Mechanical → codemod or OpenRewrite recipe for the import and assertion renames
LLM pass   → complex matchers, custom helpers, shared contexts that don't have a 1:1 mapping
Validate   → the migrated test must pass; a passing test after migration is the acceptance criterion
Land       → test files are low-risk PRs; larger batches are acceptable here than in production code
```

What goes wrong: Jest → Vitest mocking is the most common failure point. `jest.mock()` has different hoisting semantics than `vi.mock()`. LLMs trained on Jest-heavy data sometimes generate Jest-syntax mocks in Vitest files, which pass syntax checking but fail at runtime.

> [!info] Migrating tests is safer than migrating production code because the tests themselves tell you when the migration broke something. Use this to your advantage — migrate in small batches and run after each one, rather than migrating the whole suite and then running.

@feynman

Migrating a test suite is like renovating a kitchen while still having the kitchen validate every change — the room you're working on is also the quality control station, which is uncomfortable but actually safer than renovating with no feedback at all.

@card
id: aicr-ch09-c009
order: 9
title: Naming Convention Migration
teaser: Renaming everything from one convention to another sounds mechanical but is the campaign most likely to become a bikeshed — because names carry architectural meaning that a codebase-wide rename obscures until it's too late to reverse.

@explanation

Naming convention migrations come in three varieties with different risk profiles:

- **Mechanical cleanup** — renaming constants from `SCREAMING_SNAKE_CASE` to `camelCase` in JavaScript, removing Hungarian notation prefixes, fixing a consistent misspelling. Low semantic risk; the meaning doesn't change.
- **Architectural signal** — renaming `UserController` to `UserResource`, `Manager` to `Coordinator`, all `Service` classes to `Handler`. These changes encode a new architecture decision. Doing them mechanically without resolving the underlying architecture first creates a codebase where the names suggest one model but the behavior implements another.
- **Domain language alignment** — renaming all `Customer` references to `Client` or `Account` after a product pivot. High semantic value, high cross-team coordination cost.

The tooling combination:

```text
Pattern: Naming Convention Migration

Classify   → separate mechanical renaming from architectural renaming before starting
Scope      → agree in writing on the new convention before the first rename
Mechanical → LLM or ast-grep for purely stylistic renames (case, prefix removal)
Architectural → human-led, one module at a time; LLM assists but does not drive
Validate   → full test suite; grep for the old name to confirm no stragglers
```

What goes wrong: a naming campaign that starts as "rename snake_case to camelCase" drifts into "while we're here, rename `Processor` to `Handler`" and then "and maybe we should split this class." Each individual change seems incremental; collectively, the PR diff is unintelligible. Keep mechanical renaming and semantic renaming in separate PRs.

The honest question to ask before starting: is this a naming issue, or is it a design issue using names as a proxy? Renaming `OrderManager` to `OrderService` doesn't fix an `OrderManager` that has 40 methods and no clear responsibility.

> [!warning] Naming campaigns are the refactoring category most likely to generate team disagreement in code review. Agree on the new convention explicitly, preferably in a short ADR, before the first commit lands.

@feynman

A naming convention migration is like repainting all the road signs in a city — the work is mechanical, but you need to agree on the new signage standard before you start, because halfway through with two systems in use is worse than either one alone.

@card
id: aicr-ch09-c010
order: 10
title: License and Header Insertion at Scale
teaser: License header insertion is the smallest campaign pattern — but it is the best one for onboarding a new team to the mechanics of a refactoring pipeline, because the transform is trivial and the tooling setup is not.

@explanation

License header insertion is the simplest refactoring campaign: every source file in the repository needs a specific copyright notice or open-source license header at the top, and many don't have one. The transform is deterministic; an LLM is barely necessary.

Why it's worth knowing as a pattern:

- It's the lowest-risk campaign to run first in a team new to automated refactoring. The semantic risk is near zero; the only failure mode is formatting.
- It validates your entire pipeline — the discovery, transform, review, and land sequence — on a change where a mistake has no business impact.
- It has real business value: license compliance for enterprise open-source programs, consistent copyright attribution, FOSS license enforcement.

The pattern:

```text
Pattern: License / Header Insertion

Discover   → find all source files missing the expected header (grep or a lint rule)
Template   → define the exact header text, including year and copyright holder
Insert     → a simple script (or LLM for multi-language awareness) inserts at line 1
Review     → automated check: does the file now start with the expected string?
Land       → one PR per language type; keep the commit history clean for auditing
```

Where an LLM adds marginal value: handling polyglot repositories where the comment syntax differs by file type (Python `#`, Java `//`, XML `<!-- -->`). A small LLM pass to insert the header in the correct comment style for each file type is faster than maintaining a multi-language template script.

The pipeline validation argument: if your automated header insertion campaign produces inconsistent results, your discovery step is broken, your transform step is untested, or your review automation is wrong — and you've discovered this on a zero-risk campaign rather than on a framework upgrade.

> [!tip] Run the license insertion campaign first on a new codebase, not because headers are important, but because it validates the entire refactoring pipeline end-to-end with zero semantic risk.

@feynman

Running a license-header campaign before a complex refactor is like doing a fire drill before an actual emergency — the procedure is the same but the stakes are low enough that you can diagnose every breakdown in the process without consequence.

@card
id: aicr-ch09-c011
order: 11
title: Multi-Language Migrations
teaser: Python 2 → 3 is the historical reference case, CoffeeScript → TypeScript is the more recent one — both share the same lesson that multi-language migrations require a different risk model than same-language refactors.

@explanation

The reference cases:

- **Python 2 → 3** (2008–2020): The longest migration campaign in mainstream software history. `2to3` handled the mechanical changes (print statements, integer division, unicode literals, `dict.iteritems()` → `dict.items()`). LLMs were not available during most of this migration, but the pattern is clear in retrospect — `2to3` for the structural, human review for the behavioral differences (string/bytes boundary, exception chaining, changed exception hierarchies).
- **CoffeeScript → JavaScript/TypeScript** (2015–2021): CoffeeScript was transpiled; migrating to plain JS or TS meant reading the compiled output and reverse-engineering the intended source. LLMs are well-suited here because the semantic intent is preserved in the CoffeeScript but the idiomatic output in TS requires judgment the transpiler does not have.
- **Flow → TypeScript** (2018–present): Facebook's Flow type checker lost ecosystem momentum to TypeScript. `flow-to-ts` handles the annotation syntax changes mechanically; LLMs handle the Flow-specific constructs with no TS equivalent (opaque types, variance annotations).

The shared structure:

```text
Pattern: Multi-Language Migration

Transpile  → use the official or community transpiler/converter first
Residual   → identify what the transpiler left as TODO, error, or comment
LLM pass   → handle residual file by file; these are the judgment-heavy files
Idiomize   → second LLM pass to replace transpiler-native idioms with target-language idioms
Validate   → full test suite; a passing transpiler output may not be idiomatic
```

The lesson that transfers: every multi-language migration has a "transpiler output that works but reads like the source language." CoffeeScript-to-JS output in 2018 read like CoffeeScript written in JS syntax. A second idiomization pass — only feasible at scale with LLMs — is what produces code that reads like it was written in the target language.

> [!info] Flow → TS is still an active migration pattern in 2026 for companies that adopted Flow early and never migrated. The tooling has improved significantly since 2020 but the LLM residual pass remains necessary for complex generic types.

@feynman

A multi-language migration is like translating a novel first with an automated translator and then with a literary editor — the translator gets the meaning across, but the editor is what makes it read like it was written in the target language.

@card
id: aicr-ch09-c012
order: 12
title: The Campaign That Doesn't Fit a Pattern
teaser: When a campaign doesn't match any of the eleven patterns above, that's a signal worth heeding — either the scope is under-defined, you're over-fitting to a familiar pattern, or you're genuinely in novel territory that needs a different planning approach.

@explanation

Not every refactoring campaign fits a known pattern. The warning signs that you're either in a novel campaign or over-fitting an existing one:

- **The scope keeps expanding as you sample files.** You started thinking it was an API migration, but half the files require architectural changes that go beyond call-site rewrites. This is usually a sign the campaign is a refactor campaign disguised as a migration campaign.
- **The tooling combination from the nearest pattern keeps failing.** If you've run the framework upgrade pattern twice and the residual keeps exceeding 30 % of files, the campaign has more custom logic than the pattern assumed. You need a longer sample phase and a custom prompt, not a tighter application of the standard approach.
- **The review keeps surfacing unexpected categories of errors.** Pattern-matching campaigns produce predictable errors. If every 5 % sample review is surfacing a new category you hadn't planned for, the campaign shape is more complex than the pattern suggests.

How to invent your own pattern when needed:

```text
Pattern Invention

Sample     → hand-migrate 10 files before writing any automation
Categorize → group the sample into change types; name each type
Sequence   → decide which types can be automated and which need human work
Pilot      → automate one type; validate on 20 files before scaling
Iterate    → add types one at a time; never automate a type you haven't sampled
```

The over-fitting failure mode: teams that know the framework upgrade pattern sometimes force-fit a dependency replacement campaign into it. The codemod step doesn't exist (there's no official migration tool), so they skip it — but they keep the "run the codemod first" step mentally, which means they start with the LLM on all files and wonder why quality is low. The absence of a codemod step is itself information about the campaign's shape.

> [!info] The time you spend discovering that a campaign doesn't fit a known pattern is not wasted. A well-documented novel campaign becomes the pattern the next team reaches for when they face a similar problem.

@feynman

Encountering a refactoring campaign that doesn't fit any known pattern is like arriving at a city that doesn't appear on any map — the right move is to draw a careful map as you go, not to navigate by the closest map you already have.
