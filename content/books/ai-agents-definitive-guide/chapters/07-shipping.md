@chapter
id: aiadg-ch07-shipping
order: 7
title: Shipping
summary: Rollouts, fallbacks, circuit breakers, on-call ownership, and unit economics — the operational concerns that decide whether the agent survives its first month in production.

@card
id: aiadg-ch07-c001
order: 1
title: The Maturity Ladder
teaser: Demo, alpha, beta, production, scale. Each step has a different question, a different stack, and a different bar for "good enough." Skip a step and you'll meet it again as an incident.

@explanation

Shipping an agent is not a single milestone. It's a sequence of stages, each gating on a different question:

- **Demo** — does it solve the core problem at all? Streamlit, hardcoded prompts, one happy path.
- **Alpha** — does it survive someone else using it? Containerised, traced, real auth, honest failure paths.
- **Beta** — can a small set of real users trust it? Fallbacks wired in, human-in-the-loop on dangerous steps, design-partner feedback loop.
- **Production** — can it run inside the actual product? SLOs, on-call, incident playbooks, integration with the rest of your system.
- **Scale** — is the unit economics sustainable? Caching, model routing, autoscaling, possibly self-hosting.

The mistake is treating these as a single checklist to power through. Each stage answers a different question; if you skip the question, the answer arrives later in a more painful form.

> [!info] Most failed agent products died because the team shipped at "alpha-with-marketing" — the demo worked for the founders, didn't survive a hundred real users.

@feynman

Same maturity model as any startup product. Idea, MVP, paying customers, scale, optimisation. The agent layer doesn't get to skip the curve.

@card
id: aiadg-ch07-c002
order: 2
title: Provider Abstraction
teaser: Wire the agent against an interface, not against a vendor. The day a competitor ships a better model — or your provider has an outage — should be a config change, not a refactor.

@explanation

The simplest way to lock yourself in is to call `anthropic.messages.create(...)` directly throughout your codebase. Every prompt, every tool, every retry depends on the exact shape of one provider's SDK. When you want to swap, you can't.

The fix is one thin layer in your own code:

```python
class LLMClient(Protocol):
    def complete(self, messages: list[Message],
                 tools: list[Tool] | None = None,
                 thinking: ThinkingConfig | None = None) -> Completion: ...

# implementations: AnthropicClient, OpenAIClient, GeminiClient,
# OpenRouterClient, plus a LocalvLLMClient for self-hosting.
```

Production code calls the protocol; a small adapter per provider handles the per-vendor shape differences (parameter names, tool format, thinking surface). Swapping providers becomes a config flag.

The point isn't multi-vendor flexibility for its own sake — it's that the day a provider has a multi-hour outage (it has happened to all of them), your customers should not be sitting in the dark.

> [!warning] Don't over-engineer the abstraction. The goal is "swap providers without rewriting the loop." Not "support every imaginable model." A protocol with five methods beats a framework with five hundred.

@feynman

Database abstraction layers, applied to model providers. You don't write `mysql_connect` directly; you don't `anthropic.messages.create` directly. The principle is the same.

@card
id: aiadg-ch07-c003
order: 3
title: Circuit Breakers
teaser: When a downstream is degraded, stop sending it traffic. The agent that politely retries through a 30-minute outage is the agent that triples your bill and doubles your latency.

@explanation

A circuit breaker tracks the recent error rate for a downstream call. When errors cross a threshold, the breaker opens and short-circuits the call — the request fails fast instead of waiting for another timeout. After a cooldown, the breaker enters a half-open state, lets a few requests through, and either closes (recovered) or stays open (still down).

For agent stacks, breakers belong on:

- **Each model provider** — track error rate per (model, endpoint). When Anthropic is degraded, fail fast and fall over to your secondary.
- **Each external tool** — third-party APIs go down. Stop the agent from looping on a 503.
- **Each retrieval index** — embedding service down? Vector DB slow? Skip retrieval and let the agent answer with whatever context it has.

When the breaker is open, the agent gets a typed error and can choose its degradation: a fallback model, a templated answer, an explicit "this is degraded" reply.

> [!info] Without circuit breakers, an agent under provider degradation can quietly multiply its costs by 5–10× through retries before anyone notices.

@feynman

Same logic as a kitchen breaker. When the toaster shorts, you flip the breaker once; you don't keep plugging the toaster in until the wires melt.

@card
id: aiadg-ch07-c004
order: 4
title: Fallback Models, Properly Wired
teaser: A fallback model isn't a config setting. It's tested, has its own prompt-tuning, and is part of your eval set. Untested fallbacks become real outages.

@explanation

The instinct to wire a fallback — "if Claude is down, switch to GPT" — is correct. The execution is usually wrong. Teams add the fallback config, never test it, and discover during the actual outage that the prompt doesn't transfer cleanly, the tool format differs, the output schema doesn't quite match.

A working fallback has its own life:

- **Tuned for the fallback model** — prompts and few-shots adjusted because models phrase things differently.
- **In the eval set** — every release runs evals on both the primary and the fallback; quality gap is tracked.
- **Tested in production** — periodic chaos testing routes 1% of traffic through the fallback to verify it still works.
- **Documented** — the on-call doc names the fallback and explains how to flip the flag.

The simpler version: shadow the fallback continuously. A fraction of every request runs through both; the shadow's response is logged but discarded. When you need to flip, you already know it works.

> [!warning] A fallback that quietly produces worse answers is a different kind of outage. Track the quality delta — if it's too large, the fallback is a wishful config, not real protection.

@feynman

Backups you've never tested aren't backups. Same lesson, different domain.

@card
id: aiadg-ch07-c005
order: 5
title: Canary and Shadow Rollouts
teaser: New prompt? New model? Don't ship to 100% on day one. Route 1% to the new path, compare, scale up only when the comparison is favourable.

@explanation

Two patterns matter for safe rollout:

- **Canary** — a small percentage of traffic gets the new version; the rest stays on the old. Monitor error rate, latency, cost, quality. Scale up gradually if metrics hold.
- **Shadow** — every request runs through *both* versions in parallel. The new version's output is logged, not returned to the user. Compare responses pairwise, surface diffs, decide whether the new version is actually better.

Canary tests behaviour under real traffic with limited blast radius. Shadow gives you a side-by-side comparison without risking user experience. Many teams use both: shadow for a week to gather A/B-quality data, then canary to actually flip.

```text
shadow phase   →  side-by-side diffs, judge model rates,
                  human eyes on a sample, decide go/no-go
canary 1% → 5% → 25% → 50% → 100%
                  watch error rate, latency, cost, eval scores at each step
```

> [!info] The dimensions you track during a rollout are the dimensions that should be in your monitoring already. If "did we just regress quality" isn't a queryable metric, fix that before you ship the change.

@feynman

Feature flags, applied to prompts and models. The same discipline that lets backend teams ship safely lets agent teams ship without prayer.

@card
id: aiadg-ch07-c006
order: 6
title: SLOs That Make Sense for Agents
teaser: p99 latency on a one-shot API doesn't translate. Define SLOs that match how users actually experience the agent — task success rate, time-to-useful-output, cost per task.

@explanation

The traditional service SLOs — p99 latency under 200ms, 99.9% availability — don't carry over cleanly. An agent task can legitimately take 30 seconds; "availability" is more about quality than uptime.

The metrics worth treating as SLOs:

- **Task success rate** — fraction of runs that produced an answer the user accepted (or that downstream metrics validated). Bumped or eroded by every prompt change.
- **Time to useful output (TTUO)** — wall-clock from request to the first useful token. For streaming agents, this matters more than total runtime.
- **Cost per successful task** — dollars per task that produced a real result. Captures degraded retries and spend on failed attempts.
- **Refusal / fallback rate** — fraction of runs that hit a fallback or returned a "I can't help with that" response. Spikes here usually mean an upstream regression.

Pair each with an alert. The team should know within minutes when one drifts off its target.

> [!tip] Don't over-define SLOs early. Three metrics watched closely beat a dashboard of fifteen no one reads. Add more only when you've outgrown the original three.

@feynman

The point of an SLO is that someone gets paged when it's missed. An SLO no one defends is documentation; an SLO with a pager is operations.

@card
id: aiadg-ch07-c007
order: 7
title: On-Call for Agents
teaser: When the agent breaks, who gets paged? If the answer is "the engineer who built it," your on-call rota is a lottery and your reliability is going to oscillate with vacation schedules.

@explanation

Agent systems become organisational orphans when there's no clear ownership. The product team wants the AI features but doesn't own the model. The infra team owns the inference but doesn't know the prompts. The data team owns the retrieval index but doesn't see the user complaints.

The fix is naming an owning team and giving them the on-call rota. Their playbook should answer:

- Which dashboards to look at first when an alert fires.
- How to roll back a prompt or model change quickly (one command, not a deploy).
- When to flip to the fallback provider.
- How to disable the agent entirely while preserving the rest of the product.
- Who to escalate to (provider support, data team, security) and when.

Without this, every incident becomes a multi-team Slack thread that resolves slower than it should. With it, the agent is just another service the team runs.

> [!warning] "We don't have an on-call yet, the agent is in beta" is exactly when you need one. Beta users are the ones who'll remember being failed.

@feynman

Same answer as for any production service. Code without an owner has no defender; the agent is no different.

@card
id: aiadg-ch07-c008
order: 8
title: User Feedback Closes the Loop
teaser: A thumbs-up button is the cheapest eval data you'll ever collect. Wire it in early and treat the signal as a first-class metric.

@explanation

User feedback is the source of truth your eval set is approximating. Capturing it well is one of the highest-ROI engineering tasks in an agent product:

- **Implicit signals** — did the user copy the answer, follow up with a clarification, or leave the session? Each is a quality proxy.
- **Explicit signals** — thumbs, star ratings, "was this helpful?" prompts. Sparse but unambiguous.
- **Free-text feedback** — when users explain why they thumbed down, the comment is gold for prompt iteration. Pipe it to a triage queue.
- **Downstream outcomes** — for agents that drive business actions (support tickets, sales emails, code commits), did the action stick? Was the ticket reopened, the email replied to, the commit reverted?

These get joined to traces so you can ask: which prompt version, model, and tool catalog correlate with the highest user satisfaction? The answer drives every subsequent rollout decision.

> [!info] User feedback also catches drift the eval set misses. The eval is what you decided to measure; the feedback is what users actually feel. They diverge over time, and the divergence is the signal.

@feynman

Customer satisfaction surveys, with the noise removed. Every interaction is a chance to ask "was that good?" and the answer is data you can train against.

@card
id: aiadg-ch07-c009
order: 9
title: Self-Hosting — When and How
teaser: Self-hosting open-weight models becomes economical somewhere north of $50K/month of inference. Below that, the API is cheaper than your time. Above that, the math flips.

@explanation

The provider APIs are the right answer for almost every team almost all the time. They're more capable, faster to integrate, easier to upgrade, and cheaper than the alternative — until you cross a usage threshold where per-token pricing dominates everything else.

Signs you're approaching the self-host crossover:

- **Cost** — your inference bill is growing faster than revenue and dominates COGS.
- **Latency** — your traffic is clustered geographically and the round-trip to the provider hurts UX.
- **Privacy / residency** — regulatory or contractual constraints make data egress a non-starter.
- **Throughput control** — provider rate limits cap your real demand and the upgrade path doesn't keep up.

When you do go self-hosted, the toolchain is:

- **Inference engine** — vLLM, SGLang, TensorRT-LLM. All competitive in 2026; pick by your GPU stack.
- **Orchestration** — Kubernetes is fine; Ray Serve and Modal abstract more.
- **Routing layer** — a model gateway in front so prompts don't depend on which GPU they hit.

> [!warning] Self-hosting is an ongoing engineering investment, not a one-time setup. New models, new quantizations, new failure modes. Budget the FTE before you budget the GPUs.

@feynman

The classic build-vs-buy curve. Buy until the bill outgrows the team; build when the bill is bigger than the team's salary.

@card
id: aiadg-ch07-c010
order: 10
title: Unit Economics at Scale
teaser: Per-task cost has to drop below per-task revenue, with margin. If it doesn't, scale doesn't fix the business — it makes the loss bigger.

@explanation

The conversation that decides whether an agent product survives is the unit-economics one. Revenue per successful task minus cost per successful task, multiplied by volume. If the product is free and the unit cost is real, you're betting on conversion to a paid tier; if the conversion isn't strong enough, the unit economics work against you.

The cost levers in order of typical impact:

1. **Prompt caching** — usually a 30–70% input-cost reduction with almost no engineering work.
2. **Routing** — sending the easy 80% of requests to the cheap model. Can halve cost.
3. **Output reduction** — shorter outputs (terser system prompts, structured outputs) save the expensive token side.
4. **Smaller models for steady-state** — once you've optimised everything else, the model itself.
5. **Self-hosting** — the heavy hammer, with ongoing carrying cost.

Track $/successful-task as a primary KPI. Review it monthly the way you'd review gross margin. A drift of even 10% per month compounds into a different business in a year.

> [!info] Some of the best agent products run at a 10× cost gap between the cheap path and the expensive path on the same task. The product spec defines which path each user lands on.

@feynman

Same arithmetic that decides whether a hardware product is viable. Cost-of-goods has to leave room for everything else; agent inference is just COGS for software that thinks.

@card
id: aiadg-ch07-c011
order: 11
title: Communicating Limits to Users
teaser: Users forgive a bot that admits it's wrong. They don't forgive one that confidently fabricated. The way you express uncertainty is part of the product.

@explanation

The biggest UX miss in agent products is performative confidence — the agent that delivers wrong answers in the same tone it delivers right ones. Users punish this hard once they catch it; trust collapses faster than it builds.

The fixes are mostly product, not model:

- **Cite when grounded** — when an answer is based on retrieved sources, show them. Users self-verify when they care.
- **Hedge when uncertain** — "I'm not sure, but it looks like..." is better than a confident error. Models can be prompted to do this; the UI can also surface the model's confidence directly.
- **Defer when out-of-scope** — "this is outside what I can help with" is a feature, not a failure. The agent that knows its limits is the agent that gets trusted on the things inside.
- **Show the work** — for long tasks, show the steps. The user can spot a wrong turn before the final answer.

These design choices live in the prompt, the response shape, and the UI together. They have nothing to do with model intelligence.

> [!tip] Test the unhappy path. The first time the agent doesn't know something is the moment that decides whether the user comes back.

@feynman

Human experts admit when they don't know. Bad agents pretend. Building "I don't know" into the product is a deliberate design choice, not an accident of training.

@card
id: aiadg-ch07-c012
order: 12
title: What Shipped vs What Stays Shipped
teaser: Launching an agent is a milestone. Keeping it good is a discipline. The teams that maintain quality at month twelve don't have a magic stack — they have a rhythm.

@explanation

Plenty of agents launch impressively and decay quietly. The ones that hold up have an operating rhythm rather than a one-time launch checklist:

- **Weekly** — review the worst-rated traces from the past week. Find the failure mode. Fix the prompt, the tool, or the eval set.
- **Bi-weekly** — re-run the eval set against current production. Track the quality trendline; investigate any drop.
- **Monthly** — review unit economics. Where did cost-per-task move? What's the cache-hit-rate trend?
- **Quarterly** — re-evaluate model choices. Has a new release changed the optimum? Run your private evals on candidates.
- **Continuously** — feedback queue triaged daily; on-call follows the standard rota; trace storage rolls correctly.

None of this is glamorous. It's the part of agent engineering that doesn't make conference talks. It's also the part that decides whether the product is still the one users prefer in a year.

> [!info] The team that ships an agent and the team that maintains it should not be the same people doing both as side work. Maintenance is a job, not a footnote.

@feynman

Same advice as for any production service. The launch is the easy part; the operations rhythm is what keeps it alive — and the rhythm is the work.
