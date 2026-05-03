@chapter
id: aicr-ch05-tooling-landscape
order: 5
title: Tooling Landscape (2026)
summary: The 2026 tooling landscape for AI-assisted refactoring divides into IDE assistants, agentic CLIs, hybrid AST+LLM systems, and managed services — each with a distinct sweet spot and a distinct way of going wrong.

@card
id: aicr-ch05-c001
order: 1
title: The Four-Category Landscape
teaser: Every AI-assisted refactoring tool in 2026 falls into one of four buckets — and knowing which bucket you're reaching into tells you more about its failure modes than any feature list.

@explanation

The landscape has shaken out into four distinct categories, each with a different unit of work, a different level of autonomy, and a different trust model:

- **IDE assistants** (Cursor, GitHub Copilot, JetBrains AI Assistant) — live inside your editor, operate on the code you have visible or selected, and hand you a diff to accept or reject. The human stays in the loop for every change.
- **Agentic CLIs** (Claude Code, Aider, Cline) — run from the terminal or a panel, read your full codebase, plan a multi-file edit, and execute it. Autonomy is much higher; oversight requires discipline.
- **Hybrid AST+LLM systems** (OpenRewrite + LLM, ast-grep + LLM) — use a structural tool for deterministic transforms and bring the LLM in only for the judgment-heavy parts (naming, comment rewrites, edge cases). More reproducible, harder to set up.
- **Managed services / build-bot integrations** — CI pipelines that run refactoring campaigns on pull requests automatically, triggered by a schedule or a new dependency version. The robot opens the PR; a human reviews it.

These categories are not exclusive. A real refactoring campaign might use a hybrid system for the mechanical passes, an agentic CLI for the tricky files, and an IDE assistant for final cleanup. The point is that each category has different failure modes, different cost structures, and different places where human review is non-negotiable.

> [!info] As of 2026-Q2 — the category boundaries are blurring. Cursor has added an agent mode; Copilot has added multi-file edits. The taxonomy here describes distinct interaction models, not rigid product lines.

@feynman

Choosing a tool without knowing its category is like reaching into a mechanic's toolbox without knowing whether you need a torque wrench, a diagnostic computer, a hydraulic press, or a scheduling system — they all "fix cars," but the job determines the tool.

@card
id: aicr-ch05-c002
order: 2
title: Cursor
teaser: Cursor is an editor fork built around AI editing from the ground up — not a plugin bolted onto an existing tool, which changes what it can do and how fast it moves.

@explanation

Cursor is a VS Code fork with AI editing baked into the core rather than added via extension. Three main surfaces matter for refactoring:

- **Cmd+K (inline edit):** Select code, describe the change, get a diff. Fastest interaction — good for renaming, extracting a function, simplifying a conditional. The context is your selection plus a configurable amount of surrounding code.
- **Composer (multi-file edit):** Describe a larger change in natural language; Cursor plans edits across multiple files and presents them for review. This is where it earns its reputation.
- **Codebase chat:** Ask questions about your whole repository before you write a prompt. Cursor indexes your codebase locally and retrieves relevant context rather than requiring you to paste it manually.

What it is genuinely good at: medium-complexity, multi-file refactors where a human knows what they want but doesn't want to write every change by hand. The diff review UX is polished.

What it isn't good at: very large codebases where the indexing is incomplete; changes requiring deep semantic understanding of runtime behavior (it doesn't execute your code); anything requiring access to external services or real CI feedback.

The honest tradeoff: Cursor is the best editor-native refactoring UX in 2026, but it's a proprietary fork, its lead over VS Code + Copilot is not guaranteed to persist, and there is a real question about whether teams want to tie their editor choice to an AI vendor.

> [!info] As of 2026-Q2 — Cursor's market position has attracted significant competition from Microsoft (Copilot in VS Code) and JetBrains. The gap in edit UX has narrowed compared to 2024.

@feynman

Cursor is like a kitchen designed around a professional chef rather than having a chef's knife rack added to a standard apartment kitchen — the workflow assumptions are different from the start.

@card
id: aicr-ch05-c003
order: 3
title: GitHub Copilot
teaser: Copilot's advantage is not the AI — it's the distribution; it lives inside the editor most developers are already using, which means zero tool-switching friction.

@explanation

GitHub Copilot ships as a VS Code extension (and plugins for JetBrains and Neovim), which means it layers onto your existing setup rather than replacing it. For refactoring specifically, the relevant surfaces are:

- **Inline suggestions:** The original feature — next-token and next-block completions as you type. Less useful for refactoring than for writing net-new code.
- **Chat and `/refactor`:** Open the Copilot Chat pane, select a function, type `/refactor` — Copilot suggests a rewritten version. You can follow up conversationally.
- **Copilot Edits (multi-file):** As of late 2024 and into 2025, Copilot added an edits mode that applies changes across multiple files. More limited in scope than Cursor Composer or Claude Code, but improving.
- **Agent mode:** An agentic execution mode where Copilot can run terminal commands, read compiler errors, and iterate. Still less capable than dedicated agentic CLIs for complex multi-file campaigns.

The core tradeoff: Copilot is deeply integrated into VS Code, GitHub PRs, and GitHub Actions. If your team lives in that ecosystem, the friction is lower than adopting a new editor or a separate CLI. The AI capability per dollar is slightly behind Cursor's headline models in most independent comparisons, but the gap is narrower than the marketing on either side suggests.

What it cannot do well: long-horizon agentic tasks, refactors requiring understanding of runtime state, and changes that span a monorepo with many loosely coupled services.

> [!info] As of 2026-Q2 — Copilot's agent mode capabilities have expanded significantly since its 2024 preview. The distinction between Copilot Edits and Cursor Composer is smaller than it was in 2025, but not gone.

@feynman

GitHub Copilot is the house brand at the store you already shop at — not always the highest-rated product on the shelf, but you're already there and the returns process is easy.

@card
id: aicr-ch05-c004
order: 4
title: JetBrains AI Assistant
teaser: JetBrains AI Assistant's edge is not the LLM — it's the fact that it runs on top of IntelliJ's existing refactoring catalog, which means it can call the same safe, deterministic transforms your IDE has offered for 20 years.

@explanation

JetBrains AI Assistant is the AI layer for IntelliJ IDEA, PyCharm, WebStorm, Rider, and the other JetBrains IDEs. The key architectural difference from Cursor and Copilot is the integration with JetBrains' existing refactoring engine.

When you ask JetBrains AI to refactor code, it can invoke the IDE's built-in refactorings (rename symbol across the project, extract method, inline variable, change method signature) programmatically rather than generating text that looks like code. This means:

- Rename refactors update all call sites correctly, including cross-file references, because the IDE's language server does the actual renaming — the LLM just decides what to call it.
- Extract method produces valid, correctly scoped code because the IDE understands the AST.
- The LLM handles the judgment calls (what to name the extracted method, how to reorganize a class) and the IDE handles the mechanics.

What this is genuinely good at: refactoring in Java, Kotlin, Python, and other languages where IntelliJ has deep language understanding. The output is safer than pure LLM generation for structural changes.

What it struggles with: the AI features are less mature than Cursor's for open-ended, natural-language-driven refactoring. It is also only relevant if your team is already on JetBrains IDEs; the switching cost argument runs both ways.

> [!info] As of 2026-Q2 — JetBrains AI Assistant is still catching up on conversational refactoring UX compared to Cursor and Copilot. The structural advantage from the IDE's refactoring catalog is real but often undersold in comparisons.

@feynman

JetBrains AI Assistant is like a surgeon working in a hospital with a full instrument kit — the AI decides what procedure to do, and the existing hospital infrastructure carries out the precise mechanical steps safely.

@card
id: aicr-ch05-c005
order: 5
title: Claude Code
teaser: Claude Code is Anthropic's agentic CLI — it reads your entire codebase, makes a plan, runs multi-file edits, and executes terminal commands, with you setting the level of confirmation required.

@explanation

Claude Code (`claude` on the command line, or installed via npm) is an agentic coding assistant that operates at the project level, not the file level. You describe a change in natural language; it reads relevant files, writes a plan, applies edits across multiple files, and can run shell commands to check the result.

Key behaviors for refactoring:

- It reads the codebase before acting — you don't paste context manually.
- It can run your tests after a refactor and iterate if they fail.
- It asks for confirmation before destructive operations unless you've configured autonomous mode.
- It tracks what it changed and why, which helps with review.

```bash
# Ask Claude Code to refactor a module
claude "convert all callbacks in src/api/ to async/await and run the test suite"

# With a more targeted scope
claude "extract the database connection logic from app.js into its own module"
```

The honest assessment: Claude Code is well-suited for complex, open-ended refactoring campaigns where you need multi-file understanding and agentic execution. It is not the right choice when you want a tight, single-file diff to review quickly — the IDE assistants are faster for that. It also requires trust in the tool's judgment about what files to touch; auditing the plan before confirming execution is non-optional for anything important.

> [!info] As of 2026-Q2 — Claude Code's agentic execution model is one of the more capable in the CLI category, but the CLI-agentic space as a whole is a 2025 phenomenon. The tooling will look substantially different by 2027, and Anthropic's positioning in this space is actively evolving.

@feynman

Claude Code is like a senior contractor you brief once with the full requirements — they go off, read the blueprints, do the work across multiple rooms, and hand you a walk-through before calling it done.

@card
id: aicr-ch05-c006
order: 6
title: Aider
teaser: Aider is the open-source, git-native agentic CLI that predates most of the commercial tools — and for teams that want to run on their own API keys with full transparency, it is still the pragmatic baseline.

@explanation

Aider (`pip install aider-chat`) is an open-source CLI that integrates with git from the ground up. You run it from your project root, tell it which files to work with, and describe changes in natural language. It applies edits and creates a git commit automatically.

Key characteristics that differ from commercial tools:

- **Bring your own API key.** Aider works with OpenAI, Anthropic, Gemini, and local models. No separate subscription beyond the API.
- **Git-native workflow.** Every change Aider makes is automatically committed with a message. You can `git log` and `git diff` to audit exactly what happened, and `git reset` if you don't like it.
- **Repo map.** Aider generates a compressed map of your codebase's symbols and passes it as context, allowing it to work on large codebases without pasting entire files.

```bash
# Add files to context and describe the change
aider src/utils.py src/main.py
# then in the prompt: "extract the retry logic into a reusable decorator"
```

What it's not: a polished product. The UX is a terminal prompt. There is no diff preview UI before changes are applied. You rely on git to undo mistakes.

Aider's appeal is to smaller teams or individual developers who want cost control, auditability, and no proprietary lock-in. The capability ceiling has risen as underlying models improved, but the interaction model remains terminal-first.

> [!info] As of 2026-Q2 — Aider's open-source model has kept it relevant even as commercial tools have caught up on capability. The git-native commit workflow is still a genuine differentiator for teams that treat git history as an audit trail.

@feynman

Aider is like a trusted tradesperson who uses your tools and materials, leaves a detailed receipt for every job, and doesn't require you to subscribe to their proprietary platform to keep working.

@card
id: aicr-ch05-c007
order: 7
title: Cline
teaser: Cline is a VS Code extension that brings full agentic execution into the editor — it can read files, run terminals, and call external APIs, which makes it more capable than Copilot's agent mode and more visible than a terminal CLI.

@explanation

Cline (formerly Claude Dev) is a VS Code extension that gives an LLM agent access to your editor's file system, a terminal panel, and the ability to run commands — all inside VS Code. Unlike Copilot, which restricts what the agent can touch, Cline gives the model broad permissions that you can configure.

What this means in practice:

- Cline can apply multi-file edits, run your build or test suite, read the output, and iterate — all without leaving VS Code.
- Every file read, file write, and terminal command is shown in a sidebar activity log. You can approve or deny actions before they execute.
- It supports any LLM backend (Anthropic, OpenAI, Gemini, local via Ollama) — not tied to a single vendor.

How it differs from Copilot agent mode: Copilot's agent runs in a managed environment with Microsoft's guardrails. Cline runs with the full permissions of your local machine. That's more capable and more risky — a poorly specified prompt can result in the agent deleting files or running arbitrary shell commands.

How it differs from terminal CLIs (Claude Code, Aider): Cline lives in VS Code, so the diff review and file browsing happens in the editor interface rather than the terminal. Teams that prefer GUI-adjacent workflows find this more comfortable.

> [!info] As of 2026-Q2 — Cline has grown quickly from an experimental extension into a widely adopted tool. The VS Code extension model means it updates independently of the editor, and the extension's permissions model has become more granular as the user base has raised concerns about unintended side effects.

@feynman

Cline is like a co-pilot who sits in the cockpit with you — they have access to all the same controls you do, you can see everything they're doing on your shared display, and you decide whether to let them execute each maneuver.

@card
id: aicr-ch05-c008
order: 8
title: Cody (Sourcegraph)
teaser: Cody's differentiator is that it retrieves context from your entire codebase via Sourcegraph's code intelligence graph, not just the files open in your editor or an ad-hoc embedding index.

@explanation

Cody is Sourcegraph's AI coding assistant, available as a VS Code and JetBrains extension, and integrated into the Sourcegraph web UI. Its core architectural bet is that retrieval quality beats raw context window size — that answering "how is authentication handled across this monorepo?" requires structured code search, not just pasting more files into a prompt.

For refactoring, this means:

- Cody can find all usages of a symbol across a large repository before suggesting a change, using Sourcegraph's precise code intelligence (which understands cross-repo references, not just text search).
- It can answer questions about patterns used elsewhere in your codebase before generating a refactored version ("are there other files that do this? show me how they're structured").
- For enterprises with Sourcegraph already deployed, Cody requires no additional indexing infrastructure — it reuses the existing graph.

What it doesn't change: the actual LLM-generated edit is still subject to the same hallucination and reasoning limits as any other tool. Cody's advantage is in context selection, not in generation quality.

The honest tradeoff: Cody's retrieval advantage is most valuable for large codebases at organizations that already run Sourcegraph. For a small team on a single repository that fits in a context window, the operational overhead of Sourcegraph is hard to justify on AI features alone.

> [!info] As of 2026-Q2 — Cody's enterprise positioning has solidified around organizations that already rely on Sourcegraph for code search. It is not a strong contender for small-team or greenfield environments.

@feynman

Cody is like a consultant who walks into your office with a complete map of where every piece of information lives before they start advising — the advice isn't necessarily better, but it is informed by more of the right context.

@card
id: aicr-ch05-c009
order: 9
title: OpenRewrite with LLM Hybrids
teaser: OpenRewrite handles the mechanical, deterministic transforms; the LLM handles only the judgment calls — which means the reproducible 80% of a refactoring campaign doesn't depend on the LLM getting it right.

@explanation

OpenRewrite is a Java (and expanding) refactoring framework that operates on a lossless syntax tree. It ships hundreds of recipes for migrations like Java 8 to Java 17, JUnit 4 to JUnit 5, Spring Boot 2 to Spring Boot 3, and logging framework swaps. These run deterministically and produce the same output every time.

The hybrid pattern: run OpenRewrite for everything it knows how to do deterministically, then pass the residual — the files with complex logic, unusual patterns, or annotation-heavy code that the recipe couldn't fully handle — to an LLM for the remaining edits.

```bash
# Run OpenRewrite for the structural migration
./gradlew rewrite:run -Drewrite.activeRecipes=org.openrewrite.java.migrate.Java17

# Then pass the files OpenRewrite flagged as needing manual review to an LLM
claude "the following files were not fully migrated — complete the migration for each one" < review-list.txt
```

Why this matters: LLMs make mistakes on structural transforms. OpenRewrite does not. Using OpenRewrite for the 80% of changes that are purely mechanical, and the LLM only for the 20% requiring judgment, reduces both error rate and review burden.

The limitation: OpenRewrite's recipe catalog is primarily Java/JVM. The pattern generalizes — libCST for Python, ts-morph for TypeScript — but the tooling ecosystem is less mature outside the JVM world.

> [!info] As of 2026-Q2 — the OpenRewrite ecosystem has expanded to cover more frameworks and migration targets, but it remains most mature for Java/Kotlin. Teams on other stacks should look for equivalent AST-based tools before defaulting to pure LLM.

@feynman

The OpenRewrite hybrid is like a moving company where the robot handles every standard box and piece of furniture, and the human movers only touch the antiques and irreplaceable items that need individual judgment.

@card
id: aicr-ch05-c010
order: 10
title: ast-grep with LLM Hybrids
teaser: ast-grep lets you write structural search patterns once and apply them across a large codebase; the LLM handles only the creative part — rewriting the matched code into the new shape.

@explanation

ast-grep (`sg`) is a CLI tool for structural code search and replace using tree-sitter grammars. Where `grep` matches text, ast-grep matches syntax — a pattern like `$FUNC($A, $B)` matches any two-argument function call regardless of whitespace or variable names.

The hybrid pattern for refactoring:

1. Write an ast-grep rule that identifies the pattern you want to change (e.g., all usages of a deprecated API, all `Promise`-chaining code that should become `async/await`).
2. Extract all matches and their surrounding context.
3. Pass each match to an LLM to generate the replacement, using the structural context as the prompt.
4. Apply replacements, run tests.

```bash
# Find all usages of the old pattern
sg scan --rule rename-api-rule.yml --json > matches.json

# Feed matches to LLM for per-match rewriting
python scripts/llm-rewrite.py < matches.json > rewrites.patch

# Apply
git apply rewrites.patch
```

This approach is especially useful for naming-heavy refactors: ast-grep finds every occurrence of a structural pattern; the LLM generates a contextually appropriate name for each one. Neither tool can do the whole job well alone.

The honest overhead: writing good ast-grep rules takes time up front. For a one-off change on a small codebase, using a pure LLM is faster. The structural approach pays off at scale or when the same campaign needs to run repeatedly.

> [!info] As of 2026-Q2 — ast-grep supports JavaScript, TypeScript, Python, Rust, Go, Java, and C/C++ via tree-sitter. Coverage continues to expand. The tooling for automating the LLM step is still largely hand-rolled — there is no canonical library for the "ast-grep feeds LLM" pattern.

@feynman

ast-grep plus an LLM is like a spell-checker combined with a copy editor — the spell-checker finds every occurrence of the pattern reliably, and the copy editor rewrites each one in a way that fits the surrounding prose.

@card
id: aicr-ch05-c011
order: 11
title: Build-Bot and CI-Driven Refactoring
teaser: The "open a PR per file" pattern turns a refactoring campaign into a review queue — the bot does the mechanical work continuously; the team reviews and merges on their schedule.

@explanation

Build-bot integration takes refactoring out of a developer's hands entirely for the mechanical passes. The pattern:

1. A CI job (GitHub Actions, GitLab CI, Jenkins) runs on a schedule or on a trigger (new dependency version published, security advisory, policy violation detected).
2. The job applies a refactoring tool (OpenRewrite recipe, a custom LLM prompt, ast-grep rule) to one or more files.
3. The job opens a pull request with the changes, tagged with the campaign name and a description of what changed and why.
4. A human reviews and merges — or the job auto-merges if tests pass and the change is in a pre-approved category.

The "open a PR per file" variant keeps PRs small and reviewable. The "open one PR for the whole campaign" variant is faster to merge but harder to review and harder to partially accept.

Why this pattern scales: a 10,000-file Java codebase can receive a Spring Boot 3 migration campaign as a rolling set of 200 PRs over two weeks, with each PR touching 50 files. No developer needs to do the mechanical work; they only review and sign off.

What goes wrong: LLM-driven campaigns produce inconsistent quality across files — some changes are excellent, some introduce subtle bugs. Reviewing 200 PRs at speed leads to rubber-stamping. The pattern requires test coverage to be trusted; without tests, the PRs are noise.

> [!info] As of 2026-Q2 — tooling for automated refactoring campaigns is maturing (Moderne for OpenRewrite, various internal platforms at larger tech companies), but it is not yet commoditized for teams below 50 engineers. Expect more off-the-shelf support here by 2027.

@feynman

CI-driven refactoring is like a factory recall managed by mail — the company sends you a pre-paid envelope with clear instructions, you send back the part, and only the judgment calls (keep the car or return it?) stay with the human.

@card
id: aicr-ch05-c012
order: 12
title: Self-Hosted and Local Models
teaser: Local models (LM Studio, Ollama with Qwen-Coder or DeepSeek-Coder) trade capability for privacy — and for codebases that cannot leave the building, that tradeoff is non-negotiable.

@explanation

For organizations where proprietary code cannot be sent to a third-party API — financial institutions, defense contractors, regulated healthcare, companies with strict IP policies — local models are not an option but a requirement.

The practical stack in 2026:

- **Ollama** — run any supported model locally with a single command. Exposes an OpenAI-compatible API on `localhost:11434`, which means Aider, Open WebUI, and many other tools work without modification.
- **LM Studio** — GUI-first local model runner, useful for teams that want model selection without CLI overhead.
- **Qwen-Coder** and **DeepSeek-Coder** — the two open-weight models most consistently competitive with commercial models on code-specific benchmarks as of early 2026. Neither matches GPT-4o or Claude Sonnet on complex reasoning tasks, but both are viable for constrained refactoring tasks.

```bash
# Run DeepSeek-Coder locally via Ollama
ollama pull deepseek-coder:33b
ollama run deepseek-coder:33b

# Use with Aider
aider --model ollama/deepseek-coder:33b src/legacy.py
```

The honest limitation: local models in 2026 are still meaningfully behind the frontier cloud models on multi-step reasoning and long-context tasks. A complex, multi-file refactor that Claude or GPT-4o handles well will often stall or produce lower-quality output from a local model. For simpler, well-scoped refactors — renaming conventions, boilerplate replacement, single-function rewrites — the gap is manageable.

Hardware requirements are non-trivial: running a 33B parameter model at useful speed requires a machine with 32+ GB of VRAM or very fast unified memory. For most development laptops, 7B or 14B models are the practical ceiling.

> [!info] As of 2026-Q2 — the capability gap between local open-weight models and frontier commercial models has narrowed compared to 2024 but has not closed. The choice of local models remains a tradeoff, not a free alternative.

@feynman

Running a local model for code refactoring is like having an in-house lawyer instead of outside counsel — slower and less specialized, but everything stays in the building and nothing leaves without your permission.
