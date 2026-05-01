@chapter
id: sa-ch02-modularity
order: 2
title: Modularity
summary: Coupling, cohesion, and the small set of metrics that turn "well-organised code" from a vibe into a measurable property.

@card
id: sa-ch02-c001
order: 1
title: Modularity Is the Architect's Microscope
teaser: At the system level, modularity decides whether you can change one thing without breaking ten. Most architectural pain shows up first as a modularity problem.

@explanation

Modularity is the property that lets a system be reasoned about in pieces. A well-modularised system has clear boundaries, predictable dependencies, and changes that stay local. A poorly modularised one has surprises everywhere — touch the auth code, three unrelated tests fail.

The architect's job is to keep the system modular under continuous pressure. Every feature wants to reach across boundaries. Every shortcut wants to skip an abstraction. Every junior dev wants to add "just one more import." Without active resistance, modularity decays to zero.

The vocabulary worth knowing:

- **Coupling** — how dependent one piece is on another.
- **Cohesion** — how related the things inside one piece are.
- **Connascence** — the specific *kind* of dependency, on a spectrum from "name match" to "shared mutable state."

This chapter is about all three, and about the fitness functions that turn modularity from intuition into something you can defend in code review.

> [!info] "Modular" is not a binary. It's a continuous property that can be measured, drift in either direction, and be enforced with automation. The systems that stay modular for years are the ones whose teams measured it.

@feynman

A house with rooms versus a studio apartment with everything piled in one space. Both can hold the same stuff; one is much easier to clean. Modularity is the rooms.

@card
id: sa-ch02-c002
order: 2
title: Cohesion — Things Inside Belong Together
teaser: A module with high cohesion is about one thing. A module with low cohesion is a pile of unrelated functions that happened to land in the same file. The first survives change; the second doesn't.

@explanation

Cohesion measures how related the elements inside a module are. High cohesion means the module is about one concept; low cohesion means it's a junk drawer.

The classic gradation (from worst to best):

- **Coincidental** — things share a file because they happened to be added together. "utils.py."
- **Logical** — things share a category but not a purpose. "All HTTP handlers in one file."
- **Temporal** — things run at the same time but aren't otherwise related. "All startup code."
- **Procedural** — things share a sequence of steps.
- **Communicational** — things operate on the same data.
- **Sequential** — output of one is input to the next.
- **Functional** — things contribute to one well-defined task. The target.

High cohesion lets you change behaviour by changing one place. Low cohesion forces you to grep for "everywhere this concept might touch" — a sign that the concept doesn't have a home.

> [!tip] When you can't name a module without using "and" or "stuff", cohesion is too low. Split it until each module's name is a single concept.

@feynman

Same lesson as the kitchen drawer organisation. Spoons in the spoon drawer; whisks in the whisk drawer; a "miscellaneous kitchen things" drawer is where you stop being able to find anything.

@card
id: sa-ch02-c003
order: 3
title: Coupling — How Connected Two Modules Are
teaser: Coupling is the dependency between modules. Some coupling is unavoidable; the question is whether it's the right kind, in the right places.

@explanation

Coupling is what makes a change in one module force a change in another. Zero-coupled modules are independent (and rare). Tightly-coupled modules can't be changed without coordinating across teams, which is where most architecture pain comes from.

Forms of coupling, from looser to tighter:

- **Stamp** — the modules share a data structure but most fields are unused.
- **Data** — the modules share only the specific data they each need.
- **Control** — one module passes a flag that controls the other's behaviour.
- **External** — both modules depend on the same external thing (file format, protocol).
- **Common** — both modules read/write a shared global (like a database table).
- **Content** — one module reaches into another's internals. The worst kind.

The interesting tradeoff: looser coupling is more flexible but more abstract. Data coupling through a thin interface is loose; data coupling through a fat shared schema is tight. Both are "data coupling" — the difference is how much they couple.

> [!warning] Code can be loosely coupled at the call site and tightly coupled at the deployment level. Two services with a clean API contract are still tightly coupled if they share a database underneath.

@feynman

Velcro versus glue. Both attach things; one comes apart cleanly when needed, the other rips paint off the wall. Picking the right kind of attachment is what coupling is about.

@card
id: sa-ch02-c004
order: 4
title: Connascence — A Sharper Coupling Vocabulary
teaser: Connascence names the *specific kind* of coupling between two pieces of code. The name lets you talk about which couplings to fight and which to live with.

@explanation

Connascence (Meilir Page-Jones, 1992) gives names to the ways two parts of a system can depend on each other. The benefit isn't theoretical — it's that naming each kind makes the conversation about which to keep and which to remove much sharper.

Static connascence (visible in source code):

- **Name (CoN)** — both ends agree on the same identifier. Cheapest; near-impossible to avoid.
- **Type (CoT)** — both ends agree on the same type. Trivially enforceable in typed languages.
- **Meaning (CoM)** — both ends agree on the meaning of a literal value. Hard. "0 means success" is connascence of meaning.
- **Position (CoP)** — both ends agree on argument order. Brittle.
- **Algorithm (CoA)** — both ends rely on running the same algorithm. Symmetric encryption keys, hash functions.

Dynamic connascence (only visible at runtime):

- **Execution (CoE)** — order of execution matters.
- **Timing (CoTm)** — timing of execution matters.
- **Value (CoV)** — values must agree at runtime (database constraints across services).
- **Identity (CoI)** — instances must reference the same object.

The general rule: prefer static over dynamic; prefer weaker over stronger; reduce locality (the further apart the connascent points are, the worse the coupling).

> [!tip] Most "we keep getting bugs in this area" patterns are connascence-of-meaning problems. Replace magic values with named constants and the bug class disappears.

@feynman

The legal term for the specific way two things are joined. "Coupled" is the lawyer's "they're related"; connascence is the specific contract. The named version is what lets you change just the offending clause.

@card
id: sa-ch02-c005
order: 5
title: Afferent and Efferent
teaser: Afferent coupling is who depends on you; efferent is who you depend on. The ratio matters more than either number alone.

@explanation

Two metrics for module-level coupling:

- **Afferent (Ca)** — number of modules that depend on this one. High afferent means many things will break if you change me.
- **Efferent (Ce)** — number of modules this one depends on. High efferent means many things will break me.

A module with high Ca and low Ce is foundational — many depend on it, it depends on little. Often a good design (utility libraries, core types).

A module with low Ca and high Ce is a leaf — it consumes others but isn't depended on. Often a UI or orchestration layer.

A module with high Ca *and* high Ce is a problem. It's tightly coupled in both directions, hard to change, hard to remove, central to too many flows. These are the "you can't touch this without an outage" modules every legacy codebase has.

The instability metric (Ce / (Ca + Ce)) ranges from 0 (fully stable, all incoming) to 1 (fully unstable, all outgoing). Healthy systems have a mix; unhealthy ones cluster in the middle.

> [!info] Tools like JDepend, Madge, depcheck, dependency-cruiser, and just `grep -l import` produce these metrics for any codebase. Most teams don't measure; the ones that do learn surprising things on day one.

@feynman

Same instinct as social-graph centrality. The person everyone depends on for keys to the building has high afferent coupling; the person who needs everyone else's approval has high efferent. Both are normal; the person with both is the bottleneck.

@card
id: sa-ch02-c006
order: 6
title: The Stable Dependencies Principle
teaser: Things should depend in the direction of stability — modules that change rarely get depended on by modules that change often, not the reverse.

@explanation

Stability here is measured by "how often does this module change?" not "how reliable is it." A heavily-modified module is unstable; a foundational utility is stable.

The principle: dependencies flow from unstable to stable. Concrete things depend on abstract things. UI depends on domain logic. Orchestration depends on utilities. Never the other way around.

Why this matters:

- **Change locality** — when a stable module's caller changes, only the caller is affected. When a stable module changes, every caller is affected. Make the latter rare.
- **Test isolation** — stable modules have stable tests. Unstable modules churn through tests.
- **Onboarding** — new engineers can build mental models bottom-up if stability is consistent. They can't if unstable code reaches downward.

Symptoms of violation:

- A "core" module changes weekly and breaks every consumer.
- The team has a "no changes to module X without notice" rule.
- New features land by patching the most-depended-on file.

> [!warning] Frameworks violate this all the time. The framework changes; everyone using it has to update. The fix is to wrap the framework in a stable adapter — your code depends on the adapter, not the framework directly.

@feynman

Same instinct as building on bedrock instead of sand. The foundation should change less often than what's on top of it. When the foundation moves, everything moves with it.

@card
id: sa-ch02-c007
order: 7
title: The Stable Abstractions Principle
teaser: Stable modules should be abstract; unstable ones should be concrete. The most-depended-on code is interfaces, not implementations.

@explanation

Building on the stability principle: things that change rarely should also be abstract — interfaces, protocols, contracts — not concrete implementations.

Why? Concrete code carries detail. Detail is what changes. If the detail is in a stable, foundational module, you've placed change-prone code in the place where change is most expensive. The fix is to make stable modules carry only the contract; let concrete implementations live in unstable modules that change freely.

The principle in action:

- **Database access** — `UserRepository` interface stable; `PostgresUserRepository` implementation can change.
- **Notification** — `Notifier` interface stable; `SlackNotifier`, `EmailNotifier` implementations swappable.
- **Config** — `AppConfig` interface stable; the loader (env vars, file, secrets manager) is implementation detail.

What you get:

- Implementations can be replaced without touching consumers.
- Tests use a fake implementation; production uses the real one.
- New environments (dev, staging, mobile, edge) get new implementations without changing the contract.

> [!tip] The phrase "depend on abstractions, not concretions" is the Dependency Inversion Principle (D in SOLID). The stable-abstractions framing is the same idea, scaled to the architecture level.

@feynman

The same lesson as the difference between a USB port and a specific USB device. The port stays; the device changes. You don't rewire the wall every time you buy a new mouse.

@card
id: sa-ch02-c008
order: 8
title: Fitness Functions for Modularity
teaser: Modularity decays without active resistance. Fitness functions are the automated tests that catch the decay before it becomes architectural debt.

@explanation

Code review catches some modularity violations; the rest slip through because reviewers are busy and rules drift over time. Fitness functions automate the catching.

A fitness function is just a test that asserts an architectural property. Examples:

```python
# No service depends on more than 3 others.
def test_efferent_coupling():
    for service in services():
        assert efferent(service) <= 3, f"{service} depends on too many"

# UI never imports the database module directly.
def test_ui_not_coupled_to_db():
    for module in ui_modules():
        assert "db" not in imports_of(module)

# No cycles in module dependency graph.
def test_no_cycles():
    assert not has_cycles(module_dependency_graph())
```

These run in CI like any other test. When someone violates a rule, the build fails with a clear message. When the rule needs to change, you change the test (and document why in the commit message).

Tools that compute these:

- **ArchUnit** (JVM) — the canonical example.
- **NetArchTest** (.NET) — the equivalent.
- **dependency-cruiser** (JS/TS) — module dependency rules.
- **import-linter** (Python) — package-level boundary enforcement.

> [!info] Three to five well-chosen fitness functions catch more drift than fifty meeting-debated rules. Fewer, automated, in CI beats many, manual, hopeful.

@feynman

The same instinct as linting. The linter doesn't write the rules; it just enforces the ones the team already agreed on. Architecture fitness functions are linting one tier up.

@card
id: sa-ch02-c009
order: 9
title: Bounded Contexts
teaser: A bounded context is the slice of the system where one set of terms means one set of things. Cross the boundary and "customer" might mean something different. Naming the boundary is the architecture.

@explanation

Bounded context (Eric Evans, *Domain-Driven Design*) is the architectural unit that turns a sprawling domain into something tractable. Inside a context, vocabulary is consistent: "user" means one thing, "order" has one shape, "active" has one definition. Across contexts, the same word can mean different things — and you stop pretending otherwise.

Why this matters at the architecture level:

- **Module boundaries** — every bounded context naturally maps to a module, package, or service.
- **API design** — the API is the translation layer between contexts. Each context publishes its own model; consumers translate.
- **Data shape** — the shape of "customer" in the billing context isn't the same as in the support context, and trying to force one universal "customer" model produces tortured code.
- **Team alignment** — a team usually owns one or two contexts; multiple teams sharing a context is a coordination tax.

Identifying bounded contexts:

- Watch the language. When the same word means subtly different things to different teams, you've found a boundary.
- Watch the change patterns. When "we updated the order schema" breaks billing, support, and shipping all at once, the contexts are blurred.
- Watch the org chart. Strong team boundaries tend to map to context boundaries; the architecture should match.

> [!info] You can't introduce bounded contexts to a legacy system in a weekend. The conversation that names them is the start; the refactoring that enforces them takes quarters or years.

@feynman

Same instinct as international time zones. Everyone on Earth is using "the time," but it doesn't mean the same thing in Tokyo as in New York. The boundary between zones is the bit you have to design carefully.

@card
id: sa-ch02-c010
order: 10
title: When Modularity Breaks Down
teaser: Modularity erodes in predictable ways. Recognising the patterns lets you intervene before the team starts saying "we should rewrite this."

@explanation

The recurring patterns of modular decay:

- **The catch-all module** — utils, helpers, common, shared. Becomes the dumping ground for anything that doesn't fit. Cohesion drops to coincidental.
- **The god class** — one class grows to thousands of lines because every feature touches it. Coupling becomes universal.
- **The cross-cutting leak** — auth, logging, or metrics code embedded everywhere. Should be aspect-oriented or middleware; ends up scattered.
- **The convenience import** — module A imports module B "just for one thing"; over time, the dependency calcifies and gets richer.
- **The mocked-around-it test** — a test that needs five mocks to set up is a test telling you the module under test is too coupled.

What to do:

- **Audit periodically** — run module dependency analysis monthly; watch the trend.
- **Set fitness functions** — automate the rules nobody remembers.
- **Refactor on the way through** — when a feature touches a god class, slice off the new functionality into a new home. Don't rewrite; redirect.
- **Document the patterns you're trying to enforce** — "no module > 500 LOC", "no class > 200 LOC", "max 5 imports per file" — defaults that make decay obvious.

> [!warning] "We need to rewrite" is almost always wrong as a first answer. Modular decay is fixable incrementally; rewrites are how teams trade six months of decay for two years of total disruption.

@feynman

The same fight as keeping a codebase clean over years. The decay is a thousand small concessions; the fix is a thousand small refactors. There is no "modularity day" that fixes it all.
