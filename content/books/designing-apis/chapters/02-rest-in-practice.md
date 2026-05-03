@chapter
id: apid-ch02-rest-in-practice
order: 2
title: REST in Practice
summary: REST is still the dominant API style on the web — and most "REST" APIs are missing the half of the design that actually matters: resources over RPC, HTTP semantics done right, and idempotency as a property to design for, not assume.

@card
id: apid-ch02-c001
order: 1
title: Resources vs RPC
teaser: The central REST decision is picking the noun, not the verb — and most "REST" APIs betray themselves in the first URL.

@explanation

REST is built around resources — things, not actions. A resource is a noun: an order, a user, a payment, a subscription. The HTTP method tells you what you're doing to it. When you find yourself naming URLs after verbs, you've drifted into RPC with HTTP as the transport.

The tell is in the URL:

- RPC style: `/createOrder`, `/cancelOrder`, `/getUserById`
- Resource style: `POST /orders`, `DELETE /orders/{id}`, `GET /users/{id}`

The RPC shape works, but it throws away HTTP's uniform interface. You end up inventing your own conventions for everything — method selection, error semantics, caching — because nothing in the protocol knows what `/cancelOrder` means. The resource model lets HTTP do that work for you.

The harder question is finding the right noun. Cancellation is a good example: is it a `DELETE /orders/{id}`, or a `POST /orders/{id}/cancellations`, or a `PATCH /orders/{id}` with `{"status": "cancelled"}`? All three are defensible. The `POST /cancellations` shape gives you a resource you can return a body from (the cancellation receipt) and a place to attach audit metadata. The `DELETE` shape is cleaner but loses that. Neither is wrong — but you should make the choice deliberately, not by accident.

> [!tip] If your URL path contains a verb that isn't an HTTP method, stop and ask what noun would replace it. The answer is usually one level up in the hierarchy.

@feynman

Designing REST resources is like naming the departments in a building — you hang signs on the doors for what lives there, and then the standard actions (enter, leave, check the directory) apply uniformly, rather than inventing a custom procedure for every room.

@card
id: apid-ch02-c002
order: 2
title: HTTP Method Semantics
teaser: GET, POST, PUT, PATCH, and DELETE each carry a precise contract — safe, idempotent, or neither — and violating those contracts breaks caching, retries, and every client that relies on them.

@explanation

Each HTTP method carries two properties that clients and infrastructure depend on:

**Safe** means the method does not modify state. A client (browser, proxy, CDN) is free to issue a safe request without side effects. GET and HEAD are safe. Nothing else is.

**Idempotent** means that issuing the same request N times produces the same result as issuing it once. GET, HEAD, PUT, DELETE, and OPTIONS are idempotent. POST is not. PATCH is technically not, though it can be designed to be.

What that means in practice:

- `GET /orders/{id}` — safe, idempotent. Cache it. Retry it freely. Never mutate state in a GET handler.
- `POST /orders` — not safe, not idempotent. Two identical POSTs can create two orders. Retry logic requires application-level idempotency keys (see card 5).
- `PUT /orders/{id}` — idempotent. Replaces the full resource. Sending the same PUT twice leaves the resource in the same state.
- `PATCH /orders/{id}` — partial update. Not inherently idempotent: `PATCH {"amount": "+10"}` applied twice changes state twice. Design PATCH bodies as declarative state (what it should be), not relative changes (what to add).
- `DELETE /orders/{id}` — idempotent. Deleting an already-deleted resource should return 404, but the server state after two identical DELETEs is the same: the resource is gone.

```http
PUT /orders/ord_123 HTTP/1.1
Content-Type: application/json

{"status": "confirmed", "amount": 9900}
```

> [!warning] Using POST for all mutations because it feels simpler forfeits idempotency guarantees and forces every retry to be coordinated at the application layer. You don't save complexity — you move it.

@feynman

HTTP methods are like the verbs on a library's book-handling policy — "look up" is safe and can be done a hundred times, "reserve" has to be coordinated because doing it twice means two reservations, and "replace the content" can be repeated without doubling the damage.

@card
id: apid-ch02-c003
order: 3
title: Status Codes You Actually Need
teaser: Most APIs only need about a dozen status codes, and using the right one carries meaning that clients, logs, and on-call engineers rely on at 2am.

@explanation

You don't need all 70-odd HTTP status codes. You need the ones that carry distinct, actionable meaning:

**2xx — success:**
- `200 OK` — request succeeded, body contains the result.
- `201 Created` — resource was created; include a `Location` header pointing to it.
- `204 No Content` — success, nothing to return (common for DELETE, or PATCH with no response body).

**4xx — client error:**
- `400 Bad Request` — malformed syntax, missing required fields, type errors.
- `401 Unauthorized` — credentials missing or invalid. Despite the name, this is an authentication failure.
- `403 Forbidden` — credentials are valid but the caller lacks permission. This is an authorization failure.
- `404 Not Found` — the resource does not exist.
- `409 Conflict` — the request conflicts with current state (duplicate creation, version mismatch, stale optimistic lock).
- `422 Unprocessable Entity` — syntactically valid but semantically wrong (e.g., a valid JSON body where `end_date` precedes `start_date`). Prefer this over 400 for business-rule violations.
- `429 Too Many Requests` — rate limit exceeded; include `Retry-After` in the response.

**5xx — server error:**
- `500 Internal Server Error` — unexpected failure. The server broke; the request might have been valid.

The 401/403 distinction matters: a `401` tells the client to re-authenticate or supply credentials. A `403` tells the client not to bother — the identity is known and refused.

> [!info] The 400 vs 422 split is worth making. 400 signals a structural parse failure; 422 signals that the body was valid JSON but violated business rules. They require different error messages and different client handling.

@feynman

Status codes are like the symbols on a package tracking system — each one carries a specific meaning that the shipper, the carrier, and the recipient have all agreed on in advance, so nobody has to open the box to know what happened.

@card
id: apid-ch02-c004
order: 4
title: The 4xx vs 5xx Distinction
teaser: 4xx means the client did something wrong; 5xx means the server did — and conflating them causes alerts to fire on the wrong team at 3am.

@explanation

This distinction is operationally load-bearing, not academic. On-call routing, alerting thresholds, SLA metrics, and incident attribution all depend on it.

**4xx** responses are the client's fault. The request was bad, unauthorized, or in conflict with current state. These errors are expected; a healthy API serving real traffic will have a baseline 4xx rate. They should not page your on-call engineer. A spike in 4xx rates might indicate a broken client deployment, a misconfigured integration, or a credential rotation — problems worth alerting on, but not server incidents.

**5xx** responses are the server's fault. Something unexpected happened in your infrastructure. Every 5xx is a potential incident. 5xx rates feed your error budget. A production system with a 0.1% 5xx rate is not "fine" — that's one in a thousand requests failing for reasons the client cannot control.

The failure mode is using 5xx for client errors. Two common examples:
- Throwing a 500 when a client sends a malformed request because the JSON parser raised an exception — catch it and return 400.
- Returning 500 when a downstream dependency is temporarily unavailable but the upstream request was valid — return 503 (Service Unavailable) and include a `Retry-After` header.

The other failure mode is using 200 to signal errors (see card 12 on anti-patterns). Both erode the signal that operations teams and clients depend on.

> [!warning] If your monitoring alerts on 4xx rates the same way it alerts on 5xx rates, you will burn out your on-call rotation on noise. Separate them from day one.

@feynman

4xx vs 5xx is like the difference between a customer filling out a form incorrectly and the bank's system going down — both stop the transaction, but one is the customer's problem to fix and the other is yours.

@card
id: apid-ch02-c005
order: 5
title: Idempotency Keys
teaser: When a POST cannot be idempotent by nature, you can make it safe to retry by design — which is exactly what Stripe, Twilio, and AWS do with idempotency keys.

@explanation

POST creates side effects by design, which means retrying a timed-out POST can create duplicate charges, duplicate messages, or duplicate orders. Idempotency keys are how you solve this at the application layer.

The pattern: the client generates a unique key (a UUID) and sends it in a header on the first request. The server processes the request and stores the response against that key. If the same key is received again — whether the original succeeded, failed, or never got a response — the server returns the stored result without re-executing the operation.

Stripe uses `Idempotency-Key` as the header name. Twilio uses the same pattern for message creation. AWS uses `ClientToken` for EC2 and similar operations.

```http
POST /charges HTTP/1.1
Idempotency-Key: a1b2c3d4-e5f6-7890-abcd-ef1234567890
Content-Type: application/json

{"amount": 9900, "currency": "usd", "customer": "cus_abc"}
```

Key design decisions:

- Keys should be caller-generated, not server-generated, so the client has the key before the request is sent.
- Store keys with a TTL (Stripe uses 24 hours). Stale keys should be expired, not kept forever.
- Return `409 Conflict` if the same key is reused with a different request body — the semantics are ambiguous, so reject it rather than guessing.
- The idempotency store must be written atomically with the operation, or you introduce a window where two concurrent requests with the same key both execute.

> [!tip] If you offer an API that handles money, messaging, or any operation with real-world side effects, idempotency keys are not optional. Build them into the API contract from the first version.

@feynman

An idempotency key is like a check number on a paper check — if you send the same check twice, the bank recognizes the number and refuses to cash it a second time, regardless of how many times it arrives.

@card
id: apid-ch02-c006
order: 6
title: Pagination Patterns
teaser: Offset pagination is easy to implement and breaks under concurrent writes; cursor pagination is harder to build and handles real workloads correctly — knowing which failure mode you can live with is the decision.

@explanation

**Offset pagination** uses `?limit=25&offset=50` to request a window of results by position. It is easy to implement on top of SQL (`LIMIT 25 OFFSET 50`) and easy for clients to reason about (page 3 of 25 is offset 50).

The failure modes:
- If a row is inserted before the current offset while a client is paginating, the client sees a duplicate on the next page (the row shifts into the window it already read).
- If a row is deleted, the client skips a row.
- At large offsets, SQL must scan and discard all preceding rows, so `OFFSET 10000` is slow regardless of the LIMIT.

**Cursor pagination** uses an opaque cursor that encodes the position in the result set — typically a base64-encoded value of the last-seen row's sort key. GitHub's API uses this. Stripe uses `starting_after` and `ending_before` (cursor values are object IDs).

```http
GET /orders?limit=25&cursor=eyJpZCI6NDU2fQ HTTP/1.1
```

The cursor approach is stable under concurrent writes because it anchors to a record's identity, not its position. The failure mode is that it doesn't support random access — you cannot jump to page 47 without paginating through pages 1–46. For most product use cases (infinite scroll, next/prev), this is acceptable.

The choice: offset if your data is append-only or your clients need random access and your dataset is small; cursor for everything else.

> [!info] GitHub's REST API uses cursor-based pagination via `Link` headers. Stripe uses `starting_after` with the last object's ID as the cursor. Both are worth studying before designing your own pagination contract.

@feynman

Offset pagination is like asking someone to read you the 50th book on a shelf by counting from the left — if someone adds a book while you're counting, you land on the wrong one; cursor pagination is like using a bookmark — you always find the right page regardless of what was added around it.

@card
id: apid-ch02-c007
order: 7
title: Filtering and Sorting
teaser: Query parameters are the right place for filtering and sorting, but how you structure them determines whether clients can build anything useful and whether your API can evolve without breaking changes.

@explanation

Filtering and sorting belong in query parameters, not in the URL path or the request body. The URL path identifies a resource; query parameters modify how you retrieve it.

Simple key-value filtering is readable and adequate for most APIs:

```http
GET /orders?status=pending&customer_id=cus_123 HTTP/1.1
```

For operators (greater than, less than, in, not in), you need a convention. Common approaches:

- **Bracket notation:** `?created_at[gte]=2024-01-01&created_at[lte]=2024-12-31` — used by Stripe
- **JSON:API convention:** `?filter[status]=pending&filter[customer_id]=cus_123` — namespaces filter params to avoid conflicts with pagination and other params
- **DSL parameter:** `?filter=status eq pending` — flexible but requires a mini-parser and documentation investment; used by OData and Microsoft Graph

Sorting follows the same options:

```http
GET /orders?sort=-created_at,amount HTTP/1.1
```

The JSON:API convention uses a `sort` parameter where a leading `-` means descending. This is widely understood and easy to extend.

Avoid encoding filter logic in the URL path (`/orders/pending` is not a filter, it's a different resource or a sub-collection that you'll need to maintain separately). And avoid accepting filter objects in the request body on GET — it breaks caching and surprises every HTTP client.

> [!tip] Namespace your filter parameters from day one (e.g., `filter[status]` rather than just `status`). It prevents collisions with pagination, sorting, and field-selection parameters as the API grows.

@feynman

Query parameters for filtering are like the search filters on a catalog website — you're not going to a different aisle, you're asking the same catalog to show you a narrower slice of what's already there.

@card
id: apid-ch02-c008
order: 8
title: ETags and Conditional Requests
teaser: ETags give the server a way to tell clients when nothing has changed, enabling both bandwidth-saving caches and race-condition-free updates — two very different problems with the same primitive.

@explanation

An ETag is an opaque string that represents the current version of a resource. The server sets it in the `ETag` response header. The client saves it and sends it back in subsequent requests.

**The cache pattern (If-None-Match):** The client sends `If-None-Match: "abc123"` on a GET. If the resource hasn't changed, the server returns `304 Not Modified` with no body — saving bandwidth and processing. This is what GitHub's API does for resources that rarely change.

```http
GET /users/123 HTTP/1.1
If-None-Match: "etag_v7_xyz"

HTTP/1.1 304 Not Modified
ETag: "etag_v7_xyz"
```

**The optimistic locking pattern (If-Match):** The client sends `If-Match: "abc123"` on a PUT or PATCH. If the ETag no longer matches (someone else modified the resource since the client last read it), the server returns `412 Precondition Failed`. The client must re-fetch, re-apply its changes, and retry.

```http
PATCH /orders/ord_456 HTTP/1.1
If-Match: "etag_v3_abc"
Content-Type: application/json

{"status": "confirmed"}
```

This is how you handle concurrent edits without a distributed lock. The ETag encodes "which version did you read?" and the server enforces "only update if that's still current."

ETags should be cheap to compute — a hash of the resource's content, or a version counter from the database. Weak ETags (`W/"abc123"`) indicate semantic equivalence rather than byte-for-byte identity, which is appropriate for responses with varying representations.

> [!info] The caching use case and the optimistic locking use case look similar but have different semantics. If-None-Match on GET avoids unnecessary transfers. If-Match on PUT/PATCH prevents lost updates. Use them independently as needed.

@feynman

An ETag is like a version stamp on a shared document — when you pick it up to edit, you note the stamp, and when you submit your changes, the server checks that no one else has changed the stamp since you started.

@card
id: apid-ch02-c009
order: 9
title: HATEOAS — When to Bother and When to Skip
teaser: HATEOAS is the part of REST that almost nobody implements fully, and the honest answer is that for most APIs, the tradeoff doesn't pay off.

@explanation

HATEOAS (Hypermedia as the Engine of Application State) is the principle that API responses should include links describing what actions are available next, so clients don't need out-of-band documentation to navigate the API. A fully hypermedia-driven API response looks like:

```http
HTTP/1.1 200 OK
Content-Type: application/hal+json

{
  "id": "ord_123",
  "status": "pending",
  "_links": {
    "self": {"href": "/orders/ord_123"},
    "confirm": {"href": "/orders/ord_123/confirm", "method": "POST"},
    "cancel": {"href": "/orders/ord_123/cancel", "method": "POST"}
  }
}
```

The appeal: clients discover capabilities at runtime, API evolution doesn't require client updates, and the server controls the workflow.

The reality: clients almost always know what they want to do before they read the response. The link discovery model helps crawlers and exploratory tools, but it doesn't match how most API consumers are built. HAL, Siren, and JSON:API all define hypermedia formats, and none has become a universal standard.

Where HATEOAS earns its complexity:
- Workflow-heavy APIs where the available actions genuinely depend on resource state (payment flows, order lifecycles) — including a small set of action links is useful even if you don't go full HAL.
- Public platform APIs with unknown third-party clients (GitHub's API includes partial link headers for this reason).

Where it doesn't:
- Internal APIs between services you control — both ends know the contract.
- APIs with a small, known set of clients — document the state machine, don't encode it in every response.

> [!tip] A practical middle ground: return a `links` object with `self` and the one or two most context-sensitive next actions. You get most of the benefit without adopting a full hypermedia format.

@feynman

HATEOAS is like a GPS that tells you what turns are available at each intersection — great if you don't know the city, overhead if you drive the same route every day.

@card
id: apid-ch02-c010
order: 10
title: Content Negotiation
teaser: The Accept header gives clients a formal way to ask for a specific representation — and vendor MIME types are one of the cleaner ways to version an API without polluting the URL.

@explanation

Content negotiation is the HTTP mechanism by which a client declares what it can consume and the server returns the most appropriate representation. The client sends an `Accept` header; the server responds with `Content-Type` confirming what it sent.

```http
GET /orders/ord_123 HTTP/1.1
Accept: application/json

HTTP/1.1 200 OK
Content-Type: application/json
```

For versioning, vendor MIME types encode the version in the `Accept` header rather than the URL path:

```http
GET /orders/ord_123 HTTP/1.1
Accept: application/vnd.example.v2+json
```

This keeps URLs stable across versions (`/orders/ord_123` rather than `/v2/orders/ord_123`) and lets individual endpoints negotiate their own version. GitHub uses this approach: `application/vnd.github.v3+json`.

If a client requests a representation the server doesn't support, the server returns `406 Not Acceptable`. In practice, most APIs define a default fallback (usually the latest stable version) rather than hard-requiring the versioned MIME type from day one.

The tradeoff compared to URL versioning: vendor MIME types are less visible and harder to test in a browser or basic curl invocation. URL versioning (`/v2/`) is immediately obvious and easy to document. Both are in wide production use. Header versioning is the more "correct" HTTP approach; URL versioning is the more pragmatic one.

> [!info] GitHub's API accepts `application/vnd.github+json` as the current recommended MIME type and maintains backward compatibility with `application/vnd.github.v3+json`. That stability is the actual goal — the mechanism is secondary.

@feynman

Content negotiation is like ordering at a restaurant in your preferred language — you say what you'd like and how you'd like it, and the kitchen decides whether it can fulfill the request or needs to offer you a substitute.

@card
id: apid-ch02-c011
order: 11
title: Error Response Shapes
teaser: Inconsistent error JSON is one of the most common ways to erode client trust — RFC 7807 gives you a standard shape that carries enough context for both humans and machines to act on.

@explanation

RFC 7807 (Problem Details for HTTP APIs) defines a standard JSON shape for error responses. Most teams invent their own error format, get it subtly wrong, and end up with a mix of `{"error": "..."}`, `{"message": "..."}`, and `{"errors": [...]}` across endpoints.

The RFC 7807 structure:

```json
{
  "type": "https://example.com/problems/insufficient-funds",
  "title": "Insufficient Funds",
  "status": 422,
  "detail": "Your account balance of $4.50 is below the required charge of $9.99.",
  "instance": "/payments/pay_abc123"
}
```

- `type` — a URI identifying the error class. Links to documentation. Stable across requests.
- `title` — short, human-readable summary of the error class. Does not change per-instance.
- `status` — the HTTP status code, repeated in the body for clients that don't read headers.
- `detail` — instance-specific explanation. What happened in this request, not what the error class means.
- `instance` — the specific resource or operation that failed. Optional but useful for log correlation.

The format is extensible: you can add fields like `trace_id`, `invalid_params`, or `retry_after` alongside the standard fields. AWS error responses include an `__type` field for the error class and a `message` field. Stripe adds `param` to indicate which request field was invalid.

The minimum viable shape for an internal API: a stable `code` (machine-readable), a `message` (human-readable), and a `trace_id` (for log correlation). Consistency matters more than format — pick one shape and apply it everywhere.

> [!tip] Return the HTTP status code inside the body as well. Proxies, API gateways, and some logging pipelines strip or transform status codes. Having it in the body is cheap insurance.

@feynman

A well-structured error response is like a rejection letter that tells you exactly which requirement you didn't meet — not just "no," but which rule, which field, and what to do differently next time.

@card
id: apid-ch02-c012
order: 12
title: REST Anti-Patterns
teaser: The most common REST mistakes are verbs in URLs, success responses that carry errors, and tunneling everything through POST — and all three survive in production APIs because they work until they don't.

@explanation

Three anti-patterns account for most of the "REST" APIs that aren't actually RESTful:

**Verbs in URL paths.** `/getUserById`, `/createOrder`, `/cancelSubscription`. These are RPC over HTTP. They work, but they abandon the uniform interface that makes REST useful — caching, idempotency, and method semantics all rely on the URL identifying a resource and the method describing the action.

**200 with an error body.** Returning `HTTP/1.1 200 OK` with a body like `{"success": false, "error": "Not found"}` breaks every HTTP-aware layer in the stack. Load balancers track 5xx rates, not JSON `success` fields. Client libraries that raise on 4xx/5xx pass silently. Logging pipelines tag the request as successful. The entire observability stack becomes wrong.

```http
HTTP/1.1 200 OK
Content-Type: application/json

{"success": false, "error": "Account not found", "code": 1042}
```

This pattern often originates from environments where every request was proxied through a single endpoint that couldn't return non-200 responses. It leaks into production APIs and stays there because changing it is a breaking change.

**Tunneling everything through POST.** Using `POST /api` with `{"action": "getUser", "id": 123}` in the body is SOAP with JSON syntax. It defeats HTTP caching (POSTs are never cached), breaks idempotency, and makes API documentation significantly harder because the URL carries no semantics.

The common thread: all three patterns trade short-term implementation convenience for long-term operational cost. They work fine in development and cause real problems at scale — during incidents when status code dashboards are wrong, when retries create duplicate operations, and when teams try to add caching to endpoints that don't support it.

> [!warning] Changing from 200-error to proper status codes is a breaking change. If you have an existing API with this pattern, version it rather than fixing it in place — clients may be checking `response.body.success` instead of `response.status`.

@feynman

Returning 200 with an error body is like a delivery service that marks every package "delivered" in its tracking system regardless of what actually happened — the dashboard looks fine and everything downstream is broken.
