@chapter
id: apid-ch05-event-driven-apis
order: 5
title: Event-Driven APIs
summary: Webhooks, message queues, and event streams are APIs too — and they need contracts, versioning, ordering guarantees, and replay semantics that look very different from request/response REST.

@card
id: apid-ch05-c001
order: 1
title: Events Are APIs Too
teaser: An event-driven API's contract isn't a URL — it's the event schema, and every consumer that depends on it is a client you have to support.

@explanation

In a REST API, the contract is obvious: you publish a URL, document the request and response shapes, and consumers call it. In an event-driven system, the equivalent contract is the event schema — the structure of the message that flows through your queue, stream, or webhook endpoint.

This framing matters because it changes what you're responsible for:

- **Breaking the schema breaks consumers.** Removing a field, renaming a key, or changing a data type in your event payload is the same category of change as removing an endpoint from a REST API. Consumers will fail silently or loudly, depending on how their parsers are configured.
- **Producers and consumers are decoupled in time, but not in schema.** The whole point of event-driven systems is that the producer doesn't wait for the consumer. But both still need to agree on what the message looks like.
- **The contract needs to be versioned and documented.** Just as you'd version a REST API, you need to version your event schemas. Treating event schemas as "internal implementation details" is how you end up with untracked breaking changes that take down downstream services.
- **Discovery is harder.** REST APIs have URLs and OpenAPI specs. Event-driven APIs need equivalent tooling — AsyncAPI for documentation, schema registries for runtime validation.

The shift in mental model: stop thinking of events as fire-and-forget signals and start thinking of them as typed, versioned, observable API calls that happen to be asynchronous.

> [!info] Every field you add to an event schema that a consumer starts reading is a field you can no longer safely remove or rename without a deprecation window.

@feynman

An event schema is the contract that makes two services strangers who can still work together — like a shared form both parties fill out and rely on, even though they never talk directly.

@card
id: apid-ch05-c002
order: 2
title: Webhooks
teaser: Webhooks are the simplest event-driven pattern — your server pushes HTTP callbacks to a consumer's URL — but delivery, security, and retry semantics require deliberate design.

@explanation

A webhook is an outbound HTTP POST your system sends to a URL registered by the consumer when something interesting happens. GitHub sending a push event to your CI system, Stripe notifying your backend of a payment completion, Twilio confirming a message delivery — these are all webhooks.

The design surface is deceptively small but has sharp edges:

**Signature verification** is non-negotiable. Anyone who knows your webhook endpoint URL can POST fake events to it. The standard defense is HMAC-SHA256: the producer computes a signature over the payload using a shared secret and includes it in a header (`X-Hub-Signature-256` on GitHub, `Stripe-Signature` on Stripe). The consumer verifies the signature before trusting the payload.

```text
HMAC-SHA256(secret, raw_request_body) → signature
```

Use the raw request body for signature computation — not a re-serialized JSON parse — or the signature will mismatch on any whitespace difference.

**Retry semantics** must be defined. If the consumer's endpoint returns a non-2xx status or times out, does the producer retry? How many times? With what backoff? Most webhook platforms (GitHub, Stripe, Shopify) implement exponential backoff with a finite retry window. You need to decide the same for your own webhook system.

**Consumers must be idempotent.** Retries mean duplicate deliveries. A consumer that processes a "payment.completed" event twice and charges the customer twice has a serious bug. Design handlers to be safe to call multiple times with the same event.

> [!warning] Never verify a webhook signature against a parsed-and-re-serialized body. Always verify against the raw bytes exactly as received, or valid signatures will appear invalid.

@feynman

A webhook is like a business that calls you back when your order is ready — instead of you calling every five minutes to check, they ring you once it's done, but you still need to make sure it's really them calling and not a prank.

@card
id: apid-ch05-c003
order: 3
title: AsyncAPI 3.x
teaser: AsyncAPI is the OpenAPI of event-driven APIs — a machine-readable specification for documenting the channels, message schemas, and operations your event system exposes.

@explanation

OpenAPI describes REST APIs. AsyncAPI describes event-driven APIs — the same way, for the same reasons. It gives you a structured, version-controlled, toolable description of what your event system publishes and consumes.

An AsyncAPI document describes:

- **Channels** — the queues, topics, or streams where messages flow (e.g., `orders/created`, `user.signup`).
- **Operations** — whether a channel is published to or subscribed from, and by whom.
- **Messages** — the schemas of the payloads, using JSON Schema or Avro schema references.
- **Bindings** — protocol-specific details for Kafka, AMQP, WebSocket, HTTP, and others.

A minimal AsyncAPI 3.x document looks like:

```yaml
asyncapi: 3.0.0
info:
  title: Order Events API
  version: 1.0.0
channels:
  orders/created:
    messages:
      OrderCreated:
        payload:
          type: object
          properties:
            orderId: { type: string }
            customerId: { type: string }
            total: { type: number }
operations:
  publishOrderCreated:
    action: send
    channel:
      $ref: '#/channels/orders~1created'
```

AsyncAPI has a growing ecosystem: `@asyncapi/generator` can produce HTML docs, TypeScript types, and boilerplate consumers from the spec. AsyncAPI Studio provides a browser-based editor with real-time validation.

The discipline it enforces is the same as OpenAPI: the spec becomes the source of truth, changes go through the spec first, and consumers can generate typed clients from it.

> [!tip] Commit your AsyncAPI spec to the same repository as your producer code and enforce spec-first reviews. A schema change that doesn't update the spec is a breaking change waiting to be discovered by a consumer.

@feynman

AsyncAPI is the blueprint for your event system — the same way an architect's floor plan tells contractors exactly where every wall and door goes before anyone picks up a hammer.

@card
id: apid-ch05-c004
order: 4
title: Event Schema Design
teaser: Every event should carry a standard envelope of fields — id, type, version, timestamp, and source — so consumers can route, deduplicate, and evolve without parsing the payload first.

@explanation

A well-designed event schema separates the envelope from the payload. The envelope is a fixed set of fields that every event in your system carries, regardless of what it represents. The payload is the event-specific data.

The envelope fields and why they exist:

- **`id`** — a unique identifier for this specific event instance (UUID or ULID). Used by consumers to deduplicate: if the same event arrives twice, the same `id` should produce the same outcome.
- **`type`** — a namespaced string identifying what happened (e.g., `com.example.order.created`). Used for routing, filtering, and schema lookup.
- **`version`** — the schema version of the payload (e.g., `1`, `2`, or semver). Used by consumers to know which deserialization path to use.
- **`timestamp`** — the time the event occurred in the producer's system, as ISO 8601 UTC. Not the time the message was enqueued — the time the thing happened.
- **`source`** — the service or component that produced the event. Critical for debugging in systems with many producers.

```json
{
  "id": "01H8GV3K9P2N4VXQT7R6WB5MJ1",
  "type": "com.example.order.created",
  "version": "1",
  "timestamp": "2024-03-15T14:23:00Z",
  "source": "order-service",
  "data": {
    "orderId": "ORD-4521",
    "customerId": "CUST-99",
    "total": 149.99
  }
}
```

Keep the envelope stable across versions. Only the `data` field evolves between schema versions. This lets consumers implement generic envelope handling once and version-specific payload parsing separately.

> [!info] The `id` field is not optional. Without a stable unique identifier per event, you cannot safely implement idempotent consumers, and deduplication becomes guesswork.

@feynman

An event envelope is like the address and postmark on a letter — it tells you who sent it, when, and what kind of mail it is before you ever open the envelope and read what's inside.

@card
id: apid-ch05-c005
order: 5
title: CloudEvents Specification
teaser: CloudEvents is a CNCF specification for a standard event envelope — the same required fields, the same header names, across Kafka, HTTP, AMQP, and every other transport.

@explanation

CloudEvents is a Cloud Native Computing Foundation (CNCF) specification that standardizes the envelope around an event payload. It solves the "everyone invents their own envelope" problem by defining a common set of required and optional attributes and specifying how they map to different transports.

Required CloudEvents attributes:

- **`specversion`** — the CloudEvents spec version, currently `"1.0"`.
- **`id`** — unique identifier for the event, scoped to `source`.
- **`source`** — identifies the event producer (a URI or URI-reference).
- **`type`** — a reverse-DNS namespaced string describing the event type.

Optional but widely used: `datacontenttype`, `subject`, `time`, `dataschema`.

```json
{
  "specversion": "1.0",
  "type": "com.example.order.created",
  "source": "https://api.example.com/orders",
  "id": "abc-123",
  "time": "2024-03-15T14:23:00Z",
  "datacontenttype": "application/json",
  "data": {
    "orderId": "ORD-4521",
    "total": 149.99
  }
}
```

CloudEvents defines bindings for HTTP, Kafka, AMQP, MQTT, and WebSocket — so the same logical event can be transported across different infrastructure without re-mapping attribute names.

**When to use it:** CloudEvents pays off when your events need to cross system boundaries — between organizations, between cloud providers (AWS EventBridge, GCP Pub/Sub, and Azure Event Grid all support CloudEvents natively), or into open-source tooling that understands the spec.

**When it's overkill:** For an internal single-platform event system where you control all producers and consumers, a custom envelope with the same fields is equally valid.

> [!tip] AWS EventBridge, GCP Eventarc, and Azure Event Grid all accept or emit CloudEvents. If you're building on any of these, adopting the spec means your events are already in the right shape for cross-service routing.

@feynman

CloudEvents is like agreeing on a universal shipping label standard — once every courier uses the same label format, any warehouse can read, sort, and route any package without needing to know which courier dropped it off.

@card
id: apid-ch05-c006
order: 6
title: Message Queues vs Event Streams
teaser: A queue like RabbitMQ or AWS SQS delivers each message to one consumer and deletes it on acknowledgment; a stream like Kafka retains all events in a durable log and lets multiple consumers read independently — these are fundamentally different models.

@explanation

The terms "queue" and "stream" are often used interchangeably. They shouldn't be. They represent different data structures with different semantics.

**Message queues (RabbitMQ, AWS SQS, AWS SNS):**

- Each message is delivered to one consumer (competing consumers share load).
- The message is deleted from the queue once acknowledged.
- Consumers cannot replay past messages — they're gone.
- Ideal for task distribution: send an email, resize an image, process a payment.
- RabbitMQ is AMQP-based, feature-rich, and runs on-premises or in the cloud. SQS is fully managed and integrates tightly with other AWS services.

**Event streams (Apache Kafka, AWS Kinesis, GCP Pub/Sub, Confluent Cloud):**

- Events are written to a durable, ordered, append-only log partitioned across brokers.
- Multiple consumer groups read the same log independently at their own offset.
- Events are retained for a configurable period (hours, days, forever with Kafka's tiered storage).
- Consumers can replay from any offset — reprocessing historical data, backfilling a new service, recovering from a bug.
- Ideal for event sourcing, audit logs, data pipelines, and anything that needs multiple consumers or replay.

The architectural consequences are large:

- With a queue, adding a second consumer for the same event requires a fan-out topology (SNS → multiple SQS queues). With a stream, the second consumer just creates a new consumer group.
- With a queue, you cannot recover the state of what happened last Tuesday without a separate audit log. With a stream, you can replay to reconstruct it.

> [!warning] If you choose a queue and later discover you need replay or multiple independent consumers, migrating to a stream is a significant architectural change. Make the model decision deliberately.

@feynman

A message queue is like a to-do list where tasks disappear once checked off; an event stream is like a ledger where every entry is permanent and any auditor can come along later and read the whole history from the beginning.

@card
id: apid-ch05-c007
order: 7
title: Delivery Guarantees
teaser: At-most-once, at-least-once, and exactly-once delivery are not settings you pick from a menu — each comes with a real cost in latency, throughput, complexity, or infrastructure.

@explanation

Every messaging system makes a choice about what it guarantees when a message is in transit.

**At-most-once:** The message is sent and the system moves on. If the consumer crashes before processing, the message is lost. No retries, no acknowledgment required.
- Cost: nothing extra. 
- Trade-off: data loss is possible.
- Use when: telemetry, metrics, or any signal where losing some data is acceptable and throughput matters more than completeness.

**At-least-once:** The producer waits for an acknowledgment. If it doesn't arrive in time, the message is re-sent. The consumer may see the same message more than once.
- Cost: retry logic on the producer, acknowledgment round-trips, slightly higher latency.
- Trade-off: duplicate delivery is possible and expected.
- Use when: most business event systems. This is the default for Kafka (with `acks=all`), SQS, and RabbitMQ with manual acknowledgment.
- **Consumers must be idempotent** — processing the same message twice must produce the same result as processing it once.

**Exactly-once:** The message is delivered and processed exactly one time, with no duplicates and no loss.
- Cost: distributed transactions or idempotent producers + transactional consumers + coordination overhead. Kafka achieves this with idempotent producers and transactional APIs, but at a meaningful throughput cost.
- Trade-off: complexity, reduced throughput, and the guarantee only holds within the system boundary (not end-to-end through your database writes).
- Use when: financial transactions or regulatory requirements where duplicates cause real harm and you can absorb the cost.

The practical guidance: design for at-least-once, build idempotent consumers, and reach for exactly-once only when the business case justifies the infrastructure complexity.

> [!warning] "Exactly-once" guarantees in Kafka and similar systems apply to message delivery within the broker. They do not guarantee that your downstream database write or external API call also happens exactly once. End-to-end exactly-once still requires idempotency in your consumers.

@feynman

Delivery guarantees are like shipping insurance tiers — at-most-once is sending a letter with no tracking, at-least-once is certified mail that gets re-sent if undelivered, and exactly-once is a courier with a signed receipt and a locked box — more assurance costs more effort.

@card
id: apid-ch05-c008
order: 8
title: Ordering Guarantees
teaser: Strict global ordering across a distributed system is expensive to the point of impracticality — partition-based ordering (per-key or per-partition) is the design Kafka and most real systems actually use.

@explanation

When a consumer processes events out of order — applying an account update before the account creation event that preceded it — bugs follow. Ordering guarantees determine how your system prevents or manages this.

**Total ordering:** Every message across all partitions is processed in the exact sequence it was written. This requires a single partition or a serialized global log. It eliminates concurrency entirely, which limits throughput to what a single node can handle. For most production workloads, total ordering is an anti-pattern — the throughput ceiling is too low.

**Partition-based ordering (Kafka's model):** Within a single partition, Kafka guarantees strict ordering. Across partitions, there is no ordering guarantee. The design pattern is to route all events for a given key (a customer ID, an order ID) to the same partition by using that key as the partition key.

```text
partition = hash(key) % num_partitions
```

All events for `customerId: CUST-99` land in the same partition and are processed in order. Events for different customers may be interleaved, but that's safe because they don't share state.

**Per-key ordering with consumer groups:** Each partition is consumed by exactly one consumer in a consumer group at any time, which maintains the ordering guarantee through the full processing pipeline.

The constraint this imposes: hot keys (one customer generating 10,000x more events than average) will saturate a single partition while others sit idle. Design your partition key to distribute load, not just enforce ordering.

AWS Kinesis uses the same model — a partition key determines the shard, and ordering is guaranteed within a shard.

> [!info] Choosing a good partition key is a balancing act between ordering (needs same-key co-location) and throughput (needs even distribution). Customer ID works for most business domains. A single tenant ID for a multi-tenant system does not.

@feynman

Ordering in a distributed event stream is like sorting mail at a post office — you can guarantee every letter to the same address arrives in order because it all goes through the same sorting bin, but you make no promises about the order between letters going to different addresses.

@card
id: apid-ch05-c009
order: 9
title: Idempotency in Event Consumers
teaser: At-least-once delivery makes duplicate events inevitable — an idempotent consumer handles the same event twice with the same result as handling it once, using the event's id as the deduplication key.

@explanation

In any system with at-least-once delivery, your consumers will receive duplicates. A network timeout causes a re-delivery. A consumer crashes mid-processing and the message is re-queued. A deployment restart replays from the last committed offset. The right response is to design consumers that are safe to call multiple times.

**The duplicate-safe handler pattern:**

1. Extract the event `id` from the envelope.
2. Check a deduplication store (a Redis set, a database table with a unique index, or an idempotency key column) for whether this `id` has already been processed.
3. If yes, return success without re-processing.
4. If no, process the event, then record the `id` as processed atomically with the side effect.

```text
BEGIN TRANSACTION
  IF NOT EXISTS (SELECT 1 FROM processed_events WHERE event_id = :id)
    -- apply business logic
    INSERT INTO processed_events (event_id, processed_at) VALUES (:id, NOW())
END TRANSACTION
```

The atomicity of step 4 matters: recording the `id` and applying the effect must succeed or fail together. If you record the `id` first and the side effect fails, you'll skip the event next time. If you apply the effect first and the recording fails, you'll process it twice.

**Idempotency key TTL:** Storing every event `id` forever is impractical. Set a retention window based on your retry window — if your system retries for at most 72 hours, keeping idempotency keys for 7 days provides a comfortable buffer.

AWS SQS provides a `MessageDeduplicationId` field for FIFO queues that handles deduplication within a 5-minute window at the broker level, reducing (but not eliminating) the need for consumer-side deduplication.

> [!tip] Test your consumers by replaying the same event sequence twice and asserting that the system state is identical after both runs. If it isn't, your consumer is not idempotent.

@feynman

An idempotent consumer is like a cashier who checks the receipt before ringing you up again — if your order is already in the system with the same ticket number, they say "already done" and move on instead of charging you twice.

@card
id: apid-ch05-c010
order: 10
title: Schema Evolution for Events
teaser: Event schemas must evolve without breaking existing consumers — schema registries, backwards/forwards compatibility rules, and a clear versioning strategy are the tools that make this possible.

@explanation

A REST API can version its endpoints with a path prefix (`/v2/orders`). An event schema cannot version itself through a URL — it must carry its version in the message and rely on consumers to handle multiple versions gracefully.

**Backwards compatibility** means new schema versions can be read by consumers built against the old schema:
- Safe: adding optional fields with defaults.
- Safe: adding new optional fields.
- Unsafe: removing fields, renaming fields, changing a field's type.

**Forwards compatibility** means old schema versions can be read by consumers built against the new schema:
- Safe: new consumers ignore fields they don't recognize.
- Unsafe: new consumers require fields that older producers don't emit.

**Schema Registry (Confluent Schema Registry, AWS Glue Schema Registry):** A centralized service where schemas are registered, versioned, and validated. Producers serialize using the registry-assigned schema ID; consumers look up the schema ID from the message to deserialize. The registry enforces compatibility rules at publish time — it rejects a schema change that would break registered consumers.

```text
Producer → encode(payload, schema_id=42) → Kafka topic
Consumer → decode(message) → lookup(schema_id=42) → deserialize
```

Confluent Schema Registry supports Avro, JSON Schema, and Protobuf. Avro is the most common in Kafka ecosystems because its binary encoding is compact and its schema evolution rules map cleanly to backwards/forwards compatibility requirements.

The workflow: treat schema changes like API changes — propose the new schema version, validate compatibility in the registry, merge it, then update producers before consumers for additive changes, or consumers before producers for removals.

> [!warning] Renaming a field in a Kafka event schema is a breaking change for every deployed consumer. There is no rename — only adding a new field and deprecating the old one over a migration window.

@feynman

A schema registry is like an official dictionary that all departments in a company must agree to update together — before you can change what a word means, everyone who uses it has to be notified and given time to adapt.

@card
id: apid-ch05-c011
order: 11
title: Choreography vs Orchestration
teaser: In choreography, services react to events and produce new ones with no central coordinator; in orchestration, a central process directs each step — the right choice depends on complexity, observability needs, and failure handling.

@explanation

When a business process spans multiple services — "place order → reserve inventory → charge payment → send confirmation" — you have two architectural options for coordinating the steps.

**Choreography:** Each service listens for events and emits its own. No service knows the full workflow. The order service emits `order.created`. The inventory service hears it and emits `inventory.reserved`. The payment service hears that and emits `payment.charged`. No central coordinator exists.

- Advantages: services are fully decoupled, easy to add new participants, resilient to individual service failures.
- Disadvantages: the workflow is implicit — it exists only as emergent behavior across service logs. Debugging a failure means tracing events across multiple services. Adding compensation logic (what happens if payment fails after inventory is reserved?) requires every service to listen for failure events and clean up its own state.

**Orchestration:** A central process (orchestrator or saga coordinator) explicitly tells each service what to do. The orchestrator sends "reserve inventory" to the inventory service, waits for a response, then sends "charge payment" to the payment service.

- Advantages: the workflow is explicit and visible in one place. Failure paths and compensating transactions are centrally managed.
- Disadvantages: introduces a central coupling point and a potential single point of failure. The orchestrator itself becomes a service that needs testing, versioning, and deployment.

**The saga pattern** applies to both: a saga is a sequence of local transactions with compensating transactions for rollback. In choreography, sagas are coordination-free but hard to observe. In orchestration, sagas are visible but centralized.

AWS Step Functions, Temporal, and Conductor are popular orchestrators. Kafka-based choreography often uses distributed tracing (OpenTelemetry) to reconstruct workflow visibility.

> [!info] Choreography complexity grows roughly as the square of the number of services involved. For two or three services, it's clean. For eight services with multiple failure paths, the implicit workflow becomes very difficult to reason about.

@feynman

Choreography is like a jazz ensemble where each musician listens and responds to the others without a conductor; orchestration is a classical orchestra where every musician follows a conductor who controls the sequence and timing of every part.

@card
id: apid-ch05-c012
order: 12
title: Dead-Letter Queues
teaser: A dead-letter queue captures events that fail processing repeatedly — it's the circuit breaker that prevents one bad message from blocking an entire consumer, and it's where you go when something is wrong.

@explanation

In any event-driven system, some messages will fail to process. The payload might be malformed. The downstream dependency might be down. A bug in consumer code might throw on a specific input. Without a dead-letter queue (DLQ), these "poisoned" messages either block the queue indefinitely or are silently dropped.

A DLQ is a separate queue (or topic) where messages are moved after exhausting their retry attempts. The main queue stays unblocked. The failed messages are preserved for inspection and reprocessing.

**The standard DLQ workflow:**

1. Consumer attempts to process the message.
2. Processing fails. The message is returned to the queue and becomes eligible for retry.
3. After N failed attempts (the `maxReceiveCount` in SQS, the `delivery.attempt.max` in GCP Pub/Sub), the message is moved to the DLQ.
4. An alert fires on DLQ depth.
5. An engineer investigates: is it a poisoned payload (bad data), a bug in the consumer, or a transient infrastructure failure?
6. The engineer either discards the message (if it's genuinely unprocessable garbage) or fixes the consumer and replays the message from the DLQ back to the main queue.

In Kafka, DLQs are implemented as separate topics. The consumer catches processing exceptions and explicitly produces the failed message to the DLQ topic rather than committing the offset.

```text
try {
  process(event)
  consumer.commitSync()
} catch (e) {
  dlqProducer.send(dlqTopic, event, errorMetadata)
  consumer.commitSync()
}
```

**What to include in the DLQ message:** the original event plus metadata — the error message, stack trace, processing attempt count, and the consumer version that failed. This information makes the "investigate" step possible without re-running code to reproduce the failure.

> [!warning] A DLQ without an alert on its depth is a silent failure. Messages pile up unnoticed for days before someone checks. Alert on any DLQ message within minutes of arrival.

@feynman

A dead-letter queue is like a triage bin at a hospital — when a case is too complex to handle on the normal flow, it's set aside in a labeled queue so specialists can investigate without blocking everyone else waiting to be seen.
