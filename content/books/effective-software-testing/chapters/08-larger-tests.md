@chapter
id: est-ch08-larger-tests
order: 8
title: Larger Tests — Integration and System
summary: Integration and end-to-end tests catch the bugs unit tests cannot — the ones that live at the boundaries between components — but they cost more to write, maintain, and run, and the discipline is to use them sparingly and at the right level.

@card
id: est-ch08-c001
order: 1
title: Tests Bigger Than a Unit
teaser: Unit tests are fast and precise, but they can only tell you that each part works in isolation — they cannot tell you that the parts work together, and that gap is where integration tests earn their place.

@explanation

A unit test replaces every external collaborator with a test double. That isolation is its strength: fast feedback, deterministic results, no network, no database. But isolation is also its blind spot. A perfectly unit-tested codebase can fail spectacularly in production because the real database rejects a query the fake one accepted, the HTTP client serializes a field the stub never validated, or the message consumer misinterprets a schema the producer's mock always got right.

The testing tiers above the unit exist to close that gap:

- **Integration tests** — verify that two or more real components work together. A service plus its real database. A client plus a real HTTP endpoint. Scope is deliberately limited: integrate the minimum set of components that shares a real boundary.
- **System tests** — run the entire application in a near-production environment with all real dependencies. Validate end-to-end flows from the outside.
- **End-to-end (E2E) tests** — drive the system through its actual user interface (browser, mobile app, or public API) and assert on observable outcomes.

Each tier catches a different class of defect. Integration tests catch contract mismatches and ORM subtleties. System tests catch configuration errors and infrastructure assumptions. E2E tests catch user-facing regressions. None of them are free substitutes for the others.

The cost gradient runs in the same direction as the scope gradient: integration tests are slower and more brittle than unit tests; E2E tests are slower and more brittle than integration tests. This is not a reason to avoid larger tests — it is a reason to use them deliberately.

> [!info] Aniche's framing in *Effective Software Testing* is "big enough not to lie." A test that replaces every real dependency with a fake might be too small to catch a real integration bug — and recognizing that boundary is a skill.

@feynman

Unit tests confirm that every gear in a watch is correctly shaped; integration tests confirm that when you mesh the gears together, they actually turn.

@card
id: est-ch08-c002
order: 2
title: Integration Testing Scope
teaser: The hardest judgment call in integration testing is deciding which dependencies to make real and which to mock — and the rule is: make real whatever shares the boundary you actually want to test.

@explanation

Integration tests are not "unit tests with everything real." Running a test against a real database, a real message broker, and a real third-party payment API simultaneously produces a test that is slow, fragile, and tells you almost nothing when it fails, because you cannot easily isolate which boundary broke.

The discipline is to integrate exactly the components that share the boundary under test, and mock or stub everything else:

- Testing a repository class that writes to PostgreSQL? Use a real PostgreSQL instance. Mock the service layer above it and any downstream HTTP calls it would trigger.
- Testing an HTTP controller that parses requests and delegates to a service? Use a real HTTP server (or a test client that drives it in-process). Stub the service to return controlled responses.
- Testing a Kafka consumer that transforms messages and writes to a database? Use a real Kafka broker and a real database. Mock any downstream HTTP calls the consumer makes.

What makes a dependency worth integrating for real:

- You are testing behavior that depends on the specific semantics of that dependency (SQL type coercion, serialization format, broker ordering guarantees).
- The fake or mock for that dependency has a history of lying — of accepting inputs the real system would reject.
- Contract mismatches at that boundary have caused real production bugs.

What is safe to mock in an integration test:

- Third-party payment gateways and external APIs where you do not own the contract.
- Services owned by other teams when a contract test (see card 6) already covers that boundary.
- Anything that requires credentials or network access that will not be available in CI.

> [!tip] A useful heuristic: if a bug at this boundary would cause a production incident, make that dependency real in at least one test. If not, a stub is fine.

@feynman

Integration testing is like testing whether two puzzle pieces actually interlock — you need the real edges of both pieces, not cardboard cutouts you made yourself.

@card
id: est-ch08-c003
order: 3
title: Database Integration Tests
teaser: Testing a real database reveals type mismatches, constraint violations, and query plan surprises that no in-memory fake ever will — the question is not whether to do it, but how to make it repeatable.

@explanation

In-memory database replacements (H2 for JVM, SQLite for applications that use PostgreSQL in production) are tempting because they are fast and require no infrastructure. They also lie. H2's SQL dialect diverges from PostgreSQL's in ways that matter: partial index syntax, `RETURNING` clauses, `JSONB` operators, and upsert semantics all behave differently or are unsupported. A test suite that passes against H2 is a test suite that does not actually test your database code.

**Testcontainers** is the production answer for JVM, Python, Node, and Go. It starts the exact same database image your production environment uses — PostgreSQL 16, MySQL 8, MongoDB 7 — as a Docker container, runs your tests against it, and stops the container when the tests complete. The database is real. The schema migrations run against it. The constraints are enforced. The tests tell you something true.

A typical Testcontainers setup for a Spring Boot + PostgreSQL project:

- Declare a `PostgreSQLContainer` as a JUnit 5 extension or a static field.
- Override the datasource URL to point at the container's mapped port.
- Run Flyway or Liquibase migrations at test startup.
- Each test runs in a transaction that is rolled back after the test, keeping tests independent without truncating tables.

For Python (pytest + SQLAlchemy), the pattern is similar: use `testcontainers-python` to spin up a PostgreSQL container and point `DATABASE_URL` at it.

The cost is real: Testcontainers tests are 10–30 times slower than unit tests and require Docker to be available in your CI environment. GitHub Actions, CircleCI, and GitLab CI all support Docker-in-Docker. The cost is worth it for repository-layer code that exercises non-trivial SQL.

> [!warning] Never use an in-memory database to test code written for a different database engine. The dialect mismatch will let real bugs through, which defeats the entire purpose of the test.

@feynman

Testing against a real database is like tasting the dish with the actual ingredients — a description of how the dish should taste (an in-memory fake) does not reveal that the salt you bought is actually sugar.

@card
id: est-ch08-c004
order: 4
title: HTTP API Integration Tests
teaser: HTTP API integration tests drive a running server through real HTTP, exercising serialization, routing, middleware, and error handling in ways that cannot be faked by calling a service method directly.

@explanation

An HTTP API integration test starts an instance of your server (in-process or in a separate container) and sends real HTTP requests to it. The response is what a real client would receive, including status codes, headers, and body serialization. This catches a class of bugs that unit-testing the service layer cannot:

- A controller maps a 404 to a 500 because of a missing exception handler.
- A JSON field is serialized as a string when the client expects a number.
- A middleware strips an authorization header before it reaches the handler.
- A route parameter is named differently in the code and the documentation.

**Tool choices by ecosystem:**

- **Node.js / Express / Fastify:** `supertest` drives the server in-process, no network port required. Tests are fast and need no cleanup.
- **Java / Spring Boot:** `@SpringBootTest` with `WebEnvironment.RANDOM_PORT` starts the full application on a random port; `RestAssured` or Spring's `TestRestTemplate` / `MockMvc` sends requests.
- **Python / FastAPI or Django:** `httpx` with an `ASGITransport` or Django's test client drives the application in-process.

What to assert in an HTTP integration test:

- Response status code (the HTTP contract, not just the service layer result).
- Response body structure and content type.
- Key response headers (Location on 201, retry-after on 429).
- Error response shape for invalid inputs (validation errors, not found, unauthorized).

What to stub or mock in an HTTP integration test:

- Third-party downstream HTTP calls the server makes — use WireMock (JVM), `nock` (Node), or `responses` (Python) to return controlled responses.
- Databases — either use Testcontainers with a real DB, or use the real service layer stubbed at the repository boundary, depending on what you are testing.

> [!info] `supertest` and Spring's `MockMvc` both avoid opening a real network socket, which keeps test speed reasonable. Reserve full network-port tests for cases where middleware or port binding behavior is what you're testing.

@feynman

An HTTP API integration test is like calling the restaurant's actual phone number instead of testing the script your staff would recite — you find out whether the phone system works, not just whether the words are correct.

@card
id: est-ch08-c005
order: 5
title: Message Queue Integration Tests
teaser: Message-driven systems have subtle correctness properties — ordering, at-least-once delivery, schema evolution — that only surface when you test against a real broker, and Testcontainers makes that practical.

@explanation

Testing a Kafka consumer or a RabbitMQ listener with a mock is testing that your code calls the right client method, not that it correctly handles the semantics of the broker. Real brokers have real behaviors that matter:

- Kafka consumers process messages in partition order, and a consumer that works correctly in a single-partition test may fail with multiple partitions.
- RabbitMQ exchanges route messages based on routing keys and binding rules that your stub probably does not model.
- Message deserialization can fail on schema version mismatches that a hardcoded test payload never triggers.
- Consumer group rebalancing happens when consumers join or leave, and it can cause duplicate processing if your consumer is not idempotent.

**Testcontainers for brokers:**

- `KafkaContainer` starts a real Apache Kafka broker (wraps the Confluent Platform Docker image). Your producer and consumer code connects to `localhost:<mapped-port>`. Full broker semantics, real partitioning, real offsets.
- `RabbitMQContainer` starts a real RabbitMQ node. Exchange declarations, queue bindings, and dead-letter configurations all work as in production.

The flakiness problem with message queue integration tests:

- **Timing.** Messages arrive asynchronously. Tests that assert "the consumer processed the message" need an explicit wait — polling with a timeout rather than a fixed `sleep`. Libraries like Awaitility (JVM) or `pytest-asyncio` with `asyncio.wait_for` handle this cleanly.
- **Offset management.** Tests that share a Kafka broker can interfere if they reuse topic names or consumer group IDs. Use unique topic names per test run (UUID-suffixed).
- **Container startup.** Kafka containers take 5–15 seconds to become ready. Use `@BeforeAll` (JUnit 5) or pytest session-scoped fixtures to start the container once per test class, not once per test.

> [!warning] Never use a fixed `sleep` to wait for a message to be consumed. It will be too long on a fast machine and too short on a slow CI runner. Use a polling wait with a generous timeout and a short poll interval.

@feynman

Testing a message consumer with a real Kafka broker is like testing a postal worker's route using the actual mail sorting system — only then do you find out that your carrier cannot handle packages from the wrong sorting facility.

@card
id: est-ch08-c006
order: 6
title: Contract Testing
teaser: Contract tests verify that a provider's API matches what its consumers expect, catching integration bugs without requiring a running instance of both services simultaneously — and Pact is the dominant tool for this.

@explanation

Full integration tests between two services owned by different teams are logically sound but operationally painful: both services must be deployed to the same environment, test data must be coordinated, and a failure in one service blocks the other team's CI pipeline. Contract testing is a lighter alternative that preserves most of the correctness guarantee.

**Consumer-driven contracts** (the Pact model):

1. The consumer team writes a Pact test that records what the consumer sends and what it expects in response. This produces a JSON contract file (the "pact").
2. The pact is published to a Pact Broker (or PactFlow, the hosted SaaS version).
3. The provider team pulls the pact and runs a "provider verification" test — it starts the provider service and replays the consumer's requests, asserting that the responses match the recorded expectations.
4. Neither team needs a running instance of the other's service. The pact file is the shared artifact.

**What Pact catches:**

- A provider renames a JSON field the consumer depends on.
- A provider changes a field's type from string to integer.
- A provider removes an endpoint the consumer calls.
- A provider adds a required request field the consumer does not send.

**What Pact does not catch:**

- Business logic errors within the provider.
- Behavior that depends on state the pact file does not exercise.
- Non-HTTP contracts (Pact supports message contracts for Kafka/RabbitMQ as well, but the tooling is less mature).

Pact works best in organizations where teams own clear service boundaries and want to move independently without a shared integration environment. It is not a replacement for integration tests against a real dependency — it is a replacement for integration tests against a dependency you do not own and cannot run cheaply.

> [!info] PactFlow (pactflow.io) is the managed Pact Broker hosted by the creators of Pact. The open-source Pact Broker is self-hostable but requires more operational overhead.

@feynman

Contract testing is like two people agreeing in writing on exactly what one will deliver to the other, then each independently checking that they can meet their side of the agreement — without ever needing to be in the same room at the same time.

@card
id: est-ch08-c007
order: 7
title: End-to-End Tests
teaser: End-to-end tests drive the full application through its real user interface, catching regressions no integration test can see — but they are the slowest, most brittle tier, and a suite that gets too large becomes a liability.

@explanation

End-to-end (E2E) tests operate at the outermost boundary of the system. They start a real browser (or make real API calls), interact with the application exactly as a user would, and assert on outcomes visible at that boundary: page content, redirects, cookies, downloaded files. Everything in between — the server, the database, the message queue, the cache — runs for real.

**The dominant tools:**

- **Playwright** (Microsoft): supports Chromium, Firefox, and WebKit. Modern API, built-in auto-waiting, codegen for recording interactions, and first-class support for CI. The current community favorite for new projects.
- **Cypress** (Cypress.io): JavaScript/TypeScript, Chrome and Firefox. Excellent developer experience with time-travel debugging. Runs in-process with the app, which simplifies some test patterns but limits cross-origin scenarios.
- **Selenium WebDriver** (open source): the original browser automation tool. Supports every browser, every language, every CI system. Slower and more verbose than Playwright or Cypress, but ubiquitous in enterprise environments and language-polyglot teams.

**What E2E tests uniquely catch:**

- Frontend routing and navigation errors.
- Cross-browser rendering or JavaScript compatibility issues.
- Authentication and session management flows.
- Full user journeys that span multiple services and database writes.
- CSP headers, redirects, and cookie scope issues.

**The cost:**

- A single Playwright test run can take 5–30 seconds. A suite of 200 E2E tests can take 30–60 minutes without parallelization.
- E2E tests require a fully deployed application with real infrastructure or a realistic environment.
- They are inherently more brittle than integration tests because they depend on the DOM structure, CSS selectors, and timing of real user interactions.

> [!tip] Playwright's `page.waitForSelector` and auto-waiting behavior eliminate most timing issues that plagued early Selenium suites. Prefer Playwright's built-in waiting over explicit `page.waitForTimeout` calls.

@feynman

An E2E test is like hiring a real customer to walk through your store and buy something — you learn things no internal audit ever reveals, but it costs far more per check than inspecting the storeroom yourself.

@card
id: est-ch08-c008
order: 8
title: The Flaky Test Problem
teaser: Flaky tests — tests that sometimes pass and sometimes fail without any code change — erode trust in the entire test suite, and end-to-end tests are the most common source because they depend on timing, state, and real infrastructure.

@explanation

A flaky test is a test that produces different results on different runs for the same code. It is one of the most damaging things that can happen to a test suite, because once a team learns that a red build might just be "the flaky ones," they stop treating red builds as signals. The suite becomes noise.

**Root causes of E2E flakiness:**

- **Timing.** An element appears asynchronously and the test asserts before it is visible. The fix is to use the framework's built-in waiting (Playwright's auto-waiting, Cypress's retry-based assertions) rather than fixed sleeps. Never use `await page.waitForTimeout(2000)` in production test code.
- **Test pollution.** One test leaves data in the database that causes another test to fail. The fix is test isolation: each test creates its own data and cleans up after itself, or runs against a fresh environment.
- **External service instability.** A third-party API called during an E2E test rate-limits or returns a 503. The fix is to mock or stub third-party dependencies at the network level (WireMock, Playwright's `page.route()` interception).
- **Infrastructure contention.** Tests share a database connection pool or a Kafka topic and interfere with each other under load. The fix is isolation — unique identifiers per test run, or fully isolated environments.
- **Browser nondeterminism.** Animation timing, font rendering, or viewport size causes screenshot comparison tests to differ. The fix is to disable animations in test mode and use content assertions rather than pixel comparisons.

**Detection:** Track pass/fail history per test. Any test with a pass rate below 99% on green-code commits is flaky. GitHub Actions, Buildkite, and most CI platforms have built-in flaky test detection that surfaces this data.

**Response options:**

- **Quarantine:** Move the flaky test to a non-blocking suite. It still runs, but it cannot fail the build. Assign ownership to fix it within a sprint.
- **Fix:** Identify the root cause and fix the test. This is the only sustainable response.
- **Delete:** If the test cannot be made reliable and the coverage it provides is duplicated elsewhere, delete it. A missing test is less harmful than a flaky one.

> [!warning] Never add a `sleep` to fix a flaky test. It makes the test slower on every run and still fails on sufficiently slow CI machines. Use framework-native waiting primitives instead.

@feynman

A flaky test is like a smoke alarm that goes off randomly in the middle of the night — after a few false alarms, people stop evacuating, and when there is a real fire, no one moves.

@card
id: est-ch08-c009
order: 9
title: The Test Pyramid Economy
teaser: The test pyramid is an investment model — unit tests are cheap and fast so you write many, integration tests cost more so you write fewer, and E2E tests cost the most so you write only the handful that justify their price.

@explanation

Mike Cohn's test automation pyramid (introduced in *Succeeding with Agile*, 2009) arranges tiers by quantity and cost: many unit tests at the base, fewer integration tests in the middle, and a small number of E2E tests at the top. The pyramid shape is a recommendation about where to invest, not a rule about ratios.

The economic logic:

- **Unit tests** cost roughly 1x to write and milliseconds to run. Return is high: fast feedback, precise failure localization, runs on every commit.
- **Integration tests** cost roughly 5–10x to write and seconds to run. Return is high for the specific boundaries they test; diminishing returns set in quickly when you write more than necessary.
- **E2E tests** cost 20–50x to write and minutes to run. Return is high for critical happy-path flows; diminishing returns set in after 10–20 tests for most applications.

The anti-pattern is an inverted pyramid (sometimes called an "ice cream cone"): many manual tests and E2E tests at the top, almost no unit tests at the bottom. This is the shape that emerges when testing is done after the fact by a separate QA team, and it produces slow, expensive, fragile feedback.

**Rebalancing signals:**

- If E2E test runs take more than 20 minutes, the suite has grown too large. Identify E2E tests that duplicate what integration tests already cover and delete them.
- If integration tests are catching bugs that unit tests could have caught at lower cost, invest in better unit test coverage.
- If production bugs are consistently slipping through unit and integration tests, you need more E2E coverage of the failing user flows.

> [!info] The pyramid shape is a starting heuristic, not a law. A heavily UI-driven application (no API, all user interaction) may legitimately have a flatter shape. The principle is: prefer the cheapest test that gives you sufficient confidence.

@feynman

The test pyramid is like a staffing budget — you can afford many junior reviewers doing basic checks, fewer senior reviewers doing detailed analysis, and only one or two executives signing off on the biggest decisions.

@card
id: est-ch08-c010
order: 10
title: System Tests
teaser: System tests run the complete application in a near-production environment and validate behaviors that only emerge when every layer is present — they are rare, expensive, and high-value.

@explanation

System tests sit above integration tests and below E2E tests in scope. Unlike E2E tests, which drive the application through its user interface, system tests typically exercise the full stack through its API or event interface. Unlike integration tests, which isolate a specific boundary, system tests make nothing real and everything real: the application, its database, its message broker, its cache, its internal services.

What system tests reveal that smaller tests cannot:

- Configuration errors — the application reads from the wrong environment variable in the real configuration, not the test override.
- Startup and initialization bugs — the application fails to connect to the database on boot because of a missing retry policy.
- Cross-service data consistency — a write through Service A is eventually visible to a read through Service B, but the timeout is too short for CI.
- Infrastructure assumptions — the application assumes the database schema is migrated before consumers start, but in the real deployment order it is not.
- Distributed tracing and observability — logs and spans flow correctly from the entry point through every downstream component.

The practical approach for most teams is to maintain a staging environment that mirrors production topology as closely as budget allows, and run a small suite of smoke tests against it after every deployment. These smoke tests are system tests: they drive the deployed system through 5–15 critical flows and assert on observable outcomes.

Tools for system test orchestration:

- Docker Compose for local system test environments.
- Kubernetes with a dedicated test namespace for CI-level system tests.
- Testcontainers Compose for spinning up multi-container environments in CI without a pre-existing cluster.

> [!tip] System tests are most valuable immediately after deployment and after significant infrastructure changes. Running them on every commit is usually too expensive; running them never is too risky.

@feynman

A system test is like a full dress rehearsal for a play — every actor, every prop, every lighting cue is real, and what you find out is whether the whole production holds together, not just whether each actor knows their lines.

@card
id: est-ch08-c011
order: 11
title: Test Data Management for Larger Tests
teaser: Test data strategy is the hidden complexity of integration and system tests — how you create, share, and clean up data determines whether your tests are independent, fast, and reliable.

@explanation

Unit tests generate their own data entirely in memory. Larger tests that interact with real databases, real message queues, or real file systems must decide how to create, scope, and clean up test data — and the decision has significant consequences for test reliability and speed.

**The core tension:** shared data is fast (set up once, use many times) but dangerous (tests interfere with each other); isolated data is safe but slower (set up per test, clean up after each).

**Strategies and tradeoffs:**

- **Transaction rollback.** Each test runs inside a database transaction that is rolled back after the test. Fast and clean — the database is always in the same state. Limitation: does not work if your code commits the transaction internally, or if you are testing across multiple database connections.

- **Truncate and re-seed.** After each test (or test class), truncate the relevant tables and re-insert baseline data from a fixture file or factory. Reliable but slow for tables with many rows or complex foreign key relationships.

- **Test factories.** Functions or classes that create minimal, valid entities in the database (factory_boy in Python, FactoryBot in Ruby, custom builders in Java). Each test creates only the data it needs. No shared state. Tests are self-documenting about their data requirements.

- **Shared fixtures.** Read-only reference data (country codes, product categories) loaded once before the test suite runs and never modified. Tests that read this data can share it safely.

- **Unique identifiers.** For message queues and event streams, prefix every entity ID and topic name with a UUID generated at test run time. Tests cannot share a Kafka topic named `orders` — they can share a cluster where each test uses `orders-<uuid>`.

The worst pattern is tests that depend on each other's execution order — test B expects the data that test A inserted. This makes test suites impossible to run in parallel and produces mystifying failures when the order changes.

> [!warning] Tests that depend on execution order are not tests — they are scripts. Every integration test must be able to run in isolation and in any order. If it cannot, it is not testing what you think it is.

@feynman

Test data management is like maintaining clean kitchen equipment between cooking sessions — if you skip the cleanup, the flavors from the last dish contaminate the next one, and you cannot tell whether the new recipe actually tastes right.

@card
id: est-ch08-c012
order: 12
title: Performance Tests
teaser: Performance tests answer a different question than correctness tests — not "does it work?" but "does it work under load?" — and tools like k6, Locust, and Gatling exist because unit and integration tests cannot answer that question.

@explanation

Correctness tests verify behavior under controlled, low-concurrency conditions. Performance tests apply realistic or extreme load and measure whether the system meets its latency, throughput, and error rate targets. A system can pass every correctness test and fail catastrophically under production load because of a connection pool misconfiguration, a missing database index, or a synchronization bottleneck.

**Performance test categories:**

- **Load tests** — apply the expected production load and verify that response times and error rates stay within acceptable bounds. The baseline: "can we handle our normal traffic?"
- **Stress tests** — increase load until the system breaks. The question: "where is the breaking point, and does it fail gracefully?"
- **Soak tests** — apply moderate load for a long duration (hours or days). The question: "does the system degrade over time due to memory leaks, connection exhaustion, or log file growth?"
- **Spike tests** — apply sudden, extreme load increases. The question: "does the system recover from traffic spikes without cascading failures?"

**Tool choices:**

- **k6** (Grafana): JavaScript scripting, built-in metrics, excellent CI integration, VU (virtual user) model. Recommended for most teams starting fresh.
- **Locust** (Python): Python scripting, web UI, easy to customize, good for teams already using Python. Scales to large numbers of simulated users with distributed mode.
- **Gatling** (Scala/DSL): JVM-based, highest throughput simulation capability, popular in enterprise Java environments. Steeper learning curve than k6 or Locust.

When performance is part of correctness:

- An SLA that specifies p99 response time is a correctness requirement. Violating it is a bug.
- A background job that processes 10,000 records in under 60 seconds has a performance requirement embedded in its specification.

In both cases, the performance test belongs in CI — failing to meet the threshold fails the build — rather than as an ad-hoc measurement done before a release.

> [!info] k6's `checks` API lets you define pass/fail thresholds (p95 < 200ms, error rate < 1%) that exit with a non-zero code when violated. This is what makes performance tests first-class CI citizens rather than dashboard-only metrics.

@feynman

A performance test is like testing how many people can exit a theater in under two minutes — the fact that the doors open correctly tells you nothing about whether the crowd can actually get through them in time.
