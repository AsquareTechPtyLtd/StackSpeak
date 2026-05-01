@chapter
id: llmp-ch05-capabilities
order: 5
title: Capabilities
summary: Tools, function calls, code execution, vision, computer use — the patterns for giving a model abilities it didn't have when it was trained.

@card
id: llmp-ch05-c001
order: 1
title: The Capability Gap
teaser: A foundation model can write about anything and *do* almost nothing. The patterns in this chapter close the gap by giving the model functions it can call.

@explanation

Out of the box, a model produces text. Text is enough for some tasks (summarisation, classification, drafting), but most product features need actions: query a database, hit an API, run code, look at an image, click a button. The base model can't do any of those — it can only describe doing them.

The fix is structural. You expose a set of *tools* — functions with names, descriptions, and argument schemas — and the model learns to emit a tool call when one fits the task. The runtime executes the tool, returns the result, and the model continues. The model itself doesn't gain a new ability; the system around it gains one, and the model learns to delegate.

This shape is universal in 2026. Every major API supports it, with minor variations in surface. The patterns are about doing it well: which tools to add, how to describe them, when to give the model code-execution vs a curated tool, when to reach for fine-tuning instead.

> [!info] "The model can't do X" is rarely the right framing. The right one is "the system around the model can't do X yet" — and the patterns in this chapter are how you fix that.

@feynman

Same logic as a software engineer with no IDE. They can describe writing code; they can't actually run it. Hand them an editor and a compiler and the work shifts from "explaining" to "doing."

@card
id: llmp-ch05-c002
order: 2
title: Few-Shot for Unfamiliar Tasks
teaser: Before you reach for fine-tuning or new tools, try showing the model what success looks like. Three examples solve more "the model doesn't know this task" problems than people expect.

@explanation

When the model fails on a task that's new or domain-specific, the instinct is to assume it can't do it. Often it can — it just hasn't been pointed at what success looks like.

A few-shot prompt is three to five worked examples in the prompt:

```text
Convert each support ticket to a triage entry.

Ticket: "I can't log in! It says invalid password but I just changed it."
Triage: { severity: "P2", category: "auth", needs_human: false }

Ticket: "Production is down for our whole org, please respond ASAP"
Triage: { severity: "P0", category: "outage", needs_human: true }

Ticket: "The export button is in a weird place on mobile"
Triage: { severity: "P3", category: "ux", needs_human: false }

Ticket: <new ticket>
Triage:
```

Examples carry information that descriptions don't. "Output a triage entry" leaves the model guessing about your conventions. Examples remove the guessing.

> [!tip] On reasoning models, a single great example sometimes works as well as five. The model has the capability; the example calibrates the output shape.

@feynman

The intern who's never seen the project. You can write a long memo about how to format the output, or you can show three examples. The second is faster and more reliable.

@card
id: llmp-ch05-c003
order: 3
title: Tool Calls as the Primary Extension
teaser: A tool is a function the model can choose to invoke. Description in, JSON-schema args out, runtime executes, result feeds back into context. That's the whole mechanism.

@explanation

The mechanics, from the API perspective:

```python
tools = [
    {
        "name": "search_orders",
        "description": "Search the user's order history. Returns matching orders.",
        "input_schema": {
            "type": "object",
            "properties": {
                "user_id": {"type": "string"},
                "since": {"type": "string", "format": "date"},
                "status": {"type": "string", "enum": ["pending", "shipped", "delivered"]}
            },
            "required": ["user_id"]
        }
    },
    # more tools...
]

response = client.messages.create(
    model="claude-sonnet-4-6",
    tools=tools,
    messages=[{"role": "user", "content": user_query}],
)

for block in response.content:
    if block.type == "tool_use":
        result = dispatch(block.name, block.input)
        # send result back, model continues
```

The runtime is a loop:

1. Model decides whether to call a tool. If yes, emits a structured `tool_use` block.
2. Runtime executes the tool, gets a result.
3. Result is appended to the message stream as a `tool_result` block.
4. Model reads the result and either calls another tool or produces a final answer.

The loop is identical across providers; only the surface details differ.

> [!info] In 2026, modern SDKs handle the loop for you. You provide the tools and the messages; the SDK handles dispatch and turn-taking until the model is done.

@feynman

Function calling, but the function-picker is a model that just learned about your API by reading the description. Pick well, describe well, and the rest is plumbing.

@card
id: llmp-ch05-c004
order: 4
title: Tool Descriptions Are Prompts
teaser: The model picks tools by reading their descriptions. A vague description is a vague trigger; a clear one is a precise one. Treat each tool's name and description as the prompt it actually is.

@explanation

The model has no special access to your code. Its only knowledge of `search_orders` is the JSON you gave it. Everything that's clear in your head — when to use this tool, when to use a different one, what each argument means, what the response looks like — has to be written down in the description.

A description that works in production:

```json
{
  "name": "search_orders",
  "description": "Look up a user's order history by their account ID. Use this when the user asks about specific orders, order status, or 'what did I buy.' Do not use this for billing questions — use lookup_invoice instead. Returns up to 50 most recent orders matching the filters.",
  ...
}
```

Things to put in descriptions:

- **What the tool does** in one sentence.
- **When to use it** — the trigger conditions.
- **When NOT to use it** — pointing to alternatives.
- **What the result looks like** — shape, units, edge cases (empty array? null? error?).
- **Side effects** — explicit, if any. "This sends an email."

> [!warning] If two tools have similar descriptions, the model picks unpredictably between them. Disambiguate. The cost of ambiguity isn't theoretical — it's wrong tool calls in production.

@feynman

The README the model reads before pressing buttons. A vague README leads to wrong button presses, no matter how smart the reader is.

@card
id: llmp-ch05-c005
order: 5
title: Parallel Tool Calls
teaser: When three tool calls don't depend on each other, do them in parallel. The model emits all three; the runtime dispatches them concurrently. Latency drops without quality changing.

@explanation

Old tool-use loops were strictly serial: one tool, observe the result, decide the next, dispatch, observe, repeat. Modern frontier models emit multiple parallel tool calls in a single response. The runtime fires them concurrently and feeds the batched results back.

The wins are real:

- **Latency** — three 400ms tools take 400ms in parallel, not 1.2s in series.
- **Cost** — fewer round-trips back to the model.
- **Quality** — one batched observation is more coherent context than three sequential ones.

Most SDKs handle parallel dispatch automatically once the model emits multiple `tool_use` blocks in the same response. The constraint is logical, not technical: the parallel calls have to be independent.

> [!warning] Side-effecting tools should not parallelise without thought. Two simultaneous "send email" calls send two emails. Mark idempotent vs non-idempotent in your tool design, or serialise side effects explicitly.

@feynman

`Promise.all` for the model's actions. The model picks what to batch; you make sure the batched things actually don't depend on each other.

@card
id: llmp-ch05-c006
order: 6
title: MCP — Reusable Tool Servers
teaser: A tool you write once should work in your custom agent, in Claude Desktop, in your IDE, and in tomorrow's host you haven't built yet. MCP is the standard that makes that work.

@explanation

The Model Context Protocol (MCP), introduced by Anthropic in late 2024 and now broadly adopted, defines a wire format for exposing tools, resources, and prompts to model hosts. You build an MCP server; any MCP-aware host can connect — Claude Desktop, Claude Code, IDE plugins, your own agent runtime, third-party agents.

Why this matters for capability engineering:

- **One implementation, many surfaces.** Your "search internal docs" tool runs in the IDE for engineers and in the support agent for customers, from the same code.
- **Versioning at the boundary.** Bump the server, every host gets the new tool.
- **Auth scoping per server.** Permissions live in one place, not in every host.

A minimal MCP server in 2026:

```python
from mcp.server import FastMCP

server = FastMCP("docs-search")

@server.tool()
def search_docs(query: str, limit: int = 10) -> list[Doc]:
    """Search internal documentation. Returns matching pages with snippets."""
    return docs_index.search(query, limit=limit)
```

Hosts discover the tool, see its schema, and call it. The protocol handles the rest.

> [!info] You don't have to migrate everything to MCP at once. Mix native SDK tools with MCP tools in the same agent until you're ready.

@feynman

USB for AI tools. Before USB, every printer needed its own cable; before MCP, every tool needed re-implementing per host. Same fix, different layer.

@card
id: llmp-ch05-c007
order: 7
title: Code Execution as a Tool
teaser: Don't ask the model to do arithmetic; give it a Python interpreter. Don't make it draft a chart; let it run matplotlib. Code execution is the highest-leverage tool for technical tasks.

@explanation

Models hallucinate arithmetic. Models hallucinate API call results. Models invent data shapes. The fix is to let them write code that produces the answer, then run that code in a sandbox.

In 2026, every major provider ships a "code interpreter" or "code execution" tool: Anthropic's code execution, OpenAI's tools-API code interpreter, Google's Python sandbox. Open-weight equivalents (E2B, Modal, Daytona, Replit's API) work with any model.

The pattern:

```text
User: "Plot the distribution of customer ages from this CSV."

Model: <thinks: I need to load the CSV, compute the distribution, plot it.>
       <tool_call: code_exec, input: pandas + matplotlib script>

Runtime: <executes in sandbox, returns plot.png>

Model: "Here's the distribution — most customers are 30–45, with a long tail."
```

What this unlocks:

- **Reliable arithmetic** — the model writes `(193.5 * 0.0764)` and the interpreter computes it. No hallucinated digits.
- **Data analysis** — pandas, NumPy, scikit-learn all available; the model writes the script.
- **Plotting and visualisation** — charts produced from real data, not described.
- **Custom logic** — anything Python can do, the agent can do, scoped to the sandbox.

> [!warning] Sandbox aggressively. Code execution is the most powerful tool you'll add and the riskiest if it touches your real environment. MicroVM-class isolation, no production credentials, network egress allowlists.

@feynman

Giving the model a calculator, then a notebook, then an entire Python REPL. Each step extends what it can produce — and shifts work from "describing what would happen" to "showing the actual result."

@card
id: llmp-ch05-c008
order: 8
title: Vision and Multimodal Inputs
teaser: Frontier models read images, parse charts, transcribe handwriting, and analyse video. Tasks that needed bespoke vision pipelines are now one API call away.

@explanation

By 2026, multimodal input is table stakes. Claude, GPT-5, and Gemini all accept images, charts, and (with the right tier) video. The capability changes what you can hand a model:

- **Screenshots** — debug a UI bug by showing the model the broken state.
- **Charts and diagrams** — the model reads axes, extracts numbers, summarises trends.
- **Documents** — receipts, contracts, PDFs with mixed layouts. Better than tesseract; better than older OCR pipelines.
- **Photos for context** — "what's in this image" or "compose a description for this product photo."
- **Video** — frame-by-frame or sampled; useful for "what happened in this clip."

Common production uses:

```python
client.messages.create(
    model="claude-opus-4-7",
    messages=[{
        "role": "user",
        "content": [
            {"type": "image", "source": {"type": "base64", "data": image_b64}},
            {"type": "text", "text": "Describe what's wrong with this UI screenshot."},
        ],
    }],
)
```

> [!tip] Multimodal is much cheaper than running a separate vision pipeline. Before you spin up a CV stack, check whether the frontier model already does what you need. Often it does, with much less infrastructure.

@feynman

Same shift as adding eyes to the system. The model that can only read text is the colleague who's only ever looked at the requirements doc; the multimodal model is the one who's seen the screenshots, the mockups, the customer's photo of the bug.

@card
id: llmp-ch05-c009
order: 9
title: Computer Use and Browser Automation
teaser: When there's no API, give the model a screen, a keyboard, and a mouse. Computer use is slow, expensive, and surprisingly capable for the long tail of "we couldn't get a clean integration."

@explanation

Computer Use — Anthropic's primitive for letting the model see a screen and emit clicks and keystrokes — solves a specific class of problem: tasks where the API doesn't exist or the integration cost is too high. Filling in legacy enterprise software, navigating sites without public APIs, smoke-testing your own product.

The pattern (simplified):

```text
1. Take a screenshot of the current screen.
2. Send screenshot + task to the model.
3. Model emits actions: click(x,y), type("hello"), scroll, wait.
4. Runtime executes against a real browser or VM.
5. Take new screenshot. Loop.
```

It works. It's slow (every step round-trips the screen). It's expensive (every step is a multimodal call). It's also the only practical answer for some workflows.

When to reach for it:

- Vendor APIs are missing or expensive.
- The flow is genuinely visual (form filling, drag-and-drop, layout-dependent).
- You need to drive your own product end-to-end for testing.

When to avoid:

- A clean API exists. Use it.
- The task is high-throughput. Computer use doesn't scale to thousands of runs per hour cheaply.
- The task is high-stakes and irreversible. The accumulated error rate of "model clicks wrong thing once in 200 steps" is real.

> [!warning] Run computer-use agents in disposable VMs with no production credentials. Scope what they can reach. The last thing you want is a clicked-by-accident "delete account" propagating through your real systems.

@feynman

The intern who can't use your APIs but can drive a browser. Less efficient than the integration would be, but they can get the work done while the integration team's backlog clears.

@card
id: llmp-ch05-c010
order: 10
title: Custom Capability via Fine-Tuning
teaser: When prompts and tools max out and you still need a capability the base model lacks, fine-tuning is the right answer. Not before.

@explanation

Fine-tuning teaches the model new behaviour by training it on examples. It's the heavy artillery: expensive, slow, model-version-locked. For most capability gaps, prompting + tools is enough. For some, it isn't.

When fine-tuning genuinely helps:

- **Domain language the model wasn't exposed to** — extreme medical, legal, scientific notation that no base model handles fluently.
- **Output format too complex for in-prompt examples** — proprietary structured formats with intricate cross-field rules.
- **Latency-critical narrow tasks** — distill a frontier model's behaviour into a small one for your specific workflow.
- **Volume that justifies the engineering** — you'll run this enough times that the per-call savings dominate the training cost.

When fine-tuning doesn't help:

- The base model can do it with the right prompt — you're rebuilding what already works.
- The data is small (< 1000 high-quality examples) — gains are noise.
- The task changes weekly — fine-tunes have a shelf life.

In 2026, the fine-tuning UI on Anthropic, OpenAI, and Google handles the heavy lifting. You upload examples, pick a base model, get a tuned endpoint. LoRA adapters via open-weight stacks (Together, Fireworks) are similarly accessible.

> [!info] Fine-tuning is the last resort because it's the most expensive thing to maintain. Every model upgrade means re-tuning. Every prompt iteration is now slower. Pay this cost only when prompting and tools have genuinely failed.

@feynman

The difference between training a colleague on the job (prompts, tools, examples) and sending them back to school (fine-tuning). Both teach; the first is much faster to start and easier to revise.

@card
id: llmp-ch05-c011
order: 11
title: Composing Capabilities
teaser: A real agent uses several capabilities together — vision sees the screen, code execution computes the answer, retrieval fetches context, function calls dispatch the action. Composition is the design.

@explanation

Single-capability examples are pedagogical. Real agents stack capabilities:

```text
User: "Compare last quarter's revenue to forecast and explain the variance."

1. retrieve_finance_docs(quarter="Q1 2026")     → grounded source
2. code_exec(load CSV, compute deltas)          → actual numbers
3. retrieve_internal_notes(topic="Q1 variance") → context for the variance
4. compose_response(numbers + context)          → grounded explanation
```

Each capability does one thing well. The composition produces the user-visible answer. The interesting design questions:

- **What's the right ordering?** Some capabilities depend on others; some can run in parallel.
- **Where do failures degrade?** Lose retrieval, you can still answer with general knowledge plus a caveat. Lose code exec, the answer's confidence drops.
- **What's the cost shape?** Code exec is cheap-ish; vision is expensive; retrieval depends on infrastructure.
- **Where does the human step in?** When confidence is low, when an irreversible action is proposed, when sources disagree.

> [!info] The compositions that work in production are rarely the ones designed up-front. They emerge from iterating on real failures — "users keep asking X, current pipeline misses Y, add capability Z."

@feynman

The toolchain on a senior engineer's machine. They use grep, git, an IDE, a debugger, a profiler, a notebook — all together, picking each one for what it's best at. The agent's capability composition is the same instinct, codified.

@card
id: llmp-ch05-c012
order: 12
title: Picking the Right Extension
teaser: New capability needed? Try few-shot, then tools, then code execution, then vision, then computer use, then fine-tune. In that order, by cost. Most problems stop at step two or three.

@explanation

A decision order from cheapest to most expensive:

1. **Few-shot examples** — free, instant, reversible. Solve "the model doesn't know this task" most of the time.
2. **A targeted tool** — exposes an API or function. Solves "the model can't reach this system."
3. **Code execution** — gives the model a programmatic primitive. Solves "the model can't compute this reliably."
4. **Vision / multimodal** — adds perceptual input. Solves "the answer is in an image, document, or video."
5. **MCP server** — formalises tools when they need to be reusable across hosts.
6. **Computer use** — gives the model a screen and keyboard. Solves "no API exists; we have to drive the UI."
7. **Fine-tuning** — modifies the model. Solves "no amount of prompting and tooling closes the gap."

Stop at the first step that solves your problem. Each step adds cost, complexity, or surface area. The teams that compose strong agents in 2026 reach for fine-tuning rarely and for tools constantly — because the per-cost return on tools is much higher.

> [!info] The hardest capability question is "do I need to extend the model, or just frame the task better?" Half the time the model already had the capability and the prompt was hiding it. Try framing first.

@feynman

The same lesson as the cost-of-change curve. The cheap fix tried first; the expensive one only when the cheap ones genuinely failed. Most teams jump steps and pay for it.
