@chapter
id: cicdp-ch03-pipeline-topology
order: 3
title: Pipeline Topology
summary: Linear vs fan-out/fan-in, matrix builds, reusable workflows, monorepo affected-builds, and pipeline-of-pipelines — the structural choices that determine whether CI scales with the team or chokes it.

@card
id: cicdp-ch03-c001
order: 1
title: Linear vs Fan-Out Pipelines
teaser: A linear pipeline runs stages in strict sequence — build, then test, then deploy. A fan-out pipeline branches into parallel tracks at some point, trading simplicity for speed.

@explanation

The simplest possible CI pipeline is linear: each stage waits for the previous one to finish before starting. Source pushes trigger a build; the build artifact feeds unit tests; passing tests unlock a staging deploy. The dependency chain is explicit and the failure surface is easy to reason about.

Linear pipelines break down when individual stages take long enough to make the total wall-clock time unacceptable. If a build takes 3 minutes, unit tests take 4 minutes, integration tests take 10 minutes, and linting takes 2 minutes — running them sequentially costs 19 minutes per push. Most teams hit this ceiling somewhere between 50 and 200 engineers.

Fan-out pipelines split execution into independent parallel tracks after a common entry point. A typical pattern:

- Stage 1 (sequential): compile / build — produces the artifact or compiled binary that everything else needs.
- Stage 2 (fan-out): unit tests, linting, SAST scanning, and dependency auditing all run in parallel against the build output.
- Stage 3 (fan-in): all parallel tracks must succeed before the pipeline proceeds to integration testing or deployment.

In GitHub Actions, fan-out is expressed through **job-level parallelism**. Jobs within a workflow that share no `needs:` dependency run concurrently on separate runners. Defining `needs: [build]` on multiple jobs creates a fan-out from the build job.

GitLab CI uses `stages` for sequencing and jobs within a stage for parallelism. All jobs in a stage run concurrently; the next stage starts only when all jobs in the current stage pass. This maps directly to the fan-out model, though with less flexibility than the GitHub Actions dependency graph.

> [!tip] Fan-out is only worthwhile when the parallelized stages are genuinely independent. If your linter and your unit tests share a setup step that takes longer than the lint itself, the overhead of parallelism may erase the savings.

@feynman

A linear pipeline does one thing at a time, like a single cashier; a fan-out pipeline opens multiple checkout lanes simultaneously so you're not waiting for the slowest item.

@card
id: cicdp-ch03-c002
order: 2
title: Fan-In and Convergence Points
teaser: A fan-in is the convergence point where multiple parallel tracks must all succeed before the pipeline can continue — it is the gating mechanism that makes fan-out safe.

@explanation

Fan-in is the inverse of fan-out. After multiple independent jobs or stages have run in parallel, the pipeline waits for all of them to complete successfully before proceeding. The convergence point is where the pipeline reasserts a global quality gate: nothing moves forward unless everything passed.

In GitHub Actions, a fan-in is expressed by listing multiple jobs in a single job's `needs:` array:

- `jobs.deploy.needs: [unit-tests, lint, security-scan]` — the deploy job will not start until all three named jobs have succeeded.
- If any of the named jobs fails, the deploy job is skipped and the workflow fails at the fan-in point.

Fan-in convergence points have two design concerns:

- **Artifact handoff.** Parallel jobs often produce outputs that the convergence job needs. GitHub Actions uses `upload-artifact` and `download-artifact` actions; GitLab CI uses `artifacts:` with `dependencies:` to pull results forward. If artifacts are not explicitly passed, the convergence job sees only what was in the original workspace.
- **Failure visibility.** When multiple parallel jobs fail simultaneously, the developer sees all failures at once rather than discovering them one at a time. This is a user-experience advantage of fan-out/fan-in over strict linear pipelines: you batch the feedback.

The wall-clock time of the fan-out/fan-in structure is determined by the **slowest parallel track**, not the sum of all tracks. If unit tests take 5 minutes and security scanning takes 8 minutes, the convergence point is reached at 8 minutes regardless of how fast the other tracks are. Identifying and optimizing the critical path is the key to reducing total pipeline time.

> [!warning] Fan-in creates a mandatory wait on the slowest job. If one parallel track is consistently slower than all others, splitting it into further parallel sub-tasks or deferring it to a post-merge pipeline may reduce perceived latency without sacrificing quality gates.

@feynman

Fan-in is the point where all parallel lanes must merge before the car can continue — if any lane is blocked, the whole convoy waits.

@card
id: cicdp-ch03-c003
order: 3
title: Matrix Builds
teaser: A matrix build runs the same job across a grid of variable combinations — language versions, OS targets, dependency variants — without duplicating job definitions.

@explanation

Matrix builds address the testing-across-variants problem. A library that supports Python 3.9, 3.10, 3.11, and 3.12 on Linux and macOS needs to be tested in eight configurations. Writing eight separate job definitions is both verbose and fragile — any change to the job logic must be replicated in all eight.

GitHub Actions provides a first-class `strategy.matrix` construct. A minimal example:

- `strategy.matrix.python-version: ["3.9", "3.10", "3.11", "3.12"]`
- `strategy.matrix.os: [ubuntu-latest, macos-latest]`
- GitHub Actions creates 4 × 2 = 8 job instances automatically, running all of them in parallel (subject to runner availability).

Matrix builds support three important modifiers:

- `include:` adds specific combinations not generated by the base matrix, or injects extra variables into a specific cell.
- `exclude:` removes specific combinations from the generated grid (e.g., Python 3.9 on macOS is not tested).
- `fail-fast:` when set to `false`, all matrix jobs run to completion even if one fails — useful for getting a full picture of which combinations are broken. The default `true` cancels remaining jobs on the first failure.

GitLab CI achieves similar behavior with `parallel:matrix:` syntax, introduced in GitLab 13.3. CircleCI uses a `matrix` key inside a `job` definition under its pipeline config. The concept is universal; the YAML syntax differs.

Matrix builds become expensive quickly. A 4 × 3 × 2 matrix produces 24 jobs per push. At meaningful scale, teams often restrict full matrix runs to main branch merges and run only a representative subset on pull requests — for example, only the latest stable language version on Linux — to limit runner cost and feedback latency.

> [!info] Dynamic matrix generation — computing the matrix values from a prior step's output — is possible in GitHub Actions using the fromJSON() expression and an outputs: variable. This lets you build the variant list from a script rather than hard-coding it in YAML.

@feynman

A matrix build is a spreadsheet run as CI: define the rows (Python versions) and columns (OS targets), and the system runs a job in every cell simultaneously.

@card
id: cicdp-ch03-c004
order: 4
title: Reusable Workflows
teaser: Reusable workflows let you define a pipeline once and call it from multiple repositories or jobs — the DRY principle applied to CI configuration.

@explanation

As organizations grow past a handful of repositories, CI configuration drift becomes a real operational problem. Each repo develops its own slightly different pipeline for building, testing, and releasing software. When a security scanning step needs to be added to all pipelines, or a linter version needs to be bumped, the change must be replicated across every repository manually.

Reusable workflows solve this by centralizing pipeline logic in a shared repository and allowing consuming repos to call those workflows by reference. In GitHub Actions:

- A workflow file in a shared repo declares `on: workflow_call:` and defines input parameters and secrets it accepts.
- Consuming repos call it with `uses: org/shared-workflows/.github/workflows/build.yml@main` and pass in the required inputs.
- The called workflow runs as if it were defined locally, but the logic lives in one place. Updating it in the shared repo propagates to all callers on the next run.

GitLab CI has an equivalent mechanism called `include:` with `project:` and `ref:` — pipelines can include job definitions from another project in the same GitLab instance. CI/CD component catalogs, introduced in GitLab 16.x, extend this further with versioned, publishable pipeline components.

Design considerations for reusable workflows:

- **Versioning.** Callers that pin to `@main` will receive breaking changes automatically. Pinning to a tag (e.g., `@v2.1.0`) gives consuming teams control over when they upgrade.
- **Secret propagation.** Secrets must be explicitly passed to called workflows using `secrets: inherit` (GitHub) or declared in the input signature. Callers cannot implicitly share their secrets with called workflows.
- **Composability limits.** GitHub Actions does not currently support deeply nested reusable workflow calls (called workflows cannot call other reusable workflows beyond one level). Design the shared library with this constraint in mind.

> [!tip] Treat your shared workflow repository like a versioned library: changelog, semantic versioning, and a migration guide for breaking changes. Teams that rely on your workflows have their own pipelines at stake.

@feynman

A reusable workflow is a shared function for CI: write the pipeline logic once, call it from a hundred repositories, and fix bugs or add steps in a single place.

@card
id: cicdp-ch03-c005
order: 5
title: Pipeline-of-Pipelines
teaser: A pipeline-of-pipelines coordinates multiple downstream pipelines from a single orchestrating pipeline — the pattern for multi-service releases, environment promotion chains, and cross-team coordination.

@explanation

Pipeline-of-pipelines is a structural pattern where one pipeline triggers and waits on other pipelines rather than executing all logic itself. It is the CI equivalent of orchestration: a top-level coordinator that manages the sequencing and success conditions across independent downstream flows.

Common use cases:

- **Multi-service release coordination.** A release pipeline triggers builds of service A, service B, and service C. It waits for all three to pass their tests before proceeding to a coordinated deployment that requires all three to be deployed together.
- **Environment promotion chains.** A staging pipeline triggers after dev passes; a production pipeline triggers after staging passes and a human approval gate is cleared. Each environment has its own pipeline; the orchestrator manages the hand-offs.
- **Cross-team dependencies.** Team A's pipeline triggers Team B's integration test pipeline when a new API version is published. The orchestrating pipeline captures cross-team compatibility.

In GitHub Actions, pipeline-of-pipelines is achieved via `repository_dispatch` events or `workflow_dispatch` combined with the GitHub API. The orchestrating workflow posts a `repository_dispatch` event to a downstream repo, which has a workflow listening for that event type. Polling or webhook callbacks are needed to propagate success status back to the orchestrator.

GitLab CI supports pipeline-of-pipelines natively through `trigger:` jobs. A job with `trigger: project:` creates a child pipeline in another project and the parent pipeline can wait for it with `strategy: depend`. This is among the cleanest native implementations of the pattern.

The failure mode: pipeline-of-pipelines can obscure failure provenance. When a downstream pipeline fails, the upstream orchestrator shows a vague failure. Good observability — clear links from the orchestrator to downstream pipeline runs and centralized failure summaries — is essential to making the pattern operational.

> [!warning] Pipeline-of-pipelines adds coordination overhead. If a single team owns all services in the dependency graph, a monorepo with a single well-structured pipeline is often simpler and faster than orchestrating across repositories.

@feynman

A pipeline-of-pipelines is a project manager for CI: it kicks off other pipelines, waits for them to finish, and decides whether the overall release is a go based on all their results.

@card
id: cicdp-ch03-c006
order: 6
title: Build Runners and Executors
teaser: A build runner is the agent that executes pipeline jobs — it is the compute substrate beneath your CI logic, and its configuration determines what your jobs can do, how fast they run, and how much they cost.

@explanation

Every CI job runs somewhere: a virtual machine, a container, a serverless sandbox, or a bare-metal host. That runtime environment is provided by a **runner** (GitHub Actions, GitLab), **executor** (GitLab, CircleCI), or **agent** (Jenkins, Buildkite). The terminology varies, but the concept is the same.

Runner types by isolation level:

- **Container runners** — each job runs in a fresh container. Fast startup, strong isolation between jobs, no shared state. The dominant model for most cloud CI. Docker-in-Docker (DinD) is needed to build container images from within a container job.
- **VM runners** — each job gets a fresh virtual machine. Higher isolation than containers, slower startup (30–90 seconds vs 1–5 seconds). GitHub-hosted runners use this model; macOS jobs in GitHub Actions run on ephemeral VMs.
- **Process runners** — jobs run as processes on a shared host. Fastest startup, lowest cost, but jobs share the host's filesystem, network, and processes. Suitable for trusted, isolated workloads; risky for multi-tenant environments.
- **Kubernetes runners** — jobs run as Kubernetes pods. The GitLab Kubernetes executor and Actions Runner Controller (ARC) for GitHub Actions support this model. Enables dynamic scaling and resource requests per job.

Runner capacity directly constrains pipeline throughput. If 40 developers push simultaneously and each push triggers a 3-job workflow, 120 concurrent runner slots are needed to provide zero-queue experience. Most organizations run with a queue; the question is how long the queue gets at peak.

Runner configuration also determines available hardware: available memory, CPU count, GPU access, and the host operating system. Jobs that need Docker buildx for multi-architecture image builds, or that require macOS for iOS compilation, have specific runner requirements that must be planned ahead.

> [!info] Runner warm-up time (container pull, VM boot) is often invisible in job logs because the timer starts after the runner is ready. Measure total time from git push to first log line to capture the true developer experience.

@feynman

A build runner is the computer your CI job actually runs on — your YAML defines what to do, but the runner is where it happens, and its speed and availability determine how long you wait.

@card
id: cicdp-ch03-c007
order: 7
title: Self-Hosted vs Managed Runners
teaser: Managed runners are provisioned and maintained by the CI provider; self-hosted runners are machines you control — the tradeoff is operational burden against cost, customization, and network access.

@explanation

Managed runners (GitHub-hosted, GitLab SaaS shared runners, CircleCI cloud) are the zero-ops choice. You define your workflow; the platform provisions a fresh machine, runs your job, and destroys the instance. No infrastructure to maintain, no capacity planning, no OS patching.

Managed runners have predictable limitations:

- **Fixed hardware.** GitHub-hosted runners offer 2-core, 7 GB RAM (standard), 4-core, 16 GB (larger runners, additional cost), or GPU instances — but not arbitrary configurations.
- **No private network access.** Managed runners cannot reach internal services (artifact registries, private databases, on-premise systems) without a VPN or a network tunnel like Tailscale or Cloudflare Access.
- **Cost at scale.** GitHub Actions charges per minute of runner time above the free tier. At significant build volume, managed runner costs can exceed the cost of self-hosted infrastructure.

Self-hosted runners address all three constraints. You bring your own hardware or cloud instances, register them with the CI provider, and jobs route to them. Common self-hosted patterns:

- **Static self-hosted runners** — always-on VMs or bare-metal machines registered with the CI provider. Simple to set up, but idle when no jobs run and may become over-subscribed at peak.
- **Ephemeral self-hosted runners** — runners are created on demand (from an autoscaling group, Kubernetes deployment via ARC, or a Lambda/Cloud Run bootstrap) and destroyed after one job. Eliminates shared state between jobs and scales to demand.
- **On-premise runners** — physical machines in a data center or lab. Required for hardware-in-the-loop testing, air-gapped environments, or compliance contexts where build artifacts cannot leave the corporate network.

> [!warning] Self-hosted runners in GitHub Actions must be treated as security-critical infrastructure. A malicious pull request can execute arbitrary code on a self-hosted runner. Never use self-hosted runners for public repositories or for repositories that accept external pull requests without careful review.

@feynman

Managed runners are like renting a car — ready instantly, no maintenance, but limited to what the rental company offers; self-hosted runners are your own car — full control, but you handle insurance, fuel, and repairs.

@card
id: cicdp-ch03-c008
order: 8
title: Parallel Execution and Test Sharding
teaser: Test sharding splits a single large test suite across multiple runners running simultaneously — the fastest single-machine run time is irrelevant if you can run ten machines in parallel.

@explanation

A test suite that takes 30 minutes on one runner takes roughly 3 minutes if split evenly across 10 runners running in parallel. This is the core promise of test sharding: converting wall-clock time into a function of runner count rather than test count.

The mechanics of sharding require two things:

- **A way to partition the test suite.** Test files can be divided alphabetically, by file count, by historical runtime (weighted partitioning), or by module/directory boundaries. Weighted partitioning — assigning more tests to faster runners — produces the most balanced shards.
- **A way to communicate the shard index to each runner.** In GitHub Actions, matrix builds provide this naturally: `strategy.matrix.shard: [1, 2, 3, 4]` combined with `strategy.matrix.total-shards: 4` gives each job instance its position in the shard set.

Popular test runners support native sharding:

- **pytest** with `pytest-split` splits tests by duration history: `pytest --splits 4 --group 1` runs the first of four balanced groups.
- **Jest** accepts `--shard=1/4` natively since v28.
- **RSpec** uses `parallel_tests` or `rspec --format ...` with custom shard scripts.
- **Bazel** distributes test execution across a remote build cluster via Remote Build Execution (RBE), effectively sharding by build graph topology without manual shard configuration.

Platforms like Buildkite Test Analytics, Launchable, and BuildPulse offer intelligent test splitting that learns from historical timing data and predicts which tests are most likely to fail — prioritizing those in the earliest shard to surface failures faster.

> [!tip] Sharding does not help if the shard setup time dominates. If spinning up a shard requires 4 minutes of dependency installation and the tests run for 2 minutes, adding more shards makes the pipeline slower, not faster. Cache aggressively and measure setup time separately from test time.

@feynman

Test sharding is like splitting a long book report among ten students: each reads one chapter, and the whole class finishes in a tenth of the time — as long as everyone gets an equal share of pages.

@card
id: cicdp-ch03-c009
order: 9
title: Affected Builds in Monorepos
teaser: Affected build systems run only the pipelines for code that has changed — skipping the entire test suite for packages untouched by a given commit, turning O(repository) CI cost into O(change scope) CI cost.

@explanation

In a monorepo hosting 50 packages, a change to `packages/utils` should not require rebuilding and testing all 49 other packages. Naively running the full test suite on every push makes CI time proportional to repository size, not change size — a growth curve that makes CI unusable at scale.

Affected build systems solve this by computing a dependency graph and determining, for a given set of changed files, which packages are **affected** — directly changed or downstream of a change. Only affected packages are rebuilt and retested.

The major tools:

- **Nx** — the dominant affected-build tool in the JavaScript/TypeScript ecosystem. `nx affected --target=test` computes the affected project graph from the base commit (e.g., `origin/main`) and runs tests only on affected projects. Nx Cloud extends this with distributed task execution and remote caching.
- **Turborepo** — a build system from Vercel with similar affected-build semantics. Uses a hash-based caching model: tasks whose inputs have not changed are replayed from cache rather than re-executed.
- **Bazel** — a build system from Google that enforces hermetic, deterministic builds. Bazel computes a fine-grained dependency graph at the file level. `bazel query 'rdeps(//..., set(changed_targets))'` returns the reverse dependencies of changed targets. Remote Build Execution distributes those builds across a cluster.
- **Gradle with build caching** — in Java/Kotlin monorepos, Gradle's incremental build and build cache avoid re-executing tasks whose inputs have not changed.

The dependency graph must be accurate for affected builds to be safe. If a package has an undeclared dependency — it imports code from a sibling package without declaring it in the build manifest — the affected system may miss it and allow a broken build to pass. Enforced package boundaries (Nx module boundaries, Bazel's visibility rules) prevent undeclared dependencies from forming.

> [!warning] Affected builds on pull request branches can be misleading if the base comparison is wrong. Always compute affected changes against the merge base (git merge-base HEAD origin/main), not the tip of main — otherwise changes that landed on main after your branch diverged will be incorrectly flagged as part of your PR's change set.

@feynman

Affected builds are like a smart fire suppression system: instead of flooding the whole building when smoke is detected in one room, it activates only the sprinklers in rooms connected to that room.

@card
id: cicdp-ch03-c010
order: 10
title: Build Sharding for Massive Repos
teaser: Build sharding distributes the compilation and test execution of a large codebase across a cluster of machines — the technique that lets Google, Meta, and Uber build repositories with millions of files in minutes.

@explanation

At a certain scale, even affected builds produce too much work for a single machine. A repository with 10,000 packages where a shared library change triggers 2,000 affected tests still needs distribution to run in an acceptable time window. Build sharding at this scale means distributing compilation and test execution across a fleet of machines that share a remote build cache.

The enabling architecture is a **content-addressable remote cache**. Each build action is keyed by a hash of its inputs (source files, compiler flags, environment). If the cache contains a result for those inputs, the action is a cache hit — the output is downloaded rather than recomputed. This is independent of which machine executes the action.

Tools and platforms:

- **Bazel with Remote Build Execution (RBE)** — the reference implementation. Bazel's build graph is submitted to an RBE-compatible backend (EngFlow, BuildBuddy, Google Cloud RBE). Actions are executed in parallel across workers; outputs are stored in the remote cache for future builds.
- **Nx Cloud** — provides distributed task execution (DTE) for Nx projects. Tasks are distributed across agents and results are pulled from Nx Cloud's remote cache. No Bazel knowledge required.
- **Gradle Build Cache** — Gradle Enterprise (now Develocity) provides a shared remote build cache for Java/Kotlin projects. Combined with configuration cache and parallel execution, build times scale sublinearly with change scope.
- **Turborepo with remote caching** — Vercel provides a remote cache for Turborepo; self-hosted alternatives exist via the Turborepo remote cache API spec.

The key metric for build sharding effectiveness is **cache hit rate**. A 90% cache hit rate means 90% of build actions are skipped. Cache hit rate drops when build actions are not hermetic — when they depend on external state (current time, network calls, non-deterministic compilers) that makes the output different even for identical inputs.

> [!info] Hermeticity is the prerequisite for effective build caching. A build that reads from the network, depends on the system clock, or shells out to non-versioned binaries will never achieve high cache hit rates — the inputs are different on every run even for unchanged code.

@feynman

Build sharding for massive repos is like a distributed kitchen: instead of one chef cooking all 2,000 dishes, hundreds of chefs work in parallel and each dish that was already cooked today is served directly from the fridge without re-cooking it.

@card
id: cicdp-ch03-c011
order: 11
title: Pipeline Visualization and Observability
teaser: Pipeline visualization makes the structure and status of builds legible to humans; pipeline observability makes failure patterns legible to systems — both are necessary for operating CI at scale.

@explanation

A pipeline that is hard to read is a pipeline that will be hard to debug. As pipeline topology grows more complex — fan-outs, matrix builds, child pipelines, dependent jobs — the default log view becomes inadequate. Developers need a structural view of what ran, what passed, what failed, and why.

Pipeline visualization approaches:

- **DAG views.** GitLab CI renders pipelines as directed acyclic graphs in its UI, showing job dependencies visually. GitHub Actions shows a job dependency graph with status indicators per job. These views make fan-out/fan-in topology immediately readable.
- **Timeline views.** Buildkite renders a Gantt-style timeline showing when each job started, how long it ran, and where queue time was spent. This view reveals the critical path and identifies which jobs are contributing most to total wall-clock time.
- **Failure summary views.** GitHub Actions and GitLab CI both aggregate failed steps to the top of the job summary, reducing the time spent scrolling through thousands of lines of log output to find the error.

Pipeline observability — the systemic view — requires data beyond individual runs:

- **Build duration trends.** Tracking p50, p95, and p99 build duration over time reveals regressions: a new dependency or test added to the critical path shows up as a step change in the trend.
- **Flake rate.** Tests that fail non-deterministically (flaky tests) inflate pipeline failure rates and erode developer trust in CI. Tracking which tests fail intermittently — and at what rate — enables targeted remediation.
- **Queue time.** The time between job queuing and job start is often the most actionable metric for improving developer experience. Rising queue time signals runner capacity is inadequate for demand.

Tools like Datadog CI Visibility, Buildkite Test Analytics, and Gradle Develocity provide purpose-built pipeline observability dashboards. Alternatively, OpenTelemetry traces can be emitted from CI scripts and ingested into any compatible backend.

> [!tip] Pipeline observability pays the highest dividend when it is automatic — when every run emits structured data without developer action. Opt-in instrumentation produces sparse, biased data; always-on telemetry produces the trends needed for capacity planning and regression detection.

@feynman

Pipeline visualization shows you what broke in this run; pipeline observability shows you that your builds have been getting 30% slower every month — one is a debugger, the other is a health monitor.

@card
id: cicdp-ch03-c012
order: 12
title: Designing for Scale: When Topology Breaks
teaser: Pipeline topology that works at 10 engineers often collapses at 100 — the structural failure modes are predictable and the redesign decisions are architectural, not just configurational.

@explanation

Pipeline topology problems rarely announce themselves as architecture problems. They show up as slow builds, flaky tests, long queues, and frustrated developers. By the time the organization recognizes the problem as structural, the pain has often been accumulating for months.

The most common structural failure modes at scale:

- **The monolithic pipeline.** A single, sequential pipeline that started as a 3-step workflow and grew to 40 steps over two years. Every push runs every step. Build time is the sum of all steps with no parallelism. Fix: identify independent steps and restructure as a fan-out graph.
- **The shared slow test suite.** All services in a monorepo share a single test run that takes 45 minutes, regardless of which service changed. Fix: introduce affected builds (Nx, Turborepo) and shard the remaining test execution.
- **Runner starvation.** Peak build volume exceeds runner capacity; jobs queue for 10–20 minutes. Fix: autoscale self-hosted runners or upgrade to a larger managed runner tier; measure and set capacity targets based on p95 queue time.
- **Configuration drift.** 30 repositories have 30 different pipeline configurations with no shared standards. Adding a required security scan means editing 30 files. Fix: introduce reusable workflows with organizational standards encoded in the shared library.
- **Opaque pipeline-of-pipelines.** Cross-service release pipelines fail but the failure is attributed to the wrong service because downstream pipeline results are not surfaced in the orchestrator. Fix: enforce structured failure reporting and link downstream pipeline runs from the orchestrating pipeline UI.

The design principle that guides topology decisions at scale: **CI cost should scale with change scope, not repository size**. A developer changing one file in one package should not wait for 10,000 tests to run. Every topology decision — fan-out, sharding, affected builds, caching — is in service of this principle.

The organizational prerequisite for scaling pipeline topology is ownership clarity. Pipelines that "belong to everyone" belong to no one. Assigning a platform team or CI team ownership of shared pipeline infrastructure — with an SLO on build time and queue time — creates the accountability needed to sustain improvements over time.

> [!info] The inflection point where topology redesign becomes urgent is usually when median build time exceeds 15 minutes for a pull request workflow. Above that threshold, developers stop running CI locally, stop waiting for results before context-switching, and start batching changes — all of which reduce the feedback loop that CI was designed to provide.

@feynman

When your pipeline was designed for 10 engineers and you now have 100, it is not slow because of bad luck — it is slow because the topology was never designed to distribute work, skip unchanged code, or scale runners to demand. Those are architectural choices, not tuning parameters.
