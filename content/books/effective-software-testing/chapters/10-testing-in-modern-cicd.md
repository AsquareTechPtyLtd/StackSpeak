@chapter
id: est-ch10-testing-in-modern-cicd
order: 10
title: Testing in Modern CI/CD
summary: A modern test pipeline is fast, parallel, flake-aware, and tier-stratified — running everything sequentially on every push doesn't scale, and the practices that keep CI green at scale are different from "run all the tests".

@card
id: est-ch10-c001
order: 1
title: The Fast, Parallel, Stratified Pipeline
teaser: Modern CI has three properties that work together — fast feedback, parallel execution, and tests tiered by cost — and missing any one of them breaks the others.

@explanation

The goal of a CI pipeline is to give developers accurate feedback as quickly as possible. Three structural properties make that possible at scale.

**Fast** means developers don't wait. A pipeline that takes 40 minutes before telling someone their change broke something trains people to stop running it. The feedback loop that matters most is the one that runs in under 10 minutes on most pushes.

**Parallel** means multiple machines work simultaneously. Unit tests run at the same time as linting. Integration tests in different packages run concurrently. No step waits for an unrelated step to finish. In GitHub Actions this is multiple jobs in a workflow; in GitLab CI it is parallel pipeline stages; in CircleCI it is parallel job execution across containers.

**Stratified** means tests are grouped by speed and cost, and different strata run in different conditions. A common three-tier model:

- **Tier 1 — Unit tests:** Run on every commit to every branch. Sub-minute. No external dependencies.
- **Tier 2 — Integration tests:** Run on every pull request. A few minutes. Real databases, real queues, but containerized or mocked external APIs.
- **Tier 3 — End-to-end / contract tests:** Run on merge to main, or on a schedule. Can take tens of minutes. Real environments.

The failure mode is treating CI as "run all the tests in sequence." That approach works for a project with 50 tests. It does not work for a project with 50,000 tests across 20 services.

> [!tip] Design your pipeline with the stratification in mind from the start. Bolting it on after a monolithic pipeline has grown to 45 minutes is much harder than building the tiers in when the project is small.

@feynman

A stratified CI pipeline is like a hospital triage system — fast checks happen immediately for everyone, deeper investigations only for the cases that need them, and the most expensive scans run only when there's real reason to believe something is seriously wrong.

@card
id: est-ch10-c002
order: 2
title: Test Parallelization
teaser: Parallelization splits a test suite across multiple concurrent runners, cutting wall-clock time proportionally — but it introduces coordination overhead and makes shared state dangerous.

@explanation

Parallelization runs tests concurrently rather than serially. If 1,000 unit tests take 10 minutes on a single runner, four runners can theoretically finish in 2.5 minutes. In practice, the speedup is real but the math is imperfect.

**How it works in practice:**

In GitHub Actions, you define a matrix strategy over a set of runner instances. Each runner picks up a slice of the test suite and executes it independently. In CircleCI, you use `circleci tests split` to distribute test files across parallel containers. Buildkite has native parallelism via the `parallelism` key on a step — Buildkite agents pick up work from the queue automatically.

**What it costs:**

- **Coordination overhead.** Spinning up containers, installing dependencies, and cloning repos on each runner takes time. If your individual test run is 30 seconds and startup costs 60 seconds, parallelism makes things slower, not faster. Cache your dependencies aggressively.
- **Shared state is a critical hazard.** Tests that write to the same database rows, the same files, or the same in-memory singletons will have race conditions when run in parallel. Tests must be independent — each creates its own data, each cleans up after itself.
- **Result aggregation.** You need to collect test reports from every runner and merge them. JUnit XML output from each runner is the standard — the CI platform typically merges these automatically for display.

Parallelization at the file level (each runner gets whole test files) is easiest. Parallelization at the test level (each runner gets individual test functions) gives finer-grained load balancing but requires framework support.

> [!warning] Shared database state is the most common cause of flakiness introduced by parallelization. If you run tests in parallel and suddenly see random failures, suspect unintentional state sharing before anything else.

@feynman

Parallelizing tests is like assigning sections of a document to different proofreaders simultaneously — you finish faster, but every proofreader must work on their own copy, because two people editing the same page at the same time creates chaos.

@card
id: est-ch10-c003
order: 3
title: Test Sharding
teaser: Sharding distributes tests across machines to minimize total runtime — but naive even splitting creates imbalance, and the best allocation strategies use historical timing data to equalize load.

@explanation

Sharding is a specific form of parallelization focused on distributing tests across N machines such that all machines finish at approximately the same time. If machine 1 finishes in 2 minutes and machine 2 finishes in 8 minutes, the total runtime is 8 minutes — you're paying for 4 machines but only getting the speedup of the slowest one.

**The allocation problem:**

Naive sharding assigns N/total test files to each machine. This works poorly when test files have wildly different runtimes — a single slow integration test file can anchor an entire shard while other shards sit idle.

Better allocation uses historical timing data. Buildkite Test Analytics records per-test durations and can split test suites by time rather than count. Nx stores timing information in its distributed task cache and uses it to assign work optimally. The goal is for all shards to finish within a few seconds of each other.

**In practice:**

- `pytest-split` for Python splits by measured duration using a stored durations file.
- `circleci tests split --split-by=timings` uses CircleCI's recorded test durations.
- Bazel's remote execution distributes actions across workers with awareness of estimated cost.
- Nx Agents assigns tasks across machines based on the task graph and historical timing.

The sharding strategy and the number of shards are tuning parameters. Too few shards: still slow. Too many shards: startup overhead dominates. For most suites, 4–8 shards hits the knee of the curve.

> [!info] Timing-based sharding typically cuts total runtime by 20–40% compared to count-based sharding when test durations are non-uniform, which they almost always are in mixed unit/integration suites.

@feynman

Test sharding is like dividing a delivery route among couriers — you don't want one courier with fifty packages and another with two, so you use delivery time estimates to give each courier roughly the same amount of work, and everyone finishes at the same time.

@card
id: est-ch10-c004
order: 4
title: Flaky Test Detection and Quarantine
teaser: A flaky test is one that fails non-deterministically without any change to the code — and the damage it does to CI trust is disproportionate to how often it actually fires.

@explanation

A flaky test poisons CI in a specific way: developers start re-running failed pipelines as a reflex, because they know some failures are meaningless. When "maybe it'll pass on retry" becomes the mental model, a real regression can hide behind assumed flakiness for days.

**Detection strategies:**

- **Automated retry with classification.** Run the failing test N times in isolation. If it passes at least once, it is likely flaky. Both Buildkite Test Analytics and Datadog CI Visibility track per-test pass/fail rates over time and flag tests whose failure rate is inconsistent with code changes.
- **Re-run on no-diff commits.** Running the full suite on a branch where no files changed (a repeated push of the same commit) reveals tests that are failing due to timing, environment, or ordering rather than logic.
- **Failure rate dashboards.** Track each test's failure rate over a 30-day window. Tests above a threshold (say, 2% failure rate with no correlated code change) are flagged automatically.

**Quarantine zones:**

A quarantine zone is a separate CI step or configuration where known-flaky tests run but their results do not block the build. The test still runs — you want to know if the flakiness gets worse or better — but a flaky test in quarantine does not prevent a merge. The contract: tests in quarantine must be fixed or deleted within a defined SLA (typically 2 weeks).

Without a quarantine mechanism, the incentive structure is wrong: teams either ignore flaky tests (broken window effect) or spend hours debugging non-determinism under merge pressure.

> [!warning] A quarantine zone without an SLA is a test graveyard. Set a hard rule: tests in quarantine are fixed or deleted within 2 weeks, no exceptions, or the quarantine becomes a dumping ground.

@feynman

A flaky test in CI is like a fire alarm that goes off randomly at night — after enough false alarms, people stop taking it seriously, so when a real fire happens, no one reacts, which is far more dangerous than no alarm at all.

@card
id: est-ch10-c005
order: 5
title: Test Impact Analysis
teaser: Test impact analysis runs only the tests that are actually affected by a change — cutting feedback time dramatically but requiring tooling investment and accepting the risk of missed coverage.

@explanation

Instead of running the full test suite on every commit, test impact analysis (TIA) maps source files to the tests that cover them, then runs only the tests that transitively depend on changed files.

**How the mapping works:**

Tools instrument the test run to track which source files each test actually executes. Bazel uses Skylark-based dependency graphs — tests only depend on the targets they explicitly declare, so only tests that depend on changed targets need to re-run. Nx builds a task graph from `package.json` and `project.json` dependency declarations; changing a library only triggers tests in packages that depend on that library. Turborepo works similarly, using its package dependency graph.

**The speedup is significant:**

In a large monorepo, a change to a utility library used in two packages might trigger 200 tests instead of 20,000. Build time drops from 30 minutes to 2 minutes. Developers get faster feedback and make more incremental commits.

**The tradeoffs are real:**

- **Mapping accuracy.** Dynamic imports, reflection, and certain types of runtime configuration can cause the dependency graph to be incomplete. A test that *should* run might not be included.
- **Tooling investment.** Bazel and Nx require significant setup and adoption. Retrofitting TIA onto an existing Webpack project that didn't use module boundaries intentionally is hard.
- **Trust calibration.** Teams using TIA typically still run the full suite on merge to main, using TIA only for the pre-merge feedback loop.

> [!info] Test impact analysis is most valuable in monorepos with clear module boundaries. In polyrepos or in projects with implicit cross-file dependencies, the dependency graph is harder to maintain accurately.

@feynman

Test impact analysis is like a smart smoke detector that only checks the rooms where someone has been recently — rather than testing the whole house every hour, it focuses its attention where activity actually happened.

@card
id: est-ch10-c006
order: 6
title: Pre-Commit Hooks vs CI Gates
teaser: Pre-commit hooks give instant local feedback but can be bypassed and don't scale to long tests; CI gates are authoritative but slower — each serves a different enforcement role.

@explanation

Pre-commit hooks and CI gates are not substitutes for each other. They serve different purposes in the development workflow.

**Pre-commit hooks** run locally before a commit completes. Tools like `pre-commit`, Husky (for Node projects), or simple shell scripts in `.git/hooks/pre-commit` execute checks synchronously. Common candidates: linting, formatting, a fast subset of unit tests, secret scanning, import sorting.

The key constraints:

- They run on the developer's machine, so they are environment-dependent.
- They can be bypassed with `git commit --no-verify`. This is not hypothetical — developers under time pressure will use it.
- They should complete in under 30 seconds. Anything slower, developers disable them.

**CI gates** run in a controlled environment on a dedicated runner. They are the authoritative enforcement point. A CI gate blocks the merge, not just the commit. It cannot be bypassed (unless a repo admin overrides it). It runs in a clean, reproducible environment, so "works on my machine" doesn't apply.

The right distribution:

- **Pre-commit:** format, lint, basic type-check. The goal is catching embarrassing errors before they hit the repo, not enforcing correctness.
- **CI gate:** full test suite (tiered), security scanning, build verification, coverage thresholds. The goal is enforcing team policy with certainty.

Putting slow tests in pre-commit is a mistake. Putting only fast linting in CI is a mistake in the other direction — linting in CI without pre-commit means every style error triggers a full pipeline run.

> [!tip] Pre-commit hooks are developer experience tooling; CI gates are quality enforcement. Design them for different audiences: pre-commit for developer speed, CI for team policy.

@feynman

Pre-commit hooks are like a spell-checker before you hit send — they catch obvious errors immediately, but you wouldn't trust a spell-checker alone to ensure your legal contract is correct; that's what the lawyer reviewing it afterward is for.

@card
id: est-ch10-c007
order: 7
title: Required vs Informational Checks
teaser: Not every CI check should block a merge — the distinction between required and informational checks is a deliberate policy decision that affects both developer velocity and signal quality.

@explanation

In GitHub Actions, branch protection rules designate specific status checks as required. A pull request cannot be merged until all required checks pass. GitLab CI has protected branches with similar merge blocking. Buildkite supports required steps that gate deployments.

**Required checks** block the merge. They represent non-negotiable team policy. Typical candidates:

- Unit and integration tests
- Build compilation (no broken build lands on main)
- Security scan (no critical vulnerability ships)
- Code coverage threshold (configured at a meaningful baseline)

**Informational checks** run and report but do not block. Their status is visible in the PR but a failure doesn't prevent merging. Typical candidates:

- Performance benchmarks (informative, not a hard gate)
- Experimental new linting rules being phased in
- Coverage trend reporting (showing that coverage went down, without blocking if it's a small regression)
- Dependency license scanning where a failure requires human judgment rather than automatic block

The discipline is in the classification decision. Making every check required creates friction: one flaky informational tool blocks all merges. Making everything informational means checks that matter are effectively ignored. The correct answer is intentional: each check exists in one category for an explicit reason, reviewed periodically.

> [!warning] Required checks that are frequently overridden (admin bypasses, workarounds) are a signal the policy is wrong, not that the developer is. Review required checks that generate bypass requests more than once a week.

@feynman

Required versus informational checks are like required courses versus electives in a degree program — some things are non-negotiable prerequisites for graduation, and others enrich your education but don't block you from moving forward.

@card
id: est-ch10-c008
order: 8
title: Caching for Test Speed
teaser: Dependency caches, build artifact caches, and test result caches each target different kinds of redundant work — and using the wrong cache strategy for a given bottleneck leaves significant time on the table.

@explanation

Three distinct layers of caching apply in CI pipelines, each targeting different expensive operations.

**Dependency caches** store package manager outputs (`node_modules`, pip virtual environments, Maven local repositories, Go module caches). GitHub Actions provides `actions/cache`; GitLab CI has the `cache:` key; CircleCI has `save_cache`/`restore_cache`. A cache hit on `node_modules` eliminates `npm install` entirely, often saving 2–5 minutes per job. Cache keys should be keyed on the lockfile hash — `package-lock.json`, `Pipfile.lock`, `go.sum` — so the cache is invalidated when dependencies change but reused when they don't.

**Build artifact caches** store compiled outputs (TypeScript transpilation, Webpack bundles, Go binaries, Docker layers). Turborepo's remote cache stores task outputs and replays them if inputs haven't changed. Nx Cloud works the same way — if the same source hash was already built by any machine in the organization, the output is restored instead of rebuilt. Bazel's remote cache is the most sophisticated version: actions are content-addressed by their input hash, and any action with a matching hash is served from cache.

**Test result caches** skip the execution of tests whose inputs (source files, test files, fixtures) haven't changed. Bazel treats test results as cacheable actions — a test that ran successfully against the same source hash doesn't need to run again. Nx and Turborepo apply the same principle at the task level.

The cost of remote caching is cache storage and egress. For most teams, this is negligible compared to the CI compute saved.

> [!info] Test result caching (not just build caching) is the most underused optimization. Running a test whose inputs haven't changed in three days is pure waste — the result is already known.

@feynman

CI caching is like saving your work-in-progress in a game — you don't replay every level from the start just because you want to try something at the end; you restore from the last checkpoint and continue from there.

@card
id: est-ch10-c009
order: 9
title: Coverage Tracking in CI
teaser: Coverage in CI is most useful as a trend signal and regression alert — the absolute number matters less than whether it's moving in the right direction and whether drops are intentional.

@explanation

Code coverage measured locally and discarded is not particularly useful. Coverage integrated into CI becomes an ongoing signal about test quality across the team over time.

**The mechanics:**

Most test frameworks generate coverage reports in standard formats: Istanbul/c8 for JavaScript (LCOV, JSON, Cobertura), coverage.py for Python (XML, HTML), JaCoCo for Java, llvm-cov for Swift and Rust. CI jobs upload these reports to a coverage tracking service — Codecov, Coveralls, or self-hosted alternatives — or publish them as CI artifacts.

**What's enforced vs what's tracked:**

A hard threshold (fail the build if coverage drops below 80%) is a blunt instrument. It prevents a catastrophic drop but doesn't distinguish between "added 500 lines of well-tested logic" and "added 500 lines of untested code." Trend tracking — surfacing whether coverage went up or down across a PR and alerting on drops larger than a configured delta — is more informative.

In GitHub Actions, Codecov and similar tools post a coverage report as a pull request comment showing which files lost coverage and by how much. This makes coverage visible at review time without necessarily blocking the merge.

**The limits of coverage:**

Coverage shows which lines were executed, not whether the assertions were meaningful. A test that calls a function but asserts nothing raises coverage without adding correctness signal. Teams that optimize for coverage numbers without scrutinizing test quality often end up with high coverage and poor confidence.

> [!tip] Alert on coverage regressions larger than 2–3% per PR rather than enforcing a hard floor. Drops that large almost always represent real untested additions, while small fluctuations from refactoring should not block work.

@feynman

Coverage tracking in CI is like monitoring your savings rate over time — the specific number on any given day matters less than whether the trend is healthy and whether any sudden drops represent a deliberate choice or an accident.

@card
id: est-ch10-c010
order: 10
title: Test Result Reporting and Dashboards
teaser: JUnit XML is the lingua franca of CI test reporting — and purpose-built analytics platforms built on top of it turn raw pass/fail data into actionable signals about suite health over time.

@explanation

Every major CI platform — GitHub Actions, GitLab CI, CircleCI, Buildkite — can consume JUnit XML test reports. Generating them requires one flag or configuration option in most test frameworks:

- pytest: `--junitxml=results.xml`
- Jest: `jest-junit` reporter
- Go: `gotestsum --junitfile results.xml`
- Gradle: built-in XML report

JUnit XML captures test name, duration, pass/fail status, and failure message. The CI platform renders this as a structured list of test results, failure messages, and timing data — far more useful than scrolling through raw log output.

**Purpose-built analytics platforms go further:**

**Buildkite Test Analytics** ingests JUnit XML (or a native SDK) and tracks per-test duration, failure rate, and flakiness score over time. It surfaces which specific tests are slowing the suite and which are unreliable.

**Datadog CI Visibility** does the same with additional context from the CI job (branch, author, pipeline stage) and integrates with Datadog's existing APM and log data, enabling correlation between CI failures and production incidents.

Both platforms maintain historical records of test behavior. A test that takes 8 seconds today but took 500 milliseconds six months ago is identifiable, whereas that regression is invisible from individual CI runs.

> [!info] Generating JUnit XML costs nothing — it is a flag on the test runner. Not generating it means all the historical insight that platforms like Buildkite Test Analytics or Datadog CI Visibility could provide is simply unavailable.

@feynman

A test analytics dashboard is like a flight data recorder for your test suite — a single crash tells you something went wrong, but the historical record tells you whether this was a surprise or the inevitable end of a long decline.

@card
id: est-ch10-c011
order: 11
title: Testing in Monorepos vs Polyrepos
teaser: Monorepos and polyrepos create opposite CI problems — monorepos must avoid running everything for every change, while polyrepos must coordinate cross-service testing that the structure makes difficult.

@explanation

**Monorepo CI challenges:**

A monorepo with 30 packages and 50,000 tests cannot run the full suite on every commit — the feedback loop becomes unusable. The solution is affected-package analysis: determine which packages a commit touched, traverse the dependency graph to find packages that depend on them, and run only the tests for that affected set.

Nx, Turborepo, and Bazel all provide this capability. Nx's `nx affected --target=test` computes the affected set from the git diff and the project dependency graph. Turborepo's `--filter=[HEAD^1]` syntax does the same. Bazel's `bazel test $(bazel query 'rdeps(//..., set(changed_targets))')` is more verbose but more powerful.

The risks: implicit dependencies that aren't declared in the build graph cause the affected set to be incomplete. A shared environment variable, a shared database schema, or a dynamic import that isn't in any dependency declaration can lead to tests not running when they should.

**Polyrepo CI challenges:**

Polyrepos have the opposite problem. Each service has its own CI pipeline, and testing a change that touches an API boundary requires coordinating across repositories — running the consumer's tests against a new version of the producer before merging. This is typically handled via contract testing (Pact or similar) or dedicated integration test repositories that pull specific versions of each service.

Cross-repo test orchestration is harder to automate and easier to neglect. The temptation in polyrepos is to declare integration testing "someone else's problem" until a contract break in production makes it everyone's problem.

> [!warning] Affected-package analysis in monorepos is only as good as the declared dependency graph. Implicit dependencies that bypass the build system silently defeat the entire strategy — they need to be surfaced and declared explicitly.

@feynman

Monorepo CI is like a smart grocery delivery service that figures out exactly which items need restocking based on what you actually cooked this week, rather than sending the full weekly order every single day.

@card
id: est-ch10-c012
order: 12
title: Pull Request Preview Environments
teaser: A preview environment spins up an ephemeral copy of the full application for each pull request, enabling tests to run against the real thing rather than a stub — at the cost of real infrastructure overhead.

@explanation

A preview environment is a short-lived deployment of the application — typically including frontend, backend, and a seeded database — created automatically when a pull request opens and torn down when it closes. Tests run against this environment rather than against mocks or containers.

**Why it matters:**

Integration tests that run against the real application stack catch categories of bugs that unit tests and container-based integration tests cannot. Configuration errors, environment variable mismatches, authentication flows that depend on real redirect URIs, and third-party integrations that behave differently in production all surface in preview environments.

**How it's set up in practice:**

GitHub Actions and GitLab CI can trigger a deployment workflow on `pull_request` events. Platforms like Vercel, Netlify, and Railway provide preview deployments out of the box for frontend applications. For full-stack applications, Kubernetes namespaces or separate Terraform workspaces provide isolated environments per PR. The environment URL is posted back to the pull request as a deployment status or a comment.

**The test-on-the-real-thing pattern:**

End-to-end tests in tools like Playwright or Cypress point at the preview environment URL and run against the deployed application. These tests validate user-facing flows end-to-end without hitting production data or a shared staging environment.

**The tradeoffs:**

Preview environments consume real infrastructure. A team with 20 open pull requests has 20 running environments. Cost and database seeding time are real constraints. Some teams use preview environments for frontend only (cheap) and rely on container-based integration tests for backend logic (fast to start).

> [!tip] Set an automatic teardown policy — preview environments should be destroyed when the PR is closed or when it has been idle for more than 24 hours. Open environments that no one is actively using are pure cost.

@feynman

A pull request preview environment is like a dress rehearsal for a theater production — you are performing the real show in the real theater with real costumes, not describing the show on a whiteboard, so any problem that only appears in performance will be caught before opening night.
