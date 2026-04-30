@chapter
id: aiadg-ch02-architectures-patterns
order: 2
title: Reasoning Loops
summary: The control patterns that turn a chat completion into something you can ship — CoT, ToT, ReAct, and where humans gate the loop.
icon: square.grid.3x3.topleft.filled

@card
id: aiadg-ch02-c001
order: 1
title: One-Shot vs Iterative Agents
teaser: A one-shot agent answers in a single forward pass. An iterative agent is a control loop wrapped around the same model — and that loop is where almost all the leverage comes from.

@explanation

A one-shot call gives the model the request, gets a completion, and returns. Whatever planning happens, happens implicitly inside that single forward pass. There's no chance to inspect a partial result, retry a failed tool, or adjust when the world disagrees with the model's prediction.

An iterative agent runs the same model on a loop: read state, decide one action, execute, observe, decide again. Modern frontier models — Claude Opus 4.7, GPT-5, Gemini 2 — are strong enough that iteration matters more than scale. The same model running ten well-structured steps will routinely beat a larger model running once.

- **One-shot** — single forward pass; cheap, but every assumption is final.
- **Iterative** — N steps with state in between; expensive per task, but mistakes are recoverable.

> [!info] Extended-thinking modes (Claude's `thinking`, OpenAI's reasoning models) compress a one-shot call into something that *behaves* like a loop, but the visible loop you build around the model still matters because it's where you wire in tools, memory, and human oversight.

@feynman

One-shot is "compile and run." Iterative is the REPL. The compiler can be brilliant; the REPL is what catches the bug you didn't know you had.

@card
id: aiadg-ch02-c002
order: 2
title: Chain of Thought, Honestly
teaser: CoT is just asking the model to write down its reasoning. It still helps — but on reasoning-tuned models, what helps more is *what* you ask it to think about, not whether you ask it to think.

@explanation

The classic chain-of-thought prompt — "let's think step by step" — was a 2022 trick on plain instruct models. On 2025-era reasoning models it's largely a no-op; the model is already producing internal traces whether you ask or not. What still moves the needle is giving the model a structured shape to follow.

Effective shapes name the *stages* and the *output contract*:

```text
You are reviewing a pull request.
Stage 1: list what the diff actually changes (file by file).
Stage 2: identify risks (correctness, regressions, performance).
Stage 3: write the review comments.
Return only the Stage 3 output as JSON: {comments: [...]}
```

The "think step by step" framing has been replaced by named stages, structured outputs, and — when supported — an explicit thinking budget. Treat the prompt like a function signature, not a pep talk.

> [!tip] If your model exposes a thinking parameter, use it for hard problems and skip it for trivial ones. Thinking is billed; "do you have a question, sir" is not a useful place to spend tokens.

@feynman

Saying "think carefully" to a senior engineer doesn't make them think harder. Naming the artifacts they should produce does.

@card
id: aiadg-ch02-c003
order: 3
title: Tree of Thoughts and Best-of-N
teaser: When the first answer might be the wrong answer, generate several and pick. Cheap parallelism beats clever single-shot prompting on open-ended tasks.

@explanation

Tree-of-thoughts (ToT) and best-of-N sampling are the same idea wearing different hats: you don't trust the first generation, so you produce several candidates and let something downstream choose. With current APIs you usually do this with parallel completions at higher temperature, then rank them with a colder, stronger model.

1. **Diverge** — N generations at temperature 0.7+, ideally with prompts that ask for *distinct* angles, not just rephrasings.
2. **Score** — a single judge call ranks them against your criteria. Often a cheaper model can judge what a bigger model produced.
3. **Pick** — keep the winner; throw the rest away (or keep them as cached fallbacks).

The cost is roughly N× the generator price. The benefit is that you defeat the "first plausible thing" failure mode that ruins agents on creative or under-specified tasks.

> [!info] On reasoning models, you often get most of the diversity benefit by raising the thinking budget instead of branching. ToT is most useful when *evaluation* is genuinely hard and you need explicit alternatives to compare.

@feynman

Three architects sketching three floor plans is more useful than one architect drawing the "best" plan. Choice in hand beats confidence in mind.

@card
id: aiadg-ch02-c004
order: 4
title: ReAct, Updated
teaser: The reason-act-observe loop is the spine of every modern agent. Today the "act" step almost always means a tool call, and the loop is built into the SDK.

@explanation

ReAct — interleaving reasoning with action — was novel in 2023. In 2026 it's the default shape: the model produces a thought and a tool call together, the runtime executes the tool, the result lands back in the message stream, and the next turn reasons over the updated context.

What's changed is that you no longer hand-roll the loop. The Anthropic Agent SDK, OpenAI's Responses API, Vercel AI SDK, and LangGraph all expose it as a primitive — you provide tools, the SDK runs the loop until the model stops requesting tools.

```python
from anthropic import Anthropic

client = Anthropic()
response = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=4096,
    tools=[search_tool, run_python_tool],
    messages=[{"role": "user", "content": user_query}],
)
# The SDK handles tool dispatch and loops until response.stop_reason == "end_turn".
```

> [!tip] Always set a max-iterations or max-tokens cap on the loop. A model in a degenerate state will call the same tool a thousand times if you let it.

@feynman

Like writing a `while` loop in 2026 — you import the iterator, you don't index by hand. The interesting work is what you put inside the loop, not the loop itself.

@card
id: aiadg-ch02-c005
order: 5
title: Parallel Tool Calls
teaser: When the next three steps don't depend on each other, run them at once. It's a free latency win that single-threaded agent loops leave on the table.

@explanation

Old ReAct loops ran one tool at a time — even when the model wanted to fetch user data, fetch order history, and check inventory all at once. Modern frontier models emit *parallel* tool calls in a single response, and the runtime dispatches them concurrently before resuming the loop.

The wins compound on real-world workloads:

- **Latency** — three 400ms tool calls take 400ms together, not 1.2s in series.
- **Cost** — fewer round-trips back to the model means fewer billed turns.
- **Quality** — the model sees all three results in one batched observation, which tends to produce more coherent next steps than three sequential reactions.

The catch is dependency analysis. The model decides what's parallelizable, and it sometimes guesses wrong — fetching order history before user lookup, for instance. Tool descriptions that document dependencies ("requires user_id from get_user") help the model pick correctly.

> [!warning] Side-effecting tools should not be parallelized blindly. Two simultaneous "send email" calls can produce two emails. Mark idempotency in your tool schemas, or serialize side effects explicitly.

@feynman

`Promise.all` for agents. The model is the scheduler; you make sure the work it batches is actually independent.

@card
id: aiadg-ch02-c006
order: 6
title: Tools and the MCP Standard
teaser: A tool is a function the model can call. The Model Context Protocol is the open standard for describing tools so they work across runtimes — Claude Desktop, IDE plugins, custom hosts.

@explanation

In the SDK you define a tool with three things: a name, a description (the "prompt" the model reads to decide whether to use it), and a JSON schema for arguments. The SDK takes care of presenting it to the model and parsing the call.

What's changed in the last year is that tools are no longer locked to one app. The Model Context Protocol (MCP), introduced by Anthropic and now adopted across the ecosystem, defines a wire format so the same tool server can be plugged into Claude Desktop, Claude Code, an IDE, or a custom agent host. Write the tool once; expose it everywhere.

```json
{
  "name": "search_codebase",
  "description": "Searches the user's local codebase for a query string. Returns matching files and line numbers.",
  "input_schema": {
    "type": "object",
    "properties": { "query": { "type": "string" } },
    "required": ["query"]
  }
}
```

> [!info] The description is the most important field. Models pick tools by reading descriptions; a vague one produces wrong calls regardless of how good the schema is.

@feynman

MCP is to LLM tools what USB was to peripherals. Before USB, every printer had its own cable; now any printer plugs into any laptop. Same shift, different cable.

@card
id: aiadg-ch02-c007
order: 7
title: Why Multi-Agent Is Often a Trap
teaser: Five specialized agents handing off to each other sounds elegant. In practice it's slower, harder to debug, and worse than one good agent with the right tools.

@explanation

The multi-agent literature suggests breaking a problem into agents — planner, researcher, writer, critic — that pass work between them. Sometimes this helps. Often it doesn't, because the handoffs introduce latency, lost context, and an emergent class of bugs that nobody owns.

A single ReAct loop with strong tools and a long context window now handles tasks that the 2023 papers framed as multi-agent problems. The handoff overhead — re-summarizing, re-prompting, re-establishing role — costs more than it saves once frontier models can hold the whole problem in context.

Multi-agent makes sense when:

- **Different policies** — one agent must operate under stricter permissions than another (e.g., a "publishes content" agent vs an "edits internal docs" agent).
- **Genuinely parallel work** — independent investigations on different inputs, not a sequential pipeline pretending to be parallel.
- **Different model strengths** — a small fast model fronts user requests; a big slow model handles deep reasoning when the front model decides it's needed.

For everything else, the answer is usually one well-instrumented agent with better tools.

> [!warning] If you can't draw the message flow on a whiteboard in 30 seconds, the multi-agent system you've designed will not be debuggable in production.

@feynman

The microservices lesson, but for prompts. Don't decompose until the monolith is actually painful — and then only along the seams that have real friction.

@card
id: aiadg-ch02-c008
order: 8
title: Supervisor and Worker
teaser: When you do need multiple agents, the supervisor pattern is the one that holds up. One agent decides what to do; others do it.

@explanation

The supervisor pattern is the multi-agent shape that's actually robust. A supervisor agent reads the task, picks a worker, hands off the relevant context, receives the worker's result, and decides whether to dispatch another worker or finish.

Workers are usually narrow: one is great at SQL, one at file editing, one at web research. They don't talk to each other directly — every message routes through the supervisor. That's the part that makes the system tractable: there's exactly one place that owns the plan, and you can debug it by reading that one trace.

```text
supervisor:  user wants a sales report
supervisor → sql_worker:  pull last 30 days of orders
sql_worker → supervisor:  [results]
supervisor → chart_worker:  build bar chart from these results
chart_worker → supervisor:  [chart_url]
supervisor:  return summary + chart to user
```

> [!tip] Keep workers stateless. The supervisor holds the plan; the worker just does the next thing. That makes every worker call independently retryable.

@feynman

Like a tech lead with three engineers. The lead knows the goal, hands out narrow tasks, and reviews the results. The engineers don't argue with each other — they report up.

@card
id: aiadg-ch02-c009
order: 9
title: Human-in-the-Loop, Where It Actually Matters
teaser: Don't gate every step — gate the steps that touch money, identity, or the outside world. Approval fatigue trains people to stop reading the prompts.

@explanation

HITL is now table stakes for any agent that takes real action. The mistake is gating *too much*: every approval prompt is a tax on attention, and humans rapidly stop reading them. The skill is picking the right gates.

A useful taxonomy by what's at stake:

- **Reversible / cheap** — search a database, render a chart, draft an email. No gate. Let the agent do its thing.
- **Reversible / expensive** — call a paid API, write a draft to a shared doc. Optional gate; surface what happened, not what's about to happen.
- **Irreversible** — send the email, charge the card, run the migration, deploy the build. Always gate. Show diff-style previews; require explicit confirmation.

> [!info] The Claude Agent SDK and Computer Use exposed this as a first-class concept: tools can declare a `permission_mode` (auto, ask, deny) and the runtime enforces it before the tool runs.

@feynman

Same logic as `sudo`. It's not that every command is dangerous — it's that the genuinely dangerous ones should require typing the password and looking at what you're about to do.

@card
id: aiadg-ch02-c010
order: 10
title: Approval Gates and Idempotency
teaser: When a human can approve, revise, or reject, the runtime might re-execute the surrounding code on resume. Side effects that aren't idempotent end up firing twice.

@explanation

Approval gates pause the agent. On resume, the framework typically replays the node containing the pause to rebuild context. If you put a side-effecting call (HTTP POST, DB INSERT, email send) *before* the pause, every resume sends another one.

The fix is structural: split the work across two nodes.

1. **Plan node** — assembles the proposed action and stores it in state. Pauses for approval. No side effects here.
2. **Execute node** — runs only after approval is recorded in state. Reads the approved plan, executes the side effect once. No prompts, no pauses.

This holds beyond HITL. Any node that might be retried — by checkpoint replay, error recovery, manual rerun — should keep its side effects guarded by an explicit "approved" flag in state.

> [!warning] Idempotency keys on the side-effecting API are the second line of defense. The runtime should make double-execution rare; the API should make double-execution *safe* when it happens anyway.

@feynman

The same lesson HTTP handlers learned a decade ago. The retry will happen. Either the second call is a no-op, or you make sure only the first one fires.

@card
id: aiadg-ch02-c011
order: 11
title: Picking a Pattern
teaser: Most production agents are a ReAct loop with parallel tool calls, a strong tool description set, and a small number of HITL gates. Everything else is decoration.

@explanation

After all the patterns, the actual decision tree is short:

- **Default to a single ReAct loop** with parallel tool calls. Spend your effort on tool descriptions and on the prompt that frames the task.
- **Add HITL gates** at the boundary where actions become irreversible.
- **Add a supervisor** only when you have genuinely heterogeneous work or different permission scopes for different sub-tasks.
- **Add ToT / best-of-N** only on tasks where evaluation is the bottleneck — creative output, design exploration, ambiguous requirements.
- **Reach for thinking budgets** before reaching for new architectures. The cheapest "improvement" is often a parameter change.

The rest of this book builds on this baseline. Subsequent chapters add planning depth, model selection, production reliability, security, and deployment — all on top of the same loop you saw here.

@feynman

Like picking a web framework: don't pick on novelty, pick on what you'll be debugging at 2 AM. The boring, well-understood loop wins more shipping deadlines than the elegant new abstraction does.

@card
id: aiadg-ch02-c012
order: 12
title: What This Chapter Bought You
teaser: A working mental model: agent = model + loop + tools + gates. Every chapter from here adds detail to one of those four pieces.

@explanation

The four pieces of any production agent, restated:

- **Model** — the reasoner. Pick by capability and cost; use thinking budgets where they help.
- **Loop** — the control structure. Default to ReAct; add supervisor only when warranted.
- **Tools** — the action surface. Describe them well; expose them through MCP when they're reusable.
- **Gates** — the boundary between the agent and the world. Place them where reversal is expensive.

Once those four are in place, the questions stop being "what architecture" and start being "where is my agent slow, expensive, or wrong." The next chapters answer those.

@feynman

You now have the same four boxes in your head that every agent team draws on a whiteboard. The arguments people have are about the contents of the boxes — not the boxes themselves.
