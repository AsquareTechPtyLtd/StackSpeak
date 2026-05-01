@chapter
id: sa-ch07-modular-monolith
order: 7
title: Modular Monolith
summary: One deploy, clean internal boundaries. Most of the benefits of microservices — team independence, change locality, clear ownership — without the network in the middle.

@card
id: sa-ch07-c001
order: 1
title: A Monolith That's Actually Modular
teaser: A modular monolith ships as one unit but is internally divided into bounded modules with clear contracts. The result: refactor freedom of a monolith, ownership clarity of microservices.

@explanation

A modular monolith looks like a monolith from the outside — one deployment, one codebase, one process. From the inside, it's organised into bounded modules: each owns a domain, exposes a defined interface, and treats its internals as private.

```text
src/
  modules/
    billing/
      api.py         # public interface
      service.py     # internal logic
      repository.py  # internal data
      models.py      # internal entities
    inventory/
      api.py
      service.py
      ...
    shipping/
      api.py
      ...
  shared/
    auth.py
    logging.py
```

The discipline:

- **Each module exposes a public API** (functions, types). Other modules talk to it only through that API.
- **Each module owns its data.** No other module reads its tables directly.
- **Cross-module calls go through the API**, even though they're in-process.

This produces a system that's a monolith for deployment purposes (one binary, one deploy) and a service-based system for development purposes (clear boundaries, owned domains).

> [!info] The modular monolith has been quietly winning converts for the last few years. Shopify, GitHub, Basecamp, and many others run massive systems this way. The renewed attention to it is a corrective to the microservices-everywhere narrative.

@feynman

Same as a well-designed apartment building under a single roof. One front door, one mailing address. Inside, each apartment is its own world with its own walls. Both shapes are useful; the modular monolith chooses both.

@card
id: sa-ch07-c002
order: 2
title: Why Modular Monolith Wins for Most Teams
teaser: You get team independence and change locality without the operational overhead of distributed systems. For most teams under ~50 engineers, this is the sweet spot.

@explanation

The benefits microservices promise — team independence, ownership, change locality — come from *modularity*, not from network boundaries. A modular monolith delivers most of those benefits at a fraction of the operational cost.

What you keep:

- **Team ownership** — each team owns one or more modules.
- **Change locality** — internal changes don't ripple across modules.
- **Clear interfaces** — the module's public API is the contract.
- **Independent reasoning** — modules can be understood in isolation.

What you skip:

- **Network failures between modules.** In-process calls don't fail.
- **Distributed transactions.** Local DB transactions span modules.
- **Multiple deployment pipelines.** One pipeline ships everything.
- **Distributed tracing for cross-module calls.** Stack traces just work.
- **Eventual consistency complexity.** ACID by default.

For a team under ~50 engineers, the operational savings are large and the architectural compromises are minor. Many teams that started with microservices have walked back to modular monoliths in 2024-26 — not because microservices are bad, but because the cost wasn't paying for itself.

> [!info] Shopify's Maintainable Monolith and GitHub's "Monolith First" pieces are the canonical references. They're both running monoliths handling thousands of engineers; you can too.

@feynman

The car most people should buy. Not the cheapest, not the fanciest, but the one that does what most people need without the maintenance burden of the exotic option. Modular monolith is the Toyota Camry of architectures.

@card
id: sa-ch07-c003
order: 3
title: Module Boundaries
teaser: A module is a bounded context expressed in code — a domain with its own data, its own logic, and a small contract for the rest of the system. Drawing the boundaries is the design.

@explanation

A useful module owns:

- **A domain concept** — billing, inventory, shipping, identity. Something a business stakeholder would name.
- **The data for that concept** — its tables, its database schema, its reference data.
- **The logic for that concept** — calculations, validations, state transitions.
- **A small public API** — the operations other modules can invoke.

What a module does *not* own:

- **Other modules' data** — never reach into another module's tables.
- **Cross-cutting infrastructure** — auth, logging, telemetry live in shared infrastructure, not in domain modules.
- **Other modules' logic** — duplication is sometimes preferable to a fat shared layer.

The size question is the same as for services: not too big, not too small. A module of 50K LOC is too coarse — it's just a layered monolith with extra steps. A module of 500 LOC is too fine — the API overhead exceeds the encapsulation benefit.

> [!tip] A useful test: can a single team own this module without surprises? If yes, the boundary is reasonable. If multiple teams have to coordinate every change, the boundary is wrong.

@feynman

The same instinct as drawing org chart boundaries. A team is too big when communication overhead dominates; too small when nobody owns enough to make decisions. Modules follow the same shape.

@card
id: sa-ch07-c004
order: 4
title: Enforcing the Boundaries
teaser: Without enforcement, modular monoliths drift back to traditional monoliths. Fitness functions check imports; code review catches the rest. Without both, the modules are vapor.

@explanation

The boundary between modular monolith and big-ball-of-mud is enforcement. Two layers:

**Static enforcement** (CI fitness functions):

```python
# Modules can only import from their own internals or from a module's public API.
def test_module_imports():
    for module in modules():
        for imp in imports_of(module):
            target_module = module_of(imp)
            if target_module is None or target_module == module:
                continue  # internal import
            # External import — must be the target module's public API
            assert is_public_api(imp), \
                f"{module} imports private {imp}; use the public API"

# No direct database access across modules.
def test_no_cross_module_db_access():
    for module in modules():
        owned_tables = tables_owned_by(module)
        for query in queries_in(module):
            for table in tables_in_query(query):
                assert table in owned_tables, \
                    f"{module} accesses {table} which it doesn't own"
```

**Dynamic enforcement** (code review and team practice):

- New cross-module calls require justification in the PR.
- Adding to a module's public API is a deliberate decision, reviewed by the module's owners.
- "We need to read this other module's data" triggers a conversation about whether the API needs an addition or the boundary needs revisiting.

> [!warning] Without enforcement, the modular monolith decays in 6-12 months. Every shortcut to "just import this one thing" looks reasonable in the PR; the cumulative effect is loss of modularity. Enforce mechanically; no amount of "we'll be careful" works.

@feynman

The same instinct as locking your front door. You wouldn't trust everyone to be polite about not entering; you have a lock. Module boundaries need locks (fitness functions); polite norms aren't enough.

@card
id: sa-ch07-c005
order: 5
title: Database Per Module — Logically
teaser: In a modular monolith, the database is shared physically but partitioned logically. Each module owns its tables; no module reads another's. This is the single most important rule.

@explanation

A modular monolith has one database (that's part of why it's a monolith). The discipline is that each module owns a slice of that database, and no other module touches its slice.

How this works in practice:

- **Module-scoped schemas or table prefixes.** `billing_invoices`, `inventory_stock`. Or `billing.invoices`, `inventory.stock` if your DB supports schemas.
- **No SELECTs across module boundaries.** If billing needs inventory data, it calls `inventory.get_stock(...)`, not `SELECT * FROM stock`.
- **No JOINs across module boundaries.** Even one cross-module JOIN couples the schemas; once it exists, refactoring either module breaks the other.
- **No FOREIGN KEYs across module boundaries.** Constraints couple the schemas at the database level.

Why this matters more than other rules:

- The shared database is the most insidious form of coupling. It's invisible (no import to check), persistent (lives across deploys), and inertial (refactoring is multi-table migration work).
- Once two modules share data through queries, neither can evolve its schema without coordinating with the other.
- This is the difference between "we *could* extract this to a service if we needed to" and "we have a distributed monolith disguised as a modular monolith."

> [!warning] If your modular monolith has cross-module JOINs, it's not actually modular. The database is the architecture; nothing else matters until the data is partitioned cleanly.

@feynman

The same instinct as the kitchen rule in a shared house. Everyone has their own shelf; you don't take from someone else's shelf. The shared kitchen works because of the discipline; the kitchen falls apart without it.

@card
id: sa-ch07-c006
order: 6
title: When to Extract a Service
teaser: A modular monolith is the right step *toward* services. Extract a module when there's clear pressure — independent scale, different team cadence, fault isolation. Until then, leave it inside.

@explanation

The modular monolith is the natural staging area for service extraction. The boundaries are already in place; the data is already separated; the API is already defined. Extracting a module to a service is a multi-week task, not a multi-quarter rewrite.

When extraction earns its keep:

- **Independent scale** — one module needs 10× the capacity of the rest. Splitting it lets you scale just that bit.
- **Different deploy cadence** — one team wants to ship daily; the rest are weekly. Independent deploy unblocks the fast team.
- **Fault isolation** — one module's outages should not take down the whole system.
- **Heterogeneous tech** — one module genuinely needs a different language, stack, or runtime.
- **Geographic distribution** — one module needs to live closer to a different population.

When extraction is premature:

- "We might want to scale this later." Not yet a real signal.
- "Microservices are best practice." Not a real reason.
- "This module is complex." Complexity in itself isn't grounds; complexity that crosses team boundaries is.
- "We want to use a different database." Often manageable inside the monolith with the right module isolation.

> [!info] The modular monolith is unique in that it makes "extract or stay" a real decision rather than a one-way door. Most architecture decisions are hard to reverse; this one is genuinely flexible.

@feynman

Renting before buying. The modular monolith is the rental — flexible, reversible, low-commitment. Service extraction is the purchase — committed, costly, but justified when you're staying.

@card
id: sa-ch07-c007
order: 7
title: Cross-Module Communication
teaser: Even though the modules are in-process, communicate through their public APIs as if they weren't. The discipline keeps the option to extract; the cost is small.

@explanation

In a modular monolith, two modules can communicate in many ways:

1. **Direct function call to the public API.** `inventory.get_stock(item_id)`.
2. **Internal event bus.** `events.publish(StockReserved(...))`; other modules subscribe.
3. **Database-level coupling.** `SELECT * FROM other_module.table`. Forbidden; covered earlier.
4. **Shared library.** Both modules import a utility. Useful for cross-cutting only.

The recommended default: function calls to public APIs, with an internal event bus for cross-cutting concerns (audit, notifications, derived data).

Why simulate the network? Because:

- **It keeps extraction cheap.** When you decide to extract a module, it's already calling APIs — you just turn one of them into HTTP.
- **It makes coupling visible.** A direct private-attribute access is invisible; an API call is searchable.
- **It enforces team contracts.** The API is the unit of agreement; private internals are negotiable.

The cost is small: one function call, one struct allocation. In a typical web request, the cross-module call is a tiny fraction of the total time.

> [!tip] If you're using an internal event bus, treat published events the same way you'd treat a Kafka topic — schema-versioned, with consumers explicitly subscribed. The discipline scales when you eventually move to a real bus.

@feynman

Wearing the same uniform inside the office that you'd wear outside. Slightly more formal than necessary; pays off the day you have a customer walk in unexpectedly. Cross-module API discipline is the same hedge.

@card
id: sa-ch07-c008
order: 8
title: Testing a Modular Monolith
teaser: Each module gets its own unit and component tests, mocking only at the public API of other modules. End-to-end tests verify the system; module tests run on every commit.

@explanation

The testing pyramid for a modular monolith:

- **Unit tests inside each module.** Fast, plentiful. Test internal functions without crossing the module's API.
- **Component tests for each module.** Spin up the module with a real database, mock other modules at their public APIs. Run on every commit.
- **Integration tests across modules.** Test interaction between two or three modules at a time. Run on PR.
- **End-to-end tests.** The whole monolith, against a real or near-real environment. Run on merge to main.

The modular structure makes each layer cleaner:

- Component tests are bounded by the module's API; no need to spin up the whole system.
- Integration tests can be paired (billing ↔ inventory) rather than holistic.
- End-to-end tests focus on critical user flows, not exhaustive permutations.

Because the modules are in-process, the test setup is much cheaper than for microservices. A modular monolith's component test is a unit test with a real database; a microservice's component test usually involves containers, networks, and start-up time.

> [!info] One of the modular monolith's quietest wins is test speed. CI that takes 5 minutes for a modular monolith might take 50 minutes for the equivalent microservices system. That difference compounds across thousands of deploys.

@feynman

Same as testing in a single building vs across many. You can verify each office's behaviour quickly when they're in one place; coordinating tests across a campus takes much more effort.

@card
id: sa-ch07-c009
order: 9
title: Operational Profile
teaser: One deploy, one log stream, one set of metrics, one process to monitor. The operational simplicity is the modular monolith's superpower — and the reason small teams succeed with it.

@explanation

The operational footprint:

- **One deployable unit.** One container, one VM, or one binary. Deploys are atomic.
- **One log stream.** All modules log to the same place; cross-module debugging is easy.
- **One process to monitor.** Health, CPU, memory — all one set of dashboards.
- **One database.** One backup strategy, one migration tool, one connection pool.
- **One CI/CD pipeline.** Build, test, deploy. Same shape every change.

For comparison, the microservices version of the same system has:

- N containers, N deploys (sometimes coordinated, sometimes not).
- N log streams, requiring aggregation infrastructure.
- N processes, each with its own dashboards.
- Possibly N databases, with N migration tools and N backup strategies.
- N CI/CD pipelines, with shared infrastructure that's its own complexity.

For a small team, the operational savings are decisive. Most teams that picked microservices early discovered that the operations work was the actual cost — not the architectural decisions.

> [!info] The 2024-25 trend of "we moved back from microservices to a modular monolith and our deploy time went from 30 minutes to 3 minutes" is the dominant operational story for this style.

@feynman

The single car vs the fleet. The single car is one tank of gas, one insurance policy, one set of tires. The fleet has 10× of each — and you only feel the cost when you're paying for it.

@card
id: sa-ch07-c010
order: 10
title: When NOT to Pick Modular Monolith
teaser: Very different scale needs per area; multiple distinct products under one roof; team count past ~100; or you're already deep in microservices and walking back is the wrong direction. In those cases, look elsewhere.

@explanation

Modular monolith is the right answer for most teams. Some teams it isn't right for:

- **Genuinely heterogeneous scale needs.** If one part of your system needs to run on 100 nodes and another on 1, the single deploy unit becomes painful.
- **Multiple distinct products.** A platform supporting unrelated products (each with its own users, billing, lifecycle) is more naturally a set of services than modules in one monolith.
- **Past ~100 engineers.** Coordination on a shared codebase, even with strong modules, starts hurting. Service extraction becomes worth the operational cost.
- **Strict regulatory isolation.** Some regulated workloads have to live in separate processes or even separate machines.
- **Existing microservices commitment.** If your team is already running 50 microservices well, the cost of consolidation may exceed the benefit.

For most teams, none of these apply. The team that thinks "we'll have all of these problems someday" usually has none of them yet — and would be better served by a modular monolith now and re-evaluating as actual constraints appear.

> [!info] The modular monolith is forgiving. You can stay in it for years and the worst that happens is "we wish we'd extracted this module sooner." Compare that to a premature microservices commitment, where you can spend years operating a system you can't easily simplify.

@feynman

The same lesson as picking your house size. Buy for the family you have, not the family you might have. The modular monolith is the right size for the team you have today; you can extend or move when the family actually grows.
