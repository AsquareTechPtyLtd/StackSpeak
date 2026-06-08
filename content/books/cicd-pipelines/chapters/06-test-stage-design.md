@chapter
id: cicdp-ch06-test-stage-design
order: 6
title: Test Stage Design
summary: The test pyramid in CI terms — unit, integration, contract, E2E — flaky-test management, test sharding for parallel execution, and selective testing for monorepos that gets feedback to the developer in minutes, not hours.

@card
id: cicdp-ch06-c001
order: 1
title: The Test Pyramid in CI Terms
teaser: Mike Cohn's test pyramid is not a diagram for test suites — it is a budget allocation framework for CI. The pyramid tells you how many tests of each type to run, in what order, and on which triggers.

@explanation

Mike Cohn introduced the test pyramid in *Succeeding with Agile* (2009). The pyramid has three layers: unit tests at the base (many, fast, cheap), service or integration tests in the middle (fewer, slower, moderately expensive), and UI or end-to-end tests at the apex (few, slow, expensive). The shape encodes a budget constraint: fast tests should dominate; slow tests should be selective.

In CI terms, the pyramid becomes a stage ordering and trigger allocation strategy:

- **Unit tests** — run on every commit, on every pull request, before anything else. They must complete in under 5 minutes. They are the primary fail-fast signal.
- **Integration tests** — run on every merge to main, and optionally on pull requests. They take 5–20 minutes and require real or containerized dependencies.
- **End-to-end tests** — run on merge to main or nightly. They take 20–60 minutes and should be limited to the most critical user journeys.

The pyramid also implies a failure priority: a unit test failure is more actionable than an E2E test failure, because it points to a smaller blast radius. CI pipelines should stop and report as soon as the lowest feasible test layer fails, before spending compute on slower layers.

The anti-pattern the pyramid guards against is the *ice cream cone* — suites dominated by slow, brittle E2E tests and almost no unit tests. Ice cream cone test suites produce pipelines that run for 45 minutes, fail unpredictably, and give developers no actionable information about what broke or why.

> [!info] Martin Fowler's 2012 refinement of the pyramid added a fourth layer — contract tests — between integration and E2E. In microservice architectures, contract tests carry substantial weight: they verify service boundaries without requiring all services to run simultaneously.

@feynman

The test pyramid says: run lots of fast unit tests, a moderate number of integration tests, and a small number of E2E tests. In CI, that means unit tests block the PR, integration tests run on merge, and E2E tests run selectively — not on every single commit.

@card
id: cicdp-ch06-c002
order: 2
title: Unit Tests as the Pipeline Foundation
teaser: Unit tests are the cheapest signal the pipeline produces. They run in milliseconds, need no infrastructure, and point precisely to the line of code that broke. A pipeline that cannot complete unit tests in under five minutes is a pipeline that needs architectural attention.

@explanation

A unit test verifies a single function, class, or module in isolation — with external dependencies (databases, APIs, queues) replaced by mocks or stubs. The isolation is what makes unit tests fast and deterministic: they do not wait for network calls, do not compete for shared resources, and do not depend on environment configuration.

In CI, the unit test job should have three properties:

- **Speed.** If the unit test suite takes more than 5 minutes, it is either too large, poorly parallelized, or includes tests that are not actually unit tests. Jest and pytest both support parallel execution natively — use it.
- **No external dependencies.** The unit test job must not require a running database, a message broker, or network access. If it does, those tests are integration tests, and they belong in a different job with appropriate infrastructure.
- **Determinism.** Unit tests must produce the same result on every run. A unit test that fails intermittently is not testing the unit — it is testing the environment, which means it is not a unit test.

The discipline of writing good unit tests is inseparable from the discipline of writing testable code. Code with hard-coded dependencies, global state, or deeply nested conditionals is inherently difficult to unit test. If a team finds it painful to write unit tests, that is usually a signal that the production code needs structural refactoring — not that the tests should be skipped.

Common CI configuration for the unit test stage in a Node.js project with Jest:

- Run `jest --runInBand` for single-runner execution or `jest --maxWorkers=4` for parallel execution within the runner.
- Use `--ci` flag in CI to disable interactive watch mode and treat snapshot mismatches as failures rather than prompts.
- Publish test results as a JUnit XML artifact so the CI platform can surface failure details without requiring log inspection.

> [!warning] Unit tests that mock too much test nothing. A test that mocks every dependency and asserts that the mock was called is verifying the test's own setup, not the production code's behavior. Mocks should replace infrastructure, not business logic.

@feynman

Unit tests run one function in isolation, with all external dependencies replaced by stand-ins. They should take seconds, require no infrastructure, and give the same result every time. When they don't, you've stopped writing unit tests.

@card
id: cicdp-ch06-c003
order: 3
title: Integration Tests and Their Costs
teaser: Integration tests verify that components work together — which means they need real infrastructure, real dependencies, and real time. In CI, that cost must be managed explicitly or it accumulates until the pipeline becomes unusable.

@explanation

An integration test exercises the interaction between two or more components — typically a service and its database, a service and a message queue, or two services communicating over HTTP. Unlike unit tests, integration tests cannot mock away their dependencies: the point is to test the integration, not a simulation of it.

This creates a cost structure that unit tests avoid entirely:

- **Infrastructure spin-up time.** Starting a PostgreSQL container, seeding test data, and waiting for readiness probes adds 30–90 seconds before the first test even runs. Docker Compose and Testcontainers (Java, Go, Python) are the standard approaches. Both work in CI, but neither is instant.
- **Shared state contamination.** Integration tests that share a database instance without proper cleanup contaminate each other. A test that passes in isolation fails when run after another test that left dirty data. The solution is per-test transaction rollback or per-suite database recreation.
- **Longer total runtime.** A 500-test integration suite that averages 200 ms per test takes over a minute and a half, plus infrastructure overhead. Without parallelism, this scales linearly and quickly crosses the 10-minute feedback threshold.
- **Network flakiness.** Integration tests are sensitive to timing — a service that starts slowly, a queue that takes a moment to process, a test that does not wait for readiness. Retry logic and health-check polling are necessary but add complexity.

The recommended CI pattern for integration tests: run them as a separate job from unit tests, using service containers (GitHub Actions' `services:` or GitLab CI's service links) to provide real dependencies. This isolates the infrastructure cost to the integration job and avoids polluting the fast unit test signal.

> [!info] Testcontainers (testcontainers.com) is the leading library for programmatic container management in integration tests. It starts Docker containers from within the test code, waits for readiness, and tears them down after the test — eliminating the need for a separate Docker Compose file in CI.

@feynman

Integration tests check that pieces work together, which means they need real databases, real queues, real services — and all of that takes time to start and costs money to run. In CI, you manage that cost by running integration tests in a separate job, with proper cleanup between tests.

@card
id: cicdp-ch06-c004
order: 4
title: Contract Testing at Service Boundaries
teaser: Contract testing sits between integration tests and E2E tests in the pyramid — it verifies that service interfaces keep their promises without requiring every service to run at the same time. Pact is the reference implementation.

@explanation

In a microservice architecture, integration tests have a scaling problem: to verify that Service A and Service B still work together after a change to A, you need both services running, with their respective databases, in a shared environment. As the number of services grows from 5 to 50, the combinatorial cost of full integration testing becomes intractable.

Contract testing solves this with a different model. A **consumer-driven contract** is a document that specifies exactly what the consumer (Service A) expects from the provider (Service B): which endpoints, which request shapes, which response fields. The contract is generated by the consumer's tests and then verified against the provider independently — without requiring both services to run simultaneously.

The Pact framework (pact.io) is the reference implementation. Its CI workflow:

- Consumer pipeline runs Pact consumer tests, which generate a contract JSON file and publish it to a Pact Broker.
- Provider pipeline runs Pact provider verification, which fetches the contracts from the broker and verifies the provider implements them correctly.
- The Pact Broker tracks which consumer/provider version combinations are compatible. A new provider deploy is blocked if it breaks an existing consumer contract.

The power of this model is asymmetry: consumer teams can evolve their contracts independently. Provider teams know immediately — from their own CI pipeline — whether a proposed change breaks any existing consumer. This eliminates an entire class of deployment-time integration failures that would otherwise require E2E test runs to detect.

Contract tests are fast — typically completing in under 30 seconds — because they do not require real infrastructure. The Pact consumer test runs against a mock provider; the Pact provider verification runs the real provider against recorded consumer interactions.

> [!info] PactFlow (pactflow.io) is the commercial Pact Broker with additional features including bi-directional contract testing (for teams that cannot modify the provider's test suite) and can-i-deploy gates that block incompatible versions from reaching production.

@feynman

Contract testing lets two services verify their interface agreement without running at the same time. The consumer writes down what it expects; the provider checks it can deliver that — in its own CI pipeline. Pact is the tool that coordinates the exchange.

@card
id: cicdp-ch06-c005
order: 5
title: End-to-End Testing — When and How Much
teaser: End-to-end tests are the most expensive signal in the pipeline and the most brittle. The right answer is not "run more" — it is "run fewer, better-chosen scenarios" and manage them as a distinct, owned test suite.

@explanation

An end-to-end test exercises the full system from the user's perspective: a real browser, a real frontend, a real backend, a real database. Playwright and Cypress are the dominant tools in this space. Both can drive a real browser, wait for async rendering, and assert on what the user actually sees.

The cost profile of E2E tests:

- **Execution time.** A single Playwright test scenario that navigates three pages and submits a form takes 5–15 seconds. A suite of 100 such scenarios takes 8–25 minutes on a single runner.
- **Infrastructure requirements.** E2E tests need the full stack: frontend, backend, database, third-party service mocks (or staging credentials). This environment is expensive to provision and maintain.
- **Flakiness.** E2E tests are the most flake-prone category because they are sensitive to rendering timing, network conditions, and test data state. An E2E suite with a 10% flakiness rate is not a test suite — it is noise.

Given this cost structure, the recommended CI placement for E2E tests:

- **Do not run the full E2E suite on every pull request commit.** The feedback is too slow and too noisy to be useful at that frequency. Run unit and integration tests on PRs; reserve E2E for post-merge.
- **Run a critical-path smoke suite (5–10 scenarios) on every merge to main.** These cover the highest-value user journeys: login, core transaction, checkout. Failures here block deployment.
- **Run the full E2E regression suite nightly or before production releases.** This catches regressions in lower-priority paths without gating every deploy.

> [!warning] Playwright's --shard flag and Cypress's parallelization via the Cypress Cloud allow the full E2E suite to run in parallel across multiple runners, reducing total wall time proportionally. A 100-test suite that takes 20 minutes on one runner takes 5 minutes across four runners.

@feynman

E2E tests are slow, expensive, and fragile — which means you need fewer of them, not more. Run a small set of critical-path scenarios on every merge and save the full suite for nightly or pre-release runs.

@card
id: cicdp-ch06-c006
order: 6
title: Smoke Testing After Deploy
teaser: A smoke test is the pipeline's first question after a deploy: "Is the service alive?" It is not a correctness check — it is a liveness check. If the smoke test fails, the deploy is rolled back before any user is affected.

@explanation

The term comes from electronics: power on a new circuit board and check whether it smokes. In software, a smoke test runs immediately after a deploy completes and verifies that the most fundamental behaviors are working: the service starts, the health endpoint responds, the database connection is alive, and the login flow does not 500.

Smoke tests are distinct from integration tests and E2E tests in their purpose and placement:

- **Integration tests** verify behavior before a deploy. Smoke tests verify the deployed artifact in the target environment.
- **E2E tests** are comprehensive. Smoke tests are intentionally minimal — typically 5–15 critical scenarios that complete in under 2 minutes.
- Smoke tests run post-deploy, against the real environment, using real (or near-real) credentials and data.

A well-designed smoke test suite covers exactly two things: liveness (the service is reachable) and critical path correctness (the most important user action succeeds). Everything else is regression testing and belongs in a longer-running suite.

Smoke tests integrate with deployment strategy. In a canary or blue-green deploy, the smoke test runs against the new version before traffic is shifted. If the smoke test fails, the new version is killed and traffic stays on the old version — the rollback is automatic and invisible to users.

Practical smoke test implementation options:

- A dedicated Playwright or Cypress spec file that runs only the smoke scenarios, pointed at the staging or canary URL.
- A curl-based health check script that verifies HTTP status codes and response shape on critical endpoints.
- An API integration test using pytest or Jest, seeded with test-specific data and cleaned up afterward.

> [!info] The smoke test must run as a pipeline stage, not as an external monitoring check. Monitoring tells you when a problem has reached production users. A smoke test gate prevents a broken deploy from ever reaching them.

@feynman

A smoke test runs right after a deploy and asks: is this thing alive and does it do the one most important thing? It is fast, minimal, and its failure triggers an automatic rollback — before any user notices anything is wrong.

@card
id: cicdp-ch06-c007
order: 7
title: Regression Testing in CI
teaser: Regression testing is the practice of verifying that previously working behavior still works after a change. In CI, that means every commit runs a suite broad enough to catch regressions — but the suite must be fast enough to not become the bottleneck.

@explanation

A regression is a defect introduced by a change that breaks behavior that was previously correct. Regression testing is the umbrella term for the suite of tests — unit, integration, and E2E — that guards against regressions. In CI, the entire test pyramid is, in effect, a regression suite: it re-runs the full verification on every commit to catch anything the change broke.

The tension in CI regression testing is between coverage and speed. A comprehensive regression suite that covers every code path is expensive to run. A fast regression suite that skips coverage cannot catch subtle regressions. The resolution is layered regression:

- **Per-commit regression** — unit tests plus integration tests for the changed module. Fast, targeted, runs on every PR commit.
- **Per-merge regression** — the full unit and integration suite plus a smoke E2E run. Runs on every merge to main.
- **Nightly regression** — the complete E2E regression suite, performance benchmarks, and cross-browser compatibility tests. Runs on a schedule, not on commit.

Regression test suites have a lifecycle problem: they accumulate. Tests are added when bugs are found but rarely removed when the underlying code is deleted or refactored. Over time the suite slows down, flakiness increases, and the signal-to-noise ratio degrades. Treating regression tests as first-class code — subject to the same refactoring discipline as production code — is the countermeasure.

One effective practice: measure test execution time per file or module and set a policy that any test file taking more than 30 seconds is a candidate for refactoring, parallelization, or replacement with a more targeted unit test.

> [!warning] A regression suite that is never updated is a regression suite that is slowly becoming wrong. As code evolves, tests that no longer test real behavior become dead weight — they consume time, produce false confidence, and obscure genuinely useful failures.

@feynman

Regression testing means: run the tests that confirm nothing that used to work has stopped working. In CI you do this on every commit — but you split the suite into fast layers so the slowest tests only run when the cost is worth paying.

@card
id: cicdp-ch06-c008
order: 8
title: Code Coverage as a Signal (and Its Limits)
teaser: Code coverage tells you which lines were executed during your test suite — not whether those lines were tested meaningfully. Using coverage as a gate without understanding its limits produces false confidence and perverse incentives.

@explanation

Code coverage measures the percentage of production code executed during a test run. Most CI pipelines report it using tools like Istanbul (JavaScript), coverage.py (Python), JaCoCo (Java), or Coverprofile (Go). A typical CI configuration generates an HTML report and enforces a minimum threshold — commonly 80% — that blocks the build if not met.

What coverage genuinely signals:

- **Dead code.** Lines with 0% coverage are never executed. They are either unreachable dead code or a gap in the test suite — either way, worth investigating.
- **Untested branches.** Branch coverage (condition coverage) identifies conditional paths that no test exercises — a more useful signal than line coverage for finding gaps in error handling and edge case logic.
- **Coverage trends.** Coverage that decreases over time indicates that new code is being added without tests. Tracking the trend matters more than the absolute number.

What coverage does not signal:

- **Test quality.** A test that executes a function without asserting anything produces 100% coverage with zero verification. Coverage measures execution, not assertion quality.
- **Correctness.** A function can be covered and wrong. Coverage tells you the test ran the code; it does not tell you the test verified the behavior.
- **Sufficient test scope.** 80% line coverage leaves 20% of the code untested — but more critically, it says nothing about which 20% and whether that 20% contains the application's most important logic.

> [!info] Mutation testing tools — Pitest (Java), Mutmut (Python), Stryker (JavaScript) — go beyond coverage by deliberately introducing bugs into the code and checking whether existing tests catch them. A mutation score measures test effectiveness, not just test execution. It is a stronger signal than coverage and significantly more expensive to compute.

@feynman

Coverage tells you which lines ran during your tests — not whether your tests are any good. High coverage with weak assertions gives false confidence. Treat coverage as one data point, not as proof that your code is tested.

@card
id: cicdp-ch06-c009
order: 9
title: Flaky Tests and How to Handle Them
teaser: A flaky test is one that passes and fails without code changes. A single flaky test erodes trust in the entire pipeline; a flaky suite produces a team that ignores pipeline failures. Flakiness is not a nuisance — it is a pipeline correctness failure.

@explanation

A flaky test produces different results — pass or fail — across runs of the same code, same environment, and same configuration. The failure is non-deterministic: it depends on timing, shared state, resource contention, random data, or external service availability rather than on the code under test.

The root causes of flakiness:

- **Timing dependencies.** Tests that use fixed sleeps (`time.sleep(2)`) or assume an async operation completes within an arbitrary window will fail when the environment is slower than expected. Replace with deterministic waits: poll until the condition is true or fail with a timeout.
- **Shared state.** Tests that read from or write to shared data — a shared database, a shared in-memory cache, a shared file — can interfere with each other when run in parallel. Each test must own its data or use transaction rollback.
- **Order dependency.** Tests that pass when run in one order and fail in another have hidden state coupling. The fix is to make each test fully independent: arrange, act, assert, clean up.
- **External service instability.** Tests that call real external APIs will flake when those APIs are slow or down. Stub or mock external services in test suites that run in CI.

The CI response to flaky tests:

- **Detect.** Track test pass rate over time. A test that passes 85% of runs is flaky. GitHub Actions and BuildKite both offer test analytics that surface flakiness rates automatically.
- **Quarantine.** Move identified flaky tests to a quarantine suite that runs separately, does not block merges, and notifies the owning team. This restores pipeline trust immediately while giving the team time to fix root causes.
- **Fix, do not disable.** A test disabled with a TODO comment is a test that will never be fixed. Set a policy: quarantined tests get a maximum quarantine period (one sprint, two weeks) before they are either fixed or deleted.

> [!warning] The worst response to a flaky test is retrying it automatically and recording the pass. Automatic retry without root-cause analysis hides the signal, increases pipeline duration, and creates the illusion of a green pipeline that is actually unreliable.

@feynman

A flaky test sometimes passes and sometimes fails for no good reason — usually because of timing, shared data, or hidden state. The right response is: detect it, quarantine it so it stops blocking your pipeline, and fix it before the quarantine period expires.

@card
id: cicdp-ch06-c010
order: 10
title: Test Runners and Parallel Execution
teaser: A test runner that executes 1,000 tests sequentially on a single thread is a bottleneck masquerading as a tool. Modern test runners support parallelism at the file, process, or machine level — understanding which level applies to your suite determines how fast you can make it.

@explanation

A test runner is the process that discovers, executes, and reports on tests. Jest (JavaScript), pytest (Python), JUnit/Maven Surefire (Java), and Go's built-in `go test` are the dominant runners. Each supports some form of parallelism, but the granularity and configuration differ.

Parallelism levels available to test runners:

- **Thread-level parallelism.** Run multiple tests concurrently within a single process on multiple threads. Jest's `--maxWorkers` and pytest-xdist's `-n auto` both use this model. Effective for CPU-bound tests; limited by shared process state and memory.
- **Process-level parallelism.** Spawn multiple worker processes, each running a subset of tests. Provides better isolation than thread-level — a segfault or OOM in one worker does not kill the others.
- **Runner-level parallelism.** Distribute test files across multiple CI runners (machines). The test suite is divided into N shards, each runner gets one shard, and results are aggregated at the end. This is the highest level of parallelism and the one that produces the greatest speed gains for large suites.

Parallel test execution requires test isolation as a prerequisite. Tests that share mutable global state, a single database instance without cleanup, or files in the same directory will interfere with each other when run concurrently. Parallelism amplifies isolation problems — it does not create new ones, but it makes existing ones visible.

Common configuration for parallel unit tests in GitHub Actions with Jest:

- Set `--maxWorkers=50%` to use half the available CPUs, leaving headroom for the OS and runner overhead.
- Use `--forceExit` to prevent hung processes from blocking the CI step if a test leaks an open handle.
- Publish JUnit XML results from each worker and aggregate them in the CI reporting layer.

> [!info] pytest-xdist distributes test collection and execution across N worker processes using a load-balanced scheduler. For suites where test runtimes vary widely, xdist's dynamic load balancing (--dist=loadscope or --dist=worksteal) produces better utilization than static file partitioning.

@feynman

A test runner can parallelize work at three levels: threads within one process, multiple processes on one machine, or multiple machines in CI. Each level requires better test isolation. The payoff is proportional — four machines running in parallel means roughly four times the throughput.

@card
id: cicdp-ch06-c011
order: 11
title: Test Sharding for Massive Suites
teaser: Test sharding divides a test suite into N equal partitions and runs each partition on a separate runner simultaneously. It is the primary technique for keeping large test suites within the 10-minute feedback target without compromising coverage.

@explanation

When a test suite grows beyond what a single runner can execute in the feedback budget (typically 10 minutes), the options are: remove tests, speed up individual tests, or distribute the work across multiple runners. Sharding is the third option — distribute the suite across N runners, each running 1/N of the tests, and aggregate results at the end.

Sharding strategies:

- **File-based sharding.** Divide test files into N groups and assign each group to a runner. Simple to implement but can produce uneven shards if test files vary widely in execution time.
- **Time-based sharding.** Use historical timing data to produce shards of approximately equal duration. Playwright's `--shard=1/4` syntax and pytest-split's `--splits=4 --group=1` flag support this model with timing files stored between CI runs.
- **Bazel test sharding.** Bazel's `shard_count` attribute distributes test targets across runners with hermetic caching — only changed targets and their transitive dependencies re-run. This is the most sophisticated approach and the one used at Google scale.

GitHub Actions matrix strategy is the standard mechanism for sharding in GitHub-hosted pipelines. A matrix job creates N parallel runners, each receiving a shard index and total shard count as environment variables:

- Define `strategy: matrix: shard: [1, 2, 3, 4]` to create four parallel jobs.
- Pass `${{ matrix.shard }}` and `4` to the test runner's shard arguments.
- Use a final aggregation job with `needs:` on all shard jobs to collect and merge test result artifacts.

For monorepos, sharding combines with selective testing: first identify which packages changed, then shard only the tests for those packages across N runners. This keeps the feedback loop fast even as the monorepo grows, because the shard count scales with changed surface area rather than total suite size.

> [!info] Playwright natively supports sharding via --shard=X/N. Running playwright test --shard=1/4 on four parallel runners reduces a 40-minute E2E suite to 10 minutes with no changes to the test code — only a matrix configuration change in the CI YAML.

@feynman

Sharding splits your test suite into equal chunks and runs each chunk on a different machine at the same time. If 4,000 tests take 40 minutes on one runner, they take roughly 10 minutes on four runners. The tests themselves don't change — you just distribute them.

@card
id: cicdp-ch06-c012
order: 12
title: Continuous Testing as a Practice
teaser: Continuous Testing is not a stage in the pipeline — it is a practice that spans the full delivery cycle. Tests run at commit time, at deploy time, in production, and on a schedule. The goal is an unbroken feedback loop between code change and confidence signal.

@explanation

Continuous Testing (CT) extends Continuous Integration's feedback discipline across the entire delivery lifecycle. Where CI runs tests on every commit, CT ensures that test verification happens at *every stage* where a new risk surface is introduced: at the commit, at the merge, at the deploy to staging, at the deploy to production, and continuously thereafter in production.

The CT lifecycle across a typical pipeline:

- **Commit gate.** Unit tests and fast integration tests. Must complete in under 10 minutes. Blocks merge on failure.
- **Merge gate.** Full integration suite, contract tests, and code coverage check. Blocks staging deploy on failure.
- **Deploy gate.** Smoke tests against the deployed environment. Blocks traffic shift on failure. Triggers automatic rollback.
- **Nightly regression.** Full E2E suite, performance benchmarks, and cross-browser tests. Does not block deploys but generates alerts for the engineering team.
- **Production synthetic monitoring.** Scripted user journeys executed against production on a schedule (every 5 minutes). Detects production-only failures invisible to pre-deploy tests.

The DORA research identifies continuous testing as one of the technical practices most strongly correlated with high software delivery performance. Teams that practice CT have significantly lower change failure rates and faster recovery times than teams that test only at commit time.

Implementing CT requires organizational commitment beyond tooling:

- **Tests are treated as first-class code.** They are reviewed, refactored, and owned by the team that owns the production code.
- **Flaky tests are fixed, not ignored.** A flakiness budget — no more than 1% of test runs produce non-deterministic results — is monitored and enforced.
- **Test coverage is a team metric, not a compliance checkbox.** Coverage trends are reviewed in retrospectives alongside feature velocity.

> [!info] Continuous Testing does not mean running all tests at all times. It means having the right tests, running at the right stage, blocking the right gates. A poorly designed CT implementation that runs a 90-minute E2E suite on every commit is worse than a well-designed CI pipeline with a 5-minute unit test gate.

@feynman

Continuous Testing means you have a test check at every point where something new could go wrong — not just at commit time, but at merge, at deploy, in staging, and in production. The goal is that no environment change goes unverified.
