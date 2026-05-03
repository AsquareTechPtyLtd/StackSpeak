@chapter
id: apid-ch08-api-gateways-and-edge
order: 8
title: API Gateways and Edge
summary: An API gateway is the single front door for many backend services — and the design choice that decides which gateway, what it does, and what stays in your services determines whether the gateway scales with the architecture or becomes the bottleneck that blocks every change.

@card
id: apid-ch08-c001
order: 1
title: The Gateway as Front Door
teaser: An API gateway is the single entry point for clients — it routes, authenticates, rate-limits, and logs so your backend services don't have to repeat that work, but the moment it starts making business decisions, it becomes the thing that must change every time the business does.

@explanation

Every backend system eventually needs a place to centralize the concerns that every service shares: routing traffic to the right backend, verifying that the caller is allowed, enforcing usage limits, and recording what happened. The API gateway is that place.

What a gateway is responsible for:

- **Routing** — matching an incoming request to the correct upstream service and forwarding it.
- **Authentication and authorization** — validating tokens, terminating mTLS, or checking API keys before traffic reaches a service.
- **Rate limiting** — enforcing per-client, per-IP, or per-endpoint request caps.
- **Observability** — emitting access logs, injecting trace headers, and recording latency metrics.
- **Protocol translation** — translating HTTP/1.1 to HTTP/2, REST to gRPC, or handling WebSocket upgrades.

What a gateway should not do:

- Compute prices, validate business rules, join records from multiple services, or orchestrate service calls. The moment routing logic encodes a business rule ("if the user has a paid plan, route to the premium backend"), that logic is now split between your gateway config and your services — two places to change when the rule changes.

The failure mode is gradual. Teams add one plugin, then another, then a Lua script to handle a special case. The gateway becomes a distributed application in its own right, with undocumented business logic, no unit tests, and a deploy cycle tied to the gateway version.

> [!warning] Treat the gateway as infrastructure, not application code. If a change to the gateway is required every time a product requirement changes, the gateway is doing too much.

@feynman

An API gateway is the front desk of an office building — it checks badges, directs visitors to the right floor, and logs who came in, but it doesn't decide whether you're allowed to close the deal once you get upstairs.

@card
id: apid-ch08-c002
order: 2
title: Reverse Proxy Foundations
teaser: Every API gateway is a reverse proxy at its core — Nginx, Envoy, and HAProxy represent the three architectural families, and understanding their tradeoffs tells you what your gateway is actually built on.

@explanation

A reverse proxy sits in front of backend servers and forwards client requests to them. Clients talk to the proxy; the proxy talks to the backend. The distinction from a forward proxy: the client doesn't configure it, the operator does.

The three foundational systems:

**Nginx** originated as a high-performance static web server and HTTP reverse proxy. It uses an event-driven, non-blocking architecture that handles tens of thousands of concurrent connections on modest hardware. Its configuration language is declarative and expressive, but extending behavior requires Lua (via the `ngx_lua` or `openresty` modules) or recompiling with C modules. Many API gateways — Kong in particular — are built directly on top of Nginx/OpenResty.

**Envoy** was designed at Lyft as a programmable proxy for microservices. Its defining characteristic is dynamic configuration via the xDS API — route tables, cluster definitions, and filter chains can be updated at runtime without restarting. Envoy is written in C++ for performance, but it is configured via YAML or via a management plane that speaks xDS. It is the data plane of Istio, the Ambassador API Gateway, and several others.

**HAProxy** is the canonical high-availability load balancer. It is extremely fast at Layer 4 and Layer 7, excels at connection handling and health checking, and has been the backbone of traffic infrastructure at companies running very high request volumes. Its configuration is ACL-driven and less expressive than Envoy's, but it is battle-tested for raw throughput.

> [!info] If your chosen gateway behaves unexpectedly under load, knowing which proxy it's built on tells you where to look for tuning knobs — connection pool sizes, keepalive settings, and buffer limits all trace back to the underlying proxy.

@feynman

Nginx, Envoy, and HAProxy are the three chassis that most gateways are built on — like choosing between a sedan, a pickup truck, and a van before you add the custom bodywork on top.

@card
id: apid-ch08-c003
order: 3
title: Cloud-Managed Gateways
teaser: AWS API Gateway, Azure API Management, and Google Cloud API Gateway offload operations entirely, but their pricing models, feature sets, and vendor lock-in profiles differ enough that the wrong choice becomes expensive and painful to reverse.

@explanation

Cloud-managed gateways let you skip provisioning, patching, and scaling the gateway itself. The tradeoff is reduced control and tight coupling to a cloud provider's model.

**AWS API Gateway** comes in two flavors: REST API (v1) and HTTP API (v2). HTTP API is cheaper and lower-latency but supports a smaller feature set. REST API supports usage plans, request/response transformations via VTL (Velocity Template Language), and fine-grained resource policies. Both integrate natively with Lambda, IAM, Cognito, and VPC Link for private backends. Pricing is per million API calls plus data transfer. The failure mode: VTL for transformations is difficult to test locally and error messages are notoriously opaque.

**Azure API Management (APIM)** is a full-featured gateway with a portal for developer onboarding, policy-based request transformation using an XML policy language, a developer portal, and built-in monetization tooling. It has consumption tier (pay-per-call), developer, basic, standard, and premium tiers. The premium tier supports multi-region deployment and VNet integration. The failure mode: policy XML is verbose and the debugging experience for policy chains is limited — errors surface at runtime, not at authoring time.

**Google Cloud API Gateway** is the lightest of the three: it fronts Cloud Run, Cloud Functions, and App Engine using an OpenAPI spec as its configuration. It does not have the policy system or developer portal features of APIM. It is the right choice for straightforward routing to Google-managed compute; it is not a replacement for a full-featured gateway.

> [!tip] Run a cost projection at your actual request volume before committing to a cloud-managed gateway. At high volume, AWS API Gateway REST API pricing can easily exceed the cost of running Kong or APISIX on a small cluster.

@feynman

Cloud-managed gateways are a managed appliance you rent — the cloud provider handles the maintenance, but you accept their configuration model, their pricing, and their limits.

@card
id: apid-ch08-c004
order: 4
title: Self-Hosted Gateways
teaser: Kong, Tyk, Apache APISIX, and KrakenD give you full control over configuration, data residency, and plugin behavior — but "full control" means you own the ops burden too.

@explanation

Self-hosted gateways run on your infrastructure, whether that's a VM, a Kubernetes cluster, or bare metal. The appeal is control: you can extend them without asking a vendor, you keep all traffic data on your network, and you're not billed per request.

**Kong** is built on Nginx/OpenResty and is the most widely deployed open-source gateway. Its plugin system is rich — hundreds of plugins cover authentication, rate limiting, logging, transformations, and more. Kong stores its configuration in PostgreSQL (or uses a DB-less declarative mode). Kong Gateway is open source; Kong Konnect and the enterprise tier add a control plane, developer portals, and support. Failure mode: the plugin execution model runs Lua in the Nginx worker, which means a poorly written plugin can affect all traffic, not just the requests it targets.

**Tyk** is written in Go, stores configuration in Redis, and runs without a database dependency in its DB-less mode. Its plugin system supports Go, Python, and JavaScript. Tyk's dashboard and developer portal are enterprise features. Failure mode: the open-source version's configuration management tooling is less mature than Kong's.

**Apache APISIX** is also built on Nginx/OpenResty but uses etcd for its configuration store, enabling real-time config propagation across a cluster without restarts. Its plugin runner supports multiple languages via gRPC sidecars. Failure mode: etcd adds an operational dependency that must be maintained and backed up alongside APISIX itself.

**KrakenD** takes a different approach — it is a stateless, declarative gateway with no database, no admin API at runtime, and no plugins that execute arbitrary code. Configuration is a JSON file baked in at deploy time. This makes it extremely fast and operationally simple, but the lack of dynamic configuration means any routing change requires a redeploy.

> [!warning] Self-hosted gateways require you to handle upgrades, scaling, high availability, and certificate rotation. Budget for ops time before choosing self-hosted over managed.

@feynman

Choosing a self-hosted gateway is like buying a car instead of renting one — you get exactly what you want and you keep all the miles, but you also handle every oil change and tire rotation yourself.

@card
id: apid-ch08-c005
order: 5
title: Service Mesh at the Edge
teaser: Istio, Linkerd's edge gateway, and Consul Connect extend the service mesh to the cluster boundary — when the mesh already manages east-west traffic, using it for north-south entry too removes a separate gateway to operate, but the configuration model is more complex than a standalone gateway.

@explanation

Service meshes (Istio, Linkerd, Consul) manage traffic between services inside a cluster using sidecar proxies or eBPF-based interception. Most meshes also expose an ingress or edge gateway component that handles traffic entering the cluster from outside.

**Istio's Gateway** uses an Envoy proxy deployed at the cluster edge, configured via `Gateway` and `VirtualService` custom resources. Because the edge gateway is the same Envoy data plane as the in-mesh sidecars, all of Istio's traffic management capabilities — traffic splitting, fault injection, retries, timeouts, mTLS — apply identically at the edge and within the mesh. The failure mode is complexity: Istio's CRD-based configuration model has significant cognitive overhead, and misconfigurations at the Gateway level are harder to debug than a dedicated gateway's simpler routing rules.

**Linkerd** focuses on simplicity. Its edge solution uses an independent ingress controller (typically Nginx, Traefik, or Envoy-based) in front of the mesh, with the ingress proxy meshed like any other workload. Linkerd does not run a custom edge gateway — the value is in the mTLS, metrics, and reliability features applied to the traffic as it flows through the mesh, not at the entry point.

**Consul API Gateway** is HashiCorp's Kubernetes-native ingress layer for Consul Service Mesh. It integrates with Consul's service catalog and intent-based networking, making it useful in environments already operating HashiCorp infrastructure (Vault, Terraform, Nomad).

The key question when evaluating mesh-based gateways: does your team already operate a mesh? If yes, using the mesh's edge component removes a separate operational dependency. If no, adopting a full mesh solely to get edge routing is a steep cost for a modest benefit.

> [!info] Service mesh gateways shine when you need consistent policy (mTLS, observability, retries) applied uniformly from edge to service. For simple routing-only use cases, a standalone gateway has a far lower operational cost.

@feynman

Using the service mesh at the edge is like extending the security badge system from the building's interior hallways all the way out to the front door — you get consistent enforcement everywhere, but someone has to maintain the badge system for the whole building.

@card
id: apid-ch08-c006
order: 6
title: The Do-Too-Much Gateway Antipattern
teaser: When business logic migrates into gateway plugins — transformation scripts that join records, routing rules that encode product tiers, Lua functions that call downstream services — the gateway becomes the hardest part of the system to change, test, and reason about.

@explanation

The antipattern accumulates gradually. It starts with a simple plugin: strip a header before forwarding to the backend. Then: translate a legacy field name so old clients still work. Then: call an internal auth service to look up a user's subscription tier and inject a header the backend reads. Then: aggregate two service responses into one to save the mobile client a round trip.

At that point, the gateway is running business logic. The problems this creates:

- **Testability.** Gateway plugin code (Lua, Golang plugins, Kong's PDK scripts) runs inside the gateway process and is difficult to unit test in isolation. Debugging requires replicating the full gateway environment.
- **Deployment coupling.** A product requirement change — a new pricing tier, a renamed field — now requires a gateway deploy in addition to a service deploy. The two must be coordinated, or the gateway and service are briefly out of sync.
- **Ownership ambiguity.** Backend teams own service code. Platform teams own the gateway. Logic spread across both creates a no-man's land: neither team fully understands the end-to-end behavior of a single request.
- **Failure cascades.** A plugin that calls a downstream service to make a routing decision introduces a new failure mode: the downstream service is slow, the gateway queues, and now all routes are degraded — not just the one that needed the downstream call.

The test for whether logic belongs in the gateway: could you remove the logic from the gateway and add it to the upstream service without changing any external client behavior? If yes, it belongs in the service.

> [!warning] Gateway plugins that call other services are the most dangerous form of the antipattern. A routing decision that depends on a live service call means your gateway's availability is now bounded by that service's availability.

@feynman

The do-too-much gateway is like a building receptionist who, instead of directing visitors, has been gradually given the authority to approve contracts, negotiate prices, and hire staff — the receptionist is now the bottleneck for everything.

@card
id: apid-ch08-c007
order: 7
title: Routing Patterns
teaser: Host-based, path-based, and header-based routing are the three primitives every gateway supports — and composing them correctly is what determines whether your traffic management stays readable or turns into a debugging puzzle.

@explanation

Routing is the gateway's primary job: receive a request, match it against a set of rules, and forward it to the correct upstream.

**Host-based routing** matches on the `Host` header or SNI name. One gateway instance can serve multiple domains or subdomains and route each to a different backend:

```yaml
routes:
  - host: api.example.com
    upstream: api-service
  - host: admin.example.com
    upstream: admin-service
```

**Path-based routing** matches on the URL path prefix or exact path. This is the most common pattern for monolith-to-microservices decomposition — one domain, many services:

```yaml
routes:
  - path_prefix: /users
    upstream: user-service
  - path_prefix: /orders
    upstream: order-service
  - path_prefix: /products
    upstream: product-service
```

**Header-based routing** matches on arbitrary request headers. It is the mechanism for canary deployments, A/B testing, and internal traffic routing:

```yaml
routes:
  - header:
      name: X-Canary
      value: "true"
    upstream: order-service-canary
  - path_prefix: /orders
    upstream: order-service-stable
```

**Combining patterns:** Most gateways evaluate rules in priority order. A request to `/orders` with `X-Canary: true` should hit the canary backend; without the header it hits the stable backend. The order of rule evaluation matters — a catch-all path rule placed before a more specific header rule will absorb the traffic before the header rule is checked.

The failure mode: rule ordering is implicit in many gateway configurations. Adding a new route without understanding the evaluation order causes traffic to match the wrong upstream silently — requests succeed but go to the wrong backend.

> [!tip] Express routing rules in order from most specific to least specific, and make evaluation order explicit in your configuration comments. Silent misrouting is harder to detect than an outright failure.

@feynman

Gateway routing patterns are like a postal sorting system — first sort by city, then by street, then by house number, and the order of those sorting steps determines which package lands where.

@card
id: apid-ch08-c008
order: 8
title: Request and Response Transformation
teaser: Gateways can rewrite headers, reshape payloads, and translate protocols before traffic reaches a service — but each transformation the gateway owns is a behavior that lives outside your service tests and outside your service's deployment lifecycle.

@explanation

Transformation at the gateway falls into two categories: header manipulation and body manipulation. They have very different cost/benefit profiles.

**Header manipulation** is cheap and appropriate at the gateway:

```text
# Strip internal headers before forwarding to upstream
remove request header: X-Internal-Debug
# Inject caller identity after token validation
add request header: X-User-ID = ${jwt.sub}
# Add CORS headers on response
add response header: Access-Control-Allow-Origin = https://app.example.com
```

Header manipulation is stateless, fast, and doesn't require the gateway to parse the request body. It is the right level for cross-cutting concerns like injecting trace IDs or enforcing security headers.

**Body transformation** is where the cost rises sharply. Rewriting a JSON payload requires the gateway to buffer the full request body, parse it, apply the transformation, and re-serialize it before forwarding. For large payloads, this destroys streaming behavior and increases memory pressure on the gateway process.

Use body transformation at the gateway sparingly, and only for stable, long-lived compatibility requirements:

- Translating a legacy XML response to JSON for clients that can't be updated
- Normalizing a field name that differs between two API versions during a migration window

Avoid body transformation for:

- Business logic (computing derived fields, filtering results by business rules)
- Anything that requires data from another service to complete
- Transformations that change frequently as product requirements evolve

The rule of thumb: if the transformation would require a unit test to verify correctness, it belongs in a service, not the gateway.

> [!warning] Body transformation disables streaming. A gateway that buffers and rewrites large response bodies to add a field will have noticeably worse latency and memory usage at scale than a service that returns the field directly.

@feynman

Rewriting headers at the gateway is like relabeling a package at the post office — quick, cheap, and appropriate; rewriting the contents of the package is a different operation entirely and needs a different kind of facility.

@card
id: apid-ch08-c009
order: 9
title: Auth Offloading at the Gateway
teaser: Validating bearer tokens and terminating mTLS at the gateway means every backend service gets a verified identity handed to it — but the gateway must pass that identity downstream faithfully, and the backend must trust only gateway-injected identity headers, not client-supplied ones.

@explanation

Auth offloading means the gateway takes responsibility for verifying that the caller is who they claim to be, so individual services don't each need to implement token validation libraries.

**Bearer token validation** (JWT or opaque tokens): The gateway validates the token signature or calls a token introspection endpoint, extracts claims, and injects them as headers before forwarding:

```text
Authorization: Bearer <jwt>
  -> gateway validates signature, checks exp, extracts sub and roles
  -> injects X-User-ID: u_12345
  -> injects X-User-Roles: admin,reader
  -> forwards request without Authorization header (or with it, depending on policy)
```

**mTLS termination**: The gateway presents a certificate to the client and requires the client to present one in return. After verification, the gateway may forward the client's certificate fingerprint or subject as a header to the upstream:

```text
X-Client-Cert-Subject: CN=service-account-billing,O=internal
```

**Critical security invariant**: Upstream services must reject any request where identity headers (`X-User-ID`, `X-User-Roles`, `X-Client-Cert-Subject`) were supplied directly by the client, not injected by the gateway. The standard approach is to strip those headers from the incoming request at the gateway before injecting the verified values — so even if a client crafts a request with `X-User-ID: admin`, the gateway replaces it with the correct value from the validated token.

> [!warning] If backend services accept client-supplied identity headers without verification that the request transited the gateway, auth offloading is security theater. Enforce that only the gateway network path can reach backend services.

@feynman

Auth offloading is like a building security desk that checks IDs at the entrance and issues a verified visitor badge — but that system only works if every room inside checks the badge and refuses entry to anyone who walked in through a side door.

@card
id: apid-ch08-c010
order: 10
title: Rate Limiting at Edge vs In-Service
teaser: Rate limiting at the gateway is easier to operate but harder to make accurate — because distributed gateways need distributed counters, and distributed counters have consistency/latency tradeoffs that in-service rate limiting doesn't face.

@explanation

Rate limiting enforces a cap on how many requests a client can make in a time window. The decision of where to enforce it — at the gateway or inside each service — has real operational consequences.

**Gateway-level rate limiting** enforces limits before requests reach any backend. It protects all services with a single configuration and doesn't require each service team to implement it. It is the right default for API key-based quotas and abuse prevention.

The complication: most production deployments run multiple gateway instances. Rate limit counters must be shared across all instances, or a client that is hitting its limit on instance A can simply send the next request to instance B.

Shared counter options:

```text
Local (per-instance): Fast, no coordination overhead.
  Risk: a client gets N * (per-instance limit) effective quota.

Redis (distributed, single-node): Accurate within one region.
  Risk: Redis becomes a latency-adding dependency on the hot path.

Redis Cluster / sliding window: Accurate, handles failover.
  Risk: adds ~1–2ms per request for the counter roundtrip.
```

**In-service rate limiting** runs inside the service itself, making it accurate by definition — one counter, one process. The cost is that every service must implement it, and it consumes service resources for requests that should have been blocked upstream.

The pragmatic pattern: coarse-grained rate limits at the gateway (blocking obvious abuse), fine-grained limits inside services (protecting specific endpoints or operations). The gateway doesn't need millisecond accuracy; a small window of over-quota requests reaching the backend is acceptable if the service has its own limits as a backstop.

> [!info] Sliding window algorithms (as opposed to fixed windows) eliminate the burst-at-window-boundary problem, where a client can make 2x the limit by timing requests to straddle a window reset. Redis modules like `redis-cell` implement sliding windows directly.

@feynman

Rate limiting at a distributed gateway is like having security guards at multiple entrances — each guard can count people going through their door, but knowing the total requires them to communicate, and that communication takes time.

@card
id: apid-ch08-c011
order: 11
title: Caching at the Gateway
teaser: A gateway cache can eliminate redundant backend calls for read-heavy, cacheable responses — but caching at the wrong layer, on the wrong content, or without a clear invalidation strategy turns a performance win into a correctness bug.

@explanation

Gateway-level caching stores responses and serves them to subsequent identical requests without hitting the backend. The performance benefit is clear: a cached response is delivered in microseconds instead of the milliseconds of a backend round trip.

What is safe to cache at the gateway:

- **Responses that are identical for all callers** — public catalog data, reference data, responses to unauthenticated requests.
- **Responses with stable cache keys** — requests where the full cache key can be formed from URL + method + a small set of stable headers.
- **Responses with short-enough TTLs** — stale data is only acceptable within defined windows.

What is not safe to cache at the gateway:

- **User-specific responses** — if the response contains data derived from the caller's identity, the cache key must include the identity. Getting this wrong serves one user's data to another.
- **Non-idempotent responses** — POST, PUT, DELETE responses should not be cached.
- **Responses to requests with `Authorization` headers by default** — most gateway caches are correctly configured to not cache these, but verify your gateway's defaults.

Cache invalidation at the gateway is limited. Unlike an application cache that can react to writes, a gateway cache operates on HTTP semantics: `Cache-Control` headers, `Vary` headers, and TTLs. If the backend updates a resource and you need the cache cleared immediately, you need either an explicit purge API on the gateway or a very short TTL.

> [!warning] User-specific data in a shared cache is the most dangerous caching mistake. Always verify that your gateway's cache key includes the caller identity for authenticated endpoints, or disable caching for those routes entirely.

@feynman

Gateway caching is like stocking a lobby vending machine with the most popular items — it works well for things everyone orders the same way, but it breaks down the moment each customer needs something personalized.

@card
id: apid-ch08-c012
order: 12
title: Observability at the Gateway
teaser: The gateway sees every request across all services, making it the highest-leverage point to generate request IDs, propagate trace context, and emit structured access logs — but only if those signals are configured to flow through to where they're actually consumed.

@explanation

Because the gateway is the entry point for all external traffic, it can attach observability signals to every request before any backend code runs.

**Request IDs:** The gateway should generate a unique request ID for every inbound request that lacks one, attach it as a header (commonly `X-Request-ID` or `X-Trace-ID`), and log it alongside every access log entry. Backend services propagate this header through all downstream calls. When an error surfaces in logs, searching by request ID recovers the full chain of events across all services.

```text
# Gateway behavior on inbound request:
if X-Request-ID absent:
    X-Request-ID = generate_uuid()
forward with X-Request-ID header
log: {request_id, method, path, status, latency_ms, upstream}
```

**Distributed tracing propagation:** The gateway should inject or propagate W3C TraceContext headers (`traceparent`, `tracestate`) or B3 headers (`X-B3-TraceId`, `X-B3-SpanId`) depending on your tracing backend (Jaeger, Zipkin, Tempo, AWS X-Ray). The gateway creates the root span; services create child spans. Without propagation at the gateway, distributed traces are broken at the first hop.

**Structured access logs:** Gateway logs should be structured JSON, not CLF-format strings. Fields should include: timestamp, method, path, status, upstream service name, request latency, upstream latency, client IP (or anonymized version), and the request ID. Structured logs are directly queryable in tools like CloudWatch Insights, Loki, or Splunk without a parsing layer.

**Gateway-level metrics:** Counters and histograms emitted per route (not just per gateway instance) give you service-level views: request rate, error rate, and latency broken down by upstream. These are the signals your SLOs are measured against.

> [!tip] Emit a distinct metric label per upstream service, not just per gateway route. A single route can proxy to multiple upstreams (canary splits, fallbacks), and you need per-upstream visibility to detect when one upstream is degraded.

@feynman

Observability at the gateway is like having a clerk at the front desk who writes every visitor's name and timestamp in a logbook and hands them a numbered visitor badge — every interaction inside the building can reference that badge number to reconstruct the full visit.
