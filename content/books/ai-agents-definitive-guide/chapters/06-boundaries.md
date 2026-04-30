@chapter
id: aiadg-ch06-boundaries
order: 6
title: Boundaries
summary: Sandboxes, allowlists, budgets, and audit logs — the engineering that keeps a helpful agent from quietly turning into an expensive incident.

@card
id: aiadg-ch06-c001
order: 1
title: Most Rogue Agents Aren't Malicious
teaser: An agent doesn't have to be jailbroken to do damage. The dangerous ones are the polite, helpful ones that drift one step past where they should have stopped.

@explanation

The mental model from security textbooks — a malicious actor trying to break in — doesn't fit most agent failures. The agents that hurt production are the cooperative ones. They're trying to help. They take an action that's technically allowed, then chain into another, then another, and somewhere along the way the cumulative effect crosses a line that no individual step did.

A useful image: an over-eager intern who never sleeps and has all your credentials. They'll never pull a fire alarm. They'll *just* tidy up the database, *just* sync the deployment, *just* normalise that customer record. By the end of the week, half the things they touched are subtly wrong.

This chapter is about containment, not adversarial defence. Prompt injection and jailbreaks have their own chapter. Here we deal with the agent that's behaving exactly as designed and still ends up causing problems.

> [!info] The right question is not "how do I keep this agent from going rogue" but "what's the smallest blast radius I can give it while still letting it do useful work."

@feynman

The intern with admin access. Not evil — just enthusiastic — and accidentally capable of a lot of damage. The job isn't to fire them; it's to give them appropriate permissions for the actual task.

@card
id: aiadg-ch06-c002
order: 2
title: System Prompts Are Not Containment
teaser: "Don't delete files" in the system prompt is a hint. It's not a guarantee. Trust it for tone, not for safety.

@explanation

System prompts are persuasive, not enforced. The model reads "you must not modify production data" and most of the time obeys. But "most of the time" is not a security property. A model under pressure — confusing instructions, unfamiliar tools, prompt injection from a tool result — can talk itself into the prohibited action and then talk itself into believing it was the right call.

What system prompts are good for:

- **Tone, persona, and style** — voice carries through even when content drifts.
- **Default behaviour** — what to do in the common case.
- **Soft preferences** — when there are several valid choices, lean this way.

What system prompts are not good for:

- **Hard limits on what the agent is allowed to do** — that lives in the tool layer, not the prompt.
- **Authorisation** — "only managers can approve refunds" is a runtime check, not a system-prompt sentence.
- **Auditable policy** — you can't show a regulator a paragraph of natural language and call it a control.

> [!warning] Anyone shipping security via prompt instructions is one prompt-injection screenshot away from a bad week. Move policy into code.

@feynman

A sign that says "please don't take the cookies" works on most people. It's not the same as locking the cookies in a cabinet. Both have a place; neither is the other.

@card
id: aiadg-ch06-c003
order: 3
title: The Tool Surface Is the Real Surface
teaser: An agent can only do things its tools let it do. Limiting the agent's capabilities isn't a prompt problem — it's a question of which functions you bind to its name.

@explanation

The model is a brain in a jar. The jar's openings are the tools you give it. If `delete_user` isn't in the tool list, the agent literally can't delete a user, no matter how thoroughly someone jailbreaks it.

This makes tool-surface design the highest-leverage security work in agent engineering. The questions to ask before binding a tool:

- **Does the agent need this for the actual task?** If not, leave it out.
- **Is there a narrower version of the same tool?** `update_user_email` is safer than `update_user`.
- **Does this tool need authentication?** Pass scoped credentials, not the global ones.
- **What's the worst irreversible thing this tool can do?** Decide whether you can live with that on a bad day.

A tool catalog grows by accretion — engineers add tools when needed and rarely remove them. Curate aggressively. The agent that has fifty tools available and uses three of them on a typical task is paying a cognitive tax (the model has to read all fifty) and a security tax (forty-seven of them are unused attack surface).

> [!info] Different agent roles deserve different tool sets. The "research" agent doesn't need the "deploy" tools. Per-role tool catalogs are cheap to build and pay back the moment something goes sideways.

@feynman

The principle of least privilege, applied to language models. The agent gets the tools required for the job and not one more.

@card
id: aiadg-ch06-c004
order: 4
title: Permission Modes
teaser: Auto, ask, deny — three modes per tool, picked by what's at stake. The runtime enforces; the model doesn't get a choice.

@explanation

A useful pattern, popularised by Anthropic's Claude Agent SDK and Computer Use: every tool declares a permission mode that the runtime enforces before the tool runs.

- **Auto** — the agent can call this tool freely. Used for read-only or trivially reversible operations: search, fetch, render.
- **Ask** — the runtime pauses and prompts the human before executing. Used for actions with real-world cost: send email, create record, charge card.
- **Deny** — the tool exists in the catalog but cannot run in this session. Used to scope an agent down to a specific role without rebuilding the catalog.

The matrix changes per environment. Same agent in a sandbox: most tools auto. Same agent in production: same tools shift to ask or deny. The runtime, not the model, decides which mode applies.

```python
tools = [
    Tool("search_docs",     mode="auto"),
    Tool("create_ticket",   mode="ask"),
    Tool("delete_ticket",   mode="deny"),
    Tool("send_email",      mode="ask"),
]
```

> [!tip] Make "ask" the default for any tool with side effects. It's annoying for a week; it pays for itself the first time something would have gone sideways.

@feynman

Same idea as `sudo` configured per command. Some commands need no prompt; some prompt every time; some are flat-out off the menu.

@card
id: aiadg-ch06-c005
order: 5
title: Sandbox the Execution Environment
teaser: An agent that runs code or uses a computer should run inside something disposable. When it goes wrong — and occasionally it will — you destroy the sandbox, not the host.

@explanation

The moment an agent gets to execute code, run shell commands, or drive a browser, the file system and network become the attack surface. The defence is isolation: the agent doesn't run on your laptop or your production server; it runs in an ephemeral environment you can throw away.

The 2026 toolbox for sandboxing:

- **Containers (Docker, Podman)** — fast to spin up, decent isolation, fine for code execution that doesn't need real privilege boundaries.
- **MicroVMs (Firecracker, Cloud Hypervisor)** — hardware-virt boundaries, milliseconds to start. The right call for multi-tenant code execution.
- **Cloud sandbox services** (E2B, Modal, Daytona) — managed code interpreters that handle the lifecycle for you.
- **Browser sandboxes** (Browserbase, Playwright clusters) — disposable browser sessions for Computer Use and web-driving agents.

What goes inside the sandbox: read-only mounts of the working files, scoped credentials, network egress allowlists, time and resource limits. What does *not* go inside: production credentials, customer data the agent doesn't need, anything you couldn't afford to lose.

> [!warning] "We'll just run it in a container" is the right starting answer and the wrong final answer for production. Containers leak — escapes are rare but real. For code from untrusted sources, microVM-class isolation is the floor.

@feynman

Same instinct as running untrusted code in a VM. You wouldn't `curl | sh` from a stranger; don't let an agent execute its own ideas on your bare host either.

@card
id: aiadg-ch06-c006
order: 6
title: Network Egress Allowlists
teaser: An agent with internet access has a global tool. An agent with internet access *and* an allowlist has a controlled tool. The difference is what it can talk to on a bad day.

@explanation

The default for "this agent can use the internet" is too broad. It can fetch your S3 bucket, your internal services, paste data into pastebin, and call any API on the internet. The mitigation is per-agent egress policy:

- **Default deny** — the sandbox starts with no outbound network.
- **Allowlist what's needed** — explicit hostnames for the APIs the agent must reach (`api.openai.com`, `your-internal-api.example.com`, `wikipedia.org`).
- **Block internal services unless required** — even on the same VPC, the agent should not be able to reach the database, the metadata service, or the secrets manager.
- **Log every request** — destination, payload size, response code. Not the bodies (privacy) — the metadata.

For agents that need broad web access (research agents, scraping agents), invert the default: allow general egress but block known-sensitive destinations and rate-limit aggressively.

> [!info] AWS metadata service (`169.254.169.254`) is the canonical hole. An agent that can reach it from inside an EC2 instance can extract IAM credentials. Block it explicitly, every time.

@feynman

Same as firewall rules for a service. The default is "talk to nothing"; you open holes one by one for the things that actually need to happen.

@card
id: aiadg-ch06-c007
order: 7
title: Argument Gates and Allowlists
teaser: It's not enough to give the agent the right tools. Some tools should accept only a narrow set of inputs, and the runtime — not the model — should enforce that.

@explanation

A `delete_record(table, id)` tool is dangerous in part because `table` is unconstrained. The agent could pass any table name. The fix is an allowlist at the runtime layer: the tool declares a set of valid `table` values, and the runtime rejects calls that violate it.

Patterns worth using:

- **Enum validation** — argument must be one of N pre-declared values. The model can pick; it can't invent.
- **Pattern matching** — IDs match a regex, paths stay under a prefix, URLs match a domain set.
- **Range bounds** — numeric inputs clamp to sensible ranges (`max_results <= 50`).
- **Cross-arg consistency** — `start_time < end_time`, `from != to`.

The validation lives in the tool wrapper, not the tool body. The body assumes inputs are already valid. Every gate is auditable, testable, and changeable without retraining the model.

```python
@tool
def update_record(table: TableName, id: str, fields: dict):
    assert table in ALLOWED_TABLES
    assert is_valid_id(id)
    assert set(fields).issubset(MUTABLE_FIELDS_BY_TABLE[table])
    return db.update(table, id, fields)
```

> [!tip] Validation errors should be informative — "table 'sessions' is not modifiable; allowed: [users, profiles, settings]" — so the model can correct on retry instead of guessing again.

@feynman

Type-checked function arguments, just enforced at runtime instead of compile time. The model is your dynamic caller; the gate is your defensive runtime check.

@card
id: aiadg-ch06-c008
order: 8
title: Budgets — Tokens, Tools, Time
teaser: A misbehaving agent doesn't fail with a stack trace; it fails by burning resources until someone notices. Budgets turn slow-motion failures into fast-stop alerts.

@explanation

Three budgets every production agent should respect:

- **Token budget** — total input + output tokens per task. Stops the agent that gets stuck in a thought loop.
- **Tool call budget** — number of tool invocations per task. Stops the agent that calls `search` 200 times instead of giving up.
- **Wall-clock budget** — total runtime per task. Stops the agent waiting on a hung tool.

When a budget is exceeded, the runtime stops the agent, returns a controlled error, and emits a metric. The user sees a "couldn't complete this — exceeded budget" response; the on-call sees a clean signal in the dashboard.

```text
budget = TaskBudget(
    max_tokens=200_000,
    max_tool_calls=20,
    max_seconds=120,
)
```

The numbers depend on the task. A research agent gets a generous tool-call budget; a customer-support agent doesn't. Keep them per-agent rather than global.

> [!warning] The agent that consistently runs into the budget tells you something — either the budget is wrong, or the task is wrong, or there's a bug. Don't quietly raise the limit; investigate first.

@feynman

CPU and memory limits on a container. The container that hits the limit doesn't crash the host; it gets killed and you investigate. Same shape, applied to agent runs.

@card
id: aiadg-ch06-c009
order: 9
title: Capability Tiers
teaser: Group tools by what they can affect. Tier the agent's run by how many of those affect-classes it's allowed to touch in this task.

@explanation

A useful exercise: classify every tool by its blast radius and treat tiers as units of access.

- **Read-only / informational** — search, fetch, render. Cheap to grant; reversible.
- **Reversible mutation** — draft, queue, schedule. Real but recoverable; usually safe to grant with logging.
- **Side-effecting** — send, charge, deploy. Reversible only with effort. Gate explicitly.
- **Irreversible / privileged** — delete, force-merge, transfer-funds. The "are you sure" tier; usually requires a human approval.

A task declares which tiers it operates in. A "research the user's question" task is read-only; a "draft a response" task adds reversible-mutation; a "send the response" task adds side-effecting. The runtime only exposes tools at or below the declared tier.

The benefit is composability: the same agent can be run in low-tier mode for exploration and high-tier mode after explicit promotion, without rebuilding the tool catalog.

> [!tip] Promotion between tiers should be auditable — log who approved the bump, when, and for what task. "Promote to side-effecting tier" should not be a silent flag flip.

@feynman

The same role-based access control idea every backend team has shipped. Now you're applying it to a worker that thinks in English instead of SQL.

@card
id: aiadg-ch06-c010
order: 10
title: Audit Logs as Defensible Records
teaser: Save what the agent did and why. Compliance, debugging, and trust are all the same problem — they all require a record someone other than the developer can read.

@explanation

An agent that takes action without leaving a record is unauditable, indistinguishable from a glitch, and impossible to explain after the fact. The audit log is the defensible record of what happened. It needs to outlive the run.

What goes in:

- **Inputs** — original request, user identity, session context.
- **Decisions** — which tools were chosen and why (the model's thought, where applicable).
- **Actions** — every tool invocation with arguments and result.
- **Outcomes** — final answer, side effects produced, identifiers of resources touched.
- **Approvals** — when a human approved a step, who and when.
- **Resource cost** — tokens, latency, $ — for capacity planning and post-incident analysis.

Make the format machine-readable. A regulator, an auditor, or your own engineer at 3 AM should be able to grep for "every action this agent took on resource X in the last 30 days" and get a definitive answer.

> [!info] Logs are also evidence in the other direction. When a customer claims the agent did something it didn't, the log is what closes the case.

@feynman

Same as a flight data recorder. Boring on a normal day, irreplaceable when something goes wrong.

@card
id: aiadg-ch06-c011
order: 11
title: Capability Escalation Detection
teaser: The agent that called twenty unrelated tools in one session was probably looking for a way around a constraint. Spot the pattern; alert on it.

@explanation

Agents drift towards capability accumulation. A run that starts as "answer this question" gradually opens more tools, browses more pages, calls more APIs — sometimes for the right reasons, sometimes because the task was never going to fit the original scope. The patterns worth alerting on:

- **Tool diversity** — a single run touching tools from multiple capability tiers (read + mutate + side-effect) is unusual; investigate.
- **Repeat invocation** — the same tool called more than N times with similar args looks like a loop.
- **Argument drift** — tool calls where arguments expand over the run (broader queries, wider date ranges, more permissive filters).
- **Off-task tool use** — a customer-support agent calling deployment tools is, at best, a misconfigured tool catalog.

These don't need to be hard blocks. They can be soft signals — flag the run for review, surface it on a dashboard, sample for human inspection. The goal is to make pattern-level escalation visible the way you'd surface a CPU spike on a server.

> [!warning] Alert thresholds drift. If a "normal" run trips the escalation alarm 30% of the time, the alarm is worthless and the team will ignore the real ones. Tune monthly against actual traffic.

@feynman

Anomaly detection for behavior, not just metrics. Same intuition as fraud detection on credit cards — you don't need to know the next attack, you need to know what normal looks like.

@card
id: aiadg-ch06-c012
order: 12
title: Boundaries Are a Feature, Not a Restriction
teaser: Users trust agents that say no. The agent that pauses for permission feels safer than the one that always proceeds — even when both produce identical outputs.

@explanation

Engineers tend to think of governance as a tax on the agent's autonomy: the more boundaries, the less powerful the system. Users experience the inverse. An agent that says "I'm about to charge your card — confirm?" feels professional. An agent that silently charges feels reckless, even when the charge was correct.

The product implications:

- **Surface the gates** — show the user when the agent is about to do something irreversible. The pause is the trust signal.
- **Explain the boundaries** — "I can read these documents but not modify them" is a reassurance, not a limitation.
- **Honour the no** — when a user rejects an action, the agent should not try a workaround. "Got it, won't do that" is the only correct response.
- **Audit on demand** — let the user see what the agent did. Transparency converts an opaque system into a tool the user feels they own.

The agents that ship and stay shipped tend to err on the side of more boundaries, more pauses, more visible audit trails. The ones that try to feel "magic" by silently doing more often end up trusted less.

> [!info] Pro-grade products are starting to compete on this surface — Computer Use products, IDE agents, voice assistants. The visible boundary is becoming a feature buyers ask about, not a footnote.

@feynman

Same lesson as good UX in any system that takes action on the user's behalf. Confirmation dialogs annoy us right up until the moment they save us, after which they're the most loved part of the product.
