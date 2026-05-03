@chapter
id: rfc-ch13-the-ai-era-refactor
order: 13
title: The AI-Era Refactor
summary: LLM-assisted refactoring is the most significant shift in the practice since Martin Fowler's catalog itself — capable of doing the mechanical work in seconds, dangerous when applied without judgment, and worth integrating only when you understand exactly what it can and cannot guarantee.

@card
id: rfc-ch13-c001
order: 1
title: Speed Is Not Discipline
teaser: AI tools compress the execution time of a refactoring from minutes to seconds — they do not compress the thinking required to decide whether to do it at all.

@explanation

The catalog in chapters 3 through 9 is a vocabulary, not a script. Extract Method, Move Feature, Decompose Conditional — these names describe specific mechanics with specific preconditions. Knowing which one applies, and when, requires you to read the code's intent, trace the coupling, and make a judgment call about the right abstraction. None of that changes because a language model can now perform the mechanics faster.

What AI tools actually accelerate is the execution step: once you know you want to rename a method across a module, or convert a callback chain to async/await, the tool can do the structural work in seconds rather than minutes. That is genuinely useful. The cost comes when teams treat AI's speed as a signal that refactoring itself is now cheaper to get wrong — that you can try things freely and just revert. You can, but the review cost has not disappeared; it has shifted from doing the work to reading the diff carefully enough to trust it.

The discipline the catalog describes is still the constraint. AI is a faster chisel, not a different architecture.

> [!info] As of 2026-Q2 — every major IDE-integrated AI assistant (Cursor, GitHub Copilot, JetBrains AI, Claude Code) generates refactoring suggestions automatically, often unsolicited. The habit of applying them without first answering "is this the right change?" is the primary new risk.

@feynman

This is like cruise control on the highway — it relieves you of the effort of holding a steady speed, but it does not know whether the exit you need is coming up in half a mile.

@card
id: rfc-ch13-c002
order: 2
title: IDE-Integrated AI Refactoring
teaser: Cursor's Cmd+K, GitHub Copilot's `/refactor`, and JetBrains AI Assistant all perform inline refactoring inside your editor — fast, scoped, and limited to what the tool can see in its context window.

@explanation

IDE-integrated AI assistants operate on a selection or a file. You highlight a block, invoke the assistant, and describe what you want. The result is an in-place rewrite. The key tools as of 2026-Q2:

- **Cursor (Cmd+K):** Opens an inline prompt bar over a selection. Strong at single-function transforms — rename, extract, simplify conditional chains. Context is the open file and any cursor-indexed workspace files. Vulnerable to missing cross-file dependencies that aren't in the window.
- **GitHub Copilot Chat (`/refactor`):** Available in VS Code and Visual Studio. Pass it a selection; it proposes a refactored version in the chat panel before you apply it. The separation between proposal and apply is useful — you can reject or edit before committing.
- **JetBrains AI Assistant:** Deep IDE integration means the tool has real symbol awareness (the same graph IntelliJ uses for its own automated refactors). This makes it more reliable than purely text-based assistants for multi-site renames, because it routes through the IDE's own refactoring engine.
- **Cody by Sourcegraph:** Codebase-aware through Sourcegraph's graph index. Relevant when the refactoring spans a large monorepo where file-local context is insufficient.

The common failure mode across all of them: the tool sees the current file and nearby context, but the refactoring touches call sites in three other files it did not read. The diff looks clean; the broken tests catch it.

> [!warning] As of 2026-Q2 — none of these tools guarantee they have read every call site before renaming a symbol. Always run your full test suite after an AI-assisted rename, even if the diff looks trivially correct.

@feynman

Using an IDE-integrated AI refactoring tool is like asking a copy editor who has read your chapter but not your whole book to clean up a paragraph — the paragraph will be better, but the references to earlier chapters are your problem to check.

@card
id: rfc-ch13-c003
order: 3
title: Agentic Refactoring — Multi-File Campaigns
teaser: Agentic tools like Aider, Cline, and Claude Code in agentic mode can plan and execute refactorings across an entire codebase — which makes the review problem larger, not smaller.

@explanation

Agentic refactoring tools do not wait for you to highlight a block. You give them a goal — "extract the payment processing logic from `OrderService` into its own class, update all callers, and make the tests pass" — and they plan a sequence of edits, execute them, run the build, and iterate. As of 2026-Q2:

- **Aider:** Terminal-based, integrates with git. Works well for targeted campaigns where you can describe the intent precisely. Commits incrementally, so you get a readable git log.
- **Cline:** VS Code extension. Tool-using agent that can read files, run commands, and write diffs. Tends to be more conversational — you can steer mid-task.
- **Claude Code (agentic mode):** Terminal and IDE agent. Effective at multi-file campaigns where the change is well-specified. Runs tests as part of the loop and uses test failures to correct itself.
- **Devin:** Cloud-hosted agent. Higher latency, appropriate for longer-running campaigns where you're willing to hand off and review results rather than supervise in real time.

The amplification of risk scales with scope. A single-file change from Copilot that's wrong is easy to spot and revert. A 47-file refactoring campaign from Devin that is 95% correct — but has three subtle behavioral changes buried in the diff — requires the same forensic review you'd apply to any large PR. The agentic capability does not reduce the review burden; it increases the surface area that needs covering.

> [!warning] As of 2026-Q2 — agentic tools are particularly prone to "while I was in there" additions: small improvements they add beyond the stated goal. These are often reasonable and occasionally wrong. Scope your prompts tightly and diff the output against the stated intent, not just against "does it compile."

@feynman

Commissioning an agentic refactoring is like hiring a contractor to repaint the living room and coming home to find they also rewired an outlet they thought looked suspicious — the work may be fine, but you have to verify it even if you didn't ask for it.

@card
id: rfc-ch13-c004
order: 4
title: Prompt Patterns for Safe Refactoring
teaser: The difference between a useful AI refactoring and a subtle regression often comes down to how precisely you framed the request.

@explanation

Vague prompts produce rewrites. Precise prompts produce refactorings. The distinction is behavioral equivalence: a refactoring does not change what the code does; a rewrite might. If your prompt does not make behavioral preservation an explicit constraint, the model will optimize for code it considers cleaner, which is not the same thing.

Patterns that reduce risk:

**Intent-first with explicit constraint:**
```text
Rename `getUser` to `fetchUser` everywhere it appears
in this file. Don't change anything else — no formatting,
no logic, no comments.
```

**Scope boundary:**
```text
Extract the validation logic in lines 45–78 of
`OrderService.swift` into a private method called
`validateOrderItems`. Only change that method's scope —
leave all callers as they are.
```

**Behavior description:**
```text
This method's behavior: given a list of items, it filters
out any with quantity zero, then returns the total price.
Refactor it to be more readable without changing those
two behaviors.
```

**Explicit anti-goals:**
```text
Do not add early returns. Do not change the public
interface. Do not add comments.
```

The failure mode of open-ended prompts is that "make this cleaner" or "refactor this class" invites the model to apply its own aesthetic preferences — which may include inlining things you want kept separate, renaming things that were named deliberately, or restructuring error handling in ways that look equivalent but behave differently on edge cases.

> [!tip] As of 2026-Q2 — Claude 4.x models respond well to explicit "don't change X" constraints. GPT-5 and Gemini 2.x are similarly responsive. The framing discipline pays off regardless of which model you're using.

@feynman

Prompting an AI refactoring tool is like giving instructions to a very fast intern — the clearer your constraints, the less time you spend undoing the things they optimized for that you didn't want optimized.

@card
id: rfc-ch13-c005
order: 5
title: Where AI Excels — Rote Pattern Application
teaser: LLMs are at their best when the refactoring is mechanical, repetitive, and well-defined — the class of changes that used to require careful sed scripts or multi-hour IDE work.

@explanation

The refactorings where AI tools deliver consistent value are the ones where the recipe is unambiguous and the judgment call has already been made by a human:

- **Mass renames:** Renaming a method, class, or variable across hundreds of files is exactly the kind of structural work LLMs handle well. The pattern is clear; the model just has to find every instance and apply it without introducing typos or missing edge cases in string literals.
- **API modernization:** Converting a callback-based API to async/await, or updating a deprecated library's call sites to the new interface, is a pattern the model can learn from one or two examples and apply consistently across a file set.
- **Boilerplate extraction:** Extracting repeated initialization sequences, duplicated error handling blocks, or copy-pasted validation logic into shared utilities is rote work where AI accuracy is high because the pattern is visible and the transformation is local.
- **Type annotation campaigns:** Adding type hints to an untyped Python codebase, or tightening TypeScript `any` types after you've established what the shape should be, is labor AI handles well at scale.

What these have in common: the "which refactoring" and "why" decisions have already been made. You are asking the tool to execute, not to judge. The catalog's judgment work — recognizing the smell, selecting the right recipe, deciding where the boundary belongs — is already done.

> [!info] As of 2026-Q2 — the JS-to-TypeScript migration and the callback-to-async/await campaign are the two most reliably successful large-scale AI refactoring patterns in production use. Both have a well-defined mechanical transformation with high AI accuracy and clear test signal.

@feynman

AI refactoring excels at rote pattern work the same way a find-and-replace regex does — except it can handle the cases where the syntax varies and a regex would need seventeen alternations.

@card
id: rfc-ch13-c006
order: 6
title: Where AI Fails — Judgment Calls
teaser: Diagnosis errors are the failure mode you cannot catch by running tests — the model confidently applies the wrong recipe because it recognized a surface pattern, not the underlying design intent.

@explanation

The catalog smells are diagnostic categories, not mechanical triggers. "Feature Envy" (a method that seems more interested in another class's data than its own) describes a pattern that could justify Extract Method and Move Method — or it could mean the abstraction boundary you've drawn is wrong and the method belongs where it is while the boundary needs revisiting. The model sees the surface signal; it cannot reason about why the current structure exists.

Specific failure modes:

- **Inline vs. extract:** A model shown a one-liner helper function may suggest inlining it to "reduce indirection." The function may have been extracted precisely because it's tested, named for documentation, or a natural extension point. The model has no way to know.
- **Wrong smell diagnosis:** A long method with conditional logic may look like a candidate for Decompose Conditional. It may actually be a state machine that should be refactored into the State pattern from chapter 8. The mechanical appearance of the problem points one direction; the design intent points another.
- **Premature generalization:** AI tools frequently suggest introducing parameters, protocols, or abstractions for code that handles a single case today. This is speculative generality — the catalog names it, chapter 8 describes how to remove it — but the model reads it as an improvement.
- **False equivalence:** The model proposes a "cleaner" version that handles the 98% case correctly but silently changes behavior on an edge case it did not understand. The tests may not cover that edge case. This is the highest-severity failure mode.

You cannot outsource the "which recipe applies here and why" decision to a language model. You can let it execute the recipe once you've made that call.

> [!warning] As of 2026-Q2 — diagnosis errors are the class of AI refactoring failure most likely to survive code review and reach production. The change looks reasonable; the tests pass; the edge case that breaks later was not in the test suite and not in the model's context.

@feynman

Asking an AI to decide which refactoring a piece of code needs is like asking autocorrect to decide what you meant to say — it picks the most statistically likely interpretation, which is correct often enough to be useful and wrong at exactly the moments you need it most.

@card
id: rfc-ch13-c007
order: 7
title: Hallucination Risks in Refactoring
teaser: Hallucinated APIs, silent behavioral changes, and type drift are the three failure patterns specific to AI-assisted refactoring — each looks correct in the diff and breaks at runtime.

@explanation

Language models generate plausible text. In most writing contexts, "plausible" is good enough. In code, plausible-but-wrong is worse than obviously wrong, because it passes review.

**Invented APIs:** A model refactoring a method that calls `URLSession.data(from:)` may produce a refactored version that calls `URLSession.asyncData(from:)` — a method name it invented because it sounds like the async pattern. The code looks correct; it does not compile. This is the detectable case. The dangerous variant is when the invented API exists on a different type or in a different module and the code compiles, but behaves differently.

**Silent behavioral changes:** The classic case is a refactoring that preserves the obvious path but changes error handling, nil behavior, or exception semantics. A method that used to return an empty array on failure may be refactored to return nil. Every call site that assumed the empty-array contract is now broken. Tests that only assert the happy path will not catch it.

**Type drift:** In dynamically typed code or code with `any`/`AnyObject`, the model may narrow or widen a type in the refactored version. A function that accepted `Any` and dispatched on type at runtime may be refactored to accept a specific type — which removes the dispatch logic and silently ignores any inputs that no longer match the new signature.

All three are more likely when the model is working with code it has not fully read — which is the normal case for large files or multi-file edits where the relevant context is only partially in the window.

> [!warning] As of 2026-Q2 — error handling and nil/optional semantics are the highest-frequency site of silent behavioral changes in AI-refactored Swift and TypeScript code. Review these paths explicitly, not just the structural changes.

@feynman

A hallucinated API in AI-generated code is like a confident colleague who gives you detailed directions to an address that does not exist — the turn-by-turn instructions are plausible enough that you follow them until you discover the destination isn't there.

@card
id: rfc-ch13-c008
order: 8
title: Tests as the Safety Net — More Than Ever
teaser: AI-refactored code that lacks characterization tests is unverifiable at scale — the only reliable way to know a refactoring preserved behavior is to have tests that define what the behavior is.

@explanation

The catalog has always treated tests as the prerequisite for safe refactoring, not the afterthought. Chapter 10 makes the case. The AI era raises the stakes because the volume of changes is higher and the changes arrive faster than a human could produce them manually — which means the test gap is a proportionally larger risk.

**Characterization tests before refactoring:** Before running an agentic refactoring campaign on a legacy class, generate tests that document its current behavior. The prompt pattern:

```text
Look at this method. Don't refactor it yet.
Write me characterization tests that capture every
observable behavior you can identify — including
edge cases, error paths, and return values for
boundary inputs.
```

This forces you to understand what the code does before you change it, and gives you a regression suite that the AI did not write and therefore cannot silently make pass by changing the behavior to match the test.

**Tests as the loop exit condition:** Agentic tools like Aider and Claude Code can run tests as part of their edit loop. "Make this refactoring pass all existing tests" is a valid loop termination criterion. It is not a sufficient verification — it only catches regressions in behaviors the tests already cover — but it catches the obvious ones automatically.

**The human review window:** The high-value review time on an AI-refactored diff is the 20% of changes that touch error paths, type assertions, and branching logic — not the structural rearrangement, which is usually easy to verify. Allocate review attention accordingly.

> [!tip] As of 2026-Q2 — generating characterization tests with Claude Code or Copilot before starting a refactoring campaign is one of the highest-leverage uses of AI in the refactoring workflow. The cost is low; the safety benefit is high.

@feynman

Characterization tests before an AI refactoring are like taking a photograph of a room before a contractor renovates it — not because you expect them to steal the furniture, but because you want an unambiguous record of what was there when you agreed on the scope.

@card
id: rfc-ch13-c009
order: 9
title: The Trust-but-Verify Workflow
teaser: The productive posture toward AI-refactored code is neither blind acceptance nor reflexive suspicion — it is structured verification designed to catch the specific failure modes LLMs produce.

@explanation

Reviewing an AI-generated diff requires a different lens than reviewing a human-written diff. Human code tends to err in the direction of mistakes the author understands but mishandled. AI code tends to err in the direction of confident-looking changes that are subtly wrong in ways the author (the model) does not understand.

A practical workflow:

1. **Keep diffs small.** Request refactorings in units of one function or one class at a time. A 200-line diff from a human requires careful review; a 200-line diff from a model requires the same review with higher prior probability of subtle error.

2. **Spot-check 10-20% of changes manually.** For a large campaign (say, 40 files), pick 6-8 files at random and read the before/after in full. If those look clean, the rest are likely clean. If any look suspicious, read the full diff.

3. **Run mutation testing on AI-refactored code.** Mutation testing tools (like Pitest for Java, or Mutmut for Python) introduce small behavioral changes and check whether your tests catch them. If they don't, neither will you — and the AI's silent behavioral changes are exactly the mutations most likely to be invisible in review.

4. **Revert per-file when red.** If a file's tests go red after the refactoring and the fix isn't immediately obvious, revert that file and refactor it manually or re-prompt with more constraints. Do not fix an AI refactoring that you do not understand.

```text
Revert strategy prompt:
"The tests in OrderServiceTests.swift are now failing.
Before you fix them, tell me which behavior in
OrderService.swift you changed and why."
```

> [!info] As of 2026-Q2 — the "tell me what you changed before you fix it" prompt is one of the most useful diagnostic patterns for catching the class of silent behavioral changes that models introduce without flagging.

@feynman

Verifying AI-refactored code is like auditing a fast typist's transcription — you don't re-read every word, but you do spot-check the passages where meaning shifts easily, and you have the original in hand when something sounds off.

@card
id: rfc-ch13-c010
order: 10
title: The Economics Shift
teaser: When the cost of executing a refactoring drops by a factor of five to ten, the set of refactorings worth doing expands — and the constraint moves from execution to judgment and review.

@explanation

Before AI tools, the cost of a refactoring was dominated by execution time: finding every call site, making consistent edits, running tests, fixing the breaks. For a large codebase, renaming a widely-used internal method could be a half-day effort. This cost shaped what teams chose to fix — and left a large class of "worth doing but not worth the time" technical debt untouched.

AI tools change that calculation. The execution cost drops to minutes. What remains constant is the cost of understanding the code well enough to decide whether the refactoring is correct, reviewing the diff, and verifying behavior. That cost has not fallen proportionally.

The practical consequence: the Pareto front of "what's worth refactoring now" has moved. Changes that were previously too expensive relative to benefit — mass renames, API modernization across 50 call sites, extracting a cross-cutting concern that touches 30 files — are now worth attempting. The backlog of deferred structural improvements has become actionable.

The less visible consequence: teams that try to apply AI tools to the judgment layer — asking models to audit a codebase and generate a refactoring list — get output that looks thorough but reflects the model's aesthetic preferences, not the team's architectural intent. The judgment cost has not disappeared; it is easy to accidentally outsource it and harder to detect when you have.

> [!info] As of 2026-Q2 — the teams getting the most value from AI refactoring tools are not the ones using AI to decide what to refactor. They are the ones who already know what they want to fix and are using AI to execute it faster than they could manually.

@feynman

The AI refactoring cost reduction is like getting a very fast sous chef — the prep time drops dramatically, but you still have to know what dish you're making before you hand them the knife.

@card
id: rfc-ch13-c011
order: 11
title: The Skills That Matter More Now
teaser: When mechanical recipe execution becomes fast and cheap, the premium moves to the skills that have always been harder to teach — judgment, naming, and taste.

@explanation

The catalog documents mechanics. Mechanics are now easy to automate. What the catalog assumes you bring to the mechanics — the ability to look at code and correctly diagnose which smell is present, to propose an abstraction that fits the domain rather than just reduces line count, to name things so that readers understand intent without reading implementation — none of that is easier to automate than it was before.

The skills that AI tools compress:

- Finding every instance of a pattern once you've identified it
- Applying a transformation consistently across a large file set
- Typing the mechanical parts of a well-specified change
- Generating candidate names when you're blocked

The skills that AI tools do not compress:

- Reading unfamiliar code and building a mental model of its intent
- Deciding whether a long method is too long, or just dense because the domain is complex
- Choosing names that communicate the right abstraction to the next reader, not just the correct type
- Knowing when to stop — when the code is good enough and further refactoring is churn
- Recognizing that a proposed refactoring would make the code structurally cleaner but harder for the team to read

The practical consequence for learning: junior developers who use AI tools to skip mechanical practice may be building less facility with the catalog than developers who learned by doing the mechanics manually. The catalog's value as a vocabulary for discussing code is unchanged. The value of having applied each recipe enough times to recognize when it fits and when it doesn't is possibly higher than before, because the gap between people who can judge and people who can only execute is wider.

> [!tip] As of 2026-Q2 — the most consistent finding from teams using AI refactoring tools heavily is that the bottleneck has moved from "doing the work" to "knowing what work to do." That was always the harder skill; it is now the differentiating one.

@feynman

Naming and judgment in the AI era are like knowing how to navigate with a map in the era of GPS — most people never need the skill, and the people who have it are the ones you want driving when the signal drops.

@card
id: rfc-ch13-c012
order: 12
title: What Stays Human
teaser: The tooling landscape will keep rotating, the models will keep improving, and the recipes in chapters 3 through 9 will stay the same — because they describe code structure, not tools.

@explanation

This chapter will be stale. The volatility signal in this book's manifest is not a disclaimer; it is accurate. Cursor's lead in IDE integration may not persist. The model that writes the best refactoring prompts in 2026 may not be the one that does in 2027. New agentic tools will emerge; some of today's leading tools will be acquired, deprecated, or superseded.

What will not be stale:

- The catalog smells are still the right vocabulary for describing what is wrong with code. Feature Envy, Long Method, Divergent Change — these are observations about structure and coupling, not about technology. AI tools did not change what makes code hard to maintain.
- The mechanical recipes are still correct. Extract Method works the same way regardless of whether a human or a model performs the extraction. The preconditions for safe application are the same.
- Behavioral preservation is still the definition of refactoring. A change that alters what the code does is not a refactoring, regardless of how it was generated.
- Tests are still the only reliable way to know that a refactoring preserved behavior. Nothing about AI generation changes the epistemics here.

What will keep changing:

- Which tools perform which class of refactoring most reliably
- Which models hallucinate least on which language
- How much of the agentic loop can be trusted without human review
- How small the review unit needs to be to maintain adequate safety

Read this chapter for the principles; check the current tooling landscape for the specifics. The discipline is durable. The tool recommendations are not.

> [!info] As of 2026-Q2 — the two things most worth investing in regardless of where the tooling lands: the habit of writing characterization tests before refactoring, and the discipline of framing AI refactoring requests with explicit behavioral constraints. Both transfer across tools, models, and whatever comes next.

@feynman

The catalog's recipes surviving the AI era is like sheet music surviving the synthesizer — the underlying structure of what makes the composition work did not change because the instrument for playing it got more capable.
