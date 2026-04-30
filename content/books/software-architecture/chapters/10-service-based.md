@chapter
id: sa-ch10-service-based
order: 10
title: Service-Based
summary: A handful of coarse-grained services talking to each other. The pragmatic middle between monolith and microservices — most teams that say "microservices" actually want this.

@card
id: sa-ch10-c001
order: 1
title: Coarse-Grained Services
teaser: Service-based architecture is a small number of services — typically 4 to 12 — each owning a major business capability. Bigger than a microservice; smaller than a monolith. Most production architectures live here.

@explanation

Service-based architecture sits between the modular monolith and microservices on the granularity spectrum. Instead of one deployable unit (monolith) or fifty (microservices), you have a handful — coarse-grained services aligned with major business capabilities.

A typical service-based system might look like:

- **Identity service** — auth, users, sessions.
- **Billing service** — invoices, payments, subscriptions.
- **Inventory service** — products, stock, pricing.
- **Order service** — cart, checkout, fulfilment.
- **Notification service** — email, SMS, push.

Each service:

- Owns a major business capability.
- Has its own data store (or schema).
- Deploys independently.
- Talks to others through APIs (REST, gRPC, or async events).

The architecture answers a real need: teams want independent deploy and clear ownership without paying for the operational complexity of fifty microservices. Service-based gives you most of the benefits at a fraction of the cost.

> [!info] Many of the systems described as "microservices" in conference talks are actually service-based. Five to ten services is plenty; most teams don't need fifty.

@feynman

Same instinct as a small group of departments in a company. Each owns a clear function; they coordinate when needed; nobody has the overhead of a thousand-person org chart. Service-based is the small-company architecture.

@card
id: sa-ch10-c002
order: 2
title: When Service-Based Wins
teaser: Multiple teams who need independent deploy. Different scaling needs across major capabilities. Operational maturity that's intermediate — past monolith, not ready for microservices. The Goldilocks zone.

@explanation

Service-based earns its keep when:

- **Multiple teams** — each can own one or two services without stepping on others.
- **Different scaling profiles** — billing scales differently from notifications; service-based lets each scale independently.
- **Independent deploy needs** — teams ship at different cadences without coordination.
- **Moderate operational maturity** — comfortable with API contracts, basic observability, but not running 50 services with full service mesh.
- **Geographic or regulatory variation** — different services can live in different regions or compliance zones.

Misfits:

- **Tiny teams** — under 15 engineers usually don't need this much separation. Modular monolith is simpler.
- **Massive teams with extreme variance** — 200+ engineers with wildly different scaling needs may genuinely need microservices.
- **Tightly-coupled domains** — if every transaction crosses every service, you're paying for boundaries you can't honour.

> [!info] Service-based is the architecture most teams should pick when they outgrow a monolith. The leap straight to microservices is usually premature; the leap to service-based is usually right-sized.

@feynman

The right number of separate buildings for a campus. One big one is hard to navigate; ten little ones is too much overhead. Three or four buildings, each housing a department, hits the right balance for most campuses.

@card
id: sa-ch10-c003
order: 3
title: Service Boundaries Track Capabilities
teaser: A service should align with a business capability, not a database table or a UI screen. The right cuts are the ones a non-technical stakeholder would recognise.

@explanation

The boundary question for service-based: what owns a service?

The wrong answers:

- **One service per database table.** Too granular; you've built microservices without admitting it.
- **One service per UI screen.** UI changes; services should be more durable than UI.
- **One service per technical layer.** "Auth service" that's just a wrapper around the auth library is sub-architecture.

The right answer:

- **One service per major business capability.** "Identity," "Billing," "Inventory" — concepts a product manager or a customer would recognise.

The capability framing has properties that matter:

- **Stable** — capabilities don't change every quarter; the boundaries persist.
- **Owned** — a single team usually owns one capability cleanly.
- **Aligned with data** — a capability has its own data; sharing is rare.
- **Aligned with change** — features within one capability change together; cross-capability features are rare.

Drawing the boundaries is the hard work. Once you've named the four to ten capabilities, the services follow naturally. Get the capabilities wrong and every service has cross-cutting features, every change touches multiple services, and the architecture fights you.

> [!tip] Test your boundaries by listing recent feature work. Ideally each feature lands in one service. If most features touch three services, the boundaries are wrong — the work pattern is telling you so.

@feynman

The same instinct as drawing the org chart. Departments are stable because they're built around lasting business needs; team-of-the-quarter restructures are unstable because they're built around current projects. Services are like departments.

@card
id: sa-ch10-c004
order: 4
title: Inter-Service Communication
teaser: Synchronous APIs for simple request-response; async events for decoupling. Most service-based systems use both — sync for queries, async for state changes.

@explanation

Service-based architectures pick a communication style or, more often, a thoughtful mix:

**Synchronous (REST, gRPC):**

- **Pros:** Simple. Immediate consistency. Direct error reporting.
- **Cons:** Caller depends on callee being available. Latency adds up across calls.
- **Best for:** Queries, simple transactions, low-latency needs.

**Asynchronous (events, queues):**

- **Pros:** Caller doesn't depend on callee. Backpressure is natural. Good for fanout.
- **Cons:** Eventual consistency. Harder debugging. Requires schema discipline.
- **Best for:** State changes that fan out, cross-service workflows, audit trails.

A common production pattern: synchronous within a request (UI calls Order, Order calls Inventory and Billing in parallel) plus async events for everything that happens after the request resolves (Order publishes "OrderPlaced"; Notification consumes it; Analytics consumes it).

This split matches user expectations: the user-facing path is fast and synchronous; the backend ripple is async and eventual.

> [!info] Don't rebuild the same shape twice. If you're using HTTP for sync, pick a stack (gRPC, OpenAPI) and apply it everywhere. If you're using events for async, pick a broker (Kafka, RabbitMQ, NATS) and apply it everywhere. Mixed standards within a category is double the operational work.

@feynman

Same instinct as picking communication tools at a company. Slack for sync, email for async. Different tools for different shapes; everyone agrees which is which.

@card
id: sa-ch10-c005
order: 5
title: Data Ownership and Sharing
teaser: Each service owns its data. Other services don't read its tables; they call its API. Shared databases are the leading cause of "we said service-based but we have a distributed monolith."

@explanation

The single most important rule: **each service owns its data, and only that service's code touches that data directly.**

What that looks like:

- **Each service has its own database** (or its own schema in a shared cluster).
- **No cross-service JOINs.** Aggregations happen in code, not in queries.
- **No cross-service foreign keys.** References across services are by ID; integrity is the application's job.
- **Reading another service's data goes through its API.** Either request-response (sync) or subscribe to events (async).

When this rule is broken — a "shared database" between services — you have a *distributed monolith*: distributed-systems complexity with monolith coupling. The worst combination.

The compromises that look reasonable but cause damage:

- "Just this one read-only query for reporting." It becomes ten queries, then schema coupling.
- "We're sharing this table because both services use it." That table is a contract; both services are now coupled to it.
- "Reporting needs to query everything." Build a reporting service that owns its own copy (denormalised, replicated from events).

> [!warning] If you're picking service-based and not enforcing data ownership, you're paying the operational cost of services without getting the architectural benefit. Either fix the data layer or simplify back to a modular monolith.

@feynman

Same as the two-team rule for shared resources. If two teams share a code repo with no ownership rules, neither team can move fast. The shared resource has to have a clear owner; everyone else asks.

@card
id: sa-ch10-c006
order: 6
title: API Contracts as the Architecture
teaser: In service-based, the API contracts between services are the architecture. Versioning, documentation, and backward compatibility are first-class concerns — not afterthoughts.

@explanation

The contracts between services define the architecture more than any diagram does. The contract:

- **Specifies the operations** — what each service exposes.
- **Specifies the schemas** — the shape of data flowing across boundaries.
- **Specifies the error model** — what happens when things go wrong.
- **Specifies versioning** — how old and new clients coexist.

What a healthy contract regime looks like:

- **Contracts in source control** — OpenAPI, Protobuf, AsyncAPI files committed alongside the service.
- **Versioned explicitly** — `v1`, `v2`. Clients target a version; servers support multiple.
- **Backward compatible by default** — additions are non-breaking; removals require a deprecation cycle.
- **Validated in CI** — both producers and consumers run contract tests.
- **Discoverable** — central registry (Backstage, Hoppscotch, internal portal) lets teams find available APIs.

What a broken regime looks like:

- Contracts in tribal knowledge ("ask Jane how to call Billing").
- No versioning; one team's deploy breaks another team.
- Inconsistent shapes across services (some snake_case, some camelCase, some XML).
- No tests; integration breaks at runtime.

> [!tip] Treat the API contract as code that ships with the service. The PR that changes a service's API includes the contract change; the team can review both at once.

@feynman

The legal contracts between two companies. If every project starts from scratch, every interaction is expensive. Standard contracts make the boundaries cheap to use; broken contracts make every interaction a fight.

@card
id: sa-ch10-c007
order: 7
title: The Shared Database Anti-Pattern
teaser: Two services reading and writing the same database tables is the most common service-based mistake. Looks fine on day one; eventual schema change is excruciating.

@explanation

The shared database — two or more services accessing the same tables — is the most common way service-based architectures degrade.

The pattern starts innocently:

- Service A and Service B both need user data.
- Instead of building a User service with its own data and an API, both services read the `users` table directly.
- "It's faster than building an API; we'll abstract it later."

Three months later:

- Service A wants to add a `last_login_ip` column. The migration affects Service B.
- Service B wants to denormalise for performance. Service A's queries break.
- Both services have grown queries that depend on specific column orders, indexes, types.
- Refactoring either service requires coordinating with the other and producing a coordinated migration.

The fix is much harder than the initial discipline: extract a User service, give it the table, change everyone's reads to API calls, change everyone's writes to API calls. Multi-quarter project.

> [!warning] The shared database is the architecture trap that swallows most service-based projects. The discipline that prevents it is "no service touches another service's tables, ever, no exceptions" — and it has to be enforced from day one, not added later.

@feynman

The same as a shared bathroom in a startup office. Day one, fine. Year two, every dispute about cleanliness becomes a stand-up agenda item. The cost wasn't building a second bathroom — the cost was negotiating the shared one for two years.

@card
id: sa-ch10-c008
order: 8
title: Distributed Transactions and Sagas
teaser: When work spans multiple services, you can't use a single ACID transaction. Sagas — sequences of compensable steps — are the practical answer. Each step succeeds independently; failures trigger compensating actions.

@explanation

In a single database, ATM-style transactions are easy: BEGIN, do everything, COMMIT or ROLLBACK. Across services, that doesn't work — there's no global lock, no global rollback.

The pattern is the **saga**: a sequence of local transactions, each in one service, with compensating actions for rollback.

```text
Place order workflow:
  1. Order service: create order (status: pending)
  2. Inventory service: reserve stock          → if fails, compensate: cancel order
  3. Payment service: charge card              → if fails, compensate: release stock + cancel order
  4. Order service: mark order as paid          → if fails, compensate: refund card + release stock + cancel order
  5. Notification service: send confirmation    → if fails, log; user can resend
```

Each step is a local transaction. The orchestrator (or a choreography of events) coordinates the sequence. If any step fails, earlier steps are compensated by their inverse operations.

Sagas are harder than ACID but tractable:

- **Compensating actions need to be designed up front.** Every step's failure mode has to have an answer.
- **Idempotency is required.** Compensations might fire twice; both attempts should be safe.
- **Eventual consistency is the default.** During the saga, the system is in an intermediate state; consumers see this.
- **Observability matters more.** Saga state — which step we're on — has to be visible.

> [!info] Choose orchestration (a central saga coordinator) for complex sagas; choreography (services react to events) for simple ones. Most teams overuse choreography and end up with sagas they can't debug because nobody owns the flow.

@feynman

Same as the multi-step refund process at a store. You can't undo the original purchase atomically; you do steps in sequence (return, refund, restock) and if one fails, the next fixes it. Sagas are how distributed systems do refunds.

@card
id: sa-ch10-c009
order: 9
title: Operations and Observability
teaser: Service-based needs more operational maturity than monolith but less than microservices. Distributed tracing, log aggregation, structured metrics — the basics, not the full service mesh.

@explanation

Operating a few services is materially different from operating one or fifty:

**What you need (and a monolith doesn't):**

- **Distributed tracing.** When a request crosses three services, you need one trace ID to follow it.
- **Centralised log aggregation.** Per-service logs are useful; cross-service searches are essential.
- **Per-service health checks and dashboards.** Each service is its own thing.
- **Cross-service alerting.** "Service A is down" vs "Service A's latency is up because Service B is slow."
- **Deployment pipelines per service.** Each can ship independently.

**What you don't need (yet):**

- **Service mesh.** Probably overkill for 5-10 services; valuable for 50+.
- **Sophisticated traffic management.** Simple load balancing is fine.
- **Per-service Kubernetes complexity.** A simpler container orchestration handles 10 services.
- **Polyglot infrastructure.** Most service-based systems benefit from a shared stack.

The operational sweet spot of service-based is real: enough services to need basic distributed-systems tooling; few enough that you don't need the heavy machinery.

> [!info] Most teams pick microservices and discover the operational tools weren't free. Service-based teams hit the same realisation but smaller — and the investment in basic tooling (tracing, log aggregation, structured metrics) pays off whether you stay service-based or grow.

@feynman

The same lesson as picking a fleet vehicle. A car is one set of insurance and maintenance; a fleet of fifty is full-time fleet management. Three or four cars is some operational overhead, but you don't need a manager — you can rotate the keys.

@card
id: sa-ch10-c010
order: 10
title: When to Stay, When to Move
teaser: Service-based works for most teams that need more than a monolith. Move to microservices only when you have specific scaling, team, or operational pressures the larger services can't accommodate.

@explanation

Service-based is a stable destination for many teams. The signals that suggest moving to microservices:

- **A single service has become a deployment bottleneck for multiple teams.** Splitting it lets each team move independently.
- **Different parts of one service have very different scaling profiles.** Splitting them lets each scale on its own curve.
- **The service has become too large to reason about.** When ownership of one service is fuzzy, it's a hint to split.
- **Operational maturity exceeds what service-based requires.** You have the tooling, the on-call, the observability — microservices' overhead is no longer the bottleneck.

The signals that suggest staying:

- **Current services are owned cleanly** — each by one team, each with stable boundaries.
- **Operational tooling is sufficient.** Tracing, logging, alerting all work.
- **Independent deploy is happening.** Teams can ship without coordinating.
- **No specific pressure to split further.** "We might want microservices later" isn't pressure.

The honest answer: many teams that picked microservices early have walked back to service-based in 2024-26. Service-based is the default destination for "we need more than a monolith but less than fifty services."

> [!info] The "we'll be microservices someday" promise is rarely kept and rarely necessary. Service-based handles the team and scale ranges most products will ever reach. The premium for going further has to be earned by specific needs.

@feynman

The same lesson as scaling a small business. Five departments works for a long time. Five hundred is a different company. Most companies don't need five hundred — and the ones that do don't get there in a planned migration; they grow into it as scale forces.
