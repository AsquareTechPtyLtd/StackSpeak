@chapter
id: cicdp-ch01-why-pipelines-are-design
order: 1
title: Why Pipelines Are Design, Not Tooling
summary: Most teams' pipelines are accidental architectures glued together from defaults — but a pipeline is a system with four jobs (build, verify, secure, deploy), and treating it as a design problem is the difference between shipping safely and shipping luckily.

@card
id: cicdp-ch01-c001
order: 1
title: The Four Jobs of a Pipeline
teaser: Every CI/CD pipeline — regardless of the tool, the team, or the tech stack — does exactly four things: it builds software, verifies it, secures it, and delivers it. Everything else is implementation detail.

@explanation

Strip away GitHub Actions YAML, GitLab stages, and Jenkins Groovy scripts and you are left with a universal shape. A pipeline is a machine with four jobs to do, in roughly this order:

- **Build** — compile source code, resolve dependencies, and produce an artifact: a binary, a container image, a JAR, a Lambda ZIP. Build is the entry point. Everything downstream depends on its output.
- **Verify** — validate that the artifact does what it is supposed to do. Unit tests, integration tests, contract tests, end-to-end tests, static analysis, and linting all live here. Verification answers: "Does this code do what we intended?"
- **Secure** — scan for vulnerabilities, check for secrets committed to source, validate software bill of materials (SBOM), enforce license policies, and run SAST/DAST tooling. Security answers: "Is this artifact safe to ship?"
- **Deploy** — move the verified, secured artifact into a target environment. Staging, canary, production. Deploy answers: "Did the artifact land correctly?"

These four jobs map directly to the four stages of the deployment pipeline described by Jez Humble and David Farley in *Continuous Delivery* (2010): commit stage, automated acceptance tests, UAT and capacity testing, and release. The names have evolved; the underlying shape has not.

When you understand a pipeline through these four jobs, every design question becomes clearer. Where does a new test belong? In verify. Where does image signing go? In secure. Where does feature flag rollout logic live? In deploy. Without the four-job mental model, teams drop responsibilities into random stages and the pipeline becomes a script pile.

> [!info] The DORA research program (Accelerate: The Science of Lean Software and DevOps, Forsgren et al., 2018) identifies deployment frequency and lead time for changes as the two most predictive delivery performance metrics. Both are pipeline properties, not team properties.

@feynman

A pipeline has four jobs: build the thing, check the thing works, check the thing is safe, and put the thing where it belongs. Every stage you add fits into one of those four buckets.

@card
id: cicdp-ch01-c002
order: 2
title: The Accidental Architecture Problem
teaser: Most pipelines were not designed — they accumulated. A shell script that ran locally became a CI job; that job grew children; nobody owns the result. Accidental pipelines are the industry's most widely ignored technical debt.

@explanation

The typical pipeline origin story goes like this: a developer needs to run tests before merging. They add a GitHub Actions workflow with a single job. A colleague adds a Docker build. Someone attaches a deployment step targeting staging. Eighteen months later the pipeline has 40 steps, three different shell scripting styles, an undocumented dependency on a specific runner image version, and nobody knows why step 23 only runs on Tuesdays.

This is accidental architecture — a system whose structure is the residue of individual decisions made in isolation rather than the expression of an intentional design. Stewart Brand's concept of shearing layers applies: fast-moving application code was layered onto slow-moving pipeline infrastructure that nobody maintained as infrastructure.

The symptoms of an accidental pipeline:

- No one can explain, end to end, what the pipeline does without reading the YAML. There is no diagram, no documentation, no design document.
- Stages run in sequence because nobody thought about parallelism, not because sequencing was required.
- Flaky tests are commented out rather than fixed, because "the pipeline needs to stay green."
- Security scanning was added in month 18, bolted to the end, and frequently skipped in "emergency" deploys.
- The pipeline runs for 45 minutes. Nobody knows why. Nobody has profiled it.

Accidental pipelines are dangerous not because they are messy but because they are *opaque*. When something goes wrong — a vulnerability slips through, a bad deploy reaches production — the team cannot confidently answer whether the pipeline should have caught it. The pipeline has no stated contract to violate.

> [!warning] A pipeline with no design has no definition of correctness. You cannot tell whether it is working as intended, because "as intended" was never specified.

@feynman

An accidental pipeline grew by addition rather than design — it does something, but nobody can fully explain what or why, which makes it impossible to fix or trust.

@card
id: cicdp-ch01-c003
order: 3
title: Continuous Integration as the First Discipline
teaser: Continuous Integration is not a tool or a platform — it is a practice: integrate code into a shared branch frequently enough that integration problems surface in minutes, not days. The CI pipeline is the machine that enforces the practice.

@explanation

The term **Continuous Integration** was coined by Kent Beck as part of Extreme Programming (XP) in the late 1990s and formalized by Martin Fowler in his 2000 article "Continuous Integration." The core practice: every developer integrates their changes to a shared mainline at least once per day, and each integration is verified by an automated build.

CI exists to solve the integration problem. Before CI, teams worked on feature branches for days or weeks. When they merged, they discovered conflicts — not just in code, but in behavior, in contracts, in assumptions. These "integration hell" episodes could take longer to resolve than the features took to build.

The CI discipline requires:

- A single shared mainline branch that represents the truth about the system.
- Every commit to mainline triggers an automated build and test suite.
- The build must complete quickly — Fowler's original rule of thumb was under 10 minutes. A build that takes an hour will not be run frequently enough to provide CI's benefits.
- A broken build is the team's highest priority. It blocks further integration until fixed.
- Developers do not commit to a broken build. This is a social contract, not just a technical one.

The CI **pipeline** is the technical implementation of CI. It is the automated system that runs the build and tests on every commit. GitHub Actions, GitLab CI, Jenkins, and CircleCI are all tools for implementing this automation — they are not themselves CI. A team can use GitHub Actions and still not practice CI if branches live for three weeks without integrating.

> [!info] Fowler's original CI article (martinfowler.com/articles/continuousIntegration.html) remains the canonical reference. Most teams who believe they practice CI are practicing "automated testing on pull requests," which is not the same thing.

@feynman

Continuous Integration means every developer merges their work into the shared codebase at least once a day, and every merge automatically runs the tests. The pipeline is the machine that makes that automatic part happen.

@card
id: cicdp-ch01-c004
order: 4
title: The Pipeline as a System
teaser: A pipeline is not a sequence of commands — it is a system with inputs, outputs, feedback loops, failure modes, and emergent behaviors. Treating it as a system is what separates pipeline design from pipeline configuration.

@explanation

Systems thinking, as described by Donella Meadows in *Thinking in Systems* (2008), characterizes a system by its stocks, flows, and feedback loops. A pipeline has all three.

- **Stocks** — queued commits waiting to run, in-progress builds, cached artifacts, test results stored in the reporting system.
- **Flows** — code flowing from commit through build, test, and deploy into production. Feedback flowing from test failures back to developers. Security findings flowing to the security backlog.
- **Feedback loops** — a failing test must reach the developer who broke it quickly enough that the context is still fresh. A feedback loop longer than 10 minutes degrades to noise; developers context-switch away and the signal arrives cold.

Viewing the pipeline as a system surfaces design questions that are invisible when you treat it as a script:

- What is the pipeline's throughput? How many commits per hour can it process before queuing?
- Where is the bottleneck? Which stage accounts for the most wall-clock time?
- What happens under load? If 20 developers merge simultaneously, does the system degrade gracefully or collapse?
- What are the failure modes? If the artifact registry is unavailable, which stages can still run? Which must halt?
- What are the emergent behaviors? Does caching the build layer cause stale dependencies to survive security patches?

The pipeline is also a *sociotechnical system*: its effectiveness depends on the social contracts the team maintains around it (green main, no skipping, break-the-build authority) as much as on its technical configuration.

@feynman

A pipeline is a system the way a production line is a system — it has inputs, outputs, a throughput limit, and failure modes. Understanding those properties lets you design it instead of just configure it.

@card
id: cicdp-ch01-c005
order: 5
title: Stages, Jobs, and Triggers
teaser: Stage, job, and trigger are the three structural primitives every CI/CD tool provides — understanding precisely what they mean (and how they differ across tools) is the prerequisite for designing pipelines that behave predictably.

@explanation

Every major CI/CD tool — GitHub Actions, GitLab CI/CD, Jenkins, CircleCI — organizes work around the same three concepts, though the naming varies:

- **Stage** — a named phase of the pipeline. Stages execute in sequence; jobs within a stage may execute in parallel. In GitLab CI, stages are declared explicitly (`stages: [build, test, deploy]`). In GitHub Actions, stages are modeled as jobs linked by `needs:` dependencies. The concept is the same; the surface differs.
- **Job** — the atomic unit of execution. A job runs on a single runner or agent, in an isolated environment. It has a defined environment, a set of steps, and a pass/fail result. Jobs within a stage can run in parallel across multiple runners.
- **Trigger** — the event that starts a pipeline run. A push to main, a pull request opened, a tag created, a schedule (cron), a manual dispatch, or an API call. The trigger shapes the pipeline's intent: a PR trigger runs verification; a tag trigger runs release.

Good pipeline design uses triggers deliberately. A common pattern:

- **Pull request trigger** — run build + verify. Fast feedback before merge. Do not deploy.
- **Push to main trigger** — run build + verify + secure + deploy to staging. The integration signal.
- **Tag trigger** — run the full pipeline including production deploy. Release signal, often with a manual approval gate.
- **Schedule trigger** — run security scans and dependency checks nightly, when they are too slow for the PR path.

When triggers are not designed deliberately, pipelines run the same set of stages for every event — wasting compute, slowing feedback, and obscuring which signals matter. A 20-minute security scan on every pull request commit is noise; the same scan on every merge to main is signal.

@feynman

A stage groups related work into a named phase; a job is the actual unit of work that runs on a machine; a trigger is the event that decides which pipeline to start and when.

@card
id: cicdp-ch01-c006
order: 6
title: Continuous Delivery vs Continuous Deployment
teaser: Continuous Delivery and Continuous Deployment are not synonyms — the distinction is a single gate: in Delivery, a human decides when to release; in Deployment, the pipeline decides. Choosing between them is a product and risk decision, not a technical one.

@explanation

Jez Humble and David Farley defined both terms precisely in *Continuous Delivery* (2010):

- **Continuous Delivery** — every commit that passes the pipeline is in a releasable state. The software *can* be deployed to production at any time, but the decision to do so remains with a human. The pipeline produces a deployable artifact on every successful build.
- **Continuous Deployment** — every commit that passes the pipeline *is* deployed to production automatically. No human approval between green build and live traffic.

Continuous Deployment is a strictly stronger practice. It requires extremely high confidence in the automated test suite and rollback mechanisms — if 5% of builds introduce production issues, fully automated deployment means 5% of releases are broken before anyone can intervene.

The choice between them depends on:

- **Test suite confidence.** Can you catch regressions reliably in CI? If test coverage is thin, continuous deployment amplifies risk.
- **Rollback capability.** Can you roll back a bad deploy in under five minutes without data loss? If not, the cost of a bad automated deploy is high.
- **Regulatory requirements.** Some industries require a human sign-off before production changes (SOC 2, FedRAMP, PCI DSS). Continuous Deployment is incompatible with mandatory approval gates.
- **Release coordination.** Products with coordinated release schedules (marketing, pricing changes, legal disclosures) need the Continuous Delivery model: build continuously, release deliberately.

> [!info] The DORA State of DevOps reports consistently show that elite performers deploy to production multiple times per day. Most achieve this through Continuous Deployment on small, safe changes — not through heroic release coordination.

@feynman

Continuous Delivery means every green build could go to production if someone presses a button; Continuous Deployment means the pipeline presses the button automatically.

@card
id: cicdp-ch01-c007
order: 7
title: The Cost of Pipeline Defaults
teaser: Every CI/CD tool ships with defaults — default runners, default caching behavior, default timeout values, default concurrency limits. Shipping with those defaults unchanged is a design decision with real cost in speed, security, and reliability.

@explanation

GitHub Actions, GitLab CI, and CircleCI all make specific default choices on behalf of the user. These choices are reasonable starting points — but they are optimized for onboarding ease, not for production pipeline performance.

Common default costs that go unexamined:

- **No dependency caching.** The default GitHub Actions runner installs dependencies from scratch on every run. For a Node.js project with 800 packages, this can add 3-5 minutes to every build. A single cache configuration recovers this permanently.
- **Sequential stages by default.** Most teams run unit tests, integration tests, and security scans in sequence because that's the order they were added. Parallelizing them across runners can cut total wall time by 60%.
- **No build artifact reuse.** When each stage re-runs the build independently, the same compilation happens three or four times in a single pipeline run. Passing the built artifact between stages eliminates this.
- **Overpermissioned tokens.** GitHub Actions defaults to a `GITHUB_TOKEN` with write access to the entire repository. Most jobs need read access to checkout code, nothing more. The principle of least privilege is not the default.
- **No timeout configured.** GitHub Actions jobs have a default 6-hour timeout. A hung test suite can consume 6 hours of runner minutes before failing. Setting a job timeout of 15-20 minutes catches runaway builds early.

These are not obscure edge cases — they are the standard configuration of most pipelines in production. The aggregate cost is significant: slower feedback, inflated compute costs, and unnecessary security exposure.

> [!warning] A pipeline that runs correctly but takes 45 minutes is not working correctly. Speed is a correctness property: feedback that arrives late enough for engineers to have context-switched is feedback that will be ignored.

@feynman

CI/CD defaults are chosen for ease of getting started, not for production performance. Accepting them unchanged is a choice — and it usually costs you speed, security, and money.

@card
id: cicdp-ch01-c008
order: 8
title: Reading a Pipeline Diagram
teaser: A pipeline diagram is the primary design artifact — it makes stages, parallelism, dependencies, and failure paths legible at a glance. Teams that cannot diagram their pipeline cannot reason about it, which means they cannot improve it.

@explanation

A well-drawn pipeline diagram shows five things: the stages in order, which jobs within each stage can run in parallel, the artifact handoffs between stages, the trigger conditions, and the failure paths. Nothing else is required.

A minimal notation for pipeline diagrams:

- **Boxes** represent jobs. A box with a solid border is automated; a box with a dashed border has a manual approval gate.
- **Arrows** represent sequencing and data flow. A solid arrow means "this job must complete before the next starts." Arrows labeled with artifact names show what is being passed (e.g., "container image," "test report").
- **Columns** group jobs into stages. Jobs in the same column can run in parallel. Columns are ordered left to right.
- **Red paths** trace what happens when a job fails: which downstream jobs are skipped, which are cancelled, and which still run (e.g., cleanup jobs that run regardless of failure).

GitHub Actions and GitLab CI both generate pipeline visualization UIs from their configuration. These are useful for verification but should not replace an authored design diagram — the tool-generated view shows what the pipeline *does*, not what it *should* do. The authored diagram is the design intent; the generated view is the implementation.

If you cannot draw your current pipeline on a whiteboard in five minutes, it is either too complex or too poorly understood. Both are problems.

> [!info] Keep the pipeline diagram in the repository alongside the configuration. When the diagram and the implementation diverge, the diagram is either wrong (update it) or the implementation is wrong (fix it). Ambiguity is always resolved by the diagram — it is the specification.

@feynman

A pipeline diagram is the blueprint — it shows what the pipeline is supposed to do before you look at a single line of YAML. If you can't draw it, you don't know what you built.

@card
id: cicdp-ch01-c009
order: 9
title: Pipeline Anti-Patterns
teaser: The snowflake pipeline, the script pile, and the cargo-cult pipeline are three failure modes so common they deserve names — recognizing them is the first step toward treating pipeline design as a discipline rather than a craft mystery.

@explanation

Anti-patterns in CI/CD are not hypothetical — they are the default outcome when pipelines grow without design intent. Three of them are nearly universal:

- **The Snowflake Pipeline.** Every repository has a unique pipeline that evolved independently. Ten repositories have ten incompatible approaches to building, testing, and deploying. A developer moving between repositories must re-learn the pipeline. A security fix that needs to propagate to all pipelines requires ten separate pull requests. The snowflake pattern trades short-term flexibility for long-term unmaintainability.
- **The Script Pile.** The pipeline YAML is a thin wrapper around a collection of shell scripts. The actual logic lives in `deploy.sh`, `build.sh`, and `test.sh` — each written by a different person, with different error handling conventions, no shared utilities, and no tests. The script pile is often the result of "we'll refactor this later" applied iteratively for two years.
- **The Cargo-Cult Pipeline.** The pipeline copies configuration from a blog post, a previous employer, or a community template without understanding why each step exists. Security scans are included because "pipelines should have security scans," not because the team knows what to do with the findings. Steps are never removed when they become irrelevant because nobody knows what they do.

Each anti-pattern has a specific remedy:

- **Snowflake** → shared pipeline templates with per-repository overrides for genuinely different requirements.
- **Script pile** → move logic into tested, versioned tooling (Makefiles, language-native task runners, composite actions in GitHub Actions).
- **Cargo cult** → require that every step in the pipeline has a documented purpose and an owner. If no one can explain why a step exists, remove it.

@feynman

A snowflake pipeline is unique and unmaintainable; a script pile has hidden logic no one understands; a cargo-cult pipeline copies what others do without knowing why. All three grow from the same root cause: building without designing.

@card
id: cicdp-ch01-c010
order: 10
title: The Inner Loop vs the Outer Loop
teaser: The inner loop is what a developer does locally — edit, build, test, repeat. The outer loop is what the CI/CD pipeline does on every commit. Designing the boundary between them determines how fast developers can work and how much the pipeline costs to run.

@explanation

The distinction between inner and outer loop is foundational to pipeline design. It determines which work runs on a developer's machine (fast, free, private) and which runs in CI (slower, metered, auditable).

The **inner loop** is the developer's local feedback cycle: write code, run unit tests, fix failures, repeat. A healthy inner loop completes in seconds. It uses local state — the developer's machine, local Docker, local databases. It is fast because it is scoped: unit tests run against the module being changed, not the entire system.

The **outer loop** is the CI pipeline: it runs after a commit is pushed, in a clean environment, against the full integrated system. The outer loop catches what the inner loop cannot — integration failures, contract violations, environment-specific behaviors, security vulnerabilities in the dependency graph.

Design failures at the boundary:

- **Inner loop too slow.** If the developer must wait 5 minutes to run the full test suite locally, they will run tests less frequently or not at all. The inner loop must be optimized relentlessly — test selection, parallel execution, dependency isolation.
- **Outer loop duplicates inner loop.** Running the same unit tests in CI that the developer already ran locally wastes compute and time. CI should spend its budget on what the developer cannot do locally: integration tests, security scans, and cross-platform builds.
- **Outer loop too slow to provide signal.** If the CI pipeline takes 45 minutes, developers will have moved on to the next task before they see the result. The outer loop should aim to provide actionable signal within 10-15 minutes for the most common path.

> [!info] Developer experience research from Google's DORA team consistently shows that fast CI feedback (under 10 minutes) is one of the highest-leverage improvements a team can make. Every minute added to the outer loop has a disproportionate cost in context-switching and developer satisfaction.

@feynman

The inner loop is the developer's "does this work on my machine" cycle; the outer loop is CI's "does this work for everyone" check. A good pipeline design makes each one fast and avoids duplicating work between them.

@card
id: cicdp-ch01-c011
order: 11
title: Defining "Done" for a Pipeline
teaser: A pipeline without a definition of done has no way to fail correctly — it either blocks on things that don't matter or lets through things that do. "Done" is a contract, and writing it down is what separates an intentional pipeline from an accidental one.

@explanation

Every pipeline enforces some implicit definition of done: the set of conditions that must be true before code can move to the next stage or reach production. Making that definition explicit is one of the highest-value pipeline design activities.

A well-specified pipeline definition of done answers these questions at each stage boundary:

- **Build done:** The artifact compiles without errors. All dependencies resolve. The artifact is signed and stored in the registry with an immutable digest.
- **Verify done:** Unit tests pass with coverage above threshold. Integration tests pass. No new linting violations. No regressions in performance benchmarks (if applicable).
- **Secure done:** No critical or high CVEs in dependency scan. No secrets detected in source. SBOM generated and stored. SAST findings reviewed (not necessarily zero — but reviewed and triaged).
- **Deploy done:** Health checks pass in the target environment. Smoke tests confirm the service is reachable and responding correctly. Rollback is available and tested.

The definition of done is also where organizational standards get encoded. If the security team requires SAST on every merge, that requirement lives in the pipeline's definition of done — not in a policy document that engineers rarely read.

The anti-pattern: "we'll add that check later." Later means the check is optional, which means it will be skipped under pressure. Requirements that should be mandatory must be in the pipeline at design time, not retrofit time.

> [!warning] A pipeline with an escape hatch — a manual override for "emergency" deploys that skip stages — has no definition of done. It has a definition of done that applies when convenient. Design the escape hatch deliberately and audit its use.

@feynman

"Done" for a pipeline means: "these specific conditions must be true before this code can move forward." Writing that down is what makes the pipeline a gatekeeper rather than a suggestion box.

@card
id: cicdp-ch01-c012
order: 12
title: From Tooling to Design Discipline
teaser: The transition from "we use GitHub Actions" to "we have a pipeline design" is a professional maturity step — it means owning the pipeline as a system with documented intent, measured performance, and a clear owner.

@explanation

Most teams relate to their pipeline the way they relate to their IDE settings: something that was configured once, is rarely examined, and is accepted as-is unless something visibly breaks. The shift to treating the pipeline as a design discipline requires a different posture.

What design discipline looks like in practice:

- **The pipeline has a documented design.** A diagram exists. The four jobs (build, verify, secure, deploy) are explicitly represented. Every stage has a stated purpose. Every job has an owner.
- **The pipeline has a measured baseline.** Pipeline duration is tracked over time. Flakiness rates are monitored. Failure reasons are categorized. You cannot improve what you cannot measure.
- **The pipeline has a team.** Someone is responsible for its performance and maintenance. This may be a platform team, a developer experience team, or a designated rotating responsibility — but it is not nobody.
- **The pipeline is tested.** Changes to the pipeline configuration go through a review process. The pipeline itself has tests — at minimum, a dry-run or staging environment where configuration changes can be validated before they affect production builds.
- **The pipeline evolves deliberately.** New requirements (a new security scanner, a new test suite) go through a design conversation before they are added. The question is not "can we add this?" but "where does this fit in the four-job model and what is its impact on pipeline duration?"

Michiel van Merode, in *CI/CD Design Patterns*, frames this shift as the difference between "tool users" and "system designers." Tool users configure the tool to do what they need today. System designers ask what the pipeline must guarantee, and choose or configure tools to enforce those guarantees.

The rest of this book is about making that shift. Each chapter covers one design domain — from build optimization to security integration to deployment strategy to pipeline governance — not as a collection of tips, but as a coherent system for thinking about what a pipeline is and what it must do.

> [!info] The DORA research identifies "trunk-based development" and "continuous testing" as the two technical practices most strongly correlated with high software delivery performance. Both are pipeline design choices, not tool choices.

@feynman

Moving from tooling to design discipline means treating the pipeline as a system you own and are responsible for — not a configuration file you accept as-is.
