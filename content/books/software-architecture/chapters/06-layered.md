@chapter
id: sa-ch06-layered
order: 6
title: Layered
summary: The n-tier workhorse. What "layered" actually means, why it's still the right answer for most teams, and the pitfalls that turn good layers into the dreaded big ball of mud.

@card
id: sa-ch06-c001
order: 1
title: The Default Architecture
teaser: Layered (n-tier) is the architecture most systems have, even when nobody named it. Presentation talks to business logic talks to data access talks to the database. Boring; effective; the right answer more often than not.

@explanation

A layered architecture organises code into horizontal tiers, each with a defined responsibility. The classic four:

- **Presentation** — UI, API endpoints, request/response.
- **Business logic** — rules, workflows, computation.
- **Persistence** — data access, repositories, ORM.
- **Database** — the actual store.

Calls flow downward through the layers; results flow back up. Each layer talks only to the next; the presentation layer doesn't reach directly into the database; the database doesn't reach into business logic.

The shape is so natural that teams build it without naming it. Frameworks default to it (Rails, Django, Spring, ASP.NET). New engineers find it; tutorials teach it. It's the most-shipped architecture in software, and the one most production systems quietly settle into.

> [!info] If you're building a system and haven't picked a style explicitly, you're probably building a layered architecture. That's fine — but knowing it's a choice helps you make it deliberately.

@feynman

The same shape as a typical office building. Reception on ground floor; service desks above; back office above that; the data centre in the basement. Each floor has its job; calls travel via elevators between adjacent floors.

@card
id: sa-ch06-c002
order: 2
title: When Layered Is the Right Answer
teaser: Small to medium teams. Single product. Mostly synchronous. Standard CRUD plus business logic. If your system fits that profile, layered ships features faster than anything else.

@explanation

The conditions where layered architecture earns its keep:

- **Team size** — under ~30 engineers. Coordination cost stays low; everyone can hold the system in their head.
- **Domain shape** — request/response with business rules. Most CRUD-heavy products fit.
- **Scale** — moderate. Single database, single deploy. A modern monolith handles surprising scale on commodity hardware.
- **Change pattern** — features land cross-cutting. New features touch multiple layers; the structure handles it.
- **Operational maturity** — early-stage. Monoliths are forgiving; you can ship without distributed-systems expertise.

Where layered breaks down:

- **Fine-grained scale needs** — you can't scale just the auth tier without scaling the whole monolith.
- **Multiple deployable units** — different teams need to ship at different cadences.
- **Geographic distribution** — single deploy means single region (or fancy replication).
- **Heterogeneous tech** — different parts genuinely need different stacks.

> [!info] "We outgrew our layered architecture" is the most common transition story in software. The transition is usually to service-based or modular-monolith-with-extracted-services, not directly to microservices.

@feynman

The starter house. Fits a small family well; doesn't scale to twelve kids. The right answer for the right family size; the wrong answer when the family grows.

@card
id: sa-ch06-c003
order: 3
title: Open vs Closed Layers
teaser: A closed layer means traffic must go through it; an open layer can be skipped. The default should be closed — the moment you start skipping, the architecture stops being layered.

@explanation

In a strict layered architecture, every layer is *closed*: you can't skip it on the way down. UI calls business logic; business logic calls persistence; persistence calls the database. The UI never reaches into persistence directly.

This rigidity is a feature. It means:

- **Substitution is local** — swap the persistence layer (move from MySQL to Postgres); only that layer changes.
- **Concerns stay separated** — business logic stays free of SQL; UI stays free of business rules.
- **Testing is layer-bounded** — test business logic with a fake persistence; UI with a fake business layer.

An *open* layer can be skipped. Sometimes for performance ("this read-only endpoint goes straight to the cache"). Sometimes for legacy reasons ("we never refactored the auth module to call business logic"). Each opening looks like a small win and adds a coupling point that breaks the layered guarantee.

The honest stance: keep layers closed by default. When opening one is necessary, document why. Let the exceptions be visible and few; otherwise the architecture drifts to "layered, except for the parts that aren't" — which is just informal coupling.

> [!warning] The presentation layer reaching into the database directly is a classic anti-pattern. Common in legacy code; common in tutorials; almost always a mistake. Once one endpoint does it, others follow.

@feynman

The same instinct as the chain of command. You can technically skip your manager and go straight to the VP. You can also do that once or twice and then have a much harder job. Closed layers are the chain of command for your code.

@card
id: sa-ch06-c004
order: 4
title: The Big Ball of Mud
teaser: When layered architecture decays, this is what it becomes. Layers blur, dependencies cycle, every change requires touching every layer. Most legacy codebases live here.

@explanation

The Big Ball of Mud (Brian Foote and Joseph Yoder, 1997) is the most common architecture in production: a haphazardly-structured, sprawling, sloppily-duct-taped codebase where every component depends on everything else. It's not anti-architecture; it's what architecture decays into without active resistance.

Symptoms:

- **No clear layers** — UI imports persistence; persistence imports business logic; everything imports everything.
- **No clear modules** — features are scattered across files; the structure of the code doesn't match the structure of the product.
- **Cyclic dependencies** — A imports B which imports A. Compile order becomes a black art.
- **Magic numbers and globals** — values everywhere; nobody knows what changes when.
- **One person who understands the system** — the rest of the team navigates by asking them.

How layered systems get there:

- Shortcuts that bypass layers (open them up just this once).
- Cross-cutting concerns embedded in every layer instead of factored out.
- New features added without refactoring; the system grows faster than the structure.
- Team turnover; institutional knowledge of *why* the layers exist gets lost.

> [!warning] Once a system is a Big Ball of Mud, the only fixes are gradual extraction or full rewrite. Both are expensive. The cheap intervention is preventive: fitness functions, code review against architectural rules, and active layer enforcement before the rot starts.

@feynman

The garage that started organised and now has tools, kids' bikes, paint cans, and old furniture in piles. Each individual piece arriving was reasonable; the cumulative result is unworkable.

@card
id: sa-ch06-c005
order: 5
title: Keeping Layered Honest
teaser: Layered architecture stays layered through enforcement, not optimism. Fitness functions in CI catch the drift; code review catches the rest. Without both, layers blur in 18 months.

@explanation

The gap between "we have a layered architecture" and "our code follows the layered architecture" is enforcement. Fitness functions are how you close it.

Examples that work in real codebases:

```python
# Presentation layer never imports persistence directly.
def test_no_ui_to_db_imports():
    for module in modules_in("src/ui"):
        for imp in imports_of(module):
            assert not imp.startswith("src/persistence"), \
                f"{module} bypasses business layer"

# Business layer never imports presentation.
def test_no_business_to_ui_imports():
    for module in modules_in("src/business"):
        for imp in imports_of(module):
            assert not imp.startswith("src/ui"), \
                f"{module} reaches into UI; layers should flow downward"

# No cycles in module graph.
def test_no_layer_cycles():
    assert not has_cycles(module_graph())
```

These fail builds. They show up in pull request feedback. New engineers learn the rules without being told because the CI tells them.

The complement is code review. Fitness functions catch cleanly-violated rules; code review catches the subtler "this technically respects the layers but has the wrong shape" issues. Together they keep the architecture honest.

> [!info] Tools like ArchUnit (JVM), import-linter (Python), dependency-cruiser (JS/TS) make these checks practical. Pick one; integrate it on day one of the project; never look back.

@feynman

The same instinct as type-checking. The compiler enforces the rules so the human doesn't have to remember. Architecture fitness functions are the type-checker for your structural rules.

@card
id: sa-ch06-c006
order: 6
title: Layers in a Microservice
teaser: "Layered" doesn't mean "monolithic." Each microservice tends to be internally layered — UI/API → service logic → repository → DB. The style scales down to per-service.

@explanation

The layered pattern is fractal. Even microservices systems usually have layered architecture inside each service:

- **API layer** — HTTP handlers, request validation, response shaping.
- **Service / domain layer** — business logic for this service.
- **Repository / data layer** — persistence concerns.
- **Database** — the service's own store.

The same closed-layer principles apply: handlers don't reach into the database; repositories don't import handlers. Each service is a mini-monolith with the same internal structure.

This matters because:

- **Engineers move between services** — finding the same internal shape everywhere makes ramp-up faster.
- **Testing is consistent** — each service tests its layers the same way.
- **Refactoring is local** — fixing the persistence layer of one service doesn't ripple.

The microservices style is about *external* topology (many deployable units, network boundaries). Layered is the *internal* shape that most well-built services adopt.

> [!info] If you're picking microservices and don't enforce internal layering, you'll have a distributed system *and* a per-service ball of mud. That's the worst combination.

@feynman

The shape of one apartment is unrelated to the shape of the apartment building. Each unit can be laid out cleanly even when the building is sprawling. Service-internal layering is the same idea.

@card
id: sa-ch06-c007
order: 7
title: Hexagonal / Ports-and-Adapters Variant
teaser: A modern refinement of layered architecture. The business logic sits in the centre; everything else — UI, DB, third parties — is an adapter at the edge. Decouples the domain from infrastructure.

@explanation

Hexagonal architecture (Alistair Cockburn) — also called ports-and-adapters — is the layered architecture rotated. Instead of horizontal layers (UI on top, DB on bottom), you put the business logic in the centre. Around it are *ports* (interfaces) and *adapters* (implementations) connecting to the outside world.

What this rearrangement buys:

- **Business logic has no dependencies on infrastructure.** It uses ports defined in its own terms.
- **Adapters can be swapped without touching the domain.** Move from REST to gRPC: change adapters; domain unchanged.
- **Tests use fake adapters.** No mocking the database; the test wires a fake.
- **The domain is reusable across different deployments.** Same domain logic in a CLI, a web API, a worker.

In practice this is what most modern monolithic systems aspire to. The names vary — "hexagonal," "clean architecture," "onion architecture" — but the principle is the same: the domain doesn't know about the world; the world adapts to the domain.

> [!tip] The adapter discipline is most valuable for the *external* boundaries — third-party APIs, the database, the queue. The strict version (every internal call through a port) is overkill for small systems.

@feynman

Same instinct as having a power adapter for international travel. The laptop doesn't know about the wall socket; the adapter handles the difference. Hexagonal architecture is adapters all the way down.

@card
id: sa-ch06-c008
order: 8
title: Layered's Performance Profile
teaser: Layered systems have predictable performance because the call path is predictable. Latency is the sum of layer overhead; throughput is bounded by the slowest layer. Both are usually fine.

@explanation

A layered call path looks like:

```text
HTTP request
  → controller (validation, parse)
    → service (business logic)
      → repository (build query)
        → database (execute, return rows)
      → repository (map to objects)
    → service (continue logic)
  → controller (serialize response)
HTTP response
```

The total latency is the sum of each layer's work plus the database round-trip. Most of the time, the database is 80% of the budget. Optimisation focuses there: indexes, query plans, caching.

Throughput is similar — bounded by the slowest layer, usually the database. Adding application-tier replicas helps until the database becomes the bottleneck. After that, you scale the database (read replicas, sharding) or accept the ceiling.

This predictability is a feature. You can model the system's performance with simple arithmetic; you can identify bottlenecks by measuring each layer; you can scale each independently within limits.

> [!info] Most layered systems hit a single-database performance wall before any other architectural concern matters. Solving that wall — read replicas, caching, query optimisation, schema redesign — is usually higher leverage than restructuring the architecture.

@feynman

Same as a factory line. Total throughput is set by the slowest station. You speed up the line by speeding up that station, not by adding more workers to the fast ones.

@card
id: sa-ch06-c009
order: 9
title: Common Mistakes
teaser: Sneaking past layers; bloating the service layer; one-layer-per-table; god controllers. Each turns layered into pseudo-layered. Watch for them in code review.

@explanation

The recurring mistakes:

- **Skipping a layer "for performance."** UI reaches into the database for one read-only endpoint. Six months later, half the endpoints do it.
- **Anaemic domain model.** Business logic ends up in controllers (UI layer) or services that just delegate to the repository. Domain layer becomes a thin wrapper around CRUD.
- **God controllers.** One controller handles thirty endpoints. The "controller per resource" pattern is fine; "controller per system area" turns into a junk drawer.
- **One-layer-per-table.** Repositories named after database tables instead of business concepts. Couples your domain to your schema.
- **Cross-cutting in every layer.** Logging, auth, error handling repeated in every method. Should be middleware/aspects; ends up scattered.
- **Repositories that return entities all the way up.** UI receives database entities. Schema changes break the UI. Use DTOs at the boundary.

Each of these starts as a small concession and compounds. The fix is mostly review discipline plus fitness functions for the structural rules.

> [!warning] When the whole team has stopped believing in the layers ("we just put it where it makes sense"), the layers are gone. Either re-establish them or admit you're running a Big Ball of Mud and plan accordingly.

@feynman

Each of these is a paper cut; a hundred paper cuts is a serious wound. The architecture survives the individual concession; it doesn't survive a team that has lost the discipline to push back.

@card
id: sa-ch06-c010
order: 10
title: When to Stay, When to Move
teaser: Layered serves you until it stops. Signs to consider a different style: independent deploy needs, team size past ~30, very different scale shapes per area. Until then, stay.

@explanation

Layered is a starting point that becomes a continuing point for most teams. The honest signals that suggest moving:

- **Independent deploy pressure** — different teams want to ship at different cadences and the monolithic deploy is the bottleneck.
- **Differing scale needs** — one part of the system needs 10× the capacity of another. The single-deploy model means scaling everything.
- **Team size growth** — past ~30 engineers, coordination on a shared codebase starts hurting velocity.
- **Different operational profiles** — one part runs on a schedule, another is real-time, another batch. The single deploy can't accommodate.
- **Acquired or merged services** — multiple legacy systems need to integrate; making them all one deploy is unrealistic.

When these pressures are real, the next step is usually *service-based* (a few coarse-grained services), not microservices. The transition is incremental: extract one bounded context at a time, leave the rest in the monolith, see how it goes.

When those pressures aren't real, stay layered. The boring architecture is the right architecture for most teams most of the time.

> [!info] The teams that stay successfully layered for ten years aren't the ones with magic. They're the ones who keep the layers honest, refactor as they grow, and resist the urge to chase whatever architecture is trendy this year.

@feynman

The same lesson as picking a vehicle. The sedan handles 95% of trips; you don't trade it for a truck because of the 5% that needed a truck. You rent a truck for the 5%. The sedan stays.
