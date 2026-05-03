@chapter
id: aicr-ch08-risk-management
order: 8
title: Risk Management
summary: AI-driven mass refactoring multiplies blast radius by ~100× — and the practices that make it survivable are reversibility, gradual rollout, kill switches, and explicit staged-approval gates that keep the campaign recoverable when something goes wrong.

@card
id: aicr-ch08-c001
order: 1
title: Blast Radius Framing
teaser: A manual refactor touches one file and breaks one thing; an AI campaign touches a thousand files and can break a thousand things at once — that multiplier changes which risks deserve your attention.

@explanation

When a human engineer refactors a function, the blast radius is bounded by what they can hold in their head: one file, one module, maybe a handful of call sites. If something goes wrong, you revert one commit, the incident is over.

An AI-assisted mass refactoring campaign works at a different scale. A single pipeline run can produce diffs across 500 to 5,000 files in a few hours. That changes the risk profile in three ways:

- **Detection lag.** A subtle breakage introduced in file 1 of 5,000 may not surface in CI until you're already 4,000 files into the campaign. By then, the failure is no longer trivially isolated.
- **Correlated failures.** The AI applies the same transform to every file. If the transform has a flaw — a missed edge case, a wrong assumption about the calling convention — that flaw is reproduced identically in all 5,000 files. The failure is systemic, not random.
- **Review fatigue.** At 5,000 files, human reviewers cannot meaningfully audit every diff. The safety net that works at 10 files dissolves.

Blast radius is a useful organizing concept for the rest of this chapter. Every practice that follows — gradual rollout, kill switches, staged approval, per-file revert — is a technique for either shrinking the blast radius or making it survivable when it materializes.

Before starting a campaign, make the blast radius explicit: how many files, how many call sites, how many deployed services depend on those files. That number sets your risk budget.

> [!warning] The failure mode of a mass refactoring campaign is not one bug in one place — it is one bug reproduced identically across hundreds of files. Treat correlated failures as the primary risk, not random ones.

@feynman

Running an AI refactoring campaign is like updating the font on every printed form an organization uses simultaneously — changing one form is low risk, but changing all of them at once means a single typographical error propagates everywhere before anyone reads the fine print.

@card
id: aicr-ch08-c002
order: 2
title: Reversibility by Design
teaser: Every transform in a mass refactoring campaign should be independently revertable — and that property has to be designed in before the campaign starts, not retrofitted after something breaks.

@explanation

Reversibility is not automatic. It is a design constraint you impose on the campaign before writing a single prompt.

A campaign is reversible when:

- **Transforms are additive or swappable, not destructive.** Renaming a function and updating all call sites is reversible — you can rename it back. Deleting a field and migrating its data to a new schema is much harder to reverse, because the old data is gone.
- **Changes are confined to code, not data.** Schema migrations, data backfills, and infrastructure changes all carry state that persists after a revert. Pure code changes — updating an import path, replacing a deprecated API call — can be reverted without side effects.
- **Each file's change is independent.** If reverting file A requires also reverting files B through Z, you do not have per-file reversibility — you have an all-or-nothing campaign.
- **The before and after states are both valid.** If the codebase can run correctly with a mix of old-style and new-style code, you can roll out and roll back at any granularity. If the campaign requires 100% adoption before anything works, you have a big-bang deployment and no incremental escape hatch.

Before you start, ask: if we discover a problem at 80% completion, can we stop and revert without disrupting production? If the answer is no, the campaign needs to be restructured or broken into phases that each pass this test.

> [!tip] Prefer campaigns where the old and new patterns can coexist in the same codebase simultaneously. Coexistence is what makes gradual rollout and partial revert possible.

@feynman

Designing for reversibility is like renovating a building floor by floor and keeping each floor's original layout accessible behind temporary walls — if the new layout turns out to have problems, you can restore one floor without touching the rest.

@card
id: aicr-ch08-c003
order: 3
title: Gradual Rollout
teaser: Refactor 1% of files, validate, then 10%, validate, then 100% — the same discipline that makes production deploys survivable applies directly to AI refactoring campaigns.

@explanation

Gradual rollout is the single highest-leverage risk practice in a mass refactoring campaign. It converts a potentially catastrophic big-bang change into a series of small, observable steps.

The standard progression:

- **1% pilot.** Select a representative but low-criticality slice of the codebase — one service, one package, one hundred files. Apply the full transform. Run the test suite. Do a human review. Confirm the output matches expectations before proceeding.
- **10% expansion.** Broaden to a second wave covering roughly 10% of the total scope. At this scale, edge cases that escaped the pilot tend to surface. Look for statistical anomalies in test failure rates — a 2× increase in failures at 10% is a signal to stop, not a reason to push through.
- **50% checkpoint.** At the halfway point, validate with metrics, not just tests: runtime error rates, latency, coverage percentages. Compare before-and-after in a staging environment if available.
- **100% completion.** The final pass should feel boring. If it doesn't, something upstream was missed.

The critical discipline: **do not compress the stages under schedule pressure.** The value of a gradual rollout evaporates if you jump from 1% to 100% because the deadline is on Friday. Treat each stage gate as a real decision point, not a formality.

Define your go/no-go criteria for each stage in writing before the campaign starts. "Looks good" is not a criterion.

> [!info] Choose your 1% pilot slice deliberately — it should cover the code patterns most likely to expose edge cases, not just the easiest files to process.

@feynman

Gradual rollout in a refactoring campaign is identical to phased road construction: you repave one lane while traffic continues in the other, verify the new lane is safe, then switch everything over — rather than closing the entire road at once and hoping.

@card
id: aicr-ch08-c004
order: 4
title: Kill Switches and Feature Flags
teaser: A feature flag gives you a runtime on/off switch for the refactored code path — so that when an alert fires at 2am, you can halt the new behavior without a deploy.

@explanation

Feature flags decouple the deploy from the release. You ship the refactored code path to production, but keep it dormant behind a flag. When you're ready — and only when you're ready — you enable it, and you can disable it instantly if something is wrong.

The main vendors for managed feature flags:

- **LaunchDarkly** — the dominant commercial option; supports gradual percentage rollouts, targeting rules, and real-time flag evaluation without a deploy. SDK-native SDKs for most languages.
- **Unleash** — open-source alternative with a self-hosted or cloud option. Widely used in organizations that can't route flag evaluation through a SaaS.
- **Statsig** — combines feature flags with experimentation and metrics; useful if you want to measure the impact of the refactored code path against a control.
- **OpenFeature** — a CNCF-standardized API layer that decouples your code from any specific flag provider. Write to the OpenFeature SDK and swap the backing provider without code changes.

For a refactoring campaign, the flag is usually simple: a boolean that routes a given call site to the old code path or the new one. The value of the flag is that the kill switch exists and has been tested.

The failure mode: flags that are never tested in the off position. If no one has verified that disabling the flag actually routes to the old code path, the kill switch may not work when you need it.

> [!warning] Feature flags become permanent if no one owns the cleanup. Assign a flag expiry date and a ticket at the time you create the flag, not after the rollout is complete.

@feynman

A feature flag on a refactored code path is like a circuit breaker on a new electrical panel — you can flip it off the instant something sparks, without waiting for an electrician to rewire the building.

@card
id: aicr-ch08-c005
order: 5
title: Staged-Approval Pattern
teaser: Mandatory go/no-go checkpoints at 1%, 10%, and 50% completion ensure that a human has explicitly signed off on each phase — rather than letting automation carry the campaign forward unchecked.

@explanation

Gradual rollout defines what you do at each stage. The staged-approval pattern defines how you decide whether to proceed.

At each stage gate, the campaign pauses automatically. A designated approver — typically a tech lead, staff engineer, or platform team member — reviews the evidence and makes an explicit go/no-go call before the next wave starts. The automation does not proceed on its own.

What the approval review should include:

- **Test pass rate delta.** What percentage of tests passed before vs after this batch? A decline of more than 0.5% is a hold.
- **Diff quality sample.** A human spot-check of 10–20 randomly selected diffs from the batch. Are they doing what the campaign intended?
- **Failure categorization.** Any test failures from the batch should be categorized: pre-existing failure, expected change, or new regression introduced by the transform.
- **Runtime signal if available.** If the batch is deployed to staging, what do error rates and latency look like?

The approval is synchronous and documented. A Slack message saying "LGTM" does not count. A written sign-off in the campaign's tracking document — with the approver's name, the date, and the specific evidence reviewed — is the minimum bar.

This pattern sounds like bureaucracy. In practice, it is what lets you defend the campaign to leadership when something goes wrong, and it is what stops well-intentioned engineers from pushing through a failing batch because they're optimistic.

> [!tip] Keep staged approvals lightweight in happy-path cases — a five-minute review with a written sign-off. The rigor is there for the unhappy path, not to slow down a clean run.

@feynman

Staged approvals in a refactoring campaign are like the FAA's phased airworthiness certification — each flight envelope expansion requires an explicit sign-off from the test director before the next expansion begins, regardless of how well the previous phase went.

@card
id: aicr-ch08-c006
order: 6
title: Per-File Revert
teaser: The gold standard for campaign reversibility is being able to revert any single file's change independently — and whether that's achievable depends almost entirely on how the campaign was structured.

@explanation

Per-file revert means: if file `payments/processor.py` was changed by the campaign and that change turns out to be wrong, you can revert that file's change without touching the 4,999 other files the campaign modified.

What makes per-file revert easy:

- Each file's change is a single, atomic commit — or at minimum, the diff for each file is tracked separately so a targeted `git revert` is possible.
- The transform is idempotent and stateless at the file level: undoing the change to one file does not break other files that were also changed.
- The old and new patterns can coexist: after reverting one file, the codebase compiles and runs correctly with a mix of old and new code.

What makes per-file revert hard:

- **Shared-state transforms.** If the campaign renamed a shared constant and updated every reference, reverting one reference file without reverting the others leaves the codebase in a broken intermediate state.
- **Single-commit batch merges.** If all 5,000 files were squashed into one commit, per-file revert requires cherry-picking or manual patch application — not impossible, but labor-intensive under incident pressure.
- **Type-system coupling.** In strongly-typed codebases, changing a type signature propagates across files. Reverting one file may surface type errors in the files that depend on it.

Structure your campaign to produce one commit (or one PR) per batch, not one commit for the entire campaign. This is the minimum requirement for making per-file revert operationally feasible.

> [!info] Even if true per-file revert is impractical for your campaign, per-service or per-package revert may be achievable. Design the batch boundaries around deployment units.

@feynman

Per-file revert in a refactoring campaign is like being able to un-publish a single page of a revised regulatory document while keeping all the other pages in effect — simple if each page is independent, impossible if every page references page 1.

@card
id: aicr-ch08-c007
order: 7
title: Per-Batch and Per-Campaign Revert
teaser: When per-file revert is impractical, per-batch revert is the fallback — and understanding when you're actually in a per-campaign-revert-only situation is the most important thing to know before a campaign starts.

@explanation

Real campaigns rarely achieve clean per-file revert across the board. You need a clear-eyed view of your actual revert granularity before you begin.

**Per-batch revert** means you can undo all files changed in a given processing batch as a unit. If your campaign runs in batches of 50 files per PR, you can revert any of those PRs individually. This is realistic for most campaigns if you structure commits correctly, and it is a meaningful safety improvement over all-or-nothing.

Tradeoffs of per-batch revert:

- Finer batches (10–20 files) make revert cheaper but multiply the number of PRs and review load.
- Coarser batches (200–500 files) reduce operational overhead but increase the blast radius of any single bad batch.
- A batch size of 50–100 files is a common practical starting point, with adjustment based on review capacity.

**Per-campaign revert** — reverting the entire campaign — is sometimes the only realistic option. This is acceptable when:

- The campaign is fully automated and can be re-run once the root cause is fixed (the cost is time, not manual rework).
- The scope is small enough that a full revert is low risk (hundreds of files, not tens of thousands).
- All changes were squashed into a single tagged commit, making `git revert <tag>` a one-command operation.

Per-campaign revert is not acceptable as your only option when the campaign is irreversible (data migrations, dropped code paths, dependency upgrades with no compatible downgrade path). In those cases, you need a forward-fix plan, not a revert plan.

> [!warning] "We can always revert the whole campaign" is a plan, but only if the full revert has been explicitly tested in a staging environment before the campaign goes live.

@feynman

Choosing your revert granularity before a campaign starts is like a surgical team deciding whether they can close incisions as they go or must wait until the entire procedure is finished — the answer changes the risk profile of every step.

@card
id: aicr-ch08-c008
order: 8
title: Canary Deployment
teaser: Deploy the refactored code to 1% of production traffic and compare error rates, latency, and business metrics against the control before expanding — the same technique that makes large-scale service deploys survivable.

@explanation

Canary deployment applies to refactoring campaigns whenever the output is deployed code rather than a static library or internal tooling. You deploy the refactored version to a small, representative slice of production traffic, run it alongside the original, and compare observed behavior before committing to a full rollout.

The main platforms that support canary deployments natively:

- **Argo Rollouts** (Kubernetes) — defines canary steps in a rollout manifest; supports automated analysis gates that compare Prometheus metrics against baselines before advancing.
- **Flagger** (Kubernetes) — integrates with Istio, Linkerd, or AWS App Mesh for traffic splitting; supports Datadog, CloudWatch, and Prometheus for automated pass/fail decisions.
- **Spinnaker** — pipeline-based; includes a canary analysis stage using Kayenta that compares time-series metrics between canary and baseline using statistical tests.

Key metrics to compare in a refactoring canary:

- HTTP 5xx error rate (should be flat or lower after the refactor)
- P99 latency (regression here is often the first signal of a performance problem introduced by the transform)
- Business-critical throughput metrics (orders processed, successful auth attempts) where applicable

The canary can mislead you if the 1% traffic slice is not representative. If you route only weekend traffic to the canary and your refactored code has a bug that only triggers weekday batch jobs, the canary will look clean. Be deliberate about which traffic slice you use.

> [!info] An automated canary analysis with a hard failure threshold is a stronger gate than human review of dashboards. At campaign scale, the volume of signals is too high for manual comparison.

@feynman

A canary deploy for a refactored service is like reopening a renovated restaurant with only a handful of walk-in tables before the grand re-opening — you find out if the kitchen flow actually works under real orders, not imagined ones, before you're fully committed.

@card
id: aicr-ch08-c009
order: 9
title: Shadow Traffic and Dark Launching
teaser: Shadow traffic runs the refactored code path on every real request without affecting the user — so you can compare output correctness in production before you route any live traffic to the new code.

@explanation

Shadow traffic (also called dark launching) duplicates real production requests and sends them to both the existing code path and the refactored code path simultaneously. Users receive responses from the original path only; the refactored path's responses are compared silently against the original and discarded.

This technique is valuable for refactoring campaigns because it isolates the risk completely: you're running production data through the new code, which catches environment-specific behavior that staging cannot replicate, but users are never exposed to a difference in behavior.

How it works in practice:

```text
             ┌──────────────────┐
real request │   load balancer  │──► original code path ──► response to user
             └────────┬─────────┘
                      │ mirror copy
                      ▼
             ┌──────────────────┐
             │  refactored code │──► response discarded + compared
             └──────────────────┘
```

Infrastructure that supports this natively includes Envoy's mirror filter (duplicates HTTP requests at the proxy layer) and AWS ALB request mirroring. You can also implement it in application code for less-infrastructure-heavy environments.

The comparison signal: for each mirrored request, log whether the output of the refactored path matches the output of the original. A divergence rate near zero is the green light you need before enabling the refactored path for real traffic.

Shadow traffic is not free. You're running every request twice, which roughly doubles compute cost for the duration of the test. Budget for this, and cap the mirroring percentage if cost is a constraint.

> [!tip] For pure computation-heavy code (parsers, formatters, serializers), shadow traffic with output diffing is the highest-confidence pre-production validation technique available.

@feynman

Shadow traffic is like hiring a new chef to silently cook every order alongside the existing chef, then comparing the two plates before you decide whether to switch — the dining room never sees the comparison, but you see exactly where the dishes diverge.

@card
id: aicr-ch08-c010
order: 10
title: The Panic Playbook
teaser: When an alert fires at 2am during a campaign rollout, the person on call should be able to halt, assess, and revert without needing to understand the full campaign history from scratch.

@explanation

The panic playbook is a short, written document — not a wiki page with 40 subsections, but a single page — that tells the on-call engineer exactly what to do when something looks wrong during or after a mass refactoring campaign.

It should answer five questions:

- **What are the alert conditions that mean "this is campaign-related"?** (e.g., spike in a specific error type that matches files the campaign touched, latency regression correlated with the refactored service)
- **How do I confirm the campaign is the cause?** (compare the error start time to the last batch merge; check whether affected call sites are in the campaign scope)
- **How do I halt the campaign immediately?** (the specific command or UI action to stop the automation pipeline from proceeding)
- **How do I revert the last batch?** (the specific `git revert` command, PR link, or rollback script, with exact syntax — not "revert the PR," but `git revert <sha>`)
- **Who do I contact?** (the campaign owner, the platform team contact, the SRE lead — with actual handles, not role descriptions)

The panic playbook must be written before the campaign starts, reviewed by someone other than the campaign author, and accessible somewhere the on-call engineer can find it at 2am without asking anyone.

Common failures: the playbook exists but the revert commands reference branches that have already been deleted. The playbook names a contact who is on vacation. The revert command works in staging but not in production because of environment differences. Test all three before go-live.

> [!warning] A panic playbook that has never been tested is a document, not a plan. Walk through a simulated rollback in staging before the campaign touches production.

@feynman

A panic playbook is like the laminated emergency procedure card in an airplane seat pocket — it needs to be readable under stress by someone who didn't design the aircraft, and it has to work the first time without practice.

@card
id: aicr-ch08-c011
order: 11
title: Blast-Radius Estimation
teaser: Estimating blast radius before a campaign starts — how many files, services, and users are in scope — lets you decide whether the risk fits within the organization's tolerance before any code is changed.

@explanation

Blast-radius estimation is a pre-campaign exercise, not a post-incident analysis. Its purpose is to generate a number that can be held up against your organization's current risk capacity and used to make a go/no-go decision on the campaign design.

The estimation covers:

- **File count.** How many files will be modified? Run the transform against a read-only snapshot of the codebase and count the diffs without committing them.
- **Service count.** How many deployed services include at least one modified file? A campaign that touches 500 files spread across 50 services is riskier than one that touches 500 files in a single internal library.
- **Test coverage of affected files.** What percentage of the files to be modified are covered by automated tests? Low coverage in the affected set means the safety net is thin exactly where it needs to be strong.
- **Production traffic weight.** What fraction of production request volume flows through the modified code paths? Modifying a payment processing hot path is not the same as modifying a utility used only in batch jobs.
- **Dependency exposure.** Are any modified files part of a public API, a shared library consumed by external teams, or an interface that other organizations depend on?

Combine these into a simple risk statement: "This campaign modifies 800 files across 12 services, 60% covered by tests, with 40% of production traffic flowing through at least one modified path." That statement tells you what kind of rollout plan, approval gates, and monitoring you need before you start.

> [!info] Blast-radius estimation takes a few hours and can redirect a campaign that would have taken weeks to recover from. It is the cheapest risk activity on this list.

@feynman

Estimating blast radius before a campaign is like a demolition crew walking the building to locate load-bearing walls before swinging the first hammer — the walkthrough costs an afternoon; missing a load-bearing wall costs the whole project.

@card
id: aicr-ch08-c012
order: 12
title: Layered Safety Nets
teaser: No single control — not tests, not types, not canaries — is enough on its own; the practice is to layer them so that a failure that escapes one layer is caught by the next.

@explanation

Each risk control in this chapter has a known failure mode. Tests miss edge cases. Canary deploys can be misled by unrepresentative traffic. Feature flags become stale and untested. Staged approvals get rubber-stamped. Per-file revert is sometimes impractical.

The practice is not to find the one control that makes the campaign safe. It is to layer controls so that the probability of a failure escaping all of them simultaneously is acceptably low.

A practical layered defense for a production-impacting campaign:

- **Types and linting first.** The compiler and static analysis tools catch the broadest category of errors with the least operational overhead. For a rename or an API migration, most breakages are type errors.
- **Automated tests second.** Unit and integration tests catch behavioral changes that static analysis cannot. Target 80%+ coverage on modified files before starting.
- **Canary or shadow traffic third.** Catches runtime behavior that tests cannot replicate — race conditions, environment-specific configuration, production data shapes.
- **Feature flags fourth.** Provide the kill switch if something surfaces in production despite the earlier layers.
- **Panic playbook fifth.** Ensures that if all other layers fail, the human response is fast, correct, and doesn't require the on-call engineer to reconstruct the campaign's history from memory.

The point where teams go wrong is treating one layer as sufficient and skipping the others under time pressure. The compressive refactoring of 5,000 files deserves all five layers. A 50-file internal utility refactor might be fine with just types, tests, and a documented revert command.

> [!tip] Match the depth of your safety-net stack to the blast radius you estimated. A campaign with a narrow, low-traffic blast radius does not need all five layers; a campaign touching core business logic does.

@feynman

Layered safety nets in a mass refactoring campaign are like the independent redundant systems on a commercial aircraft — each system is designed to catch failures the others miss, because the cost of no single system being sufficient is unacceptable.
