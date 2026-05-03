@chapter
id: aicr-ch03-prompting-for-refactoring
order: 3
title: Prompting for Refactoring
summary: Prompting is the leverage point of AI-assisted refactoring — the difference between a 95% success rate and a 50% success rate is almost always the prompt, not the model.

@card
id: aicr-ch03-c001
order: 1
title: The Prompt Is the Spec
teaser: When you delegate a refactoring to an AI model, the prompt is the only place your constraints live — if you don't write it down, the model has no way to know it.

@explanation

Vague prompts produce vague refactorings. This is not a model limitation you can route around by picking a better model — it is a structural property of the task. The model cannot infer your intent from context it was not given. If you don't specify what must stay the same, the model will change it. If you don't specify the scope, the model will guess.

The shift that makes AI refactoring reliable is treating prompt quality the same way you treat test coverage: a gap in the prompt is a gap in the specification, and a gap in the specification will eventually produce a defect.

Three things every non-trivial refactoring prompt needs:

- **Why you're making the change.** The model makes better structural decisions when it understands the goal, not just the mechanical instruction.
- **What is in scope.** An explicit boundary on which files, functions, or patterns the change applies to.
- **What must not change.** Behavior, public API, error semantics — whatever correctness depends on.

The analogy that keeps this grounded: a pull request description that only says "refactor" is useless to a reviewer. A prompt that only says "refactor" is useless to a model. Prompt as PR description is a useful mental check before you send anything.

> [!warning] Model quality has almost no effect on output quality when the prompt is underspecified. A stronger model will produce a more fluent wrong answer, not a correct one.

@feynman

Writing a refactoring prompt is like writing a scope-of-work for a contractor: the clearer you are about what you want done and what you don't want touched, the fewer surprises you get back.

@card
id: aicr-ch03-c002
order: 2
title: Intent-First Prompts
teaser: Starting with why before how gives the model the context it needs to make judgment calls correctly — and refactoring always involves judgment calls.

@explanation

Two prompts that produce different outputs:

```text
Convert this function to async/await.
```

```text
I want to convert this function to async/await so the call site can use
structured concurrency and stop blocking the main thread. The external
behavior must be identical — same error types, same return type shape,
same logging side effects.
```

The second prompt produces a structurally better result because the model can now reason about trade-offs. If the callback pattern was doing something that doesn't translate cleanly to async/await — an error swallowing idiom, a timing dependency — the model will flag it rather than silently paper over it.

Intent also constrains scope implicitly. "I'm extracting this so it can be tested in isolation" tells the model not to inline anything, not to merge it with adjacent logic, and to preserve the seam that makes injection possible.

The pattern: open with `I want to [do X] because [reason]`, then follow with the mechanical instruction and constraints. The because clause is not courtesy — it's load-bearing specification.

The failure mode: providing a reason that conflicts with the instruction. "I want to simplify this because it's hard to test, but don't change the interface" will produce inconsistent output if simplification requires interface changes. Resolve the conflict in the prompt before sending.

> [!tip] If you can't write a one-sentence reason for a refactoring, that's a signal to pause and think before prompting. The model will have the same problem you do.

@feynman

Briefing a junior engineer with "rewrite this function" versus "rewrite this function so it's easier to unit-test without hitting the database" produces completely different first drafts — intent narrows the solution space the same way.

@card
id: aicr-ch03-c003
order: 3
title: Scope Boundary Prompts
teaser: Explicitly naming what is in scope — and what is not — is the single most effective safety move in an AI refactoring workflow.

@explanation

The most common source of unintended changes is an underspecified scope. Without explicit boundaries, the model will refactor what it thinks is related, and it will usually be right — and occasionally wrong in a way that takes hours to find.

A scope boundary prompt names both sides of the line:

```text
Refactor only the `parseConfig` function in config/loader.ts.
Do not modify:
- The `ConfigSchema` type definition
- Any other functions in this file
- Any call sites in other files
```

Explicit file paths are better than implicit references. "Only change this function" is weaker than "only change lines 42–87 of loader.ts." When the model has an exact boundary, it will flag cases where the refactoring cannot be contained within that boundary rather than silently expanding scope.

The scope boundary pattern is especially important for:

- Functions with many call sites — you want a clean refactoring of the implementation without a cascade of call-site changes
- Modules at architectural seams — changing the internal logic without touching the public contract
- Batch refactoring runs — when you're iterating the same transform across many files and need each application to be self-contained

The failure mode: a scope that is too narrow to be meaningful. "Only change this one line" that happens to be entangled with the five lines around it will produce a technically compliant but structurally broken result. If the scope boundary cannot hold the refactoring, the model should tell you — make sure your prompt asks for that.

> [!info] As of 2026-Q2 — models with tool use or file-read access may expand scope on their own initiative. Explicit "do not modify" lists are more reliable than assuming the model will stay within the current file.

@feynman

Scope boundary prompts are like painter's tape before a wall repaint — the tape doesn't do the painting, but it's the difference between a clean result and a mess that takes longer to fix than the job itself.

@card
id: aicr-ch03-c004
order: 4
title: Anti-Goal Prompts
teaser: Listing what you do not want changed — behavior, signatures, error semantics — is often more precise than describing what you do want.

@explanation

Anti-goal prompts name the things that must survive the refactoring unchanged. This is a different framing from scope boundaries: scope tells the model which code to touch, anti-goals tell the model which properties of that code are invariants.

```text
Refactor this authentication middleware to reduce nesting depth.
Do not change:
- The function signature (same parameters, same return type)
- The HTTP status codes returned on each error path
- The order of validation checks (rate limit before token validation)
- Any log message strings (they are used for alerting)
```

Anti-goals are especially valuable for:

- **Public APIs** — callers in other codebases or other teams depend on the signature; breaking it is not a refactoring
- **Error semantics** — the model will often rationalize error handling when it "cleans up" a function; naming error types as anti-goals prevents this
- **Ordering and timing** — side effects that happen in a specific sequence for a reason the model cannot infer from structure alone

The act of writing the anti-goal list is itself useful. You frequently discover constraints you had not made explicit — behaviors that are load-bearing in ways that are not obvious from the code structure.

The failure mode: anti-goals that are too broad. "Do not change any behavior" is not an anti-goal — it's a contradiction of the instruction to refactor. Anti-goals should be specific properties, not general preservation of everything.

@feynman

An anti-goal list in a prompt is like the "do not disturb" items in a renovation spec — you're telling the contractor exactly which walls are load-bearing before they start swinging a hammer.

@card
id: aicr-ch03-c005
order: 5
title: Few-Shot Examples
teaser: Showing one or two before-and-after pairs in the prompt produces more consistent results than describing the transform in words — especially when the pattern is stylistic rather than structural.

@explanation

When the refactoring has a clear mechanical pattern that is hard to specify abstractly, examples outperform descriptions. This is particularly true for style-level transforms: naming conventions, error-handling idioms, comment style, formatting that does not change behavior but does need to be consistent.

A few-shot prompt for a callback-to-promise transform:

```text
I'll show you the pattern, then apply it to the function below.

Before:
  function fetchUser(id, callback) {
    db.query('SELECT * FROM users WHERE id = ?', [id], (err, rows) => {
      if (err) return callback(err);
      callback(null, rows[0]);
    });
  }

After:
  async function fetchUser(id) {
    const rows = await db.query('SELECT * FROM users WHERE id = ?', [id]);
    return rows[0];
  }

Now apply the same transform to:
[target function]
```

Few-shot examples work best when:

- The transform has a clear surface pattern but subtle edge cases (showing the edge case in the example teaches the model to handle it)
- The target codebase has a house style that deviates from the model's defaults
- You are running the same transform across many files and need consistency across all applications

The failure mode: examples that carry unintended style signals. If your example uses a particular error handling idiom or a specific variable naming convention, the model will generalize that — including into places where it doesn't apply. Keep examples narrow and representative.

> [!tip] For batch refactoring, use one well-chosen example per session rather than adding examples for each individual case. A strong representative example is more useful than many partial ones.

@feynman

Few-shot examples in a prompt are like showing a new hire the output of the last three tickets before asking them to complete the next one — the example communicates style and conventions faster than any written description could.

@card
id: aicr-ch03-c006
order: 6
title: Output Format Constraints
teaser: Specifying how the output should be formatted — unified diff, specific file paths, code only — is what separates output you can act on immediately from output you have to clean up first.

@explanation

By default, models produce explanatory prose around the changed code. That is useful for exploration and learning. It is not useful when you have a script that needs to apply the change to 200 files. Specify the format.

```text
Output only the modified function. No explanation before or after.
Preserve the surrounding code exactly as-is. Do not include file-level
imports or other functions.
```

Or, for diff-based workflows:

```text
Output a unified diff (--- a/path/to/file.ts +++ b/path/to/file.ts format).
No explanation. No markdown fences. Raw diff only.
```

Format constraints that are worth knowing:

- **Code only** — eliminates explanatory prose; useful when the output feeds a pipeline
- **Unified diff** — machine-applicable; lets you review the change before applying it
- **Specific file paths in diff headers** — required for `git apply` to work without manual editing
- **No markdown fences** — if your tooling is consuming raw output, backtick blocks add noise that must be stripped

The failure mode: asking for a diff when the change is larger than the context window can produce reliably. Diffs for large files become inconsistent and hard to apply. For large transforms, code-only output with clear delimiters is more reliable than a diff.

> [!info] As of 2026-Q2 — structured output modes (JSON schema, tool use) can enforce format more reliably than prose instructions for models that support them. For tooling integrations, structured output is worth the setup cost.

@feynman

Output format constraints are like specifying file format when commissioning a design — if you say "I need an SVG" rather than just "I need a logo," you don't get a PNG that has to be converted before it can go into production.

@card
id: aicr-ch03-c007
order: 7
title: Chain-of-Thought for Risky Transforms
teaser: Asking the model to enumerate edge cases before producing the rewrite surfaces problems that would otherwise appear silently in the output.

@explanation

For transforms where correctness is non-trivial — concurrency changes, type system migrations, memory management rewrites — asking the model to reason before producing code catches more defects than reviewing the output after the fact.

```text
Before rewriting this function, enumerate:
1. All edge cases in the current implementation (null inputs, empty
   collections, error paths, concurrency assumptions)
2. Any semantic changes that the rewrite would introduce
3. Any assumptions you are making that I should verify

Then produce the rewrite.
```

The reasoning step does two things. First, it forces the model to build a more complete internal representation of the code before generating the replacement. Second, it surfaces the model's assumptions explicitly — which means you can catch a wrong assumption before it is baked into the output.

Chain-of-thought prompts are most valuable for:

- **Concurrency refactorings** — async transforms, lock removal, parallel execution changes that can introduce races
- **Type system migrations** — adding strict nullability, migrating generics, where implicit behavior changes are easy to miss
- **Error handling rewrites** — any change to which errors surface and how they propagate

The failure mode: the reasoning step adds latency and increases output length significantly. For mechanical transforms with no behavioral edge cases, chain-of-thought adds cost without value. Use it selectively on the transforms where silent drift is the real risk.

> [!warning] Chain-of-thought output should be read, not just produced. If you ask the model to reason and then ignore the reasoning, you lose the entire value of the pattern.

@feynman

Asking a model to reason through edge cases before rewriting is like asking a surgeon to talk through the procedure before making the first incision — the planning step is where problems get caught cheaply.

@card
id: aicr-ch03-c008
order: 8
title: The Checklist Prompt Pattern
teaser: Ending a prompt with "before producing output, verify:" turns the model into its own first reviewer and catches the most common drift errors before they reach you.

@explanation

The checklist prompt appends a verification step to the generation instruction. The model checks its own output against explicit criteria before returning it — or, more precisely, the checklist shapes what the model generates by making the criteria salient at generation time.

```text
Refactor the error handling in this module to use a Result type instead
of thrown exceptions. Constraints:
- All public function signatures must remain unchanged
- All error messages must be preserved exactly
- No new dependencies

Before producing output, verify:
- [ ] Every public signature is unchanged
- [ ] Every error message string appears in the output
- [ ] No import statements were added
- [ ] The output compiles without type errors (reason through it)
```

The checklist pattern works best when:

- The constraints are objective and checkable (unchanged signatures, preserved strings)
- You are doing a transform that has a consistent set of failure modes you have seen before
- You want the model to flag violations rather than silently satisfy them approximately

The failure mode: checklists that are too long or contain subjective criteria. A checklist with twelve items loses coherence — the model will satisfy them nominally rather than substantively. Keep it to four or five concrete, binary checks.

> [!tip] The first time you run a new transform type, do it without a checklist and note what went wrong. That list of what went wrong becomes your checklist for every subsequent run.

@feynman

The checklist prompt pattern is the preflight checklist in aviation — not because pilots don't know how to fly, but because verification done systematically before departure catches the things familiarity causes you to skip.

@card
id: aicr-ch03-c009
order: 9
title: Multi-Step Prompts
teaser: Breaking a refactoring into discovery, plan, and execute phases produces more reliable results than asking for the full output in a single shot — especially when the codebase context is large.

@explanation

Single-shot prompts for complex refactorings fail in a predictable way: the model has to simultaneously understand the codebase, reason about the transform, and generate correct output. Separating those concerns across multiple prompts reduces the cognitive load on each step and lets you validate before proceeding.

A three-step pattern for a non-trivial refactoring:

**Step 1 — Discovery:**
```text
Read the following module and identify every location where the legacy
logging API is used. List each call site with the file, line reference,
and which arguments are passed.
```

**Step 2 — Plan:**
```text
Given this list of call sites, describe the transform needed to migrate
each one to the new structured logging API. Note any call sites that
cannot be migrated mechanically.
```

**Step 3 — Execute:**
```text
Apply the transform to the following file only. Use the plan from step 2.
```

Multi-step prompts are worth the overhead when:

- The refactoring touches more code than can be reliably held in one generation context
- There are call sites that need different handling (mechanical vs. manual)
- You need a human checkpoint between planning and execution

The failure mode: over-decomposing simple transforms. If the change is one function and three call sites, a single well-structured prompt is faster and produces the same quality. Multi-step adds overhead; use it for problems where single-shot reliability is genuinely insufficient.

@feynman

Multi-step prompting is the same discipline as writing a design doc before writing code — separating "what should we do" from "do it" prevents the worst mistakes from being baked in before anyone has a chance to review.

@card
id: aicr-ch03-c010
order: 10
title: The "Explain Your Changes" Follow-Up
teaser: Asking the model to summarize what it did after a refactoring is the fastest way to surface silent drifts that reviewing the diff alone would miss.

@explanation

The model will occasionally make changes that are technically within scope but semantically outside intent. These are the hardest defects to catch in code review because the code is correct — it just does something slightly different from what you asked for.

The follow-up prompt:

```text
You just produced a refactored version of this function. Summarize:
1. Every change you made to the logic (not just formatting)
2. Any assumptions you made that were not stated in the prompt
3. Any behavior that is different in the output versus the input
```

A good model response will either confirm the output matches the intent or flag a specific deviation. If the response is "no logical changes, formatting only," and the diff shows a changed conditional, you have found a silent drift worth investigating.

This pattern is worth running on:

- Any transform that touches conditional logic or error paths
- Refactorings of functions with side effects
- Cases where the model expanded scope beyond what you asked

The follow-up is cheap — one additional round trip. The value is asymmetric: when the refactoring is correct, the summary confirms it in 30 seconds. When something drifted, the summary surfaces it before the code goes into review.

> [!info] As of 2026-Q2 — in multi-turn sessions, the follow-up prompt can reference the previous turn directly. In single-shot or API workflows, include the output in the follow-up prompt explicitly.

@feynman

The "explain your changes" follow-up is the same as asking a contractor to walk you through what they did before you sign off — the walkthrough reveals the gap between what you intended and what was delivered, before the invoice is paid.

@card
id: aicr-ch03-c011
order: 11
title: Prompt Anti-Patterns
teaser: Vague verbs, over-broad scope, conflicting instructions, and missing context are the four failure modes that account for most bad AI refactoring output.

@explanation

The failure modes are consistent enough to name:

**Vague verbs.** "Improve this function," "clean this up," "make it better." These are not instructions — they are preferences without constraints. The model will produce a plausible-looking change that reflects its training distribution, not your intent. Replace with specific transforms: "reduce cyclomatic complexity to below 5," "extract the validation logic into a separate function named `validateInput`."

**Over-broad scope.** "Refactor this module." A module with eight functions and three types is not a single refactoring — it is eight or more. Broad scope produces a large diff that is hard to review, hard to revert, and likely contains at least one change you didn't want. Scope one function or one pattern per prompt.

**Conflicting instructions.** "Simplify this function but don't change any behavior." Simplification often requires behavioral trade-offs. "Add type annotations but keep it backwards compatible." These constraints are not always compatible. Contradictions produce unpredictable output — the model will resolve the conflict silently, and not always in the way you'd prefer.

**Missing context.** Asking the model to refactor a function without providing the type definitions it depends on, the interface it implements, or the call sites it must satisfy. The model will infer these and will occasionally infer them wrong.

> [!warning] "Improve the code quality" is the most common anti-pattern. It is too vague to constrain and too subjective to verify. Every prompt that uses "improve" without a specific criterion will produce output you have to second-guess.

@feynman

Prompt anti-patterns are the equivalent of a ticket that says "fix the bug" with no reproduction steps — the engineer will do something, it just might not be the thing you needed.

@card
id: aicr-ch03-c012
order: 12
title: Prompt Versioning and Reuse
teaser: Prompts that produce reliable refactoring results are worth storing, reviewing, and sharing — the prompt is now part of your codebase.

@explanation

A prompt that produces a correct, consistent output for a given transform type is a reusable artifact. Treat it like a script: store it, version it, and review changes to it.

The practical pattern at the team level:

```text
# prompts/refactoring/callback-to-async.md
# Last reviewed: 2026-03
# Applies to: Node.js callback-style functions targeting ES2022+

You are refactoring a Node.js function from callback style to async/await.
Constraints:
- Do not change the function name
- Do not change the parameter list (except removing the callback parameter)
- Replace callback(err, result) with return/throw semantics
- Preserve all existing JSDoc comments

Before producing output, verify:
- [ ] No callback parameter in the output signature
- [ ] Every error path throws rather than calls callback
- [ ] Return type reflects the resolved value, not void
```

What to factor into a template versus leave inline:

- **Template:** constraints that are stable across applications (language version, naming conventions, behavioral invariants that apply to the whole codebase)
- **Inline:** the target code, the specific scope boundary, any context that changes per application

The failure mode: templates that accumulate too many constraints and become over-specified. A prompt template that was written for one specific migration and never trimmed will produce brittle results on the next one. Review templates after each use and remove constraints that no longer apply.

> [!tip] Store prompt templates in the repository alongside the code they refactor. A `prompts/` directory checked into version control means prompts go through the same review process as code.

@feynman

A prompt template library is the same idea as a runbook — you write down the procedure the first time you do something successfully so you don't have to rediscover it under pressure the next time.
