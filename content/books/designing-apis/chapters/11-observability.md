@chapter
id: apid-ch11-observability
order: 11
title: Observability
summary: APIs are observable when you can answer three questions in production — what's happening now, why did this request fail, and which slow path actually moved the SLO — and the OpenTelemetry-based stack of metrics, traces, and logs is the standard answer.

@card
id: apid-ch11-c001
order: 1
title: The Three Questions of Observability
teaser: Observability is not a dashboard — it's the ability to answer three operational questions about your API in production without deploying a new build.

@explanation

The framing comes from control theory: a system is observable if you can determine its internal state from its outputs. Applied to APIs, that means three concrete questions you must be able to answer at 2 a.m. without guessing:

- **What is happening right now?** Is the service healthy? What is the current request rate, error rate, and latency? This is the metrics question.
- **Why did this specific request fail?** What path did request `abc-123` actually take through the system? Which downstream call timed out, and how long did each hop take? This is the traces question.
- **Which slow path is actually moving the SLO?** Of the hundred things that could be optimized, which one is responsible for the most SLO burn this week? This requires correlating metrics, traces, and logs together.

Each signal answers a different question. Metrics give you aggregated health at low cost. Traces give you per-request causality. Logs give you raw event detail. The three are complementary, not substitutes — teams that instrument only logs and call it observability find themselves doing expensive log grep operations for questions that a counter would answer in milliseconds.

The cost discipline that follows from this framing: only collect what answers one of the three questions. Data collected for "maybe someday" reasons is where observability budgets go to die.

> [!tip] When evaluating an observability tool or deciding what to instrument, map each signal back to one of the three questions. If you cannot articulate which question a metric or log line answers, it probably should not be collected.

@feynman

Observability is your ability to diagnose your API's health and failures from the outside — the way a doctor diagnoses a patient from symptoms rather than opening them up.

@card
id: apid-ch11-c002
order: 2
title: The Three Signals — Metrics, Traces, and Logs
teaser: Metrics, traces, and logs each answer a fundamentally different question — using the wrong signal for the question is why debugging often feels harder than it should.

@explanation

**Metrics** are numeric measurements aggregated over time — counters, gauges, and histograms. They are cheap to store and query because they discard the detail of individual events. A counter of HTTP 500 responses tells you the error rate; it does not tell you which user, which endpoint, or why. Prometheus is the dominant open-source metrics store; virtually every observability vendor ingests Prometheus-format data.

**Traces** are records of a single request's journey through a distributed system. A trace is made up of spans — one per unit of work (a database call, an HTTP request to a downstream service, a queue publish). Traces answer causality questions that metrics cannot: "did the slowdown originate in my service or in the downstream authentication API?" Jaeger is the canonical open-source trace backend; Tempo (from Grafana) is the scalable object-storage-backed alternative.

**Logs** are timestamped records of discrete events — errors, state transitions, debug output. They are the highest-fidelity signal and the most expensive to store and query at scale. Logs are best used for capturing events that cannot be expressed as a number (exception stack traces, user actions, audit records). Loki (Grafana) and Elasticsearch are common log backends.

The signals interact:

- A metric alert fires; you pivot to a trace to find the slow span; the trace carries a log correlation ID; you pull the full log context for that request.
- Without correlation IDs linking all three, each signal is an island.

> [!info] The term "three pillars of observability" is widely used but slightly misleading — the signals are not equal in cost or cardinality. Metrics are cheap and coarse; traces are medium cost and per-request; logs are expensive and high-fidelity. Budget accordingly.

@feynman

Metrics tell you your car's speed and fuel level; traces show you the exact route you took to get here; logs are the voice recorder capturing everything anyone said during the drive.

@card
id: apid-ch11-c003
order: 3
title: RED Metrics — Rate, Errors, Duration
teaser: RED gives you the three numbers that summarize service health from the consumer's perspective — how busy is it, is it succeeding, and how fast is it responding.

@explanation

RED was popularized by Tom Wilkie and is the standard starting point for API service health monitoring:

- **Rate** — requests per second (or per minute). This is your load signal. A sudden drop often indicates a problem upstream; a sudden spike may indicate a traffic anomaly.
- **Errors** — the proportion of requests that return an error. This requires defining what counts as an error: HTTP 5xx responses, timeouts, and application-level error codes all need to be counted. HTTP 4xx is a judgment call — a 404 is probably the caller's fault; a 429 may indicate a capacity problem.
- **Duration** — the distribution of request latency, typically reported as percentiles (p50, p95, p99). Mean latency is a dangerous metric because it hides the long tail. A service where 50% of requests complete in 10 ms and 1% complete in 10 seconds has a fine mean and a terrible p99.

In Prometheus exposition format, these translate to:

```
# Rate: counter
http_requests_total{method="POST", status="200", endpoint="/orders"}

# Errors: counter
http_requests_total{method="POST", status="500", endpoint="/orders"}

# Duration: histogram
http_request_duration_seconds_bucket{le="0.1", endpoint="/orders"}
http_request_duration_seconds_bucket{le="1.0", endpoint="/orders"}
http_request_duration_seconds_count{endpoint="/orders"}
http_request_duration_seconds_sum{endpoint="/orders"}
```

RED metrics are the first thing to instrument in a new service and the first thing to check when an alert fires. They are intentionally narrow — they describe what the service is doing from the outside, not why.

@feynman

RED is like the three gauges on a car dashboard that matter most — speedometer (rate), warning light (errors), and temperature (latency) — everything else is detail you check when one of these looks wrong.

@card
id: apid-ch11-c004
order: 4
title: USE Metrics — Utilization, Saturation, Errors
teaser: USE complements RED by looking at the resources underneath the service — the CPU, memory, connections, and queues that constrain what the service can do.

@explanation

USE was defined by Brendan Gregg and focuses on resource health rather than service health:

- **Utilization** — what percentage of the resource's capacity is in use? CPU at 80%, memory at 60%, database connection pool at 90%.
- **Saturation** — how much work is waiting for the resource that is currently full? Thread pool queue depth, request queue length, disk I/O wait time. Saturation is the leading indicator of latency degradation — by the time utilization hits 100%, queues are already building.
- **Errors** — resource-level errors: dropped packets, failed disk writes, OOM kills, connection refused counts.

RED tells you a service is slow; USE tells you why. If RED shows high p99 latency and USE shows the database connection pool is at 95% utilization with a non-zero queue depth, you have a diagnosis.

Typical USE metrics for an API service:

- CPU utilization and throttle percentage (for containerized workloads, the throttle percentage often matters more than raw utilization)
- Memory utilization and OOM event count
- Database connection pool: active, idle, waiting, max
- Thread pool queue depth
- Network bandwidth utilization and packet error rate

USE and RED together give you a complete picture: RED describes the symptoms; USE describes the cause.

> [!info] For containerized APIs, CPU throttle percentage is often more diagnostic than CPU utilization percentage. A container can show 40% CPU utilization while being throttled 60% of the time if its CPU limit is set too low relative to its request.

@feynman

If RED tells you the service is sick, USE tells you which organ is failing — it looks at the resources the service depends on rather than the service's external behavior.

@card
id: apid-ch11-c005
order: 5
title: Distributed Tracing — Spans, Context Propagation, and Sampling
teaser: A trace stitches together every span of work a request touched across all services — but it only works if every service in the path participates in context propagation.

@explanation

A **trace** represents a single end-to-end request. It has a unique `trace_id`. Every unit of work within that request is a **span**, which records:

- A unique `span_id`
- The `trace_id` it belongs to
- A `parent_span_id` linking it to the span that initiated it
- Start time and duration
- Service name, operation name
- Status (OK, error)
- Attributes (HTTP method, DB query, status code, etc.)
- Events (timestamped log-like records attached to the span)

Spans form a tree. The root span is typically the inbound HTTP request. Child spans are created for downstream calls — database queries, cache reads, outbound HTTP calls to other services, queue publishes.

**Context propagation** is the mechanism that carries the `trace_id` and `parent_span_id` across service boundaries. Without it, every service sees only its own isolated spans. Propagation works by injecting the trace context into the HTTP request headers (via W3C Trace Context, discussed in the next card) and extracting it on the receiving end. Every service in the request path must extract, continue, and re-inject the context.

**Sampling** is mandatory at scale. Recording every span for every request at 10,000 RPS produces enormous data volumes that are expensive to store and query. The two main strategies:

- **Head-based sampling** — the decision to record or drop is made at the root span, before downstream spans are created. Simple and cheap; the tradeoff is that you cannot bias toward interesting requests because you haven't seen them yet.
- **Tail-based sampling** — the decision is made after the trace is complete, allowing you to keep all error traces and slow traces regardless of sampling rate. More expensive because all spans must be buffered until the decision is made.

@feynman

A distributed trace is like a flight itinerary that follows your request through every airport layover — each hop is a span, and the trace shows you the whole journey and where the delay actually happened.

@card
id: apid-ch11-c006
order: 6
title: OpenTelemetry — SDK, Protocol, and What It Has and Hasn't Replaced
teaser: OpenTelemetry is the vendor-neutral standard for instrumentation — it defines how you emit metrics, traces, and logs, not where they go, which is why it coexists with every major backend.

@explanation

OpenTelemetry (OTel) is a CNCF project that provides:

- **Language SDKs** — libraries for Go, Java, Python, Node.js, .NET, Ruby, and others that provide APIs for creating spans, recording metrics, and emitting logs in a standardized way.
- **Automatic instrumentation** — agents or bytecode instrumentation that add tracing to popular frameworks (Express, Django, Spring, gRPC, database drivers) without code changes.
- **OTLP (OpenTelemetry Protocol)** — the wire format for exporting telemetry. OTLP is gRPC-based (with an HTTP/JSON variant) and is now the native ingestion format for Datadog, Honeycomb, New Relic, Grafana Cloud, and most other vendors.
- **The Collector** — a standalone proxy/pipeline that receives telemetry from services, applies transformations and filtering, and exports to one or more backends. Running a Collector lets you change backends without touching application code.

What OpenTelemetry **has** replaced:

- Vendor-specific SDKs for instrumentation. You no longer need to install the Datadog or New Relic SDK into your application. You instrument with OTel and send OTLP to whatever backend you choose.
- Custom propagation formats in most new services.

What OpenTelemetry **has not** replaced:

- Backends and storage. OpenTelemetry emits data; you still need Prometheus, Jaeger, Tempo, Loki, or a vendor to store and query it.
- Alert configuration, dashboards, and SLO tracking. These remain backend-specific.
- The Prometheus scrape model. Prometheus still uses its own pull-based format. OTel metrics can be exported via a Prometheus exporter, but the two models are not identical.

> [!tip] Use the OTel Collector even in a single-backend setup. It decouples your services from the backend, makes it trivial to add a second destination (e.g., send to both Grafana and a security SIEM), and lets you apply sampling and filtering centrally.

@feynman

OpenTelemetry is the universal power adapter for observability — it gives every service a standard plug so you can connect to any backend without rewiring the device.

@card
id: apid-ch11-c007
order: 7
title: W3C Trace Context — traceparent, tracestate, and Cross-Service Correlation
teaser: W3C Trace Context is the HTTP header standard that lets services pass trace IDs across the boundary — without it, every service's spans are disconnected islands.

@explanation

W3C Trace Context is a W3C Recommendation (not just a de facto convention) that defines two HTTP headers:

**`traceparent`** carries the core propagation data:

```http
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```

The four fields, dash-separated:
- `00` — version (currently always `00`)
- `4bf92f3577b34da6a3ce929d0e0e4736` — trace ID (16 bytes / 32 hex chars), unique per trace
- `00f067aa0ba902b7` — parent span ID (8 bytes / 16 hex chars), the span that made this call
- `01` — trace flags (`01` = sampled, `00` = not sampled)

**`tracestate`** is an optional vendor extension field for carrying additional, vendor-specific context alongside the standard trace ID:

```http
tracestate: vendorname=opaquevalue
```

How it works in practice: service A receives an inbound request, creates a root span, and injects `traceparent` into every outbound call. Service B extracts `traceparent`, creates a child span with service A's span ID as its `parent_span_id`, does its work, and injects a new `traceparent` (with its own span ID in the parent field) into calls to service C. The `trace_id` is unchanged through the whole chain.

The alternative header format `b3` (from Zipkin) is still found in older services. Most OTel SDKs support both; if you operate a mixed environment, configure the SDK to propagate both formats during the transition period.

@feynman

`traceparent` is like a baton in a relay race — each service passes it to the next, ensuring every runner can be linked back to the same race without anyone having to carry the whole story from the start.

@card
id: apid-ch11-c008
order: 8
title: Structured Logging — JSON Logs, Correlation IDs, and the Log-Once Rule
teaser: Structured logs are queryable because machines write them; correlation IDs make them useful because they connect a log line to the trace and request that produced it.

@explanation

Unstructured logs are human-readable strings. Structured logs are machine-readable objects — typically JSON — where every field has a name and a queryable value.

A structured log line:

```json
{
  "timestamp": "2025-03-14T09:26:53Z",
  "level": "error",
  "service": "orders-api",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "request_id": "req-7f3a1b",
  "user_id": "u-1234",
  "message": "payment gateway timeout",
  "duration_ms": 5001,
  "gateway": "stripe",
  "http_status": 504
}
```

Key fields:

- **`trace_id` and `span_id`** link the log line to the active OTel trace. Loki and Grafana can pivot from a log to its trace automatically when these fields are present.
- **`request_id`** / **`correlation_id`** — a stable identifier for the inbound request. Useful in systems that predate OTel adoption.
- **Structured fields for queryable data** — duration, status codes, identifiers, error types. Never embed these in the message string.

**The log-once rule:** emit one log entry per logical event. Logging the same error at every layer of the call stack produces duplicate log lines that inflate storage costs and confuse aggregations. Log at the point of origination; re-throw or propagate context without re-logging.

**What belongs in logs vs traces:** Log lines are for events with discrete, non-numeric detail (stack traces, request bodies for debugging). Use span attributes and events for structured data that belongs on the trace. Duplicating everything into both is expensive.

> [!warning] Never log high-cardinality PII (email addresses, full request bodies, SSNs) in production logs. Structured logging makes it easy to add fields — which also makes it easy to accidentally log data that violates GDPR or HIPAA requirements.

@feynman

Structured logging is the difference between a librarian's card catalog and a pile of sticky notes — both have the same information, but only one can answer a query in under a second.

@card
id: apid-ch11-c009
order: 9
title: Cardinality Discipline — Why High-Cardinality Labels Break Metrics
teaser: Adding a user ID as a metric label feels like more observability — until it creates ten million time series and brings your metrics backend to its knees.

@explanation

**Cardinality** in the context of metrics is the number of unique time series a metric has, determined by the unique combinations of its label values. A metric with labels `{method, status, endpoint}` across 5 HTTP methods, 10 status codes, and 20 endpoints has 1,000 time series — manageable. Add a `user_id` label with 1 million users and you have 1 billion time series. Prometheus will OOM. Datadog will invoice you aggressively.

Common high-cardinality label sources:

- User IDs, account IDs, session tokens
- Full URL paths with embedded IDs (`/orders/12345` instead of `/orders/{id}`)
- Request IDs or trace IDs
- Dynamic hostnames or pod names beyond a modest fleet
- Free-form error messages

What to do instead:

- Use cardinality-bounded labels only: HTTP method, status code, normalized path template, service name, region, environment.
- Put high-cardinality fields in **traces and logs**, which are designed for per-event storage — not in metrics, which aggregate.
- Normalize dynamic path segments before labeling: `/orders/12345` → `/orders/{order_id}`.

A practical cardinality audit in Prometheus:

```
# Find metrics with the most time series
sort_desc(count by (__name__)({__name__=~".+"}))
```

Most metrics backends have a cardinality limit — Prometheus's default is 2 million active series. Exceeding it causes scrape failures and data loss, not a graceful error.

> [!warning] Cardinality problems are insidious because they grow gradually. A new label that seems fine at 1,000 users becomes catastrophic at 100,000. Review label additions against your total user/entity count before shipping.

@feynman

Adding a user ID to a metric label is like making a separate column in a spreadsheet for every customer instead of one column for "customer type" — the spreadsheet explodes before you can read it.

@card
id: apid-ch11-c010
order: 10
title: Sampling Strategies — Head-Based, Tail-Based, and When Each Fits
teaser: Sampling is not optional at scale — the choice between head-based and tail-based sampling determines whether you can guarantee capturing the traces that actually matter.

@explanation

At 10,000 RPS, recording every span at 100% sampling produces roughly 86 billion spans per day. No team has the budget for that, and querying it would be impractical. Sampling discards most traces while retaining a representative or strategically selected subset.

**Head-based sampling:**

The decision to record or drop is made at the start of the trace — at the root span, before any downstream calls are made. A common implementation: sample 1% of all requests uniformly, or 100% of requests from a specific test tenant.

- Advantages: simple, low memory overhead, no buffering required, consistent decision propagates via `traceparent` flags.
- Disadvantages: you cannot bias toward interesting traces because you have not seen them yet. A rare error that occurs in 0.01% of requests may be dropped entirely at a 1% sample rate.

**Tail-based sampling:**

The decision is made after the trace is complete. All spans are buffered in a collector or sampling proxy until the full trace arrives, then a rule engine decides: keep all error traces, keep all traces over 1 second, drop everything else at 1%.

- Advantages: guarantees capture of errors and slow traces regardless of overall sample rate. This is the most operationally useful strategy.
- Disadvantages: requires buffering all in-flight spans in the collector (memory-intensive at high RPS), more complex to operate, and introduces a delay before traces are written.

The OTel Collector supports tail-based sampling via the `tailsampling` processor. Honeycomb's Refinery is a purpose-built tail-sampling proxy.

A common hybrid: head-based sampling for high-RPS healthy traffic (1%); tail-based sampling at the collector layer that overrides to keep all errors and p99+ latency traces.

@feynman

Head-based sampling is deciding to record a phone call before it starts; tail-based sampling is deciding whether to keep the recording after you've heard how the call ended — and only the second approach guarantees you always keep the calls that went wrong.

@card
id: apid-ch11-c011
order: 11
title: Service-Level Objectives — What to Measure, Error Budgets, and Burn Rate Alerting
teaser: An SLO is a promise about your API's reliability expressed as a percentage — and an error budget is the budget you have to spend on incidents, deployments, and experiments before you break the promise.

@explanation

**SLI (Service Level Indicator):** The metric you measure. For APIs, the most common SLIs are:

- Availability: proportion of requests that return a non-5xx response
- Latency: proportion of requests that complete under a threshold (e.g., under 500 ms)
- Error rate: proportion of requests that return an error

**SLO (Service Level Objective):** The target. "99.9% of requests return a non-5xx response over a 30-day rolling window." This translates to 43.8 minutes of allowable downtime per month.

**Error budget:** `1 - SLO target`. A 99.9% SLO has a 0.1% error budget. If your current window has consumed 80% of the error budget, you have 20% left. Error budgets create shared accountability between development (who wants to ship) and operations (who wants stability) — both teams spend from the same budget.

**Burn rate alerting** is the operationally important part. Instead of alerting when you breach the SLO, alert when you are consuming the error budget too fast. A burn rate of 1x means you will exactly consume the budget by the end of the window. A burn rate of 14.4x means you will exhaust a 30-day budget in 2 hours — that is an urgent alert.

A two-level burn rate alert (from Google's SRE workbook):

- **Page:** burn rate > 14.4x over the past 1 hour (exhausts budget in 2 hours)
- **Ticket:** burn rate > 1x over the past 6 hours (on track to exhaust budget)

This eliminates alert noise from brief spikes while ensuring genuine SLO threats always page.

> [!tip] Start with availability and p99 latency as your first two SLOs, set the target slightly below your current actual performance, and tighten it over time. An SLO that is never under pressure is not measuring anything meaningful.

@feynman

An SLO is a budget for unreliability — you decide in advance how much downtime and slowness is acceptable, and an error budget tells you exactly how much of that budget you have left to spend.

@card
id: apid-ch11-c012
order: 12
title: The Vendor Landscape and Cost Discipline
teaser: Every major observability vendor now ingests OTel, but pricing models diverge sharply — understanding per-span and per-event costs before you scale is what separates a manageable bill from a shocking one.

@explanation

**Managed vendors:**

- **Datadog** — full-stack observability with tight integration between metrics, traces, logs, and APM. Per-host pricing for infrastructure metrics; per-million spans for APM; per-GB for logs. Known for aggressive costs at scale and a rich query language.
- **Honeycomb** — purpose-built for high-cardinality event data and tail-based querying. Per-event pricing. Designed around the assumption that you should be able to store and query every event without pre-aggregation. Favored by engineering teams doing deep trace analysis.
- **New Relic** — per-user and data-ingest pricing model (GB ingested per month). All-in-one platform with APM, infrastructure, logs, and synthetic monitoring.
- **Dynatrace** — Davis AI engine for automatic root cause analysis. Per-host pricing for full-stack monitoring. Dominant in enterprise and regulated industries.
- **Grafana Cloud** — managed hosting for the OSS Grafana stack. Per-series pricing for metrics (Mimir), per-GB for logs (Loki), and per-span for traces (Tempo). Generous free tier.

**Open-source self-hosted stack:**

- **Prometheus** — metrics collection and storage (short-term retention)
- **Mimir** — horizontally scalable long-term Prometheus-compatible metrics storage
- **Tempo** — scalable trace backend backed by object storage (S3/GCS)
- **Loki** — log aggregation with a Prometheus-like query model
- **Jaeger** — trace collection and visualization (older standard; Tempo has largely superseded it for new deployments)
- **Grafana** — unified dashboard and alerting frontend for all of the above

**Cost discipline:**

- Traces are the most expensive signal per unit. A 1% sample rate cuts trace costs by 99% with acceptable fidelity for healthy traffic; tail-based sampling recovers the error traces.
- Logs are the second most expensive. Apply log-level filters aggressively in production: DEBUG logs belong behind a runtime flag, not streaming to a paid ingest pipeline permanently.
- Metrics are cheapest but cardinality is the lever — see card 9. Dropping high-cardinality labels reduces costs nonlinearly.
- Most teams overspend on logs and underspend on traces. The correct ratio depends on workload, but investigate your log volume before blaming trace costs.

> [!info] Vendor lock-in in observability is real but mitigable. OTel instrumentation is vendor-neutral; the lock-in comes from query languages, dashboards, and alert configurations, which are all backend-specific. Budget for a migration cost if you switch backends after building deep operational workflows.

@feynman

Choosing an observability vendor is like choosing a cell carrier — the underlying network (OTel) is mostly standard, but the plans, prices, and bill surprises differ enough that you should read the pricing page before you commit to a long-term contract.
