@chapter
id: llmp-ch07-action
order: 7
title: Action
summary: The shift from "the model produces text" to "the model does things." Side effects, reversibility, approval gates, and the patterns that keep an action-taking system honest.

@card
id: llmp-ch07-c001
order: 1
title: Action Changes the Stakes
teaser: A wrong sentence is annoying. A wrong action sends an email, charges a card, deletes a row. The patterns in this chapter exist because the cost of a mistake is no longer just embarrassment.

@explanation

Up to this chapter, the model produces content. Worst case, the content is wrong and the user has to ignore it. With action, the model causes things to happen in the world. Worst case, the model causes the wrong thing — and the wrong thing has a customer, a record, or a dollar attached.

This shift demands a different posture in design:

- **Idempotency** — actions can fire twice; both firings should be safe.
- **Reversibility** — irreversible actions deserve more friction than reversible ones.
- **Approval** — the human is part of the loop where the cost of error is real.
- **Audit** — what was done, by whom, at what point.
- **Recovery** — when something goes wrong (and it will), the system needs a way back.

These aren't optional features bolted on at the end. They're the design vocabulary of any agent that takes action. The chapter is about applying that vocabulary deliberately.

> [!info] The capability chapter covered how to give the model a tool. This chapter covers how to keep the tool from being misused.

@feynman

The shift from intern who writes memos to intern with a credit card. Both can produce work; only one needs supervision around the cost of misuse.

@card
id: llmp-ch07-c002
order: 2
title: The Action Loop
teaser: Read state, decide an action, execute, observe the result, decide again. Five steps, repeated until the goal is met. The same loop that powered the agents book — applied here to the action layer specifically.

@explanation

Action-taking systems share a common shape:

1. **Read state** — current context, prior steps, user input, system state.
2. **Decide** — model picks the next action. Usually a structured tool call.
3. **Execute** — runtime invokes the action. Side effects fire here.
4. **Observe** — result is read back into context (success, failure, returned data).
5. **Loop or finish** — either the goal is met (return the answer) or the next iteration runs.

What distinguishes action loops from pure generation loops is what lives at step 3. Generation loops are pure — re-running step 3 is harmless. Action loops have side effects — re-running step 3 fires the side effect again. Every pattern in this chapter lives at the boundary of step 3.

```python
while not done(state):
    action = model.decide(state)
    if needs_approval(action):
        action = await human_approval(action)
    result = execute(action)            # side-effect boundary
    state = observe(state, action, result)
```

> [!tip] Make `execute` the only place side effects happen in your code. Everything before is planning; everything after is observation. The single boundary is what makes the rest tractable.

@feynman

Same shape as the read-eval-print loop, but with consequences. The print step is doing things, not just showing them — and that's where care concentrates.

@card
id: llmp-ch07-c003
order: 3
title: Reversibility Tiers
teaser: Not every action is equally dangerous. Read-only is free; reversible mutation is cheap; side-effecting needs gates; irreversible needs human approval. Tier them upfront and the rest follows.

@explanation

Build the tool catalog with reversibility in mind:

- **Tier 0 — Read-only / informational.** `search_docs`, `fetch_user_profile`, `render_chart`. No state changes. Approve freely.
- **Tier 1 — Reversible mutation.** `draft_response`, `schedule_task`, `update_label`. Real changes, but undo-able with low cost. Log; sometimes notify.
- **Tier 2 — Side-effecting.** `send_email`, `create_record`, `charge_subscription`. Changes the outside world. Often needs approval, always needs audit.
- **Tier 3 — Irreversible / privileged.** `delete_user`, `force_merge`, `transfer_funds`. Cost of error is high; recovery is slow. Always require explicit human approval.

The runtime enforces tier policy:

```python
TIER_POLICY = {
    Tier.READONLY:    "auto",
    Tier.REVERSIBLE:  "auto",
    Tier.EFFECTING:   "ask",
    Tier.IRREVERSIBLE: "approve_with_diff",
}

def execute(action):
    policy = TIER_POLICY[action.tier]
    if policy == "ask":
        if not user_approved(action): return None
    if policy == "approve_with_diff":
        if not user_approved_with_preview(action.preview()): return None
    return action.run()
```

The model doesn't get to decide its own tier. The tool's metadata declares it; the runtime enforces.

> [!info] When you can't decide what tier a tool belongs to, ask: how long does it take to undo this action, and is undo always possible? The honest answer usually points to the right tier.

@feynman

The same instinct as `rm` vs `mv`. Some operations move things; some destroy them. The distinction matters for how much friction you accept around each.

@card
id: llmp-ch07-c004
order: 4
title: Idempotency Keys
teaser: A retry will happen. Either the retry is safe by construction, or you guarantee it via an idempotency key. Both work — but you have to pick one explicitly.

@explanation

Production systems retry. Models retry. Runtimes retry on transient failure. Users retry by clicking again. The action that runs once and the action that runs three times need to produce the same outcome.

The standard tool is the idempotency key — a unique identifier per logical operation that the server checks before executing:

```python
@tool
def send_invoice(customer_id: str, amount: float, idempotency_key: str) -> Result:
    if seen(idempotency_key):
        return cached_result(idempotency_key)   # already processed; same response
    result = invoice_service.create(customer_id, amount)
    store(idempotency_key, result)
    return result
```

The key is generated once per logical action — typically a hash of the args plus a step ID — and reused across retries of the same logical step. The first execution does the work; subsequent calls return the cached result without re-executing.

For tools you don't control (third-party APIs), this responsibility moves to the wrapper layer in your code. Your wrapper holds the idempotency cache; the third-party API sees the same args every time and you handle the dedup before it gets there.

> [!warning] "It usually works without idempotency" is a gambler's claim. Add the key now; the retry that double-bills will happen, and you don't want to discover which user got the duplicate via their support ticket.

@feynman

The elevator button. Press it once, the elevator comes. Press it three times, the elevator still comes — once. The system was designed for retry; design yours the same way.

@card
id: llmp-ch07-c005
order: 5
title: Approval Gates with Diffs
teaser: When a human approves, show them the change — the diff, the preview, the actual data. "Approve action" without context is rubber-stamping; "approve this specific change" is real review.

@explanation

Approval gates that show only "the model wants to do X" are weak. Users approve quickly, miss errors, and lose trust the first time something slips through. Approval gates that show the diff — what changes, what the new state looks like, who's affected — are real.

Patterns that work:

- **Diff display** — for record edits, show before/after. For drafts, show the draft. For commands, show the command.
- **Affected-set preview** — "this will email 47 customers; here's the list."
- **Change explanation** — "I'm increasing the refund limit from $500 to $1000 because the customer's order qualified for the high-tier policy."
- **Confirmation phrasing** — "I will send this email to alice@example.com" is clearer than "Run send_email tool."

The approval UI is part of the action surface. If the user doesn't see what they're approving, the gate is theatre.

```text
Action: send_email
   To: alice@example.com
   Subject: Your refund has been processed
   Body: <preview>

   This will be sent immediately. [Approve] [Edit] [Cancel]
```

> [!tip] Approval fatigue is real. If users approve everything reflexively, your gates lose their power. The more selective you are about what triggers a gate, the more attention each gate gets.

@feynman

Same as the deploy preview link in a CI pipeline. The dialog says "deploy" but the click that matters is the one after the engineer reads the diff.

@card
id: llmp-ch07-c006
order: 6
title: Async Actions
teaser: Some actions take seconds; some take hours. Block the loop on the second kind and you'll have unhappy users and a lot of timeouts. The agent has to handle async like the rest of your stack does.

@explanation

Many real actions are async by nature: send an email (delivery is async), provision a resource (takes minutes), schedule a transfer (effective tomorrow). The agent can't sit and wait; the loop has to handle the gap.

Patterns that fit:

- **Fire-and-forget** — kick off the action, return immediately with a tracking ID. The agent's response is "started X; will follow up when complete."
- **Polling** — return immediately, then check a status endpoint on the next loop turn or in a background task.
- **Webhook callback** — register a callback URL with the action provider. When the work completes, the agent's session resumes (state is persisted, the callback wakes it).
- **Event-driven** — actions emit events; the agent subscribes to relevant ones and reacts when they arrive.

For long-running work, the agent's "memory" of the in-flight action has to live somewhere durable — Redis, a job queue, a workflow engine like Temporal. In-memory state doesn't survive a restart.

```python
def schedule_provision(args):
    job_id = provisioner.start_job(args)         # returns instantly
    save_pending_action(job_id, args, agent_id)  # for resume on completion
    return {"job_id": job_id, "status": "started"}
```

> [!info] Anthropic's Claude Code background bash is a good example: long-running commands run in the background, the agent gets notified when they complete, and the workflow doesn't block. Same pattern, generalisable to any async tool.

@feynman

The microservices lesson, applied to actions. Don't hold a synchronous connection open for an hour; fire the work, get a handle, check on it later. Agents don't get to skip this discipline.

@card
id: llmp-ch07-c007
order: 7
title: Audit Trails as a First-Class Output
teaser: Every action has to leave a record someone other than the developer can read. What was done, by whom, when, with what arguments, with what result. Without it, the system is unaccountable.

@explanation

The audit trail is the log of everything the agent did, structured for replay and review. It's not the same as the trace (the dev-debug log of how the agent thought). It's the legal/operational record of what actually happened in the world.

What goes in:

- **Identity** — the agent that took the action, the user it was acting on behalf of, the session.
- **Action** — name, arguments, timestamp, idempotency key.
- **Decision context** — why this action (the model's thought, the inputs that led here).
- **Approval** — whether and how a human approved.
- **Result** — success, failure, identifiers of resources created/modified, side effects produced.
- **Cost** — tokens, latency, dollars.

The format is structured, not prose:

```json
{
  "audit_id": "ad-2026-04-28-1f2a",
  "agent_id": "support-agent-v1.2.3",
  "user_id": "u_38291",
  "session_id": "s_8a2f",
  "action": "issue_refund",
  "arguments": {"order_id": "o_1234", "amount": 49.99},
  "approval": {"by": "human:alice@example.com", "at": "2026-04-28T13:42:01Z"},
  "result": {"status": "ok", "transaction_id": "tx_9821"},
  "timestamp": "2026-04-28T13:42:03Z"
}
```

This format is searchable. A regulator, an auditor, or your engineer at 3 AM can answer "what did the agent do for user X in the last 30 days" with a definitive query.

> [!warning] Audit logs without a retention policy become a liability. Decide upfront how long you keep them, what gets purged, what's required by regulation. The wrong answer here lands legal teams in your slack.

@feynman

Same as a flight data recorder. Boring on a normal day, irreplaceable when something goes wrong — and required by law in some industries.

@card
id: llmp-ch07-c008
order: 8
title: Rollback by Design
teaser: When an action goes wrong, the system needs a way back. Sometimes that's an undo function; sometimes it's a compensating action; sometimes it's a manual escalation. Pick one upfront, per action.

@explanation

Every Tier 1+ action should answer: how do we undo this if it was wrong? The answer should be in the tool design, not improvised after the fact.

Recovery patterns:

- **Native undo** — the system supports `delete_record` followed by `restore_record`. Cleanest when available.
- **Compensating action** — there's no undo, but there's an action that cancels the effect. Sent the wrong email? Send a follow-up correcting it. Charged the wrong amount? Issue a refund.
- **Saga / workflow** — multi-step actions where each step has a paired compensator. If step 3 fails, run compensators for steps 1–2 in reverse.
- **Manual escalation** — for irreversible actions, the rollback is "page the human." This is acceptable, but the action's tier should reflect that recovery isn't automated.

Your tool catalog should pair each Tier 1+ tool with its rollback path:

```python
TOOLS = [
    Tool("send_email",      compensator="send_correction_email"),
    Tool("issue_refund",    compensator="reverse_refund"),
    Tool("provision_vm",    compensator="deprovision_vm"),
    Tool("delete_account",  compensator=None, irreversible=True),
]
```

> [!info] If a tool's compensator is "page the human," that's fine — but it should be visible in the catalog so reviewers can spot which actions don't have automated recovery.

@feynman

The "control-Z" question for every action. If the answer is "you can't," the action should require a real approval. If the answer is "click here," the friction can be lower.

@card
id: llmp-ch07-c009
order: 9
title: Multi-Step Plans
teaser: Complex actions are sequences. Have the model lay out the plan first, get approval on the plan (not each step), then execute steps with checkpoints.

@explanation

For tasks that take 5+ actions, approving each one individually is exhausting and counterproductive. The user clicks through without reading. Better: approve the plan up front, then execute with checkpoints.

```text
User: "Migrate our staging database to the new schema."

Model:
  Plan:
  1. Backup current schema (read-only).
  2. Run migration script.
  3. Verify row counts match.
  4. Update application config.
  5. Restart application servers.
  6. Run smoke tests.

  Approve this plan? [Yes] [Edit] [Cancel]
```

Once approved, execution proceeds step by step. Between each step, the runtime can:

- **Show progress** — the user sees the agent work through the plan.
- **Pause on deviation** — if a step fails or surfaces unexpected results, halt and re-confirm.
- **Allow abort** — at any point the user can stop the rest of the plan.

This pattern is how Computer Use, IDE agents, and multi-step coding agents handle long tasks. The plan-first approach concentrates the human attention on the moment that matters: the design of the action, not its execution.

> [!tip] Plans should be written so a human can read and verify them. "Run script X" is opaque; "Backup, then migrate, then verify" is reviewable.

@feynman

The runbook a senior engineer writes before a complex deploy. Same instinct, applied to an agent's task — the plan is the unit of approval.

@card
id: llmp-ch07-c010
order: 10
title: Failure Recovery
teaser: Tools fail. Networks blip. APIs change behaviour. The agent has to handle failure as a first-class case — not as an exception that ends the run.

@explanation

Failures will happen. The patterns that handle them well:

- **Distinguish failure types** — transient (network blip, rate limit), client error (bad args, missing permission), server error (the upstream is broken), logical error (the operation is wrong for the situation). Different categories warrant different responses.
- **Retry the transient kind, with backoff** — most provider errors fall here. Don't burn budget retrying client errors; they won't fix themselves.
- **Surface client errors back to the model** — let it self-correct. "Tool returned: invalid date format. Use ISO 8601." On retry, the model fixes its arguments.
- **Escalate logical errors** — when the failure indicates the action was the wrong choice (not just a bad call), surface the situation to the user rather than retrying with a slight tweak.
- **Cap retries with a budget** — same lesson as in the reliability chapter. Three attempts max, then escalate.

```python
def execute_with_recovery(action):
    for attempt in range(MAX_RETRIES):
        try:
            return action.run()
        except TransientError as e:
            backoff(attempt)
            continue
        except ClientError as e:
            return ClientFailure(error=str(e))   # surface to model for retry
        except LogicalError as e:
            return Escalation(reason=str(e))     # surface to human
    return ExceededRetries()
```

> [!warning] An agent that retries forever is a runaway. Always pair retries with a max-attempts cap and a max-time budget.

@feynman

Same pattern as resilient distributed systems. Most of the work isn't the happy path; it's making the unhappy path safe and informative.

@card
id: llmp-ch07-c011
order: 11
title: The Action Surface Is the Security Surface
teaser: Every tool you give the agent is a path through which something can go wrong. Limit the surface, scope the credentials, and audit the boundary — because the model is not a security perimeter.

@explanation

The model doesn't enforce security; the runtime does. Anything you give the model the ability to do, it might do — under user input, under unexpected state, under misinterpretation. The mitigations are structural:

- **Least privilege** — give each agent only the tools it actually needs. The "research" agent doesn't need the "deploy" tools. Per-role tool catalogs.
- **Scoped credentials** — never hand the agent god-mode tokens. Issue tokens scoped to the tools and resources it actually needs.
- **Argument allowlists** — `delete_record(table="users")` is dangerous; `delete_record(table=ALLOWED_TABLES, id=...)` is bounded.
- **Network egress allowlists** — agents that can reach the internet should only reach the hosts you've named.
- **Sandbox execution** — code-running agents go in MicroVM-class isolation, not on your bare host.
- **Audit everything** — every action, with the identity of the caller, the arguments, the result.

These are the same controls you'd apply to any service taking action on behalf of users. Agents don't get a pass because they're "just an LLM."

> [!warning] Prompt injection is a real attack vector. Untrusted content (user emails, web pages, customer messages) can contain instructions the model will read as commands. Treat the model as untrusted when it's been exposed to untrusted input. Action gates and scoped credentials are the defence — not "tell the model not to fall for it."

@feynman

The principle of least privilege, applied to a worker that thinks in English. The same controls security teams have always insisted on; the new actor just speaks in tokens.

@card
id: llmp-ch07-c012
order: 12
title: Picking the Right Action Pattern
teaser: Most action systems need three things: tier-aware approval, idempotency on every Tier 2+ tool, and an audit trail. The rest depends on what you're doing — but those three are non-negotiable.

@explanation

A useful starter checklist for any agent that takes action:

- **Tier every tool** — read-only, reversible, side-effecting, irreversible. Map to permission modes.
- **Idempotency keys on every Tier 2+ tool** — non-negotiable. The retry will happen.
- **Audit trail with structured logs** — every action, who, when, what, with what result.
- **Approval gates on Tier 3 actions** — with diffs and previews, not just "Approve?"
- **Compensators or escalation paths** — every Tier 1+ tool answers "how do we undo this?"
- **Sandboxed execution for code** — no exceptions for "trusted internal users."
- **Scoped credentials** — least-privilege tokens; rotate aggressively.
- **Failure recovery** — distinguish failure types; retry only the transient ones; cap retries.

The patterns are mostly common sense from operations and security, applied consistently to an agent that can take real actions. None of them are about the model being smarter; all of them are about the system around the model being honest about its capabilities.

> [!info] An agent that ships and stays shipped almost always has these in place. An agent that ships and goes badly almost always skipped two or three of them. The post-mortem is rarely "the model was wrong"; it's "the system around the model wasn't ready."

@feynman

Same hygiene as productionising any service. The patterns aren't novel; the actor is. Apply the operational discipline you'd apply to any system that takes action — and the model becomes a tractable component, not a liability.
