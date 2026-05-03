@chapter
id: apid-ch01-api-design-as-architecture
order: 1
title: API Design as Architecture
summary: Every API decision is an architectural decision — what you expose, how you version it, how you evolve it — and the cost of getting these wrong is paid for the lifetime of every consumer the API ever has.

@card
id: apid-ch01-c001
order: 1
title: APIs Are Long-Lived Contracts
teaser: An API is not a feature you ship and iterate on — it is a contract you sign with every caller, and breaking it costs everyone except you.

@explanation

When Stripe published its first API in 2011, engineers at thousands of companies wrote code against it. That code is still running today. Stripe has added hundreds of endpoints since then, but the core charge object, the field names, the error format — those have remained stable, because changing them would break software that Stripe's engineers have never read and cannot reach.

That is what makes API design architectural: the decision lives outside your codebase. When you ship a buggy UI, you fix it and users see the update. When you ship a breaking API change, you break clients that are deployed in production, in mobile apps waiting for users to update, in batch jobs that run at 2 a.m. in systems you don't control.

The asymmetry matters:

- The API designer spends a week rethinking a resource structure.
- Fifty downstream teams each spend a day updating their integrations.
- The total cost to the ecosystem is fifty times the cost to the designer.

This is why architectural thinking is the right frame. You are not just designing software for yourself — you are making decisions that constrain every system that integrates with yours, for as long as either system exists. The same rigor you would apply to a database schema, a message format, or a network protocol belongs here.

> [!warning] Every public endpoint you ship is a commitment. Treat the decision to add a new field or endpoint with the same seriousness you would treat a schema migration on a production database.

@feynman

An API is like the electrical outlet standard a country adopts — once millions of devices are built around it, changing the shape of the socket means every device ever made is suddenly incompatible.

@card
id: apid-ch01-c002
order: 2
title: Contract-First Design
teaser: Write the API specification before you write any implementation code — the spec is the design document, and the conversation it forces is the most valuable part of the process.

@explanation

Contract-first design means you specify the API — its resources, request shapes, response shapes, status codes, and error formats — before any server code exists. The specification itself becomes the primary artifact of API design, not the implementation.

The practical workflow:

- Write an OpenAPI 3.1 document (for HTTP/REST APIs) or an AsyncAPI 3.x document (for event-driven APIs) describing what callers will send and receive.
- Review the spec with the teams that will consume the API. They will immediately identify missing fields, wrong naming, and incorrect assumptions about how they will actually use the endpoint.
- Generate mock servers from the spec so consumer teams can build against it while you implement.
- Generate server stubs, documentation, and client SDKs from the same spec. The spec becomes the source of truth for all of these.

GitHub and Twilio both publish their APIs as OpenAPI documents. The spec is the contract, the documentation, and the test oracle simultaneously.

The failure mode of implementation-first design is that the API reflects your internal data model rather than your callers' mental model. You end up with endpoints like `/getUserAccountDetailsAndPreferences` that return a 300-field object because that is what your service already has, not because any caller needs all of it.

> [!tip] Spec-first forces the most valuable conversation — what does the caller actually need? — before any implementation work is done and before any refactoring becomes expensive.

@feynman

Writing the API spec before the implementation is like drawing the floor plan before breaking ground — it is far cheaper to move a wall on paper than to knock it down after the building is framed.

@card
id: apid-ch01-c003
order: 3
title: The API as Product
teaser: Your API has users, and those users deserve the same product thinking — documentation, versioning, deprecation notices, migration guides — as any user-facing feature.

@explanation

The teams calling your API are your users. They have onboarding friction, confusion points, and frustration when things change unexpectedly. Treating the API as a product means treating those concerns as real product concerns.

What product thinking looks like in practice:

- **Documentation is a product feature.** Stripe's documentation is widely cited as a competitive advantage. It includes working code examples in every major language, a clear changelog, and migration guides for every breaking change. Twilio's documentation does the same. Poor documentation is a product defect.
- **Versioning is a product promise.** A version number is a commitment that the behavior within that version will not change in breaking ways. Stripe uses date-based versioning (`2023-10-16`); GitHub uses URI versioning (`/v3/`). The specific scheme matters less than the discipline of honoring the promise.
- **Deprecation is a product process.** When you deprecate an endpoint or a field, you owe callers: a sunset date, a migration path, and enough lead time to act on it. AWS famously maintains backward compatibility for decades. The SQS API from 2006 still works today.
- **Error messages are UX.** An error that says `{"error": "invalid_param"}` leaves the caller guessing. An error that says `{"error": "invalid_param", "field": "amount", "message": "amount must be a positive integer in the smallest currency unit (cents)"}` is documentation.

> [!info] When you design the error format, imagine a developer at 11 p.m. debugging a production incident using only the error response. That is your user. Design for them.

@feynman

An API without good documentation and a deprecation policy is like a public transit system with no schedules posted — technically it runs, but users can't rely on it.

@card
id: apid-ch01-c004
order: 4
title: Internal vs External APIs
teaser: Internal APIs can be changed by coordinating with your own teams; external APIs have consumers you cannot call — and that difference changes almost every design decision.

@explanation

The distinction is not about where the API lives on the network. An internal API is one where you can reach every consumer and coordinate changes with them. An external API is one where you cannot — either because consumers are third-party developers, because clients are mobile apps you cannot force-update, or because your company is large enough that coordinating every team is effectively impossible.

What changes between the two:

- **Backward compatibility obligation.** Internal APIs can use coordinated deploys and change with all consumers in lockstep. External APIs must treat every released version as permanent until explicitly sunset.
- **Tolerance for rough edges.** An internal API can be pragmatic and imperfect if the two teams involved understand the constraints. An external API must be designed for a developer who has never spoken to you and never will.
- **Surface area discipline.** Internal APIs can expose more — you are both the designer and the consumer, so you can add internal fields that you later remove. External APIs should expose the minimum necessary. Every field you publish externally is one you must support forever.
- **Security model.** External APIs need explicit authentication and authorization design from the start. Internal service-to-service APIs in a trusted network sometimes get away with less rigor — until they don't.

What stays the same: good naming, consistent error handling, and clear semantics matter regardless of audience.

> [!tip] If your company is growing, assume any internal API will eventually be called by a team you have never met. Design it with that future in mind from day one.

@feynman

An internal API is like a verbal agreement between colleagues who sit ten feet apart; an external API is a written contract with strangers — the standards for clarity and change management are not the same.

@card
id: apid-ch01-c005
order: 5
title: The Cost of Breaking Changes
teaser: A breaking change is cheap for you and expensive for your callers — understanding this asymmetry is the first step to taking API stability seriously.

@explanation

A breaking change is any modification that causes a previously valid request to behave differently or fail. The most common categories:

- Removing a field from a response
- Renaming a field
- Changing a field's type (string to integer)
- Changing the semantics of a field (a boolean that meant one thing now means something subtly different)
- Removing an endpoint
- Changing required vs optional for a request parameter

The asymmetry: when you decide to rename `user_id` to `userId` for consistency, it takes your team an afternoon. But every team that calls your API must now find every place they read that field, update the code, test it, and deploy it. If you have 20 consumer teams, the total engineering cost is roughly 20x your own. If consumers are external developers — GitHub has millions — the math is worse.

This is not hypothetical. The Twitter API v2 migration, the Google Maps Platform pricing change in 2018, the Mailchimp API deprecation cycles — each generated widespread engineering pain across the ecosystem.

The discipline this demands: treat field removal and renaming as you would treat dropping a production database column. It may be correct eventually. The question is always: is it worth the cost to every team that calls this?

> [!warning] Renaming a field for consistency is almost never worth the ecosystem cost. Add an alias, document the preferred name, and deprecate the old one over a long timeline — do not rename and break.

@feynman

A breaking API change is like a city that renumbers all its streets overnight — the city planners save time, but every business that printed its address on a sign or a business card pays the cost.

@card
id: apid-ch01-c006
order: 6
title: Evolution Over Revolution
teaser: Additive changes are almost always safe; breaking changes are almost always avoidable — learning to evolve an API without breaking it is a core API design skill.

@explanation

Most breaking changes can be replaced with additive changes that achieve the same goal over a longer timeline.

The patterns:

- **Add, don't rename.** If `first_name` is the wrong field name, add `given_name` alongside it. Document `first_name` as deprecated. Remove it in a future major version, after a long sunset window.
- **Add, don't remove.** If an endpoint is being replaced, add the new one. Keep the old one running. Give consumers time to migrate.
- **Make response fields optional before removing them.** Before you remove a field entirely, document it as deprecated and stop guaranteeing its presence. This allows consumer code to handle both cases before the field disappears.
- **Expand types, never contract them.** Changing a field from string to an enum of valid strings is a breaking contraction — existing callers may be sending values not in the new enum. Adding new allowed values to an existing enum is safe.
- **Version at the right granularity.** Stripe versions at the account level — each API key is pinned to a version, and you opt in to upgrades. This gives consumers control without requiring a simultaneous fleet-wide migration.

The RFC 2119 principle applies here: if a change can be made backward-compatible, it should be.

> [!info] Stripe maintains backward compatibility per API key version, which means a developer who built an integration in 2015 can still run it unmodified. That is the target standard for a mature external API.

@feynman

Evolving an API without breaking it is like renovating a building while tenants are still living in it — you add the new wing before you demolish the old one, not the other way around.

@card
id: apid-ch01-c007
order: 7
title: Consumer-Driven Contract Design
teaser: Your API exists to serve its callers, not to mirror your internal implementation — designing from the consumer's perspective produces fundamentally different APIs than designing from the inside out.

@explanation

Consumer-driven contract design starts from a specific question: what does the caller actually need to accomplish their task? Not: what data do I have? Not: how is my database structured?

The failure mode of inside-out design is visible everywhere. An API that returns a 200-field user object because the database has 200 columns. An API that requires callers to make three requests to get the data they need for one screen because the service is structured around internal bounded contexts. An API that uses internal jargon — field names that make sense to the team that built the service but not to any external developer.

Consumer-driven design inverts this:

- Start with the consumer's use case. What task are they performing? What data do they need to display, and what fields are actually required?
- Design the request and response shapes around that use case. Derive the internal implementation from the external contract, not the reverse.
- Test the contract from the consumer side. Consumer-driven contract testing (tools like Pact) lets consumer teams define the requests they will make and the responses they require, and verifies that the provider satisfies them — independent of implementation details.

The GitHub REST API is a good example of consumer-oriented design: responses include hypermedia links (`url` fields) to related resources, documentation links, and human-readable identifiers alongside machine IDs, because callers commonly need all of these.

> [!tip] Before finalizing any endpoint design, write the client code that will call it. If the client code feels awkward or requires multiple requests to do something logically atomic, the API design is wrong.

@feynman

Designing an API from the inside out is like writing a menu that lists your ingredients and letting customers figure out the dishes — design the dish first, then source the ingredients.

@card
id: apid-ch01-c008
order: 8
title: Designing for Cardinality
teaser: Five callers and five million callers need different APIs — scale changes which decisions are cheap, which decisions are dangerous, and which abstractions you can afford.

@explanation

Cardinality — the number of callers and the volume of requests — changes the design problem in non-obvious ways.

At low cardinality (internal service-to-service, a handful of partner integrations):

- You can use verbose payloads; bandwidth is not a concern.
- You can use chatty APIs (multiple round trips per operation); the overhead is negligible.
- You can change behavior by coordinating with every team that calls you.
- Flexibility and convenience are higher priorities than efficiency.

At high cardinality (public API, mobile clients, millions of requests per second):

- Payload size becomes a cost and latency driver. Slack's Event API uses compact payloads and pushes enrichment responsibility to callers. Stripe returns minimal objects with links to expand related resources.
- Chatty APIs become a reliability risk. N+1 patterns at scale cause cascading load.
- Caching assumptions become load-bearing design decisions. Cache-control headers, ETags, and conditional requests matter.
- You cannot coordinate changes with every consumer. Backward compatibility becomes a hard constraint, not a goal.

The mistake is designing for current cardinality and having to rewrite for actual cardinality. AWS S3's API was designed for high cardinality from the start — it is why the API has been stable for nearly two decades.

> [!info] If you expect your API to grow significantly in callers or request volume, design for the future cardinality from the beginning. The API contract is the hardest thing to change after the fact.

@feynman

Designing an API for five callers is like planning a neighborhood road; designing for five million is like planning a highway interchange — the stakes of getting the structure wrong are not the same.

@card
id: apid-ch01-c009
order: 9
title: API Surface Area
teaser: Every endpoint and every field you publish is a permanent commitment — the discipline of keeping surface area small is the discipline of keeping future options open.

@explanation

API surface area is the total set of things callers can depend on: endpoints, fields, parameters, headers, status codes, error codes, and behavioral guarantees. Every element of surface area is a commitment you are making to every current and future caller.

The principle is simple: publish only what callers actually need. The corollary is equally important: every element of surface area you do not publish is something you can still change.

The patterns that expand surface area unnecessarily:

- Returning full internal objects in API responses, including fields that callers will never use but will come to depend on.
- Publishing convenience endpoints that duplicate the capability of existing endpoints, creating two surfaces to maintain.
- Leaking internal identifiers, database IDs, and implementation details into public responses — callers will build logic around these, and you lose the ability to change your internal model.

The patterns that keep surface area minimal:

- Return only the fields callers have documented use cases for. Add more as use cases emerge.
- Prefer fewer, more general endpoints over many specific ones. GitHub's GraphQL API lets callers specify exactly which fields they want; the surface area is defined by the schema, not by a proliferating list of REST endpoints.
- Use opaque identifiers (Stripe's `cus_xxxxx` format) rather than numeric database IDs. This decouples your internal model from the external contract.

> [!warning] Fields are easier to add than to remove. Ship the minimum viable response shape, then expand it based on real consumer requests — not based on what you think callers might eventually want.

@feynman

API surface area is like code — the less you have to maintain, the fewer places something can break.

@card
id: apid-ch01-c010
order: 10
title: API Smells
teaser: Certain endpoint patterns reliably signal that an API was designed inside-out, without thinking about callers — learning to recognize them is the first step to avoiding them.

@explanation

"API smells" are patterns that indicate structural problems in an API design, analogous to code smells in software engineering. They do not always mean the API is broken, but they reliably indicate that design thinking was missing.

The most common ones:

- **Endpoints that map directly to database tables.** `/api/user_account_records` or `/api/product_inventory_items` betrays that the API was generated from a schema dump. The API surface mirrors internal storage, not caller use cases.
- **Verbs in resource names.** REST resources should be nouns: `/orders`, `/payments`, `/subscriptions`. Endpoints like `/getOrder`, `/createPayment`, `/cancelSubscription` suggest RPC thinking applied to an HTTP API — neither fully REST nor fully RPC, and harder to reason about than either done cleanly.
- **Deeply nested URLs.** `/api/v1/organizations/{org_id}/departments/{dept_id}/employees/{emp_id}/timesheets/{sheet_id}/entries` requires callers to know the full hierarchical path to every resource. A flat structure with query filters is almost always easier to consume.
- **Inconsistent casing and naming.** Some endpoints use `camelCase`, others `snake_case`. Some use `id`, others use `uuid`, others use `identifier`. Inconsistency is a signal that the API grew without a design authority.
- **Boolean proliferation.** A response with twenty boolean flags (`is_active`, `is_verified`, `is_suspended`, `is_trial`, `is_enterprise`...) usually means a state machine should have been modeled explicitly, with a single `status` field and a well-documented set of valid values.

> [!tip] Review every new endpoint against this list before publishing it. The smells are easiest to fix at design time — they are very hard to fix after callers have built against them.

@feynman

API smells are like grammatical errors in a legal contract — individually small, but collectively a signal that the document was not written with the reader in mind.

@card
id: apid-ch01-c011
order: 11
title: Specification Languages
teaser: OpenAPI, AsyncAPI, Protocol Buffers, and GraphQL SDL each describe a different kind of API contract — choosing the right one is itself an architectural decision.

@explanation

Specification languages are the tools you use to write the API contract before writing the implementation. Each is designed for a different interaction model.

**OpenAPI 3.1** — The standard for HTTP/REST APIs. Describes endpoints, request/response schemas, authentication schemes, and error formats in YAML or JSON. Supported by a large ecosystem of tooling: mock servers (Prism), documentation generators (Redoc, Swagger UI), code generators, and contract testing tools. GitHub, Stripe, Twilio, and most major public REST APIs publish OpenAPI specs.

**AsyncAPI 3.x** — The equivalent for event-driven and message-based APIs: Kafka topics, MQTT streams, WebSocket protocols, webhooks. Models channels, messages, and publish/subscribe patterns. Useful when your "API" is a stream of events rather than a request/response pair. Slack's event webhooks and AWS EventBridge schemas are examples of this style.

**Protocol Buffers (protobuf) + gRPC** — A binary serialization format paired with an RPC framework. The `.proto` file is the specification. Code-generates type-safe clients and servers in most languages. Preferred for internal service-to-service communication where performance and strict typing matter more than human-readability. Google internal APIs, Kubernetes, and etcd use gRPC.

**GraphQL SDL** — The schema definition language for GraphQL. Describes types, queries, mutations, and subscriptions. The spec is the schema; clients query exactly the fields they need. GitHub's v4 API and Shopify's Storefront API are prominent examples.

The decision between them maps to your interaction model: request/response HTTP (OpenAPI), events (AsyncAPI), high-performance RPC (protobuf/gRPC), or flexible graph queries (GraphQL SDL).

> [!info] You do not have to choose one format for your entire organization. Stripe uses OpenAPI for its public REST API and Protocol Buffers for internal service communication — the format should fit the use case.

@feynman

Choosing a specification language is like choosing a contract template — you want one written for your kind of agreement, not a residential lease when you are signing a commercial lease.

@card
id: apid-ch01-c012
order: 12
title: The Four API Styles
teaser: REST, RPC/gRPC, GraphQL, and event-driven are not competing answers to the same question — they are answers to different questions about how callers and systems interact.

@explanation

Each API style maps to a different interaction model. Choosing between them is an architectural decision, not a technology preference.

**REST** — Resources and representations. The interaction model is: callers manipulate named resources via a small set of standard verbs (GET, POST, PUT, PATCH, DELETE). The contract is stable and human-readable. Caching, statelessness, and uniform interfaces make REST APIs easy to scale and easy to integrate with. Stripe, GitHub, Twilio, and AWS all use REST for their primary public APIs. Best for: public APIs, CRUD-heavy domains, any context where a broad consumer audience needs simple discoverability.

**RPC / gRPC** — Procedure calls over the network. The interaction model is: callers invoke named operations with typed parameters and receive typed responses. Protocol Buffers provide schema enforcement and code generation. Binary encoding is compact and fast. Best for: internal service-to-service communication, latency-sensitive systems, streaming data transfer (gRPC supports bidirectional streaming).

**GraphQL** — A query language for APIs. The interaction model is: callers specify exactly what fields they need in a single query, across multiple related types. No over-fetching or under-fetching. The schema is the contract. Best for: APIs with diverse clients that need different subsets of data (mobile vs web vs third-party), domains with complex relationships between entities.

**Event-driven** — Asynchronous messages on a bus or stream. The interaction model is: producers emit events; consumers subscribe to what they care about. No direct coupling between producer and consumer. Best for: workflows that span multiple services, audit trails, real-time feeds, cases where the producer should not wait for the consumer.

The chapters that follow cover each of these in depth.

> [!info] Many production systems use more than one style. AWS exposes a REST API for configuration, publishes events via EventBridge, and uses gRPC internally between services. The styles complement each other.

@feynman

The four API styles are like the four modes of transportation — car, train, plane, and boat — each designed for a different combination of distance, speed, cargo, and terrain, and none of them universally better than the others.
