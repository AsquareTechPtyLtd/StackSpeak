@chapter
id: cpe-ch03-writing-patterns
order: 3
title: Writing Patterns — ADRs, RFCs, and Design Docs
summary: The recurring document types in engineering teams — their purpose, format, lifecycle, and the workflow that keeps them from going stale the week after they're written.

@card
id: cpe-ch03-c001
order: 1
title: Docs as Code
teaser: Treating documentation the same way you treat source code — versioned, reviewed, and shipped alongside the change that motivated it — is the difference between docs that stay accurate and docs that become archaeology.

@explanation

Docs-as-code is a practice, not a tool. The core principle: documentation lives in the same version control system as the code it describes, is written in a plain-text format (almost always Markdown), and goes through the same review process as code changes — pull requests, reviewers, approval gates.

What this practice changes in practice:
- A code change and its documentation change land in the same commit or PR. The diff is reviewable together.
- Documentation history is queryable with `git log` and `git blame`. You can see who wrote a claim and when.
- Documentation changes require the same review bar as code changes — they don't bypass quality gates because "it's just a doc."
- Old documentation is explicitly superseded or deleted through the same process as removing dead code.

What this practice does not fix:
- Writers who don't write. Version control does not produce content.
- Docs that were never useful to begin with.
- The temporal distance between "code merges" and "someone updates the README."

The last point is the critical one. Docs-as-code only prevents rot if the team enforces the discipline that doc changes accompany code changes — not as a suggestion, but as part of the definition of done.

> [!tip] Add a documentation check to your PR template. "Have you updated relevant docs?" as a checkbox does not guarantee updates, but it makes omission a deliberate choice rather than an oversight.

@feynman

Like keeping tests in the same repo as the code they test — the proximity is the practice; without the discipline, the proximity alone doesn't help.

@card
id: cpe-ch03-c002
order: 2
title: Architecture Decision Records
teaser: An ADR is a short, permanent record of a significant architectural choice — the context that made it necessary, the options considered, and the reasoning for the decision made.

@explanation

An Architecture Decision Record (ADR) answers a question that code cannot: why is this system designed the way it is? Code tells you what was chosen. An ADR tells you what was rejected and why, which is often the more important information when you need to change something years later.

The standard ADR format (from Michael Nygard's original proposal):

- **Title:** short noun phrase describing the decision. "Use PostgreSQL for the primary datastore" not "Database choice."
- **Status:** proposed, accepted, deprecated, or superseded.
- **Context:** the forces at play when this decision was made. What was true about the system, the team, and the constraints that made this decision necessary.
- **Decision:** the choice made, stated affirmatively. "We will use PostgreSQL."
- **Consequences:** what follows from this decision — both positive and negative. What becomes easier, what becomes harder, what is now off the table.

When to write an ADR:
- When rejecting a significant option that might look obviously correct to the next person who evaluates the system.
- When making a choice that would be expensive to reverse.
- When the decision is non-obvious and the reasoning will not be apparent from the code.

When not to write one:
- Trivial implementation choices that have no long-term consequence.
- Choices that are already covered by team standards or linting rules.
- Decisions that will certainly be revisited within weeks.

> [!info] ADRs are decision records, not design documents. They record choices already made. If the decision hasn't been made yet, you're writing an RFC, not an ADR.

@feynman

Like a git commit message for architecture — the diff shows what changed, but only the message explains why.

@card
id: cpe-ch03-c003
order: 3
title: ADR Lifecycle
teaser: An ADR isn't done when it's written — it moves through states as the system evolves, and managing those states is what keeps the record useful rather than misleading.

@explanation

The statuses in an ADR aren't decoration. They communicate whether the recorded decision is still in effect and whether the reasoning still applies.

The standard lifecycle:

- **Proposed:** a decision is under discussion. The ADR captures the context and options in motion. Not yet binding.
- **Accepted:** the decision is made and the system should reflect it. This is the primary live state.
- **Deprecated:** the decision was accepted but the approach it describes is no longer recommended, even if the system still contains artifacts of it. Use this when the decision is being phased out.
- **Superseded:** the decision has been explicitly replaced by a newer decision, which should be referenced by ID. The old ADR stays intact — it's a historical record, not a wiki page to be edited in place.

What breaks when teams don't manage lifecycle:
- Engineers read an accepted ADR whose reasoning no longer applies and treat it as current guidance.
- The system diverges from accepted ADRs with no record of why.
- ADRs accumulate without anyone tracking whether they're still accurate, making the full set untrustworthy.

Operationalizing lifecycle management:
- Add ADR review to major refactor tickets. When you change a significant architectural piece, check whether an ADR should be superseded.
- Make ADR status part of architecture review. "Does any accepted ADR conflict with this proposal?" is a useful standing question.
- Keep the number of accepted ADRs bounded. If the catalog grows to hundreds, the review cost becomes prohibitive.

> [!warning] Never edit the body of an accepted ADR to revise history. If the decision changed, mark the old one superseded and write a new one. The old ADR is the record of what was true then.

@feynman

Like deprecating an API — the old version stays documented and reachable; you just signal clearly that it's no longer the thing to use.

@card
id: cpe-ch03-c004
order: 4
title: RFCs
teaser: A Request for Comments is a structured proposal for a significant change — it opens a window for team input before a decision is locked, and creates a durable record of the reasoning whether or not the proposal is accepted.

@explanation

The RFC (Request for Comments) format originated at IETF for internet standards and has been adopted by engineering teams at scale — notably Rust, React, and many product organizations — as a way to coordinate significant decisions across people who can't all be in the same room.

A useful RFC structure:

- **Summary:** one paragraph on the proposed change and its motivation.
- **Motivation:** what problem is this solving, and why now?
- **Detailed design:** how the proposal works in practice. Enough detail to evaluate it concretely — not a full implementation plan, but not a vague direction either.
- **Drawbacks:** the honest case against the proposal. If you can't articulate the downside, you haven't thought it through.
- **Alternatives:** what other approaches were considered and why this one was chosen over them.
- **Unresolved questions:** what's still unclear and needs resolution before or during implementation.

The RFC circulation process:
- Author drafts the RFC and shares it for comment, typically with a specified comment window (one to two weeks).
- Stakeholders and reviewers comment asynchronously. The author responds, revises, and updates the unresolved-questions section.
- A designated decision-maker (team lead, architecture group) accepts, rejects, or asks for further revision at the end of the comment window.
- The RFC is merged into the repository with its final status recorded.

> [!info] The RFC comment window is not optional. Without a deadline, the "RFC that never gets a decision" is the default outcome — everyone has read it, no one has rejected it, and it's unclear whether the work can start.

@feynman

Like a design review with an async comment thread and an explicit close date — the structure is what prevents it from becoming a conversation that drifts forever.

@card
id: cpe-ch03-c005
order: 5
title: The RFC That Never Gets a Decision
teaser: An RFC without a designated decision-maker and a close date is a document, not a process — it will accumulate comments and produce no outcome.

@explanation

The single most common RFC failure mode is the proposal that sits in a PR for months, receives thoughtful feedback, undergoes multiple revisions, and never reaches a decision. The author can't proceed, the reviewers feel like they did their part, and the question remains open.

Why this happens:
- No designated decision-maker. Everyone has the power to comment; no one has the authority to close.
- No close date. Without a deadline, asynchronous decision-making defaults to indefinite deferral.
- The proposal is contentious and the decision-maker is conflict-averse. It's easier to leave the PR open than to accept and own the blowback.
- Scope creep during review. The RFC starts as "should we use gRPC?" and acquires thirty comments about service mesh architecture, which requires a separate RFC, which is never written.

Fixes that work:
- **Assign a decision-maker at the time the RFC is opened.** It's in the template. If it's blank, the RFC is not valid for review.
- **Set a close date in the RFC summary.** "Comments accepted until [date]. Decision by [date + 3 days]."
- **Separate blocking concerns from non-blocking concerns.** Reviewers mark concerns as "must resolve before acceptance" vs. "nice to address before implementation." Blocking concerns require resolution; non-blocking concerns are on record.
- **Accept with conditions.** The decision can be "accepted, with the following open questions to be resolved in implementation" — this unblocks work without pretending the questions don't exist.

> [!warning] If your RFC process produces proposals that routinely take longer than four weeks to reach a decision, the bottleneck is authority, not clarity. Fix the process, not the document format.

@feynman

Like a code review where no one has merge rights — the feedback is real but the work can never ship.

@card
id: cpe-ch03-c006
order: 6
title: Design Docs
teaser: A design doc is a working document that captures what you're building, why, what options you considered, and what's still uncertain — written before significant implementation, updated during it, and preserved as a record after it.

@explanation

A design doc is not an ADR (which records a single decision) and not an RFC (which proposes a change for external comment). It's the working document for a feature or system — the place where the engineer doing the work thinks on paper before building.

What belongs in a design doc:

- **Problem statement:** what user or system problem is being solved. One to three paragraphs. If this is vague, the doc isn't ready to be written.
- **Goals and non-goals:** what success looks like, and explicitly what this system is not trying to do. Non-goals are as important as goals — they prevent scope creep during review.
- **Constraints:** technical, organizational, and timeline constraints that shaped the solution. Reviewers can't evaluate a design without understanding its constraints.
- **Options considered:** the realistic alternatives with brief tradeoffs. Not a comprehensive survey, but enough to show that the space was explored.
- **Proposed solution:** the approach with enough detail to evaluate feasibility and identify risks. Diagrams belong here.
- **Open questions:** things you don't know yet and need to resolve. Numbered, assigned if possible.

What does not belong:
- Implementation steps or sprint planning — that's a project plan, not a design doc.
- Marketing language or aspirational claims.
- A complete API specification — that's a separate spec document.

> [!tip] Write the problem statement and goals first, then share them for feedback before writing the rest. If reviewers don't agree on the problem, the proposed solution debate is premature.

@feynman

Like an architect's schematic drawings — not the building plans contractors work from, but the spatial reasoning that precedes them and that everyone reviews before committing to structural choices.

@card
id: cpe-ch03-c007
order: 7
title: Technical Specs vs Design Docs vs Implementation Plans
teaser: Three document types that engineers conflate constantly — each serves a different purpose, a different audience, and a different moment in the project lifecycle.

@explanation

The confusion between these three usually results in a document that tries to do all three jobs and does none of them well.

**Design doc:** explores the problem and proposed solution before significant implementation. Audience: engineers, tech leads, and adjacent teams who need to validate the approach. Written before implementation begins. Updated as understanding evolves. Goal: alignment on what's being built and why.

**Technical spec:** precisely specifies the interface, protocol, or format that a system exposes to callers. Audience: engineers who need to build against or integrate with the system. Written when the interface is stable enough to commit to. Not a narrative document — it's a reference. Goal: accurate, complete specification of the contract.

**Implementation plan:** sequences the work into tasks, phases, and owners. Audience: the engineering team doing the work and the manager tracking it. Written when the design is settled. Goal: coordination of who does what and when.

Why conflation is costly:
- A design doc that includes sprint tasks will be outdated before it's published. Sprint tasks change; the design doc should not.
- A technical spec that includes design narrative is hard to use as a reference. Engineers need to extract the spec from the reasoning.
- An implementation plan that includes design discussion turns project tracking into a design review, which is the wrong forum.

The practical rule: if you're explaining why, it's a design doc. If you're specifying the exact behavior of an interface, it's a technical spec. If you're sequencing tasks for execution, it's an implementation plan.

> [!info] It's fine for a small project to combine a brief design section and an implementation section in a single document — just label the sections clearly so readers know which mode they're in.

@feynman

Like the difference between an architect's concept sketches, the structural engineering drawings, and the contractor's build schedule — same project, three documents with three different jobs.

@card
id: cpe-ch03-c008
order: 8
title: README Patterns
teaser: A README that actually helps answers one question: what do I need to do to make this work, and why would I want to? The README that doesn't help answers neither.

@explanation

The repository README is the first document a new engineer sees. It sets the context for every subsequent interaction with the codebase. A weak README forces every new contributor to dig through source files and ask questions that should have been answered in five minutes.

A README that works covers:

- **What this is:** one to three sentences. What the project does, who it's for. If a new engineer can't explain the project after reading this paragraph, rewrite it.
- **Quick start:** the shortest path to a working state. Real commands, not prose descriptions of commands. If it requires ten steps, the project needs a setup script, not a longer README.
- **How it's structured:** where the significant parts of the codebase live. Not every file — the mental model for the layout.
- **How to run tests:** the exact command. Nothing more.
- **How to contribute:** link to a CONTRIBUTING doc if it exists, or a two-sentence summary if it doesn't.
- **Links to the canonical documentation:** if there's a wiki, a design doc, or an API spec, link to it here. The README is the front door, not the house.

A README that doesn't work:
- Opens with three paragraphs about the origin story of the project.
- Has a "Getting Started" section with twelve numbered steps and no script.
- Was written for the v1 architecture and has not been updated since the v2 refactor.
- Lists every feature as a bullet point with no indication of which ones actually work.

> [!warning] A README that describes the aspirational version of the project rather than the current version is worse than no README — it sends new contributors down incorrect paths.

@feynman

Like the first page of an IKEA manual — it either shows you the finished product and the tool list clearly, or you waste twenty minutes assembling the wrong piece.

@card
id: cpe-ch03-c009
order: 9
title: Runbooks
teaser: A runbook is an operational document for on-call engineers — step-by-step instructions for diagnosing and resolving specific failure modes, written for the version of yourself who has been woken up at 3am and cannot think clearly.

@explanation

A runbook is not a design doc, a tutorial, or a general reference. It has a specific job: enabling an engineer who is unfamiliar with a system to execute a specific response to a specific alert, in a specific amount of time, without making things worse.

What a runbook for a specific alert contains:

- **Alert name and trigger condition:** what fired this page and what threshold caused it.
- **Severity and urgency:** is this customer-facing? Is data loss possible? What's the impact if this isn't resolved in the next hour?
- **Initial diagnostic steps:** what to check first, with exact commands. `kubectl get pods -n production` not "check the pods."
- **Decision tree:** if X, do Y. If Z, do W. The branching logic should cover the four or five most common root causes.
- **Remediation steps:** exact commands and procedures for each root cause.
- **Escalation path:** who to wake up if the runbook doesn't resolve the issue, and how.
- **Post-incident actions:** what to do after recovery (open an incident ticket, notify stakeholders, run a cleanup job).

The runbook test: hand the runbook to an engineer who has never worked on this system. Ask them to follow it without help. If they get stuck, the runbook has a gap. Conduct this test when the runbook is written and annually thereafter.

An untested runbook is a liability — it gives on-call engineers false confidence in a document that may send them in the wrong direction at 3am.

> [!tip] Write runbooks immediately after resolving incidents. The steps are fresh, the root causes are documented in the incident ticket, and the gaps in the previous runbook are obvious from what actually happened.

@feynman

Like an emergency procedure checklist in aviation — designed to be followed under stress without requiring deep system knowledge, because expertise is not available on demand at 3am.

@card
id: cpe-ch03-c010
order: 10
title: Documentation as Part of the Definition of Done
teaser: A feature isn't done when the code ships — it's done when the next engineer can understand it, operate it, and change it without asking the author. Documentation is the mechanism that closes that gap.

@explanation

"Definition of done" (DoD) is the explicit list of conditions a piece of work must satisfy before it's considered complete. Most engineering teams have DoD criteria for testing, code review, and deployment. Fewer have enforceable DoD criteria for documentation — and it shows.

Documentation criteria that belong in a definition of done:

- **README updated** if the setup, configuration, or architecture changed.
- **API docs updated** if any interface was added, changed, or removed.
- **Runbook created or updated** if a new operational component was deployed.
- **ADR written** if a significant architectural decision was made during implementation.
- **Inline comments added** for any code whose intent is non-obvious from reading it.
- **Migration or upgrade notes added** if the change requires action from consumers or operators.

Why this discipline degrades without enforcement:
- Documentation tasks have no automated test that turns red when they're skipped.
- Documentation doesn't block shipping in most teams.
- The engineer who wrote the code is the worst person to assess how much documentation it needs — they already understand it.

The fix is structural, not aspirational. Add documentation to the PR template as explicit checkboxes. Block merge on a documentation review from someone who didn't write the code. Make documentation debt as visible as test coverage debt.

> [!info] The cost of writing documentation at feature time is roughly 10-20% of the implementation effort. The cost of reconstructing understanding six months later — through code archaeology, Slack archaeology, and interviewing the original author — is often comparable to re-implementing the feature.

@feynman

Like the closing inspection on a construction project — the building is not done just because the walls are up; it's done when it passes the checks that confirm it's safe to occupy.

@card
id: cpe-ch03-c011
order: 11
title: Docs in PRs
teaser: Reviewing documentation changes alongside code changes — in the same PR, with the same bar — is the workflow that keeps documentation accurate and prevents it from drifting into fiction.

@explanation

The docs-in-PRs workflow has a specific mechanism: the PR diff shows both the code change and the documentation change together. The reviewer sees them side by side. If the documentation doesn't match the code, the mismatch is visible before merge.

What this enables:

- **Accuracy review:** reviewers who spot a discrepancy between the code and the documentation can catch it in the same pass. They don't need to remember to check a separate wiki page after the fact.
- **Completeness review:** a code change that adds a significant new behavior with no documentation change is an obvious signal that something is missing. The absence of a doc update is itself reviewable.
- **Historical accuracy:** because documentation is versioned in git, the documentation state at any past commit matches the code state at that commit. Bisecting for regressions can include documentation context.

Practical constraints of this workflow:

- Only works for documentation that lives in the repository. Wiki pages, Notion, Confluence, and Google Docs are not diffs.
- Requires that reviewers are expected to review docs, not just code. If reviews skip the `.md` files, the workflow produces no benefit.
- Requires writers to put documentation in the repository, which is itself a practice change for teams used to external wikis.

The migration path for teams on external wikis: start with README and runbooks in the repo, establish the workflow habit there, then migrate higher-traffic docs over time.

> [!tip] If a PR contains only documentation changes, it still gets a reviewer. Documentation-only PRs that merge without review are a sign that the team doesn't take documentation as seriously as code.

@feynman

Like a schema migration paired with the application code change that requires it — you review them together because they have to be correct together.

@card
id: cpe-ch03-c012
order: 12
title: Migration Guides and Upgrade Notes
teaser: Migration guides are the documentation everyone delays writing and everyone needs urgently — the explicit instructions for moving from the old version to the new one, written by the person who made the change before they forget what they changed.

@explanation

Migration guides serve a different audience from design docs or READMEs: they're written for engineers who have working systems that depended on the old behavior, and who need to understand exactly what changed and what they have to do about it.

What a migration guide contains:

- **What changed:** the specific behaviors, interfaces, or data formats that are different in the new version. Be precise. "The authentication flow was updated" is useless. "The `/auth/token` endpoint now returns a `refresh_token` field and requires a `client_id` header" is useful.
- **Why it changed:** one sentence on the motivation. Engineers are more likely to invest in migration work when they understand the reason.
- **What breaks without action:** describe the failure mode explicitly. "Without migration, requests to `/auth/token` will return a 400 error starting in version 3.0."
- **Step-by-step migration instructions:** exact code changes, configuration changes, or data transformations required. With before/after examples where relevant.
- **Timeline:** when the old behavior is removed, if applicable. What's deprecated, what's removed, what will be removed in a future version.
- **Rollback instructions:** how to revert if the migration causes problems.

Why teams avoid writing these:
- The engineer who made the breaking change is already moving to the next feature.
- It requires thinking from the consumer's perspective, which requires knowing who your consumers are and what they depend on.
- Writing a complete guide surfaces how disruptive the change is, which can be uncomfortable.

The cost of not writing one: every downstream team either guesses, asks the author directly, or discovers the breaking change in production. The total time spent across all those teams exceeds the time the migration guide would have taken to write.

> [!warning] If a change requires migration and ships without a migration guide, the author has shifted the documentation burden to every consumer of the system. This is the documentation equivalent of a memory leak.

@feynman

Like a breaking change in a public API — the changelog entry is not optional; it's the contract that lets the ecosystem absorb the change without each team reinventing the diagnosis.
