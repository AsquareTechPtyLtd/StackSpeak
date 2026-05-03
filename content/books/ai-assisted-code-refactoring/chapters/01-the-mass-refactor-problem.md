@chapter
id: aicr-ch01-the-mass-refactor-problem
order: 1
title: The Mass-Refactor Problem
summary: Some refactorings are too large to do by hand — and the historic toolchain of regex, codemods, and AST passes hits a ceiling that LLMs can finally cross when handled with discipline.

@card
id: aicr-ch01-c001
order: 1
title: When Refactoring Outgrows a PR
teaser: At some point a refactoring stops being a task and becomes a campaign — and the tools that work for one file simply do not scale to one thousand.

@explanation

Most refactorings you do daily are small: rename a method, extract a helper, inline a constant. A single PR, a few minutes of review, done. But a different class of refactoring exists — one where the change is structurally trivial per file but the sheer number of files makes a manual approach economically indefensible.

Call it a mass refactoring. The defining characteristic is not technical complexity but scale:

- A codebase with 100,000+ lines of code where every file touches a deprecated API
- A microservices estate with 100+ services that all need a common logging interface swapped out
- A monorepo migration that must rename, restructure, and re-type thousands of files simultaneously

Real campaigns that hit this threshold: Twitter/X's multi-year JS-to-TypeScript migration of a multi-million-line frontend codebase, Stripe's systematic API versioning refactors across hundreds of internal services, Google's large-scale C++ modernization passes across a monorepo that spans billions of lines.

The problem is not that the change is hard to make. The problem is that making it in 5,000 files by hand would take months, block other work, and inevitably produce inconsistencies. No one can justify that to their manager — so the refactoring never happens, and the technical debt compounds.

This book is about the tools and discipline that close that gap. The subsequent chapters cover prompt patterns (ch03), validation pipelines (ch04 and ch06), and risk management (ch08). This chapter frames the problem the entire toolchain is designed to solve.

> [!info] As of 2026-Q2 — the campaigns referenced here (Twitter/X, Stripe, Google) are widely cited in engineering literature and continue to shape how the industry thinks about large-scale refactoring tooling.

@feynman

A mass refactoring is like changing a single character in a contract template — trivial per page, but if you have ten thousand signed copies in filing cabinets, the logistics become the whole problem.

@card
id: aicr-ch01-c002
order: 2
title: Why Mass Refactorings Happen
teaser: Mass refactorings are not accidents — they are the accumulated cost of progress: frameworks evolve, security vulnerabilities are patched, type systems mature, and every one of those forces eventually touches every file in your codebase.

@explanation

Mass refactorings are almost always triggered by forces outside your codebase that impose a hard deadline or a hard ceiling:

- **Framework upgrades.** Moving from React 17 to React 18, Django 3 to Django 5, or Spring Boot 2 to Spring Boot 3 requires touching every component that uses a changed API — which is frequently most of them.
- **Deprecated API elimination.** A platform team deprecates an internal RPC framework in favor of gRPC. Every caller across 80 services needs updating before the old framework can be decommissioned.
- **Language-version migrations.** Python 2 to Python 3 was the canonical example for a generation. Kotlin-to-Swift migrations in mobile codebases follow the same pattern.
- **Security patches.** A cryptographic primitive is deprecated (e.g., SHA-1 is found unsafe); every place that touches it must be found and updated before the old library version reaches end-of-life.
- **Type system migrations.** Adding TypeScript types to a JavaScript codebase, adding type annotations to a Python 3.9 codebase with `mypy`, or enabling Swift's strict concurrency checking — each requires systematic changes to thousands of call sites.

The common thread: the trigger is external, the scope is systemic, and the change per file is often mechanical. That mechanical quality is exactly what makes automation relevant — and exactly what makes getting the automation wrong dangerous.

> [!warning] "Mechanical" does not mean "safe to skip review." A mechanical change applied incorrectly at scale multiplies one bug into every file you touched. The discipline this book builds toward assumes automation for reach and humans for validation, never automation for verification.

@feynman

A mass refactoring triggered by a deprecated API is like a building code change that requires every structure built before 1990 to add a fire-suppression system — the rule is the same for every building, but executing it across an entire city is a logistics and inspection problem, not a construction problem.

@card
id: aicr-ch01-c003
order: 3
title: Regex and sed — The First Tool, and Its Failure Mode
teaser: Regex is where every engineer's instinct goes first for text replacement at scale, and where the first lesson about the limits of pattern matching gets learned the hard way.

@explanation

The instinct is understandable: `sed -i 's/oldFunction/newFunction/g' **/*.ts` looks like it does exactly what you want. And for a trivial rename in a consistent codebase, it often does.

The failure modes arrive quickly once your patterns involve:

- **Context sensitivity.** `oldFunction` as a string literal, a comment, a variable name in a test fixture, and an import path may all match the same regex but require different handling.
- **Multiline constructs.** A function call spread across four lines does not match a single-line pattern.
- **False positives.** `userId` and `getUserId` both contain `id`. `s/import React/import React, { useState }/` breaks files that already import `useState`.
- **Silent partial matches.** A regex that is 95% correct produces a codebase that is 95% migrated, which looks like success until the 5% surfaces as runtime errors weeks later.

The deeper problem is that regex operates on bytes, not on meaning. It has no model of what a function call is, what a type annotation means, or whether two uses of the same string are semantically equivalent. Every regex-based refactoring campaign accumulates exceptions that must be handled by hand.

```bash
# The archetypal sed refactor — seductive in its simplicity
sed -i '' 's/require("lodash")/import _ from "lodash"/g' src/**/*.js
# Fails on: require('lodash'), require( "lodash" ), dynamic requires
```

> [!warning] As of 2026-Q2 — regex refactoring remains widely used and is appropriate for genuinely trivial renames in small, consistent codebases. The failure modes above are not hypothetical; they are the reason the entire subsequent toolchain exists.

@feynman

Using regex to refactor code is like using find-and-replace to edit a contract — it works fine on simple phrases, but as soon as the same word appears in a different legal context, the replacement produces nonsense that looks correct until a lawyer reads it.

@card
id: aicr-ch01-c004
order: 4
title: Codemods and AST Tools — Structural Refactoring
teaser: Codemods operate on the parse tree rather than raw text — which eliminates most false-positive failures and handles the multiline and context cases that sink regex, up to the limit of what the grammar knows.

@explanation

The step up from regex is operating on an Abstract Syntax Tree (AST): a structured representation of code that knows the difference between an identifier in a function call, an identifier in a string literal, and an identifier in a comment.

The main tools in this space:

- **jscodeshift** — Facebook's JavaScript/TypeScript codemod runner. You write a transform function that receives an AST, manipulates it with the `jscodeshift` API, and returns the modified AST. It handles formatting preservation reasonably well. Used extensively for React API migrations.
- **ast-grep** — A newer, language-agnostic structural search-and-replace tool that uses tree-sitter grammars. You write patterns in the target language's syntax, not in regex. Supports JavaScript, TypeScript, Python, Go, Rust, Java, and more.
- **Comby** — A structural search-and-replace tool that works at a higher level of abstraction than regex — it understands balanced delimiters, language structure, and whitespace variability without requiring a full AST.
- **Semgrep** — Primarily a static analysis tool, but its pattern-matching engine is powerful enough for systematic transformations, and it has pre-built rulesets for common migration patterns.

```bash
# ast-grep structural replacement — matches regardless of whitespace/formatting
ast-grep --pattern 'console.log($MSG)' --rewrite 'logger.info($MSG)' --lang ts
```

The ceiling: AST tools are excellent when the refactoring is syntactically expressible — a rename, a call-site transformation, a wrapper addition. They struggle when the correct transformation depends on runtime behavior, cross-file type information, or semantic intent that isn't encoded in the syntax.

> [!info] As of 2026-Q2 — ast-grep has gained significant adoption as a faster, language-agnostic alternative to jscodeshift for projects that don't want to write full transform functions. Semgrep's autofix capabilities have expanded, though it remains primarily positioned as a linter.

@feynman

A codemod is like a mail-merge template that understands the grammar of the document it's editing — instead of blindly replacing words, it knows the difference between a name in the address block and the same name in the body text.

@card
id: aicr-ch01-c005
order: 5
title: OpenRewrite — Platform-Scale Refactoring for the JVM
teaser: OpenRewrite is what happens when you take the codemod idea seriously at enterprise scale — a recipe-based framework that parses, transforms, and emits code with type resolution, cross-file awareness, and a growing catalog of first-party migrations.

@explanation

OpenRewrite (openrewrite.org) is a refactoring framework built around the concept of lossless semantic trees — ASTs enriched with type attribution and cross-file knowledge. A recipe is a composable unit of transformation: it can be a single rule or a composition of dozens.

What makes OpenRewrite distinct from jscodeshift or ast-grep:

- **Type-attributed trees.** OpenRewrite resolves types across the full classpath. It knows that a `List` in one file is `java.util.List`, not `com.example.util.List`, and applies transformations accordingly.
- **Cross-file consistency.** A recipe that renames a method can update every call site across the entire project in one pass, including generated code and test fixtures.
- **First-party migration recipes.** The OpenRewrite catalog includes curated recipes for Spring Boot 2 → 3 migrations, JUnit 4 → 5, Jakarta EE namespace changes, log4j → SLF4J, Java 8 → 17 idiom upgrades, and more.
- **Build tool integration.** It runs as a Maven or Gradle plugin — no separate toolchain installation beyond your existing JVM build.

```bash
# Run the Spring Boot 3 migration recipe
./mvnw rewrite:run -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-spring:LATEST \
  -Drewrite.activeRecipes=org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_0
```

The ceiling: OpenRewrite is JVM-first. Python, Go, JavaScript, and Rust support exists but is significantly less mature. It also cannot handle migrations where the correct transformation requires understanding runtime semantics, business logic, or intent that isn't derivable from the type system.

> [!info] As of 2026-Q2 — OpenRewrite's Java and Kotlin support is production-grade and widely used. Its non-JVM language support (Python, JavaScript) is under active development but not yet comparable in depth.

@feynman

OpenRewrite is like a code migration contractor who has already performed the same renovation on three hundred buildings of the same architectural style — they show up with pre-built templates, know where all the load-bearing walls are, and can complete the job systematically rather than improvising from scratch.

@card
id: aicr-ch01-c006
order: 6
title: Where Deterministic Tools Hit a Wall
teaser: Every deterministic tool — regex, codemod, AST transformer, OpenRewrite recipe — operates on structure; once the correct transformation depends on semantic intent rather than syntactic shape, the toolchain stalls.

@explanation

Deterministic tools are reliable because they apply the same rule to every match. That reliability is also their ceiling: the rule must be expressible as a pattern over code structure.

The transformations that fall outside that ceiling:

- **Behavior-equivalent rewrites.** Converting a `for` loop to a `stream().map().filter().collect()` chain is not syntactically mechanical — it requires knowing that there are no side effects in the loop body that break stream semantics. A codemod cannot safely make that judgment.
- **Cross-language migrations.** Moving a service from Python 2 to Kotlin, or from JavaScript to TypeScript with meaningful types (not `any`), requires understanding the semantics of the original code, not just its structure.
- **Idiom modernization.** Replacing callback patterns with async/await, upgrading defensive null checks to optional chaining, converting class-based components to hooks — each has structural signatures but also semantic edge cases that patterns miss.
- **Intent-dependent naming.** A function called `getData` in one context means "fetch from API" and in another means "parse from cache." A rename that doesn't understand the distinction produces code that compiles but misbehaves.

The signal that you've hit this wall: your codemod has a growing exception list. Every new exception is a file that required human judgment, and the number of such files determines whether automation was net positive.

> [!tip] Track your exception rate during pilot runs. If more than 5-10% of matched sites require manual intervention, you are likely at or past the deterministic ceiling for that specific transformation. That is the point where LLM assistance becomes cost-effective.

@feynman

Deterministic tools hit their wall at the same place a spell-checker does — they can find words that are wrong by the rules, but they cannot tell you when a grammatically correct sentence means the opposite of what you intended.

@card
id: aicr-ch01-c007
order: 7
title: The Cost-of-Attempt Asymmetry
teaser: The refactorings that would save the most time long-term are often the ones that never get started, because the upfront cost of a manual 10,000-file migration is impossible to justify against a speculative future benefit.

@explanation

There is a perverse economic asymmetry in large refactorings: the cost is concrete, immediate, and attributable to a team; the benefit is diffuse, future, and shared across the whole organization.

A manual migration across 10,000 files might take 6 engineer-months. The team that does it might see no direct benefit in their roadmap — the benefit accrues to every team that no longer has to work around the old API. No rational team lead volunteers for that trade.

This asymmetry explains:

- Why deprecated APIs persist for years after the deprecation notice appears
- Why "we should really upgrade to X" becomes a standing agenda item that never moves
- Why the technical debt compounds: every month the migration doesn't happen, more code is written against the old API, and the migration scope grows

The calculus changes when the marginal cost of the migration drops by an order of magnitude. If a well-designed LLM-assisted pipeline can do the mechanical portion of a 10,000-file migration in hours rather than months — with human review concentrated at choke points rather than spread across every file — the economics shift from "unjustifiable" to "obvious."

That is the actual argument for LLM-assisted refactoring. Not that LLMs are magic. Not that they replace engineers. That they compress the cost-of-attempt far enough to make previously uneconomic refactorings viable.

> [!info] As of 2026-Q2 — the cost reduction claim is real but varies sharply by refactoring type. The chapters on validation pipelines (ch04) and risk management (ch08) address how to measure whether a given campaign actually achieved the cost reduction before you commit to scale.

@feynman

The cost-of-attempt asymmetry is the same reason city infrastructure maintenance gets deferred — the pothole costs pennies to fill today and dollars to repair the car it damages next year, but the budget for today is more visible than the damage next year.

@card
id: aicr-ch01-c008
order: 8
title: What LLMs Actually Unlock
teaser: LLMs bring semantic understanding to pattern matching — they can recognize what a piece of code is trying to do, not just what it looks like, which is exactly the capability that deterministic tools lack at the wall.

@explanation

The capability LLMs add is not raw transformation speed — codemods are faster at pure find-and-replace. What LLMs add is the ability to match on intent rather than shape:

- **Flexible pattern matching.** An LLM can identify all the places in a codebase that implement a "retry with exponential backoff" pattern, regardless of whether they look like a for-loop, a while-loop, a recursive function, or a third-party library call. No AST pattern captures all of those.
- **Context-sensitive transformation.** Given surrounding code, an LLM can judge whether a `getData` function is fetching from an API or reading from a cache, and apply the appropriate rename.
- **Natural language specification.** You can describe the transformation in plain English ("convert all Promise chains to async/await, but preserve .catch() handlers that log errors without re-throwing") rather than encoding it as a tree pattern. This dramatically lowers the barrier to expressing complex migrations.
- **Cross-language understanding.** An LLM that understands both Python and Kotlin can produce a semantically equivalent migration rather than a structural transliteration.

The cost: LLMs are probabilistic. The same prompt, given twice, may produce different outputs. They hallucinate APIs that don't exist. They silently introduce semantic drift. None of these are reasons to reject LLM-assisted refactoring — they are reasons to build validation pipelines around it. Chapter 06 covers this in detail.

> [!warning] As of 2026-Q2 — no current model (Claude 4.x, GPT-5, Gemini 2.x) is reliable enough to apply LLM-generated refactoring changes directly to production without automated testing and human review at choke points. The discipline is non-negotiable.

@feynman

LLMs unlock what pattern matching cannot, in the same way a seasoned editor unlocks what spell-check cannot — the spell-checker finds rule violations, but the editor understands what you were trying to say and whether you said it.

@card
id: aicr-ch01-c009
order: 9
title: Campaign vs Change — The Structural Difference
teaser: A mass refactoring is not a large change request — it is a project with distinct phases, each of which can fail independently, and treating it as a single PR is the first and most common mistake.

@explanation

A typical feature PR has a simple lifecycle: write, review, merge. A mass refactoring campaign has a different structure entirely:

1. **Discovery.** Map the full scope of the change. How many files? How many distinct patterns? Are there outliers that require non-mechanical treatment? This phase often reveals that the estimated scope was wrong by a factor of two.
2. **Sample.** Apply the transformation to a small, representative subset — say 50-100 files across different modules. Run the test suite. Look for surprises. This is your cheapest opportunity to find out that the approach is wrong.
3. **Plan.** Decide on batch size, validation gates, rollout order (leaf dependencies before core libraries), and the manual review criteria that qualify a batch for merge.
4. **Execute in batches.** Not one PR with 10,000 files. Multiple PRs, each small enough to be reviewed, each gated on passing tests, each isolated enough to roll back without cascading.
5. **Validate.** Automated tests cover the mechanical correctness. Human reviewers cover the choke points — the files where the transformation was ambiguous, the interfaces between modules, the high-traffic paths.
6. **Land and clean up.** Merge in dependency order. Remove compatibility shims. Remove the old API once all callers are migrated.

This structure is what distinguishes a successful mass refactoring from an abandoned one. The campaigns that fail are almost always the ones that tried to do discovery, sampling, planning, execution, and validation in a single heroic effort.

> [!tip] Chapters 04 and 06 go deep on the execution and validation phases respectively. This campaign structure is the skeleton both chapters assume.

@feynman

A mass refactoring campaign is structured like a construction project, not like a task — no one builds a skyscraper by combining all the work into a single uninterrupted effort, and no one should migrate 10,000 files without a plan, phases, and inspection points.

@card
id: aicr-ch01-c010
order: 10
title: The New Failure Modes LLMs Introduce
teaser: LLMs eliminate some failure modes from the deterministic toolchain and introduce new ones — and the new ones are more dangerous because they are harder to detect.

@explanation

The failure modes of regex and codemods are usually loud: the diff looks wrong, the tests fail, the code doesn't compile. The failure modes of LLM-generated refactoring are often silent:

- **Silent semantic drift.** The generated code compiles, the tests pass, and the behavior is subtly different from the original in a way that only manifests under a specific input condition or at a specific load level. This is the most dangerous failure mode because it survives automated validation and reaches production.
- **Hallucinated APIs.** LLMs confidently produce code that references library methods, configuration keys, or environment variables that do not exist. The code looks correct, even to a reviewing engineer who isn't deeply familiar with the library.
- **Inconsistent style across batches.** Batch 1 of your migration uses one idiom for async error handling; batch 2 uses a different one because the context window for batch 2 didn't include the example from batch 1. The resulting codebase is internally inconsistent in ways that accumulate into maintenance debt.
- **Context window truncation.** A long file passed to an LLM may be transformed correctly in the first half and incorrectly in the second half because the model lost the context established at the start.
- **Prompt sensitivity.** Small changes in how you describe the transformation produce meaningfully different outputs. A pipeline that was working at file 500 may drift at file 5,000 as edge cases accumulate.

None of these are arguments against LLM-assisted refactoring. They are arguments for the validation infrastructure described in chapters 04 and 06 — specifically, why testing after LLM transformation must be more rigorous than testing after deterministic transformation.

> [!warning] As of 2026-Q2 — silent semantic drift is the failure mode the field is least well-equipped to catch automatically. Behavioral testing (not just compilation and unit tests) is the best current mitigation, and chapter 06 covers the techniques in detail.

@feynman

LLM failure modes are like the errors a confident but slightly misinformed colleague introduces into a document they've edited — the grammar is fine, the writing is fluent, and the factual mistake is invisible until someone with domain expertise reads it carefully.

@card
id: aicr-ch01-c011
order: 11
title: Why 2026 Specifically
teaser: The convergence of capable enough models and deep enough IDE integration is recent — two years ago, LLM-assisted mass refactoring was an interesting research idea; today it is a repeatable engineering practice.

@explanation

Two independent developments matured in roughly the same 24-month window and made this book possible rather than premature:

**Model capability.** The gap between "can produce plausible-looking code" and "can reliably produce semantically correct code for complex refactoring tasks" closed significantly between 2024 and 2026. Context window size scaled from ~32K tokens to 1M+ tokens, which means an entire service (not just a single file) can be passed in a single call with room for the full transformation prompt. Code-specific benchmarks (HumanEval, SWE-bench) show sharp improvements across the same period.

**IDE and toolchain integration.** LLM assistance moved from chat interfaces that required copy-pasting code to native integration with the tools engineers already use: inline suggestions in VS Code and JetBrains, context-aware agents that can read and write files, run tests, and iterate — without the engineer leaving their editor. A mass refactoring pipeline in 2024 required custom scripting to glue together API calls, file I/O, and test runners. In 2026, the same pipeline is expressible in a few dozen lines using existing agentic tooling.

The combination — models capable enough to produce reliable refactoring output, and tooling integrated enough to run it at scale — is what defines the current moment. This book is not a projection of future capability; it is a description of what is repeatable today, with honest notes about where the edges still are.

> [!info] As of 2026-Q2 — the model and tooling landscape referenced here is moving fast. The refreshCadence for this book is 9 months, and the tool-specific chapters (ch02 through ch05) are the most likely to need updating. The structural principles in this chapter are more durable.

@feynman

The right moment to write a book about using a new tool is not when the tool first appears, but when using it reliably has become learnable — the same reason books about Git emerged years after its release, once the workflows had been discovered by practice.

@card
id: aicr-ch01-c012
order: 12
title: The Discipline This Book Builds
teaser: The promise of LLM-assisted mass refactoring is only redeemed if you treat the LLM as one component in a validated pipeline — not as a solution, but as a capable, fallible collaborator that needs mechanical checks at every step.

@explanation

Every chapter in this book is an instance of the same principle: compress the cost of a mass refactoring campaign by automating reach, while protecting correctness through mechanical validation and human review at choke points.

The specific disciplines:

- **Small batches.** Never ask an LLM to transform your entire codebase in one call. Batch by file, by module, or by service boundary. Smaller batches fail narrowly, are easier to review, and are easier to roll back.
- **Mechanical validation after every batch.** Compilation, type-checking, and unit tests are the floor. They catch hallucinated APIs and syntax errors. They do not catch semantic drift — which is why behavioral tests and diff review matter too.
- **Human review at choke points, not everywhere.** Mass refactoring produces too many diffs for humans to read every line. Concentrate human review on the interfaces, the high-traffic paths, and the files where automated validation gave ambiguous signals.
- **Idempotent transforms.** Design your prompts and your pipeline so that re-running them produces the same result. This makes partial failures recoverable.
- **A pilot before a campaign.** Apply the full pipeline to a small, throwaway subset first. The pilot reveals miscalibrated prompts, unexpected edge cases, and validation gaps before they appear at scale.

This book does not promise that following these disciplines makes LLM-assisted refactoring risk-free. It promises that following them makes the risk manageable and the outcome auditable — which is the best you can claim for any tool applied at mass scale.

> [!tip] If you take one thing from this chapter before reading the rest: the discipline is not optional overhead that slows you down. It is the mechanism that makes the speed sustainable. Campaigns that skip the validation infrastructure are the ones that produce a codebase that is faster to have and harder to trust.

@feynman

The discipline around LLM-assisted refactoring is the same discipline a structural engineer applies when using new materials — you test the material under controlled conditions, you don't rely on it for load-bearing work until you understand its failure modes, and you inspect the structure after installation even if you trust the material.
