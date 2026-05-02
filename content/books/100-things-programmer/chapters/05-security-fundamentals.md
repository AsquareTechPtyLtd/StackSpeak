@chapter
id: ttp-ch05-security-fundamentals
order: 5
title: Security Fundamentals
summary: Security is not a feature you add at the end — it is a set of specific, learnable practices that reduce the blast radius of the mistakes every system eventually makes.

@card
id: ttp-ch05-c001
order: 1
title: Input Validation at Every Trust Boundary
teaser: The frontend validates nothing from the server's perspective. Every trust boundary — not just the UI — must validate its inputs independently.

@explanation

Input validation is the first line of defense because attackers don't use your UI. They send HTTP requests directly, craft malformed JSON, or replay packets with modified fields. If your server trusts that the frontend already checked the input, you have no server-side defense.

The rule is: validate at every trust boundary, every time. A trust boundary is any point where data crosses from one execution context to another — browser to server, service A to service B, database to application layer, file system to parser.

Two strategies for specifying what's valid:

- **Allowlisting (preferred):** define exactly what is acceptable and reject everything else. A field that must be a positive integer: reject any input that is not a positive integer.
- **Denylisting:** define what is unacceptable and allow the rest. This approach loses because attackers find encodings and edge cases you didn't anticipate. `<script>` is on your list? They'll try `%3Cscript%3E`, `&#x3C;script&#x3E;`, Unicode variants.

Allowlisting is harder to write but dramatically harder to bypass. Denylisting is a game you are always one step behind in.

Validation should also check:
- **Type** — is this actually a string, not an object or array?
- **Range** — is this integer between 1 and 100?
- **Length** — is this string under 255 characters?
- **Format** — does this email match the expected pattern?

The practical impact: in 2021, OWASP's top-10 included injection (driven by unsanitized input) as a top-3 vulnerability category across surveyed applications.

> [!warning] "The frontend already validates it" is a statement about user experience, not security. A user who is attacking you does not go through your frontend.

@feynman

It's like a nightclub that checks IDs at the front door but lets anyone walk in through the side entrance — the check only matters if it's the only way in.

@card
id: ttp-ch05-c002
order: 2
title: SQL Injection and Parameterized Queries
teaser: SQL injection is 30 years old, still in OWASP's top 3, and still preventable with one technique: parameterized queries. Escaping is not a substitute.

@explanation

SQL injection happens when user-supplied input is concatenated into a SQL string, allowing an attacker to change the structure of the query. The classic example:

```
SELECT * FROM users WHERE name = '" + username + "'
```

If `username` is `' OR '1'='1`, the query returns every row. If it's `'; DROP TABLE users; --`, the consequences are worse. This is not theoretical — it has been used to exfiltrate millions of records from production databases.

The correct fix is parameterized queries (also called prepared statements). The query structure is sent to the database separately from the data, so the data can never be interpreted as SQL:

```sql
SELECT * FROM users WHERE name = ?
```

The `?` is a placeholder. The database driver handles binding the value, and the value is treated as data, never as SQL syntax.

**What does not work:**
- Escaping special characters — encoding is fragile, and you will miss an edge case.
- Sanitizing input before inserting — the data still reaches the SQL layer, and sanitization has bypass paths.

**ORMs:** most ORMs (ActiveRecord, SQLAlchemy, Hibernate, GORM) use parameterized queries internally by default — but each one has a raw query escape hatch (`execute_raw`, `query`, `Raw`) that bypasses protection. Audit every use of those methods.

`EXPLAIN` output shows query plans and indexes, not injection risk. Don't mistake a well-optimized query for a safe one.

> [!warning] Every raw SQL string that includes user data is a potential injection point. The fix takes 30 seconds. The breach takes months to recover from.

@feynman

Parameterized queries are like sealed envelopes — the database processes the address on the outside (the query structure) without opening the letter (the user data) and running whatever's inside.

@card
id: ttp-ch05-c003
order: 3
title: Cross-Site Scripting (XSS) and Output Encoding
teaser: XSS lets attackers inject scripts into pages your users trust. The root cause is putting user data into HTML without encoding it — and "it looks safe" is never a valid defense.

@explanation

XSS occurs when user-supplied content is rendered as HTML (or JavaScript) rather than as plain text. There are three variants:

- **Stored XSS:** malicious script is saved in the database (a comment, a profile name) and served to every user who loads the page.
- **Reflected XSS:** malicious script is in the URL and reflected back in the response (search results, error pages).
- **DOM-based XSS:** malicious script is injected via client-side JavaScript that reads from `location.hash`, `document.referrer`, or similar untrusted sources.

The root cause in all three: user data lands in a context where it is interpreted as code rather than text.

`innerHTML = userInput` is always wrong. Even if the input "looks safe" right now, you are creating a path that future developers will reuse with less-safe inputs. Use `textContent` for plain text, or use a library (DOMPurify with strict config) if you genuinely need to support a subset of HTML.

**Defense layers:**
- **Output encoding:** encode data for the context it will appear in (HTML entity encoding for HTML context, JavaScript escaping for JS context, URL encoding for URLs). Most modern templating engines (Jinja2, Handlebars, Razor, Blade) do this by default. Know what yours does by default.
- **Input sanitization:** strip or reject tags you don't need. Useful, but not sufficient on its own.
- **Content Security Policy (CSP):** an HTTP response header that tells the browser which scripts are allowed to execute. A strict CSP (`script-src 'self'`) blocks inline scripts even if injection succeeds — defense in depth, not a primary fix.

> [!tip] The default behavior of your templating engine matters. Verify that auto-escaping is on and know exactly how to opt out — because opting out is where most XSS originates.

@feynman

XSS is what happens when you display a sticky note someone handed you and it turns out to be a command — text and instructions look the same until you fail to distinguish them.

@card
id: ttp-ch05-c004
order: 4
title: Secrets Management and the Version Control Problem
teaser: A secret committed to git is permanently compromised — git history survives rotations. The question is not whether to avoid this but how far along the correct path you currently are.

@explanation

Secrets (API keys, database passwords, tokens, private keys) need to be stored somewhere. The options, in ascending order of correctness:

**In source control:** the most common mistake. A secret pushed to a private repo is accessible to anyone with repo access, anyone the repo is ever shared with, and — if the repo is ever made public — the entire internet. Critically, git history is permanent. Removing the secret in a subsequent commit does not remove it from `git log`. GitHub's secret scanning detects common patterns and will alert you, but detection is not prevention.

**In environment variables:** a meaningful improvement. Secrets leave source control and live in the runtime environment. They are visible in process listings (`ps aux`), CI/CD logs if printed or if `--env` is used carelessly, and anywhere the process's environment is dumped. Better than git, still not production-grade.

**In a secret vault:** AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, GCP Secret Manager. Secrets are encrypted at rest, access is controlled via IAM or policies, rotation is automated, and access is audited. This is the production standard. Applications retrieve secrets at startup via an authenticated API call rather than reading an environment variable set at deploy time.

The practical steps for a leaked secret: rotate it immediately (before you finish the postmortem), revoke the old value, audit access logs for the window it was exposed, and add a pre-commit hook (truffleHog, detect-secrets) to prevent recurrence.

> [!warning] Rotating a secret after it has been in git history is necessary but not sufficient — assume it was read during the exposure window and act accordingly.

@feynman

A secret in git history is like a key you hid under your doormat and then moved — everyone who visited while it was there already knows where you look for keys.

@card
id: ttp-ch05-c005
order: 5
title: Principle of Least Privilege
teaser: Every user, service, and process should have only the permissions it needs for the specific task it performs — the blast radius when something goes wrong scales directly with the permissions that were granted.

@explanation

Least privilege is the practice of granting the minimum permissions necessary for a task to complete, and no more. It applies at every layer:

- **Database credentials:** a service that reads from one table should have `SELECT` on that table, not `ALL PRIVILEGES` on the entire database.
- **IAM roles:** a Lambda function that writes to one S3 bucket should have `PutObject` on that bucket's ARN, not `s3:*` on `*`.
- **OS users:** a web server process should not run as root.
- **API tokens:** a read-only integration should receive a read-only token.

The argument for least privilege is not that it prevents compromise — it doesn't. It is that it bounds the damage when a compromise occurs. If a credential is stolen:

- With broad permissions: the attacker can read all databases, write to all buckets, exfiltrate all secrets, modify infrastructure.
- With narrow permissions: the attacker can only do what the credential could do. The blast radius is contained.

The friction argument is real: scoping permissions precisely takes time, requires understanding what the service actually needs, and creates tickets when requirements change. The counterargument is equally real: the average cost of a data breach in 2023 was $4.45 million (IBM Cost of a Data Breach Report). The friction of scoping permissions correctly is almost never close to that.

> [!info] Audit your service accounts and IAM roles periodically. Permissions accumulate over time as requirements change; the old ones rarely get removed.

@feynman

Giving a contractor keys to every room because they need to fix one bathroom is not a time-saver — it's a decision you'll regret if they turn out to have been compromised.

@card
id: ttp-ch05-c006
order: 6
title: Dependency Risk and Supply Chain Attacks
teaser: Every package you install is code you are running with your permissions, written by someone you've never vetted. The supply chain is the attack surface most developers ignore.

@explanation

Modern applications depend on hundreds of packages. Each one is a trust decision you made — often implicitly, often quickly, often by running `npm install` or `pip install` without much scrutiny.

The attack vectors in the dependency supply chain:

- **Typosquatting:** a malicious package published with a name one character off from a popular package (`coollors` vs `colors`, `lodash` vs `lodahs`). A mistyped install command is all it takes.
- **Compromised upstream:** a legitimate package's maintainer account is taken over. The attacker publishes a new version with malicious code. Every project that auto-updates gets it. This happened to `event-stream` (npm, 2018) and `ua-parser-js` (npm, 2021).
- **Malicious maintainer:** a package is donated to a new maintainer who is bad faith. The package was safe when you added it; it isn't any more.

Mitigations, in order of impact:

- **Lockfiles** (`package-lock.json`, `poetry.lock`, `Gemfile.lock`) — pin exact versions and hashes. Prevents unexpected version upgrades without your knowledge.
- **Automated scanning** — Dependabot (GitHub), Snyk, OWASP Dependency-Check. Surface known CVEs in your dependency tree before they surface in an incident.
- **Audit before installing** — look at the package's npm/PyPI page, GitHub repo, maintainer history, and download count before adding something new. Thirty seconds of scrutiny.
- **Minimize surface area** — every dependency you don't add is a dependency you don't need to maintain or audit.

> [!warning] `npm audit` reports known vulnerabilities, not unknown ones. A clean audit result means no known CVEs; it does not mean your dependencies are safe.

@feynman

Importing a package is like hiring a subcontractor and giving them access to your building — you are responsible for what they do while they're in there, even if you didn't watch them work.

@card
id: ttp-ch05-c007
order: 7
title: Authentication vs. Authorization
teaser: Authentication proves who you are. Authorization decides what you can do. Checking one without the other is the most common access control failure — and OWASP ranks it #1.

@explanation

Authentication and authorization are distinct problems that are often conflated:

- **Authentication:** verifying the identity of a user or service. "Are you who you say you are?" Answered by passwords, tokens, certificates, MFA.
- **Authorization:** verifying that the authenticated identity has permission to perform a specific action on a specific resource. "Are you allowed to do this, to this thing?" Answered by roles, policies, ACLs.

The failure mode is checking authentication but not authorization. The user is logged in — but can they see *this* resource? Can they modify *this* record? Is the order they're requesting *theirs*?

A concrete example of broken access control: `/api/orders/12345` returns an order. The endpoint checks that the request includes a valid session cookie (authentication). It does not check that the order belongs to the authenticated user (authorization). User A can retrieve User B's orders by incrementing the ID. This is called IDOR (Insecure Direct Object Reference).

OWASP's 2021 Top 10 ranked Broken Access Control as the #1 vulnerability category, present in 94% of tested applications. The prevalence is not because it's hard to prevent — it's because it's easy to forget when building a feature.

Authorization checks should be:
- Server-side only (client-side checks are display logic, not security)
- Applied at every endpoint, not assumed from a previous check
- Explicit per resource, not inherited from "the user is logged in"

> [!warning] A middleware that checks authentication before routing is a good start, not a complete authorization model. Every handler that touches a resource still needs to verify the requester has rights to that resource.

@feynman

Authentication is showing your ID at the door; authorization is checking whether your ticket gives you access to the VIP section — they're separate checks and one does not imply the other.

@card
id: ttp-ch05-c008
order: 8
title: Hashing vs Encryption for Passwords
teaser: Passwords should be hashed, not encrypted. If you can retrieve the original password, so can an attacker with your key — the whole point of hashing is that retrieval is computationally infeasible.

@explanation

Two fundamentally different operations are often confused:

- **Hashing** is a one-way function. Given input, it produces a fixed-length digest. You cannot reverse it to get the original input. Used for: passwords, integrity verification.
- **Encryption** is a two-way function. Given input and a key, it produces ciphertext. Given ciphertext and the key, you recover the original input. Used for: data at rest, data in transit, any data you need to retrieve.

For passwords, one-way is what you want. When a user logs in, you hash the supplied password and compare it to the stored hash. You never need to retrieve the original. If an attacker gets your database, they have hashes, not passwords — and reversing the hash is computationally expensive.

The wrong tools for password hashing:
- **MD5 and SHA-1** — cryptographically broken, fast to compute. A modern GPU can compute billions of MD5 hashes per second, making brute force practical.
- **SHA-256/SHA-512** — cryptographically sound, but designed to be fast. Still vulnerable to GPU-accelerated brute force without additional cost.

The correct tools for password hashing:
- **bcrypt** — deliberately slow, includes salt, widely supported. Cost factor can be increased as hardware gets faster.
- **scrypt** — memory-hard (resists GPU parallelism), good for high-security contexts.
- **Argon2** — winner of the 2015 Password Hashing Competition, current recommendation. Three variants: Argon2i, Argon2d, Argon2id (use id for passwords).

The rule about rolling your own crypto: don't. Not because you aren't smart enough, but because the attack surface of a cryptographic primitive requires years of peer review to harden, and you don't have that time.

> [!warning] If your database is compromised, your hashing algorithm is now public knowledge. The question is how long it takes to crack — bcrypt/Argon2 are measured in years per hash; SHA-256 is measured in seconds.

@feynman

Hashing a password is like running it through a shredder before filing it — when you need to verify it, you shred the new input and compare the shreds, never reassembling the original.

@card
id: ttp-ch05-c009
order: 9
title: HTTPS, TLS, and Transport Security
teaser: Plain HTTP sends every byte in cleartext. On any network — including "internal" ones — that traffic is readable by anyone who can see it. TLS is not optional for production systems.

@explanation

TLS (Transport Layer Security) encrypts data in transit between client and server, authenticates the server's identity via certificates, and ensures data integrity. HTTPS is HTTP over TLS.

The current landscape:
- **TLS 1.3** is current (2018). Faster handshake, stronger ciphers, removed weak cipher suites.
- **TLS 1.2** is acceptable but aging.
- **TLS 1.0 and 1.1** are deprecated — PCI DSS requires disabling them.
- **SSL** is broken and must not be used.

Certificate validation is three checks, not one:
1. The certificate is signed by a trusted CA (certificate authority).
2. The certificate has not expired.
3. The certificate's hostname matches the hostname you're connecting to.

Failing to check all three is a common TLS implementation mistake. Many HTTP client libraries allow you to disable certificate validation with a flag — `verify=False` in Python's requests, `NODE_TLS_REJECT_UNAUTHORIZED=0` in Node. These flags exist for testing against local development certs; using them in production removes all TLS protection.

**Additional hardening:**
- **HSTS (HTTP Strict Transport Security):** an HTTP response header that instructs browsers to only connect via HTTPS for a specified duration. Prevents SSL stripping attacks.
- **Certificate pinning:** hardcoding expected certificates or public keys in the client. Prevents compromise via a rogue CA. High maintenance cost — pinned certs expire and must be rotated before the pin breaks.

The "internal network" assumption is a specific risk: internal traffic is commonly transmitted unencrypted on the assumption that the network perimeter is trusted. That assumption fails in the presence of a compromised internal machine, a misconfigured switch, or lateral movement after an external breach.

> [!info] "We're on an internal network" is not a TLS exemption. Encrypt internal service-to-service traffic. The network perimeter is not a security boundary — it's a speed bump.

@feynman

Plain HTTP is like mailing a postcard: anyone who handles it between sender and recipient can read it — TLS is the envelope.

@card
id: ttp-ch05-c010
order: 10
title: Threat Modeling as a Design Activity
teaser: Threat modeling is the practice of asking "what could go wrong?" before the code exists — security is dramatically cheaper to address in design than in production.

@explanation

Threat modeling is a structured way to identify security threats during design, before any code is written. The goal is to find the ways an attacker could misuse the system and design mitigations in from the start.

The basic process:
1. **Draw a data flow diagram.** Map every component in the system and every data flow between them. Include: external actors, processes, data stores, trust boundaries. This forces you to make the system explicit before discussing what could go wrong.
2. **Enumerate threats.** For each component and data flow, ask: what could go wrong here?
3. **Prioritize and mitigate.** For each threat, decide: accept, mitigate, transfer (insurance), or eliminate. Document the decision.

**STRIDE** is a structured threat enumeration lens developed by Microsoft, useful for step 2:
- **S**poofing — can an attacker impersonate a user, service, or component?
- **T**ampering — can an attacker modify data in transit or at rest?
- **R**epudiation — can a user deny performing an action because there's no audit log?
- **I**nformation Disclosure — can an attacker access data they shouldn't?
- **D**enial of Service — can an attacker make the system unavailable?
- **E**levation of Privilege — can an attacker gain permissions they don't have?

A one-hour threat modeling session on a new feature will surface more security issues than a post-launch penetration test, and fixing design-time issues costs nothing compared to remediating a deployed system. A 2018 study by the System Sciences Institute at IBM found that fixing a defect in production costs 15x more than fixing it in design.

Threat modeling does not require a security specialist. Any engineer familiar with the system can run a STRIDE pass. The data flow diagram is the forcing function — the discipline of drawing the system makes the threats visible.

> [!tip] Add threat modeling as a step in your design doc template. A section titled "What could go wrong?" with a STRIDE pass takes 30 minutes and changes the security posture of every feature it touches.

@feynman

Threat modeling is the security equivalent of a pre-flight checklist — you run through the known failure modes before you're in the air, not after you've already crashed.
