@chapter
id: apid-ch07-api-security
order: 7
title: API Security
summary: API security is layered — authentication says who, authorization says what, transport says how it travels, rate limits say how often, and CORS says who in the browser can talk to you — and missing any layer is a vulnerability.

@card
id: apid-ch07-c001
order: 1
title: Layered API Security
teaser: API security is not one mechanism — it is five distinct layers, and attackers don't care which one you skipped.

@explanation

Every API has the same five questions to answer:

- **Who are you?** — Authentication. Is this caller who they claim to be?
- **What are you allowed to do?** — Authorization. Does this caller have permission for this resource and action?
- **Is the channel safe?** — Transport security. Is the data in transit encrypted and the server's identity verified?
- **How often can you call?** — Rate limiting. Is this caller consuming resources within acceptable bounds?
- **Where is this request coming from in a browser?** — CORS. Is this cross-origin browser request permitted?

The failure mode of treating security as a single gate is that bypassing one layer exposes everything behind it. A service with strong authentication but no authorization lets any authenticated user access any other user's data (BOLA — broken object-level authorization, the OWASP API Security Top 10 2023 number-one vulnerability). A service with authorization but no rate limiting is vulnerable to credential stuffing at scale. A service with rate limiting but no TLS leaks credentials in transit.

The architectural discipline is to treat each layer as independently required. They compose, but none substitutes for another.

> [!warning] "We have JWTs" is not the same as "we have security." Authentication is one layer. Every other layer still needs to be present and correctly configured.

@feynman

API security is like a bank vault that needs a keypad code, a fingerprint, a guard check, a time lock, and a weight sensor — removing any one of them, even if the others are strong, creates a path in.

@card
id: apid-ch07-c002
order: 2
title: API Keys
teaser: API keys are the simplest credential mechanism — they work well for server-to-server integrations where the key never leaves a controlled environment, and they fall apart the moment they appear in client-side code.

@explanation

An API key is an opaque string that identifies and authenticates a caller. The server maps the key to a client identity and, optionally, a permission set. Keys are passed in a header (most common), a query parameter (less secure — keys appear in server logs), or occasionally in the request body.

```http
GET /v1/data HTTP/1.1
Authorization: Bearer sk_live_abc123...
X-Api-Key: sk_live_abc123...
```

Where API keys are appropriate:

- Server-to-server calls where the key is stored in an environment variable or secrets manager, never in client-side code.
- Internal service integrations in a controlled network (behind a VPN or in a private subnet).
- Developer tooling and CLIs where the developer owns the key.

Where API keys break down:

- **No expiry by default.** A compromised key is valid indefinitely unless you explicitly rotate or revoke it. Most teams don't rotate until after a breach.
- **No identity delegation.** A key identifies an application, not a user acting within an application. You cannot issue a key that says "this is Alice, who has read access to her own data only."
- **Single factor.** If the key leaks — through a public GitHub commit, a browser's network tab, a log aggregator — the attacker has full access. There is no second factor to verify.
- **Client-side is fatal.** API keys embedded in mobile apps or browser JavaScript are effectively public. Reverse engineering an APK or reading JavaScript bundles takes minutes.

> [!warning] API keys committed to a public repository are actively scanned and exploited within minutes of the push. Use a secrets manager (Vault, AWS Secrets Manager, environment variables) — never a config file that might enter version control.

@feynman

An API key is like a physical keycard — it's convenient and works fine when you keep it in your pocket, but if you leave it on the desk where anyone can photograph it, everyone now has your access.

@card
id: apid-ch07-c003
order: 3
title: OAuth 2.0 and OIDC
teaser: OAuth 2.0 (RFC 6749) is the standard for delegated authorization — letting a user grant an application access to their resources on another service without handing over their password.

@explanation

OAuth 2.0 defines four authorization flows (called "grant types"), each suited to a different client type and trust level:

**Authorization Code (+ PKCE):** The user is redirected to the authorization server, authenticates there, and a short-lived code is returned to the client. The client exchanges the code for tokens server-side. PKCE (Proof Key for Code Exchange) adds a code verifier/challenge to prevent code interception — required for public clients (mobile apps, SPAs). This is the correct flow for any application that acts on behalf of a user.

**Client Credentials:** The client authenticates directly with the authorization server using its own client ID and secret, receiving an access token without user involvement. The correct flow for machine-to-machine (M2M) communication where there is no user in the loop.

**Device Code:** Used when the client cannot display a browser (a smart TV, a CLI tool). The device shows a code, the user goes to a URL on another device to authorize, and the client polls for the token. Correct for browserless environments.

**Implicit:** The access token is returned directly in the redirect URL. Deprecated — never use it. PKCE with Authorization Code replaces it entirely.

OpenID Connect (OIDC) is a thin identity layer on top of OAuth 2.0. While OAuth 2.0 only answers "what can this client do?", OIDC adds a signed ID token (a JWT) that answers "who is this user?" — including claims like `sub` (subject identifier), `email`, `name`, and `iat` (issued at).

> [!info] OAuth 2.0 is for authorization; OIDC is for authentication. Using OAuth 2.0's access token to answer "who is this user?" is a common misuse — that's what the OIDC ID token is for.

@feynman

OAuth 2.0 is like using a valet key — you give the parking attendant a key that only opens the car door and starts the engine, not a key that opens your house; you've delegated one specific permission without handing over everything.

@card
id: apid-ch07-c004
order: 4
title: JWTs as Access Tokens
teaser: A JWT (RFC 7519) is a self-contained, signed token that carries claims — the server can verify it without a database lookup, which is both its biggest advantage and its most dangerous failure mode.

@explanation

A JSON Web Token has three Base64URL-encoded parts separated by dots: a header, a payload, and a signature.

```json
// Header
{
  "alg": "RS256",
  "typ": "JWT"
}

// Payload (claims)
{
  "sub": "user_abc123",
  "iss": "https://auth.example.com",
  "aud": "https://api.example.com",
  "exp": 1700000000,
  "iat": 1699996400,
  "scope": "read:orders write:cart"
}
```

The signature is computed over the header and payload using the key specified in `alg`. A resource server (your API) verifies the signature using the authorization server's public key (for RS256/ES256) or a shared secret (for HS256 — avoid in distributed systems).

Why stateless verification matters: the API does not need to call the authorization server or hit a database on every request. It verifies the signature, checks `exp` (not expired), `iss` (trusted issuer), and `aud` (intended for this API), then trusts the claims.

The dangerous failure modes:

- **`alg: none`** — some early JWT libraries accepted unsigned tokens if the header said `alg: none`. Always explicitly validate the algorithm; never accept what the token claims.
- **Not validating `aud`** — a token issued for one API is accepted by another. Cross-audience replay becomes possible.
- **Not validating `exp`** — the token is checked after it has expired. An attacker with a stolen token has unlimited time.
- **No revocation path.** A JWT is valid until it expires. If you need to invalidate it early (user logs out, compromised token), you need a block list — which reintroduces state.

> [!warning] The "stateless" benefit of JWTs disappears if you need immediate revocation. Short expiry (15 minutes or less for access tokens) is the primary mitigation; a server-side deny list is the safety net.

@feynman

A JWT is like a signed check — anyone can verify the signature is real without calling the bank, but once signed it cannot be cancelled until the date on it passes, so you keep the amounts small and the dates close.

@card
id: apid-ch07-c005
order: 5
title: Token Rotation and Refresh Tokens
teaser: The short-lived access token plus long-lived refresh token pattern balances security (limited exposure window) with usability (no re-login every 15 minutes).

@explanation

The access token / refresh token pair works as follows:

- The authorization server issues an **access token** with a short expiry (typically 5–15 minutes) and a **refresh token** with a long expiry (hours, days, or until explicitly revoked).
- The client uses the access token for API calls. When it expires (or just before), the client presents the refresh token to the token endpoint and receives a new access token.
- The refresh token itself should be rotated on each use: the authorization server invalidates the old refresh token and issues a new one. This is refresh token rotation.

Why rotation matters: if an attacker steals a refresh token and uses it, the server can detect the anomaly — the legitimate client will attempt to use the old (now-invalidated) token, which signals a replay attack. The server can invalidate the entire token family.

Implementation requirements:

- Refresh tokens must be stored securely. In a browser, `httpOnly`, `Secure`, `SameSite=Strict` cookies are the correct storage mechanism — not `localStorage`, which is accessible to any JavaScript running on the page.
- In mobile apps, the platform secure enclave (iOS Keychain, Android Keystore) is the correct location.
- Refresh token endpoints must be rate-limited. An attacker with a stolen refresh token will attempt to use it before the legitimate client does.

The failure mode is infinite-lived access tokens (no expiry or very long expiry) combined with no revocation mechanism. A stolen token from a session three months ago is still valid.

> [!tip] Set access token expiry to 15 minutes or less. Set refresh token expiry based on session idle timeout requirements, not "what feels comfortable." Enable refresh token rotation. These three settings together close most stolen-token attack windows.

@feynman

Access tokens are like a day pass at a concert venue — valid for a few hours, then you exchange your wristband for a fresh one at the desk; the refresh token is the receipt that lets you do that exchange without buying a new ticket.

@card
id: apid-ch07-c006
order: 6
title: Mutual TLS (mTLS)
teaser: In standard TLS the client verifies the server's certificate; in mTLS both sides present certificates — making it the strongest credential mechanism for service-to-service communication and the most operationally expensive.

@explanation

Standard TLS provides transport encryption and server identity verification. The client checks that the server's certificate was signed by a trusted CA, establishing that it is talking to the correct server. The server has no cryptographic proof of who the client is.

Mutual TLS adds client certificate authentication. The client presents its certificate during the TLS handshake; the server verifies it against a trusted CA (often an internal CA for service meshes). Both parties are cryptographically proven to each other before any application-layer data is exchanged.

Why mTLS beats bearer tokens for internal service-to-service communication:

- The credential (a private key) never travels over the network. Bearer tokens must be transmitted on every request.
- Certificate verification happens at the transport layer, before HTTP parsing, before any application code runs. A misconfigured application cannot accidentally bypass it.
- Revocation can happen at the infrastructure level (CRL or OCSP), independently of application code.

The operational cost:

- **Certificate lifecycle management.** Certificates must be issued, rotated before expiry, and revoked when a service is decommissioned. Service mesh platforms (Istio, Linkerd) automate this via short-lived certificates (24-hour SPIFFE/X.509 certs), making rotation transparent.
- **PKI infrastructure.** You need an internal CA — either self-managed (cert-manager + Vault) or managed (AWS Private CA). This is non-trivial to operate correctly.
- **Debugging complexity.** TLS handshake failures are harder to diagnose than a 401 with a descriptive body.

> [!info] In a Kubernetes service mesh with Istio or Linkerd, mTLS between services is on by default and certificate rotation is automated. The operational cost argument against mTLS is largely resolved when a mesh is already in use.

@feynman

mTLS is like two people meeting by exchanging sealed letters from their respective embassies — neither side trusts the other's words alone; each verifies the other's official credentials before the conversation begins.

@card
id: apid-ch07-c007
order: 7
title: Rate Limiting Strategies
teaser: Rate limiting protects your API from abuse, accidental amplification, and credential stuffing — and the algorithm you choose determines how well it handles bursts and how fair it is across callers.

@explanation

Four common algorithms:

**Fixed Window:** Count requests within a fixed time window (e.g., 100 requests per minute, reset at :00 each minute). Simple to implement. The failure mode: a caller can make 100 requests at :59 and 100 more at :01, yielding 200 requests in a two-second window at the boundary — double the intended limit.

**Sliding Window:** Track request timestamps over a rolling window (e.g., the last 60 seconds). More accurate than fixed window; eliminates boundary bursts. Higher memory cost — you must store per-request timestamps or use an approximate sliding log.

**Token Bucket:** A bucket holds tokens up to a maximum capacity. Tokens are added at a fixed rate. Each request consumes one token. If the bucket is empty, the request is rejected or queued. The bucket allows short bursts (up to capacity) while enforcing an average rate. AWS API Gateway uses token bucket semantics.

**Leaky Bucket:** Requests are added to a queue (the bucket) and processed at a fixed output rate. Excess requests either queue (introducing latency) or are dropped. Unlike token bucket, leaky bucket smooths bursts into a constant rate — useful when the downstream system cannot handle variable rates.

Granularity choices: rate limit per API key, per user, per IP, per endpoint, or combinations. Per-IP limiting alone is weak against distributed botnets and proxied clients.

The failure mode of coarse limits: a single abusive caller consuming the entire rate limit budget of a shared pool, degrading service for legitimate callers. Dedicate per-client limits for any API where callers have distinct identities.

> [!info] Token bucket is the most common choice for external APIs because it allows legitimate bursts (a user refreshing a dashboard quickly) while enforcing a sustainable average rate. Leaky bucket is better for protecting fragile downstream systems that cannot handle burst load.

@feynman

Token bucket is like a turnstile with a token dispenser — tokens refill steadily, you can save a few up if you wait, but the bucket only holds so many, and if you empty it you wait for it to refill before you get back in.

@card
id: apid-ch07-c008
order: 8
title: Rate Limit Response Shapes
teaser: When you reject a request for rate limiting, the response must tell the caller what happened, when they can retry, and how much budget they have left — without this, clients implement random backoff or, worse, hammered retry loops.

@explanation

The correct HTTP status code for rate limiting is `429 Too Many Requests`. Return this — not `503 Service Unavailable` (implies a server problem), not `403 Forbidden` (implies a permanent access denial).

Standard response headers:

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 30
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1700000060
Content-Type: application/json

{
  "error": "rate_limit_exceeded",
  "message": "Too many requests. Retry after 30 seconds.",
  "retry_after": 30
}
```

Header semantics:

- `Retry-After` — seconds until the client may retry (RFC 7231). Also accepts an HTTP-date. This is the most important header; clients that honor it back off correctly.
- `X-RateLimit-Limit` — the total allowed requests in the current window.
- `X-RateLimit-Remaining` — how many requests remain before hitting the limit. Sending this on every response (not just 429) allows clients to proactively throttle before being rejected.
- `X-RateLimit-Reset` — Unix timestamp when the window resets.

The IETF draft `draft-ietf-httpapi-ratelimit-headers` is working toward standardizing these headers; `RateLimit-Limit`, `RateLimit-Remaining`, and `RateLimit-Reset` (without the `X-` prefix) are the proposed standard forms.

The failure mode on the client side: ignoring `Retry-After` and retrying immediately, which produces a storm of rejected requests that count against the rate limit budget, extending the time until service resumes. Implement exponential backoff with jitter when `Retry-After` is absent; honor it exactly when it is present.

> [!tip] Proactively return `X-RateLimit-Remaining` on every response, not only on 429. Clients that monitor this header can throttle themselves before hitting the limit, reducing rejected traffic and improving user experience.

@feynman

A rate limit response is like a traffic light that shows you not just the red light but a countdown timer — without the timer you have no idea whether to wait two seconds or two minutes, so you either sit there indefinitely or run the red.

@card
id: apid-ch07-c009
order: 9
title: CORS
teaser: CORS is the most misunderstood security mechanism in web APIs — it does not protect the server from requests; it protects users from malicious sites that would make requests on their behalf using the user's cookies and sessions.

@explanation

The Same-Origin Policy (SOP) prevents JavaScript running on `evil.com` from reading responses from `api.bank.com`. CORS (Cross-Origin Resource Sharing) is the mechanism by which `api.bank.com` can selectively relax this restriction for trusted origins.

CORS protects against a specific attack: a malicious site causes the user's browser to send authenticated requests to a target API (using the user's cookies or stored credentials), then reads the response to exfiltrate data. Without SOP and CORS, visiting a malicious site could silently drain a bank account or read private emails.

What CORS is not: a server-side security control. The server still receives and may process the request — CORS only controls whether the browser delivers the response to the originating JavaScript. A non-browser client (curl, Postman, a server) ignores CORS entirely.

Preflight requests: before sending a cross-origin request with custom headers or non-simple methods (PUT, DELETE, PATCH, or POST with application/json), the browser sends an `OPTIONS` preflight request. The server must respond with the correct CORS headers or the browser blocks the actual request.

```http
HTTP/1.1 200 OK
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Max-Age: 86400
```

The critical failure mode: `Access-Control-Allow-Origin: *` (wildcard) combined with `Access-Control-Allow-Credentials: true`. This combination is rejected by browsers (credentials cannot be sent to a wildcard origin) and signals a fundamental misunderstanding of the threat model. Enumerate allowed origins explicitly; never use a wildcard for credentialed requests.

> [!warning] `Access-Control-Allow-Origin: *` is safe only for truly public, unauthenticated data. For any API that handles user data or accepts credentials, enumerate allowed origins explicitly — do not wildcard.

@feynman

CORS is not a lock on the server door — it is a rule the browser enforces: the browser, acting on the user's behalf, refuses to hand the response from your bank's API to the JavaScript code running on a random other site.

@card
id: apid-ch07-c010
order: 10
title: API Gateway as Security Choke Point
teaser: An API gateway centralizes authentication, rate limiting, TLS termination, and logging into a single enforcement point — removing the need to implement each of those in every individual service.

@explanation

In a microservices architecture, duplicating authentication and rate limiting logic across dozens of services creates inconsistency, bugs, and maintenance burden. An API gateway moves those cross-cutting concerns to a single layer that every request passes through before reaching a service.

What a gateway handles:

- **TLS termination.** The gateway receives HTTPS from clients and forwards HTTP (or HTTPS) to internal services. Internal services don't need to manage public TLS certificates.
- **Authentication.** The gateway validates JWTs or API keys, rejects invalid requests, and optionally injects verified claims as headers for downstream services. A service that receives a request from the gateway can trust the identity has already been verified.
- **Rate limiting.** Applied per-client, per-route, or globally before the request reaches any service.
- **Request/response logging.** Centralized audit log for all API traffic — no service needs to implement its own.
- **IP allowlisting and threat detection.** WAF integration, IP reputation filtering, and bot detection at the gateway layer.

The failure mode is using the gateway as the only security layer and trusting that internal requests are implicitly legitimate. If an attacker gains access to the internal network (through a compromised service, SSRF, or misconfigured network policy), they can call any service directly, bypassing the gateway. Defense-in-depth requires services to perform their own authorization even when behind a gateway.

> [!info] A gateway that handles authentication does not eliminate service-level authorization checks. The gateway can tell a service "this is user Alice," but only the service knows whether Alice is permitted to access the specific resource she is requesting.

@feynman

An API gateway is like a building's security desk — every visitor checks in there, shows ID, and gets a visitor badge, but that badge doesn't mean every room in the building is now open; individual departments still lock their own doors.

@card
id: apid-ch07-c011
order: 11
title: Threat Modeling and OWASP API Security Top 10
teaser: Threat modeling asks "what could go wrong?" systematically — and the OWASP API Security Top 10 (2023 edition) is the empirically derived answer for APIs specifically.

@explanation

STRIDE is a threat modeling framework that enumerates threat categories for any system:

- **S**poofing — impersonating another user or service
- **T**ampering — modifying data in transit or at rest
- **R**epudiation — performing actions that cannot later be proven
- **I**nformation Disclosure — exposing data to unauthorized parties
- **D**enial of Service — preventing legitimate access
- **E**levation of Privilege — gaining permissions not granted

Applied to an API endpoint, STRIDE produces a checklist of questions: can a caller spoof another user's identity? Can the request body be tampered in transit? Is there an audit log (non-repudiation)? Can the response leak data beyond what the caller is entitled to?

The OWASP API Security Top 10 (2023) translates this into the most commonly exploited API vulnerabilities in practice:

- **API1:2023 — Broken Object Level Authorization (BOLA):** Failing to verify that the requesting user owns the object they are accessing. The most prevalent API vulnerability. A request to `/orders/12345` should verify that the authenticated user is the owner of order 12345.
- **API2:2023 — Broken Authentication:** Weak token validation, missing expiry checks, insecure credential storage.
- **API3:2023 — Broken Object Property Level Authorization:** Returning more fields than the caller is permitted to see; accepting more fields than the caller is permitted to set (mass assignment).
- **API4:2023 — Unrestricted Resource Consumption:** No rate limiting on resource-intensive operations; allowing unbounded query parameters.
- **API5:2023 — Broken Function Level Authorization:** Lower-privilege users accessing administrative endpoints.

The failure mode of STRIDE without OWASP: STRIDE is general; it can miss API-specific patterns like BOLA that don't map cleanly to generic threat categories. Use both — STRIDE for systematic coverage, OWASP API Top 10 for API-specific pattern recognition.

> [!warning] BOLA (API1:2023) is the number-one API vulnerability because it requires almost no skill to exploit — just change the object ID in the URL. Every endpoint that takes an identifier must verify the caller owns or has permission for that specific object, not just that the caller is authenticated.

@feynman

Threat modeling is like a pre-flight checklist — you don't wait to discover what can go wrong by flying; you go through the list of known failure modes systematically before every flight, because the time to find a problem is on the ground.

@card
id: apid-ch07-c012
order: 12
title: Audit Logging for APIs
teaser: Audit logs are the post-incident record of what happened — but they are only useful if you log the right things, store them safely, and explicitly never log the secrets that would turn your log store into a credential vault.

@explanation

What to log on every API request:

- Request timestamp (UTC, with milliseconds)
- Caller identity (user ID, client ID, or API key identifier — never the raw key)
- HTTP method and path (sanitized — no query parameters that contain tokens)
- Source IP and, where available, user agent
- Response status code
- Request duration
- Request/correlation ID for tracing across services

What never to log:

- Full API keys or bearer tokens — an identifier (first 8 characters, a hashed form, or the key ID) is sufficient for tracing
- Full request bodies if they contain passwords, payment card data, or personal health information
- Session tokens or cookie values
- Private key material of any kind

Storing logs securely: logs are a high-value target. Access should be restricted to security and operations teams, not the general engineering org. Log stores must be append-only from the application's perspective — the application can write but not delete — to prevent tampering. SIEM integration (Splunk, Datadog, Elastic, AWS Security Lake) enables correlation and alerting.

Retention requirements vary by regulation: PCI DSS requires one year with three months online; HIPAA requires six years; GDPR requires logs not to be retained longer than necessary (tension with security retention). Establish a retention policy before deciding on storage.

The failure mode is logging tokens as part of debugging an authentication issue, then committing the log aggregator config or sample logs to a repository. Token material in logs has caused significant breaches.

> [!warning] Never log bearer tokens, API keys, or session identifiers in full. Log the key ID, a prefix (first 8 characters), or a hash. A compromised log store should not also be a compromised credential store.

@feynman

An audit log is a security camera recording — you want to know who entered, when, and what they did, but you do not want the camera recording the combination to the safe, because if someone steals the footage they now have the combination too.
