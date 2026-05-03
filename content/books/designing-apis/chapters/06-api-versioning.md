@chapter
id: apid-ch06-api-versioning
order: 6
title: API Versioning
summary: API versioning is mostly about deciding what counts as a breaking change and how long you owe support to old consumers — and the technical mechanics (URL, header, media-type) are downstream of that policy.

@card
id: apid-ch06-c001
order: 1
title: Versioning Is Policy, Not Mechanics
teaser: Before you pick URL paths versus headers, you need to answer a harder question — what are you actually promising to your consumers, and for how long?

@explanation

Every versioning debate that starts with "should we put it in the path or the header?" is starting in the wrong place. The URL scheme is a detail. The policy is the foundation.

Your versioning policy is the set of commitments you make to consumers:

- Which changes are considered breaking and will trigger a new version.
- How long you will continue to support an old version once a new one exists.
- How much notice you will give before you retire a version.
- How you will communicate that notice.

Without answering those four questions, picking a URL scheme is meaningless. A team that ships `/v2` every time they rename a field is just as disruptive as one that silently removes fields on `/v1` — they've made a choice about policy, just an unconsidered one.

The mechanics — where the version token lives in a request — are how you signal which version a consumer wants. But they don't define what a version is, or when you need a new one, or when the old one goes away. Those are judgment calls that need to be made once, written down, and communicated to consumers before they start building on your API.

Teams that skip the policy step end up revisiting the mechanics decision every six months, because the mechanics never solve the underlying problem.

> [!tip] Write your versioning policy in a single public document before you write a line of versioned code. Even a rough draft forces the conversations that need to happen.

@feynman

You can't decide how to label something until you decide what it is you're promising — the mechanics of versioning are just labels on a promise you've already made.

@card
id: apid-ch06-c002
order: 2
title: What Counts as a Breaking Change
teaser: Consumers break when your API does something different from what the contract said — and the contract is often broader than the schema you published.

@explanation

The practical definition: a breaking change is any change that causes a correctly written client to fail or behave incorrectly.

Changes that are generally safe (non-breaking):

- Adding a new optional field to a response body.
- Adding a new optional request parameter.
- Adding a new endpoint or resource.
- Adding a new enum value (with caveats — see below).
- Relaxing a validation constraint (accepting what you previously rejected).

Changes that are breaking:

- Removing a field from a response body.
- Renaming a field (equivalent to removing one and adding another).
- Changing a field's type (e.g., `string` to `integer`, or `object` to `array`).
- Tightening a validation constraint (rejecting what you previously accepted).
- Changing the meaning of an existing field even if the type stays the same.
- Removing an endpoint.
- Changing authentication requirements.

The enum caveat: adding a new enum value is technically non-breaking on your end, but it breaks clients that use exhaustive switch statements with no default case. Stripe documents this explicitly and asks clients to handle unknown enum values gracefully. If your consumers include strongly typed clients, adding enum values is effectively a breaking change.

The "meaning" problem is the sneakiest: changing what an `integer` field represents — say, switching from milliseconds to seconds — doesn't break deserialization, but it breaks every consumer that does math with that value.

> [!warning] Schema compatibility is necessary but not sufficient. Semantic changes that preserve the schema are still breaking changes.

@feynman

A breaking change is anything that makes a client that was right yesterday wrong today — and that includes changing what a field means, not just its name or type.

@card
id: apid-ch06-c003
order: 3
title: URL Versioning
teaser: Putting the version in the path — `/v1/orders`, `/v2/orders` — is the most widely adopted approach for public APIs, and its dominance comes from a specific set of practical advantages.

@explanation

URL versioning embeds the version token directly in the path:

```http
GET /v1/orders/123 HTTP/1.1
Host: api.example.com
```

```http
GET /v2/orders/123 HTTP/1.1
Host: api.example.com
```

Why it dominates public APIs:

- **Discoverability.** The version is visible in every log line, every browser tab, every curl command. You never have to debug which version a request was targeting.
- **Cache-friendliness.** HTTP caches key on URLs. Different versions at different paths cache independently without any special logic.
- **Simplicity.** Routing by URL path is the default behavior of every reverse proxy, load balancer, and API gateway on the market. No custom header parsing required.
- **Linkability.** You can share, bookmark, or hardcode a URL and it stays valid for as long as that version exists.

The real costs:

- **URL proliferation.** Resources exist at multiple paths simultaneously. You need routing rules for every version you keep alive. Documentation splits across versions.
- **"Versions" feel permanent.** Consumers embed `/v1/` in their code and never revisit it. The path creates an implicit guarantee that v1 will live forever — or at least long enough that there's no urgency to migrate.
- **Breaks REST purity.** Strict REST argues that a URL should identify a resource, not a resource-at-a-particular-version. In practice, this argument loses to operational clarity almost every time.

Twilio, Stripe (for older endpoints), and virtually every large public API platform use URL versioning. For APIs consumed by third parties you don't control, it is the most defensible default.

> [!info] URL versioning is the right default for public APIs. The discoverability and routing simplicity outweigh the philosophical objections in almost every real deployment.

@feynman

URL versioning is the least clever approach — and that's why it works: the version is right there in every request, visible to everyone, with no special knowledge required to route or debug it.

@card
id: apid-ch06-c004
order: 4
title: Header Versioning
teaser: Putting the version in a custom request header keeps your URLs clean and your resources stable — but the discoverability cost is real, and it penalizes casual consumers.

@explanation

Header versioning passes the version token in a request header rather than the URL:

```http
GET /orders/123 HTTP/1.1
Host: api.example.com
Accept-Version: 2
```

The URL stays the same across versions. Only the header changes. From a REST perspective, this is the cleaner model: the URL identifies the resource, and the header communicates protocol preferences.

Where it fits well:

- **Internal APIs** where all consumers are services you operate. Every client is code you control, so you can ensure the header is always set correctly.
- **APIs with stable, long-lived clients** — mobile SDKs, server-side libraries — where the version is set once in a configuration file and rarely touched.
- **Teams that care about URL stability** for documentation or SEO purposes.

The problems in practice:

- **You can't test it from a browser.** Pasting a URL into a browser doesn't produce a versioned request. Debugging and exploration require tooling that sets headers.
- **Logs and traces omit the version by default.** If your observability stack logs request paths, you've lost the version signal. You have to specifically instrument header capture to know which version each request was targeting.
- **It doesn't survive intermediaries.** Some proxies and CDNs strip or transform custom headers. Version headers in particular are frequently problematic.
- **Documentation is harder to link.** You can't construct a URL that unambiguously refers to a resource at a specific version.

Header versioning is not wrong — it's a coherent choice for the right context. But public APIs that depend on casual adoption (where someone runs `curl` from the command line and expects it to work) pay a meaningful discoverability penalty.

> [!warning] If your API is externally facing and you expect consumers to explore it without reading the docs first, header versioning will confuse a meaningful percentage of them.

@feynman

Header versioning keeps the URL clean but hides the version from anyone not reading the request metadata — it's a better model for machines talking to machines than for humans exploring an API.

@card
id: apid-ch06-c005
order: 5
title: Media-Type Versioning
teaser: Media-type versioning uses the `Accept` header to negotiate both format and version — it's the most HTTP-correct approach, and it's what GitHub chose for its REST API.

@explanation

Media-type versioning encodes the version into the `Content-Type` and `Accept` headers using a vendor-specific media type:

```http
GET /repos/octocat/Hello-World HTTP/1.1
Host: api.github.com
Accept: application/vnd.github.v3+json
```

The server responds with the corresponding `Content-Type`:

```http
HTTP/1.1 200 OK
Content-Type: application/vnd.github.v3+json
```

This is content negotiation extended to the version dimension. The URL remains stable. The representation of the resource changes based on what the client declares it can accept. RFC 6838 defines the `vnd.` prefix convention for vendor-specific media types.

Why it's conceptually correct:

- The URL identifies the resource. The `Accept` header describes what format and version of the representation you want. That is precisely what `Accept` is for.
- It's the mechanism HTTP already provides for negotiating representation formats — versioning is a natural extension.

Why most teams don't use it:

- **Verbose and unfamiliar.** The `vnd.example.v3+json` syntax is obscure to developers who don't live in the HTTP spec.
- **Hard to test interactively.** Like header versioning, you can't explore it from a browser address bar.
- **Parsing complexity.** You need proper content negotiation logic on the server, not just a URL prefix router.
- **Two headers to manage.** Both `Accept` (request) and `Content-Type` (response) need to carry the versioned media type consistently.

GitHub uses this pattern and documents it well. For most teams, the cognitive overhead relative to URL versioning is not justified — but it is the cleanest expression of the HTTP resource model.

> [!info] Media-type versioning is the most semantically correct approach. It's also the most operationally complex. Most teams accept that tradeoff by choosing URL versioning instead.

@feynman

Media-type versioning says "the URL identifies the thing; the Accept header identifies which version of the thing you speak" — it's the HTTP model done right, which is why it's beautiful in theory and uncommon in practice.

@card
id: apid-ch06-c006
order: 6
title: Query Parameter Versioning
teaser: Passing the version as a query parameter (`?version=2`) is common in practice and usually wrong — it conflates filtering parameters with protocol negotiation, and most of its apparent advantages are illusory.

@explanation

Query parameter versioning looks like this:

```http
GET /orders/123?version=2 HTTP/1.1
Host: api.example.com
```

Or in the variant used by some AWS and Google services:

```http
GET /orders/123?api-version=2021-01-01 HTTP/1.1
```

Why teams reach for it:

- It keeps the URL path clean.
- It's easy to test in a browser or with curl without setting headers.
- It "feels" like URL versioning without committing to a versioned path.

Why it's usually wrong:

- **Semantics are muddled.** Query parameters communicate filtering, sorting, and pagination state. A version parameter is a different category of concern — it's protocol negotiation, not resource selection. Mixing them creates confusion about what the query string means.
- **Caching breaks down.** HTTP caches treat `?version=1` and `?version=2` as different resources, which is correct — but caching infrastructure often handles query parameters inconsistently, and version parameters accidentally end up excluded from cache keys.
- **Optional semantics are dangerous.** If `?version=` is omitted, what version do you serve? If the default changes over time, omitting the parameter becomes a hidden breaking change. If the default never changes, old clients are pinned forever.
- **Discoverability is no better than header versioning.** You can paste the URL in a browser, but the version is easy to omit and easy to misread in a long query string.

The exceptions: AWS services like CloudFormation and Google Cloud APIs use date-stamped query parameters (`?api-version=2021-01-01`) with some success — but those are tightly controlled internal-facing APIs with sophisticated client tooling, not patterns to replicate casually.

> [!warning] Query parameter versioning appears to combine the benefits of URL and header approaches, but in practice it gets the tradeoffs of both without the full benefits of either.

@feynman

Query parameter versioning is version information wearing the wrong clothes — it looks like filtering state, lives next to your sort orders and page sizes, and creates confusion that URL path versioning sidesteps entirely.

@card
id: apid-ch06-c007
order: 7
title: The Evergreen API Model
teaser: Some teams never version their API at all — they commit to backward compatibility as a permanent discipline, so consumers always get the latest behavior without needing to migrate.

@explanation

The evergreen model's premise: if you never make a breaking change, you never need a version. Every addition is backward-compatible. Old clients keep working. No migration, no deprecation timelines, no N-1 support cost.

What this requires in practice:

- **Strict change management.** Every proposed API change goes through a review that asks: "does this break any existing client?" The bar is higher than most teams maintain.
- **Additive-only field policy.** You add fields; you never remove or rename them. Fields you regret live in the schema forever, clearly documented as deprecated.
- **Permissive consumers.** Clients must ignore unknown fields rather than failing on them. If your consumers are code you ship (a mobile SDK, a server-side library), you can enforce this. If they're arbitrary third parties, you can't.
- **Semantic discipline.** You commit to never changing what a field means even if you'd do it differently today.

The hidden cost: over time, the schema accumulates the archaeology of past decisions. Fields with misleading names stay. Behavioral quirks that can't be changed become load-bearing. The API becomes harder to understand for new consumers even as it remains stable for old ones.

This model works well for:

- Internal service-to-service APIs where all consumers are code you own.
- SDKs where you control both the API and the client library.
- APIs designed explicitly around the open/closed principle from the start.

It tends to break down for public APIs that predate the discipline — the legacy decisions are already baked in, and "never remove anything" means carrying those decisions indefinitely.

> [!tip] Evergreen is a legitimate strategy, but it requires more rigor than versioning, not less. Teams that adopt it without the discipline end up with the worst of both worlds — an inconsistent schema that's also hard to migrate.

@feynman

The evergreen model says you'll never need a version bump because you'll never do anything that breaks a client — which sounds like less work until you realize it requires more discipline, not less.

@card
id: apid-ch06-c008
order: 8
title: Expand-Contract for Breaking Changes
teaser: When a breaking change is unavoidable, the parallel-change pattern — expand, migrate, contract — lets you make it without a hard cutover that breaks consumers overnight.

@explanation

Expand-contract (also called parallel-change) is a three-phase technique for making breaking changes to an API contract without forcing all consumers to migrate at once.

**Phase 1: Expand.** Add the new shape alongside the old one. If you're renaming a field from `customer_id` to `account_id`, add `account_id` to the response while keeping `customer_id`. Accept both field names in requests. Publish the change with clear documentation: `customer_id` is deprecated, `account_id` is the new name, both are supported until a specified date.

**Phase 2: Migrate.** Give consumers time to update. Communicate actively — changelogs, email lists, deprecation headers on every response. Track which consumers are still reading `customer_id` via usage analytics or logging. Actively help high-volume consumers migrate. This phase is where most of the calendar time lives.

**Phase 3: Contract.** Once usage of the old shape has dropped to zero (or an acceptable threshold), remove it. This is now a non-event for consumers — everyone already migrated. If a consumer missed the migration, their code breaks, but they were warned.

The key insight: phase 3 is only safe because phase 1 and phase 2 were thorough. Teams that skip straight to "remove the old field on a date" and hope everyone migrated are not doing expand-contract — they're doing a hard cutover with advance notice, which is a different (riskier) thing.

Expand-contract works for field renames, type changes, endpoint restructuring, and authentication changes. It requires you to maintain the old and new shapes simultaneously during phase 2, which has a maintenance cost — but that cost is lower than coordinating simultaneous consumer migrations across dozens of teams.

> [!info] The migration phase has no fixed length. It ends when usage of the old shape is gone, not when a calendar date arrives.

@feynman

Expand-contract is the "build the new road before closing the old one" approach to API changes — consumers migrate when they're ready, not when you pull the rug out.

@card
id: apid-ch06-c009
order: 9
title: Deprecation Policy and HTTP Headers
teaser: Deprecation without a timeline is just documentation. HTTP provides two headers — `Deprecation` and `Sunset` — that make deprecation machine-readable and visible in the response itself.

@explanation

Two RFCs formalize deprecation signaling in HTTP responses:

- **RFC 9745 — `Deprecation` header:** Signals that the resource or API version being accessed is deprecated. The value is an HTTP date indicating when the deprecation was announced, or the boolean `true` if the date is unknown.
- **RFC 8594 — `Sunset` header:** Signals when the resource will become unavailable. The value is an HTTP date (the planned shutdown date).

A deprecation response looks like this:

```http
HTTP/1.1 200 OK
Deprecation: Sat, 01 Jan 2025 00:00:00 GMT
Sunset: Sat, 01 Jul 2025 00:00:00 GMT
Link: <https://api.example.com/v2/orders>; rel="successor-version"
```

The `Link` header with `rel="successor-version"` is the third piece — it tells a consuming client where to go instead.

What makes this useful beyond plain documentation: monitoring tools and API gateways can parse these headers automatically and surface deprecation warnings in dashboards, alerting, and SDK logs. Stripe's SDKs and several API management platforms treat `Sunset` as a first-class signal. Consumers who are logging response headers will see the deprecation even if they never read the changelog.

Reasonable timelines for public APIs:

- Minimum six months from announcement to sunset for stable endpoints.
- Twelve months is a more defensible default for widely adopted APIs.
- Internal service APIs can run shorter windows, but three months is a reasonable floor.

The precise timeline matters less than the consistency: pick a policy, document it, and apply it uniformly so consumers can plan.

> [!tip] Add `Deprecation` and `Sunset` headers to every response from a deprecated endpoint — not just the documentation page. The header is the most reliable way to ensure a consuming developer sees the warning in context.

@feynman

The `Deprecation` and `Sunset` headers turn deprecation from a blog post someone might miss into a signal visible in every response that monitoring tools can act on automatically.

@card
id: apid-ch06-c010
order: 10
title: Communicating Deprecation to Consumers
teaser: Announcing a deprecation once is not the same as ensuring consumers act on it — the communication plan matters as much as the technical mechanism.

@explanation

Response headers signal deprecation to the technical layer. Reaching the humans who need to schedule migration work requires a different set of channels.

The full communication stack for a deprecation:

- **Changelog entry.** The canonical record. Date, what's changing, why, what consumers should do, and by when. Should be linkable from every other notice.
- **In-response warning.** `Deprecation` and `Sunset` headers on every deprecated endpoint, plus — for APIs that support it — a `X-Warning` or response body field that prints a human-readable notice the first time (or on some interval). Twilio has used this pattern effectively.
- **Email to registered developers.** Opt-in contact to the email addresses of applications actively calling the deprecated endpoint. Not a mass blast — targeted to consumers with actual usage.
- **Developer dashboard notice.** A banner or alert in the developer portal tied to the specific application's usage data. Slack and Stripe both surface these inline in their dashboards.
- **SDK release notes.** If you ship client libraries, the next SDK release after a deprecation announcement should emit a runtime warning when the deprecated path is called.
- **Direct outreach for high-volume consumers.** Any consumer accounting for significant traffic on the deprecated endpoint deserves a direct message, not just a changelog entry.

What not to do: announce once on a blog post and assume consumers will find it. Most won't. Developer attention is scarce. The deprecation communication plan is a series of touchpoints across multiple channels, spaced over the migration window, not a single notification event.

> [!info] Deprecation adoption is a marketing problem as much as a technical one — you're asking consumers to spend engineering time on migration work that benefits you, not them. The communication plan needs to reflect that reality.

@feynman

Deprecating an API is easy; getting consumers to migrate before the deadline requires a communication strategy that meets developers where they actually look, not where you wish they looked.

@card
id: apid-ch06-c011
order: 11
title: Multi-Version Support Cost and Version Retirement
teaser: Every version you keep alive is infrastructure, testing, and documentation overhead — the N-1 support window is a real operational commitment, and N-2 needs a clear death date.

@explanation

When you ship v2, v1 doesn't disappear. It continues to serve requests, accept deployments, receive security patches, and appear in test suites. That cost is invisible until you have three or four versions in active support simultaneously.

The N-1 model: you commit to supporting the current version (N) and the previous version (N-1). Consumers on N-2 or older are out of the support window and migrate at their own risk. This is the model GitHub, Twilio, and most mature API platforms use.

What N-1 support actually requires:

- **Infrastructure.** Both versions need routing, deployment slots, and capacity. URL versioning makes this visible (two path prefixes); other schemes still require it.
- **Bug fixes applied to both versions.** A security vulnerability in shared logic needs to be patched in every supported version. The more versions you maintain, the more places you patch.
- **Test suite coverage per version.** Integration tests need to run against every version you promise to support.
- **Documentation kept current.** A documented behavior difference between v1 and v2 needs to stay accurate for as long as both versions exist.

Version retirement (killing N-2):

Announce the retirement of an old version before you ship a new one, not after. Consumers need to know that when you ship v3, v1's clock starts. The Sunset header carries the exact date. The retirement should be a non-event if the migration window was real.

The cost of skipping version retirement: Stripe still serves API versions from 2014. The codebase carries a decade of compatibility shims. That's a real cost — carefully managed by Stripe, but not a model most teams can replicate without Stripe's engineering investment.

> [!warning] "We'll support it indefinitely" is not a policy — it's an absence of policy. Every version needs a planned retirement date from the moment it's deprecated.

@feynman

Keeping an old API version alive is like keeping a spare apartment — it feels fine when you have one, but by the time you have four, the maintenance is a full-time job.

@card
id: apid-ch06-c012
order: 12
title: Stripe's Date-Versioned API and Anti-Patterns to Avoid
teaser: Stripe's versioning model is one of the most studied in the industry — and the anti-patterns it implicitly guards against are the ones most teams stumble into first.

@explanation

Stripe's API uses date-stamped versions rather than sequential integers:

```http
GET /v1/charges HTTP/1.1
Stripe-Version: 2024-04-10
```

Each date represents a point-in-time snapshot of the API contract. When a new version is released (a new date), accounts are pinned to the version they were created on — they continue to receive the old behavior by default unless they explicitly upgrade. Stripe maintains compatibility for pinned versions for years, with a published policy of never retiring a version while any paying customer is pinned to it.

The migration tooling they built to make this sustainable:

- A changelog entry for every version date, listing every behavioral change.
- API request logs that show which version each call was made against.
- A "version upgrade" flow in the dashboard that shows a diff of how your specific API usage would change under the new version.
- SDK methods that let you override the version for a single request in test mode.

The anti-patterns Stripe's model is designed to prevent:

- **Silent breaking changes.** The worst category. Changing behavior on an existing endpoint without a version bump, changelog entry, or any signal to consumers. Consumers find out when something breaks in production.
- **Version bumps for non-breaking changes.** Shipping v2 because you added three optional fields. This depletes the goodwill version numbers carry and trains consumers to ignore version migrations.
- **v2 that's mostly v1 with a rename.** A new major version that provides no material improvement, just a cleanup — forcing consumers to migrate for nothing. The political will to maintain two versions evaporates quickly when v2 has no clear advantage.
- **Skipping the deprecation window.** Announcing a breaking change and removing the old behavior in the same release cycle.

Most teams can't replicate Stripe's full model. The useful lessons are: pin behavior explicitly, communicate changes at the per-behavior level (not per-version), and build tooling that makes migration visible to consumers.

> [!info] The expensive part of Stripe's model is not the version pinning — it's the observability and migration tooling they built on top of it. The pinning without the tooling just defers the migration problem.

@feynman

Stripe's versioning model is a decade of lessons about what happens when you have millions of consumers who can't all migrate at the same time — and the core insight is that visibility and tooling matter more than where you put the version token.
