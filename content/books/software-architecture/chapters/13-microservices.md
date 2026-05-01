@chapter
id: sa-ch13-microservices
order: 13
title: Microservices
summary: Many small services, each independently deployed, each owning its data. The most-discussed style of the 2010s — and the one most often adopted prematurely. What the architecture actually is, what it costs, when it earns its keep.

@card
id: sa-ch13-c001
order: 1
title: What Microservices Actually Are
teaser: A microservices architecture has dozens or hundreds of small services, each owning a single capability, each independently deployable, each with its own data store. The "small" and "independent" are both load-bearing.

@explanation

Microservices are easy to caricature and harder to define rigorously. The defining properties:

- **Small** — each service owns a narrow capability. "Authenticate users" or "calculate shipping cost," not "manage everything about orders."
- **Independently deployable** — each ships on its own pipeline; one service's deploy doesn't affect another.
- **Own data** — each service has its own database (or schema). No cross-service queries.
- **Communication via APIs** — synchronous (REST, gRPC) or async (events). Never shared state.
- **Owned by one team** — usually a single team can hold one service in its head and ship without coordination.
- **Bounded context** — each service represents a coherent piece of the domain.

Microservices are *not*:

- **Just "small services."** A service-based architecture has small services too. The difference is granularity and operational independence.
- **A reaction to monoliths.** Many teams shouldn't split their monolith. The right move is often a modular monolith.
- **A scalability solution.** They scale, but so do most other architectures with proper engineering.

> [!info] The 2014-2019 hype made "microservices" synonymous with "modern architecture." The 2020s have been a long correction. Many teams have moved back to service-based or modular monoliths after discovering the operational cost.

@feynman

The same lesson as picking the right number of houses. A house per family member sounds independent and clean. The maintenance bill, the coordination, the shared infrastructure — they punish you. Most families want one house with a few rooms, not many houses.

@card
id: sa-ch13-c002
order: 2
title: SOA — The Predecessor
teaser: Service-Oriented Architecture (SOA) was the 2000s pattern that microservices descended from. Coarse services, central orchestration, often a heavy enterprise service bus. SOA is mostly historical now; microservices took its lessons and shrunk the services.

@explanation

Service-Oriented Architecture (SOA) was the architectural pattern of the 2000s enterprise:

- **Coarse-grained services** — broader than microservices; closer to "service-based" in modern terms.
- **Enterprise Service Bus (ESB)** — a heavy middleware layer that routed and transformed messages between services.
- **Standards-heavy** — SOAP, WSDL, BPEL, XML. Lots of XML.
- **Top-down design** — architects defined services centrally; teams implemented to spec.
- **Reusable across the enterprise** — one "Customer service" used by every application.

What worked: the idea of services as units of business capability, with clear contracts and reusability.

What didn't:

- **The ESB became a bottleneck.** Heavy middleware that every team depended on. Changes were slow; failures were catastrophic.
- **Reusability across the enterprise was overpromised.** Services designed for many consumers became generic, brittle, and slow to evolve.
- **Centralised governance slowed teams.** The architecture team became a constraint on velocity.
- **Tooling was heavy.** Enterprise stacks were expensive, complex, and rarely loved by developers.

Microservices took the "services with clear capabilities" idea, ditched the ESB and the centralised governance, and scaled the granularity down. The result is more flexible, more decoupled, and easier for individual teams to own.

> [!info] SOA still exists in plenty of large enterprises that adopted it 15-20 years ago and haven't migrated. The replacement isn't usually "microservices everywhere"; it's "modular services with lightweight integration."

@feynman

Same as the difference between mainframes and PCs. Mainframes had one big shared resource; PCs distributed compute. Microservices to SOA is the same shape — distribute the work; ditch the central bus.

@card
id: sa-ch13-c003
order: 3
title: When Microservices Earn Their Keep
teaser: Many teams shipping concurrently. Massive scale. Heterogeneous tech needs. Strong fault isolation requirements. When at least three of these are real, microservices start paying off.

@explanation

The honest set of conditions where microservices are the right choice:

- **Many teams.** 50+ engineers, organised into 5+ teams. Each team owns its services and ships independently.
- **Genuine scale variance.** Different parts of the system have wildly different scaling needs.
- **Heterogeneous tech.** Different services genuinely benefit from different stacks (Python for data, Go for high-throughput APIs, Rust for systems-level work).
- **Strong fault isolation.** A failure in one service must not cascade. Critical for high-availability systems.
- **Operational maturity.** The team can run distributed systems — observability, deployment, on-call, incident response.
- **Geographic distribution.** Services need to live close to users in different regions, with different compliance requirements.

When most of these are absent, microservices are operational overhead with little benefit. The team pays for the architecture; the architecture doesn't pay back.

The most common reason teams pick microservices and regret it: the team isn't large enough. With 10 engineers, every microservice is owned by 1-2 people; vacation, illness, or attrition causes ownership gaps. The coordination costs exceed the team independence benefits because there's no team independence to gain.

> [!warning] "We'll start with microservices because we'll grow into them" is the most expensive shortcut in software architecture. You'll spend two years operating a system that doesn't fit your team — by the time you've grown, the architecture is calcified and migration is multi-quarter work.

@feynman

The right number of teams depends on the work. A startup of 10 doesn't need 7 departments; that's overhead. A company of 1000 needs them; that's organisation. Microservices are department-shaped; you need to be a company-shaped team to use them.

@card
id: sa-ch13-c004
order: 4
title: The Operational Tax
teaser: Microservices' biggest cost is operational. Many deploys, many log streams, many monitoring dashboards, many on-call responsibilities. The platform team that makes it tractable is itself a major investment.

@explanation

The operational footprint of microservices, compared to a single monolith:

- **N deploy pipelines.** Each service has its own.
- **N log streams.** Aggregated centrally; distributed tracing required to follow a request.
- **N monitoring dashboards.** Per-service health, plus cross-service rollups.
- **N on-call rotations.** Or one rotation that covers all of it.
- **N container images, N registries, N image lifecycles.**
- **A service mesh** — Istio, Linkerd, Cilium. Adds capability and operational surface.
- **A central observability platform** — Datadog, Honeycomb, Grafana stack. Requires investment.
- **Cross-service authentication and authorisation.** Each service authenticates each other; service identity is its own subsystem.
- **A platform team.** A dedicated group that maintains the shared infrastructure. Often 3-10 engineers' worth.

For a small team, this is a lot. For a large team, it's the price of entry.

The architecture works when the platform team's cost is less than the engineering velocity gain across all the product teams it serves. Below a certain organisation size, the math doesn't work — you're paying platform costs without enough product teams to amortise them.

> [!info] The "platform engineering" discipline that matured in 2020-2026 is largely a response to this. Companies that succeed at microservices have invested in platform — internal developer platforms, golden paths, paved roads. Without it, every team rebuilds the wheel.

@feynman

The same lesson as scaling any organisation. Adding a department adds capacity *and* HR overhead. Below a certain scale, the HR overhead exceeds the capacity benefit. Microservices are no different — the architecture has overhead that scales with team count.

@card
id: sa-ch13-c005
order: 5
title: Bounded Contexts and Service Granularity
teaser: A microservice should map to one bounded context. Too coarse and it's a service-based service; too fine and you're in distributed-monolith territory. The granularity question is where most architectural mistakes live.

@explanation

The right size for a microservice is a topic of long debate. Some heuristics that help:

- **One bounded context per service.** A capability with its own vocabulary, its own data, its own team. "Identity," "billing," "pricing," "inventory."
- **Owned by one team.** If two teams have to coordinate on every change, the service is in the wrong place — or the team boundary is.
- **Independently scalable.** The service should have its own scaling profile. If it doesn't, why is it a separate service?
- **Self-contained for most operations.** Most requests should be served without calling out to many other services.

Common granularity mistakes:

- **One microservice per database table.** Too fine. The CRUD microservices that just wrap a table aren't services; they're remote data-access objects. Pulling them together into a coarser service usually wins.
- **Microservice per UI screen.** UI changes too often; services should be more durable.
- **Microservice per developer or team without thought.** Conway's Law on autopilot.
- **Microservice that owns multiple business capabilities.** "Order service" that does pricing, fulfilment, and notifications is too coarse — it's three services in a trench coat.

> [!info] When in doubt, start coarser and split. Going from "this is too coarse" to splitting is mechanical. Going from "this is too fine" to consolidating is multi-service refactoring. The reverse direction is much harder.

@feynman

Same as picking a team size. Too big and coordination dominates; too small and you can't get anything done. The right size is the smallest that can independently own meaningful work.

@card
id: sa-ch13-c006
order: 6
title: Distributed Data — The Hard Part
teaser: Microservices' database-per-service rule is non-negotiable. Cross-service queries, distributed transactions, eventual consistency — all the costs you don't have in a monolith become daily concerns.

@explanation

The hardest part of microservices isn't the services — it's the data.

What you give up:

- **ACID transactions across services.** A "place order" operation that touches Inventory, Payment, and Order must use sagas, not transactions. Each step has compensating logic.
- **Cross-service queries.** Reports that need data from five services can't run a single SQL JOIN. They aggregate via API calls (slow) or via dedicated reporting services with replicated data (complex).
- **Foreign-key integrity across boundaries.** The user_id in the Order service is just a value; nothing enforces it points to a real user.
- **Strong consistency by default.** Eventual consistency becomes the norm; UI patterns and business logic must accept it.

What you build instead:

- **Sagas with compensating actions.** Multi-step distributed transactions explicitly modelled.
- **Event-driven projections.** Services publish events; reporting services consume and build their own views.
- **Idempotent operations everywhere.** Retries are normal; double-processing must be safe.
- **Distributed tracing.** When something goes wrong, you need to follow it across services.
- **Schema versioning and contracts.** Cross-service schemas are public; backward compatibility matters.

> [!warning] Teams that retain a shared database while calling themselves microservices are running a *distributed monolith* — distributed-systems pain with monolith coupling. This is the worst combination and unfortunately common. The database-per-service rule is the line that separates microservices from this anti-pattern.

@feynman

The same shift as moving from a single bank account to many. A bank account makes "move money from savings to checking" easy. Many accounts in many banks make every transfer a coordinated process. Microservices have the same data shape; the work is much harder.

@card
id: sa-ch13-c007
order: 7
title: Service Mesh and Communication Infrastructure
teaser: At enough services, you stop thinking about HTTP calls and start thinking about traffic. Service mesh — Istio, Linkerd, Cilium — provides the abstraction. Adds capability and ongoing operational work.

@explanation

A service mesh is the network-layer infrastructure that handles cross-service concerns:

- **Service discovery** — service A finds service B without hard-coded addresses.
- **Load balancing** — requests spread across instances of B.
- **Mutual TLS** — services authenticate each other; traffic is encrypted in flight.
- **Observability** — automatic metrics and traces for every cross-service call.
- **Circuit breaking** — when B is failing, calls to it fail fast instead of hanging.
- **Retries and timeouts** — applied uniformly across services.
- **Traffic management** — canary deploys, A/B testing, header-based routing.

Without a mesh, each service has to implement these itself (or via libraries — the older "fat client" approach). With a mesh, the network handles them; services just make calls.

The mesh isn't free:

- **Performance overhead.** Each call adds proxy hops; latency increases by milliseconds.
- **Operational complexity.** The mesh itself has to be operated, monitored, and upgraded.
- **Learning curve.** New abstractions for the team to understand.

For systems with 10+ services and real cross-service traffic, the mesh usually pays back. For smaller systems, the overhead exceeds the benefit. Most large microservices deployments in 2026 use Istio, Linkerd, or eBPF-based meshes (Cilium); smaller deployments often skip the mesh entirely.

> [!info] The mesh is what makes microservices operationally tractable at scale. If your team is going to grow into 30+ services, plan for a mesh. If you're staying smaller, you may not need one.

@feynman

The traffic system in a city. A village doesn't need traffic lights; they're overhead. A city needs them; without, gridlock. The mesh is traffic infrastructure for the city of services.

@card
id: sa-ch13-c008
order: 8
title: API Gateways and Backends-for-Frontends
teaser: External clients talk to a gateway, not to individual services. The gateway aggregates, transforms, and authenticates. BFF (backends-for-frontends) extends the pattern — one gateway per client type.

@explanation

External traffic to a microservices system goes through an **API gateway**:

- **Single entry point** — clients talk to one address; the gateway routes internally.
- **Aggregation** — one client request can fan out to multiple services; the gateway merges responses.
- **Authentication and authorisation** — checked once at the gateway; passed through as identity.
- **Rate limiting** — per client, per endpoint, per region.
- **Transformation** — services emit canonical formats; the gateway shapes them for clients.

A common refinement: **backends-for-frontends (BFF)**. Instead of one gateway for all clients, have one gateway per client type:

- **Web BFF** — serves the web app, with web-shaped responses.
- **Mobile BFF** — serves the mobile app, with mobile-optimised payloads (smaller, fewer fields).
- **Partner BFF** — serves third-party API consumers, with stable, versioned contracts.

Each BFF aggregates from internal services; each is owned by the client team that uses it. The pattern decouples internal service evolution from client expectations — internal services can change as long as the BFF maintains its contract.

> [!tip] BFFs are particularly useful when mobile constraints differ from web. Mobile apps want fewer round-trips; the BFF aggregates and pre-shapes. Web BFFs can be more permissive about chattiness.

@feynman

The same instinct as a hotel concierge. The guest doesn't talk to the kitchen, the laundry, the spa, and the front desk separately. The concierge does the routing. The gateway is the system's concierge.

@card
id: sa-ch13-c009
order: 9
title: When Microservices Fail
teaser: The most common failure: too many services, too few engineers, no platform investment. The system is technically microservices and operationally a swamp. Recovery is consolidation, not more abstraction.

@explanation

The recurring failure modes:

- **Premature decomposition.** A team of 10 has 30 services; each owned by 1 person; nobody can take a vacation.
- **Distributed monolith.** Services share a database; "microservices" is the marketing layer over what's actually a tightly-coupled system.
- **Ungoverned proliferation.** New services spawn without thought; no inventory; no clear ownership.
- **Operational debt.** The team can't deploy, monitor, or debug at the scale they've reached.
- **Cross-team coordination tax.** Most features touch many services; coordinating ships is the new bottleneck.

The fix when these patterns emerge isn't usually "more microservices best practices." It's consolidation:

- **Merge services that change together.** If service A and B always deploy as a pair, they should be one service.
- **Move shared data ownership.** Instead of two services accessing the same data, give one service ownership and the other a clean API.
- **Pull capability inward.** Some "services" are really library functions someone exposed over HTTP. Bring them back into the calling service.
- **Build the platform.** If you can't get out of microservices, invest in the platform team that makes them tractable.

> [!info] In 2024-2026, "we're consolidating our microservices into a modular monolith" became a routine engineering blog post. The retreat is the right move when the architecture isn't paying off.

@feynman

Same as any over-built system. The right answer when the bridge is too complex isn't more engineers — it's a simpler bridge. Microservices that aren't paying back deserve the same response.

@card
id: sa-ch13-c010
order: 10
title: Microservices in 2026 — A Mature View
teaser: Microservices are a tool, not a virtue. The architecture is right for some teams at some scales. The discourse has matured past "microservices everywhere" into "microservices when warranted." That's the right place to land.

@explanation

The honest 2026 view of microservices:

- **They're not the default.** Modular monolith is. Microservices are an upgrade for teams that have outgrown it.
- **They earn their keep at scale.** Past 50+ engineers, with real team independence pressure and operational maturity, microservices outperform alternatives.
- **They cost real money.** Platform engineering, operational tooling, distributed-systems expertise. Budget for it.
- **They require strong contracts.** API discipline, schema versioning, backward compatibility. Without these, microservices are chaos.
- **They benefit from platform engineering.** Paved roads, golden paths, internal developer platforms. The team velocity comes from the platform; without it, every team reinvents.
- **They co-exist with simpler patterns.** A typical large company has microservices for the core platform, modular monoliths for newer products, layered architectures for back-office tools. Mix is fine.

The teams that succeed with microservices in 2026 are the ones that grew into the architecture rather than picked it as a starting point. The ones that started with microservices and survived did so because they invested heavily in platform from day one.

> [!info] The "monolith first" advice from Martin Fowler in 2015 is still the right starting point for almost every team. A decade of evidence has not changed the calculus — most teams that ignored it regretted it.

@feynman

The right tool for the right job, at the right scale. A microservices architecture is the metropolitan transit system — invaluable in cities of millions, completely unnecessary in towns of thousands. Pick based on your population.
