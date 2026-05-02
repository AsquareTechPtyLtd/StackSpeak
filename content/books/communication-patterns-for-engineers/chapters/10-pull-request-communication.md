@chapter
id: cpe-ch10-pull-request-communication
order: 10
title: Pull Request Communication
summary: The PR description is a document, a test plan, and a letter to the reviewer — all at once. Getting it right shortens review time, prevents rework, and creates a searchable record of why the code is the way it is.

@card
id: cpe-ch10-c001
order: 1
title: The PR Description as a Communication Artifact
teaser: A PR description is not a formality — it's a document that serves three different readers at the same time: the reviewer today, the future engineer debugging this code, and the automated systems that parse commit history.

@explanation

Most engineers treat the PR description as an afterthought: the code is done, the description is the annoying last step before hitting "Create." That's backwards. The description is doing significant work:

- It tells the reviewer what context they need to evaluate the change — without it, they're reading code in a vacuum.
- It documents intent, so when this code breaks in 14 months, whoever is debugging it can tell whether it broke in the intended way or an unintended one.
- It creates a searchable record. "Why did we change the rate-limiting logic?" is answerable with a git log search, but only if the PR described the why.
- It signals to the team that you've thought clearly about what you built — unclear descriptions often indicate unclear thinking, and reviewers notice.

A good PR description contains:
- What changed (high-level summary, not a recitation of the diff)
- Why it changed (the motivation — the bug, the requirement, the improvement)
- How to test it (steps a reviewer or QA engineer can follow to verify behavior)
- Any context that helps the reviewer evaluate tradeoffs (why this approach vs. an alternative)

The description doesn't need to be long. It needs to be complete. Four sentences covering those four elements beats a 10-paragraph narrative that buries the motivation on page two.

> [!info] If you find yourself writing a very long description, it's often a signal that the PR is too large. The description is revealing the problem, not causing it.

@feynman

Like writing a commit message — the code shows what changed, but only the message explains why anyone should care.

@card
id: cpe-ch10-c002
order: 2
title: PR Title Conventions
teaser: The PR title lives in git log forever. Imperative mood, a scope prefix, and a 72-character limit aren't pedantry — they're what makes the log readable 18 months later.

@explanation

The PR title ends up in merge commit messages, changelogs, release notes, and `git log --oneline` output. It will be read hundreds of times by people who don't have context. Optimize for that reader, not for the person writing it under deadline.

The conventions that actually help:

**Imperative mood.** "Add rate limiting to the auth endpoint" rather than "Added rate limiting" or "Adding rate limiting." Reads as an instruction, which is how git log reads cleanest — each entry describes what applying that commit does to the codebase.

**Scope prefix.** `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`. Follows the Conventional Commits convention. Makes it possible to scan a log and find all fixes, or filter for features in a release. Some teams extend this to `feat(auth):` or `fix(billing):` for module-level scoping.

**72 characters or fewer.** The hard limit where most tools wrap. Stay under it.

**Describe the change, not the effort.** "Fix null pointer in payment handler" is useful. "Spent 3 days hunting down the crash" is not — that belongs in the description body.

What to avoid:
- Vague titles: "Fix bug", "Update code", "WIP"
- Branch names as titles: "feature/JIRA-1234"
- Ticket numbers as titles: "JIRA-1234" with no description
- Past tense or present progressive that creates ambiguity in log scans

> [!tip] Write the title as if it will appear in a changelog sent to other engineers. Would they understand what changed from the title alone?

@feynman

Like a newspaper headline — the summary of the story in one line, written for the reader skimming, not the journalist who wrote it.

@card
id: cpe-ch10-c003
order: 3
title: The PR Body Structure
teaser: Three sections — what changed, why it changed, how to test it — cover 90% of what reviewers need. The rest is context specific to your PR.

@explanation

A consistent body structure reduces the cognitive load for reviewers who read PRs all day. When the structure is the same across every PR, they know where to find the information they need without re-orienting.

A practical three-section structure:

**What changed.** A prose summary, not a diff recitation. "This replaces the synchronous email send in the checkout flow with a queued background job" is useful. "Modified EmailService.swift, updated CheckoutViewModel.swift, added JobQueueService.swift" is just the diff in sentence form — the reviewer can see that.

**Why it changed.** The motivation. Link the bug report, the Slack thread, the ADR, the product requirement. "Checkout was timing out when the email provider was slow — p99 latency spiked to 8s on Friday" is the kind of context that makes reviewers trust the change direction immediately.

**How to test it.** Concrete steps. Not "test as usual" — that puts the burden on the reviewer to figure out what "usual" means for this change:
- Steps to reproduce the scenario this fixes, if it's a bug
- Steps to exercise the new behavior, if it's a feature
- What the expected outcome looks like
- Any environment or flag requirements ("requires `FEATURE_EMAIL_QUEUE=true`")

Optional sections worth adding when relevant:
- **Screenshots or recordings** for visual or behavioral changes
- **Migration notes** if deployments require sequencing
- **Alternatives considered** if the approach is non-obvious

> [!tip] If you can't write the "Why it changed" section in two sentences, spend time on that before opening the PR. The description difficulty is telling you something about the change clarity.

@feynman

Like a scientific paper abstract — background, method, result, in that order, so the reader can decide whether to go deeper.

@card
id: cpe-ch10-c004
order: 4
title: Self-Review Notes
teaser: Flagging the hard parts for your reviewer is a sign of engineering maturity, not weakness. It focuses attention where it matters and signals that you've already thought critically about your own code.

@explanation

A self-review note is a comment or section in the PR description that tells the reviewer where to focus careful attention — and why.

Examples of useful self-review notes:

- "The retry logic in `BackgroundJobService.processNext()` is the part I'm least confident in — specifically around the backoff calculation when the job has been retried more than three times. Worth a close look."
- "I'm aware that the new `UserCache` class duplicates some behavior from `SessionCache` — I chose not to merge them because the invalidation rules are different, but I'm open to pushback."
- "Line 147 in `AuthViewModel.swift` has a race condition I couldn't reproduce reliably. Adding a note here because I want a second pair of eyes before we ship."

What self-review notes accomplish:
- Reviewers spend time on the code that needs it, rather than on the straightforward parts
- They signal intellectual honesty — you're not trying to sneak something through
- They document uncertainty, which becomes useful context if a bug surfaces later
- They prevent the reviewer from spending 20 minutes reviewing a helper function you already stress-tested and 5 minutes on the complex algorithm you're unsure about

Self-review notes don't have to be attached to problems — they can also highlight intentional tradeoffs: "This approach is O(n²) for small n — that's acceptable because n is bounded at 10 in our data model."

> [!warning] Don't use self-review notes as a substitute for fixing known issues before opening the PR. "I know the error handling is incomplete" should be a fix, not a note. Notes are for genuine uncertainty, not deferred work.

@feynman

Like annotating your own essay before handing it to an editor — pointing to the sections you know are rough saves time for both of you.

@card
id: cpe-ch10-c005
order: 5
title: Screenshots and Recordings for UI and Behavior Changes
teaser: For visual or behavioral changes, a 10-second screen recording replaces 500 words of description and removes the reviewer's need to check out the branch and run the app.

@explanation

Text is the right medium for describing logic. It is a poor medium for describing how something looks or how a user flow feels. For UI and behavioral changes, visuals are not optional — they're the most efficient form of evidence.

When to include visuals:
- Any visible layout or style change
- Any new user flow, modal, sheet, or transition
- Any animation or state transition
- Bug fixes where the old behavior was visible (before/after comparison)
- Changes that affect loading states, error states, or empty states

What to capture:
- **Screenshots** for static changes: layout, typography, color, spacing. Always include both light and dark mode if the app supports both.
- **Screen recordings** for any change involving motion, interaction, or state transitions. A recording of the checkout flow before and after the fix communicates instantly what a text description would take paragraphs to approximate.
- **Annotated screenshots** for layout changes that are subtle — use arrows or boxes to point out what changed, especially when the diff is a 2px spacing adjustment that won't be obvious in a static screenshot.

Practical considerations:
- Keep recordings short — capture the specific flow, not a 3-minute tour of the app
- Prefer recordings that show the interaction, not just the result
- Name files descriptively so the PR doesn't accumulate `Screen Recording 2024-11-03 at 14.22.31.mov`

> [!tip] On iOS/macOS, use the Simulator's `File > Record Screen` for quick recordings, or drag a `.mov` directly into the GitHub PR description field.

@feynman

Like attaching the receipt to an expense report — the claim is already credible, but the evidence makes approval faster.

@card
id: cpe-ch10-c006
order: 6
title: Test Evidence in PRs
teaser: Showing that tests pass is table stakes. Showing what you tested, how, and what the output looked like is what gives reviewers confidence the change actually works.

@explanation

A PR that says "tests pass" conveys almost no information. Test evidence that conveys confidence looks different:

**New tests for new behavior.** If you added a feature, show the test you wrote to cover it. Paste the test name or test output in the description. "Added `testCheckoutWithSlowEmailProvider_completesWithoutTimeout()`" is more confidence-inspiring than "tests pass."

**Passing test output for bug fixes.** For a regression fix, include the failing test output before the fix and the passing output after. This makes the fix verifiable without checking out the branch.

**Manual test steps and observed output.** For changes that are difficult to cover fully with unit tests (animations, third-party integrations, UI states), document the manual test you ran:
- Environment and device/simulator used
- Steps you followed
- What you observed

**Edge case coverage.** Explicitly note which edge cases you tested — empty state, network failure, concurrent requests, very long strings in UI, etc. Reviewers often ask about edge cases; answering preemptively closes the loop faster.

Test evidence is not about proving the code is perfect — it's about giving the reviewer enough signal to calibrate how much independent verification they need to do. A PR with thorough test evidence gets faster reviews because the reviewer trusts the level of diligence already applied.

> [!info] If you can't write a test for a change, document why in the PR. "This change is difficult to unit test because X — I validated it manually with Y" is acceptable. Silence on test coverage is not.

@feynman

Like a lab report — the result matters, but showing your work is what lets anyone else verify or reproduce it.

@card
id: cpe-ch10-c007
order: 7
title: Writing PRs for Future Readers
teaser: The primary reader of a PR description is not the reviewer — it's the engineer debugging this code 18 months from now using git blame and git log.

@explanation

The review is temporary. The commit history is permanent. Write the PR with the permanent reader in mind.

What future readers need from PR descriptions:
- **The problem that motivated the change.** Not "fix bug" — "fix null pointer when user has no payment method on file (introduced in #892)." The context collapses the debugging surface from the entire codebase to one PR.
- **Why this approach, not an alternative.** If you chose a background queue over synchronous processing, that choice will look strange to someone reading the code without context. "We chose async to avoid blocking the checkout critical path; synchronous processing was acceptable until email latency P99 exceeded 4s" makes the intent clear.
- **What wasn't changed, and why.** Sometimes the most important thing to document is the decision not to touch something. "We're not refactoring the legacy payment adapter in this PR — that's tracked in #1034 to avoid scope creep."
- **Links that will still be relevant.** Bug reports, ADRs, design docs, Slack threads (if your Slack is retained) — anything that provides background. GitHub issues outlast Slack threads.

What future readers don't need:
- Descriptions of what the diff shows (they can read the diff)
- Explanations of how the language works
- Reassurances that the code was tested ("tested on simulator" adds nothing without specifics)

> [!tip] A quick test: imagine you're reading this PR description cold, with no memory of writing it, two years from now. Can you tell why this code exists? If not, the description needs more "why."

@feynman

Like leaving commented notes in a complex function — not for the compiler, but for the person who inherits the code and needs to understand the intent without access to the original context.

@card
id: cpe-ch10-c008
order: 8
title: Responding to Code Review
teaser: Responding to review comments well is a distinct skill from writing good code. The goal is to close the loop efficiently — acknowledge, act, and keep the conversation moving forward.

@explanation

Code review comments are not personal assessments of your ability. They're questions, suggestions, and observations from someone trying to help ship better code. Responding to them well means treating them that way.

Practical patterns for responding:

**Acknowledge and resolve.** For straightforward feedback — a bug you missed, a naming improvement, a missing test — just fix it, push, and resolve the thread with a short note: "Fixed in latest push" or "Good catch, updated." Don't over-explain.

**Clarify before changing.** If a comment seems to be based on a misunderstanding, ask before rewriting. "I think this handles the case you're describing — the null check on line 14 covers the empty state. Am I missing something?" is faster than changing code that didn't need changing and opening a new round of review.

**Push back constructively.** Disagreement is allowed. State your reasoning, reference supporting evidence (a benchmark, a spec, a prior decision), and make a clear ask: "I'd rather keep this synchronous for now because the async version adds 40 lines and we don't yet have evidence of the latency problem. Can you share what's motivating the concern?" Frame it as a collaboration toward the right answer, not a defense.

**The "not blocking" acknowledgment.** For stylistic preferences or minor suggestions the reviewer isn't requiring — "I see the point, I'll track it for cleanup" closes the thread without creating churn. It's also honest: if you're not going to fix it now, say so.

> [!warning] Never resolve a reviewer's thread unilaterally without addressing it. If you're intentionally not acting on a comment, say so explicitly. Silently resolving is the fastest way to erode reviewer trust.

@feynman

Like responding to manuscript feedback — you don't have to accept every note, but you do have to address every note.

@card
id: cpe-ch10-c009
order: 9
title: Giving Code Review Feedback
teaser: The nit / suggestion / blocking distinction is not about softening criticism — it's about giving the author the information they need to prioritize and act.

@explanation

Not all review comments have the same urgency. When reviewers don't signal this, authors have to guess — which leads to unnecessary back-and-forth, stalled PRs, and friction on both sides.

A three-tier convention used effectively across many engineering teams:

**`nit:`** — a minor stylistic or preference comment. The reviewer doesn't require a change; they're noting it. "nit: prefer `guard let` over `if let` here for early exit style." The author can take it or leave it without blocking the merge.

**`suggestion:`** — a substantive improvement the reviewer recommends but isn't blocking on. "suggestion: this could use a constant for the magic number 3 — `maxRetries` would make it more readable." The author should consider it, and if they choose not to act, they should say why.

**`blocking:`** — a change the reviewer requires before approving. A correctness issue, a security concern, a missing test for a critical path, a violation of team conventions. "blocking: this endpoint is missing authentication." The PR doesn't merge until this is addressed.

Using the convention consistently:
- Reviewers: prefix every comment with one of the three levels. The extra five characters prevent miscommunication.
- Authors: don't merge with unresolved `blocking:` comments. Respond to `suggestion:` comments even if you choose not to act. `nit:` comments can be resolved with a brief acknowledgment or a fix.

Additional useful prefixes: `question:` for genuine questions that don't imply required changes, `praise:` (or nothing, just a positive comment) for code you want to highlight as a good approach.

> [!tip] If you find yourself leaving mostly blocking comments on every PR, consider whether the team's PR scope and preparation norms need adjustment — not every issue needs to be caught in review.

@feynman

Like an editor marking up a manuscript with different pen colors for errors vs. suggestions vs. preferences — the marks themselves communicate priority, not just the content.

@card
id: cpe-ch10-c010
order: 10
title: Async Code Review Etiquette
teaser: Code review is an async workflow. The etiquette that makes it function — response times, status signals, and not going silent — is as important as the quality of the feedback itself.

@explanation

Most code review happens across time zones, across calendars, and between other work. The informal norms that make this function are often undocumented but consistently felt when they're violated.

Norms that reduce friction:

**Respond within one business day.** If you're a reviewer who's been tagged, a same-day response (even "I'll look at this tomorrow, blocked on incident response today") prevents the author from guessing whether their PR is in the queue. A response SLA of one business day is a reasonable team default.

**Re-request review after addressing comments.** GitHub's "Re-request review" button exists for this reason. Don't assume the reviewer will notice a new push — explicitly ping them that the comments have been addressed and you're ready for another pass.

**Don't abandon a review mid-way.** If you start reviewing and don't have time to finish, leave a comment: "I've reviewed through line 200, will finish tomorrow" or "Leaving partial feedback — the auth section specifically needs another reviewer." Partial feedback with a status note is better than silence.

**Don't go silent on the author side.** If a PR has been sitting without action for two days, a short message — "Hey, this is blocking the feature branch — any chance to review today?" — is appropriate. It's not nagging; it's keeping the async loop from stalling indefinitely.

**Approve with comments when comments are non-blocking.** Many reviewers hold approval until every nit is resolved. This creates unnecessary cycles. If comments are all `nit:` or `suggestion:`, approve and let the author decide whether to address before merging.

> [!info] Async code review works by shared norms, not by tooling. If PRs are routinely sitting for days, the problem is a team norm, not a GitHub settings problem.

@feynman

Like async communication on a distributed team — the workflow is fine, but only if everyone sends the signals that keep the loop moving.

@card
id: cpe-ch10-c011
order: 11
title: Stale PR Hygiene
teaser: A PR open for two weeks is a liability — it diverges from main, accumulates context debt, and signals an unresolved decision. Small PRs and the draft pattern are the tools that prevent staleness.

@explanation

PRs stall for predictable reasons: scope is too large, the change is blocked on a dependency, the author is uncertain about an approach, or review cycles have dragged on. The cost of a stale PR:

- **Merge conflicts accumulate.** Every day a long-lived branch drifts from main is a day of integration work deferred, and that work compounds.
- **Context fades.** The reviewer's context from their first read is gone a week later. The author's memory of why they made specific choices has faded. The review cycle restarts effectively from scratch.
- **It creates ambiguity in the team's queue.** Is this PR dead? Is it blocked? Is it waiting for review? Silence is the worst signal.

Patterns that prevent stale PRs:

**The draft pattern.** Open the PR as a draft as soon as the branch exists — even before it's ready for review. This signals work in progress, starts CI, and lets others track it. Promote to "Ready for review" when you want feedback.

**Keep PRs small.** The single most effective intervention. PRs under 400 lines get reviewed faster, generate better feedback, and are easier to merge. If you need to ship a large feature, use a feature branch as the integration target and stack smaller PRs on top of it.

**Close or update stale PRs explicitly.** If a PR is blocked indefinitely, either close it with a note explaining why, or leave a comment updating its status. Don't let it sit in "open" limbo — that's noise for the team.

**Rebase regularly on long-lived branches.** A daily or every-other-day rebase on active feature branches keeps merge conflicts small and keeps CI reflecting the real integration surface.

> [!warning] A PR open for more than a week without activity is usually a process problem, not a code problem. The fix is to address what's blocking — not to keep it open indefinitely.

@feynman

Like a parking space with an abandoned car in it — the longer it sits, the more it blocks everything else and the harder it becomes to move.

@card
id: cpe-ch10-c012
order: 12
title: Anti-Pattern: The 3000-Line PR
teaser: A 3000-line PR with "various fixes" as the title is not a PR — it's a blame avoidance strategy. It's unjustifiable scope crammed into a single review event that no reviewer can evaluate properly.

@explanation

The 3000-line PR is the most common and most damaging PR anti-pattern in professional engineering teams. It appears in several forms:

- The feature-plus-refactor PR: "while I was in this file, I cleaned up the whole module"
- The deadline panic PR: two weeks of work batched because "we need to ship this sprint"
- The "it's all connected" PR: genuine interdependency used to justify unlimited scope
- The low-confidence PR: the author isn't sure any individual piece is right, so they bundle everything to obscure the uncertainty

What happens to 3000-line PRs:
- Reviewers rubber-stamp them because thorough review is not practically possible
- Bugs that would have been caught in a smaller PR get through because the diff is too noisy
- Merge conflicts are severe and time-consuming
- The git history becomes useless for forensics — one PR contains changes that belong to five different logical units
- The review feedback is thin or nonexistent, which deprives the author of the learning opportunity

How to avoid it:
- Break the work before you start coding, not after. If the feature requires three conceptual units, plan three PRs.
- Separate refactors from behavior changes. A PR that changes behavior and also refactors is doubly hard to review.
- Ship infrastructure and logic separately — add the new table, then add the code that uses it.
- If genuine coupling makes a large PR unavoidable, document it explicitly and make the description exceptional.

> [!warning] If a PR title says "various fixes," "cleanup," or "misc," that's a signal the author couldn't articulate a single clear purpose. That's a PR to reject at the title level and ask the author to break up.

@feynman

Like submitting a 40-page memo when the decision requires a 2-page brief — the length isn't impressive, it's a signal that the thinking hasn't been done.
