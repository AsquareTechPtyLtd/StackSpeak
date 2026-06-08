@chapter
id: cicdp-ch09-deployment-strategies
order: 9
title: Deployment Strategies
summary: Recreate, Rolling, Blue/Green, Canary, Shadow, Ring, Dark Launch — when each is correct, how auto-rollback closes the loop, and the bake-time discipline that turns deployment into a non-event.

@card
id: cicdp-ch09-c001
order: 1
title: Recreate vs Rolling Deployment
teaser: Recreate and Rolling are the two baseline deployment strategies — one trades downtime for simplicity, the other trades complexity for availability. Every other strategy in this chapter is a refinement of Rolling.

@explanation

Before you reach for canary releases or blue/green environments, you need to understand the two primitive strategies every orchestrator supports out of the box.

- **Recreate** — terminate all instances of the old version, then start all instances of the new version. There is a gap between termination and readiness: the service is unavailable during that window. Simple to implement, impossible to misunderstand, and fine for non-critical internal services or batch jobs where downtime is acceptable.
- **Rolling Update** — replace instances gradually, one or a few at a time, while the rest continue serving traffic. At no point is the entire service offline. Kubernetes implements this natively via the `RollingUpdate` strategy in a Deployment spec.

A minimal Kubernetes rolling update configuration:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # allow 1 extra pod above desired count
      maxUnavailable: 0  # never reduce below desired count
  minReadySeconds: 30    # pod must be ready for 30s before next rolls
```

The two parameters that govern rolling behavior are critical. `maxSurge` controls how many extra pods can exist during rollout — setting it to 1 means at most one pod above the desired replica count runs at a time, limiting compute overhead. `maxUnavailable: 0` ensures the existing pod count never drops below capacity, achieving zero-downtime at the cost of temporarily running one extra pod.

Rolling updates introduce a period of *version skew*: old and new versions serve traffic simultaneously. Your API must be backward-compatible during this window. If the new version changes a database schema in a breaking way — dropping a column that the old version reads — the rolling update will produce errors mid-deployment. Schema changes must be deployed independently, ahead of the application change, using expand-and-contract migrations.

> [!warning] A rolling update is only zero-downtime if your health checks are correctly configured. Without readiness probes, Kubernetes will route traffic to pods that have started but are not yet serving requests — producing errors that look like a bad deploy but are actually a missing probe.

@feynman

Recreate shuts everything down and starts fresh — simple but with downtime. Rolling replaces instances one at a time so traffic never fully stops — more complex but the foundation of zero-downtime deployment.

@card
id: cicdp-ch09-c002
order: 2
title: Blue/Green Deployment
teaser: Blue/Green runs two identical environments side by side and flips traffic atomically between them — giving you instant rollback and a warm standby, at the cost of doubling your infrastructure footprint.

@explanation

In a blue/green deployment, two environments exist simultaneously: the current live environment (blue) and the new version environment (green). The load balancer or DNS points exclusively at blue while green is prepared, validated, and warmed up. When green is ready, traffic is switched atomically. Blue becomes the standby.

The critical properties that distinguish blue/green from rolling:

- **Atomic cutover.** There is no mixed-version window. Either 100% of traffic hits the old version or 100% hits the new version. Version skew during the transition is eliminated.
- **Instant rollback.** If green produces errors after cutover, reverting means flipping the load balancer back to blue — an operation that takes seconds and requires no redeployment.
- **Warm standby.** Blue remains live and warmed during the green deployment. Unlike a rollback from a rolling update — which requires re-deploying the old image — blue rollback has no startup latency.

A Kubernetes implementation uses two Deployments and a Service with a label selector switch:

```yaml
# Service selector — change "version: blue" to "version: green" to cut over
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: my-app
    version: blue   # atomic flip: change to "green" to switch traffic
  ports:
    - port: 80
      targetPort: 8080
```

In AWS, blue/green is typically implemented with ALB target group switching via CodeDeploy or with Elastic Beanstalk environment swaps. Spinnaker provides a first-class blue/green pipeline stage that orchestrates the target group swap and monitors error rates during the bake period before automatically completing or rolling back the cutover.

The key constraint of blue/green is *cost*: you run double the infrastructure during every deployment. For large clusters or expensive compute, this is significant. Serverless and ephemeral compute environments reduce this cost dramatically — Lambda supports alias-based traffic shifting that approximates blue/green without duplicate capacity.

> [!info] Database state is the Achilles heel of blue/green. The cutover is atomic for compute but not for data. If green writes records in a new schema format, rolling back to blue means blue must read those records. Design your database migrations to be backward-compatible with both versions before cutting over.

@feynman

Blue/green means two full environments live at once. You deploy to the inactive one, validate it, then flip a switch to make it live. Rollback is just flipping the switch back — instant and safe, as long as you can afford to run both environments at once.

@card
id: cicdp-ch09-c003
order: 3
title: Canary Release
teaser: A canary release shifts a small percentage of live traffic to the new version and compares metrics before promoting — it is the only strategy that validates a deployment using real production traffic against real user behavior.

@explanation

The term comes from coal mining: canary birds detected toxic gases before humans were affected. In deployment, the canary is the small population of users or requests that experiences the new version first — their metrics detect problems before the full population is affected.

Argo Rollouts implements canary natively with a traffic-weighted split and automated analysis:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  strategy:
    canary:
      steps:
        - setWeight: 5    # 5% of traffic to new version
        - pause: {duration: 10m}
        - setWeight: 25
        - pause: {duration: 10m}
        - setWeight: 50
        - pause: {duration: 10m}
        # fully promoted after final pause passes analysis
      analysis:
        templates:
          - templateName: success-rate
        args:
          - name: service-name
            value: my-app-canary
```

Flagger, the alternative to Argo Rollouts, runs canary analysis as a continuous feedback loop: it adjusts traffic weight based on Prometheus metrics, Datadog metrics, or custom webhooks, and promotes or rolls back automatically without manual steps.

The metrics that canary analysis gates on determine the quality of the gate. A weak gate — only checking HTTP 5xx rate — will miss latency regressions, queue depth increases, and downstream error amplification. A strong gate monitors:

- **Error rate** — percentage of requests returning 5xx, compared between canary and baseline.
- **Latency percentiles** — p50, p95, p99 response time. A canary that is correct but 40% slower is a bad canary.
- **Business metrics** — checkout conversion rate, search click-through rate. Functional correctness is necessary but not sufficient.
- **Downstream impact** — error rates in services called by the canary. A new version that produces well-formed requests to a downstream service but with subtly different payloads can cause silent failures.

> [!warning] A canary at 1% traffic is statistically underpowered for low-volume services. If you receive 100 requests per hour and route 1% to canary, you get 1 canary request per hour — far too few to detect a 5% error rate increase with confidence. Calibrate canary weight to the traffic volume you need for statistical significance.

@feynman

A canary release sends a small slice of real traffic to the new version and watches what happens. If the metrics look good, you gradually send more traffic. If something breaks, only a small fraction of users was affected before you roll back.

@card
id: cicdp-ch09-c004
order: 4
title: Shadow Deployment
teaser: Shadow deployment sends a copy of live production traffic to the new version without routing any users to it — the new version processes real requests but its responses are discarded, making validation completely safe.

@explanation

Shadow deployment, sometimes called traffic mirroring or dark traffic testing, is the safest strategy for validating a new version under real load: the new version sees exactly what production sees, but its responses never reach users.

Istio implements traffic mirroring via a VirtualService with a mirror directive:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
    - my-service
  http:
    - route:
        - destination:
            host: my-service
            subset: stable
          weight: 100
      mirror:
        host: my-service
        subset: shadow
      mirrorPercentage:
        value: 100.0  # mirror 100% of traffic to shadow
```

The shadow subset receives every request but Istio discards its response. You observe the shadow's logs, metrics, and traces — comparing error rates, latency distribution, and response payload structure against the stable version — without any user impact.

Shadow deployment is particularly valuable for:

- **High-stakes services** — payment processing, fraud detection, authentication — where even a 1% canary error is unacceptable.
- **Algorithm or model replacement** — comparing the new recommendation engine's output against the current one for accuracy before exposure.
- **Load testing under production traffic shape** — synthetic load tests cannot replicate the real distribution of request types, sizes, and concurrency patterns.

The critical operational constraint: the shadow service must not produce side effects. If the new version writes to a database, sends emails, or charges payment accounts, mirrored requests will trigger those actions twice. Shadow is appropriate for read-heavy or idempotent services. Write-heavy services require careful mutation interception — either a separate shadow database or suppression of write operations in shadow mode.

> [!info] Shadow deployment doubles the compute load on the shadow service while the mirror is active — plan capacity accordingly. Mirror at 10-25% of traffic if the shadow service cannot absorb full production load.

@feynman

Shadow deployment sends a copy of every real request to the new version, but throws away its response — users are never affected. You watch the shadow's metrics to validate behavior under real traffic with zero risk, as long as the new version doesn't cause side effects like writing to a database.

@card
id: cicdp-ch09-c005
order: 5
title: Ring Deployment
teaser: Ring deployment rolls a new version through concentric layers of users — from internal employees to early adopters to general availability — treating each ring as a validation gate before the next ring opens.

@explanation

Ring deployment formalizes the intuition behind canary into an organizational structure. Instead of routing by traffic percentage, you route by user segment — each ring is a named population with defined membership and entry criteria.

Microsoft pioneered ring deployment for Windows updates and Azure services. A typical ring structure:

- **Ring 0 — Dogfood.** Internal employees only. The team that built the feature. Highest tolerance for instability, fastest feedback.
- **Ring 1 — Internal Broad.** All employees across the organization. Catches issues that only surface at organizational scale.
- **Ring 2 — Preview / Beta.** Opted-in external users. Tech-savvy early adopters who accept instability in exchange for early access. Bug reports come with context.
- **Ring 3 — Limited GA.** A geographic region or customer segment. Validates at production scale with real business impact but contained blast radius.
- **Ring 4 — Full GA.** 100% of users. Only reached after each previous ring's metrics have satisfied the promotion gate.

Ring deployment differs from canary in two important ways. First, the unit of progression is time-gated by observation, not just traffic percentage — a ring must bake for a defined period (often days) before the next ring opens. Second, ring membership is deterministic by user identity, not stochastic by request sampling. User A always gets the new version in Ring 2; User B always gets the old version until Ring 3 opens. This consistency is critical for reproducing bugs and for A/B experiment validity.

Implementation requires a feature flag or targeting system that can route by user segment. LaunchDarkly, Split.io, and Unleash all support user targeting rules. In Kubernetes, Argo Rollouts supports ring-like progression via analysis-gated steps with manual promotion. Spinnaker supports multi-cluster canary that maps cleanly to geographic ring structures.

> [!info] Ring deployment trades deployment speed for risk containment. A full ring progression with four rings and 48-hour bake times takes eight or more days from Ring 0 to Full GA. This is appropriate for infrastructure changes and platform services — but not for hot fixes. Have an emergency lane that skips rings for critical patches, with a compensating audit.

@feynman

Ring deployment releases to employees first, then early adopters, then a regional subset, then everyone — with a validation pause at each ring. The blast radius of any bug is contained to the current ring until you choose to open the next one.

@card
id: cicdp-ch09-c006
order: 6
title: Dark Launch
teaser: A dark launch deploys new functionality to production but keeps it invisible to users — the code runs, the data writes, and the performance impact is measured before a single user can interact with the feature.

@explanation

Dark launch separates deployment from release. The feature is deployed — in production, with production data, at production scale — but wrapped in a feature flag that renders it invisible or inactive to users. The team observes its behavior in the real environment before deciding to expose it.

Facebook's development of the Like button is a canonical dark launch example: the backend infrastructure processed like counts for months before the button was visible in the UI. When the UI launched, the backend had already been validated at scale.

Dark launch use cases and their mechanics:

- **Database migration validation.** Write to both old and new schemas simultaneously (dual write). Dark-launch reads from the new schema. Compare results against old schema reads before switching reads over. This is the safest path through schema migrations in high-traffic systems.
- **Search algorithm replacement.** Run the new ranking algorithm for every search query, log its results, but show users the existing results. Offline comparison of result quality before any user exposure.
- **Infrastructure replacement.** Send requests to a new queue, cache, or storage backend in dark mode. Validate throughput, latency, and correctness before cutting traffic over.
- **Capacity planning.** Measure the CPU, memory, and I/O impact of the new feature under production traffic before it is user-visible — avoiding the surprise of a new feature that doubles database read load.

Dark launch requires discipline in flag management. Features left dark indefinitely accumulate as dead code paths. Every dark-launched feature needs a committed release date or a removal date — otherwise the flag graveyard grows and the complexity of the codebase increases with no corresponding user value.

> [!warning] Dark launch is not the same as shadow deployment. Shadow sends copies of live traffic to a separate instance with discarded responses. Dark launch runs the new code path inside the production instance — the code is live, but its output is suppressed or logged rather than shown to users. Both are valid; the choice depends on whether the new code needs to share state with production.

@feynman

A dark launch means the feature is deployed and running in production — it's just switched off for users. You can watch its performance, validate its correctness, and measure its impact before anyone actually uses it.

@card
id: cicdp-ch09-c007
order: 7
title: Health Checks and Readiness Probes
teaser: Health checks are the sensory system of deployment — without them, an orchestrator cannot distinguish a starting pod from a crashed one, and zero-downtime deployment becomes accidental rather than guaranteed.

@explanation

Kubernetes defines three probe types, each serving a distinct purpose in the deployment lifecycle:

- **Startup probe.** Runs only during container initialization. If it fails within the configured failure threshold, the container is killed and restarted. Use this for slow-starting applications (JVM warm-up, large model loading) to prevent liveness probes from prematurely killing pods that are still initializing.
- **Liveness probe.** Runs continuously after startup. If it fails, Kubernetes kills and restarts the container. Liveness detects deadlock, memory exhaustion, or crash states that the process has not yet exited from.
- **Readiness probe.** Runs continuously. If it fails, Kubernetes removes the pod from service endpoints — it stops receiving traffic but is not restarted. Readiness detects temporary unavailability: connecting to upstream dependencies, loading caches, draining a queue.

```yaml
livenessProbe:
  httpGet:
    path: /healthz/live
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /healthz/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2

startupProbe:
  httpGet:
    path: /healthz/live
    port: 8080
  failureThreshold: 30  # 30 * 10s = 5 minutes for startup
  periodSeconds: 10
```

The most common misconfiguration: using the same endpoint for liveness and readiness. If the readiness endpoint reflects upstream dependency health ("my database is reachable") and you use it for liveness too, a downstream database outage will cause Kubernetes to restart all your pods in a loop — cascading the outage into a complete service failure. Liveness should reflect only the process's own health; readiness should reflect its ability to serve requests.

During rolling updates, `minReadySeconds` on the Deployment spec forces Kubernetes to wait before considering a new pod available and proceeding to the next pod in the rollout. Set this to a value that gives your monitoring stack time to collect and evaluate the first few minutes of metrics.

> [!info] Expose a /healthz/ready endpoint that checks all dependencies the service requires to serve traffic — database connections, message broker connectivity, required feature flags. Expose a /healthz/live endpoint that checks only whether the process is alive and not deadlocked. Never conflate the two.

@feynman

Kubernetes has three health checks: startup (is the container still initializing?), liveness (is the process alive?), and readiness (is this pod ready to receive traffic?). Without readiness probes, your zero-downtime deployment is a claim, not a guarantee.

@card
id: cicdp-ch09-c008
order: 8
title: Auto-Rollback on SLO Breach
teaser: Auto-rollback closes the deployment feedback loop: instead of humans watching dashboards after every deploy, the pipeline monitors SLOs and reverses the deployment automatically when the new version degrades service.

@explanation

Manual rollback under pressure is error-prone and slow. A deployment that starts degrading at 2am will continue degrading until an on-call engineer wakes up, diagnoses the cause, and executes the rollback — a process that routinely takes 20-40 minutes. Auto-rollback compresses this to under two minutes.

Argo Rollouts implements auto-rollback via AnalysisTemplate resources that run Prometheus queries against the canary:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 60s
      successCondition: result[0] >= 0.95
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}",
              status!~"5.."}[5m]))
            /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))
```

When the success rate drops below 95% for three consecutive intervals, Argo Rollouts marks the analysis as failed and triggers an automatic rollback to the stable revision — without human intervention.

Flagger takes a slightly different approach: it runs a continuous feedback loop that adjusts traffic weight based on analysis results. If the canary metrics fail, Flagger sets traffic weight back to 0% and marks the canary as failed, then alerts via webhook, Slack, or PagerDuty.

Designing effective auto-rollback gates requires answering three questions:

- **What metrics trigger rollback?** Error rate and latency are the minimum. Add business metrics where the pipeline can query them.
- **What are the thresholds?** Thresholds too strict produce false positives that roll back good deploys. Too lenient and you miss real regressions. Derive thresholds from historical SLO baselines.
- **What is the evaluation window?** A 1-minute window catches fast failures but produces noisy rollbacks during transient spikes. A 10-minute window is more stable but means 10 minutes of degraded service before rollback. Match the window to your traffic volume and SLO tolerance.

> [!warning] Auto-rollback is not a substitute for a good deployment strategy. If you deploy directly to 100% of traffic with no canary or blue/green, auto-rollback can only engage after the damage is done to all users. Auto-rollback is the safety net — a progressive deployment strategy is the net you want to land on in the first place.

@feynman

Auto-rollback means the pipeline watches your service's error rate or latency after each deployment, and if the numbers get bad, it reverses the deployment automatically — no human required. It turns "someone has to notice and fix it" into "the system fixes itself.".

@card
id: cicdp-ch09-c009
order: 9
title: Bake Time and Promotion Gates
teaser: Bake time is the mandatory observation window between deployment and promotion — the discipline that prevents a deployment from being declared successful before the metrics have had time to show whether it actually is.

@explanation

"Baking" a deployment means letting it run in a partially-promoted state long enough for meaningful metrics to accumulate before proceeding to the next stage. The bake period is the interval during which your canary analysis, SLO monitors, or human reviewers observe real behavior.

Without bake time, deployment pipelines exhibit a common failure pattern: the deploy succeeds, health checks pass, and the pipeline immediately promotes to 100% — only for users to report errors 15 minutes later when the slow memory leak or the increased database query volume finally manifests.

A promotion gate is the formal check that must pass at the end of a bake period before promotion proceeds. Gates take three forms:

- **Automated metric gates.** Prometheus or Datadog queries evaluated against thresholds. Pass/fail is deterministic. Used in Argo Rollouts AnalysisTemplates and Flagger metrics checks.
- **Webhook gates.** The pipeline calls an external service that returns pass/fail. Useful for business logic that cannot be expressed as a metric query: "has the A/B test reached statistical significance?", "has QA signed off?"
- **Manual approval gates.** A human reviews the bake-period dashboard and explicitly approves promotion. Appropriate for high-stakes production changes, regulated environments, or changes that require business sign-off.

Calibrating bake time is empirical. Start by asking: what is the longest interval over which a bad deploy has historically appeared healthy? If you have had incidents where errors surfaced 30 minutes after deployment, your bake time must be at least 30 minutes. Common defaults:

- **Staging to production:** 30-60 minutes of automated metric gates.
- **Canary to 25%:** 10-15 minutes of automated gates at each weight step.
- **Ring promotion:** 24-72 hours of observation with manual approval between rings for platform changes.

> [!info] Bake time applies to rollback as well as promotion. When rolling back, bake the rollback candidate before declaring the rollback successful. A bad rollback target — one that was stable in the past but whose environment has since changed — is discovered during the rollback bake, not after you have committed to it.

@feynman

Bake time is the waiting period after deployment where you watch the metrics before promoting further. It's not impatience — it's the recognition that some problems only appear after a few minutes of real traffic. A promotion gate is the specific check that must pass before the bake period ends.

@card
id: cicdp-ch09-c010
order: 10
title: Deployment Orchestration Across Services
teaser: Deploying a single service is solved — deploying a set of interdependent services in the correct sequence, with coordinated rollback, is the orchestration problem that Spinnaker, Argo Workflows, and GitOps pipelines were built to address.

@explanation

Single-service deployments follow a straightforward pattern: build, test, deploy, bake, promote. Multi-service deployments introduce ordering constraints, interface compatibility requirements, and cross-service rollback coordination that cannot be managed by individual service pipelines in isolation.

Spinnaker addresses orchestration through pipeline templates with fan-out and fan-in stages. A release pipeline might:

- Deploy shared infrastructure (config maps, secrets rotation) first.
- Deploy backend services in dependency order — databases before caches, caches before API servers.
- Run integration tests across the deployed version set.
- Deploy frontend services and BFF layers only after backend integration tests pass.
- Run end-to-end smoke tests across the full stack.

GitOps (implemented via Argo CD or Flux) shifts orchestration responsibility to the Git repository. The desired state of all services is declared in Git. The GitOps controller reconciles the cluster to that state continuously. Deployment ordering is handled by sync waves in Argo CD:

```yaml
# In the Application or manifest:
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"   # deploy this before wave 2
---
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"   # deploy this after wave 1 healthy
```

Deployment orchestration must also account for rollback coordination. If a deployment of services A, B, and C succeeds for A and B but fails at C, the rollback must decide: roll back only C, or roll back A and B as well to restore a known-good version set? The answer depends on whether A and B's new versions are compatible with C's old version — which requires explicit contract documentation between services.

> [!warning] Implicit deployment ordering — where service teams deploy independently on their own schedules — is the source of most production incidents in microservice environments. Even without a formal orchestration tool, publish a deployment dependency graph and require that services respect it during releases.

@feynman

Deploying one service is straightforward. Deploying ten services that depend on each other requires an orchestrator that knows the order, can pause to run integration tests between them, and can roll back the right subset if something fails partway through.

@card
id: cicdp-ch09-c011
order: 11
title: Blast Radius and Service Mesh
teaser: Blast radius is the scope of impact if a deployment goes wrong — a service mesh gives you the traffic controls to shrink it, and a circuit breaker ensures that one bad service cannot cascade failure across the whole system.

@explanation

Blast radius is a deliberate design parameter, not an accident. Before deploying, answer: if this deployment produces errors, how many users are affected, and which downstream services are impacted? Deployment strategy is the primary tool for controlling blast radius, but a service mesh adds a second layer of defense.

Istio provides three blast-radius controls that operate independently of the deployment strategy:

- **Traffic splitting.** Route a percentage of requests to the new version via VirtualService weight rules. When combined with canary deployment, the service mesh enforces the traffic split at the sidecar layer — independent of any application code.
- **Circuit breaking.** Via DestinationRule outlier detection: if a host exceeds a configured error threshold (e.g., 5 consecutive 5xx responses), Istio ejects it from the load balancing pool for a configurable interval — preventing further traffic from reaching a degraded pod.
- **Retry and timeout policies.** Retry policies prevent transient startup errors from reaching users during a rolling update. Timeout policies prevent a slow canary from causing upstream timeouts that cascade.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: my-service
spec:
  host: my-service
  trafficPolicy:
    outlierDetection:
      consecutiveGatewayErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50  # never eject more than 50% of hosts
```

The `maxEjectionPercent` parameter is critical: without it, a bad deploy that affects all pods simultaneously would eject 100% of hosts from the pool, taking down the service completely. Capping ejection at 50% ensures the service degrades gracefully rather than failing entirely.

Blast radius thinking extends to database connections, cache invalidations, and message queue subscribers. A new version that doubles the database query rate does not just affect its own pods — it affects every service sharing that database. Blast radius analysis must traverse service dependencies, not just the deployed service.

> [!info] A service mesh does not replace a good deployment strategy — it is additive. Canary deployment limits the blast radius of bad traffic; outlier detection ejects individual bad instances; circuit breaking prevents cascading failures. Each layer catches a different class of failure.

@feynman

Blast radius is how much breaks if your deploy goes wrong. A service mesh like Istio lets you shrink it: route only a slice of traffic to the new version, automatically eject pods that are returning errors, and stop retrying requests to a broken service so the failure doesn't spread.

@card
id: cicdp-ch09-c012
order: 12
title: Approval Gates and Deployment Windows
teaser: Approval gates and deployment windows are the governance layer of deployment strategy — they encode organizational risk tolerance, regulatory requirements, and operational experience into the pipeline itself.

@explanation

Not every deployment decision should be made by automation. Approval gates and deployment windows are the mechanisms for encoding human judgment and organizational constraints into the pipeline in a structured, auditable way.

An approval gate is a pause in the pipeline that requires explicit sign-off before progression. Gate types and their appropriate use cases:

- **Engineering approval.** Required before promoting from staging to production. An engineer reviews the bake-period metrics and confirms no anomalies. Reduces the risk of automated gates missing subtle regressions.
- **Security approval.** Required for changes to authentication systems, secrets management, or network policies. Enforces a second pair of eyes on security-sensitive deployments.
- **Change advisory board (CAB).** Required in regulated industries (finance, healthcare, defense) to satisfy change management requirements. The CAB review is a pipeline gate, not a separate offline process.
- **Product approval.** Required for customer-visible features that need marketing, legal, or support readiness before release. Decouples technical deployment from business release.

A deployment window is a time constraint on when deployments may proceed to production. Common patterns:

- **Business-hours-only windows.** Deploy only during hours when full support staffing is available. Reduces on-call burden and ensures expert response is available for rollback.
- **Freeze periods.** No production deployments during major business events (Black Friday, end-of-quarter), peak traffic periods, or major holidays.
- **Maintenance windows.** Scheduled periods for infrastructure changes that require brief downtime. Pre-communicated to customers; automated deployments queue until the window opens.

In Spinnaker, deployment windows are configured as execution windows on pipeline stages. GitHub Actions implements them via environment protection rules with a `wait-timer` or required reviewer configured on the production environment.

> [!warning] Approval gates are only as effective as their audit trail. A gate that approvals can be bypassed silently — by re-running the pipeline with elevated permissions, or by skipping the gated stage — is not a gate. Every bypass must generate an alert and an audit log entry. Design the bypass as an exception path, not a hidden capability.

@feynman

An approval gate stops the pipeline and waits for a human sign-off before proceeding. A deployment window restricts when the pipeline is allowed to deploy at all. Together, they make organizational risk policies part of the pipeline — not a separate process that can be forgotten under pressure.
