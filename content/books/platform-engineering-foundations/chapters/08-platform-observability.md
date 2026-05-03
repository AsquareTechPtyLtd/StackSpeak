@chapter
id: plf-ch08-platform-observability
order: 8
title: Platform Observability
summary: A platform team has its own observability needs — DX metrics like deploy frequency and lead time, platform-health metrics like API gateway latency, and the meta-question of whether the platform itself is healthy enough to keep its SLA to its users.

@card
id: plf-ch08-c001
order: 1
title: Observability of the Platform Itself
teaser: Most teams instrument their applications; fewer ask who is watching the platform that runs them — but when the platform goes dark, every team it serves goes dark with it.

@explanation

Application observability is well understood: you instrument services, collect traces in Honeycomb or Jaeger, aggregate logs in Datadog or Grafana Loki, and alert when error rates spike. Platform observability asks a harder version of the same question. When the internal developer platform (IDP) itself is slow, broken, or silently degraded, no single application team will have full visibility into what happened. They will see symptoms — pipelines failing, scaffolding hanging, deployments timing out — but not the root cause.

The framing that makes this concrete:

- The platform team is a service provider. Its customers are internal engineering teams.
- A service provider that cannot observe its own service cannot reliably keep its commitments to those customers.
- Platform observability is not about monitoring the applications running on the platform. It is about monitoring the delivery substrate — the CI/CD pipelines, the IDP API layer, the golden path templates, the secrets management backend, the infrastructure provisioning layer.

What this means in practice:

- The platform team needs its own dashboards, its own alerting, and its own on-call rotation — not shared ownership with the application teams it serves.
- Signals must cover both availability (is the system up?) and quality (is it responding acceptably?).
- The platform team must be able to answer "was the platform healthy during that outage?" before any postmortem can accurately assign root cause.

> [!info] OpenTelemetry is increasingly used to instrument the platform layer itself — exporting traces from CI pipeline orchestrators, provisioning APIs, and IDP backends — using the same vendor-neutral SDK that application teams already use.

@feynman

Observing the platform is like putting a speedometer in the car that all your drivers share — if no one is watching it, a transmission problem will look like a driver problem until it is too late.

@card
id: plf-ch08-c002
order: 2
title: Platform SLOs
teaser: An SLO is a commitment — and a platform team that has not written down what it is promising to its users has no shared definition of what "good" means or what counts as an incident.

@explanation

A Service Level Objective (SLO) is a target value for a service level indicator (SLI) over a rolling time window. For external services, SLOs are often contractually backed. For an internal platform team, SLOs function differently: they create a shared understanding with internal customers about what the platform commits to and what lies outside that commitment.

Meaningful platform SLOs typically cover three domains:

**Availability commitments** — Is the IDP API accepting requests? Is the CI/CD orchestrator processing jobs? A target like "99.5% API availability over a 30-day window" translates to roughly 3.6 hours of allowed downtime per month. That number forces a concrete conversation about what tolerance is acceptable.

**Latency commitments** — How long does a scaffold-new-service request take to complete? A p95 target like "new project scaffolded in under 90 seconds" is actionable. When the p95 climbs to 8 minutes, the SLO violation is visible and triggerable.

**Workflow success rate** — What fraction of deployments initiated through the golden path actually succeed? A 98% deploy success rate target sounds aspirational until you calculate that 2% failure on 100 deploys per day is two failed deploys every day.

The tradeoff is honesty about measurement. SLOs only work if the team measures the thing it is committing to, not a proxy. Measuring CI pipeline uptime is easier than measuring end-to-end deploy success rate — but it is not the same thing.

> [!warning] SLOs that are set and never reviewed become decoration. Revisit them quarterly: tighten when the platform has matured, and honestly reset when the team knows a target is aspirational rather than achievable.

@feynman

A platform SLO is a written promise from the platform team to every team that depends on it — the same way a restaurant commits to a wait time, so diners know whether to come back tomorrow or look for somewhere else to eat.

@card
id: plf-ch08-c003
order: 3
title: DORA Metrics — The Four Signals
teaser: The DORA research program identified four metrics that distinguish elite software delivery from average — and they measure outcomes, not activity.

@explanation

The DORA (DevOps Research and Assessment) program, founded by Nicole Forsgren, Jez Humble, and Gene Kim and detailed in *Accelerate* (2018), established four metrics as the canonical measure of software delivery performance:

**Deploy frequency** — How often does the team deploy to production? Elite teams deploy multiple times per day. High performers deploy between once per day and once per week. Low performers deploy between once per month and once every six months. Frequency is a proxy for batch size: small, frequent deploys carry less risk per deploy.

**Lead time for changes** — How long from a commit being merged to that commit running in production? Elite teams achieve under one hour. This measures how fast the delivery system turns intent into running software.

**Change failure rate** — What percentage of changes to production cause a degradation requiring remediation? Elite teams have a rate of 0–15%. This measures the quality gate built into the delivery process.

**Mean time to restore (MTTR)** — When a production incident occurs, how long does it take to restore service? Elite teams restore in under one hour. This measures resilience — not whether incidents happen, but how fast recovery happens.

The power of the DORA framework is that these four metrics are interconnected. High deploy frequency with poor change failure rate is not elite performance. All four must be healthy together.

> [!info] The DORA metrics are outcome metrics, not activity metrics. A team that measures "number of deploys" without measuring change failure rate can improve one number while making the underlying system worse.

@feynman

The four DORA metrics are like vital signs for a delivery pipeline — each one tells you something important, but a doctor who only checks your pulse is not giving you a physical.

@card
id: plf-ch08-c004
order: 4
title: The Fifth DORA Metric — Reliability
teaser: In 2023 the DORA program added reliability as a fifth metric, recognizing that fast delivery is only valuable if the system being delivered remains stable for the people using it.

@explanation

The 2023 DORA State of DevOps report formalized reliability as a fifth metric alongside the original four. The motivation: a team that deploys frequently but whose systems are frequently unavailable to users is not performing well by any meaningful definition — it is just failing fast.

Reliability in the DORA context is measured as **operational performance** — specifically, whether teams meet their own reliability targets. This is intentionally framed in terms of SLO attainment rather than a single raw metric, because the definition of "reliable" varies by system criticality.

Measurement approaches used in practice:

- SLO attainment percentage (e.g., "we met our 99.9% availability SLO in 87% of the weeks this quarter")
- Error budget burn rate (borrowed from Google's SRE practices — how fast is the error budget being consumed relative to the policy?)
- User-facing incident frequency

The addition of reliability closes a gap in the original framework. A team that achieves elite deploy frequency and fast lead time by skipping quality gates will eventually surface that shortcut as poor reliability. The fifth metric makes the tradeoff visible.

For platform teams, reliability applies twice: once to the platform itself, and once to the services their users deliver on top of the platform.

> [!tip] Error budget burn rate — consuming more than 5x the expected burn rate in a short window — is a more sensitive early warning signal than waiting for an SLO violation to accumulate.

@feynman

Reliability as a fifth DORA metric is the check that makes sure going fast and going somewhere useful are not mutually exclusive — speed without stability is just arriving at the wrong destination sooner.

@card
id: plf-ch08-c005
order: 5
title: The SPACE Framework
teaser: DORA measures delivery throughput; the SPACE framework broadens DX measurement to capture dimensions that pipeline metrics alone will never see — including how developers actually feel about their work.

@explanation

The SPACE framework was introduced by Forsgren, Storey, Maddila, Zimmermann, Houck, and Butler in a 2021 ACM Queue paper as a structured approach to measuring developer productivity and experience. SPACE is an acronym for five dimensions:

**Satisfaction and well-being** — Do developers find their work meaningful? Do they experience burnout? Survey-based, but correlated strongly with retention and long-term productivity.

**Performance** — Does the developer's work achieve its outcome? This is outcome-focused: did the feature ship, did it work, did it reduce bugs? Not "how many lines of code were written."

**Activity** — Volume of observable outputs: pull requests opened, deploys made, code reviews completed. Activity metrics are the easiest to collect and the most easily gamed. SPACE explicitly warns against using activity as a proxy for performance.

**Communication and collaboration** — How effectively does the team share knowledge, review code, and coordinate? Measured via network analysis of pull request review patterns or survey.

**Efficiency and flow** — Are developers able to work with minimal interruption and handoff? Time in meetings, context-switch frequency, and "flow state" survey items feed this dimension.

The tradeoff is measurement cost. DORA metrics are largely automatable from CI/CD tooling. SPACE dimensions like satisfaction require regular surveys with enough psychological safety to produce honest answers. Many teams start with DORA and layer in SPACE dimensions as the measurement program matures.

> [!warning] Activity metrics (commits, PRs, tickets closed) are the most tempting to measure because they require no surveys. They are also the most likely to produce Goodhart's Law failures — once a measure becomes a target, it ceases to be a good measure.

@feynman

SPACE is a reminder that developer productivity is not a single number — it has five faces, and optimizing only the ones you can measure easily is like judging a restaurant solely by how fast orders are placed, without tasting the food.

@card
id: plf-ch08-c006
order: 6
title: Platform Health Dashboards
teaser: A platform health dashboard is not a vanity display — it is the first place the platform team looks when something feels wrong, and it must show signal, not noise.

@explanation

A useful platform health dashboard answers three questions at a glance: Is everything up? Is everything performing within acceptable bounds? Is anything trending toward a problem?

The signals worth tracking on a platform health dashboard:

- **API gateway latency** — p50, p95, and p99 request latency for the IDP API or developer portal. A rising p99 often indicates queue saturation or a degraded downstream.
- **CI/CD queue depth and job duration** — How many jobs are waiting? How long are jobs taking compared to their 30-day baseline? Queue depth spikes before latency spikes.
- **Provisioning success rate** — What fraction of infrastructure provisioning requests complete successfully? Failed Terraform runs and timed-out Helm deployments should appear here.
- **Error rate by platform component** — Broken out by component so that a scaffolding service failure does not hide behind an otherwise healthy aggregate.
- **SLO burn rate** — Is the error budget consuming faster than expected?

Tools used by platform teams in practice include Grafana (widely used, open source, integrates with Prometheus, Loki, Tempo), Datadog (richer out-of-the-box alerting, higher cost), and Honeycomb (strong for trace-centric observability). The tool matters less than the discipline of defining meaningful thresholds and routing alerts to people who can act on them.

Alerting thresholds should be set at values that are actionable, not at values that are technically a violation. An alert that fires when p99 latency exceeds 200ms is useful. An alert that fires every time there is a single 500 error is noise that trains the team to ignore pages.

> [!tip] Build the dashboard before you need it. The worst time to figure out what to instrument is during an active incident when you need those signals right now.

@feynman

A platform health dashboard is the platform team's equivalent of an airplane cockpit — it does not fly the plane, but it makes the difference between noticing a problem while there is still time to respond and noticing it after something has already gone wrong.

@card
id: plf-ch08-c007
order: 7
title: User-Facing Platform Status Pages
teaser: An internal status page that tells developers whether the platform is up is not a luxury — it is the single most effective way to reduce support noise during an incident.

@explanation

When CI pipelines start failing, the first thing developers do is file tickets, ping the platform team on Slack, and assume their own code broke something. A public-facing internal status page — visible to all engineering staff — short-circuits this loop. If the status page shows a known incident, developers can stop debugging their own code and wait.

What an effective internal status page contains:

- **Current status per component** — not a single green/yellow/red for the whole platform, but per-service status: CI/CD, IDP API, secrets management, artifact registry, infrastructure provisioning. Granularity is trust.
- **Active incidents with timelines** — when the incident started, what the current hypothesis is, and when the next update will be posted. The absence of updates is itself a communication failure.
- **Incident history** — the last 30 or 90 days of incidents with their resolution summaries. This builds credibility over time and lets teams see whether the platform is trending toward stability or instability.

Tools used for this: Atlassian Statuspage (common for internal use), open source alternatives like Cachet, or a simple auto-generated page fed from the platform health dashboard.

The transparency argument: teams that trust the platform are more willing to adopt the platform's paved roads. Trust is built incrementally through consistent, honest communication during incidents — and destroyed once by a surprise downtime that had no communication attached to it.

> [!info] A status page that shows green when the platform is actually degraded is worse than no status page. Automate the status transitions from your monitoring system so that human delay cannot let the page lag behind reality.

@feynman

An internal platform status page is like a train departure board — even when the news is bad, knowing what is actually happening lets everyone make a sensible decision about what to do next.

@card
id: plf-ch08-c008
order: 8
title: Synthetic Platform Load Tests
teaser: A synthetic deploy — a scripted end-to-end workflow run on a schedule — detects platform degradation before any real user does, which is the difference between the platform team finding a problem and the platform team being told about it.

@explanation

A synthetic platform load test (sometimes called a canary or synthetic monitor) is a scripted workflow that exercises the full golden path on a fixed schedule: create a project from a template, push a change, trigger CI, deploy to a staging environment, verify the deploy succeeded, and clean up. If any step fails or takes longer than a threshold, the platform team is paged before any developer has encountered the failure.

Why this matters:

- Problems in the provisioning pipeline often have no natural user trigger until a team actually needs to create a new service. Synthetic tests ensure coverage even during quiet periods.
- Load pattern is predictable and instrumented. When a synthetic run slows down, the team knows exactly where in the pipeline the latency appeared, because every step is traced.
- Catching degradation before users report it shifts the platform team from reactive to proactive. The credibility difference is significant: "we caught and fixed this at 2am before anyone noticed" versus "we found out when six teams filed tickets simultaneously."

Implementation considerations:

- Synthetic deploys should run to an isolated environment (or a clearly marked test namespace) so they do not pollute production metrics or consume real resource quotas.
- Run frequency should match the SLO window: if the SLO is measured over 30-day rolling windows, running synthetics hourly is sufficient. If you are trying to detect transient failures, every 5 minutes is more appropriate.
- Synthetic test results should feed the same dashboard as real platform metrics — not a separate tool that the team stops checking.

> [!warning] Synthetic tests that are not maintained decay into false confidence. When the golden path changes and the synthetic script is not updated, it will pass while testing a workflow no one actually uses anymore.

@feynman

A synthetic platform load test is like sending a mystery shopper through your own store every hour — not to check on any specific customer, but to make sure the experience still works the way it is supposed to before a real customer walks in.

@card
id: plf-ch08-c009
order: 9
title: Per-Team Usage Analytics
teaser: Usage analytics tell the platform team which paved roads developers actually walk and which golden paths were paved for nobody — without that signal, investment is guided by assumption rather than evidence.

@explanation

A platform team that cannot see how its platform is being used is operating on faith. Usage analytics provide the feedback loop that makes the platform a product rather than a project.

What useful per-team usage data looks like:

- **Adoption rate by component** — What fraction of teams use the CI/CD golden path versus bring-your-own pipeline? What fraction use the scaffolding templates versus create services by hand? Low adoption on a feature the platform team invested in is a signal worth investigating.
- **Off-paved-road detection** — Which teams are provisioning infrastructure outside the IDP? Which teams have custom pipeline configurations that bypass platform guardrails? This data identifies both the teams who need re-engagement and the use cases the platform has not yet solved.
- **Version distribution** — For platform components that have versioned releases, which teams are on current versions and which are pinned to old ones? A long tail of old versions indicates either poor communication about upgrades or upgrade friction worth reducing.
- **Feature usage frequency** — Absolute usage counts reveal whether low adoption of a feature is because teams tried it and stopped or because they never found it.

Privacy and trust considerations: usage analytics on internal tooling can create friction if developers feel surveilled. The platform team's goal is to improve the product, not to rank developers. Communicate what is collected, aggregate data at the team level rather than the individual level, and close the loop by visibly acting on what the data reveals.

> [!info] Usage analytics do not replace user research. A feature with low adoption may be low because it is discoverable, usable, unnecessary, or broken — and instrumentation alone cannot tell you which.

@feynman

Per-team usage analytics are the platform team's store traffic data — they tell you which aisles people are visiting, which shelves they are ignoring, and which parts of the store nobody seems to find at all.

@card
id: plf-ch08-c010
order: 10
title: Cost Observability for the Platform
teaser: If the platform team cannot break down its own infrastructure spend by service and by team, it cannot have an honest conversation about platform ROI or explain why costs are growing.

@explanation

Platform engineering teams run real infrastructure: CI runners, artifact registries, secrets management backends, IDP services, and shared observability tooling. That infrastructure costs money, and the platform team is accountable for it — but accountability requires visibility.

Cost observability for the platform has two dimensions:

**Internal cost breakdown** — How much does each platform component cost to operate? CI/CD runners during peak hours, artifact storage, Kubernetes control plane costs, and monitoring tooling each have their own cost profile. A Grafana dashboard fed from cloud billing APIs (AWS Cost Explorer, GCP Billing) broken down by service tag gives the platform team the ability to track trends and justify investment.

**Per-team cost attribution** — Which application teams are consuming the most platform resources? A team running 400 parallel CI jobs consumes more CI runner capacity than a team running 10. Without attribution, the platform team absorbs cost that is structurally driven by team behavior. Attribution data supports conversations about quota policies, cost-sharing models, and the ROI calculation for self-service capabilities that reduce platform load.

The tradeoff: rigorous cost attribution requires tagging discipline from the start. Infrastructure resources must be tagged with team identifiers consistently before provisioning. Retrofitting tagging onto an existing platform is painful. The platforms that have good cost observability built it into the golden path templates from the beginning — every resource created via the IDP is tagged automatically.

> [!tip] Start with cost attribution at the team granularity before trying to get per-feature or per-workflow cost data. Team-level attribution is achievable with basic resource tagging; anything finer requires more sophisticated instrumentation.

@feynman

Cost observability for the platform is like itemized billing for a shared office — without it, everyone assumes someone else is responsible for the large electricity bill, and no one has the information needed to reduce it.

@card
id: plf-ch08-c011
order: 11
title: The Platform On-Call
teaser: Someone needs to be paged when scaffolding breaks at 3am — and the answer to "who?" determines whether platform reliability is owned or merely hoped for.

@explanation

Application teams have on-call rotations because production systems fail in unpredictable ways at unpredictable times. A platform team that operates without an on-call rotation is implicitly accepting that platform failures will go unaddressed until business hours. That acceptance may be appropriate for a low-criticality internal tool. It is not appropriate when the platform is the delivery substrate for dozens of teams with their own production SLAs.

What a platform on-call rotation covers:

- Alerts from the platform health dashboard (SLO burn rate, API error rate spikes, CI queue saturation)
- Synthetic monitor failures indicating end-to-end path degradation
- High-severity tickets from developer teams experiencing platform-caused blockers
- Infrastructure cost anomalies that suggest a runaway workload or misconfigured resource

Rotation design considerations:

- **Team size constraints.** A platform team of four cannot sustain a 24/7 on-call rotation without burning people out. Small teams often adopt business-hours on-call with a documented escalation path for off-hours platform failures, accepting that some incidents will wait until morning.
- **Runbook completeness.** An on-call rotation is only as effective as its runbooks. If the on-call engineer cannot resolve a CI queue jam without waking up the engineer who built the CI layer, the rotation is providing alerting coverage but not resolution coverage.
- **Handoff hygiene.** Weekly handoff notes documenting unresolved alerts, notable incidents, and in-flight investigations reduce the ramp-up cost for incoming on-call engineers.

> [!warning] An on-call rotation without runbooks trains engineers to escalate rather than resolve. Every novel incident is an opportunity to write a runbook entry — the next on-call engineer's problem is always the current one's documentation failure.

@feynman

A platform on-call rotation is the platform team making the same commitment to its users that application teams make to their users — that someone responsible will pick up the phone when things break, not just when the office is open.

@card
id: plf-ch08-c012
order: 12
title: Postmortems for Platform Incidents
teaser: A platform incident postmortem has a different audience than a service incident postmortem — its impact is measured in teams blocked, not in users affected, and its communication must cross organizational boundaries.

@explanation

When a production service has an outage, the postmortem audience is primarily the team that owns the service and its immediate stakeholders. When the platform has an outage, the audience is every team that was blocked during that window — potentially dozens of engineering teams with their own management chains, their own SLAs to external customers, and their own accountability questions.

What makes platform incident postmortems structurally different:

**Impact quantification is multi-team.** A 90-minute CI outage at 2pm on a Tuesday affects every team that tried to merge and deploy during that window. Quantifying impact requires cross-team data: how many pipeline runs failed, how many deploy windows were missed, how many teams were actively blocked. This is harder to collect than a single service's error log.

**Communication must scale.** A platform incident postmortem cannot be an internal-to-platform-team document. It must be distributed in a form that answers the questions every affected team is already asking: what happened, why, was my team affected, and what will prevent recurrence? The level of technical detail appropriate for the internal postmortem is usually too high for the org-wide summary.

**Corrective actions carry higher leverage.** A fix to the CI orchestrator prevents future failures across all teams simultaneously. The cost-benefit calculation for postmortem action items is weighted differently than for a single service: the impact of not fixing a platform weakness compounds across every team that depends on the platform.

Blameless postmortem culture, popularized by the SRE community and documented in Google's Site Reliability Engineering book, applies directly — but the facilitation challenge is larger when the affected audience spans organizational lines.

> [!info] Separate the internal technical postmortem from the external-to-the-platform-team communication. The internal document should be detailed and specific; the org-wide summary should answer "were you affected and is it fixed" without requiring the reader to understand CI orchestration internals.

@feynman

A platform postmortem is a report that must make sense to every team that was affected — which means writing it in two voices at once: the technical voice that satisfies the engineers who need to prevent recurrence, and the plain voice that satisfies everyone else who just needed to ship something that day.
