@chapter
id: apid-ch12-multi-api-architectures
order: 12
title: Multi-API Architectures
summary: Real systems compose many APIs — internal services, external partners, mobile and web frontends each pulling different shapes — and the patterns for stitching them (BFF, composition, mesh, gateway-of-gateways) decide whether the architecture stays comprehensible at scale.

@card
id: apid-ch12-c001
order: 1
title: Many APIs, One Product
teaser: At scale, a product is not one API — it is dozens of APIs composed together, and the seams between them are where complexity and failure accumulate.

@explanation

Early in a product's life, one API often serves all clients: the web frontend, the mobile app, and any third-party integration all hit the same endpoints. This feels simple. It becomes expensive as each of those clients diverges in what it needs.

The composition challenge appears in several forms:

- **Shape mismatch.** Mobile clients want smaller payloads and fewer round trips. Web dashboards want aggregated views. Admin tools want raw data. A single API cannot serve all three well simultaneously.
- **Release coupling.** Adding a field for mobile breaks the API contract for existing integrations. Versioning multiplies. Nobody is happy.
- **Ownership diffusion.** As teams grow, the single API becomes a shared bottleneck — every team blocks on the team that owns it.
- **Security surface.** One API means one security model. Internal microservices and public integrations have radically different trust requirements.

The patterns covered in this chapter — BFF, composition layers, service meshes, partner APIs — all exist to answer the same question: how do you let a product made of many APIs behave coherently to the people using it?

The first honest observation is that composition is the default, not the exception. Every non-trivial production system is already doing multi-API architecture; the only question is whether it is intentional.

> [!info] If you are building a product with more than one client type (mobile, web, third-party), you already have a multi-API problem. Designing for it early is cheaper than refactoring under load.

@feynman

A product at scale is like a restaurant — the customer sees one menu, but the kitchen has separate stations for grill, pastry, and prep, each with its own workflow, and the expediter's job is to make sure a coherent plate arrives at the table.

@card
id: apid-ch12-c002
order: 2
title: Backend-for-Frontend (BFF)
teaser: A BFF is a thin API layer owned by a specific frontend team — it aggregates, shapes, and translates backend calls into exactly what one client type needs, and nothing else.

@explanation

Phil Calçado introduced the Backend-for-Frontend pattern at SoundCloud, and Sam Newman gave it wide coverage in *Building Microservices*. The core idea is simple: instead of forcing multiple frontends to share one general-purpose API, give each frontend its own dedicated backend that speaks its language.

```
Mobile App  ──►  Mobile BFF  ──►  User Service
                              ──►  Content Service
                              ──►  Recommendation Service

Web App     ──►  Web BFF     ──►  User Service
                              ──►  Content Service
                              ──►  Analytics Service
```

The BFF owns:

- **Aggregation.** One BFF call may fan out to three internal API calls and merge the results, saving the client from orchestrating that itself.
- **Shape.** The BFF can strip fields, rename properties, and flatten nested structures into exactly what the client renders.
- **Protocol translation.** Internal services may speak gRPC or event streams; the BFF exposes REST or GraphQL to the client.
- **Auth delegation.** The BFF is the trust boundary — it holds the session token and exchanges it for internal service credentials.

The fragmentation tradeoff is real. If you have five client types (iOS, Android, web, TV, partner), you may end up with five BFFs. Each is a small surface, but each is a service that must be deployed, monitored, and maintained. Teams that build one BFF per client and then let those BFFs accumulate shared logic — copy-pasted between them — end up with a distributed monolith made of BFFs.

The discipline is: a BFF should contain **no** business logic. If the same logic appears in two BFFs, it belongs in a downstream service, not in both BFFs.

> [!warning] BFFs that accumulate shared business logic become a form of distributed duplication. If two BFFs implement the same rule, extract it into a service.

@feynman

A BFF is like a personal assistant for each client — the mobile team's assistant knows exactly what the mobile app needs and fetches it from the right departments, while the web team's assistant does the same for the web app, and neither tries to do the other's job.

@card
id: apid-ch12-c003
order: 3
title: API Composition
teaser: An API composition layer aggregates calls to multiple downstream services and returns a single coherent response — trading simplicity for coordination complexity and latency.

@explanation

API composition is a general pattern: a service (or a layer) accepts a request, fans out to several backend APIs, and merges the results. It is sometimes implemented as a BFF, sometimes as a dedicated aggregator service, and sometimes as a GraphQL gateway.

A concrete example: a product detail page needs data from three services.

```
Client
  |
  v
Composition Layer
  |-- GET /products/{id}     --> Product Service
  |-- GET /inventory/{id}    --> Inventory Service
  |-- GET /reviews/{id}      --> Review Service
  |
  v
Assembled response to client
```

The composition layer runs the three calls (possibly in parallel), merges the responses, handles partial failures gracefully, and returns one clean payload.

What composition buys you:

- **Fewer round trips for clients.** The client makes one request instead of three.
- **Stable contracts.** Internal service APIs can change without clients noticing, as long as the composition layer adapts.
- **Centralized error handling.** A downstream service being slow or unavailable can be handled in one place rather than in every client.

What it costs:

- **Latency stacking.** If the three calls cannot be parallelized, the total latency is the sum. Even with parallelism, you pay the latency of the slowest call.
- **Coupling.** The composition layer knows about all its downstream services. As services change, the composition layer changes.
- **Observability complexity.** When a composed request is slow, it is not obvious which downstream call is the culprit without distributed tracing.

GraphQL is the most common framework for building composition layers because its resolver model maps naturally to fan-out patterns — each field in a query resolves independently, and the engine can parallelize where there are no dependencies.

@feynman

API composition is like a travel agent booking a trip — instead of you separately calling the airline, hotel, and car rental company, the agent coordinates all three and hands you one itinerary.

@card
id: apid-ch12-c004
order: 4
title: Internal vs External API Boundaries
teaser: Internal and external APIs serve different masters — internal APIs optimize for developer velocity and can evolve freely; external APIs are contracts with strangers and must be treated like published law.

@explanation

One of the most costly mistakes in multi-API architecture is designing the same API to serve both internal services and external consumers. The constraints are different enough that they pull the design in opposite directions.

**Internal APIs:**

- Consumers are known. You can contact them directly when you need to make a breaking change.
- Deployment is coordinated. Internal services can be migrated on a schedule.
- Trust is high. mTLS or network-level controls provide strong guarantees about who is calling.
- Contracts can be informal. Shared schema repos, gRPC .proto files, and integration tests are enough.
- Performance is the priority — verbosity and robustness are secondary.

**External APIs:**

- Consumers are unknown strangers. You cannot contact them. They find out about changes from your changelog.
- Versioning is mandatory. Once published, a contract must be honored for years.
- Trust is zero. Every request must be authenticated and authorized. Rate limiting exists because some callers are adversarial.
- Documentation is a product. If it is unclear, consumers will not use the API or will misuse it.
- Stability is the priority — the most useful API is the one that does not surprise its users.

The correct pattern is to let internal services evolve freely behind an internal boundary, and to publish a stable, versioned external API that is a deliberate projection of only what external consumers need. That projection is usually implemented by a gateway or a BFF.

Mixing the two — exposing internal service APIs directly to external callers — means external callers block every internal refactor, and internal services carry the authentication and rate-limiting overhead designed for adversarial traffic.

> [!warning] Exposing internal service APIs directly to external consumers creates a coupling that is expensive to undo. Treat the internal/external boundary as a deliberate architectural line from the start.

@feynman

Internal and external APIs are like the difference between talking to a colleague and publishing a legal contract — with a colleague, you can call them and say "we're renaming this field tomorrow," but once something is published externally, you are bound to it.

@card
id: apid-ch12-c005
order: 5
title: Service Mesh vs API Gateway
teaser: A service mesh (Istio, Linkerd) handles east-west traffic between services; an API gateway handles north-south traffic from external clients — they overlap on auth and observability, but solve different problems.

@explanation

Both service meshes and API gateways sit in the network path and provide cross-cutting capabilities like authentication, rate limiting, retries, and telemetry. The confusion comes from the overlap. The distinction comes from the traffic direction.

**API Gateway** — north-south traffic:

```
Internet / Mobile / Web
          |
     [API Gateway]        <-- auth, rate-limit, routing, TLS termination
          |
  Internal Services
```

The gateway is the ingress point. It terminates TLS, validates tokens, enforces rate limits, and routes requests to the right internal service. Products: AWS API Gateway, Kong, Apigee, Envoy (as edge proxy).

**Service Mesh** — east-west traffic:

```
Service A  -->  [sidecar proxy]  -->  [sidecar proxy]  -->  Service B
```

Each service gets a sidecar proxy (Envoy in Istio's case). The mesh handles mTLS between services, retries, circuit breaking, and telemetry without modifying application code. Products: Istio, Linkerd, Consul Connect.

Where they overlap:
- Both can enforce authentication (JWT validation, mTLS)
- Both can emit metrics and traces
- Both can do traffic shaping (retries, timeouts, circuit breakers)

When to choose which:

- **Only an API gateway:** Small service count, external-facing traffic is the main concern, teams don't own the service infrastructure.
- **Only a service mesh:** Services communicate frequently with each other; you need mTLS and observability at the service-to-service level without writing it into every service.
- **Both:** Larger organizations commonly run an API gateway for north-south traffic and a service mesh for east-west traffic. They serve different layers.

> [!info] Running both a service mesh and an API gateway is not redundant — they address different traffic flows. The mistake is using a service mesh as a replacement for a proper API gateway, or vice versa.

@feynman

An API gateway is the front door of your building — it decides who gets in from outside; a service mesh is the internal phone system — it controls how everyone inside talks to each other, securely and reliably.

@card
id: apid-ch12-c006
order: 6
title: Traffic Routing Patterns at the API Edge
teaser: Canary releases, blue-green deployments, and dark launches let you move traffic gradually and safely — the API gateway or service mesh is where these patterns are implemented without changing application code.

@explanation

The API edge (gateway or mesh) is the natural place to implement traffic routing patterns because it can shape traffic without involving application code.

**Canary release:**

```
All traffic
    |
    +-- 95% --> v1 (stable)
    +--  5% --> v2 (canary)
```

A small percentage of real traffic is routed to the new version. If error rates or latency on v2 are acceptable, the percentage shifts gradually until v2 is 100%. If v2 is bad, roll back by setting the weight back to 0.

**Blue-green deployment:**

```
Before:  All traffic --> Blue (v1)     Green (v2, idle)
After:   All traffic --> Green (v2)    Blue (v1, on standby)
```

Two full environments exist simultaneously. Switching is instantaneous — change the routing rule. Rollback is equally instant. The cost is running two full environments during the transition.

**Dark launch (shadow traffic):**

```
All traffic --> v1 (responses returned to client)
            --> v2 (receives copy of requests, responses discarded)
```

v2 processes real traffic but its responses are not returned to clients. Teams use this to validate that a new implementation produces correct results under production load without any user impact.

**Header-based routing:**

Internal or beta testers send a request header (`X-Beta-User: true`) and the gateway routes them to the new version while all other traffic goes to the stable version.

These patterns require a gateway or mesh that supports weighted routing and header matching — features present in Envoy, Kong, AWS API Gateway, and Istio's VirtualService resources.

@feynman

Traffic routing patterns at the API edge are like a controlled road diversion — you can redirect 5% of cars onto a new road to test it under real conditions, while keeping 95% on the known route, and switch the signs in seconds if something goes wrong.

@card
id: apid-ch12-c007
order: 7
title: Public APIs as a Product
teaser: A public API is a product, not a feature — it has a target user (the developer), a discovery mechanism (the portal), and a support contract (the changelog and versioning policy).

@explanation

Organizations that treat their public API as a technical artifact rather than a product invariably produce APIs that nobody uses, or worse, APIs that developers are forced to use but resent.

A public API treated as a product has:

- **A developer portal.** Documentation is the primary UI. It includes reference docs (every endpoint, every field, every error code), getting-started guides, authentication walkthroughs, and runnable examples. Products like Stripe and Twilio are industry benchmarks for developer portals — their documentation is the reason developers choose them.
- **A versioning and deprecation policy.** Developers need to know how long a version will be supported and how far in advance breaking changes will be announced. Six months' notice is a common floor for public APIs at scale.
- **A changelog.** Every release is documented. Developers subscribe to changes. Surprises in an API changelog are a trust failure.
- **SDKs.** Official client libraries in the languages your users work in reduce integration friction dramatically. They also let you abstract away protocol details that would otherwise leak into developer code.
- **A feedback channel.** GitHub issues, a developer forum, or a public roadmap where developers can report bugs and request features.

The platform team that owns the developer portal is often separate from the teams that build the APIs themselves. Their job is to ensure the portal stays accurate, the SDKs stay current, and the developer experience of the whole API surface is coherent — not just the individual endpoints.

> [!tip] Look at Stripe's API documentation and changelog as a reference standard. If your developer portal does not provide equivalent clarity, it is a product problem, not a documentation problem.

@feynman

A public API is a product whose user is a developer — the documentation is the UI, the SDKs are the packaging, and the versioning policy is the support contract, and a developer's first impression of your API is determined entirely by the quality of those three things.

@card
id: apid-ch12-c008
order: 8
title: Partner APIs
teaser: Partner APIs are the middle ground between fully public and fully internal — they are scoped, versioned, and rate-limited, but issued to named organizations rather than anonymous developers.

@explanation

A partner API is OAuth-protected, rate-limited, and versioned like a public API, but access is gated — not available to anyone with a credit card. Organizations apply, agree to terms, and receive credentials scoped to what they are allowed to do.

The defining characteristics:

- **Named consumers.** You know who every caller is. API keys or OAuth client credentials are issued to specific organizations, not to anonymous accounts.
- **Scoped access.** A partner who is allowed to read orders may not be allowed to write them. Scopes at the OAuth level enforce this at the token level rather than relying on documentation.
- **Rate limits differentiated by tier.** A small integration partner and a large enterprise partner have different rate limit tiers negotiated into their contracts.
- **SLA expectations.** Partners often have contractual SLA requirements. This affects how you operate the partner API infrastructure — uptime monitoring, incident communication, and support response times are all different from a public API.
- **Auditability.** Every request is logged with enough context to answer "what did this partner do, and when?" This is both a compliance requirement and a debugging tool.

The design implication: partner APIs often expose a narrower but more stable contract than internal APIs, because changing a partner API means contacting named companies and negotiating migration timelines. That cost is real and should push the design toward fewer, more deliberately chosen endpoints.

@feynman

A partner API is like a wholesale account at a supplier — it is not open to the public, you know every customer by name, the terms are negotiated, and what they are allowed to buy is spelled out in the contract.

@card
id: apid-ch12-c009
order: 9
title: API Marketplaces
teaser: API marketplaces (RapidAPI, AWS Marketplace) let you publish an API as a monetized product to a developer audience that is already looking — trading control for distribution.

@explanation

API marketplaces are platforms where API providers publish their APIs and developers discover and subscribe to them. The marketplace handles billing, API key issuance, usage metering, and rate limiting — the provider delivers the API, and the marketplace delivers the distribution.

The two dominant platforms:

- **RapidAPI** (now Panzura) — a general-purpose marketplace with thousands of APIs. Providers publish OpenAPI specs, set pricing tiers (free, freemium, paid per-call), and RapidAPI handles the developer portal, billing, and API key proxying.
- **AWS Marketplace (API Gateway integration)** — AWS lets you publish APIs through API Gateway as products in AWS Marketplace. Buyers subscribe and are billed through their AWS account, which removes the friction of a separate billing relationship for AWS-native consumers.

When to consider publishing to a marketplace:

- Your API has standalone value beyond your own product (data, utility, AI inference).
- You want distribution without building a developer portal and billing infrastructure.
- Your target users are developers who already browse marketplaces for APIs.

The tradeoffs:

- **Control.** The marketplace proxies your traffic. You are dependent on their uptime and pricing model. If RapidAPI changes terms, you are exposed.
- **Revenue share.** Marketplaces take a percentage. The value must outweigh the cut.
- **Discoverability vs brand.** Developers find you through the marketplace but may never visit your site. This can limit brand building and direct customer relationships.

Marketplaces are most useful for APIs that are genuinely utility-like — weather data, address validation, currency conversion — where distribution is the bottleneck, not differentiation.

@feynman

Publishing to an API marketplace is like selling products on a platform storefront — you reach an existing audience without building a shop, but you pay commission, follow the platform's rules, and share the customer relationship with the marketplace.

@card
id: apid-ch12-c010
order: 10
title: Internal API Discovery
teaser: As the number of internal APIs grows, discovery becomes a first-class problem — without a service catalog, engineers build duplicate APIs or call the wrong version of one that already exists.

@explanation

In small engineering organizations, internal API discovery is a Slack message away. In organizations with dozens of teams and hundreds of services, undocumented internal APIs become shadow infrastructure — parallel implementations grow because teams do not know what already exists.

The tools for internal API discovery:

- **Backstage** (open-source, from Spotify) is the most widely adopted service catalog. Teams register their services in a central catalog with links to API specs, runbooks, ownership, and deployment status. Engineers search the catalog before building something new. API specs are embedded directly (OpenAPI, AsyncAPI, gRPC .proto).
- **API hubs.** Some API gateway products (Kong, AWS API Gateway) include an API hub or developer portal that publishes internal API specs automatically when APIs are deployed to the gateway.
- **Shared spec repositories.** A Git repository containing all internal OpenAPI and AsyncAPI specs, with CI that validates specs on merge and publishes rendered documentation. Lower infrastructure overhead than Backstage, but less structured.

What a good internal catalog provides:

- Searchable index of all APIs with ownership clearly attributed
- Links to API spec, current version, and changelog
- Deprecation status — is this API still active?
- Dependency graph — which services call which APIs
- On-call contact for each API

The failure mode without a catalog: a new team builds a service that already exists, integrates with an API that was deprecated six months ago, or calls a service's internal implementation directly instead of its stable public interface — and nobody finds out until something breaks.

> [!tip] Backstage with a mandatory service registration step in the new-service template is the most effective way to keep the catalog complete — discovery tools only work if engineers actually register their services.

@feynman

An internal API catalog is like a library card catalog — without it, you cannot know what books exist, so you either go looking in person through endless stacks or assume the book you need does not exist and write it yourself.

@card
id: apid-ch12-c011
order: 11
title: Cross-API Consistency
teaser: When dozens of APIs are built by different teams, naming conventions, error shapes, and pagination patterns diverge — and every divergence is a tax on every developer who integrates across more than one.

@explanation

In a large organization with many API-producing teams, consistency across APIs is not automatic. It requires deliberate platform work.

The areas where inconsistency hurts most:

- **Error shapes.** Team A returns `{"error": "not found"}`. Team B returns `{"message": "Resource not found", "code": 404}`. Team C returns an HTML error page. A client that integrates with all three must write three different error parsers. The RFC 7807 Problem Details standard (`application/problem+json`) is the established solution — one error shape across the entire platform.
- **Pagination.** Cursor-based vs. offset-based vs. page-number-based are all reasonable choices, but mixing them forces clients to implement all three. A platform-wide decision — pick one — eliminates this.
- **Naming conventions.** `created_at` vs `createdAt` vs `created_time`. `user_id` vs `userId` vs `user`. camelCase vs snake_case for JSON. Mixing them requires clients to normalize.
- **Versioning strategy.** URL versioning (`/v1/`, `/v2/`) vs header versioning (`API-Version: 2024-01-01`) vs query parameter. All have merits; mixing them across the same platform is confusing.
- **Date formats.** ISO 8601 (`2024-01-15T10:30:00Z`) everywhere, or a mix of Unix timestamps, formatted strings, and relative times.

The mechanism for enforcing consistency is a **platform API style guide** — a document and a linting ruleset that all APIs must pass before deployment. Tools like Spectral (for OpenAPI linting) let you encode the style guide as machine-checkable rules and run them in CI.

A platform team that owns the style guide and enforces it through automated linting is the only scalable way to maintain cross-API consistency without blocking individual teams.

@feynman

Cross-API consistency is like grammar in a language — a single author can break the rules and be understood, but when a hundred different authors write for the same audience with different conventions, readers spend effort decoding style instead of absorbing meaning.

@card
id: apid-ch12-c012
order: 12
title: The Spaghetti API Antipattern
teaser: When services call services call services without discipline, you get chains of synchronous API calls that are slow, fragile, and impossible to reason about — and the way out is harder than the way in.

@explanation

The spaghetti API antipattern emerges gradually. Each service-to-service call seems reasonable in isolation. Service A calls Service B to get user data, Service B calls Service C to validate a permission, Service C calls Service D to fetch a role, Service D calls Service A to get the account context. Nobody designed this topology — it assembled itself.

How to recognize it:

- **Latency that cannot be explained.** A request that should take 50ms takes 800ms. Distributed tracing reveals a chain of 12 sequential internal API calls, each adding 50–100ms.
- **Cascading failures.** Service D goes down. Service C starts failing. Service B starts failing. Service A starts failing. A single service outage ripples through the entire system.
- **Circular dependencies.** Service A depends on Service B which depends on Service A. Deployment ordering becomes impossible. Startup sequencing is fragile.
- **Nobody knows the full call graph.** When a request fails, it is unclear which team owns the failing dependency. The service catalog (if it exists) does not match the actual runtime behavior.

How to escape:

- **Trace first.** Use distributed tracing (Jaeger, Zipkin, AWS X-Ray) to map the actual call graph. You cannot refactor what you cannot see.
- **Identify sync calls that can be async.** Many service-to-service calls are fire-and-forget or can tolerate eventual consistency. Replacing synchronous calls with events eliminates direct coupling.
- **Extract shared data to a canonical source.** When multiple services call a third service just to look up the same reference data (user roles, product catalog), move that data to a shared cache or a read model that each service owns locally.
- **Enforce a fan-out limit.** A composition layer that makes more than N downstream calls is a code smell. Set a platform convention — if a request requires more than five downstream calls, the design needs review.

> [!warning] Distributed tracing is not optional in a multi-service system — without it, the spaghetti API antipattern is invisible until it causes a production incident.

@feynman

The spaghetti API antipattern is like a city that grew without zoning laws — every block looks reasonable by itself, but the overall road network is a tangle where getting from one side to the other requires passing through a dozen intersections, and closing any one road brings traffic to a standstill everywhere.
