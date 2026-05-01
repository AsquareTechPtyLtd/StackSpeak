@chapter
id: sa-ch05-architecture-styles
order: 5
title: Architecture Styles
summary: A tour of the named shapes — what each is, what each is for, and the dimensions to compare them on before picking one.

@card
id: sa-ch05-c001
order: 1
title: Style Is the Top-Level Shape
teaser: Architecture style is the topology your system inherits — layers, services, events, pipelines. The choice constrains everything below it. Most other architectural questions become easier once the style is set.

@explanation

An architecture style is the named shape your system takes at the top level. It's the answer to "what kind of system is this?" — and the answer matters because every style optimises for different characteristics, requires different operations, and produces a different kind of code.

The styles this book covers (one chapter each):

- **Layered** — n-tier; the workhorse default.
- **Modular monolith** — one deploy, clean internal boundaries.
- **Pipeline** — sequential transformations.
- **Microkernel** — core plus plug-ins.
- **Service-based** — coarse-grained services.
- **Event-driven** — async, decoupled, reactive.
- **Space-based** — replicated state for extreme scale.
- **Microservices** — many small, independently-deployable services.

Each is useful for some kinds of systems and wrong for others. The next chapters unpack each individually; this chapter is about the dimensions you'll compare them on.

> [!info] You'll often see "we use X architecture" written in a job posting or talk. Useful as a label; not the whole story. The style is the headline — the implementation is what actually decides whether the system holds up.

@feynman

Same instinct as picking the floor plan for a house. Open-plan, layered, modular — each has its strengths; the choice changes how every room feels. The style is the floor plan.

@card
id: sa-ch05-c002
order: 2
title: Monolith vs Distributed
teaser: The first dimension that decides everything else. A monolith ships in one piece; a distributed system ships as many pieces that talk to each other. Almost every architectural pain in production traces back to this choice.

@explanation

Two big buckets:

**Monolithic styles** — one deployable unit. Components live together, communicate via in-process function calls, share a database. Layered, modular monolith, microkernel are all monolithic.

**Distributed styles** — many deployable units. Services communicate via network. Each owns its data. Service-based, event-driven, space-based, microservices are all distributed.

The bucket dictates a long list of consequences:

- Network failures (none vs. always).
- Transaction shape (ACID vs. saga / eventual consistency).
- Debugging (stack trace vs. distributed trace).
- Deployment (atomic vs. rolling, sometimes coordinated).
- Cost (one process vs. many).
- Cognitive load (one codebase vs. many).
- Team scaling (coordination tax vs. team independence).

Most of "but how do I do X" questions in distributed systems have an obvious answer in a monolith. Most "but how do we scale X" questions in a monolith have an obvious answer in a distributed system. The trade is real and large.

> [!warning] "Microservices because Netflix uses them" is a common reasoning error. Netflix has 200M+ users and a thousand engineers. If you have 100K users and 10 engineers, the cost of distributed-systems engineering will eat the benefit.

@feynman

Same as solo apartment vs apartment building. The solo apartment has one of everything you need; you don't share with anyone. The apartment building has more capacity; you have to share elevators, hallways, garbage. Different tradeoffs; neither is universally better.

@card
id: sa-ch05-c003
order: 3
title: Synchronous vs Asynchronous
teaser: Synchronous means "wait for the answer"; asynchronous means "I'll get back to you." The choice ripples through latency, error handling, and the shape of every interface.

@explanation

The second big dimension. Synchronous communication means the caller waits for the callee to respond before proceeding. Async means the caller fires the request and continues; the response (if any) arrives later via callback, polling, or event.

Synchronous wins on:

- **Simplicity** — request, wait, get response. Easy to reason about.
- **Immediate consistency** — when the call returns, the work is done.
- **Direct error reporting** — failures come back as errors at the call site.

Asynchronous wins on:

- **Decoupling** — caller doesn't depend on callee being available.
- **Throughput** — caller doesn't block; can fire many requests in parallel.
- **Backpressure** — queues smooth out load spikes.
- **Failure isolation** — callee outage doesn't fail the caller's request.

The pattern in modern architectures: synchronous within tight component boundaries (where the work is fast and the failure modes are simple); asynchronous across team or service boundaries (where decoupling matters).

> [!info] You can mix. Many production systems are mostly synchronous with strategic async at the boundaries that need it. "Async everywhere" is as much of an over-correction as "sync everywhere."

@feynman

Phone call vs email. Phone is sync — you wait for the answer; the line is tied up. Email is async — you send, you continue, the answer arrives later. Both are valid; the right choice depends on what you're talking about.

@card
id: sa-ch05-c004
order: 4
title: Stateful vs Stateless
teaser: Stateless components remember nothing between calls; stateful ones do. Stateless scales horizontally; stateful needs replication, sharding, or routing. The choice shapes operations.

@explanation

A stateless service holds no per-request state across calls. Every request is self-contained — auth from a token, data from the database, response computed and returned. Two replicas of a stateless service are interchangeable.

A stateful service holds state. Could be in memory, a session, a connection, a long-lived computation. Two replicas are not interchangeable; the user must reach the right one.

What this dictates:

- **Scaling** — stateless services scale by adding replicas. Stateful services scale by sharding (partition state across replicas) or replicating (every replica holds all state).
- **Resilience** — stateless services lose nothing on a crash. Stateful services either persist state externally or risk losing it.
- **Routing** — stateless services accept any load balancer. Stateful services often need sticky sessions or consistent hashing.
- **Operations** — stateless services are easy to deploy, restart, replace. Stateful services need careful drains, migrations, and failover plans.

Almost every modern web service is stateless by default; state lives in databases, caches, queues. The architecture question is where the stateful boundaries are — and whether you're paying the operational cost they bring.

> [!tip] When in doubt, push state to the persistence tier and keep services stateless. The operational simplicity is worth a lot.

@feynman

The receptionist who knows everyone (stateful) vs the receptionist who looks up everyone in the directory (stateless). The first is faster but irreplaceable; the second is slower but easy to swap. Most production systems pick the second.

@card
id: sa-ch05-c005
order: 5
title: Topology — How Components Connect
teaser: Even within a style, the topology — who calls whom, in what direction — varies. Common shapes: hierarchical, peer-to-peer, hub-and-spoke, mesh. Each is its own optimisation.

@explanation

Topology is the graph structure of your components. The same set of components can be wired in very different shapes:

- **Hierarchical** — calls flow strictly downward through layers. The classic n-tier shape.
- **Hub-and-spoke** — a central component mediates everyone. Common in event-driven systems with a broker.
- **Peer-to-peer** — components talk to each other directly. Common in service-based and microservices systems.
- **Mesh** — every component to every other. Rare and usually a mistake.
- **Pipeline** — a one-way chain. Each stage feeds the next.

The topology decides operational properties:

- **Hub** — single point of failure; bottleneck; central authority.
- **Mesh** — N² connections; coupling explodes; debugging is hard.
- **Hierarchy** — clear ownership; rigid; harder to evolve.
- **Pipeline** — easy to reason about; one direction of failure.

Most "we have microservices" architectures fall into a peer-to-peer shape that drifts toward mesh over time. The drift is the source of much of the operational pain.

> [!warning] When you can no longer draw the topology on a whiteboard, the system has more topology than the team can manage. Either simplify (consolidate components) or invest in tooling (service mesh, dependency dashboards).

@feynman

Same instinct as the shape of a transit network. Spokes from a hub vs a grid vs a chain — each works for some city, none works for all. The shape is the architecture.

@card
id: sa-ch05-c006
order: 6
title: The Comparison Dimensions
teaser: Each style scores differently on a small set of axes — partitioning, deployability, evolvability, performance, scalability, simplicity, cost. The chart is what makes "which style?" a real conversation instead of a vibe.

@explanation

When evaluating architecture styles, score each on consistent dimensions:

- **Deployability** — how easy to ship a change.
- **Elasticity** — how fast scaling happens.
- **Evolvability** — how easy to add features.
- **Fault tolerance** — how the system handles partial failure.
- **Modularity** — how clean the boundaries are.
- **Performance** — latency and throughput.
- **Scalability** — how big it gets.
- **Simplicity** — total cognitive load.
- **Testability** — how verifiable the system is.
- **Cost** — total ownership.

A style that scores 5/5 on every dimension doesn't exist. Each style trades — that's why each style exists.

A useful artifact: a chart with styles on one axis and dimensions on the other, scored by your team for your context. The chart is the discussion. When two engineers disagree about a style, they usually disagree about the score on one or two dimensions; surfacing which is the productive conversation.

> [!info] The book has a multi-page table comparing styles on these dimensions. The exercise is more valuable than the table — the team's own scores reflect their priorities and constraints. Build your own.

@feynman

Same as a Consumer Reports comparison. The features chart matters less than the act of comparing. By the time you've scored five styles on ten dimensions, you know your priorities better than you did before starting.

@card
id: sa-ch05-c007
order: 7
title: Style Drives Quanta Count
teaser: Layered, modular monolith, pipeline, microkernel — all monoliths, single quantum. Service-based, event-driven, microservices — distributed, multiple quanta. The style implies the count.

@explanation

The architecture quantum (introduced in chapter 3) — the deployable unit with synchronous functional cohesion — has a count that the style largely sets:

- **Single quantum**: layered, modular monolith, pipeline (in monolithic form), microkernel.
- **Few quanta**: service-based, pipeline (when stages are independently deployed).
- **Many quanta**: event-driven (per service), space-based (per processing unit + cache), microservices.

The number of quanta is the strongest predictor of operational complexity. One quantum is one deploy, one log file, one debug session. Many quanta is many deploys, many log streams, distributed traces.

The architect's choice of style is therefore implicitly a choice about how much operational complexity the team can handle. Teams that pick microservices and don't have the ops maturity for it spend a year in pain before either retreating or maturing.

> [!info] If your team has never operated a distributed system before, picking a multi-quantum style is a multi-quarter learning curve. Plan for it; don't pretend it's a transparent choice.

@feynman

The same lesson as picking how many cars to own. One car is simple; five cars means five sets of insurance, registration, maintenance schedules. The benefit is real; the operational tax is real.

@card
id: sa-ch05-c008
order: 8
title: Style and Data Architecture
teaser: Each style has a typical data shape. Layered: shared database. Microservices: database-per-service. Event-driven: event log + materialised views. The data shape is half the architecture.

@explanation

Data architecture follows from style:

- **Layered, modular monolith** — usually one database, transactional, normalised. Multiple modules read/write the same schema.
- **Service-based** — one database shared between services, or carefully partitioned. Coarse-grained.
- **Microservices** — database per service. Each service owns its data; cross-service queries become API calls or async events.
- **Event-driven** — event log as the source of truth; materialised views per consumer. Eventual consistency by default.
- **Space-based** — in-memory data grid replicated across processing units; backed by a persistent store.
- **Pipeline** — data flows through stages; each stage's output is the next stage's input.

The right data shape isn't independent of the style — it's part of the style. Picking microservices and keeping a shared database produces a "distributed monolith," the worst of both worlds: distributed-systems complexity without distributed-systems benefits.

> [!warning] Database-per-service is the prerequisite for microservices, not an optional flavour. Teams that keep the shared database and call themselves microservices are in for a bad time.

@feynman

The architecture style is half the answer. The data shape is the other half. Both have to match — and they usually do match within a style. The "distributed monolith" is what happens when they don't.

@card
id: sa-ch05-c009
order: 9
title: The "Boring" Default
teaser: For most systems most of the time, layered or modular monolith is the right answer. The reason microservices content dominates the internet is that distributed systems are interesting — not that they're usually correct.

@explanation

A useful prior: most teams should start with a monolith and stay there longer than they think. The reasons:

- **You probably don't have the scale** to need anything else. Most systems handle their entire production load on one moderately-sized box.
- **You probably don't have the team size** to coordinate distributed development. Until you have ~30 engineers, microservice boundaries usually map to internal team boundaries that don't yet exist.
- **You probably don't have the operational maturity.** Distributed systems require observability, deployment, incident response, and on-call practices that most teams build over years.
- **You probably don't have the data shape.** Many domains are inherently transactional; forcing them into eventual consistency is friction without benefit.

The honest progression for most products:

1. **Modular monolith** — clean boundaries, single deploy, ship features.
2. **Service-based** — extract the bits that genuinely have different scale or team needs.
3. **Microservices** — only when you have the team, the scale, and the operational maturity.

Going from 1 to 2 to 3 is much easier than starting at 3 with a small team and walking it back.

> [!info] "Boring is good" applies in architecture more than almost anywhere else. Boring architectures are well-understood, well-debugged, and easy to hire for. Exotic architectures are interesting; that's not the same as right.

@feynman

The boring car gets you to work every day. The exotic one sits in the shop most of the year. Same lesson, applied to architecture: pick the boring option unless you have a specific reason not to.

@card
id: sa-ch05-c010
order: 10
title: How to Read the Style Chapters
teaser: The next chapters cover each style — what it is, when to pick it, what it costs, how it fails. Use them as a comparison reference, not a sequential read. Skip ahead to the styles you're considering.

@explanation

Each of the next chapters follows a similar template:

- **What it is** — the topology, the shape, the typical wiring.
- **When to pick it** — the use cases and team profiles where it makes sense.
- **What it's good at** — the characteristics it optimises for.
- **What it costs** — the characteristics it trades away.
- **Common pitfalls** — how teams adopt it badly.
- **Variants and modern usage** — how it shows up in 2026.

You don't need to read them in order. If your team is debating between modular monolith and microservices, read those two and the "Choosing a Style" chapter. If you're inheriting a layered system, read that one. Skip the rest until you need them.

> [!tip] The biggest value of an architecture-styles tour isn't picking your style — it's recognising styles in systems you encounter. The next time someone says "we have a CQRS event-driven architecture," you'll know what to expect from it.

@feynman

A reference book chapter, not a novel. You wouldn't read a recipe book cover to cover; you'd flip to what you needed. The same is true here — skim the menu, dive into what's relevant.
