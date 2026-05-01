@chapter
id: sa-ch11-event-driven
order: 11
title: Event-Driven
summary: Components communicate by publishing and subscribing to events. The right shape for fan-out workflows, audit trails, and cross-team decoupling — and the wrong shape for almost everything else.

@card
id: sa-ch11-c001
order: 1
title: Events as the Backbone
teaser: An event-driven architecture replaces direct calls with published events. Components don't know who consumes their events; consumers don't know who produces them. The decoupling is the whole point.

@explanation

In an event-driven system, components don't call each other directly. Instead:

- **Producers publish events** to a broker (Kafka, RabbitMQ, NATS, EventBridge, Pulsar).
- **Consumers subscribe** to the events they care about.
- **The broker** routes events from producers to consumers.

A typical event-driven flow:

```text
Order service        publishes  →  OrderPlaced event
                                       ↓
                                       ↓ (broker routes to subscribers)
                                       ↓
                              ┌────────┼────────┐
                              ↓        ↓        ↓
                       Inventory   Notification  Analytics
                       (reserves)   (sends email) (logs metric)
```

The Order service doesn't know about Inventory, Notification, or Analytics. Any of them can be added or removed without changing the producer. Consumers can be temporarily down without affecting the producer.

This decoupling is the architecture's main virtue. It's also its main cost — the things that would be straightforward in a synchronous system get harder.

> [!info] Event-driven architectures are more talked about than used. Most teams that say "we're event-driven" are actually service-based with some events for fanout. That's fine — the pattern is most useful applied surgically, not as the default.

@feynman

Same instinct as broadcasting on a radio frequency. The DJ doesn't know who's listening. Listeners tune in independently. The radio doesn't care if zero people listen or a million.

@card
id: sa-ch11-c002
order: 2
title: When Event-Driven Is the Right Style
teaser: Workflows that fan out to multiple consumers. Cross-team decoupling. Audit and analytics derived from operational events. When events are the natural model, this is the right shape.

@explanation

Event-driven excels when:

- **Fan-out is natural.** One event triggers many independent reactions. New order → reserve stock + notify customer + update analytics + trigger fraud check.
- **Cross-team decoupling matters.** Producers can ship without coordinating with consumers (and vice versa).
- **Audit is the architecture.** The event log itself is the source of truth; current state is a projection.
- **Workflows span multiple services.** The events are the workflow; sagas pull along.
- **Real-time analytics or streaming.** Events flow into Kafka; consumers compute aggregations live.

It's a poor fit when:

- **Request-response is the natural shape.** "Get user by ID" is a query, not an event. Forcing it through events adds latency without benefit.
- **Strong consistency is required.** Eventual consistency is the default; immediate consistency is hard.
- **Debugging is critical.** Tracing an event through five consumers, with retries and out-of-order delivery, is materially harder than a stack trace.
- **Latency budgets are tight.** Event hops add latency.

The honest pattern: most production systems use events for the parts that benefit (state changes, fan-out, audit) and synchronous calls for the rest (queries, transactions). Mixed mode is fine; "event-driven everything" is usually wrong.

> [!warning] If your team can't articulate why a particular interaction is event-driven instead of synchronous, the answer is probably "we shouldn't have made it event-driven." Reach for events deliberately.

@feynman

Same as broadcasting vs phone calls. Broadcasting works for "everyone needs to hear this"; phone calls work for "I need an answer from this specific person." Picking the wrong tool makes everything harder.

@card
id: sa-ch11-c003
order: 3
title: Event Schemas Are Forever
teaser: Once consumers depend on an event's shape, you can't change it without breaking them. Event schemas need the same versioning discipline as public APIs — because that's what they are.

@explanation

The event is a contract. Once consumers parse a particular event shape, that shape is locked. You can:

- **Add optional fields.** Existing consumers ignore them.
- **Add new event types.** Existing consumers ignore them.
- **Mark fields as deprecated.** Don't remove until you know nobody depends on them.

You cannot, without breaking consumers:

- **Rename a field.** Existing consumers reference the old name.
- **Change a field's type.** Existing consumers parse the old type.
- **Remove a field.** Existing consumers may require it.
- **Change semantics of an existing field.** Old consumers interpret it the old way.

The discipline:

- **Schema registry** — central source of truth for event schemas. Schema Registry (Confluent), Glue (AWS), in-house equivalents.
- **Schema versioning** — every event carries a version; consumers handle old versions gracefully.
- **Compatibility checks in CI** — proposed schema changes are rejected if they break compatibility.
- **Backward and forward compatibility** — old consumers can read new events; new consumers can read old events. Until you're sure of when each consumer migrated, both directions matter.

> [!warning] The team that ships event schemas without registry, versioning, and compatibility checks is shipping a future migration nightmare. Get this discipline in place day one — retrofitting it is hard.

@feynman

Same as a public API. Once it's public, every change is a coordination problem. Events are private until consumed; they become public the moment someone subscribes. Treat them like public from the start.

@card
id: sa-ch11-c004
order: 4
title: Choreography vs Orchestration
teaser: Choreography: each service reacts to events independently; the workflow emerges. Orchestration: a central coordinator drives the steps. Choreography is decoupled but hard to debug; orchestration is centralised but visible.

@explanation

When workflows span multiple services, two patterns:

**Choreography** — services react to events independently. The workflow is implicit in who subscribes to what.

```text
OrderService publishes OrderPlaced
  ↓
InventoryService consumes OrderPlaced; publishes StockReserved
  ↓
PaymentService consumes StockReserved; publishes PaymentProcessed
  ↓
OrderService consumes PaymentProcessed; updates state
```

**Orchestration** — a central component (the orchestrator, often a workflow engine) drives the steps. Services do the work but don't know about each other.

```text
Orchestrator: starts saga
  → Orchestrator calls InventoryService.reserveStock
  → Orchestrator calls PaymentService.charge
  → Orchestrator calls OrderService.confirm
  ↓
Orchestrator: saga complete
```

Choreography is more decoupled. Each service is independent. New steps in the workflow are added by adding subscribers; no central place to update.

Orchestration is more debuggable. The orchestrator owns the workflow definition; you can read it. When things go wrong, the orchestrator's state tells you where.

A useful rule: choreography for simple workflows (2-3 steps, well-understood); orchestration for complex ones (many steps, error handling, branches). Tools like Temporal, AWS Step Functions, and Camunda do orchestration well.

> [!info] Choreography is often picked for the "decoupled" benefit but produces workflows nobody can debug. The team realises the cost two years in. Orchestration's "centralised" cost is usually worth it for non-trivial flows.

@feynman

Choreography is jazz — each musician improvises within the structure. Orchestration is a symphony — a conductor controls the timing. Both produce music; only one is listenable when half the musicians don't show up.

@card
id: sa-ch11-c005
order: 5
title: Event Sourcing
teaser: Store the events themselves as the source of truth; rebuild current state by replaying them. Powerful for audit and time-travel, painful for almost everything else.

@explanation

Event sourcing takes the event-driven idea to the data layer: instead of storing the current state of a record, store the events that produced it.

Traditional storage:

```text
users table:
  id=1, balance=100
```

Event-sourced storage:

```text
events stream:
  AccountOpened(id=1, initial=0)
  Deposit(id=1, amount=50)
  Deposit(id=1, amount=70)
  Withdrawal(id=1, amount=20)

Current state (a projection): id=1, balance=100
```

What this buys:

- **Complete audit.** Every change is a recorded event. You can answer "what happened on this account on June 3" trivially.
- **Time travel.** Replay events up to any point in history.
- **Multiple projections.** Different views of the same events. The same source produces both an account balance and a tax-year summary.
- **Natural fit for event-driven systems.** The events are already there.

What this costs:

- **Schema migrations are hard.** Old events have old shapes; you can't just ALTER TABLE.
- **Querying is indirect.** You query projections, not the event log; building the right projections is the work.
- **Tooling is less mature.** Event Store, Kurrent, Marten exist; mainstream ORMs don't help.
- **Mental model shift.** Engineers used to CRUD have to learn the events-and-projections pattern.

> [!info] Event sourcing is a niche pattern for systems where audit and time travel are first-class requirements (banking, accounting, regulated systems). It's overkill for most CRUD apps. Don't reach for it because it sounds elegant; reach for it because the audit requirement makes it pay off.

@feynman

The bookkeeper's ledger vs a balance display. The ledger records every transaction; the balance is the current sum. Event sourcing is the ledger as the system of record; the balance is just one view of it.

@card
id: sa-ch11-c006
order: 6
title: CQRS — Command-Query Responsibility Segregation
teaser: Reads and writes go through different models. Writes update the canonical state; reads use specialised projections optimised for the query shape. Useful where the read and write patterns are very different.

@explanation

CQRS — separating the read path from the write path — is a pattern that often shows up alongside event sourcing in event-driven systems.

The shape:

```text
Writes: Command → CommandHandler → Event → EventStore
                                          ↓
Reads:                              QueryHandler → ReadModel
                                          ↑
                                  Projection (consumes events, builds the read model)
```

What you get:

- **Independent scaling.** Reads and writes scale separately. A read-heavy system can have many read replicas; the write path stays small.
- **Optimised models.** The write model is normalised and consistent; read models are denormalised for the queries they serve. Different models for different shapes.
- **Multiple read views.** Same write events feed many read projections. The reporting view, the search view, the dashboard view — all derived.

What it costs:

- **Eventual consistency between writes and reads.** A write is immediately persisted; the projection that updates the read model is async.
- **Complexity.** Two models, projection code, careful synchronisation.
- **Debugging is harder.** "Why doesn't the read reflect my write?" — usually because the projection hasn't caught up.

CQRS without event sourcing is also valid (and simpler). The key idea — separate the model used for writes from the one used for reads — applies any time the read pattern is very different from the write pattern.

> [!warning] CQRS is overused. Most apps don't need separate read and write models. Adopt it when the read patterns genuinely differ from writes; don't adopt it because someone said "use CQRS."

@feynman

Same instinct as building separate dashboards on top of the same database. The database has the data; the dashboards have specific shapes. CQRS formalises the split as part of the architecture.

@card
id: sa-ch11-c007
order: 7
title: Out-of-Order, At-Least-Once, and Other Realities
teaser: Distributed event systems don't deliver events in order, exactly once, or reliably. Designing consumers to handle the realities is most of the work.

@explanation

The realities of event delivery in distributed systems:

- **Out-of-order delivery.** Events from one producer may arrive at the consumer in a different order than they were published.
- **At-least-once delivery.** Events are delivered, but may be delivered more than once. Exactly-once delivery is mostly a marketing term.
- **Late events.** An event from yesterday might arrive today (consumer was down, broker buffered).
- **Lost events.** Despite best efforts, events occasionally vanish. Brokers should have durability guarantees; consumers should still handle the case.

Consumer design that handles these:

- **Idempotent processing.** Processing the same event twice produces the same result. Critical for at-least-once delivery.
- **Order independence.** Where possible, design so the order of events doesn't matter. Where it does matter, use sequence numbers or timestamps to detect and handle.
- **Retries with backoff.** When processing fails, retry. With exponential backoff. With a cap.
- **Dead-letter queues.** Events that consistently fail go to a DLQ; humans investigate.
- **Watermarks.** For time-windowed processing, use watermarks to decide "we've seen all the events for this window."

> [!info] The streaming-frameworks (Flink, Kafka Streams, Beam) handle most of these for you, if you use them properly. Hand-rolling event processing is doable but every team that does it discovers these realities the hard way.

@feynman

The same realities as distributed messaging in general. Mail can arrive out of order, twice, late, or not at all. The receiving end has to be designed for what the postal system actually does, not what we wish it did.

@card
id: sa-ch11-c008
order: 8
title: Observability in Event-Driven Systems
teaser: Tracing an event through five consumers is much harder than reading a stack trace. Observability tooling — distributed tracing, event correlation, schema lineage — is required, not optional.

@explanation

In a synchronous system, debugging is "follow the call stack." In event-driven, the call stack is gone — replaced by an asynchronous web of producers and consumers. Without specialised observability, debugging becomes archaeology.

What event-driven observability needs:

- **Trace IDs propagated across events.** Every event carries the trace ID of its triggering request. Consumers tag downstream events with the same ID.
- **Correlation IDs for sagas.** Multi-step workflows share a saga ID; you can pull all events for one saga.
- **Per-topic / per-consumer dashboards.** Throughput, lag, error rate, DLQ rate. Real time.
- **Schema registry integration.** "What's the latest schema for this event?" answerable without grep.
- **Event browsers.** UI that lets you query "show me all events of type X in the last hour" — like a database, but for events.

Tools in 2026:

- **OpenTelemetry** — covers distributed tracing across event boundaries.
- **Confluent Cloud / Redpanda Cloud** — Kafka with built-in monitoring.
- **AWS X-Ray, Datadog, Honeycomb** — APM with event-aware tracing.
- **Schema Registry, AsyncAPI** — schema lineage and discovery.

> [!warning] Teams that pick event-driven without budgeting for observability tooling pay for it in incident MTTR. The minute you're trying to debug a saga that went wrong without a saga browser, you'll wish you had one.

@feynman

Same as needing logs to debug a non-trivial program. You don't add logging after a problem; you add it before. Event-driven observability is the same — built in or you'll regret it.

@card
id: sa-ch11-c009
order: 9
title: Event-Driven Pitfalls
teaser: Mistaking events for queries. Coupling through schema. Using events for everything. Each is common; each makes the architecture worse than synchronous would have been.

@explanation

The recurring mistakes:

- **Using events for queries.** "I need to ask another service for data, so I'll publish a `RequestUserDetails` event and wait for a `UserDetailsResponse`." That's a synchronous call dressed up as an event; just call the other service.
- **Coupling through event schema.** Producer "knows" what consumers need; events become rich, fragile, and dependency-inverted. The producer should publish what *happened*, not what consumers want.
- **"Everything is an event."** Forcing every interaction through the event system. The 90% of interactions that are simple request-response gain nothing and pay overhead.
- **No idempotency.** Events fire twice; consumers process twice; database has duplicate rows. The retry guarantees forced this — design for it from the start.
- **Event soup.** Hundreds of event types, no discoverability, nobody knows what's published or who consumes. Schema registry and team discipline are the only fixes.
- **Choreography for complex workflows.** When sagas have ten steps and three branches, choreography becomes unmaintainable. Use orchestration.

Each mistake is recoverable but expensive. The architecture that pays attention to these from day one outperforms the one that retrofits.

> [!info] Most "we regret going event-driven" stories trace back to one or more of these. The architecture works when applied carefully; it punishes the casual adoption.

@feynman

Same as adopting any new tool. Most failures aren't about the tool — they're about applying it where it didn't fit, or skipping the discipline the tool demanded. Event-driven is no exception.

@card
id: sa-ch11-c010
order: 10
title: Event-Driven, Pragmatically
teaser: Most production systems use events strategically — for fanout, for cross-team boundaries, for state changes that need audit. Combined with synchronous calls for queries and tight coupling.

@explanation

The honest, pragmatic view of event-driven in 2026:

- **Don't make it the default.** Synchronous calls are simpler. Default to them; reach for events when there's a clear reason.
- **Use events for state changes that fan out.** "OrderPlaced" naturally has many interested consumers; broadcast it.
- **Use events for cross-team boundaries.** Event-driven decoupling is real; teams can ship independently when they're producer/consumer through events.
- **Use events for audit and analytics.** The event log is great for "what happened?" — log every state change.
- **Don't use events for queries.** A query is a question with an immediate answer; events are about what happened.
- **Don't use events for tightly-coupled flows.** When step B can't happen without step A, the orchestration is part of the design — model it as such.

A typical production system might be:

- 80% service-based with synchronous calls.
- 15% event-driven for fanout and async workflows.
- 5% special tooling (sagas, event sourcing, CQRS where it earns its keep).

That mix matches how most successful production systems actually look. The all-events architecture is rare and usually optional.

> [!info] The architecture that calls itself "event-driven" is often actually "service-based with thoughtful events." That naming convention matches reality better and sets expectations correctly for new team members.

@feynman

The same lesson as choosing tools. The right kit has multiple tools; the all-hammer kit makes everything look like a nail. Event-driven is one tool — useful for specific problems, not the answer to everything.
