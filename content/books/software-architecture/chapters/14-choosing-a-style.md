@chapter
id: sa-ch14-choosing-a-style
order: 14
title: Choosing a Style
summary: A decision framework for picking among the styles. Domain, scale, team, characteristics — the dimensions that actually decide, in the order they should be considered.

@card
id: sa-ch14-c001
order: 1
title: Start From Constraints, Not Styles
teaser: Don't pick a style and ask "where does it fit?" Pick the constraints — team, scale, characteristics — and let them point at a style. The style is the answer; the constraints are the question.

@explanation

The wrong way to pick: "We want microservices." Then look for reasons. Then justify them. The style is decided before the analysis.

The right way: enumerate constraints — team size, scale targets, prioritised characteristics, operational maturity, domain shape. Score each style against the constraints. The winner is the style that fits *this* situation.

A useful constraint checklist:

- **Team size and shape.** How many engineers? How many teams? How experienced?
- **Scale, current and planned.** Requests per second, data volume, geographic distribution.
- **Prioritised characteristics.** From the chapter on -ilities. Pick three or four that matter most.
- **Operational maturity.** What can your team actually run today?
- **Domain shape.** Transactional? Analytical? Real-time? Batch?
- **Tech constraints.** Language ecosystem, existing infra, regulatory.
- **Time horizon.** Are you optimising for next quarter or next decade?

Score each style on how well it satisfies each constraint. The exercise produces a winner — and, more importantly, surfaces the trade-offs the team is implicitly accepting.

> [!info] The act of scoring is more valuable than the score. By the time you've worked through it, your team has aligned on what actually matters — which is the harder problem than picking the style.

@feynman

The same as picking a vehicle. You don't start with "I want a sports car" and then explain why; you start with "I have three kids, two dogs, and a long commute" and the vehicle picks itself. Architecture is the same shape.

@card
id: sa-ch14-c002
order: 2
title: Domain Shape Drives Half the Answer
teaser: Transactional vs analytical, request-response vs event-driven, real-time vs batch. The domain's natural shape rules out half the styles before you've started. Don't fight the domain.

@explanation

The shape of the work tells you which styles fit:

- **Transactional CRUD with business logic** — layered, modular monolith, service-based.
- **Analytical / reporting** — pipeline, sometimes layered with a dedicated analytics layer.
- **Stream processing** — event-driven, pipeline.
- **Extreme-scale interactive** — space-based, microservices.
- **Platform / extensibility** — microkernel.
- **Mixed (multiple domains)** — service-based or microservices, possibly with internal pipelines.

Some styles are wrong for some domains:

- **Pipeline architecture for an interactive UI** — latency adds up; the shape doesn't fit.
- **Event-driven for a simple CRUD app** — overhead without benefit.
- **Microservices for a small focused product** — complexity without payoff.
- **Space-based for ordinary load** — engineering theatre.

Recognise the shape early. The team that's debating "microservices vs event-driven" without first asking "what's the actual shape of our domain?" is debating in the wrong direction.

> [!info] Most production systems are at heart "transactional CRUD with business logic" — and most of them should default to layered or modular monolith. The exceptions are the interesting cases; they're not the default.

@feynman

The same as picking a building shape for the use case. A library doesn't look like a stadium; a stadium doesn't look like an office. The use decides the shape; pretending otherwise produces buildings that don't work.

@card
id: sa-ch14-c003
order: 3
title: Team Size Decides the Granularity
teaser: 5 engineers can't run microservices. 500 engineers can't run a monolith effectively. The team count is one of the cleanest predictors of which styles fit.

@explanation

Rough thresholds, with caveats:

- **Under 10 engineers** — modular monolith. Maybe layered. Anything else is overhead.
- **10–30 engineers** — modular monolith or service-based. Microservices are usually premature.
- **30–80 engineers** — service-based works well. Modular monolith still fine if you're disciplined. Microservices viable for the parts that have specific pressures.
- **80–200 engineers** — service-based or microservices. The decision depends on team independence pressure and operational maturity.
- **200+ engineers** — microservices, usually. Below this many engineers, the platform investment doesn't amortise.

The thresholds are soft. Some 10-engineer teams run microservices well (with specialised platforms or managed infrastructure that does the heavy lifting). Some 200-engineer teams run modular monoliths beautifully (Shopify, Basecamp, GitHub). The thresholds are starting points, not laws.

What matters more than the raw count is the team *shape*:

- **Many small teams** — favours microservices or service-based.
- **Few large teams** — favours modular monolith or layered.
- **One team** — modular monolith or layered. Pretty much always.

> [!info] Conway's law: your architecture will mirror your team structure. If you can't articulate the team structure that supports your chosen architecture, you're going to fight Conway's law. You'll lose.

@feynman

The same instinct as picking the office layout for the team. One team in a single open space; 50 teams in separate floors with conference rooms. Architecture and org structure track each other; either both fit or both fight.

@card
id: sa-ch14-c004
order: 4
title: Operational Maturity Sets the Ceiling
teaser: The most important architecture you can run is the most complex one your team can operate. Past that ceiling, you have a pretty diagram and a permanent incident.

@explanation

Different styles demand different levels of operational maturity:

- **Layered, modular monolith** — basic. One process, one log, one deploy. Most teams already have what's needed.
- **Pipeline** — moderate, depending on the runtime (batch is easy; streaming is harder).
- **Microkernel** — moderate. The plug-in lifecycle and discovery need maturity.
- **Service-based** — moderate-to-high. Multiple deploys, distributed tracing, log aggregation, on-call rotation.
- **Event-driven** — high. Brokers, schema discipline, event observability, saga management.
- **Microservices** — very high. All of service-based plus service mesh, platform engineering, distributed-systems expertise.
- **Space-based** — very high, with specialised expertise. Data grid operations, replication tuning, capacity planning.

The honest assessment is hard for many teams because the gap between "we know we should have this" and "we actually have this" is large. Distributed tracing is easy to imagine and time-consuming to build; observability is easy to want and expensive to operate.

When a team picks a style its operational maturity can't support, the result is the same: production is fragile; incidents are long; team time goes to ops instead of features. The architecture is a line on a diagram; the operations are real.

> [!warning] Don't pick a style your team can't operate. Pick the most complex one you can run *today*, plus a small extension you can grow into. Anything beyond that is wishful diagramming.

@feynman

The car you can drive vs the car you wish you could drive. The race car you can't handle is more dangerous than the sedan you can. Same lesson — operational reality limits architectural ambition.

@card
id: sa-ch14-c005
order: 5
title: Characteristics Trade-Off Matrix
teaser: A grid with styles on one axis and characteristics on the other, scored 1-5. The team scores together; the discussion is the design conversation. The matrix is the artifact.

@explanation

A practical exercise: build the matrix.

```text
                  | Modular | Service- | Event-  | Micro-   | Space-
                  | Monolith| Based    | Driven  | services | Based
------------------|---------|----------|---------|----------|--------
Deployability      |   3     |   4      |   4     |   5      |   3
Elasticity         |   2     |   3      |   3     |   4      |   5
Evolvability       |   4     |   4      |   3     |   5      |   3
Fault Tolerance    |   2     |   3      |   4     |   5      |   5
Modularity         |   3     |   4      |   4     |   5      |   4
Performance        |   5     |   4      |   3     |   3      |   5
Scalability        |   2     |   3      |   3     |   5      |   5
Simplicity         |   5     |   3      |   2     |   1      |   1
Testability        |   4     |   3      |   2     |   3      |   2
Cost (lower better)|   5     |   4      |   3     |   2      |   1
```

These are illustrative; your scores will differ based on context. The exercise is what matters — sit down with the team, score together, argue, justify. By the end, you've aligned on which characteristics matter and which styles you can actually live with.

> [!tip] The matrix isn't a calculator. Don't sum the columns and pick the highest. The right answer is the style that best matches your *prioritised* characteristics — the ones your team and domain actually care about. Other characteristics are tradeoffs you accept.

@feynman

The same as a comparison shopping spreadsheet. The spreadsheet doesn't decide; the conversation around it does. By the time you've filled it in, you know what you want — even if the spreadsheet doesn't pick a clear winner.

@card
id: sa-ch14-c006
order: 6
title: Hybrid Styles Are Normal
teaser: Real systems mix styles. A modular monolith with extracted services for scale-sensitive parts. Microservices with event-driven backbone. Layered services with microkernel for plug-ins. Most production systems are hybrids; that's fine.

@explanation

Pure styles are rare in the wild. Most real systems combine elements:

- **Modular monolith with extracted services.** The bulk of the system is one deploy; one or two parts have been pulled out as standalone services for specific reasons (scaling, isolation, polyglot).
- **Microservices with synchronous core and event-driven periphery.** Critical paths are sync; fan-out and audit are async events.
- **Layered architecture with a pipeline subsystem.** Most of the app is layered; the data ingestion path is a pipeline.
- **Service-based with microkernel components.** A few of the services are themselves plug-in-driven; the rest are conventional.

Hybridisation isn't compromise; it's appropriate use of tools. Each style fits some part of the system; using all of them where they fit produces a system that works.

The discipline is in being explicit about which style applies where:

- Document the mix. "We're a modular monolith except for the search service, which is standalone."
- Apply each style's discipline within its domain. The modular monolith's modularity rules apply to the monolith; the service's contracts apply at its boundary.
- Don't accidentally drift. The "microservice" that's actually inside the modular monolith because someone copy-pasted patterns is confusion.

> [!info] The 2026 reality: most architectural job descriptions and conference talks describe systems as "microservices" or "event-driven" because pure labels are easier to communicate. The actual systems are hybrids. The hybrid is fine; the dishonest labelling causes confusion.

@feynman

The same shape as buildings designed for mixed use. The ground floor is retail; the floors above are residential; the basement is parking. Each fits the function; the building is a hybrid because the uses are mixed. Architectures follow the same logic.

@card
id: sa-ch14-c007
order: 7
title: Cost as a First-Class Constraint
teaser: Different styles have very different cost curves. Microservices and space-based are expensive to operate. Layered and modular monolith are cheap. If cost matters in the decision, account for it explicitly.

@explanation

The total cost of an architecture has multiple components:

- **Infrastructure** — compute, storage, network, managed services.
- **Engineering** — feature velocity, debugging time, on-call burden.
- **Platform** — dedicated team for shared infrastructure.
- **Tooling** — observability, deployment pipelines, security scanning.
- **Operational** — incident response, capacity planning, capacity headroom.

Different styles cost differently:

- **Layered, modular monolith** — low. One deploy, one log, simple infra. Most cost is engineering.
- **Service-based** — moderate. Multiple deploys, basic distributed tooling. Engineering cost similar; ops cost up.
- **Microservices** — high. Platform investment is required; per-service ops add up; infrastructure scales with service count.
- **Event-driven** — moderate-to-high. Broker infrastructure, schema management, event-aware tooling.
- **Space-based** — very high. Specialised infrastructure, dedicated platform expertise.

For startups, cost is often the binding constraint. A modular monolith team can ship features for the cost a microservices team spends on operations. Picking the cheaper architecture isn't a downgrade; it's a strategic call to spend on what matters.

> [!info] "We can afford the architecture" should be a conscious decision. The team that doesn't think about the cost of microservices and adopts them anyway is making the decision implicitly — and usually badly.

@feynman

Same lesson as picking a house. Bigger isn't always better; the mortgage payments cancel the lifestyle benefits. Architecture cost works the same — pick the right size, not the most ambitious one.

@card
id: sa-ch14-c008
order: 8
title: The Default — Modular Monolith
teaser: When you don't have a specific reason to do something else, build a modular monolith. It's the boring answer; it's the right answer for more teams more of the time than any other style.

@explanation

The defensible default for most teams in 2026:

- **Single deployable unit.** Easier to ship, easier to debug, easier to operate.
- **Strong internal modules.** Clear boundaries, clean contracts, owned domains.
- **One database.** Logical partition by module ownership; no cross-module SQL.
- **Conventional technology.** Whatever your team is best at; pick boring stacks.
- **Service-based escape hatches.** The monolith is the home; specific services can be extracted for specific reasons.

This default fits:

- Most teams under 50 engineers.
- Most domains (transactional CRUD, business logic, light analytics).
- Most workloads (up to and including surprising scale).
- Most operational profiles (start-up to mid-stage).

When the default stops fitting, the move is incremental: extract one service, see how it goes, extract another if pressure justifies. The team grows into a service-based or microservices architecture only as specific pressures emerge.

The teams that pick the default and stay there for years aren't dragging their feet — they're successful. The team that ships features at a steady cadence on a modular monolith is the team that doesn't need to interrupt feature work for an architecture migration.

> [!info] "Boring is good" is the right starting point. The exotic architectures get the conference talks; the boring architectures get the shipped products.

@feynman

The boring car gets you to work daily. The exotic one gets you to the dealership monthly. Same lesson, applied to architecture — pick the boring option until you have a specific reason not to.

@card
id: sa-ch14-c009
order: 9
title: Reversibility — Pick the Door You Can Walk Back Through
teaser: Some style choices are reversible; some aren't. Modular monolith → service-based is incremental. Microservices → modular monolith is multi-quarter. When in doubt, pick the more reversible direction.

@explanation

Architecture decisions vary in reversibility:

- **Modular monolith → service-based:** moderately reversible. Extract a service; if it doesn't work, fold it back.
- **Service-based → microservices:** moderately reversible. Split a service; can be merged back.
- **Microservices → service-based:** harder. Many services to consolidate; data migration; team boundary realignment.
- **Microservices → modular monolith:** very hard. Sometimes called "monolith first redux"; multi-quarter project.
- **Single-database → database-per-service:** very hard. Large data migration, schema changes, application changes.

The asymmetry suggests: when uncertain, pick the more reversible direction. Start coarser; split later if needed. Start with shared databases (within a single service); split later if needed. Start synchronous; introduce async events later.

This isn't conservatism — it's optionality. The architecture that's easy to refactor preserves the team's ability to react to learning.

> [!warning] "We'll just adopt microservices because we can always go back later" is wrong. Going back is the hardest direction. Adopt microservices when you're sure; the cost of being wrong is bigger going one way than the other.

@feynman

The same lesson as one-way doors vs two-way doors. Two-way doors you can walk back through; one-way doors are commitments. Pick two-way doors when you can; reserve one-way doors for decisions you're confident about.

@card
id: sa-ch14-c010
order: 10
title: The Decision Framework, in Order
teaser: Domain → constraints → characteristics → team → operations → reversibility → style. Walk through in that order; let the answer fall out. Skip a step and you've decided on vibes.

@explanation

A short, ordered framework:

1. **What's the domain shape?** Transactional, analytical, streaming, real-time. Rules out half the styles immediately.
2. **What are the hard constraints?** Regulatory requirements, existing infrastructure, language stacks. Narrows the field.
3. **What are the prioritised characteristics?** Pick three or four that matter most. Score the remaining styles against them.
4. **What's the team shape?** Size, experience, structure. Eliminates styles the team can't realistically operate.
5. **What's the operational maturity?** Honest assessment of what's running well today plus what could realistically be built.
6. **How reversible is the decision?** Prefer reversible directions when uncertain.
7. **Pick.** With the previous six steps done, the answer is usually obvious.
8. **Document.** ADR with the decision, the constraints considered, the alternatives rejected, the trade-offs accepted.

The framework looks slow but compresses the decision into hours instead of months. The slow version — debating microservices vs monolith for two quarters without ever scoring against constraints — is the actually-slow version.

> [!info] Most architectural mistakes aren't from picking the wrong style. They're from picking without going through this kind of process — vibes, hype, or "we did this at my last job." The framework makes the decision defensible.

@feynman

Same as any structured decision framework. The framework doesn't decide; it forces you to surface the inputs the decision depends on. Once the inputs are clear, the decision usually follows.
