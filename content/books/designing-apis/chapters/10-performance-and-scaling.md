@chapter
id: apid-ch10-performance-and-scaling
order: 10
title: Performance and Scaling
summary: API performance is design-driven — caching headers, conditional requests, pagination, batching, and persisted queries each shave latency or cost; the wins compound, and the API contract carries the rules.

@card
id: apid-ch10-c001
order: 1
title: Performance Is a Design Decision
teaser: Most API performance outcomes are locked in at contract design time — by the time you're tuning the implementation, the biggest wins are already off the table.

@explanation

When teams talk about "optimizing" an API after the fact, they are almost always working on the margin. The structural costs — round trips, payload size, cache eligibility, N+1 patterns — are determined by the shape of the contract, not the speed of the database query.

The decisions that determine performance profile:

- **How many round trips does the caller need?** An endpoint that returns a user and their top five orders in one response costs one network round trip. An endpoint that returns only the user, requiring a second call for orders, costs two. Multiplied across millions of requests, that difference is measured in infrastructure spend, not just milliseconds.
- **Can the response be cached?** A response with no `Cache-Control` header, or with `Cache-Control: no-store`, cannot be cached by any intermediary or client. That decision, made once in the contract, forces every client to make a fresh request every time.
- **What does the payload contain?** Sending fifty fields when callers reliably use five is waste that compounds at scale. It occupies bandwidth, serialization time, and memory on both sides.
- **What is the pagination model?** Offset pagination with large offsets causes full table scans on the database side. That is not fixable in the implementation without changing the contract.

The right time to ask "is this design fast?" is when drafting the API, not after the first load test. Performance constraints belong in the spec alongside correctness constraints.

@feynman

Optimizing an API after you've locked in the contract is like soundproofing a house after the walls are drywalled — you can add a little, but the biggest wins required decisions made before the first nail went in.

@card
id: apid-ch10-c002
order: 2
title: HTTP Caching Headers
teaser: Cache-Control, Expires, and Vary are the three headers that determine what gets cached, for how long, and whether a cached response is actually the right one — and most APIs get at least one of them wrong.

@explanation

HTTP caching is the highest-leverage performance tool available to an API designer because the wins happen without touching the origin server at all.

**`Cache-Control`** is the authoritative header. Key directives:

- `max-age=N` — the response is fresh for N seconds; no request to the origin is needed during that window.
- `s-maxage=N` — overrides `max-age` for shared caches (CDNs, proxies) while leaving browser cache behavior unchanged. Useful when you trust CDN freshness rules but want browsers to revalidate more often.
- `no-cache` — the response can be stored but must be revalidated before use. Commonly confused with `no-store`, which prohibits storage entirely.
- `private` — the response is for one user and must not be stored in a shared cache. Required for any response containing user-specific data.
- `immutable` — combined with a long `max-age`, signals that the resource will never change for this URL. Correct for versioned assets; dangerous for data APIs.

**`Expires`** is the older alternative to `max-age`. When both are present, `Cache-Control` wins. Prefer `Cache-Control` for all new work.

**`Vary`** tells caches which request headers affect the response. If your API returns different content for `Accept-Encoding: gzip` vs no encoding header, `Vary: Accept-Encoding` ensures gzip and uncompressed responses are cached separately. Getting `Vary` wrong produces cache poisoning — a compressed response served to a client that cannot decompress it.

```http
HTTP/1.1 200 OK
Cache-Control: public, max-age=300, s-maxage=600
Vary: Accept-Encoding
Content-Type: application/json
```

> [!warning] `Cache-Control: no-cache` does not mean "don't cache" — it means "cache but always revalidate." Use `no-store` if you genuinely want no caching. Confusing the two is one of the most common caching mistakes in production APIs.

@feynman

`Cache-Control` is the instructions you leave for every cache between your server and the client — without it, each cache guesses, and guesses vary badly across implementations.

@card
id: apid-ch10-c003
order: 3
title: Conditional Requests
teaser: Conditional requests let a client ask "has this changed?" instead of "give me this" — and when nothing has changed, the server sends back 304 Not Modified with no body at all.

@explanation

A conditional request is a revalidation: the client already has a cached copy and wants to know if it is still valid without transferring the full response again.

Two mechanisms:

**ETags with `If-None-Match`**

The server includes an `ETag` in its response — a fingerprint of the response content (often a hash or version identifier). The client stores this tag alongside the cached response. On the next request, the client sends the tag back:

```http
GET /products/42 HTTP/1.1
If-None-Match: "v3-a7f3c1"
```

If the resource has not changed, the server returns `304 Not Modified` with no body. The client uses its cached copy. If the resource has changed, the server returns `200 OK` with the new body and a new ETag.

**Last-Modified with `If-Modified-Since`**

Same pattern, but uses a timestamp instead of a fingerprint. Less precise than ETags — two-second timestamp granularity can produce stale responses in high-write systems. ETags are preferred for any resource that can change more than once per second.

```http
GET /reports/weekly HTTP/1.1
If-Modified-Since: Sat, 26 Apr 2025 12:00:00 GMT
```

The 304 response has no body, which means it consumes almost no bandwidth. For large payloads that change infrequently — documentation, configuration, reference data — conditional requests can reduce bandwidth by 90%+ with no change to application logic on the client side beyond caching the ETag.

The tradeoff: conditional requests still require a network round trip to the server. For very high request rates, push-based cache invalidation (webhooks, event streams) eliminates even this cost.

@feynman

A conditional request is like calling the library to ask if a book has been updated before making the trip — if they say "no changes," you stay home and use your existing copy.

@card
id: apid-ch10-c004
order: 4
title: Compression
teaser: Gzip and Brotli compress API responses at the transport layer and routinely cut JSON payload sizes by 70–90% — the wins are large relative to the CPU cost, and Brotli's ratio beats gzip on text.

@explanation

Most JSON responses compress extremely well because they are repetitive text — key names repeat across every object in an array, whitespace adds bulk, and common values recur throughout.

**Gzip** is universally supported and the safe default. Compression ratios for typical JSON payloads run 70–85%. A 100 KB JSON array of objects commonly compresses to under 15 KB.

**Brotli** is a newer algorithm (originally from Google) that consistently achieves better compression ratios than gzip on text — typically 15–25% smaller than an equivalent gzip output. Brotli is supported in all modern browsers and most HTTP clients. Some older API clients or SDK versions may not support it; gzip remains the fallback.

Negotiation is handled at the transport layer via the `Accept-Encoding` request header and the `Content-Encoding` response header:

```http
GET /v1/orders HTTP/1.1
Accept-Encoding: br, gzip, deflate
```

```http
HTTP/1.1 200 OK
Content-Encoding: br
Vary: Accept-Encoding
Content-Type: application/json
```

**Transport-level vs application-level compression:**

- Transport-level compression (handled by the web server or gateway — nginx, AWS API Gateway, Cloudflare) requires no application code changes. Enable it in the server config and it applies to all responses.
- Application-level compression (compressing in your handler code) gives you more control — e.g., only compressing responses above a size threshold — at the cost of doing it explicitly everywhere.

For most APIs, enabling compression at the reverse proxy or gateway is the right approach. Compressing responses already below 1 KB is often counterproductive — the compressed output can be larger than the input, and the CPU cost is not zero.

@feynman

Compressing an API response is like vacuum-sealing luggage — the contents are identical, they just take up far less space in transit, and the client unpacks them on arrival.

@card
id: apid-ch10-c005
order: 5
title: Pagination at Scale — Cursor vs Offset
teaser: Offset pagination is easy to implement and breaks at scale; cursor pagination is harder to design but runs in constant time regardless of how deep into the dataset you go.

@explanation

**Offset pagination** uses a `?page=N&limit=M` or `?offset=N&limit=M` model. The database translates this to `LIMIT M OFFSET N`. The problem: to satisfy `OFFSET 10000`, the database must scan and discard the first 10,000 rows, even though they are never returned. On a table of 10 million rows with active writes, a deep page request becomes a full-table sequential scan with sort overhead.

The cost grows quadratically with page depth. Page 1 is cheap. Page 1,000 is not.

**Cursor pagination** uses an opaque cursor that encodes the position of the last item seen — typically the indexed value at the last row (often an ID or timestamp). The query becomes:

```http
GET /v1/events?after=evt_a9f3c2&limit=50
```

Which translates to something like `WHERE id > 'evt_a9f3c2' ORDER BY id LIMIT 50`. The database uses the index directly, regardless of how many total rows exist or how deep into the dataset you are. The cost is constant.

Tradeoffs to be honest about:

- Cursor pagination does not support random access. You cannot jump to "page 47" directly — you must walk the cursor forward. This is almost always acceptable for API consumers but matters for internal tooling that needs arbitrary page access.
- Cursors must be stable — if a cursor encodes a timestamp and two records share the same timestamp, the cursor needs a tiebreaker (typically the primary key) to be deterministic.
- Returning `next_cursor: null` as the terminal signal is cleaner than counting total pages, and avoids an expensive `COUNT(*)` query.

For any dataset that grows without bound, cursor pagination is the production default. Offset pagination is acceptable for small, bounded datasets or internal admin tools where deep pagination is not expected.

> [!tip] Design your cursor as an opaque, base64-encoded string from day one. This lets you change the underlying encoding without a breaking API change — callers treat it as a black box.

@feynman

Offset pagination is like finding your place in a book by counting every page from the cover each time; cursor pagination is like using a bookmark — you go directly to where you left off.

@card
id: apid-ch10-c006
order: 6
title: Batching Endpoints
teaser: A batching endpoint accepts an array of inputs and returns an array of results in one call — when the per-item overhead dominates the per-item work, batching is the most impactful optimization available.

@explanation

Many API call patterns are naturally array-shaped: resolve fifty user IDs to profiles, enrich a hundred order records with product details, send twenty notifications at once. Without a batch endpoint, each of these becomes N sequential or concurrent HTTP requests with N round trips, N TLS handshakes, and N units of connection overhead.

A batching endpoint collapses that to one:

```http
POST /v1/users/batch
Content-Type: application/json

{
  "ids": ["usr_001", "usr_002", "usr_003"]
}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "results": [
    {"id": "usr_001", "name": "Alice"},
    {"id": "usr_002", "name": "Bob"},
    {"id": "usr_003", "error": "not_found"}
  ]
}
```

Design considerations:

- **Per-item error handling.** A batch response should include per-item success/failure, not fail the entire request if one item errors. The pattern above — an `error` field on failing items alongside successful items — is the most useful shape for callers.
- **Size limits.** Cap the maximum batch size (100 or 500 is common) to prevent individual requests from overwhelming your backend. Document the limit in the contract.
- **Throughput vs latency tradeoff.** Batching is a throughput optimization, not a latency optimization. A single-item request is faster than a batch of one because it skips the array overhead. Batching pays when request volume is the bottleneck, not when raw response time is.
- **Idempotency.** Batch endpoints that create resources need idempotency keys per item, not just per request.

Batching is particularly valuable when you control both sides — such as a mobile app calling your own backend — because you can tune the client to accumulate requests over a short window and flush them as a batch.

@feynman

A batching endpoint is like a delivery truck making one trip with fifty packages instead of fifty drivers each making one trip — the per-package overhead drops dramatically when the fixed trip costs are shared.

@card
id: apid-ch10-c007
order: 7
title: GraphQL Persisted Queries
teaser: Persisted queries replace a full GraphQL query string in the request with a short hash, reducing payload size and letting the server reject arbitrary queries — fixing both the bandwidth and the abuse surface in one step.

@explanation

In standard GraphQL, the client sends the full query text in every request. For complex queries, this is hundreds or thousands of bytes per request, plus the risk that any client can send any query of arbitrary complexity.

Persisted queries change the protocol: during development or at build time, the client registers its queries with the server, which stores them and returns a hash. At runtime, the client sends only the hash:

```http
POST /graphql HTTP/1.1
Content-Type: application/json

{"id": "a1b2c3d4", "variables": {"userId": "usr_001"}}
```

The server looks up the stored query by hash, executes it, and returns the result. The client never sends the query text after registration.

This solves two problems at once:

**Bandwidth reduction.** A 500-byte query string sent a million times per day costs 500 MB of request body bandwidth. A 16-byte hash costs 16 MB. The reduction compounds for large queries and high traffic.

**Runtime query cost control.** Without persisted queries, clients can send arbitrary queries of arbitrary depth and complexity. A malicious or buggy client can send a query that joins ten nested collections and bring down the server. With persisted queries, only pre-registered queries are executable. The server can reject any request that does not match a known hash.

The tradeoff: persisted queries couple the client build to the server's query registry. Deploying a new client with new queries requires the server to have those queries registered first. This requires coordination between client and server deployments that does not exist with ad-hoc queries.

Tools like Apollo's persisted query link and Relay's persisted query support handle the registration workflow. The server-side registry is typically a Redis instance or a flat file loaded at startup.

@feynman

Persisted queries are like replacing a long typed order with a numbered menu item — instead of reading out the full recipe every time, you say "I'll have a number 7," and the kitchen already knows what that means.

@card
id: apid-ch10-c008
order: 8
title: Edge Caching with CDNs
teaser: A CDN like Cloudflare, Fastly, or CloudFront caches responses at points of presence close to the client — but only responses that are correctly marked as cacheable and do not contain user-specific data.

@explanation

A CDN distributes cache nodes (points of presence, or PoPs) geographically. When a user in London requests a resource served from a US origin, a CDN with a London PoP can serve the response from London if it has a valid cached copy. The latency difference between a cache hit at a nearby PoP and an origin round trip across an ocean can be 200–400 ms.

What is safe to cache at the edge:

- **Public, non-personalized responses.** Product catalogs, documentation, reference data, public search results, static configurations. These are ideal — same response for every caller, long TTLs possible.
- **Semi-public responses with query-key variation.** Cloudflare, Fastly, and CloudFront all support caching by URL including query string. `GET /products?category=electronics` can be cached separately from `GET /products?category=books` when the cache key includes the full URL.

What must not be cached at the edge:

- **Responses containing user-specific data.** Any response that varies by authentication token, session, or user ID cannot be cached in a shared edge cache without cache poisoning risk. The `Cache-Control: private` directive prevents edge caching for these responses.
- **Responses to authenticated requests**, unless the CDN is configured to treat the auth token as part of the cache key (which Fastly and Cloudflare support but requires explicit configuration).

The operational workflow:

- Cloudflare and Fastly respect `Cache-Control` headers by default. Set the correct headers at the origin, and the CDN respects them.
- CloudFront has separate "cache behavior" configuration in addition to origin headers; misconfiguration can cache private responses even when the origin sets `Cache-Control: private`.

Cache purging — invalidating a specific URL or set of URLs at the edge after a data change — is a first-class operation on all three platforms via API. Design your cache invalidation strategy before launch, not after you discover stale data in production.

> [!warning] Forgetting `Cache-Control: private` on a personalized response can cause CDN nodes to serve one user's data to another. This is one of the most serious caching bugs possible and has affected major platforms.

@feynman

A CDN is like stocking convenience stores near customers with copies of popular items from the main warehouse — most requests get served without traveling to the warehouse, and only cache misses make the full trip.

@card
id: apid-ch10-c009
order: 9
title: Server-Side Caching Tiers
teaser: Redis and Memcached sit between your API handlers and your database, storing computed results in memory — but cache invalidation, the famously hard problem, is where most server-side caching strategies eventually fail.

@explanation

Server-side caching places a fast in-memory store between your application and the data source. Rather than recomputing or re-querying on every request, the handler checks the cache first, returns the stored value on a hit, and falls back to the source on a miss.

**Redis** is the most widely deployed option. It is a persistent, data-structure-aware store that supports strings, hashes, sorted sets, lists, and more. Redis supports TTL-based expiry, atomic operations, and pub/sub. It is appropriate as a cache, a session store, a queue, and a rate-limit counter. Persistence (RDB snapshots, AOF logging) is configurable but optional for pure caching use cases.

**Memcached** is simpler — purely a key-value cache with no persistence and no data structures beyond strings. Its threading model can outperform Redis at very high request rates for pure caching workloads, though the difference is rarely significant in practice for API tiers.

Common caching patterns:

- **Cache-aside (lazy loading).** The application checks the cache; on miss, reads from the database and writes to the cache. Simple, but the first request after a cache miss is always slow.
- **Write-through.** On every database write, also write the new value to the cache. The cache is always warm, but write latency increases.
- **TTL-based expiry.** Every cached entry has a maximum age. Simple to implement; the tradeoff is that stale data is served until TTL expires.

The two hard problems in caching, as the original quote goes, are cache invalidation and naming things. Cache invalidation is hard because you need to evict or update a cached value every time the underlying data changes — and in distributed systems, "every time" is harder than it sounds. Writers and readers may be in different services, changes may come from multiple sources, and the failure mode (a reader serving stale data indefinitely) is silent.

@feynman

Server-side caching is like a chef keeping a prep bowl of the most-requested sauce ready on the counter — most orders are served instantly, but you have to throw out the prep bowl and make fresh when the recipe changes.

@card
id: apid-ch10-c010
order: 10
title: Connection Reuse — HTTP/1.1, HTTP/2, HTTP/3
teaser: Each HTTP version changes how connections are reused and how requests are multiplexed — and the protocol your API speaks has a larger effect on perceived latency than most application-level optimizations.

@explanation

**HTTP/1.1** introduced persistent connections (keep-alive): after a response is delivered, the TCP connection stays open for subsequent requests rather than closing and reopening. This eliminates the TCP handshake and TLS negotiation overhead on every request. However, HTTP/1.1 connections are serial — only one request can be in flight on a single connection at a time (without pipelining, which is poorly supported in practice). Browsers and clients work around this by opening multiple parallel connections, typically six per origin.

**HTTP/2** introduces multiplexing: multiple requests and responses can be interleaved on a single TCP connection simultaneously. There is no head-of-line blocking at the HTTP layer. A single connection replaces the pool of parallel connections required under HTTP/1.1. HTTP/2 also introduces header compression (HPACK), which reduces the overhead of repetitive headers across many requests to the same API.

**HTTP/3** replaces TCP with QUIC, a UDP-based protocol developed by Google and standardized by the IETF. QUIC eliminates head-of-line blocking at the transport layer — in HTTP/2, a single lost TCP packet blocks all multiplexed streams until the packet is retransmitted; in QUIC, a lost packet only blocks its own stream. QUIC also reduces connection establishment from two round trips (TCP handshake + TLS handshake) to one. Fastly and Cloudflare both support HTTP/3; it is the default for traffic between modern browsers and these CDNs.

For APIs:
- If you terminate TLS at a load balancer or API gateway, check whether it negotiates HTTP/2 with clients. Most modern gateways (AWS API Gateway, Kong, nginx) do.
- Connection reuse between your API gateway and your upstream services (backend HTTP connections) is separately configurable and equally important in high-throughput environments.

@feynman

HTTP/2 is like upgrading from a narrow single-lane road to a multi-lane highway between the same two cities — the same route, but many more vehicles moving simultaneously instead of in a queue.

@card
id: apid-ch10-c011
order: 11
title: Rate-Limit Headers as a Performance Signal
teaser: Rate-limit headers are not just about enforcement — they are a feedback mechanism that lets well-behaved clients back off proactively instead of hammering the API until they are rejected.

@explanation

A client that retries rejected requests in a tight loop is not just a rate-limiting problem — it is a performance problem. Every rejected request still consumes a TCP connection, TLS negotiation, authentication verification, and rate-counter lookup on the server side. The cost of a rejected request is not zero.

Rate-limit response headers give clients the information they need to avoid rejection in the first place:

```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 743
X-RateLimit-Reset: 1746384000
Retry-After: 0
```

- `X-RateLimit-Limit` — the total allowance for the current window.
- `X-RateLimit-Remaining` — how much of the allowance is left.
- `X-RateLimit-Reset` — Unix timestamp when the window resets.
- `Retry-After` — on a 429 response, the number of seconds the client must wait before retrying.

The IETF draft standard `RateLimit-Limit`, `RateLimit-Remaining`, and `RateLimit-Reset` (without the `X-` prefix) is gaining adoption and should be preferred for new APIs.

A well-implemented client SDK reads `RateLimit-Remaining` and `RateLimit-Reset` and spreads its remaining calls across the remaining window. It reads `Retry-After` on 429 and waits exactly that long rather than applying a random exponential backoff. These behaviors reduce server-side load significantly in burst scenarios.

The tradeoff: exposing rate limit state through headers increases the information available to clients trying to exploit the limits. For public APIs, the benefit to well-behaved clients almost always outweighs this risk.

> [!tip] Return rate-limit headers on every successful response, not only on 429s. A client that can see its allowance draining can throttle itself before it is throttled by you.

@feynman

Rate-limit headers are like a fuel gauge — without them the driver keeps going until the car stops; with them the driver can decide to refuel before running out.

@card
id: apid-ch10-c012
order: 12
title: Streaming Responses and When to Use Them
teaser: Streaming sends response data incrementally rather than waiting for the complete response — the right tool when the response is large, long-running, or genuinely event-driven.

@explanation

A standard HTTP response is sent in full once the server has assembled it. The client waits. For most API responses — a few kilobytes of JSON — this is invisible. For responses that are large, computed over seconds, or produced by ongoing events, making the client wait for the complete payload introduces unnecessary latency and often poor user experience.

**Chunked transfer encoding** sends a response body in pieces as they become available, without knowing the total size in advance. The server sets `Transfer-Encoding: chunked` and flushes data to the client progressively. Used for large file downloads, log streaming, and responses whose size is not known ahead of time.

**Server-Sent Events (SSE)** is a one-way, long-lived HTTP connection where the server pushes events to the client. The protocol is simple: a persistent `text/event-stream` response that the server writes to over time. SSE is appropriate for one-way real-time data — stock tickers, notification feeds, progress updates on long-running jobs. It runs over HTTP/1.1 and HTTP/2, works through proxies, and reconnects automatically on drop.

```http
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache

data: {"status": "processing", "progress": 42}

data: {"status": "processing", "progress": 87}

data: {"status": "complete", "result_url": "/results/job_123"}
```

**WebSockets** provide a full-duplex, bidirectional channel established via an HTTP upgrade handshake. WebSockets are the right choice when the client also needs to send data over the same persistent connection — chat, collaborative editing, real-time game state. The tradeoff over SSE: WebSockets do not automatically reconnect, do not work over HTTP/2 (require their own connection), and add complexity to load balancers and proxies.

The common mistake is reaching for WebSockets when SSE is sufficient. If the data flows one way — server to client — SSE is simpler, has better infrastructure support, and handles reconnection for free.

@feynman

Streaming a response is like reading a book aloud chapter by chapter as it comes off the press instead of waiting for the entire print run to finish before anyone hears a word.
