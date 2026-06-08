@chapter
id: cicdp-ch10-progressive-delivery
order: 10
title: Progressive Delivery and Feature Flags
summary: Decoupling deploy from release — flag systems (LaunchDarkly, OpenFeature), flag debt and lifecycle, A/B testing infrastructure, and the experimentation pipeline that turns CI/CD into a learning loop.

@card
id: cicdp-ch10-c001
order: 1
title: Progressive Delivery as a Concept
teaser: Progressive delivery is not a tool or a pipeline stage — it is a philosophy: ship code to production continuously, but control who sees it, how much of it, and for how long. James Governor coined the term to describe what comes after continuous delivery.

@explanation

In 2018, James Governor of RedMonk introduced the term **progressive delivery** to describe an emerging class of deployment practices that go beyond simply automating the path to production. His definition: progressive delivery is continuous delivery with fine-grained control over the blast radius of each release.

The key insight behind progressive delivery is that deploying code to production and releasing that code to users are two separate acts. Traditional release engineering collapsed these: when you deployed, users saw the change. Progressive delivery separates them deliberately:

- **Deploy** — move a new version of code into a production environment, running alongside or replacing the previous version.
- **Release** — expose the deployed code to users, in whole or in part. The release can happen immediately after deploy, days later, or via a gradual rollout to 1% of traffic, then 10%, then 100%.

The practical techniques of progressive delivery include feature flags, canary deployments, ring deployments, blue-green deployments, and A/B testing. What unifies them is that they all answer the same question: how do we reduce the risk of a given change by controlling its exposure before committing fully?

Progressive delivery is especially important for teams that have achieved continuous deployment — they ship dozens of times per day — but need finer risk management than a rollback strategy alone provides. You cannot roll back fast enough if a bad deploy reaches 100% of users in 30 seconds. Progressive delivery solves for that by never reaching 100% without a deliberate decision.

> [!info] Governor's framing: "Progressive delivery makes it easier to release new features iteratively and deliver them to specific users, rather than rolling them out to all users at the same time." The pipeline is no longer just a path to production — it is a control plane for user exposure.

@feynman

Progressive delivery means you deploy code to production all the time, but you control who actually sees it — maybe 1% of users first, then more, then everyone — so a bad change can't hurt everyone before you notice it.

@card
id: cicdp-ch10-c002
order: 2
title: Decoupling Deploy from Release
teaser: The most important architectural insight in modern release engineering is that deploy and release are independent axes. A team that understands this can ship continuously while still coordinating releases — and a team that conflates the two is constrained to do both at once or neither.

@explanation

In most teams' mental models, a deployment is a release: you push code, it goes live. This conflation has practical consequences. If deploy equals release, then every deploy is a public commitment. Release coordination (marketing launches, pricing changes, legal disclosures, synchronized multi-service changes) must happen at deploy time — which means deploy frequency drops to match release cadence. Continuous deployment becomes incompatible with coordinated releases.

The separation of deploy from release breaks this constraint:

- A feature can be deployed to production — fully operational, tested under real traffic — while being invisible to users via a flag that is off.
- The release decision (when users see it, who sees it first, how fast it rolls out) is separated from the engineering pipeline.
- Multiple features can accumulate in production, tested and verified, waiting for a coordinated release event that marketing or product controls.
- A bad release can be reversed by flipping a flag — without a rollback, a redeploy, or an incident.

Amazon's deployment philosophy — codified in their release tooling and described in various engineering blog posts — explicitly separates deployments (which happen on engineer schedules, dozens per day per service) from feature releases (which happen on product schedules). The code for a Prime Day feature may be deployed months before the sale; the flag turns on at the scheduled moment.

The pipeline consequence: your CI/CD pipeline's job is to get verified code into production quickly. The *release* pipeline — the flag system, the rollout configuration, the exposure policy — is a second system that the engineering pipeline feeds. Designing them separately is what makes each one clean.

> [!warning] Teams that deploy and release simultaneously cannot practice continuous deployment without also releasing continuously. If your business cannot release continuously, continuous deployment becomes a governance problem — unless you decouple the two.

@feynman

Deploying means putting code in production; releasing means letting users see it. If you treat them as the same thing, you can only ship as fast as your business is ready to release. If you separate them, you can ship every hour and release on a schedule.

@card
id: cicdp-ch10-c003
order: 3
title: Feature Toggles in Practice
teaser: Pete Hodgson's 2017 article on feature toggles is the canonical reference — it names four distinct toggle types and explains why treating all flags as the same kind of switch is a design error that produces unmaintainable flag systems.

@explanation

Pete Hodgson's article "Feature Toggles (aka Feature Flags)" (martinfowler.com, 2017) established the vocabulary the industry now uses. His central argument: not all feature toggles are the same. Conflating them produces flag systems that are simultaneously over-engineered for simple use cases and under-engineered for complex ones.

Hodgson's four toggle categories:

- **Release toggles** — hide incomplete features from users while allowing the code to be integrated and deployed. Intended to be short-lived; a release toggle that survives the feature launch is technical debt immediately.
- **Experiment toggles** — route users into A/B test cohorts. Drive data collection for statistical analysis. Should be managed by an experimentation platform, not hand-coded conditionals.
- **Ops toggles** — control operational behaviors: circuit breakers, rate limiters, cache bypass flags. Often long-lived. Change at runtime by operations staff, not by developers.
- **Permission toggles** — gate features by user entitlement (beta users, premium subscribers, internal staff). Often permanent for the lifetime of the entitlement model.

In code, a release toggle looks like this in a LaunchDarkly-integrated Node.js service:

- `const showNewCheckout = await ldClient.variation('new-checkout-flow', userContext, false);`
- `if (showNewCheckout) { return newCheckoutHandler(req); }`
- `return legacyCheckoutHandler(req);`

The toggle point is always a conditional at the call site. The flag evaluation — which might involve user targeting rules, percentage rollouts, or environment overrides — is handled by the flag SDK, not the application code. This separation keeps the application clean and the rollout logic centralized.

> [!info] Hodgson's key design principle: the cost of a toggle point (a conditional in code) is low; the cost of toggle management (knowing what flags exist, what they do, and when to remove them) is high. Design your flag system to minimize management cost, not toggle point cost.

@feynman

A feature toggle is just an if-statement whose condition comes from outside the code rather than being hardcoded. The complexity isn't the toggle itself — it's tracking dozens of them, knowing which are still needed, and knowing when to clean them up.

@card
id: cicdp-ch10-c004
order: 4
title: Flag Lifecycle and Flag Debt
teaser: Every feature flag is technical debt the moment it is created — the question is whether the debt is intentional and time-bounded. Flag debt, like code debt, accumulates interest: stale flags make code harder to read, tests harder to write, and incidents harder to diagnose.

@explanation

A feature flag has a lifecycle. It is born when a feature starts development, it matures when the feature is fully released, and it should die shortly after — when the old code path is removed and the toggle point deleted. Teams that treat flags as permanent configuration accumulate flag debt.

The symptoms of flag debt:

- **Zombie flags.** Flags that have been 100% on or 100% off for months, with the old code path never removed. The flag is inert but its toggle point remains — a dead branch that confuses future readers and sometimes hides bugs.
- **Combinatorial complexity.** With 20 active flags, you have 2^20 theoretical code path combinations. Testing them all is impossible. Bugs exist in untested flag combinations. Knight Capital's 2012 $440M trading loss was triggered by legacy code activated by a flag that had been dormant for years and was reused by mistake.
- **Documentation rot.** The purpose and expected lifetime of a flag was clear to the engineer who created it. Six months later, nobody knows if it is safe to remove.
- **Incident complexity.** When a production incident occurs, responders must reason about which flags are on for the affected users. A system with 50 active flags and complex targeting rules makes incident diagnosis significantly harder.

Flag lifecycle management requires:

- Every flag gets a stated expiry policy at creation time: "remove after full rollout," "permanent ops toggle," or "remove after experiment concludes."
- Flag management platforms (LaunchDarkly, Statsig) surface stale flags by tracking when a flag last changed and alerting on flags with no traffic variation.
- Cleanup tasks are backlog items, not optional cleanup. Every flag retirement is a pull request that removes the conditional and deletes the old code path.

> [!warning] Treat flag cleanup as a first-class engineering task. A team that adds 5 flags per sprint and retires 2 will have 90 active flags after a year. The marginal cognitive cost of each flag is not zero — it is paid on every code review, every test run, and every incident.

@feynman

Flag debt is what happens when you add flags faster than you remove them. Each stale flag is a dead branch in your code that makes reading, testing, and debugging harder. The fix is treating flag retirement as normal engineering work, not optional cleanup.

@card
id: cicdp-ch10-c005
order: 5
title: OpenFeature: The Standard
teaser: OpenFeature is a CNCF specification that defines a vendor-neutral API for feature flag evaluation — freeing application code from SDK lock-in and enabling a plug-in model where the flag provider can be swapped without changing a single line of feature code.

@explanation

Before OpenFeature, every feature flag system required its own SDK. Switching from LaunchDarkly to Flagsmith meant updating every flag evaluation call in application code — a large, error-prone migration that locked teams into their initial vendor choice.

The Cloud Native Computing Foundation (CNCF) incubated **OpenFeature** (openfeature.dev) to solve this. OpenFeature defines a standard API surface for flag evaluation, with provider implementations for each backend. Application code calls the OpenFeature API; a registered provider translates those calls to the specific flag system's protocol.

The OpenFeature architecture:

- **OpenFeature Client** — the API your application code calls. Methods like `getBooleanValue('flag-key', false, context)` are identical regardless of provider.
- **Provider** — a plug-in registered at startup that connects the OpenFeature client to a specific flag backend: LaunchDarkly, Flagsmith, CloudBees, Statsig, or a custom in-process provider for testing.
- **Hooks** — middleware that runs before and after flag evaluation. Used for logging, telemetry, caching, and error handling without coupling these concerns to application code.
- **Evaluation Context** — structured user/session/request attributes passed to flag evaluation. The provider uses the context to apply targeting rules. Standardizing context structure across the application is a key architectural concern.

In a Java Spring Boot service using the OpenFeature Java SDK:

- `OpenFeatureAPI.getInstance().setProvider(new LaunchDarklyProvider(ldClient));`
- `Client client = OpenFeatureAPI.getInstance().getClient();`
- `boolean enabled = client.getBooleanValue("new-pricing", false, ctx);`

Switching to Flagsmith later requires changing one line — the provider registration — rather than every flag evaluation call in the codebase.

> [!info] OpenFeature reached CNCF Incubating status in 2023. SDKs are available for Java, JavaScript/TypeScript, Go, Python, PHP, .NET, and Ruby. For greenfield flag implementations, OpenFeature should be the default choice: it preserves optionality and makes testing easier via in-process providers that bypass remote calls entirely.

@feynman

OpenFeature is a standard interface for feature flags — like JDBC for databases. Your code calls the standard API; a plug-in provider connects that to whatever flag system you're using. Switching providers later doesn't touch your application code.

@card
id: cicdp-ch10-c006
order: 6
title: LaunchDarkly and Commercial Flag Systems
teaser: LaunchDarkly, Statsig, Optimizely, and Unleash represent the spectrum of commercial and open-source flag platforms — each with different tradeoffs between evaluation latency, targeting sophistication, experimentation capability, and operational overhead.

@explanation

LaunchDarkly (founded 2014) pioneered the commercial feature flag market and remains the reference implementation for enterprise flag systems. Its architecture is worth understanding because it illustrates the key design decisions every flag system must make.

LaunchDarkly's core architecture:

- **Streaming flag delivery.** Flag rule changes are pushed to SDKs via Server-Sent Events (SSE) within milliseconds. The SDK evaluates flags in-process — there is no per-request round trip to a remote service. Evaluation latency is measured in microseconds.
- **Multi-variate flags.** Flags are not limited to boolean. A flag can return a string, number, or JSON object — enabling full configuration as code (feature configuration, not just feature presence).
- **Targeting rules.** Rules are evaluated against user context attributes: user ID, plan tier, country, device type, any custom attribute. Rules support percentage rollouts and rule-based targeting without application code changes.
- **Flag analytics.** Tracks which users evaluated which flags and which variation they received. Used for debugging, for experimentation, and for identifying stale flags.

The alternatives and their niches:

- **Statsig** — strong experimentation platform built on top of flag infrastructure. Native support for experiment metrics, statistical significance reporting, and CUPED variance reduction. Strong fit for teams where flags and A/B testing are tightly coupled.
- **Optimizely (Experimentation)** — originated as an A/B testing platform; added feature flags. The tooling is optimized for experimentation workflows, with a visual experiment editor and built-in stats engine.
- **Unleash** — open-source flag system with a self-hosted option. Lower operational cost but requires engineering time to run. OpenFeature provider available. Strong choice for privacy-sensitive environments where flag data cannot leave the perimeter.

> [!info] All major commercial flag systems now support OpenFeature providers, which reduces the switching cost substantially. Evaluate flag platforms on targeting sophistication, experimentation capabilities, SDK language coverage, and audit logging — not on the API surface, which OpenFeature standardizes.

@feynman

LaunchDarkly and its competitors are remote-control systems for your code: they decide which code path each user gets, in real time, without a redeploy. The key engineering decision is whether you need just flag management, or flag management plus experiment analysis.

@card
id: cicdp-ch10-c007
order: 7
title: A/B Testing Infrastructure
teaser: A/B testing is not a feature flag with two values — it is a statistical experiment requiring randomized assignment, treatment isolation, metric collection, and a valid significance test. Building A/B infrastructure on top of a flag system requires each of these to be designed explicitly.

@explanation

A/B testing — or more precisely, controlled experimentation — is the practice of randomly assigning users to treatment and control groups, exposing each group to a different code path, and measuring whether the treatment caused a statistically meaningful change in a target metric. It is a causal inference tool disguised as a product development practice.

The infrastructure requirements for valid A/B testing:

- **Stable assignment.** A user assigned to the treatment group must stay in the treatment group for the experiment's duration. Reassigning users mid-experiment contaminates results. Stable assignment is typically implemented via a deterministic hash of user ID and experiment key.
- **Instrumentation.** Every experiment exposure (who saw which variant) must be logged with the same user ID that the product metrics system uses. Without this join, you cannot connect experiment assignment to outcome metrics.
- **Metrics pipeline.** Experiment metrics must be aggregated by variant. This requires an event stream (Kafka, Kinesis, or similar), aggregation jobs (Spark, dbt, or a metrics platform), and a variance-aware statistics layer.
- **Statistical engine.** Frequentist t-tests and z-tests are the baseline. Modern platforms (Statsig, Optimizely, Netflix's internal tools) use CUPED (Controlled-experiment Using Pre-Experiment Data) to reduce variance and increase experiment sensitivity, shortening the minimum detectable effect window.
- **Guardrail metrics.** Every experiment must define not just the target metric ("increase checkout conversion") but also guardrail metrics ("do not increase error rate", "do not increase latency"). An experiment that wins on conversion but breaks latency must be rejected.

Statsig's experiment SDK integrates flag assignment and event logging in a single call:

- `const experiment = statsig.getExperiment(user, 'checkout_redesign');`
- `const variant = experiment.get('layout', 'control');`

> [!warning] The most common A/B testing mistake is peeking: checking results before the experiment has run long enough to achieve statistical power, and stopping when the result looks favorable. This inflates false positive rates significantly. Use fixed-horizon tests or sequential analysis methods that are designed for early stopping.

@feynman

A/B testing is a controlled experiment: you randomly split users into groups, show each group something different, and measure whether the difference caused a real change in behavior. The infrastructure challenge is connecting who saw what with what they did afterward — reliably, at scale.

@card
id: cicdp-ch10-c008
order: 8
title: Continuous Delivery vs Continuous Deployment Revisited
teaser: Progressive delivery reframes the CD debate. Feature flags dissolve the tension between continuous deployment and release coordination — you can deploy continuously and release deliberately. The question is no longer "which model should we choose?" but "how do we implement both simultaneously?"

@explanation

Chapter 1 introduced the distinction: continuous delivery is the capability to release at any time; continuous deployment is the practice of releasing automatically on every green build. The tension has always been: organizations that need coordinated releases (aligned with marketing, legal, or support) have argued that continuous deployment is incompatible with their requirements.

Progressive delivery resolves this tension by decoupling the technical pipeline from the release decision:

- The CI/CD pipeline practices continuous deployment: every green build on main deploys to production automatically.
- Features in progress are hidden behind flags — deployed to production, but not released to users.
- The release event is controlled by product or marketing: a flag is enabled on a schedule, a launch date, or a staged rollout plan.
- Engineering ships continuously. The business releases deliberately. Both goals are satisfied simultaneously.

Facebook (now Meta) has practiced this model at scale for years. Their continuous deployment pipeline pushes to production multiple times per day. Major product launches (News Feed algorithm changes, Stories rollout, Marketplace) are released via gradual flag rollouts independent of the deployment pipeline. The two cadences run on separate tracks.

The implication for regulated industries: continuous deployment behind flags does not necessarily violate change management requirements. The argument to auditors is that the deployment pipeline moves tested, approved code; the release decision (flag enable) is the controlled change event that is logged, approved, and reversible within seconds.

> [!info] Jez Humble's updated position on this: "With feature flags, the continuous deployment vs continuous delivery debate becomes somewhat moot. You can have continuous deployment — every build automatically reaches production — while still exercising full control over when features are visible to users. It's not either-or anymore."

@feynman

Feature flags let engineering teams deploy to production automatically every day, while the business team controls when users actually see anything. You get the speed of continuous deployment and the control of continuous delivery — both at the same time.

@card
id: cicdp-ch10-c009
order: 9
title: Experimentation as a Pipeline Concern
teaser: When experimentation is integrated into the delivery pipeline, CI/CD stops being a path to production and becomes a learning loop. Each release is a hypothesis; each experiment is a validation step; each data point feeds back into the next iteration. This is the experimentation pipeline.

@explanation

Most organizations treat experimentation as a product discipline separate from engineering delivery. Product managers design experiments; engineers implement flag logic; analysts measure results; and these loops run on entirely separate cadences. The result is that the learning cycle is slow — weeks or months from hypothesis to validated conclusion.

Integrating experimentation into the delivery pipeline changes this. The experimentation pipeline has four stages that mirror — and extend — the CI/CD pipeline:

- **Hypothesis definition.** The feature branch includes not just code but a documented hypothesis: what behavior is expected to change, what metric will be measured, and what minimum detectable effect justifies the investment. This lives in a machine-readable experiment config file alongside the code.
- **Instrumentation verification.** A pipeline stage validates that the instrumentation events required for the experiment are correctly emitted. Test events fire in the staging environment and are verified against the experiment config. A feature that launches without proper instrumentation produces no usable data.
- **Gradual rollout.** The flag system's rollout plan is checked into source control alongside the code. The pipeline promotes the rollout automatically: 1% on day 1, 10% on day 3, 50% on day 7, 100% on day 14 — with automatic halts if guardrail metrics breach thresholds.
- **Experiment conclusion.** When the experiment concludes, the results are logged and attached to the original feature PR or ticket. Flag cleanup is a required step before the feature is considered done.

Netflix's experimentation platform (described in their engineering blog and the book "Designing Distributed Systems") treats every product change as an experiment by default. The engineering and product organizations share a single platform that handles flag management, rollout scheduling, metric collection, and result reporting. Separating these into disconnected tools is the source of most organizational friction in the experimentation pipeline.

> [!info] Booking.com's 2013 paper on their experimentation culture remains a benchmark: they ran more than 1,000 concurrent experiments across the platform. The prerequisite was not a sophisticated stats engine — it was an engineering culture where instrumentation was a first-class requirement for every feature, enforced at code review and pipeline stages.

@feynman

An experimentation pipeline means every new feature is treated as a hypothesis: you state what you expect to happen, verify the instrumentation is correct before launch, roll out gradually, and measure the result. The CI/CD pipeline becomes a learning loop, not just a delivery mechanism.

@card
id: cicdp-ch10-c010
order: 10
title: Release Trains for Coordinated Releases
teaser: A release train is a scheduled release cadence that departs on a fixed schedule regardless of which features are on board — like a real train that leaves whether or not every passenger has arrived. Teams that cannot or will not adopt continuous deployment often find release trains the practical middle ground.

@explanation

The release train model was formalized in the Scaled Agile Framework (SAFe) but the practice predates it. Apple's iOS point releases, Kubernetes minor releases, and most enterprise software products operate on a release train model: releases happen every N weeks on a schedule; features that are ready board the train; features that miss the cutoff wait for the next one.

Release trains work by separating feature readiness from release cadence:

- The train departs on a fixed schedule — weekly, bi-weekly, or monthly — regardless of which features are complete. There are no "one more day" delays.
- Features are gated individually. Incomplete features are either excluded (using a flag) or held back to the next train. The train itself is never delayed for a feature.
- The pipeline builds and validates the release candidate on the train's cutoff date. Automated testing, security scans, and UAT all run against the fixed snapshot.
- A release manager (or automated tooling) tracks which features are on the current train, their test status, and their approval state.

The Kubernetes release train is illustrative. Minor releases (1.N) ship roughly every four months. Each release train has a feature freeze date, a code freeze date, and a release date. Enhancement proposals that miss the feature freeze wait for 1.N+1. The predictability this creates — for contributors, for cloud providers, for operators — is the value of the model.

Release trains and feature flags are complementary. Progressive delivery organizations use flags to route unfinished features away from the train; the train delivers everything that is ready; flags gradually expose new features after the train has shipped.

> [!info] The train metaphor is deliberate: a missed train is not a crisis, it is a scheduling outcome. Teams that treat a missed release as a crisis will slip dates to avoid the miss. Teams that accept the train model ship higher-quality releases because the pressure to delay is removed.

@feynman

A release train leaves on a fixed schedule no matter what. If your feature isn't ready, it waits for the next train. This sounds harsh but it's actually liberating — nobody can pressure the team to delay a release for one feature, because the train doesn't negotiate.

@card
id: cicdp-ch10-c011
order: 11
title: Immutable Infrastructure and Rollback
teaser: Immutable infrastructure — the practice of never modifying a running server, only replacing it with a newly built image — is the prerequisite for reliable rollback. Without immutability, "rollback" is actually a forward deploy of old code into an environment that has mutated from what that code expected.

@explanation

The term **immutable infrastructure** was popularized by Chad Fowler in a 2013 blog post. The principle: servers (or containers, or functions) are never patched in place. When a change is needed — a new release, a security patch, a configuration update — a new image is built from source, tested in the pipeline, and deployed to replace the running instance. The old instance is terminated.

Why immutability is prerequisite to reliable rollback:

- **Mutable servers drift.** A server that has been running for months has accumulated patches, config changes, and installed software that are not reflected in any source artifact. Rolling back the application code to v1.2 on a server that has mutated since v1.2 was deployed is not actually running v1.2's environment.
- **Immutable artifacts make rollback a deploy.** If v1.2 produced an immutable container image with a content-addressed digest, rolling back means deploying that exact image. The environment is identical to what ran in production when v1.2 was healthy.
- **The pipeline builds immutability.** Every artifact that exits the build stage must be immutable and content-addressed. Docker image digests (`sha256:...`), not mutable tags (`:latest`), should be the deployment reference.

In a Kubernetes deployment context, the rollback workflow for an immutable infrastructure stack:

- `kubectl rollout undo deployment/myapp` — Kubernetes replaces the current pods with the previous ReplicaSet, which references the previous image digest.
- The previous image is already in the registry. No rebuild is needed. Rollback completes in the time it takes to pull and start the container.

Immutable infrastructure also simplifies the relationship between feature flags and rollback. For stateless behavior changes, a flag disable is faster and less disruptive than a rollback. For infrastructure-level changes (a new database schema, a changed environment variable), rollback via immutable image replacement is the right tool.

> [!warning] Database migrations are the primary exception to immutable infrastructure rollback. If v1.3 applied a schema migration that v1.2 is incompatible with, rolling back the application to v1.2 may not be safe without also rolling back the database — which is often much harder. Design migrations to be backward-compatible (expand/contract pattern) so rollback is always an option.

@feynman

Immutable infrastructure means you never change a running server — you replace it with a freshly built one. That makes rollback straightforward: you just redeploy the previous version's image, which is identical to what ran before. No mutations means no surprises.

@card
id: cicdp-ch10-c012
order: 12
title: Anti-Patterns: Flag Soup
teaser: Flag soup is what happens when feature flags multiply without discipline — a codebase where every conditional is a flag, flag state is undocumented, targeting rules are contradictory, and no one can confidently reason about what any given user will experience. It is one of the most predictable failure modes of progressive delivery.

@explanation

Flag soup is the progressive delivery equivalent of the snowflake pipeline or the script pile. It emerges gradually, one flag at a time, until the system has properties that no individual flag addition intended:

- **Flags within flags.** Feature B's behavior depends on whether Flag A is enabled for the current user. Feature C depends on both A and B. The effective behavior for any given user requires evaluating a graph of flag dependencies, which no tooling surfaces clearly.
- **Contradictory targeting.** Flag X targets "all users in the US"; Flag Y targets "all premium users"; Flag Z targets "beta users not in the US." A US-based premium beta user has an indeterminate experience that no one explicitly designed.
- **Untestable flag combinations.** With 30 active flags, the test matrix is 2^30 combinations. Tests cover the happy path with all flags in their default state. The states that actually reach users in production are not tested.
- **Flags as configuration management.** Flags originally intended as temporary release toggles are repurposed as permanent configuration — API endpoint URLs, timeout values, feature tier gates. The flag system becomes a configuration management database without the structure or tooling of one.
- **No owner, no expiry.** A flag created by an engineer who has since left the team controls a production code path. Nobody knows if it is safe to enable or disable. Removing it feels risky; leaving it feels unsafe.

Preventing flag soup requires process, not just tooling:

- Every flag has a named owner, a type (from Hodgson's taxonomy), and a stated expiry condition.
- Flag creation is a pull request — not just a UI action in the flag platform — so it goes through code review.
- Flag retirement is a sprint commitment. The team tracks outstanding flags as technical debt on the backlog.
- Flag dependencies are prohibited by convention. If a feature requires two flags to be in a specific combination, that combination becomes a single flag.

> [!warning] Progressive delivery is powerful precisely because it adds a new control surface to your system. Like any control surface, it requires governance. A flag system without lifecycle management does not add control — it adds hidden state, and hidden state is where incidents live.

@feynman

Flag soup is what you get when you add feature flags without removing them — a system full of conditionals nobody understands, testing combinations nobody has checked, and production behavior nobody can predict. The fix is treating flags like any other technical debt: track them, own them, and retire them.
