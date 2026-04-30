@chapter
id: sa-ch12-space-based
order: 12
title: Space-Based
summary: An architecture for extreme scale. Replicate state into in-memory grids; ditch the database in the request path. Niche, demanding, and the right answer for systems that genuinely need it.

@card
id: sa-ch12-c001
order: 1
title: The Database Bottleneck
teaser: Most architectures are bottlenecked by the database. Space-based architecture removes the database from the request path — replicating state across nodes in memory — and absorbs orders-of-magnitude more load.

@explanation

Most production systems hit a scale wall at the database. Read replicas help; sharding helps more; but eventually a single shared database is the bottleneck, and adding application-tier capacity stops helping.

Space-based architecture (also called "tuple space") is a structural answer: instead of every request going to the database, each request hits an in-memory data grid that's replicated across nodes. The database stops being on the critical path; it becomes a backing store, asynchronously updated.

```text
[Client] → [Processing Unit (with in-memory data grid)] → response
                ↓ (async)
           [Persistent store]
```

Each processing unit (PU) has:

- **Application code** — the business logic.
- **Local in-memory cache** — a copy of the data this unit needs.
- **Data grid replication** — keeps caches consistent across PUs.
- **Async persistence** — writes back to durable storage.

When traffic spikes, you add more PUs. Each one has its own copy of the data; each one can serve requests independently. The database isn't in the loop.

> [!info] Examples: large-scale ticketing systems (Concert ticketing during onsale), travel reservations, fraud detection at major banks, ad-tech bidding platforms. Each is a system whose request rate would melt any database.

@feynman

Same instinct as caching everything in memory at every node. The database isn't in the hot path; the data is. Space-based makes the cache the architecture, not an optimisation.

@card
id: sa-ch12-c002
order: 2
title: When Space-Based Is Right
teaser: Extreme load with high read/write ratios. Bursty traffic. Latency requirements no database can meet. Space-based earns its keep when the alternatives can't even theoretically scale to the load you have.

@explanation

The conditions that justify space-based:

- **Massive concurrent load.** 100K+ requests per second sustained, or huge bursts above that.
- **Sub-millisecond latency requirements.** Database round-trips are too slow.
- **Bursty traffic.** Onsale events, flash sales, viral spikes. Traditional architectures degrade or fail; space-based absorbs through PU scaling.
- **High availability under partition.** PUs can keep serving locally even when the data grid is partitioned.

It's a poor fit for:

- **Normal workloads.** If a database can serve your traffic, use a database. Space-based is overkill.
- **Strong consistency needs.** The architecture is built around eventual consistency between PUs and the durable store.
- **Complex queries.** In-memory grids handle key-value access well; complex JOINs and aggregations less so.
- **Small teams.** The operational complexity is real; you need engineers who understand distributed caches.

The honest threshold: if your team is debating whether to pick space-based, you probably don't need it. Teams that need it usually know — they've already failed with simpler architectures.

> [!warning] Picking space-based for an ordinary workload is engineering theatre. The architecture is more demanding than ordinary teams are ready for, and the benefits don't matter at small scale.

@feynman

Same as picking a Formula 1 car for grocery runs. The car is brilliant at what it does; the grocery run isn't where it earns its keep. Match the tool to the actual problem.

@card
id: sa-ch12-c003
order: 3
title: Processing Units
teaser: Each PU is a self-contained service that handles requests using local in-memory data. PUs scale horizontally — add nodes to handle more load. The architecture's elasticity comes from this.

@explanation

A processing unit (PU) is the basic compute element of a space-based architecture. Each PU:

- Runs the application logic.
- Holds a local in-memory copy of the data it needs.
- Receives requests directly (via load balancer or partition-aware routing).
- Serves requests using local data, without touching the database.

Multiple PUs run in parallel. They're functionally identical (or specialised by data partition). Adding capacity is "spin up more PUs." Removing it is "spin down some PUs."

The PU's footprint:

- **Memory** — the working set fits in RAM. Bigger working sets mean bigger PUs or partitioning.
- **CPU** — depends on workload; usually heavy compute on the data, not on serialization.
- **Network** — internal grid traffic for replication; external traffic for client requests.

The PU model is what makes space-based "elastic": there's no shared bottleneck (no central database; no central queue), so adding PUs adds capacity proportionally — at least until network or grid replication becomes the limit.

> [!info] PUs are typically deployed as containers or VMs in cloud environments. Kubernetes, ECS, or VM-based fleet management all work; the orchestration is standard.

@feynman

Same instinct as the worker pool in a distributed system. Each worker is independent; adding more workers adds capacity. The trick in space-based is each worker carrying its own data so it doesn't queue at a central database.

@card
id: sa-ch12-c004
order: 4
title: The Data Grid
teaser: PUs share state through an in-memory data grid — Hazelcast, Apache Ignite, GridGain, or modern alternatives. Updates replicate across PUs in milliseconds. The grid is the system's working memory.

@explanation

The data grid is the in-memory data store that makes space-based work. It's distributed across PUs (each PU has a slice; the slices replicate); writes propagate to all replicas; reads are local.

Modern grid technologies:

- **Hazelcast** — long-standing, well-documented, mature.
- **Apache Ignite** — open-source, feature-rich (also offers persistence and SQL).
- **GridGain** — commercial, built on Ignite.
- **Redis with replication** — simpler grid; eventual consistency.
- **Redpanda / KIP-500 Kafka** — for systems that fit the streaming model.

The grid handles:

- **Replication** — every write goes to N replicas; reads are local.
- **Partitioning** — data spreads across PUs; you can have more data than fits on one node.
- **Failure** — when a PU dies, its replica takes over.
- **Consistency** — eventual by default; some grids offer stronger guarantees at a latency cost.

Operationally, the data grid is its own thing to manage. Network topology matters; replication factor matters; cluster membership matters. Teams running space-based usually have a dedicated platform team for the grid.

> [!warning] The data grid is the heart of the architecture. Picking it badly — or operating it carelessly — is the most common way space-based deployments fail. Budget for grid expertise.

@feynman

Same as the shared whiteboard in an office. Everyone can read and write; updates show up for everyone. The whiteboard is fast; you don't go to a filing cabinet for normal work.

@card
id: sa-ch12-c005
order: 5
title: Data Pumps
teaser: Updates from PUs are pumped to the durable store asynchronously. The pump is the bridge between the in-memory world and the persistent one. Latency in the pump translates to risk on PU failure.

@explanation

Space-based architectures still need durable storage — the database isn't in the hot path, but it's not gone. Writes flow from the data grid to the database via a *data pump*: an async process that batches and writes updates to durable storage.

The pump's responsibilities:

- **Capture changes** from the data grid.
- **Batch them** for efficient database writes.
- **Acknowledge** completion, so the grid knows the write is durable.
- **Handle failure** — retry, dead-letter, or escalate.

The tradeoffs:

- **Pump latency vs durability.** A slow pump means changes aren't durable for a while; a PU crash loses recent writes.
- **Batching size vs throughput.** Larger batches are more efficient; smaller batches reduce loss on failure.
- **Single pump vs distributed.** A single pump is a bottleneck; distributed pumps need coordination.

Some systems also use the pump in reverse — *data readers* pull batches from the durable store into the grid on cold start (or after a partition heals). The architecture has both directions, both async, both async-friendly.

> [!info] The data pump is where space-based architectures most often have hidden bugs. Race conditions, replay edge cases, ordering anomalies — they all surface here. Test the pump under failure carefully.

@feynman

The same shape as a write-back cache. The cache serves reads and writes fast; the database is updated in the background. The cache is the architecture; the database is just durability.

@card
id: sa-ch12-c006
order: 6
title: Eventual Consistency by Design
teaser: Two PUs see slightly different views of the data while replication catches up. The architecture is built around this; expecting strong consistency is fighting it.

@explanation

The data grid is replicated across PUs, but replication isn't instant. There's a window — usually milliseconds, sometimes seconds under load — where one PU has a recent write and another doesn't.

Consequences for application design:

- **Reads might be stale.** A PU just read; another PU just wrote; the first PU may not see the write yet.
- **Writes might conflict.** Two PUs write to the same key concurrently; the grid resolves with last-write-wins or CRDT-like merging, depending on configuration.
- **State transitions need tolerance.** "User just paid" → "show paid status" might lag for a moment; the UI should accept that.

Patterns that work:

- **Read your own writes** — when a user makes a change, route their next request to the PU that processed the change. They see consistency.
- **Idempotent operations** — if the same operation might fire on two PUs (rare but possible), make sure both runs are equivalent.
- **Conflict-free types** — use CRDTs for counters, sets, registers where conflicts can occur naturally.
- **Compensating logic** — for critical operations, accept that conflicts happen and have explicit reconciliation.

> [!warning] If your business logic assumes strong consistency, space-based isn't the right architecture. Force-fitting strong consistency on top of a replicated grid usually means recreating a database, which kills the latency benefit.

@feynman

The same realities as collaborative editing. Two people typing in the same paragraph in Google Docs. The system shows them slightly different views for a moment, then converges. Space-based has the same shape, applied to operational data.

@card
id: sa-ch12-c007
order: 7
title: Elasticity Under Bursts
teaser: Space-based shines under bursts. Add PUs; each carries its weight; throughput scales nearly linearly. The architecture absorbs spikes that would crash database-bound systems.

@explanation

The flagship use case: a ticketing system selling concert tickets. Demand spikes from 100/sec to 100,000/sec at the moment tickets go on sale. A database-bound architecture queues, throttles, or fails. A space-based architecture scales by adding PUs.

Why elasticity works in space-based:

- **No central bottleneck.** Adding PUs doesn't add load to a shared component.
- **Local data.** A new PU comes up with its slice of the grid; serves requests immediately.
- **Stateless or near-stateless logic.** PUs can come and go without complex handoffs.
- **Cloud-native fit.** Auto-scalers (Kubernetes HPA, ECS, etc.) spin up PUs based on metrics.

The limits:

- **Grid replication overhead.** As you add PUs, the grid replication traffic grows. There's a ceiling.
- **Network.** Inter-PU bandwidth becomes the constraint at very large scale.
- **Cold-start latency.** A new PU has to populate its grid slice before it's useful. Plan for warm-up.
- **Working set must fit in memory.** If your data grows beyond what your PUs can hold, partitioning is required.

> [!info] The elasticity is real but isn't infinite. Most space-based deployments scale to the low millions of RPS; beyond that, partitioning and specialisation kick in.

@feynman

Same lesson as scaling a phone bank. One operator can take 10 calls/hour. Add operators; capacity rises. The architecture is the operator pool; the data grid is the shared customer database. Add operators when calls spike.

@card
id: sa-ch12-c008
order: 8
title: Operational Demands
teaser: The grid, the pumps, the PU lifecycle, the failover, the deployment dance — space-based is operationally heavy. The teams that succeed have built or bought the platform that makes it tractable.

@explanation

Operating space-based requires:

- **Grid expertise.** Cluster topology, replication, partition strategy, failure modes. Not standard knowledge; needs training or hires.
- **Custom monitoring.** Per-PU metrics, grid health, pump lag, replication lag, cold-start time.
- **Failure-mode runbooks.** PU dies, grid splits, pump backs up — each is a known scenario with a written response.
- **Capacity planning.** Memory per PU; PU count for expected load; headroom for bursts.
- **Deployment discipline.** Rolling deploys that respect grid quorum; canary rollouts that don't take down too many PUs at once.

The teams that succeed in space-based have either:

- **Built a platform team** that owns the grid, the deployment patterns, the operational tooling.
- **Bought a managed offering** (Hazelcast Cloud, Ignite-based vendors).

The teams that fail try to bolt space-based onto existing infrastructure without the platform investment. They discover, painfully, that the grid is its own ecosystem.

> [!warning] If your organisation can't dedicate platform engineers to the data grid, space-based isn't the right call. The architecture only earns its keep if the operational story is solid.

@feynman

Same lesson as building any high-performance infrastructure. The car needs a pit crew; the rocket needs mission control. Space-based is the same — the magic only happens when the support apparatus is in place.

@card
id: sa-ch12-c009
order: 9
title: Modern Alternatives
teaser: Most workloads that historically needed space-based can now use a fast key-value store, a serverless platform, or a stream processor. Space-based isn't dead; the field around it has new options.

@explanation

Space-based architecture was popularised in the 2000s when the alternatives were limited: relational databases, basic caches, application servers. The 2010s and 2020s changed the menu:

- **Distributed key-value stores** — DynamoDB, Bigtable, ScyllaDB, FoundationDB. Sub-millisecond reads at massive scale; managed; no PU lifecycle to operate.
- **In-memory databases as a service** — Redis Enterprise, ElastiCache, Memcached as a service.
- **Serverless platforms** — Cloudflare Workers, AWS Lambda + DynamoDB, Vercel Edge Functions. Auto-scaling without managing PUs.
- **Stream processors with state** — Flink, Kafka Streams, Materialize. Stateful processing at scale.
- **Edge compute** — geographically distributed processing close to users; scales naturally.

Many workloads that 15 years ago would have demanded space-based now ship on these. The architecture survives in places that genuinely need its specific properties (sub-millisecond, massive bursts, custom replication semantics) but the boundaries have shifted.

> [!info] Before picking space-based in 2026, evaluate whether a managed alternative covers your needs. Most teams don't need the bespoke architecture; they need scalable infrastructure they don't have to operate.

@feynman

The same shift as not running your own datacenter. The cloud absorbed 95% of "we run our own infra" workloads. Specialised architectures like space-based are seeing the same pattern — managed alternatives now cover most of the ground.

@card
id: sa-ch12-c010
order: 10
title: When to Reach for Space-Based
teaser: Honest signal: you've tried databases, caches, and managed alternatives, and you still can't hit your SLOs. The architecture earns its operational cost when nothing else can deliver. That's a small set of systems.

@explanation

The decision tree, brutally short:

1. **Can a database handle your load?** Yes → use it. Most systems.
2. **Can a database with caching handle it?** Yes → use it. Many of the rest.
3. **Can a managed key-value store handle it?** Yes → use it. Most systems beyond #2.
4. **Do you need bespoke replication, custom data structures in memory, or sub-millisecond latency at extreme bursts?** No → use simpler alternatives.
5. **Yes, and you have the team for it?** Space-based is on the table.

The honest count: maybe one team in fifty needs space-based. The rest are better served by simpler architectures with managed infrastructure.

For the team that does need it, the architecture is genuinely powerful. Onsale ticketing systems, real-time bidding platforms, fraud-detection systems handling millions of events per second — these are the canonical fits. The architecture works; the team has to be ready.

For everyone else, space-based is a curiosity worth understanding (it shows you what extreme scaling looks like) but not a goal to pursue.

> [!info] You'll meet engineers excited about space-based because of its elegance. The elegance is real; it just doesn't pay off at most teams' scale. Save it for the workloads that actually need it.

@feynman

The same lesson as picking specialised tools. The right circular saw for that one cut is genuinely better than a hand saw — but you don't buy a circular saw for occasional use. You buy it when you're cutting daily. Space-based is a daily-cut tool for niche workloads.
