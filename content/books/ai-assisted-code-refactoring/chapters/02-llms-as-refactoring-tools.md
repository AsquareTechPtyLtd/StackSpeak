@chapter
id: aicr-ch02-llms-as-refactoring-tools
order: 2
title: LLMs as Refactoring Tools
summary: LLMs are a new category of refactoring tool — flexible enough to handle semantic transforms that AST-based tooling can't, but probabilistic in ways that demand new validation discipline.

@card
id: aicr-ch02-c001
order: 1
title: What an LLM Actually Does at Refactor-Time
teaser: An LLM doesn't read your code the way you do — it predicts the next token, conditioned on everything in its context window, and produces output that looks like a refactor.

@explanation

When you send a function to Claude Sonnet 4.6 or GPT-5 and ask it to "convert to async/await," no internal AST is built. No semantic model of your codebase is constructed. The model generates tokens, one at a time, each conditioned on the prompt plus all prior output. The result looks like code because it was trained overwhelmingly on code, and because the surrounding context — your function signature, your variable names, your comments — strongly constrains what a plausible completion looks like.

This matters because it explains the failure modes. The model doesn't know your function calls an API that doesn't support async. It doesn't know your project uses a custom event loop. It doesn't know the import you need doesn't exist in the version you're on. It generates what is statistically plausible given what it can see, and what it can see is limited to the context window.

Two things follow from this:

- **The quality of the output is almost entirely a function of the quality of the context.** A refactor prompt that includes the relevant type signatures, the surrounding call sites, and the module's import section will produce better output than one that includes only the function body.
- **The model can be confidently wrong.** It won't hedge; it will produce syntactically valid, structurally plausible code that silently drops a behavior, invents an API method, or uses a renamed parameter. "Confident and wrong" is the characteristic failure mode, not "obviously broken."

> [!warning] LLMs do not verify their output against a running environment. A refactor that compiles cleanly can still be semantically incorrect. Your test suite is the only ground truth.

@feynman

An LLM refactoring your code is like a very well-read intern who has read millions of pull requests but has never actually run your test suite — the output looks plausible, but plausible is not the same as correct.

@card
id: aicr-ch02-c002
order: 2
title: Deterministic vs Probabilistic Transforms
teaser: The fundamental split in refactoring tools: rename a symbol in an IDE and the result is guaranteed; ask an LLM to "simplify this function" and you get a sample from a distribution.

@explanation

Deterministic transforms have exactly one valid output for a given input. Your IDE's rename refactoring changes every reference in the project, respecting scope rules, and nothing else. jscodeshift codemods apply a fixed AST transformation: input A always produces output B. ast-grep pattern matches with surgical precision. These tools produce the same result every time you run them, and you can verify correctness by checking that the AST shape changed exactly as intended.

Probabilistic transforms do not. Ask Claude Opus 4.7 to "extract the validation logic into a separate function" and you get one sample from the space of all plausible completions. Run it again and you may get a different function name, a different parameter order, or a different edge-case handling. The temperature setting controls how concentrated or diffuse the distribution is, but even at temperature 0 you are not guaranteed identical outputs across model versions or system prompt variations.

The practical split:

- **Deterministic:** Symbol rename, extract method with a specified name, move class, change signature mechanically — anything where the transform is fully specified and scope-aware.
- **Probabilistic:** Improve naming, translate idioms, port to a different language, add documentation, convert callback to async/await where the semantics require judgment about intent.

Neither category is superior. Deterministic tools are appropriate for exact structural transforms; probabilistic tools are appropriate for transforms that require semantic judgment. The error is using one where the other is warranted.

> [!info] As of 2026-Q2 — "temperature 0" does not mean the same thing across providers. Anthropic and OpenAI both reserve the right to introduce non-determinism at the infrastructure level (load balancing, sampling implementation). Same temperature, different runs, occasionally different outputs.

@feynman

A deterministic refactor is like a precision lathe cutting to a fixed spec — the part is always the same; a probabilistic refactor is like asking a skilled machinist to "make it look cleaner" — the result depends on their judgment that day.

@card
id: aicr-ch02-c003
order: 3
title: Where LLMs Beat AST Tools
teaser: The cases where LLMs outperform structured tools are real — cross-language ports, naming improvements, and comment-aware rewrites are things no AST tool can do well.

@explanation

AST tools operate on syntax trees. They are excellent at transforming code whose structure is known, unambiguous, and fully within one language. They cannot cross language boundaries, they cannot improve names, and they have no concept of what a comment says.

LLMs handle several classes of transform that AST tools cannot:

- **Cross-language ports.** Translating Python business logic to Go, or a JavaScript utility to Rust, requires understanding intent, not just syntax. Claude Opus 4.7 with a full context window and the source idioms visible routinely produces usable first drafts of these ports — drafts that would take a human hours to write from scratch.
- **Naming improvements.** Renaming `d` to `durationMs` or `tmp` to `filteredCandidates` is a semantic operation that requires understanding what the variable holds. No AST tool can infer that; an LLM conditioned on the surrounding code often can.
- **Idiom translation.** "Rewrite these three nested if-statements as a guard clause pattern" is a structural pattern humans recognize as idiomatic but that no codemods encode for arbitrary cases.
- **Comment-aware refactoring.** If a comment describes intended behavior that the code violates, an LLM can notice the discrepancy. An AST tool ignores comments entirely.
- **Context-spanning cleanup.** When the smell crosses function or file boundaries in ways that resist mechanical pattern-matching, an LLM with sufficient context can identify and restructure it.

The failure mode: LLMs invent. A cross-language port may use a standard library function that doesn't exist in the target language's version you're on. A naming improvement may produce a name that collides with an existing symbol. Verify every LLM output against the target environment.

> [!tip] Use LLMs for the "judgment" layer — naming, intent translation, idiom normalization — and use AST tools for the structural plumbing. They're better together than either is alone.

@feynman

An AST tool is a perfect typist — it changes exactly the characters you specify; an LLM is a translator — it can carry meaning across languages and styles, but it can also make a translator's mistakes.

@card
id: aicr-ch02-c004
order: 4
title: Where AST Tools Still Win
teaser: For single-language structural changes where exact semantic preservation is the requirement, AST tools are safer, faster, and cheaper than any LLM.

@explanation

The case for AST tools is not nostalgia — it's precision. When you need to rename a symbol across 40,000 files in a Go monorepo, `gorename` does it correctly or fails loudly. It doesn't drift. It doesn't invent an intermediate variable. It doesn't hallucinate that a method exists on a type where it doesn't. The transform is either correct or an error.

The categories where AST tools are the right default:

- **Symbol rename in a statically-typed language.** TypeScript Language Server, gopls, rust-analyzer — all of these perform rename operations with full scope awareness. An LLM producing a global find-and-replace across a large codebase will miss shadowed variables and generate false positives.
- **Mechanical signature changes.** Adding a required parameter to a function used in 200 places is a structural transform with a known shape. jscodeshift or ast-grep with a pattern rule is faster, auditable, and deterministic.
- **Import organization and dead code removal.** Tools like `goimports`, TypeScript's `organizeImports`, or `autoflake` for Python do this precisely and at zero per-token cost.
- **Formatting normalization.** Prettier, gofmt, rustfmt. No LLM should be in this loop.

The cost argument matters at scale. Passing 40,000 files through Claude Sonnet 4.6 at current pricing to fix import ordering is expensive and slower than a one-second CLI run. Use the right tool for the cost profile, not just the capability profile.

> [!info] As of 2026-Q2 — Comby is underused for structural search-and-replace in mixed-language codebases. It operates on syntax patterns without a full AST and handles cases that simple regex cannot, without the overhead of a full language-specific toolchain.

@feynman

Using an LLM to rename a symbol in a statically-typed language is like hiring a human translator to re-typeset a document — they can do it, but a printer already solved this problem without the translation cost.

@card
id: aicr-ch02-c005
order: 5
title: The Hybrid Pattern
teaser: The most reliable large-scale refactors combine both: use an AST tool for the structural transform, then pass the result to an LLM for naming normalization and edge-case cleanup.

@explanation

Neither AST tools nor LLMs are universally better. The productive pattern is sequencing them by what each does well.

A worked example: you're migrating a Python codebase from `requests` to `httpx` with async support.

1. **AST tool first.** Use a jscodeshift-equivalent (libcst in Python, for example) to mechanically replace `import requests` with `import httpx`, swap `requests.get(url)` for `httpx.get(url)`, and flag every call site for manual attention. This step is deterministic and reviewable.
2. **LLM second.** Pass each flagged function to Claude Sonnet 4.6 with the context: "This function was synchronous and used requests. Convert it to use async httpx. The calling code already uses async/await." The LLM handles the semantic judgment — where to add `await`, how to handle connection pooling configuration, what to do with the `Session` object pattern.
3. **AST tool for verification.** Re-run a static analysis pass to confirm all call sites were converted and no synchronous `requests` calls remain.

This sequence gets you the precision of deterministic tooling for the structural plumbing and the semantic flexibility of an LLM for the judgment layer, while using each tool only where it has an advantage.

The failure mode of the hybrid pattern is losing track of which changes came from which step. Commit the AST-tool output as a separate commit before running the LLM pass. This makes the LLM's diff reviewable in isolation.

> [!tip] Commit after each tool's pass. A three-step migration with three commits is dramatically easier to review and revert than a single commit mixing mechanical and semantic changes.

@feynman

The hybrid pattern is like using a CNC machine to cut the rough shape and then a skilled craftsperson to finish the edges — each handles the part of the work it's built for.

@card
id: aicr-ch02-c006
order: 6
title: Context Window Realities
teaser: What the model can see determines what it can refactor correctly — and the gap between "file-level context" and "project-level context" is where most production hallucinations originate.

@explanation

Context window sizes have expanded dramatically. As of 2026-Q2, Claude Opus 4.7 and Sonnet 4.6 support 200K tokens; GPT-5 supports comparable context; Gemini 2.x leads with 1M+ tokens in certain configurations. In token terms, 200K tokens is roughly 150,000 words, or about 5,000–8,000 lines of code depending on density.

This sounds large until you load a real codebase. A mid-size service with its models, services, controllers, test files, and configuration is easily 50,000+ lines. A monorepo is orders of magnitude more. The model sees a slice, not the whole.

The practical consequences:

- **Type drift.** If the type definition for a struct or interface is not in the context window, the model will invent one based on usage patterns. The invented type may be close enough to compile but wrong enough to fail at runtime.
- **The needle-in-a-haystack problem.** Empirical research (including on Claude models specifically) shows that retrieval accuracy degrades when relevant context is buried deep in a large window. A 200K-token context where the key interface definition appears at position 150K is less reliable than a 20K-token context where it appears near the top.
- **Import paths.** Third-party packages, internal packages, and aliased imports that are not in the context window get invented. The invented path looks plausible but doesn't exist.

The mitigation is not "use a bigger context window" — it's "curate the context deliberately." Include type definitions, import sections, call sites, and tests for the code you're refactoring. Exclude unrelated files.

> [!info] As of 2026-Q2 — larger context windows are available but not free. A 200K-token request to Claude Opus 4.7 costs significantly more than a 20K-token request. Curation pays for itself both in cost and in output quality.

@feynman

A model with a 200K-token context window looking at your codebase is like a researcher reading a chapter from a book they've never seen — they can work with what's on the page, but they'll invent anything the page doesn't tell them.

@card
id: aicr-ch02-c007
order: 7
title: Hallucination Patterns Specific to Refactoring
teaser: LLM hallucinations during refactoring have recognizable shapes — invented APIs, wrong import paths, type-hint drift, and silently dropped behavior are the four patterns you'll encounter repeatedly.

@explanation

General hallucination in LLMs is well-documented. Refactoring introduces a specific set of failure modes worth knowing by name so you can check for them systematically.

**Invented APIs.** The model generates a method call that doesn't exist on the type, or uses a function from a library version you don't have. Example: `df.to_parquet(engine="pyarrow", schema=schema)` — the `schema` parameter exists in some versions, not others. The model produces what looks like valid usage without knowing your version.

**Wrong import paths.** Internal package paths that weren't in the context get invented. `from myapp.utils.validators import validate_email` becomes `from myapp.validation.email import validate_email` — plausible, wrong. This is especially common in monorepos where module paths are deep and non-obvious.

**Type-hint drift.** The refactored function's type signature diverges from the original — a `str | None` becomes `Optional[str]`, a `list[dict]` becomes `List[Dict[str, Any]]`, a specific enum type becomes a generic `str`. Each individually looks reasonable; collectively they introduce type inconsistencies that mypy or pyright will catch, but only if you run them.

**Silently dropped behavior.** The most dangerous pattern. The model restructures a function and omits a branch — an error handler, a null check, a logging call, a metric increment. The output is syntactically correct and functionally plausible but the removed behavior was real. Tests catch this; code review frequently misses it because the new code looks clean.

> [!warning] "Silently dropped behavior" is the failure mode least likely to be caught in review and most likely to cause production incidents. Run your full test suite on every LLM-produced refactor before merging.

@feynman

LLM hallucinations during refactoring are like a copyeditor who, while cleaning up your prose, accidentally removes the paragraph that contained the punchline — the result reads smoothly and misses the point.

@card
id: aicr-ch02-c008
order: 8
title: Determinism Strategies
teaser: Getting repeatable output from an LLM requires deliberate configuration — temperature 0 is the baseline, but it's not sufficient on its own.

@explanation

When you're running a refactor across hundreds of files, inconsistency compounds. Two files with identical patterns should produce identical transformed output. Achieving this requires understanding what actually controls LLM output variance.

**Temperature 0.** The primary lever. Setting temperature to 0 forces the model toward the highest-probability token at each step, producing the most consistent output for a given input. For refactoring tasks, this should always be your default.

```python
# Anthropic Messages API — temperature 0 for deterministic output
import anthropic

client = anthropic.Anthropic()
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=4096,
    temperature=0,
    messages=[{"role": "user", "content": refactor_prompt}]
)
```

**Structured output / constrained decoding.** For transforms where the output shape is known, use structured output (JSON mode, tool use, or similar) to constrain the response format. This reduces variance by eliminating formatting choices from the generation process.

**Prompt pinning.** Every variable in the prompt — system prompt wording, context ordering, example placement — affects output. Pin your prompts as versioned artifacts and track changes. A prompt that worked well in March may behave differently in June after a model update.

**Same-prompt-same-output as a goal, not a guarantee.** Even at temperature 0, model updates, infrastructure changes, and system prompt variations can shift outputs. Treat determinism as a target you approach, not a property you achieve absolutely.

> [!info] As of 2026-Q2 — Anthropic's prompt caching feature makes repeated identical prompt prefixes cheaper and faster. For large-file refactors where the system prompt and type definitions stay constant, caching the prefix meaningfully reduces latency and cost.

@feynman

Temperature 0 is like setting a slot machine to always pick the highest-probability symbol — you get the most consistent outcome, but the machine is still probabilistic at its core, and the house can update the odds overnight.

@card
id: aicr-ch02-c009
order: 9
title: Cost Economics at Refactor Scale
teaser: Per-token pricing changes the calculus for large refactors — the right model choice is not always the most capable one, and local models have a real cost advantage at volume.

@explanation

Token pricing as of 2026-Q2 (approximate, input/output per million tokens):

- **Claude Opus 4.7:** ~$15 / $75 — highest capability, highest cost
- **Claude Sonnet 4.6:** ~$3 / $15 — strong capability, 5x cheaper than Opus
- **Claude Haiku 4.5:** ~$0.80 / $4 — fast, cheapest in the Claude family
- **GPT-5:** comparable to Opus pricing in most configurations
- **Gemini 2.x Flash:** sub-$1 / sub-$3 — competitive with Haiku for many tasks

A single file refactor costs fractions of a cent. A 10,000-file refactor at 500 tokens per file (input + output) is 5 million tokens. At Opus pricing, that's ~$450. At Sonnet pricing, ~$90. At Haiku pricing, ~$20.

The model-selection decision for large refactors:

- Use the smallest model that produces acceptable output for the task class. Mechanical transforms (import reordering, trivial idiom changes) often work well with Haiku 4.5. Semantic transforms (cross-language ports, complex restructuring) warrant Sonnet 4.6 or Opus 4.7.
- **Local models earn their keep at volume.** A locally-hosted model (Llama 3.x, Qwen 2.5-Coder, DeepSeek-V3) has near-zero per-token cost after hardware. For a refactor campaign processing millions of tokens per day with acceptable quality from a smaller model, local deployment pays for itself.
- **Batch API reduces cost.** Anthropic's Message Batches API and OpenAI's Batch API offer ~50% discounts for non-real-time workloads. A refactor pipeline running overnight qualifies.

> [!info] As of 2026-Q2 — pricing changes frequently. The cost ratios above are directionally stable but the absolute numbers shift with model releases and competition. Check current pricing before committing a refactor budget.

@feynman

Choosing a model for large-scale refactoring is like choosing shipping speed — overnight express is available, but if your deadline is next week, ground shipping at a fifth the cost gets the job done.

@card
id: aicr-ch02-c010
order: 10
title: The Stochastic Test Suite Mindset
teaser: Run the same refactor three times, diff the results, and treat disagreement as a signal — the places where runs diverge are exactly where your confidence should be lowest.

@explanation

Because LLM output is probabilistic, a single run of a refactor is a single sample. If you run it once and merge, you've treated one sample as ground truth without knowing how stable that output is. The stochastic test suite mindset addresses this by making variance visible before you commit.

The technique:

1. Run the same refactor prompt on the same input three times, with temperature 0 but with minor prompt variations (different system prompt phrasing, different context ordering).
2. Diff all three outputs against each other.
3. Where all three agree: high confidence. The transform is stable.
4. Where two agree and one differs: investigate. The differing output may be exposing an ambiguity in the prompt or a genuine uncertainty about the correct transform.
5. Where all three differ: low confidence. The model does not have a stable answer for this input. Either restructure the prompt with more context, fall back to a manual transform, or use an AST tool.

This technique catches the "silently dropped behavior" failure mode more reliably than a single pass, because dropped behavior often appears inconsistently across runs — sometimes the branch is preserved, sometimes it's elided.

Cost: three runs instead of one at a 3x cost increase for that file. For high-stakes code paths, this is trivially justified. For bulk mechanical transforms where a spot check shows all runs agreeing, you can run one.

> [!tip] Automate the three-run comparison. A script that runs your refactor prompt three times and reports disagreeing sections takes an afternoon to write and will pay for itself on the first complex refactor you catch a bug in.

@feynman

Running the same LLM refactor three times and comparing is like asking three different witnesses to describe the same event — where they all agree you have reliable testimony; where they diverge you know to dig deeper.

@card
id: aicr-ch02-c011
order: 11
title: When Not to Reach for an LLM
teaser: The strongest sign of LLM maturity is knowing when not to use one — and for a large class of refactors, the IDE you already have is faster, cheaper, and more correct.

@explanation

The technology is new enough that there's social pressure to use it for everything. The productive discipline is the opposite: reach for an LLM only when the task class actually warrants it.

Do not use an LLM for:

- **Symbol rename in a statically-typed language.** Your IDE's language server does this with full scope awareness in seconds for free. Claude Sonnet 4.6 will do it for dollars, occasionally incorrectly.
- **Extracting a method with a specified name and signature.** "Extract Function" in IntelliJ, VS Code, or Xcode does this deterministically. An LLM introduces the possibility of naming drift and behavior drop.
- **Mechanical AST-shape changes.** Moving a parameter from position 2 to position 3 across all call sites. Adding a required field to a struct and initializing it to a known default. These have fully specified outputs; jscodeshift or libcst handles them without hallucination risk.
- **Formatting, import organization, dead code removal.** These are solved problems with zero-cost, zero-hallucination tools. Prettier, gofmt, autoflake, and their equivalents are the right answer.
- **Any refactor where the output is fully determined by the input.** If you could write the transformation as a search-and-replace rule with full confidence in the result, don't pay for LLM tokens.

The useful test: "Could I write this as a codemods rule?" If yes, write the codemods rule. LLMs earn their place on the transforms where the answer is no.

> [!warning] Using an LLM for tasks that deterministic tooling handles correctly trades a reliable outcome for an unreliable one, at a financial cost. This is not a capability upgrade — it's a regression.

@feynman

Reaching for an LLM to rename a symbol is like hiring a translator to correct your own native-language typo — the capability is there, but so is the risk of creative misinterpretation where none was needed.

@card
id: aicr-ch02-c012
order: 12
title: Model Capability Moves Quarterly
teaser: The model that is the wrong tool today for a given refactoring task may be the right tool in 18 months — and the reverse is equally true, as pricing and capability trade-offs continue to shift.

@explanation

The practical implication of LLMs as refactoring tools is that your toolchain decisions have a shorter shelf life than they did with static analysis. When jscodeshift landed, the API stabilized and your codemod scripts from 2015 still run today. LLM-based tooling doesn't work that way.

What has changed meaningfully in the last 18 months:

- **Context window expansion.** File-level context was the constraint in 2024. Project-level context (200K–1M tokens) is the norm in 2026. Tasks that required retrieval-augmented generation workarounds in 2024 now fit in a single call.
- **Structured output reliability.** Early models produced valid JSON intermittently; current Claude 4.x and GPT-5 family models produce valid structured output with near-100% reliability, making LLM output usable as direct pipeline input.
- **Code-specific model quality.** The gap between code-capable and general models has narrowed. Claude Haiku 4.5 handles tasks in 2026 that required Opus-tier models in 2024.

What will likely change in the next 18 months:

- Agentic refactoring tools that run tests, observe failures, and iterate without human intervention will mature from experimental to production-ready.
- Local model quality for code tasks will continue closing the gap with API-hosted models, changing the cost calculus for volume workloads.
- Per-token pricing will continue falling, shifting more refactor tasks from "too expensive" to "default on."

The design principle: build your refactoring pipelines so the model is a pluggable component, not a hardcoded assumption. The prompt, the validation pipeline, and the diff review workflow are the durable parts.

> [!info] As of 2026-Q2 — the Anthropic model family (Opus 4.7, Sonnet 4.6, Haiku 4.5) represents the current capability tiers. These identifiers will change; the tier structure — expensive/capable, balanced, fast/cheap — is likely to persist across generations.

@feynman

Treating a specific LLM as a permanent tool choice is like standardizing on a specific version of gcc in 1995 — the right choice today, but a constraint worth loosening before your build scripts are a decade old.
