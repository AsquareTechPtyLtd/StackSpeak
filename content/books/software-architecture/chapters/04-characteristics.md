@chapter
id: sa-ch04-characteristics
order: 4
title: Characteristics
summary: The "-ilities" — the qualities your architecture is supposed to deliver. Identifying which ones matter, measuring them, and protecting them under continuous change.

@card
id: sa-ch04-c001
order: 1
title: The "-ilities" Are What You're Optimising For
teaser: Architecture isn't built to be "good" in the abstract. It's built to deliver specific qualities — performance, availability, security, evolvability — and the choice of which qualities matters more than any single style.

@explanation

Every system delivers some non-functional qualities and not others. The list of qualities that show up in real systems is long: performance, availability, security, scalability, evolvability, maintainability, observability, deployability, recoverability, learnability, accessibility, durability — the list reads like an IETF taxonomy.

The architect's job: pick the three or four that matter most for *this* system and *this* business, and document the priority. Everything downstream — style, components, tools — gets evaluated against those.

Why the priority is the leverage point:

- A system optimised for availability looks different from one optimised for cost.
- A system optimised for evolvability looks different from one optimised for performance.
- The same team building "the right architecture" for two different priorities builds two different systems.

The team that doesn't agree on priorities builds something that's bad at all of them. The team that agrees can pick a direction and live with the tradeoffs.

> [!info] The number is small for a reason. A system optimised for everything is optimised for nothing. The discipline is in the cutting — what you take off the list matters more than what you put on it.

@feynman

Same instinct as picking your team's quarterly OKRs. You can't have ten; you can have three. The act of picking is the strategy.

@card
id: sa-ch04-c002
order: 2
title: Operational Characteristics
teaser: The first family — what the system does day-to-day. Availability, performance, throughput, scalability, recoverability. Mostly measured in numbers; mostly the ones that page the on-call.

@explanation

Operational characteristics describe how the system behaves while running. They're the qualities that show up on the dashboard:

- **Availability** — fraction of time the system serves requests. SLOs of 99.9%, 99.99%, etc.
- **Performance** — latency at p50, p95, p99. Time to first byte, time to interactive.
- **Throughput** — requests per second, transactions per minute, messages per hour.
- **Scalability** — how throughput grows as resources grow. Linear scaling, sub-linear scaling.
- **Elasticity** — how fast the system can scale up under load.
- **Recoverability** — how fast the system returns to normal after a failure (RTO).
- **Reliability** — does the system produce correct output under expected conditions.

These are mostly numeric, mostly testable, mostly visible to operators. The architect's job is to set realistic targets, design for them, and provide the instrumentation to measure them.

> [!warning] Five-nines availability sounds like a goal; it's a budget. 99.999% means 5 minutes of downtime per year. That ceiling shapes every dependency, every deployment, every recovery procedure. Don't promise it casually.

@feynman

Same as measuring a car's performance. Top speed, 0–60, fuel economy, range. The numbers tell you what the car is for. Operational characteristics tell you what your architecture is for.

@card
id: sa-ch04-c003
order: 3
title: Structural Characteristics
teaser: The second family — how the system holds up over time. Maintainability, evolvability, deployability, modularity. Less visible to users; what makes the system survive five years of change.

@explanation

Structural characteristics describe how the system *changes*. They're the qualities that show up over months and years, not on a request-by-request basis:

- **Maintainability** — how easy it is to fix a bug or modify behaviour.
- **Evolvability** — how easy it is to add new features.
- **Deployability** — how easy it is to ship a change to production.
- **Modularity** — how clean the boundaries between parts are.
- **Testability** — how easy the system is to verify automatically.
- **Configurability** — how the system can be adjusted without code change.
- **Portability** — how well the system moves to a new environment.

These are harder to measure than operational characteristics. The metrics are indirect: cycle time from commit to production (deployability), bug rate per change (maintainability), feature velocity over time (evolvability). But the lack of crisp numbers doesn't make them less important — they're the qualities that decide whether the system is still useful in three years.

> [!info] Operational characteristics get attention because they show up on dashboards. Structural characteristics are why teams complain about "tech debt" in retros. Both deserve architecture-level care.

@feynman

The car analogy again. Operational is "how does it drive?"; structural is "how easy is it to maintain?" A car that drives well and breaks every month isn't a good car.

@card
id: sa-ch04-c004
order: 4
title: Cross-Cutting Characteristics
teaser: The third family — security, accessibility, observability, privacy. They touch every part of the system; they can't be added later. Architecting for them up front is much cheaper than retrofitting.

@explanation

Cross-cutting characteristics affect every component:

- **Security** — auth, encryption, secret handling, audit. Every component participates.
- **Privacy** — what data is collected, where it lives, who can see it. Every data path participates.
- **Observability** — logs, metrics, traces. Every code path emits something.
- **Accessibility** — keyboard nav, screen reader, contrast. Every UI surface participates.
- **Compliance** — regulatory frameworks (GDPR, HIPAA, PCI). Every data store and flow participates.
- **Internationalisation** — locale-aware formatting, translation. Every text-producing path participates.

The defining feature: you can't add these in one place. They show up in every code path, every data flow, every interface. Retrofitting is expensive precisely because it requires touching everything.

The architecture-level mitigation: bake the patterns in at the component level. A logging library every component uses. An auth middleware every request goes through. A telemetry standard every team emits. The patterns become the path of least resistance, and new code naturally inherits the qualities.

> [!warning] "We'll add security later" is the most expensive sentence in software architecture. Security retrofits routinely cost 5-10× what designing-in would have cost — and they're never as good as the designed-in version.

@feynman

The plumbing in a house. You don't decide where the bathroom goes after the walls are up. Cross-cutting characteristics are the plumbing of software — designed in early, painful to retrofit.

@card
id: sa-ch04-c005
order: 5
title: Identifying Characteristics From Requirements
teaser: Requirements rarely call out architectural characteristics by name. They sneak in through phrases like "the system must support" or "users expect." Translating them into -ilities is the architect's first move.

@explanation

A typical product requirement: "The system needs to support 50,000 concurrent users with sub-second response times, and we're planning to expand to three new regions by year-end."

Hidden inside that one sentence:

- **Scalability** — 50,000 concurrent users.
- **Performance** — sub-second response times.
- **Geographic distribution / fault tolerance** — three new regions.
- **Elasticity** — implied; can the system scale on demand.
- **Availability** — implied; cross-region usually means SLO commitments.

The translation from product language to architectural language is what the architect contributes in the requirements meeting. Without it, the requirements get implemented and the architect is surprised that the result doesn't scale.

The discipline:

- **Read every requirement looking for hidden characteristics.** Words like "support," "expected," "large," "many" are signals.
- **Surface what you found in writing.** A characteristics list with priorities, agreed by stakeholders.
- **Re-read on every requirement change.** New requirements often reveal new characteristics that were latent.

> [!tip] Keep a running list of characteristics for the system as it evolves. Every quarter, re-rank. The list moves; the architecture should know when it has.

@feynman

Same instinct as reading a contract for what's between the lines. The product manager says "performant"; the architect hears "p99 < 500ms." Translation is most of the value.

@card
id: sa-ch04-c006
order: 6
title: Domain Concerns Drive Priorities
teaser: Different domains rank characteristics differently. Banking optimises for security and consistency; gaming for latency; e-commerce for availability. Get the ranking wrong and you ship the wrong system.

@explanation

There's no universal "good architecture." A system that's brilliant for one domain is wrong for another. A short tour of the typical priority orders:

- **Banking / finance** — security, consistency, auditability, durability. Performance and developer experience are second-tier.
- **Trading / real-time** — latency, throughput. Everything else is negotiable.
- **E-commerce** — availability, scalability, performance. Eventual consistency is acceptable; a checkout being down for an hour isn't.
- **Healthcare** — privacy, security, auditability, reliability. Latency is forgivable; a HIPAA violation isn't.
- **Gaming** — latency, scalability, fault tolerance. Players notice 100ms; they don't notice an eventually-consistent leaderboard.
- **Internal tools** — maintainability, deployability. Few users; the value is in moving fast.
- **Public APIs / dev tooling** — backward compatibility, documentation quality, deployability.

The exercise that surfaces priorities: have the team rank a list of 8-12 characteristics. Surface disagreements. The argument is the design conversation.

> [!info] Most architectural mistakes come from importing a priority order from a previous job that doesn't apply to the current domain. The Netflix architecture isn't the right architecture for a hospital system.

@feynman

Same as picking equipment for the job. A racing car and a cargo truck are both vehicles; one is bad at the other's job. Domain decides which "vehicle" the architecture should be.

@card
id: sa-ch04-c007
order: 7
title: Measuring Characteristics
teaser: A characteristic you can't measure is a wish. Each prioritised -ility needs a metric, a target, and a way to verify it in production.

@explanation

Once the priorities are set, each one needs operational substance:

- **Availability** — SLO percentage. Measured by uptime monitoring; verified against synthetic + real-user metrics.
- **Performance** — p50/p95/p99 latency targets. Measured with APM tools; verified with load tests.
- **Scalability** — target requests per second under fixed resources, or marginal cost per added user. Measured under load.
- **Maintainability** — cycle time from bug report to fix. Measured from issue tracker.
- **Deployability** — time from commit to production, frequency of deploys per week. Measured from CI/CD pipeline.
- **Security** — number of CVEs unaddressed, time to patch critical vulns. Measured from security scanner.
- **Observability** — fraction of requests with full traces, log coverage. Measured from telemetry stack.

The metric matters because it makes the abstract concrete. "We care about availability" is talk; "we maintain 99.95% uptime measured against the user-facing health endpoint, with budget review when we drop below 99.9% in any quarter" is engineering.

> [!warning] Don't pick a metric you can't measure today. The metric that requires building observability infrastructure first is a metric that will never get measured. Start with what's instrumented; add metrics as you add observability.

@feynman

Same instinct as KPIs in any business. You measure what you care about; you care about what you measure. Architectural characteristics earn their priority by getting measured.

@card
id: sa-ch04-c008
order: 8
title: Fitness Functions for -ilities
teaser: A characteristic you measure once is a snapshot; a characteristic you measure continuously is a property of the architecture. Fitness functions automate the continuous part.

@explanation

A fitness function for an architectural characteristic is just a test that runs in CI (or production) and asserts the characteristic is being met. It catches drift before it becomes a regression.

Examples:

```python
# Performance fitness function
def test_p99_latency_under_threshold():
    results = run_load_test()
    assert results.p99_ms <= 200, f"p99 latency regressed to {results.p99_ms}ms"

# Maintainability — module size limit
def test_no_module_over_500_loc():
    for module in source_modules():
        assert lines_of_code(module) <= 500

# Security — no secrets in code
def test_no_secrets_in_repo():
    assert run_secret_scan() == []

# Deployability — pipeline length
def test_pipeline_under_15_minutes():
    last_runs = ci_pipeline_durations(last=10)
    assert max(last_runs) <= 15 * 60
```

These run automatically. When someone violates a rule, the build fails with a clear message. The architecture stays consistent because the rules are encoded, not just remembered.

The 2024-25 wave of architecture-as-code tools — ArchUnit, NetArchTest, Pyverse, Structurizr, dependency-cruiser, Backstage — make this practical at scale. Pick one that fits your stack and start small.

> [!info] Three or four well-chosen fitness functions catch more drift than a 30-page architecture document nobody reads. Encoded rules beat written rules every time.

@feynman

Same instinct as having tests for code. The test runs every commit; the document gets read once. Fitness functions are how architecture gets the test treatment.

@card
id: sa-ch04-c009
order: 9
title: Trade-offs Between Characteristics
teaser: Optimising for one -ility almost always costs another. The architect's craft is in knowing which trades are real and which are myth — and picking deliberately.

@explanation

Characteristics fight each other. The interesting craft is knowing which fights are real:

- **Availability vs consistency (CAP)** — under partition, you pick one. Real, well-known, unavoidable.
- **Performance vs evolvability** — caching, denormalisation, hand-tuned code all give performance; they all hurt evolvability.
- **Security vs developer experience** — every auth check, every encrypted boundary, every audit log adds friction.
- **Maintainability vs performance** — abstraction layers help maintainability and add latency.
- **Scalability vs simplicity** — distributed systems scale; they aren't simple.

The skill is knowing which trades you're making and explicitly accepting them. The architects who get into trouble are the ones who pretend they can have everything — and end up shipping a system that's a compromise on every dimension.

A useful exercise: for each pair of prioritised characteristics, write down which side wins when they conflict. The order of priorities is what tells the team what to do when reality forces a choice.

> [!tip] Document the trade-offs, not just the priorities. "We optimise for availability over consistency" is more useful than "availability is priority 1." The trade is the actionable bit.

@feynman

Same as picking a phone plan. More minutes means less data; more data means less storage. There is no plan with everything; the choice is which thing you want most.

@card
id: sa-ch04-c010
order: 10
title: Characteristics Change Over Time
teaser: A startup at 100 users cares about evolvability and cost. The same product at 10 million users cares about availability and security. Architectures that don't adjust their priorities ossify and break.

@explanation

The priorities you set at year one rarely match the priorities you need at year five. The reasons are predictable:

- **User base grows** — performance and scalability climb the priority list.
- **Regulatory exposure grows** — security, privacy, audit climb.
- **Team grows** — maintainability and team independence climb.
- **Product matures** — evolvability matters less; reliability and cost matter more.
- **Technology shifts** — new platforms make some characteristics easier; new threats make others harder.

The architect's role isn't just setting the priorities at the start; it's revisiting them. A useful cadence:

- **Quarterly** — informal review of the priority list. Anything moved? Anything new on the horizon?
- **Annually** — formal review with leadership. Update ADRs that depend on the priorities.
- **On major shifts** — IPO, acquisition, regulatory change, product pivot, scale milestone. The priorities likely changed; the architecture should know.

The teams that don't revisit ship architectures that look right by old priorities and wrong by current ones. They get caught flat-footed when the new requirement collides with the old design.

> [!warning] The architecture that worked for the demo isn't the architecture that works at scale. The architecture that worked at scale isn't the architecture that works at maturity. Pretending the priorities are static is how you end up with a Big Rewrite.

@feynman

The same lesson as in any long-running project. The priorities of week one aren't the priorities of year three. The team that re-asks "what are we actually optimising for now?" is the team that stays effective.
