@chapter
id: rfc-ch12-refactoring-at-scale
order: 12
title: Refactoring at Scale
summary: Codebases that span millions of lines, dozens of teams, and live traffic need refactoring patterns that don't require freezing development — and Branch by Abstraction, Parallel Change, the Strangler Fig, and feature-flag-driven rollouts are how those changes ship without an outage.

@card
id: rfc-ch12-c001
order: 1
title: Scale Changes the Rules
teaser: The refactoring moves that work cleanly in a 10,000-line codebase will stall, conflict, or cause outages when you apply them to a 10-million-line codebase with 50 teams committing every hour.

@explanation

At small scale, you rename a method, update all call sites, run the tests, and merge. The entire operation fits in a single PR and takes an afternoon. At large scale, that same rename touches 400 files across 30 repositories owned by teams who are mid-sprint and will not rebase on your work.

The problems that emerge at scale:

- **Long-lived feature branches become merge debt.** A refactoring branch that stays open for two weeks while you track down every call site is accumulating conflicts with every other commit to main. By the time you land it, you've spent more time on merge resolution than on the refactoring itself.
- **Coordinated deployments become coordination failures.** Changing an interface while also migrating every consumer assumes you can deploy everything atomically. Distributed systems don't offer atomic deploys across services.
- **Testing at scale requires isolation.** You can't run the full test suite of every downstream consumer before every refactoring commit. You need techniques that let you make the change incrementally without breaking consumers mid-migration.

The patterns that follow — Branch by Abstraction, Parallel Change, the Strangler Fig, and feature flags — all share one structural property: they make the refactoring incremental and independently deployable. No big-bang cutover. No code freeze. No "we'll merge when it's done." Each step is a mergeable, deployable unit on its own.

> [!warning] Long-lived refactoring branches are the leading cause of refactoring abandonment at scale. If a refactoring can't land in main incrementally, it will either die in review or land as a conflict bomb.

@feynman

Refactoring a large codebase is like rerouting a river through a city — you can't stop the water flowing while you dig; you have to build the new channel while the old one still runs, then cut over one section at a time.

@card
id: rfc-ch12-c002
order: 2
title: Branch by Abstraction
teaser: Paul Hammant's Branch by Abstraction introduces an indirection layer around the component you want to replace, so you can migrate incrementally behind the seam without a feature branch.

@explanation

The pattern, introduced by Paul Hammant, works in four steps:

1. **Create an abstraction** — introduce an interface or facade in front of the component you want to replace. All callers now go through the abstraction. The old implementation is the only thing behind it.
2. **Build the new implementation** behind the abstraction, alongside the old one. Both exist simultaneously; the abstraction controls which one is called.
3. **Migrate callers** by routing them to the new implementation, one callsite or one feature at a time. The abstraction layer is what makes this safe — you can verify each routed call before moving on.
4. **Remove the old implementation** once all callers are migrated. The abstraction may stay (it was worth the indirection) or be inlined away.

```text
                ┌──────────────────┐
callers ──────► │  Abstraction     │ ──── old impl (default)
                │  (interface/     │
                │   facade)        │ ──── new impl (behind flag)
                └──────────────────┘
```

What makes Branch by Abstraction different from a feature branch is that every step is a commit to main — not to a side branch. The abstraction is merged first. The new implementation is merged behind the abstraction while the old one stays live. There is no moment where the codebase is broken.

The failure mode: the abstraction becomes permanent load-bearing infrastructure that nobody dares remove. The "temporary" facade outlives both implementations by years. Treat the abstraction as scaffolding — schedule its removal as a work item the moment the migration completes.

> [!tip] The abstraction layer is not the goal — it's scaffolding. Add a TODO or a tracking ticket for its removal the day you create it.

@feynman

Branch by Abstraction is like installing a light switch before you rewire the house — the switch lets you flip between old wiring and new wiring while both are live, so you never leave the building without power.

@card
id: rfc-ch12-c003
order: 3
title: Parallel Change (Expand-Contract)
teaser: Martin Fowler's Parallel Change pattern breaks a breaking interface change into three non-breaking phases — expand, migrate, contract — so every individual commit is safe to deploy.

@explanation

Parallel Change, also called Expand-Contract, solves the problem of changing a method or API contract that has many consumers you can't update all at once.

**Phase 1 — Expand:** Add the new interface alongside the old one. The old method stays unchanged; the new method is added. No consumer is broken. Deploy this.

**Phase 2 — Migrate:** Update consumers to use the new method. You can do this across many PRs, many teams, and many deploy cycles. At any moment during this phase the system is fully functional — some consumers use the old method, some use the new one, all are valid.

**Phase 3 — Contract:** Once all consumers have migrated, delete the old method. This is now a safe deletion — nothing calls it.

A concrete example: changing a `createUser(name: String)` signature to `createUser(request: CreateUserRequest)`:

```text
Phase 1 (expand):   both createUser(name:) and createUser(request:) exist
Phase 2 (migrate):  callers move to createUser(request:) one by one
Phase 3 (contract): createUser(name:) deleted
```

This pattern is safe because it decomposes one breaking change into three non-breaking changes. The middle phase can span sprints or quarters if needed. The only rule is that you cannot skip to Phase 3 until Phase 2 is complete.

The failure mode: stalling at Phase 1. Expand lands, some callers migrate, and then the work loses momentum. The old and new methods coexist for 18 months. Use a deprecation annotation and a lint rule to enforce forward progress.

> [!info] Deprecation annotations (`@Deprecated`, `@deprecated`) are the mechanism for making Phase 2 visible. Without them, callers that haven't migrated are invisible and Phase 3 never arrives.

@feynman

Parallel Change is like adding a new entrance to a building before sealing the old one — once the new entrance is open and everyone has started using it, you close the old door; you never leave people locked out mid-transition.

@card
id: rfc-ch12-c004
order: 4
title: The Strangler Fig
teaser: Martin Fowler's Strangler Fig pattern rewrites a legacy system in place by routing traffic incrementally to a new implementation, never requiring a big-bang cutover.

@explanation

The name comes from the strangler fig tree, which grows around a host tree until the host is entirely replaced. Fowler applied the metaphor to legacy system rewrites.

The mechanical shape:

1. **Introduce a routing layer** in front of the legacy system. This is typically an HTTP proxy, a message router, or a facade service. It passes all traffic to the legacy system by default.
2. **Build the new implementation for a bounded piece of the system** — one API endpoint, one domain, one set of features.
3. **Route traffic for that piece to the new implementation** by updating the routing layer. Legacy handles everything else.
4. **Repeat** until the routing layer sends nothing to the legacy system.
5. **Decommission the legacy system.**

```text
client ──► [ routing layer ] ──► legacy (handles everything initially)
                │
                └──► new service (handles routed paths)
```

The key property: the legacy system is never "turned off." It shrinks progressively as the new system takes over its surface area. At any point you can roll back a segment to legacy by updating the routing layer.

The failure mode: the Strangler Fig becomes a permanent parallel system. The routing layer handles traffic for both systems indefinitely because neither migration completes nor decommissioning happens. This is usually a governance failure — the team that built the new system moves on, and the legacy core never gets fully strangled.

> [!warning] A Strangler Fig without a committed decommissioning date tends to become a permanent dual-system architecture. Set the decommissioning deadline before you build the routing layer.

@feynman

The Strangler Fig is like a road bypass — you build the new road while the old one still carries traffic, reroute one exit at a time, and eventually close the old road; you never shut down the entire route while the new one is under construction.

@card
id: rfc-ch12-c005
order: 5
title: Feature Flags as a Refactoring Tool
teaser: Feature flags decouple deployment from activation, giving you a kill switch for new code paths that lets you ship refactored code to production before you're ready to commit to it.

@explanation

A feature flag is a conditional in code that routes execution to one path or another based on a runtime-evaluated configuration value. In the context of refactoring, it enables a specific capability: you can deploy refactored code to production while it's still inactive, validate it in isolation, and roll back without a deployment if something goes wrong.

The operational pattern:

```swift
if flags.isEnabled("new-payment-processor") {
    return newPaymentProcessor.charge(amount)
} else {
    return legacyPaymentProcessor.charge(amount)
}
```

You deploy this with the flag off. The old path runs in production. You activate the flag for internal users first, then a percentage of production traffic, then everyone. If the new path fails, you flip the flag — no deploy, no rollback PR, no incident window.

Tools that operationalize this pattern: LaunchDarkly, Statsig, Unleash, and the vendor-neutral OpenFeature standard (as of 2026, OpenFeature has SDKs for Java, Go, .NET, JavaScript, and Python, making it a reasonable default for polyglot environments).

The failure mode is well-documented: flags become permanent. The branch guarded by `isEnabled("new-payment-processor")` becomes load-bearing code that nobody dares delete because the flag has been "on" for two years and nobody knows what the "off" path does anymore. Flags are scaffolding — they need expiry dates and cleanup policies from day one.

> [!warning] Every feature flag is technical debt with a slow timer. Assign an owner and an expiry date when you create the flag; schedule its removal the moment the migration is confirmed complete.

@feynman

A feature flag is like a circuit breaker on a newly wired section of a building — the wiring is live and tested, but you can trip the breaker instantly if anything looks wrong before you fully commit to it.

@card
id: rfc-ch12-c006
order: 6
title: Database Refactoring with Expand-Contract
teaser: Schema changes can't be deployed atomically across application and database, so Expand-Contract for databases decomposes a column rename or table split into phases that each leave the system fully operational.

@explanation

Renaming a column in a live database is not a two-step operation. If you rename `users.email_addr` to `users.email` in one deployment, every application instance that hasn't yet deployed the matching code will break.

The database Expand-Contract pattern decomposes this into safe phases:

**Phase 1 — Expand:** Add the new column. Write to both old and new columns. Read from the old column. The schema now has both; all application versions work.

**Phase 2 — Backfill:** Migrate existing data from the old column to the new column for all existing rows.

**Phase 3 — Migrate reads:** Update all application code to read from the new column. Both old and new columns are still written. Verify in production.

**Phase 4 — Stop writing the old column:** Remove the dual-write. Read and write only the new column.

**Phase 5 — Contract:** Drop the old column.

```sql
-- Phase 1: add new column, keep old
ALTER TABLE users ADD COLUMN email VARCHAR(255);

-- Phase 2: backfill
UPDATE users SET email = email_addr WHERE email IS NULL;

-- Phase 5 (after phases 3-4 complete): drop old
ALTER TABLE users DROP COLUMN email_addr;
```

Each phase is a separately deployable unit. The system is fully functional throughout.

The failure mode: stalling between Phase 3 and Phase 4, where dual-write persists indefinitely. Every write now has to maintain two columns. Add a tracking ticket and a deprecation warning in the ORM layer to force Phase 4 forward.

> [!info] Database Expand-Contract is the only safe strategy for zero-downtime schema changes in systems where the application and database can't deploy atomically. Every other approach — including blue-green — still requires this pattern for schema compatibility during transition.

@feynman

Renaming a live database column is like renaming a street while people are navigating to addresses on it — you put up both signs simultaneously, update the maps one by one, and only tear down the old sign after everyone is using the new name.

@card
id: rfc-ch12-c007
order: 7
title: API Versioning During Refactoring
teaser: When you change an API contract, maintaining both the old and new versions in parallel — with an explicit deprecation timeline — is what separates a managed migration from a breaking change.

@explanation

API versioning during refactoring is Expand-Contract applied at the service boundary. The old contract is version n; the refactored contract is version n+1. Both are live simultaneously, and consumers migrate on their own schedule.

The three decisions you have to make:

**How you express the version:** URL path (`/v1/users`, `/v2/users`), request header (`Accept: application/vnd.stackspeak.v2+json`), or query parameter (`?version=2`). URL path is the most visible and easiest to route; headers are cleaner but harder to test in browsers and logs.

**How long you maintain both:** Consumer migration timelines must be realistic. Internal APIs can have 4–8 week deprecation windows. Public or partner APIs commonly need 6–12 months. The deprecation window must be communicated before the new version launches, not after.

**How you enforce the deadline:** Logging, then warnings in response headers (`Deprecation: Sat, 01 Jan 2026 00:00:00 GMT`), then traffic monitoring, then hard cutover. Clients that ignore the deprecation header are the reason most migrations stall.

The failure mode: maintaining n, n+1, and n+2 simultaneously because n was never fully retired. Version accumulation turns a codebase into an archaeology project. Each active version is a branch of logic that must be maintained and tested. Enforce retirement: when n+1 ships and the migration window opens, set a hard calendar date for removing n.

> [!tip] Add a `Deprecation` and `Sunset` response header to every endpoint running on the old contract, from the moment the new version launches. Clients that monitor headers will notice; clients that don't will at least have an audit trail for the incident post-mortem.

@feynman

API versioning during refactoring is like running two bus routes on the same corridor — the old route keeps running while the new schedule rolls out, and you only retire the old route once the ridership data shows everyone has switched.

@card
id: rfc-ch12-c008
order: 8
title: Cross-Team Coordination
teaser: When a refactoring spans multiple teams, the bottleneck shifts from code to coordination — and platform teams that provide the migration path rather than doing the migration are how large organizations scale refactoring work.

@explanation

At single-team scale, you own the consumers of your interface and can migrate them yourself. At multi-team scale, you own the interface but not the consumers — 15 other teams have call sites in their codebases, and they have their own roadmaps.

The enabling team model (drawn from Team Topologies by Skelton and Pais) applies here: the team driving the refactoring doesn't do all the migration work. Instead, they create the migration path and make it easy for consuming teams to migrate themselves:

- Publish migration guides with before/after examples.
- Provide codemods (automated code transforms — see jscodeshift for JavaScript, or custom SwiftSyntax refactorings for Swift) that consuming teams can run locally.
- Set up a shared tracking dashboard showing which teams have migrated and which haven't.
- Create a deprecation annotation that surfaces in consuming teams' build output without requiring cross-team communication.

The escalation path when teams don't migrate: gradual enforcement. First, log calls to the deprecated interface. Then emit build warnings in consuming repos. Then break the build. Then remove the interface.

The failure mode: platform teams that do all the migration work themselves at scale. It's well-intentioned but doesn't scale past three or four consuming teams. It also removes the consuming team's ownership — they don't understand what changed and can't maintain the migrated code.

> [!info] Codemods are underused outside of JavaScript. For large-scale API migrations across many teams, an automated code transform that handles 80% of cases runs faster than any coordination process.

@feynman

Cross-team refactoring coordination is like a standards body issuing a new electrical code — the body sets the spec and the deadline, provides the guidance, and inspectors enforce it; they don't rewire every building themselves.

@card
id: rfc-ch12-c009
order: 9
title: Monorepo Refactoring
teaser: A monorepo's greatest refactoring advantage is atomic cross-package changes — one PR can update both the interface and every consumer simultaneously, which eliminates the coordination problem entirely for intra-repo changes.

@explanation

In a monorepo, a rename or interface change can touch all consumers in a single commit. The PR that renames `UserService.fetchUser` to `UserService.getUser` also updates every call site in every package in the same diff. No deprecation window, no parallel versions, no migration tracking dashboard — the change is atomic.

This is the primary refactoring advantage of the monorepo model. Tools like Bazel, Nx, and Turborepo make this practical at scale by providing:

- **Incremental builds.** Only packages affected by the change are rebuilt. A rename in a utility package doesn't rebuild the entire graph.
- **Affected change detection.** Nx and Turborepo can identify which packages are downstream of a change and run only their tests. This makes the test-before-merge loop tractable even in large graphs.
- **Dependency graph visibility.** Knowing which packages depend on which lets you reason about the blast radius of a refactoring before you make it.

What monorepos don't eliminate: large-scale structural refactorings still require the same patterns. Splitting a package in two, replacing a shared library with a different interface, or restructuring a domain boundary all require incremental strategies because a single PR that touches 300 files is still a review and merge risk even if it's technically atomic.

The failure mode: treating the monorepo's atomic change capability as permission to land arbitrarily large refactorings in single commits. Large commits are hard to review, hard to bisect if they introduce a regression, and psychologically resistant to thoroughness in code review.

> [!tip] Even in a monorepo with atomic cross-package changes, prefer a sequence of medium-sized PRs over a single enormous one. Atomic is about correctness; reviewability is about quality.

@feynman

A monorepo is like owning the entire building — if you want to rename the hallways, you can update all the door signs and all the maps in one morning; in a city of separate buildings, the same change requires a letter campaign.

@card
id: rfc-ch12-c010
order: 10
title: Polyrepo Refactoring
teaser: In a polyrepo, every cross-service refactoring is a coordination problem — and the cost of dependency synchronization means you either invest in tooling or you accept that shared interfaces change slowly.

@explanation

In a polyrepo, the service that owns an interface and the services that consume it are in separate repositories, deployed independently. Changing the interface requires coordinated PRs across repos with no atomic merge guarantee.

The options, in order of investment:

**Versioned libraries:** Package the shared interface as a library and publish a new version. Consumers upgrade on their own schedule. This is Expand-Contract at the package level — you maintain the old version while consumers migrate. Requires a package registry (npm, Maven Central, Swift Package Index, an internal Artifactory).

**Schema-first contracts:** For service boundaries defined by HTTP or gRPC, maintain the interface definition in a shared schema repository (OpenAPI, Protobuf). Consumer contract testing (Pact, Spring Cloud Contract) verifies that producers and consumers agree on the contract before either deploys. Changes to the schema are versioned and consumers can pin to a version.

**Coordinated PRs with tooling:** Scripts that open PRs in all downstream repos simultaneously, cross-linking them. GitHub's gh CLI and GitLab's API make this automatable. You still can't merge atomically, but you can sequence the merges: producer first, then consumers.

The failure mode: "email-driven refactoring," where the team driving the change notifies downstream teams and waits. Without tooling and enforcement, this produces indefinitely stalled migrations — the consuming team intended to update but the sprint filled up, and the deprecated interface is still live two years later.

> [!warning] Polyrepo refactoring without tooling defaults to the slowest consumer's pace. If you can't automate the migration or enforce a deprecation deadline through the build system, plan for the migration to take twice as long as your estimate.

@feynman

Refactoring across a polyrepo is like updating a shared recipe that dozens of restaurants have adapted — you can publish the new version, but each kitchen decides when to adopt it, and a few will still be running the old recipe long after everyone else switched.

@card
id: rfc-ch12-c011
order: 11
title: Long-Running Migration Governance
teaser: Migrations that span quarters lose momentum without explicit governance — a tracking dashboard, a "deprecate by date" policy, and a designated owner are what separate migrations that complete from migrations that become permanent technical debt.

@explanation

A refactoring that spans multiple sprints needs the same project management infrastructure as a feature. Without it, it stalls for predictable reasons: the team that started it gets pulled onto a higher-priority initiative, the consuming teams deprioritize it, and the "temporary" dual-state becomes permanent.

The governance mechanisms that work:

**Visibility:** A tracking dashboard that shows, per consuming team or per call site, what percentage of the migration is complete. Make it public within the organization so teams can see their status relative to others. Shame is a coordination mechanism.

**Deadlines with consequences:** "We will remove the old interface on [date]" is more effective than "we encourage teams to migrate." The consequence — a broken build — is what gives the deadline credibility. Set it far enough out to be fair; commit to it enough to be believed.

**Ownership continuity:** Assign a named owner for the migration at the start. When that person changes teams or roles, reassign explicitly. Ownerless migrations are the ones that stall.

**Checkpoint cadence:** A brief monthly review — who migrated last month, who's blocked and why, is the deadline still realistic — surfaces blockers before they become cancellations.

The failure mode: treating migration governance as bureaucratic overhead and skipping it. The refactoring starts with energy, stalls at 70% completion when the exciting work is done and only the difficult stragglers remain, and the old system runs indefinitely in "maintenance mode" that consumes incident capacity without being on anyone's roadmap.

> [!info] The 70% problem is common enough to plan for. Budget explicit time for the last 30% of a migration — the stragglers are usually the hardest cases, not the easiest.

@feynman

Running a long-term migration without governance is like renovating a building floor by floor — if you stop scheduling the next floor after you finish the fifth, the scaffolding stays up, the contractor moves on, and the building is half-renovated indefinitely.

@card
id: rfc-ch12-c012
order: 12
title: Designing for Reversibility
teaser: A refactoring you can't partially revert is a refactoring that requires perfect confidence before rollout — and at scale, that confidence is rarely available.

@explanation

The patterns covered in this chapter — Branch by Abstraction, Parallel Change, Strangler Fig, feature flags — share a design property beyond incrementalism: they make partial reversal possible. If the new code path exposes a bug after 10% rollout, you can route that 10% back to the old path without rolling back the entire deployment.

Designing for reversibility means:

- **Keeping the old code path live** until you're confident in the new one. The old payment processor stays in the codebase (behind the flag) until you've run the new one at 100% traffic for a meaningful period.
- **Separating data migration from code migration.** If the new code path writes to a new data store, that store should be writable independently of the old one during transition. A revert should not require manual data reconciliation.
- **Logging which path executed** per request. When a production incident occurs, you need to know within seconds whether the new code path is involved.
- **Making the revert a configuration change, not a code change.** Flag-based rollouts revert in seconds; revert-by-code-deployment takes minutes to hours.

Michael Feathers' concept of seams — points in the code where behavior can change without editing the code — is what makes reversibility mechanical rather than heroic. At service scale, service boundaries are seams: you can reroute traffic at the boundary without touching either service's internals.

The failure mode is the "we deleted the old code too soon" post-mortem. The new implementation looked stable at 100% traffic for two weeks, the old code was deleted, and then a rare but real edge case surfaced in week three. Keep old code longer than feels necessary. Storage is cheap; incidents are not.

This chapter has covered the structural techniques for large-scale refactoring. Chapter 13 explores how AI-assisted tooling — automated codemods, LLM-driven migration scripts, and static analysis at repository scale — is beginning to change the economics of the migration phase.

> [!tip] Delete old code paths only after you've run the new path at 100% traffic for at least as long as your slowest meaningful traffic cycle — weekly batch jobs, monthly billing runs, seasonal spikes. "It's been stable" is not the same as "it's been exercised."

@feynman

Designing a refactoring for reversibility is like installing a bypass valve in a water system — if the new pipe section has a leak, you shut the valve and traffic flows through the old route while you fix it, instead of draining the whole system.
