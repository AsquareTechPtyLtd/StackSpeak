@chapter
id: rfc-ch09-big-refactorings
order: 9
title: Big Refactorings
summary: Some refactorings are too big for a single sitting — campaigns that take weeks or months, run alongside live development, and reshape the spine of a codebase rather than a single method.

@card
id: rfc-ch09-c001
order: 1
title: Big Refactorings Are a Different Category
teaser: When a refactoring cannot fit in a PR, cannot be paused safely overnight, and cannot be reviewed in a single sitting, you have left the territory of technique and entered the territory of campaign management.

@explanation

The refactorings in chapters 3 through 8 share one property: you can finish any of them before lunch. Extract a method, move a class, replace a conditional with polymorphism — each has a clear start, a clear end, and a test suite that tells you when you are done.

Big refactorings do not work this way. They share a different set of properties:

- **Duration.** Weeks or months, not hours. The codebase continues receiving feature commits while the refactoring is in flight.
- **Scope.** They reshape structural decisions — an inheritance hierarchy, the split between business logic and UI, the module boundaries of an entire subsystem.
- **Reversibility.** You cannot simply revert. Halfway through a big refactoring, the codebase may be in a state that is neither the old design nor the new one — and that in-between state can be the worst of both worlds if you stop.
- **Coordination overhead.** Other engineers are landing code in the same files. You must communicate constantly or risk merging against a moving target.

The failure mode that kills most big refactorings is treating them as large versions of small refactorings — pushing everything into a long-lived branch, reviewing it in one shot, and merging. That approach inverts the risk profile. Small refactorings are safe because they are short-lived; scaling them up by making them long-lived erases the safety property entirely.

What works instead is the campaign mindset: a sequence of individually safe, individually reviewable steps, each one landing in the main branch, none of them leaving the codebase in a broken state.

> [!warning] A big refactoring that lives entirely on a feature branch for three weeks is not a refactoring — it is a merge event waiting to conflict with everything that happened in the meantime.

@feynman

Renovating a house while you live in it is nothing like renovating an empty one — every decision about what to tear down depends on what the occupants still need working tonight.

@card
id: rfc-ch09-c002
order: 2
title: Tease Apart Inheritance
teaser: When a single inheritance hierarchy is doing two unrelated jobs simultaneously, every new requirement doubles the subclass count — the fix is to separate the two concerns into independent hierarchies connected by delegation.

@explanation

The smell: you have an inheritance tree where subclass names encode two orthogonal dimensions — something like `ReportPrinterHTMLFormat`, `ReportPrinterPDFFormat`, `SummaryPrinterHTMLFormat`, `SummaryPrinterPDFFormat`. Adding a new report type requires two new subclasses. Adding a new format requires two more. The tree scales as the product of the two dimensions.

```text
Before:
         Printer
           |
    ┌──────┴──────┐
ReportHTML   ReportPDF   SummaryHTML   SummaryPDF

After:
    Printer ──delegates to──> Format
       |                         |
  Report  Summary           HTML   PDF
```

The campaign:

1. Identify which dimension is doing more work and which is incidental. The incidental dimension becomes the extracted hierarchy.
2. Add a field on the primary hierarchy that holds an instance of the new hierarchy.
3. For each method that belongs to the incidental dimension, move it to the new hierarchy and delegate.
4. Once all methods are delegated, the mixed subclasses are no longer pulling double duty — collapse them.

The danger: the two dimensions are often not as cleanly separable as they look. Business logic leaks between them. You discover the separation mid-campaign and have to revise your plan. Start with the clearest cases; do not attempt to separate everything at once.

> [!tip] If you cannot name the two dimensions without hesitation, pause. An unclear split produces a new hierarchy that is just as confused as the original one.

@feynman

Teasing apart an inheritance hierarchy is like separating two employees who have been sharing one job description — useful while the company was small, but increasingly expensive as each new responsibility now belongs to both of them.

@card
id: rfc-ch09-c003
order: 3
title: Convert Procedural Design to Objects
teaser: Turning a procedural codebase into an object-oriented one is the largest classical refactoring — it requires identifying the data clusters that want to become objects and migrating behavior toward them incrementally.

@explanation

This is the refactoring that Fowler describes as taking the longest. It is the appropriate response to a codebase organized around large procedure files — functions that manipulate global or passed-in data records, with no natural home for behavior.

The campaign follows a recognizable arc:

1. **Find the data clusters.** Look for groups of variables that always travel together — passed as a parameter cluster, stored in parallel arrays, or repeated in every function signature. These are the objects trying to emerge.
2. **Create value objects first.** Introduce record types that hold the data without behavior. This alone reduces cognitive load and prevents the cluster from drifting apart.
3. **Move behavior toward the data.** For each function that operates primarily on one of the new types, move it into that type as a method. Start with functions that access no other data cluster.
4. **Repeat until the top-level procedures are thin coordinators.** The goal is not to eliminate all procedures — it is to ensure that behavior lives with the data it operates on.

The failure mode is moving behavior too aggressively before the data model is stable. If you move twenty methods into a class and then discover the class needs to split, you are now doing two campaigns at once. Stabilize the data model before migrating behavior.

> [!warning] A procedural-to-OO conversion attempted in one large branch almost always produces a merge conflict that is structurally unresolvable — every file changed, against a base that has also changed.

@feynman

Converting a procedural codebase to objects is like reorganizing a warehouse from "everything on one enormous shelf sorted by arrival date" to "aisles organized by product category" — you cannot move everything at once without closing the warehouse.

@card
id: rfc-ch09-c004
order: 4
title: Separate Domain from Presentation
teaser: Business logic embedded in view controllers and UI handlers is one of the most common structural problems in long-lived codebases — extracting it is incremental, high-value, and rarely finished in one campaign.

@explanation

The smell is business logic that can only be tested by instantiating a UI component. Validation rules live in form handlers. Pricing calculations happen in template renderers. Tax logic is threaded through controller methods that also set HTTP headers.

The campaign:

1. **Identify a single rule.** Pick one piece of business logic that has no legitimate reason to know about the presentation layer — a validation, a calculation, a state transition.
2. **Extract it to a domain object.** A plain class or struct with no UI imports. Test it directly.
3. **Replace the in-place logic with a call to the domain object.** The UI layer now delegates. Its tests, if any, become thinner.
4. **Repeat.** The domain model grows one extracted concept at a time.

The coordination challenge: feature work keeps landing in the controllers you are extracting from. The safest pattern is to extract only from files where no feature work is currently active, or to coordinate explicitly so that feature authors know to target the new domain objects rather than the controllers.

What you gain: domain logic that is independently testable, reusable across presentation contexts (web and API, or SwiftUI and widgets), and readable without understanding the rendering pipeline.

> [!info] A domain object that imports a UI framework is not a domain object. Keep the dependency arrow pointing one way: presentation depends on domain, never the reverse.

@feynman

Separating domain from presentation is like pulling the recipe out of the line cook's head and writing it down in a format the pastry chef can also use — the cooking method stays the same, but the knowledge is no longer trapped in one context.

@card
id: rfc-ch09-c005
order: 5
title: Extract Hierarchy
teaser: When a class grows a collection of boolean flags that select between incompatible behaviors, replace the flags with a small inheritance tree — one subclass per behavior variant.

@explanation

The smell: a class with fields like `isSpecialCase`, `isPremiumTier`, `isLegacyMode`, where each flag gates a different branch in nearly every method. Adding a new variant means adding a new flag and auditing every method for where the new branch belongs.

```text
Before:
  Order
    - isRush: Bool
    - isInternational: Bool
    - isDigital: Bool
    - calculateShipping() { if isRush ... if isInternational ... }

After:
        Order
          |
  ┌───────┼──────────┐
Rush  International  Digital
```

The campaign:

1. Pick the flag that controls the most behavior — the one you would ask "what kind of order is this?" about.
2. Create a subclass for each value of that flag and move the flag-specific branches into overrides.
3. Replace construction sites with factory methods or a factory function that returns the appropriate subclass.
4. Remove the flag from the parent class. The conditional is gone — the type system now carries the distinction.
5. Repeat for the next flag, which may now be a flag on a subclass rather than the parent.

The failure mode is creating a subclass hierarchy that is immediately too deep. Prefer flat over nested. If two flags are truly orthogonal, the result might be better modeled with a Strategy or a composition rather than inheritance — revisit the Tease Apart Inheritance technique.

> [!tip] If you find yourself writing `if type(of: self) == SubclassX` anywhere in the parent, you have not finished the extraction.

@feynman

Extracting a hierarchy from a flag-ridden class is like replacing a single multi-purpose room in a house with a proper kitchen, bathroom, and bedroom — the flags were the "I'll figure out what this room is later" decision, and you are finally figuring it out.

@card
id: rfc-ch09-c006
order: 6
title: The Campaign Mindset
teaser: The discipline that makes big refactorings survivable is simple but uncommon — you work in strictly ordered steps, you never hold two half-done refactorings simultaneously, and you ship something to main every day.

@explanation

The principles:

**One refactoring in flight at a time.** If you are mid-way through separating a domain layer and you notice an inheritance problem, you write it down and finish what you started. Splitting attention between two structural campaigns produces a codebase that is broken in two directions at once.

**Every step must be independently safe.** Each commit, each PR, each day's work should leave the codebase in a runnable, testable state that is at least as clean as it was before you started. The step might not be the final state — but it must not be a worse state.

**Work small and ship often.** A big refactoring that only ever lives on a branch accrues merge debt. Every day the branch ages, the conflict surface grows. Ship the preparatory moves — the renamed variables, the extracted interfaces, the added indirection — before you ship the structural change that depends on them.

**Document the campaign intent.** A short note (a team wiki page, a pinned issue) explaining what you are doing and why lets feature authors avoid landing changes that work against you. It also gives you a forcing function: if you cannot explain the campaign in two sentences, the scope is unclear.

The failure mode that ends campaigns is stopping in the middle of a preparatory move and letting it sit. A half-extracted interface, an unused abstraction layer, a duplicated code path that was supposed to be temporary — each one leaves the codebase worse than before you started.

> [!warning] "We'll finish the second half next sprint" is how big refactorings turn into permanent technical debt with extra steps.

@feynman

Managing a big refactoring campaign is like running a road construction project on a live highway — you close one lane at a time, complete the work, reopen it, then close the next one; you never close the whole highway and you never leave a lane closed overnight without a plan to reopen it.

@card
id: rfc-ch09-c007
order: 7
title: Mikado Method
teaser: The Mikado Method treats a dependency-heavy refactoring as a graph problem — you start by attempting the goal, note what breaks, record those dependencies, revert, and work the dependency tree from the leaves inward.

@explanation

Invented by Ola Ellnestam and Daniel Brolund, the Mikado Method is a technique for making progress on refactorings where a naive first attempt breaks fifteen other things.

The algorithm:

1. **Try the goal.** Make the change you want to make. Do not worry about what breaks.
2. **Record what breaks.** Each broken thing is a prerequisite — something that must be true before your goal change is safe. Write each one as a node in a dependency graph.
3. **Revert the goal change.** Return to a clean state. This is the discipline that makes the method work — you do not keep a broken half-finished change in your working tree.
4. **Pick a leaf.** Choose a prerequisite with no unresolved dependencies of its own. Attempt it. If it breaks things, recurse.
5. **Work toward the root.** Once a leaf is done and merged, the next node in the graph becomes addressable. Each merged step shrinks the graph.

The method produces a prioritized, dependency-ordered work queue from first principles. It works especially well when you cannot tell how deep the refactoring goes until you start.

The failure mode: not reverting when step 3 requires it. Keeping broken intermediate states in the working tree defeats the safety property. The revert discipline feels costly but is what makes each step reviewable.

> [!info] The Mikado graph does not need to be formal. A whiteboard diagram, a nested list in a text file, or a GitHub issue with a checklist all work — the value is in externalizing the dependency structure, not in the tool.

@feynman

The Mikado Method is like pulling the right stick from a game of Mikado — you probe the pile, identify which sticks are blocking the one you want, remove those first, and only then pick up your target.

@card
id: rfc-ch09-c008
order: 8
title: Branch by Abstraction
teaser: Branch by Abstraction lets you replace a deeply-used component incrementally — you introduce an abstraction layer, route clients through it, build the new implementation behind it, then flip the switch.

@explanation

Branch by Abstraction (BbA) is a technique for replacing a component that has many callers without a long-lived version-control branch. The branching is in the code, not in git.

The four phases:

1. **Create an abstraction.** Introduce an interface or abstract class that wraps the current component. Route all existing callers through it. The abstraction initially just delegates to the old implementation.
2. **Build the new implementation.** With callers isolated behind the abstraction, you can build the replacement without disrupting anyone. Ship it to main in a non-default, non-routed state.
3. **Migrate callers.** Redirect callers from the old implementation to the new one, gradually and verifiably. You can migrate by module, by feature, or by traffic percentage.
4. **Remove the old implementation.** Once all callers are on the new path and the abstraction is no longer switching, delete the old code and simplify or remove the abstraction layer itself.

BbA is covered in more depth in chapter 12 alongside the Strangler Fig pattern, which applies the same philosophy at service boundaries rather than class boundaries.

The failure mode is leaving the abstraction in place after the migration is complete. An abstraction that serves no routing purpose is accidental complexity — a seam that future engineers will assume exists for a reason.

> [!tip] Keep the abstraction layer thin. Its job is routing, not orchestration. If business logic accumulates in the abstraction, you have created a new problem to fix.

@feynman

Branch by Abstraction is like installing a new water main while the city is still running — you lay the new pipe alongside the old one, connect buildings one block at a time, and only cap the old main after every building has water from the new one.

@card
id: rfc-ch09-c009
order: 9
title: Tracking Progress During a Long Campaign
teaser: A big refactoring with no visible progress signal loses momentum and loses stakeholder confidence — lightweight tracking is not overhead, it is how the campaign stays alive.

@explanation

The problem with multi-week refactorings is that progress is invisible until late. Feature work produces deployed functionality that stakeholders can see. Structural refactoring produces cleaner code that stakeholders cannot see — which means the campaign is easy to deprioritize, defer, or declare done prematurely.

Tracking approaches that work at the team level:

- **A tagged TODO list.** A consistent comment marker (`// TODO(rfc-domainextract)`) applied to every site that still needs to be migrated. Count them weekly. A declining number is progress. A flat number is a warning that work has stalled.
- **A checklist issue.** A GitHub or Jira issue with one checkbox per module, per class, or per call site. Closing checkboxes is low-friction and visible to the team.
- **A code quality metric.** Tools like CodeClimate, SonarQube, or a custom script can track the specific smell you are eliminating — coupling between modules, test coverage of a newly-extracted domain layer, or duplication in a subsystem. Trending metrics give you objective evidence of progress and a stopping criterion.

What you are not trying to do: produce a Gantt chart, estimate to the day, or report the refactoring as a percentage complete. Structural campaigns do not decompose that way. What you are trying to do is make the progress visible enough that no one declares the campaign dead because they forgot it was happening.

> [!info] A refactoring with no tracking artifact is easy to cancel. A refactoring with a checklist issue that is 60% checked off is much harder to cancel — the sunk cost is visible and the remaining work is bounded.

@feynman

Tracking a refactoring campaign is like publishing a before-and-after renovation timeline with weekly photos — not because the photos speed anything up, but because visible progress is what keeps the project funded through the messy middle.

@card
id: rfc-ch09-c010
order: 10
title: The "Stop Early" Question
teaser: Not every big refactoring should be finished — recognizing when a campaign should be paused or abandoned requires asking whether the remaining steps still justify the disruption.

@explanation

A big refactoring can fail without producing broken code. It can fail by becoming irrelevant, by costing more than it saves, or by leaving the codebase in a permanent half-state that is harder to work with than either the original design or the target design.

The conditions under which stopping early is the right call:

- **The business context has changed.** The subsystem you are refactoring is being replaced by a third-party service next quarter. Continuing the campaign produces clean code that will be deleted.
- **The cost-benefit has inverted.** Early steps produced clear wins. Later steps require touching more and more stable, well-tested code to achieve diminishing structural gains. The marginal value of each remaining step is less than the disruption it introduces.
- **The design insight has changed.** Mid-campaign, you discover that the target architecture has a fundamental problem you did not see from the start. Finishing would produce a wrong design. The right move is to stop, document what you learned, and plan a different approach.

Stopping early requires intentional cleanup: reverse any temporary abstractions that were introduced as preparation, close out the tracking issue with a clear statement of why the campaign ended, and document the surviving partial improvements so future engineers know what was intentional.

A partial improvement left silently is a permanent source of confusion. A partial improvement with a clear explanation is a documented decision.

> [!warning] Stopping a campaign without cleaning up the scaffolding — the temporary abstractions, the routing flags, the transitional interfaces — leaves the codebase worse than when you started.

@feynman

Knowing when to stop a renovation early is like knowing when to stop digging when you hit unexpected geology — continuing is not courageous, it is expensive, and sometimes the right move is to backfill the trench and redesign the foundation.

@card
id: rfc-ch09-c011
order: 11
title: The "Rewrite from Scratch" Temptation
teaser: When a codebase is painful enough to prompt a big refactoring campaign, the team will almost always also consider throwing it away and starting over — and that temptation is usually wrong.

@explanation

Joel Spolsky named this failure mode in his 2000 essay "Things You Should Never Do, Part I." His argument: when you rewrite from scratch, you throw away the accumulated knowledge encoded in the existing code — not just the readable parts, but the thousands of bug fixes, edge-case handlers, and hard-won integrations that appear to be accidental complexity but are actually load-bearing.

The rewrite looks attractive because the existing code is ugly. But ugliness and ignorance are not the same thing. An ugly legacy codebase usually knows things the rewrite team does not know yet — about the domain, about the customers, about the failure modes of the problem space.

The failure modes of rewrites:

- **The second-system effect.** The rewrite accumulates every feature request that was ever deferred from the original system, producing something larger and more complex than what it replaces.
- **The moving target.** The original system continues receiving business requirements during the rewrite. By launch, the rewrite is already behind.
- **The never-done rewrite.** The complexity of the original reveals itself incrementally in the new code. The rewrite expands to match the original's scope and then keeps expanding. Netscape 6. The Borland Delphi rewrite. The list is long.

Incremental refactoring — the campaign approach — is slower and more frustrating than a greenfield rewrite. It is also survivable. The existing system runs, earns revenue, and serves users throughout. A rewrite requires betting the product on a future system that has not yet proven itself.

> [!warning] "The old code is unmaintainable" is almost always an argument for incremental refactoring, not for a rewrite. The new code will be unmaintainable in different ways within three years if the team that writes it does not change how it works.

@feynman

Choosing a rewrite over a refactoring campaign is like deciding to demolish your house and rebuild it because the kitchen layout is inconvenient — possible, occasionally right, but rarely the most sensible response to a local problem.

@card
id: rfc-ch09-c012
order: 12
title: The Economics of Big Refactorings
teaser: A big refactoring that cannot be justified in terms of delivery speed, defect rate, or developer throughput will not survive the first sprint planning meeting where it competes with feature work.

@explanation

Big refactorings require ongoing investment from the team and ongoing tolerance from whoever prioritizes the backlog. That tolerance is not infinite. To sustain a campaign, you need to be able to explain and demonstrate its value in terms the organization understands.

The before/after metrics that are credible:

- **Cycle time for changes in the affected area.** If adding a new payment method took two weeks before the domain extraction and takes two days after, that is the argument.
- **Defect rate in the affected area.** A cohesive domain layer with test coverage produces fewer regressions than business logic distributed across controllers.
- **Developer ramp-up time.** How long does a new engineer take to make their first safe change in the refactored subsystem? If it drops from days to hours, that is measurable.
- **Test coverage as a proxy.** A well-structured codebase is testable. An increase in test coverage of the affected area is often a side effect of a successful structural campaign — and it is a metric teams already track.

How to know the campaign paid off: pick one metric before you start, measure it, and measure it again after the campaign closes. A refactoring that does not improve at least one measurable outcome was likely scope for scope's sake.

The risk is over-engineering the measurement. Elaborate dashboards and multi-quarter OKRs for a code cleanup project signal that the project has lost proportion. One metric, measured twice, is enough for most campaigns.

> [!tip] The strongest economic argument for a big refactoring is a concrete example: "last month we spent four days debugging a pricing bug because tax logic is in three different controllers — after this campaign, that logic will be in one tested class."

@feynman

Justifying a big refactoring is like justifying a road resurfacing project — the road is not broken, traffic is moving, but every pothole costs more in vehicle repairs and slowdowns than the resurfacing would cost, and the cumulative case eventually becomes undeniable.
