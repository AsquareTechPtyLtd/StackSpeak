@chapter
id: ttp-ch08-data-and-state
order: 8
title: Data and State
summary: How you model, store, and move data through a system determines its correctness, performance, and maintainability more than almost any other architectural decision — and most of the classic bugs in production trace back to a state management choice made early that seemed harmless at the time.

@card
id: ttp-ch08-c001
order: 1
title: Choosing the Right Data Structure
teaser: The data structure you reach for first isn't a style choice — it determines whether an operation takes a microsecond or ten seconds at scale.

@explanation

Every data structure is a contract about what operations are cheap and what operations are expensive. Picking the wrong one means you've accepted hidden costs that don't surface until your dataset is large enough to hurt.

The decision tree most engineers skip:

- **"Do I need to check membership?"** Use a Set or HashMap. Scanning a List for existence is O(n); a hash lookup is O(1). At 1 million elements, that's the difference between 1 microsecond and 1 second.
- **"Do I need ordered insertion and fast removal from both ends?"** Use a Deque or Queue, not a List with `removeFirst()` — which shifts every remaining element on each call.
- **"Do I need to rank or prioritize?"** Use a heap-backed Priority Queue, not a sorted List you re-sort after every insert.
- **"Do I need key-value lookup?"** Use a HashMap. Looping over a list of pairs is something a junior developer does once before they understand hash tables.

The engineer who always reaches for a List writes correct code that degrades gracefully until the data grows — and then falls apart spectacularly. The fix at that point is a data structure change that touches every caller.

The right question before writing a collection: what operations will this thing need to support, and how often? Answer that before you type `var results = []`.

> [!warning] A List used as a lookup table is a performance bug waiting for enough data to become visible. Check membership operations on any collection that might grow past a few hundred elements.

@feynman

Using a List when you need a HashMap is like searching for a word by reading every page of a dictionary instead of using alphabetical order — it works, but only until the dictionary gets big enough that you notice.

@card
id: ttp-ch08-c002
order: 2
title: Immutability as a Design Choice
teaser: Immutable objects eliminate an entire class of bugs before you write the tests for them — but the choice has costs, and you should understand both sides before defaulting to either.

@explanation

Shared mutable state is the root cause of a specific, painful category of bugs: the value that changed between when you read it and when you used it, the object that was modified by a function you didn't know about, the race condition that only reproduces under load. Immutability eliminates all of these by making objects incapable of changing after creation.

The benefits are concrete:
- No defensive copying. If an object can't be modified, passing it to a function is safe — you don't need to copy it first to protect against mutation.
- Thread safety is free. Immutable objects can be shared across threads with no synchronization.
- Reasoning is simpler. When you see `order.total` in the code, you know it's the same value it was five lines ago.

The costs are real too:
- Allocation pressure. Updating an immutable object means creating a new one. In hot loops or high-throughput paths, this can matter.
- Verbosity. Languages that weren't designed around immutability (Java, C#) require explicit effort — `final` fields, builders, copy constructors.

Value objects in domain modeling are the clearest win: `Money`, `EmailAddress`, `OrderId` — things that represent a value, not an entity with identity. These should almost always be immutable. Mutable state belongs in entities that explicitly model lifecycle (an `Order` that transitions through states), not in value types.

> [!tip] Default to immutability for data transfer objects, value types, and anything passed across thread boundaries. Make mutability a deliberate choice, not the default.

@feynman

An immutable object is like a signed check — once issued, the amount can't change, which is exactly why both parties trust it.

@card
id: ttp-ch08-c003
order: 3
title: Null: The Billion-Dollar Mistake
teaser: Tony Hoare called null his billion-dollar mistake in 2009 — null pointer exceptions remain the most common runtime error in Java and C#, decades after the problem was understood.

@explanation

Tony Hoare introduced null references in ALGOL W in 1965, and by his own estimate the decision has caused over a billion dollars in bug fixes, crashes, and downtime. The problem is structural: null is a valid value in every reference type, so any reference can be null, which means every dereference is potentially a crash that the compiler won't tell you about.

The discipline of not using null where you don't have to:

- **Return empty collections, not null.** A method that returns `null` instead of an empty list forces every caller to check for null before iterating. Return `[]`. The caller's code is cleaner, and null pointer exceptions in for-loops disappear.
- **Return Optional/Maybe, not null.** When a value might genuinely be absent, use the type system to say so. `Optional<User>` forces the caller to handle the absent case explicitly. `User` (which might secretly be null) does not.
- **Avoid null parameters.** A function that accepts null as a parameter has hidden conditional logic. Two different call sites behave differently. Name the distinction explicitly instead.

Modern languages have learned this lesson: Swift, Kotlin, and Rust make nullability explicit in the type system and require you to handle it at the call site. In those languages, a non-optional type is a compiler guarantee that the value is present.

In languages without this safety (Java before Optionals, C#, JavaScript), the discipline has to be applied manually — which is why null pointer exceptions are still the #1 runtime error in production Java applications.

> [!warning] Every time you return null instead of an empty collection or an Optional, you're pushing error handling onto the caller — and trusting that they remember to do it. Most of the time, they don't.

@feynman

Returning null where you could return Optional is like handing someone a box and not telling them it might be empty — they'll find out when they try to take something out.

@card
id: ttp-ch08-c004
order: 4
title: State in Distributed Systems
teaser: Before you can reason about what happens when a node fails, you need to know exactly where your state lives — and in distributed systems, the answer is always "in more places than you think."

@explanation

In a monolith, state has one home: the database, plus what's in memory for the current request. In a distributed system, state fragments across every layer of the architecture.

Where your state actually lives:
- **The database** — durable, consistent, slow to write.
- **In-memory caches** (Redis, Memcached) — fast, lossy, may diverge from the database.
- **Message queues** (Kafka, SQS) — messages in flight that haven't been processed yet; state that exists but hasn't been applied.
- **The calling client** — the browser or mobile app holding a copy of data that may be stale.
- **The service instance's heap** — anything held in memory between requests (connection pools, local caches, scheduled job state).

The CAP theorem formalizes the fundamental constraint: in a distributed system that can experience network partitions, you can guarantee consistency (every node sees the same data) or availability (every request gets a response), but not both simultaneously. Most systems make a business-driven choice between the two — and the teams operating them often don't know which choice was made.

What happens when a node fails is determined by where that node held state. A stateless service can restart anywhere. A service with in-memory state loses it on restart. A message queue consumer that fails mid-processing may re-process messages — which is why idempotency matters.

> [!info] Before the next architecture review, map where every piece of state in your system lives. If any of it exists only in memory and has no recovery path, that's a gap worth closing.

@feynman

Distributed state is like cash in multiple wallets — convenient until someone needs to know the exact total, at which point you have to decide which wallet is authoritative.

@card
id: ttp-ch08-c005
order: 5
title: Database Transactions and ACID
teaser: ACID isn't just four letters on a slide — each property addresses a specific failure mode, and the isolation levels let you trade correctness for performance in ways that will eventually bite you.

@explanation

ACID is the contract a transactional database makes about what it guarantees when things go wrong:

- **Atomicity:** All writes in a transaction commit together, or none do. No partial writes. If a transfer deducts from account A and then crashes before crediting account B, the debit rolls back.
- **Consistency:** The database moves from one valid state to another. Constraints, foreign keys, and invariants are preserved across the transaction boundary.
- **Isolation:** Concurrent transactions don't see each other's intermediate state. Two transactions running simultaneously produce the same result as if they ran sequentially.
- **Durability:** Once a transaction commits, the data survives — even if the server crashes immediately after.

Isolation is where the tradeoffs live. The SQL standard defines four levels:

- **Read Uncommitted:** Can read uncommitted changes from other transactions. Fastest. Allows dirty reads.
- **Read Committed:** Only reads committed data. Default in PostgreSQL and SQL Server. Allows non-repeatable reads.
- **Repeatable Read:** Same row read twice in a transaction returns the same value. Default in MySQL/InnoDB. Allows phantom reads.
- **Serializable:** Full isolation. Slowest. No anomalies. Rarely used in production because of the throughput cost.

Most production systems run at Read Committed and accept the theoretical anomalies, betting that concurrent writes to the same rows are rare enough not to matter. Sometimes that bet is wrong.

> [!warning] The default isolation level of your database is not "safe." Know what anomalies it permits and whether your application logic depends on guarantees it isn't actually getting.

@feynman

ACID properties are the database's promise that partial success is impossible — the same way a good banking system makes it impossible to deduct money without also crediting it.

@card
id: ttp-ch08-c006
order: 6
title: The N+1 Query Problem
teaser: The loop that looks innocent in code fires one database query per iteration — and at 1,000 records, that's 1,001 round trips where 1 would do.

@explanation

The N+1 pattern is pervasive, especially in ORM-heavy codebases, because it's invisible from the code. You write what looks like a simple loop:

```
orders = Order.findAll()
for order in orders:
    print(order.customer.name)  // triggers a query per order
```

The ORM lazily loads `customer` on each access. What looks like one operation is actually N+1 database queries: one to fetch orders, then one per order to fetch the customer. At 10 records, it's fine. At 1,000, it's 1,001 queries. At 100,000, it's a production incident.

The performance difference is not marginal. Replacing 1,000 round trips with a single JOIN typically reduces latency from several seconds to under 100 milliseconds. The fix is eager loading — telling the ORM to JOIN the related data in the initial query:

```
orders = Order.findAll(include: ['customer'])
```

How to detect it:
- Enable query logging in development. Count the queries for a single request. If the count scales with the data, you have an N+1.
- APM tools (Datadog, New Relic) surface slow traces with high query counts — 50+ queries per request is a red flag.
- Libraries like Django Debug Toolbar or Hibernate's statistics output show query counts per request.

ORMs don't hide this deliberately — they're designed for developer ergonomics, not query efficiency. Knowing when eager loading is needed is part of using them correctly.

> [!tip] Any time you access a relationship inside a loop, assume you have an N+1 until you've checked the query log. The assumption is right more often than not.

@feynman

The N+1 problem is like fetching each item on a grocery list in a separate trip to the store — you could do it all in one, but the abstraction made it easy to forget.

@card
id: ttp-ch08-c007
order: 7
title: Cache Invalidation Strategies
teaser: A cache that diverges from the database is worse than no cache — it serves wrong data with fast response times, which makes the bug harder to notice and harder to attribute.

@explanation

Phil Karlton's observation — "there are only two hard things in computer science: cache invalidation and naming things" — is a joke with a serious point. Caching is easy to add and hard to maintain correctly.

The main invalidation strategies:

- **TTL (time-to-live):** Cached entries expire after a fixed duration. Simple, predictable. Correct for data where some staleness is acceptable (product catalog, user profile). Wrong for anything requiring strong consistency (account balance, inventory count).
- **Event-based invalidation:** When the underlying data changes, explicitly invalidate or update the cache entry. Correct but complex — you need to ensure every write path triggers the invalidation, and distributed systems make this harder.
- **Write-through:** Every write goes to the cache and the database simultaneously. Cache is always consistent. Adds latency to writes; cold-start problem on new cache entries.
- **Write-behind (write-back):** Writes go to the cache immediately, to the database asynchronously. Fast writes, but data can be lost if the cache fails before the write propagates.
- **Cache-aside:** Application reads from cache; on miss, reads from database and populates cache. Most common pattern. Risk: thundering herd on a popular expired key.

The production incidents that follow from getting this wrong are always variants of the same story: a code change updates the database, the cache holds the old value, users see stale data for [TTL duration], someone pages the on-call because they can't figure out why their change isn't live.

> [!warning] When a bug "fixes itself" after a few minutes, the cache is the first suspect. A cache serving wrong data is a correctness bug, not a performance bug — treat it accordingly.

@feynman

A stale cache is like a whiteboard that shows last week's architecture — technically present, actively misleading, and more confident-looking than it has any right to be.

@card
id: ttp-ch08-c008
order: 8
title: Schema Evolution and Migration
teaser: Renaming a column takes five minutes in a local dev environment and two weeks of careful planning in production — the database and application can't redeploy atomically.

@explanation

The fundamental constraint of schema migration in production: you cannot atomically swap out the database schema and all running application instances simultaneously. For some window — minutes to hours, depending on deployment strategy — old code runs against the new schema, or new code runs against the old schema. Your migration must be safe for both.

**Additive changes are safe:** adding a new nullable column, adding a new table, adding an index. Old code ignores the new column; new code can use it.

**Destructive changes are dangerous:** dropping a column, renaming a column, changing a column's type. If you drop a column before deploying the code that stops reading it, the old instances crash. If you deploy the code first, it reads a column that doesn't exist yet and crashes.

The expand/contract pattern for safe column renames:
1. **Expand:** Add the new column. Deploy code that writes to both old and new columns, reads from old.
2. **Migrate:** Backfill the new column from the old.
3. **Contract:** Deploy code that reads from the new column, stops writing to the old. Then drop the old column in a separate migration.

This takes longer but never leaves the system in an inconsistent state.

Migration tools (Flyway, Liquibase for JVM; Alembic for Python; ActiveRecord migrations for Rails) version and apply migrations automatically, ensuring every environment runs the same schema in the same order. The alternative — hand-running SQL in production and hoping you didn't miss a step — is how databases drift.

> [!info] A schema migration that you can't roll back is a risk event. Before running destructive migrations in production, have a tested rollback plan.

@feynman

Safe schema migration is like renovating a room in a house where people are still living — you can't tear out the floor at once, so you work one section at a time and make sure nothing collapses while someone's standing on it.

@card
id: ttp-ch08-c009
order: 9
title: Idempotency and Delivery Guarantees
teaser: Networks fail, timeouts happen, and retries are necessary — an operation that can't be safely retried is a bug waiting for the infrastructure to misbehave.

@explanation

An operation is idempotent if calling it multiple times with the same input produces the same result as calling it once. `DELETE /users/123` is idempotent — deleting an already-deleted user is the same outcome as deleting it once. `POST /charges` is not idempotent by default — submitting the same charge twice creates two charges.

Why this matters: every network call can fail in ambiguous ways. You send a request; the connection drops. Did the server receive it? Did it process it? You don't know. The safe response to this uncertainty is to retry. If the operation is not idempotent, you've now potentially duplicated a payment, sent two emails, or inserted a row twice.

**Idempotency keys** are the standard fix for non-idempotent operations: include a unique client-generated token with the request. The server stores the key and the result; if the same key arrives again, it returns the stored result without re-executing. Stripe, Twilio, and most payment APIs require idempotency keys for exactly this reason.

**Delivery semantics** in message queues:
- **At-most-once:** Message may be lost; never delivered twice. Fast, lossy.
- **At-least-once:** Message will be delivered, possibly more than once. Safe to retry; consumers must be idempotent.
- **Exactly-once:** Message delivered exactly once. Expensive to guarantee; often simulated by idempotent consumers + at-least-once delivery.

Most production systems use at-least-once delivery and require idempotent consumers. Building the consumer first, then relaxing it, is the wrong order.

> [!tip] When designing any state-modifying operation that will be called over a network, ask: "What happens if this is called twice?" If the answer is "bad things," add idempotency before shipping.

@feynman

An idempotent operation is like a light switch you can flip on as many times as you want — it's still just on, and the room isn't getting any brighter.

@card
id: ttp-ch08-c010
order: 10
title: Event Sourcing vs CRUD
teaser: CRUD stores what the system looks like now; event sourcing stores how it got here — and that distinction matters more than it sounds when you need to audit, replay, or debug production behavior.

@explanation

In CRUD (Create, Read, Update, Delete), the database holds the current state of each entity. An `orders` table has one row per order with the current status, total, and address. When the order ships, you UPDATE the row. The previous state is gone.

In event sourcing, the database stores a sequence of events: `OrderPlaced`, `PaymentConfirmed`, `ItemShipped`, `OrderCancelled`. Current state is derived by replaying the event log. The row you'd read in CRUD doesn't exist as a stored entity — it's computed.

**Event sourcing benefits:**
- **Full audit log:** Every state transition is a first-class record. You don't need to instrument it.
- **Replay:** Feed the event log into a different projection to build a new read model or correct a data bug.
- **Time travel:** Reconstruct the exact state of any entity at any point in time — useful for debugging "what did the system see when it made this decision?"
- **Event-driven integration:** Other services subscribe to the event stream naturally.

**Event sourcing costs:**
- **Query complexity:** "Show me all orders over $100 that shipped last week" requires a read model (a materialized projection), not a simple SELECT.
- **Storage growth:** Events are append-only. The log grows forever. Snapshotting is necessary at scale.
- **Eventual consistency:** Read models are updated asynchronously; queries may not reflect the most recent event immediately.
- **Team complexity:** Most engineers are fluent in CRUD; event sourcing has a learning curve.

CRUD is the right default for most systems. Event sourcing earns its complexity in domains where auditability, replayability, or complex temporal queries are actual requirements — financial systems, compliance-heavy domains, systems where "what happened and when?" is a first-class product feature.

> [!info] The question isn't "which is better" — it's "does this domain's requirements justify the operational cost of event sourcing?" The audit log that CRUD can't provide is a legitimate reason. The hype cycle is not.

@feynman

CRUD is a whiteboard showing the current state of the project; event sourcing is the commit history — the whiteboard is easier to read, but the commit history is the only one that can tell you how you got here.
