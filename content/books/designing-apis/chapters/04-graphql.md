@chapter
id: apid-ch04-graphql
order: 4
title: GraphQL
summary: GraphQL solves the over-fetching and under-fetching problems of REST by letting the client describe its needs — but it brings its own design problems (N+1, complexity attacks, federation overhead) that don't show up until you scale.

@card
id: apid-ch04-c001
order: 1
title: The GraphQL Framing
teaser: GraphQL is a query language for APIs — the client describes the exact shape of the data it wants, and the server returns precisely that, no more, no less, through a single endpoint.

@explanation

REST gives you a fixed menu: you call `/orders/:id` and get whatever the server decided to include. GraphQL inverts that contract. You write a query that names exactly the fields you need, and the server executes it. Under-fetching (making five requests to assemble one screen) and over-fetching (getting 40 fields when you need 4) both disappear — in theory.

The structural facts:

- **One endpoint.** A GraphQL API exposes a single HTTP endpoint, typically `POST /graphql`. The operation type and field selection live in the request body, not the URL.
- **Client-driven shape.** The client is not constrained by what the server returns from a fixed route. If you need `user.name` and `user.avatar.url`, you ask for exactly that.
- **Strongly typed schema.** Everything is described in a Schema Definition Language (SDL). The schema is the contract between client and server — it's introspectable, which means tooling can generate types, docs, and clients from it automatically.
- **Three operation types.** Queries read data, mutations write data, subscriptions open a long-lived channel for real-time events.

This framing explains both why GraphQL is compelling for product teams building complex UIs and why it is significantly more complex to operate than a JSON-over-HTTP REST API.

> [!info] The "one endpoint" design means HTTP-level caching — GET requests cached by URL — no longer applies by default. This is not a small tradeoff; it reshapes how you think about performance from day one.

@feynman

GraphQL is like a custom sandwich order — instead of choosing from a fixed menu, you tell the kitchen exactly what you want on it, and nothing else shows up on the plate.

@card
id: apid-ch04-c002
order: 2
title: Schema-First Design with SDL
teaser: The SDL is the contract — write it before you write a single resolver, and every downstream decision (types, nullability, naming) becomes easier to get right.

@explanation

Schema-first means you define your types in the Schema Definition Language before writing any implementation. The SDL is human-readable and tool-readable: Apollo Server, GraphQL Yoga, and Mercurius all parse the same SDL syntax.

The four building blocks of a GraphQL schema:

- **Types** — `type User { id: ID!, name: String!, email: String }`. The `!` marks a field as non-null. Designing nullability carefully matters: every nullable field forces clients to handle the null case; every non-null field is a promise your resolvers must never break.
- **Queries** — read operations declared on the root `Query` type. Each query is a named entry point into your data graph.
- **Mutations** — write operations declared on the root `Mutation` type. By convention, mutations are named as verbs: `createOrder`, `cancelSubscription`.
- **Subscriptions** — real-time operations declared on the root `Subscription` type.

```graphql
type Query {
  order(id: ID!): Order
  orders(userId: ID!, status: OrderStatus): [Order!]!
}

type Order {
  id: ID!
  total: Float!
  status: OrderStatus!
  lineItems: [LineItem!]!
}

enum OrderStatus {
  PENDING
  FULFILLED
  CANCELLED
}
```

Schema design decisions — field naming, nullability, argument shapes — are expensive to change once clients are depending on them. Deprecation via `@deprecated` exists, but clients have to adopt it. Design the schema as if it is a public API, even in early product phases.

> [!tip] Prefer designing your schema around your domain model (what it means), not your database schema (how it's stored). A schema that mirrors your tables 1:1 is one of the most common GraphQL anti-patterns.

@feynman

The SDL is like an architectural blueprint — you decide the shape of every room before the first brick is laid, because moving walls after the house is built is expensive.

@card
id: apid-ch04-c003
order: 3
title: Resolvers — The Per-Field Execution Model
teaser: Every field in a GraphQL response is produced by a resolver function — understanding this execution model is the most important concept for writing correct and performant GraphQL servers.

@explanation

When a GraphQL server receives a query, it walks the selection set field by field. For each field, it calls the corresponding resolver function. If there is no custom resolver, a default resolver reads the property from the parent object. If there is one, you control exactly how that field's value is produced.

A resolver has a fixed signature: `(parent, args, context, info)`.

```ts
const resolvers = {
  Query: {
    order: async (_, { id }, { dataSources }) => {
      return dataSources.ordersAPI.getOrder(id);
    },
  },
  Order: {
    lineItems: async (order, _, { dataSources }) => {
      return dataSources.ordersAPI.getLineItems(order.id);
    },
  },
};
```

- `parent` — the resolved value of the parent object. For `Order.lineItems`, it's the already-resolved `Order`.
- `args` — field arguments from the query.
- `context` — the shared request-scoped object where you put authenticated user, data sources, and loaders.
- `info` — the query AST; rarely needed outside advanced tooling.

The execution model is recursive. The server resolves `Query.order`, gets back an `Order` object, then resolves each field of that `Order` — including `lineItems`, which triggers its own resolver. This tree-walking is deterministic and predictable, but it creates the structural condition for the N+1 problem.

> [!warning] The context object is your primary tool for dependency injection. Instantiate data sources and DataLoaders once per request in context, not once per resolver call, or you will lose the batching behavior that makes GraphQL performant.

@feynman

A resolver is like a factory function for one answer — GraphQL asks each field "what are you?" and the resolver gives back the value for that field, one by one, walking the tree.

@card
id: apid-ch04-c004
order: 4
title: The N+1 Problem
teaser: The N+1 problem is not a bug in your code — it is a structural consequence of the per-field resolver model, and it will silently kill your database under real query loads.

@explanation

Consider a query that fetches a list of orders and each order's customer name:

```graphql
query {
  orders {
    id
    customer {
      name
    }
  }
}
```

With naive resolvers, this executes as:

1. One query to fetch all orders — returns N orders.
2. One query per order to fetch the customer — N more queries.

Total: 1 + N database calls, where N is the number of orders returned. Fetch 100 orders and you fire 101 queries. Fetch 1,000 and you fire 1,001. This is the N+1 problem.

Why is it structural? Because resolvers are invoked independently, one per field, with no built-in coordination between them. The `Order.customer` resolver has no visibility into the fact that 99 other `Order.customer` resolvers are about to run with different `order.customerId` values. Each makes its own database call in isolation.

The problem gets worse as queries grow deeper. A query with three levels of nested relationships multiplies the issue: orders → customers → addresses. REST APIs avoid this naturally because the endpoint author controls which JOINs happen; in GraphQL, the client controls the shape, so you lose that protection.

> [!warning] N+1 in GraphQL is invisible until you inspect query logs. Add slow-query logging and query count metrics before you ship a GraphQL API to production — you will be surprised by what you find.

@feynman

The N+1 problem is like a librarian who, instead of grabbing all the books from the shelf in one trip, goes back to the shelf individually for every book on a 100-item list.

@card
id: apid-ch04-c005
order: 5
title: DataLoader — Batching and Caching
teaser: DataLoader is the standard fix for N+1 — it collects all the keys requested within a single tick of the event loop and resolves them in one batched call, then caches within the request.

@explanation

DataLoader, originally written by Facebook for their GraphQL infrastructure and now a standalone library, works by exploiting JavaScript's event loop. Within a single tick, DataLoader collects all the keys passed to `.load()` across every resolver that runs in parallel. At the end of the tick, it calls your batch function once with all collected keys. You get the results back, and DataLoader distributes them to the individual callers.

```ts
import DataLoader from 'dataloader';

const customerLoader = new DataLoader(async (customerIds: readonly string[]) => {
  const customers = await db.customers.findMany({
    where: { id: { in: customerIds as string[] } },
  });
  // Return in the same order as customerIds
  return customerIds.map(id => customers.find(c => c.id === id) ?? null);
});

// In resolvers
const resolvers = {
  Order: {
    customer: (order, _, { loaders }) => loaders.customer.load(order.customerId),
  },
};
```

Two properties to understand:

- **Batching.** All `.load()` calls within the same event loop tick are grouped into one batch function call. Instead of 100 individual database queries, you get one query with a 100-item `IN` clause.
- **Per-request caching.** Once a key has been loaded in a request, subsequent `.load()` calls for the same key return the cached result. This eliminates duplicate loads within a single query execution.

DataLoader must be instantiated per request, not once at server startup. A shared instance would leak cached data between requests. Create loaders in the context function.

> [!tip] The return order from your batch function must match the order of the input keys. DataLoader relies on positional matching. If your database returns rows in a different order, you must re-sort them before returning.

@feynman

DataLoader is like a bus — instead of sending a taxi for each passenger one at a time, it waits until the end of the boarding window, collects everyone who showed up, and runs one trip to the destination.

@card
id: apid-ch04-c006
order: 6
title: Mutations — Naming, Input Types, and Errors-as-Data
teaser: Mutations in well-designed GraphQL APIs follow consistent naming conventions, use dedicated input types, and model business errors as data in the payload — not as HTTP status codes or thrown exceptions.

@explanation

Mutation naming follows a verb-noun convention: `createOrder`, `updateUserProfile`, `cancelSubscription`. Avoid REST-style naming like `POST /order` — mutations should read as actions.

**Input types** are the correct way to structure mutation arguments. A mutation taking more than one argument should use a single `input` argument with a dedicated `Input` type:

```graphql
mutation {
  createOrder(input: { userId: "u1", items: [{ productId: "p1", qty: 2 }] }) {
    order {
      id
      total
    }
    userErrors {
      field
      message
    }
  }
}
```

**Payload types** are the return type of a mutation — a dedicated object that carries both the result and any errors. The pattern above, popularized by the Shopify API, puts business errors inside the payload as `userErrors` rather than throwing GraphQL errors. This is the errors-as-data pattern.

Why it matters:

- GraphQL errors (thrown exceptions) are transport-level signals — network failures, authorization failures. Business validation failures are domain events. Mixing them forces clients to handle both in the same error-handling path.
- `userErrors` can include field-level attribution, making form validation straightforward.
- The HTTP response stays 200 even when a business rule fails — the client inspects the payload, not the status code.

> [!tip] Design a `MutationPayload` convention early and apply it consistently. Inconsistent mutation shapes across a large schema become a maintenance burden that grows with every new feature.

@feynman

A mutation payload with errors-as-data is like a form submission that shows you exactly which field has a problem — rather than just saying "failed" and making you guess what went wrong.

@card
id: apid-ch04-c007
order: 7
title: Subscriptions — Real-Time with GraphQL
teaser: GraphQL subscriptions let clients declare interest in server-pushed events using the same query language — but the transport choices and operational complexity are meaningfully different from queries and mutations.

@explanation

A subscription is a long-lived connection where the server pushes updates to the client whenever a relevant event occurs. The client declares what it wants to receive using the same field selection syntax:

```graphql
subscription {
  orderStatusChanged(userId: "u1") {
    id
    status
    updatedAt
  }
}
```

**Transport options:**

- **WebSocket (graphql-ws protocol)** — the default and most capable option. Full bidirectional communication. Supported natively by Apollo Client, urql, and Relay. Requires a WebSocket-capable server; not compatible with serverless functions without a dedicated WebSocket gateway.
- **Server-Sent Events (SSE)** — one-way push over an HTTP connection. Simpler to proxy, works with HTTP/2, no WebSocket handshake. GraphQL Yoga supports SSE out of the box. Less capable (no bidirectional messaging), but sufficient for most real-time use cases.

**Operational considerations:**

- Subscriptions require stateful, long-lived server processes. This conflicts with horizontal scaling and serverless architectures. You typically need a dedicated subscription server or a PubSub broker (Redis, Kafka) to fan out events across multiple server instances.
- Apollo Server, GraphQL Yoga, and Mercurius all support subscriptions, but each has different PubSub integration stories. Check the documentation for your chosen server before committing.

> [!warning] Subscriptions are the feature most likely to cause architecture surprises. If your deployment target is serverless or a stateless container fleet, design the real-time layer separately — SSE through a dedicated gateway, or a separate WebSocket service — rather than bolting subscriptions onto your main GraphQL server.

@feynman

A GraphQL subscription is like a newspaper delivery subscription — instead of going to the store every day to check if there's news (polling), you register once and the paper shows up at your door when there's something new.

@card
id: apid-ch04-c008
order: 8
title: GraphQL vs REST — When to Use Which
teaser: GraphQL is not a universal upgrade over REST — each wins in specific contexts, and the decision should be driven by your team's access patterns, not by which one sounds more modern.

@explanation

GraphQL tends to win when:

- **Multiple clients with divergent data needs.** A mobile app, a web app, and a third-party partner all need different subsets of the same data. REST forces you to build multiple endpoints or accept over-fetching; GraphQL lets each client query exactly what it needs.
- **Rapidly evolving product UIs.** Frontend teams can iterate on data requirements without waiting for new REST endpoints. The schema's additive-only evolution model supports this well.
- **Interconnected data graphs.** Products with complex relationships between entities (social graphs, e-commerce with products, orders, users, reviews) benefit from the ability to traverse relationships in a single query.

REST tends to win when:

- **Simple, stable CRUD.** A resource with predictable read and write patterns needs no query language. REST is less code, easier to cache, and simpler to reason about.
- **Public APIs with broad consumer bases.** REST's discoverability via URLs, browser compatibility, and HTTP caching make it more accessible to consumers who may not have GraphQL tooling.
- **File uploads and streaming.** REST handles multipart form data and chunked transfer naturally; GraphQL's binary handling is awkward.
- **Performance-critical GET requests.** CDN and browser caching of REST GET responses is trivially easy. Making GraphQL queries cacheable requires persisted queries and additional infrastructure.

Both may be wrong when your real requirement is a streaming API or an event-driven architecture — consider Server-Sent Events or a message broker before reaching for either.

> [!info] Many production systems use both: GraphQL for the product-facing API where clients need flexibility, REST for machine-to-machine integration where simplicity and caching matter more.

@feynman

Choosing between GraphQL and REST is like choosing between a custom-order restaurant and a fixed lunch special — the custom order is more powerful and more flexible, but the fixed special is faster, cheaper, and easier when you already know what you want.

@card
id: apid-ch04-c009
order: 9
title: Query Complexity Attacks
teaser: Because clients control query shape, a malicious or careless client can construct a deeply nested query that overwhelms your server — depth limits, breadth limits, and persisted queries are the standard defenses.

@explanation

GraphQL's flexibility is a security surface. Consider this query sent to a social graph API:

```graphql
{
  user(id: "u1") {
    friends {
      friends {
        friends {
          friends {
            name
          }
        }
      }
    }
  }
}
```

At each nesting level, the result set can multiply. Four levels of a friends relationship could return millions of nodes. This is a legitimate denial-of-service vector, not a theoretical one.

The standard mitigations:

- **Depth limiting.** Reject queries that exceed a maximum nesting depth (e.g., 10 levels). Simple to implement; most GraphQL server libraries have plugins for this.
- **Breadth limiting.** Reject queries that request more than a maximum number of fields or aliases at any level.
- **Query cost analysis.** Assign a cost to each field — potentially weighted by how expensive it is to resolve — and reject queries that exceed a total cost budget. More precise than depth/breadth limits, but requires you to maintain cost annotations on your schema.
- **Persisted queries.** In production, only allow queries that are pre-registered on the server. The client sends a hash rather than the full query string; the server looks up the pre-approved query and executes it. This completely eliminates arbitrary query injection. Apollo Server and Apollo Studio support persisted queries natively. This is the most robust defense, and the correct posture for any public-facing GraphQL API.

> [!warning] Depth limiting alone is not sufficient. A shallow but extremely wide query (requesting 1,000 fields with aliases) can also exhaust resources. Use a combination of depth, breadth, and cost limits.

@feynman

Query complexity limits are like a buffet with a plate size limit — you can choose anything you want from the table, but you can't stack the plate so high that you bring the kitchen to a halt.

@card
id: apid-ch04-c010
order: 10
title: Schema Federation
teaser: Federation lets multiple teams own separate subgraphs that compose into a single unified schema — the right architecture when one team and one schema can no longer cover the whole data graph.

@explanation

As an organization grows, a single GraphQL schema owned by a single team becomes a bottleneck. Different teams own different domains — orders, inventory, users, payments — and coordinating schema changes through one team does not scale.

Apollo Federation solves this by defining a composition model. Each team owns a subgraph: a self-contained GraphQL service that describes its portion of the data graph. A gateway (the Apollo Router or a compatible alternative) composes these subgraphs into a single supergraph that clients query as if it were one API.

The key primitives:

- **`@key` directive** — marks the primary key of an entity, allowing other subgraphs to extend it. An `Order` subgraph might mark `id` as the key; the `Shipping` subgraph can then reference an `Order` by its `id` without owning the full type.
- **Entity resolution** — when a query needs fields from multiple subgraphs, the Router plans and executes the cross-subgraph fetch automatically. The client sees one response.
- **Schema composition** — the supergraph is validated at build time, not at runtime. A schema that can't compose fails the build, not the production request.

```graphql
# In the Orders subgraph
type Order @key(fields: "id") {
  id: ID!
  total: Float!
}

# In the Shipping subgraph
type Order @key(fields: "id") {
  id: ID!
  trackingNumber: String
  estimatedDelivery: String
}
```

Federation adds meaningful operational overhead: you now run multiple GraphQL services, a schema registry, and a router. It is not the right starting point — it is the migration target when monolithic schema ownership breaks down.

> [!info] Apollo Federation is the most widely adopted federation standard, but it is not the only one. GraphQL Mesh and Mercurius Gateway offer alternatives. Evaluate whether you actually need federation before adopting it — premature federation trades a schema coordination problem for an infrastructure coordination problem.

@feynman

Schema federation is like a department store where each department manages its own inventory — you walk in through one entrance and shop the whole store, but the electronics team and the clothing team operate independently behind the scenes.

@card
id: apid-ch04-c011
order: 11
title: The Tooling Landscape
teaser: The GraphQL ecosystem has a small number of mature, well-supported tools — knowing which one to reach for on the server side and the client side saves you from unnecessary evaluation work.

@explanation

**Server-side:**

- **Apollo Server** — the most widely deployed GraphQL server for Node.js. Framework-agnostic, integrates with Express, Fastify, and others. Strong ecosystem of plugins (Apollo Studio, persisted queries, usage reporting). Excellent documentation. The default choice for most teams.
- **GraphQL Yoga** — built by The Guild, runs on any JavaScript runtime including Cloudflare Workers and Deno. First-class support for Server-Sent Events subscriptions, Envelop plugin system, and file uploads. The right choice if you need edge/serverless deployment or SSE subscriptions.
- **Mercurius** — GraphQL adapter for Fastify. Tightly integrated with Fastify's performance characteristics and plugin system. Good choice if you're already running a Fastify application and want to minimize runtime overhead.

**Client-side:**

- **Apollo Client** — full-featured React client with normalized in-memory cache, optimistic UI, pagination utilities, and DevTools. The highest capability option; also the heaviest. Best suited for complex product UIs with many interconnected queries.
- **urql** — lighter alternative to Apollo Client with a composable exchange system. Easier to customize and extend. A good default for most React applications that don't need the full Apollo Client feature set.
- **Relay** — Facebook's GraphQL client, designed for scale and correctness. Requires a compiler step and enforces strict schema conventions (cursor-based pagination, global object IDs). Significant investment to adopt, but the most principled architecture for large applications with complex data dependencies.

> [!tip] Start with Apollo Server on the server and urql on the client unless you have a specific reason to go heavier. Both are well-maintained, well-documented, and easy to migrate away from if your needs change.

@feynman

Picking a GraphQL server is like choosing a kitchen setup — Apollo Server is the well-stocked professional kitchen that works for almost everyone, Yoga is the compact portable setup that runs anywhere, and Mercurius is the high-performance racing kitchen bolted inside a Fastify car.

@card
id: apid-ch04-c012
order: 12
title: GraphQL Anti-Patterns
teaser: The most common GraphQL mistakes — exposing database tables directly, writing mutations that behave like REST POST endpoints, and ignoring caching — are all design decisions that feel harmless at first and become painful at scale.

@explanation

**Anti-pattern 1: Exposing database tables 1:1.**
Mapping your database schema directly to your GraphQL schema produces a leaky abstraction. Clients become coupled to your internal data model. Renaming a column requires a breaking schema change. Internal IDs, join tables, and denormalized fields all surface to clients who shouldn't know or care about them. Design your schema around your domain model — what the data means to consumers — not around how it's stored.

**Anti-pattern 2: Mutations that look like REST POST endpoints.**
A mutation called `createOrder` with arguments `(userId, productId, quantity)` is fine. A mutation called `createOrder` with 20 arguments mirroring the columns of an orders table is a sign that the domain model hasn't been designed. Use input types, model business operations as named actions, and group related fields into objects. Mutations should express what a user is trying to do, not what a database row looks like.

**Anti-pattern 3: Ignoring caching.**
GraphQL's single POST endpoint breaks HTTP GET caching by default. Many teams accept this and either cache nothing or cache at the application layer with Redis. Both are more expensive than they need to be. Persisted queries let you execute pre-registered operations as GET requests with query hashes in the URL — making CDN and browser caching possible again. Apollo Studio, Apollo Server's persisted query support, and GraphQL Yoga's response caching plugin all address this. Ignoring it is a performance and cost decision, not just a technical one.

**Anti-pattern 4: Skipping DataLoader everywhere.**
Adding a DataLoader for one resolver and forgetting it for the rest produces an API that performs well in tests (which query simple shapes) and poorly in production (which queries complex nested shapes). Assume every resolver that fetches from a database or an upstream service needs a DataLoader unless you've verified it can't produce N+1 behavior.

> [!warning] The "it works in development" trap is more common in GraphQL than in REST, because development queries are usually simple and flat. Always test with the nested, realistic query shapes that production clients will actually send.

@feynman

GraphQL anti-patterns are like shortcuts in carpentry — they look like they save time until you're mid-project and realize the whole frame needs to come apart because the first cut was wrong.
