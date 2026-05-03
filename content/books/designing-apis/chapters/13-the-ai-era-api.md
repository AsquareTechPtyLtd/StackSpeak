@chapter
id: apid-ch13-the-ai-era-api
order: 13
title: The AI-Era API
summary: AI agents and LLM tool-calling reshape what an API contract is — schemas now have to be LLM-readable, descriptions are runtime-load-bearing, and a new protocol family (MCP, Anthropic Tools, OpenAI Function Calling) has emerged to standardize how models talk to APIs.

@card
id: apid-ch13-c001
order: 1
title: Agents Are First-Class API Consumers
teaser: Your API has a new consumer that cannot read a PDF, cannot ask a colleague, and decides which endpoint to call based solely on what your schema says about itself.

@explanation

For the past decade, the two audiences for an API were humans (reading docs, building integrations) and SDKs (generated clients consuming a machine-readable spec). As of 2026-Q2, a third audience is well-established: LLM-based agents that discover, select, and invoke endpoints at runtime with no human in the loop.

What this changes:

- **The schema is the interface.** An agent has no prior knowledge of your API. It reads the tool manifest — names, parameter schemas, description strings — and decides whether and how to call you. A description that says `"Update a record"` is meaningfully worse than one that says `"Update a single customer record by ID; prefer this over batch-update when changing fewer than 5 fields."` The first leaves an agent guessing; the second gives it routing information.
- **Documentation is invoked, not read.** Human developers read docs once, form a mental model, then write code. Agents re-read the schema on every invocation. The description fields in your JSON Schema are not fluff — they are executed context.
- **Failure paths need to be machine-parseable.** An agent cannot "look at the error message and figure it out." Error responses need structured bodies with action-oriented language so the agent can decide whether to retry, fall back, or stop.

The shift does not invalidate anything in the chapters before this one. REST, GraphQL, versioning, security — all of it still applies. What changes is that a new class of consumer has arrived with very different literacy: high syntax precision, zero institutional knowledge, and no tolerance for ambiguous descriptions.

> [!info] As of 2026-Q2, Claude 4.x, GPT-5, and Gemini 2.x all support native tool-calling. The agent-as-API-consumer pattern is production reality, not a forward projection.

@feynman

Your API now has a user who reads the label on every button before pressing it, every single time, with no memory of having pressed it before.

@card
id: apid-ch13-c002
order: 2
title: Tool-Calling Fundamentals
teaser: Tool-calling is how an LLM maps a natural-language intent to a specific API invocation — and it depends entirely on the quality of the JSON Schema you hand it.

@explanation

Tool-calling (also called function calling) is a model capability where the LLM, given a set of tool definitions and a user request, produces a structured call rather than a prose response. The runtime then executes that call and feeds the result back to the model.

The basic flow:

```text
1. Developer registers tools: [{ name, description, inputSchema }]
2. User sends a request: "What is the status of order #4821?"
3. Model selects a tool and emits a structured invocation:
   { tool: "get_order_status", input: { order_id: "4821" } }
4. Runtime calls the actual API with that input.
5. API response is injected back into the model's context.
6. Model produces a final answer to the user.
```

What the model sees when selecting a tool is exactly three things: the tool name, its description, and its input schema. Nothing else. This makes schema quality the primary lever for agent reliability.

Key mechanics:

- **Name-as-signal.** The model treats the tool name as a semantic shorthand. `get_order` is a better name than `order_endpoint_v2` — the model's routing is influenced by naming conventions that resemble human-readable intent.
- **Required vs optional parameters.** Mark parameters as required only when the tool genuinely cannot run without them. Forcing an agent to provide a value it does not have causes unnecessary fallback and retry loops.
- **Enum constraints.** Where a parameter has a bounded value set, express it as a JSON Schema `enum`. This prevents the model from hallucinating a value that the API will reject.
- **Multi-tool routing.** When a toolset has many tools, the model performs a soft-ranking to pick the best match. Overlapping descriptions between two tools increases the chance of the wrong one being selected.

> [!warning] As of 2026-Q2, the tool-calling specs across providers have largely converged on JSON Schema for input definitions, but the exact envelope format (how tools are declared, how results are returned) still differs between Anthropic Tools, OpenAI Function Calling, and MCP. Abstraction at the orchestration layer is advisable.

@feynman

Tool-calling is how a model turns "book me a flight" into a precise API call — and the only thing standing between a good call and a hallucinated one is whether your schema description was clear enough.

@card
id: apid-ch13-c003
order: 3
title: Anthropic Tools
teaser: Anthropic's tool-use shape defines how Claude receives tool definitions and emits structured invocations — and the description field is where most of the real work happens.

@explanation

Anthropic's tool-use API (used by Claude 4.x models) follows a specific envelope format. A tool definition sent to the API looks like this:

```json
{
  "name": "get_customer",
  "description": "Retrieve a single customer record by their unique ID. Use this when you have a customer_id and need their profile, tier, or contact details. Do not use this to search by name — use search_customers for that.",
  "input_schema": {
    "type": "object",
    "properties": {
      "customer_id": {
        "type": "string",
        "description": "The UUID of the customer, as returned by list_customers or search_customers."
      }
    },
    "required": ["customer_id"]
  }
}
```

When Claude selects this tool, it emits a content block with `type: "tool_use"` containing the tool name and a JSON object matching the input schema. Your handler receives that object and calls the actual API.

What this pattern makes explicit:

- **The description is doing routing work.** The phrase "Do not use this to search by name — use search_customers for that" is not documentation flavor — it is an instruction Claude reads to decide between two tools. In a well-designed toolset, each tool description briefly states what the tool is for and — critically — when to use something else instead.
- **The input schema is validated by the model, not just by your API.** Claude will only produce values that conform to the declared types and enums. A mismatch between the schema and what your API actually accepts is a latent bug.
- **Handler separation.** The handler (the code that calls your actual API) is separate from the schema definition. Keep this layer thin — it should do the call and return the result without reformatting.

> [!info] As of 2026-Q2, Claude 4.x supports parallel tool use — the model can emit multiple tool-use blocks in a single response when it determines that several calls can proceed independently. Your handler infrastructure needs to accommodate concurrent execution.

@feynman

An Anthropic tool definition is a name, a plain-English routing instruction, and a typed input contract — the model reads all three before deciding whether this is the right tool to call.

@card
id: apid-ch13-c004
order: 4
title: OpenAI Function Calling
teaser: OpenAI introduced function calling in 2023 and the ecosystem has largely converged on the same JSON Schema core — understanding the history explains why the two formats look similar but are not identical.

@explanation

OpenAI introduced function calling in June 2023 (GPT-3.5 and GPT-4). The format placed tool definitions in a `functions` array in the chat completion request. By late 2023 it was renamed to "tools" with a `type: "function"` wrapper, which is the shape still in use with GPT-5:

```json
{
  "type": "function",
  "function": {
    "name": "get_customer",
    "description": "Retrieve a single customer record by ID.",
    "parameters": {
      "type": "object",
      "properties": {
        "customer_id": {
          "type": "string",
          "description": "The customer UUID."
        }
      },
      "required": ["customer_id"]
    }
  }
}
```

The surface differences from Anthropic Tools are small but real:

- Anthropic uses `input_schema`; OpenAI uses `parameters`. Both are JSON Schema objects.
- Anthropic's invocation comes back as a content block with `type: "tool_use"`; OpenAI's comes back as a `tool_calls` array in the message.
- OpenAI added a `strict: true` mode (2024) that forces the output to exactly match the schema, including no extra properties. Anthropic has comparable behavior through schema enforcement in the model itself.

What matters for API designers: the JSON Schema core is stable and shared. The envelope is provider-specific. If you are building a multi-provider tool orchestration layer, abstract the envelope and share the schema definitions across providers.

> [!info] As of 2026-Q2, both providers recommend against relying on the model to infer correct parameter values when a schema constraint (enum, format, pattern) can make it explicit. Constraints that reduce the model's degrees of freedom improve reliability.

@feynman

OpenAI Function Calling and Anthropic Tools are two dialects of the same language — both describe tools in JSON Schema and both return structured invocations, but the envelope around those schemas differs enough to need an adapter if you support both.

@card
id: apid-ch13-c005
order: 5
title: MCP — Model Context Protocol
teaser: MCP is Anthropic's open protocol for connecting models to tools, data sources, and services — and as of 2026-Q2 it is the closest thing to a cross-vendor standard that the agent API space has.

@explanation

Model Context Protocol (MCP) is an open protocol, first published by Anthropic in late 2024, that defines a standard way for LLM hosts to connect to external tools and data sources. The core idea: instead of each model provider inventing its own integration format, MCP provides a shared transport and capability negotiation layer.

MCP uses JSON-RPC 2.0 as its transport. An MCP server exposes capabilities — tools, resources, and prompts — which a client (the model host or agent runtime) can discover and invoke:

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_customer",
    "arguments": {
      "customer_id": "uuid-1234"
    }
  },
  "id": 1
}
```

The server responds with a result or an error in the JSON-RPC envelope.

Why MCP matters for API designers:

- **Discovery is built in.** An MCP server exposes a `tools/list` method. An agent runtime can discover available tools without hardcoding them.
- **Provider-neutral.** An MCP server written once can be used by any model host that implements the client side — Claude, a custom agent runtime, or a future system you do not control today.
- **Composable.** Multiple MCP servers can be registered with a single agent. The agent runtime routes calls to the appropriate server based on which tools each server declares.

> [!info] As of 2026-Q2, MCP has growing adoption beyond Anthropic's own products. Several agent frameworks (including LangChain, CrewAI, and a number of enterprise orchestration tools) support MCP servers as a first-class integration target. The specification is at modelcontextprotocol.io.

@feynman

MCP is a universal adapter between models and tools — instead of every tool speaking a different dialect to every model, MCP is a shared socket that both sides agree to fit.

@card
id: apid-ch13-c006
order: 6
title: Schema Design for LLM Consumers
teaser: Descriptions are runtime instructions, not docs comments — what looks like metadata to a human SDK consumer is load-bearing routing logic for an LLM.

@explanation

The quality bar for a JSON Schema intended for LLM tool-calling is materially higher than for a schema used only by a generated SDK client. For a human developer, a description is a hint. For an LLM, it is the primary signal for whether to call this tool, how to call it, and what to do with the result.

Patterns that work:

- **Action verbs in tool names.** `get_order`, `cancel_subscription`, `search_products` — not `order`, `subscription`, `products`. The verb tells the model what the tool does before it reads the description.
- **Routing guidance in descriptions.** Each tool description should answer: when do I use this, and when should I use something else instead? "Use this to retrieve a single order by ID. To list multiple orders by status, use list_orders instead." This directly reduces misrouting.
- **Units and formats in parameter descriptions.** A parameter described as `"Amount to charge"` leaves the model guessing whether to pass `10`, `10.00`, `"10"`, or `"10 USD"`. A description that says `"Amount in cents as an integer (e.g., 1000 for $10.00)"` removes that ambiguity entirely.
- **Example values in parameter descriptions.** For string parameters with non-obvious formats (ISO 8601 dates, slugs, UUIDs), include an example value inline in the description. The model uses it to match the pattern.
- **Explicit null behavior.** If a parameter can be omitted and the tool has a useful default, say so. If omitting it causes an error, mark it required.

Anti-patterns:

- One-word descriptions (`"The ID"`, `"The name"`)
- Descriptions that describe the type rather than the semantics (`"A string containing the customer ID"`)
- Tool names that are internal implementation identifiers (`endpoint_v2_handler`, `new_customer_crud`)

> [!tip] Write each tool description as if you are writing an instruction to a junior colleague who has never used your API, has no context about your system, and can only read this one description. That is exactly what the model is.

@feynman

For a human, a JSON Schema description is a comment; for an LLM, it is the source of truth — write it like it will be executed, because it will be.

@card
id: apid-ch13-c007
order: 7
title: The Agent-First Endpoint Pattern
teaser: Endpoints designed for LLM consumers behave differently from endpoints designed for human-driven SDKs — verbose responses, embedded context, and action-oriented errors all reduce agent failure rates.

@explanation

An "agent-first endpoint" is not a separate API — it is a design posture applied to endpoints that will be called by LLM agents as a primary consumer. The changes are mostly in response shape and error behavior.

**Verbose, self-describing responses.** A human SDK client calling `GET /orders/4821` might be satisfied with a minimal response like `{ "status": "shipped", "tracking": "1Z999AA10123456784" }`. An agent trying to answer a user's question benefits from a response that includes everything the agent might need to avoid a second call: `{ "status": "shipped", "carrier": "UPS", "tracking": "1Z999AA10123456784", "estimated_delivery": "2026-05-06", "items_count": 3, "can_cancel": false }`. Agents make fewer redundant calls when responses include anticipated follow-up fields.

**Action-oriented error messages.** An error like `{ "error": "invalid_parameter" }` is unhelpful to an agent. An error like `{ "error": "invalid_parameter", "field": "customer_id", "message": "customer_id must be a UUID v4; received '4821' which appears to be a legacy numeric ID", "suggestion": "Use resolve_legacy_id to convert numeric IDs to UUIDs" }` gives the agent a recovery path without a retry loop.

**Status embedded in success responses.** Where an action can fail silently (a record-not-found returns 200 with an empty object), agents interpret the empty response as success and proceed incorrectly. Return a consistent structure that distinguishes "found and returned" from "query succeeded but nothing matched."

**Idempotency tokens in mutation endpoints.** Agents retry. Every mutation endpoint that an agent will call should accept an idempotency key. This is covered further in the next card.

> [!info] As of 2026-Q2, there is no formal specification for "agent-first" responses. This is a design pattern, not a standard. The underlying principle is that agents make decisions based on response content — the richer the content, the better the decisions.

@feynman

An agent-first endpoint is designed knowing the caller cannot stop and ask a question — so the response includes the answers to the questions the caller would have asked next.

@card
id: apid-ch13-c008
order: 8
title: Idempotency in Agent Contexts
teaser: Agents retry, loop, and sometimes call the same endpoint multiple times without knowing they already called it — idempotency keys change from a nice-to-have to a hard requirement.

@explanation

Idempotency has always been good API design. In agent contexts it becomes critical because agents introduce retry patterns that differ from human-driven clients:

- **Model-level retries.** If a tool call returns an ambiguous result (a timeout, a partial success, an unexpected shape), the model may re-invoke the same tool with the same arguments before concluding there is a problem.
- **Orchestration-level retries.** Agent frameworks typically have their own retry policies applied on top of the model's own behavior. A network error at the framework layer can cause a second call before the model is even aware the first one was attempted.
- **Loop-induced duplicates.** In multi-step agentic workflows, a model may revisit an earlier step as part of replanning. Without idempotency, this creates duplicate charges, duplicate orders, or duplicate messages.

The standard pattern: mutation endpoints accept an `Idempotency-Key` header (a UUID the caller generates once per logical operation). If the same key arrives again within the idempotency window, the server returns the stored result from the first call without executing the operation again.

What agents specifically require:

- **The idempotency window must be long enough.** A 60-second window is designed for humans experiencing network hiccups. An agent workflow that takes 10 minutes to complete may retry at minute 8. Consider 24-hour windows for endpoints that agents call in long-running workflows.
- **The response must be identical on retry.** An idempotent endpoint that returns slightly different data on the second call (a new timestamp, a regenerated token) breaks agents that compare responses across invocations.
- **Failure idempotency.** If the first call failed (5xx), a retry with the same key should attempt the operation again — not return the stored failure.

> [!warning] Every endpoint that modifies state and will be called by an agent is a candidate for duplicate execution. Idempotency keys are the mitigation. Designing this in after the fact is painful.

@feynman

Idempotency in agent APIs means: if the same operation arrives twice, the second one is safe to ignore — because agents do not always know whether they have already done something.

@card
id: apid-ch13-c009
order: 9
title: Authentication for Agents
teaser: "An LLM is calling your API on behalf of a user" is a trust problem — the agent needs credentials, but the user needs to remain in control of what the agent can do with them.

@explanation

Authentication for agent-to-API calls introduces a trust model that differs from both user-direct and service-account patterns. The relevant scenario: a user asks an agent to take an action on their behalf — book a flight, post a message, execute a transaction. The agent needs credentials. The user needs to remain the authority over what those credentials permit.

The emerging patterns as of 2026-Q2:

**OAuth 2.0 with user consent scopes.** The cleanest solution. The agent (or the platform hosting the agent) initiates an OAuth flow where the user explicitly grants a specific scope to the agent. The agent receives a time-limited access token scoped to exactly what the user approved. The token is user-issued, not developer-issued. This is structurally similar to how third-party apps have always worked — the novelty is that the "app" is an AI agent.

**Agent-specific API keys with scope restrictions.** Some providers (Stripe, GitHub, and others) support API keys with restricted permission sets. A key issued specifically for agent use can be scoped to read-only operations or to a narrow set of endpoints, limiting the blast radius if the agent over-reaches or if the key is exposed in the model's context.

**Short-lived tokens with narrow permissions.** For high-stakes operations, the pattern is: generate a single-use or time-limited token valid for exactly one operation, pass it to the agent, and revoke it immediately after use.

What does not work well:

- **Embedding full-privilege credentials in the agent's system prompt.** The model context is not a secure credential store. Credentials embedded in context can appear in logs, in error messages, and potentially in model outputs.
- **Service account tokens with broad permissions.** An agent running as a service account with admin access is a large blast radius for a compromised prompt injection.

> [!warning] Prompt injection — where an adversarial document read by an agent instructs it to take unauthorized actions — is a live attack surface as of 2026-Q2. Minimal-scope credentials are a defense-in-depth measure against it.

@feynman

Agent authentication is like giving a personal assistant a key card that only opens the doors they actually need — not because you distrust them, but because mistakes and accidents are easier to contain.

@card
id: apid-ch13-c010
order: 10
title: Rate Limiting Agents
teaser: Agents call your API in bursts during planning phases and in tight loops during execution — the traffic shape is nothing like a human-paced client, and rate limits designed for humans will break agent workflows.

@explanation

Human-driven API clients produce smooth-ish traffic: a user clicks, a request is made, a user thinks, another request follows. Agents produce fundamentally different traffic patterns:

- **Planning bursts.** When an agent starts a complex task, it may call several tools in parallel to gather context — 5 to 10 calls in under a second — before starting execution.
- **Execution loops.** In iterative workflows (write code, run tests, fix errors, repeat), an agent can hit the same endpoint dozens of times in quick succession.
- **Fan-out at scale.** One user session with an agent may produce more API calls than a hundred users operating a traditional client.

Rate limiting strategies that work better for agents:

- **Per-agent identity limits, not per-IP.** Many agents operate from data center IP ranges that are already shared across thousands of workloads. IP-based rate limiting will deny the right traffic for the wrong reasons. Rate limit on the authenticated identity — the agent's API key or OAuth token.
- **Short-window burst allowances.** A limit of `100 requests/minute` smooth-averaged punishes legitimate planning bursts. A two-tier limit — `20 requests/second` burst, `100/minute` sustained — allows the planning phase to succeed while still bounding runaway loops.
- **Differentiated limits by operation cost.** A cheap `GET /status` call and an expensive `POST /generate-report` call should not consume the same quota. Weight your rate limit units by backend cost, not by request count.
- **Graceful 429 responses.** When an agent hits a rate limit, the `Retry-After` header is not optional — it is the signal the agent uses to decide when to try again. Include it. Make the value accurate.

> [!tip] As of 2026-Q2, if you have enterprise customers building agent workflows on your API, consider a separate "agent tier" rate limit profile that reflects the actual traffic shape, rather than fitting agent workloads into limits designed for human-paced clients.

@feynman

An agent is not a polite visitor who pauses between requests — it is a parallel executor that makes as many calls as its task requires, as fast as your API allows.

@card
id: apid-ch13-c011
order: 11
title: Documentation as Prompt
teaser: Your OpenAPI spec and README are not just developer references — they are context that gets injected into agent prompts, and what you put there shapes what the agent believes your API can do.

@explanation

In many agent architectures, the agent is given a tool manifest or a fragment of your API documentation as part of its context. This is documentation-as-prompt: the text you write for humans is read by the model at runtime and used to make decisions. The implications are different from traditional documentation quality:

**What agents read in your docs:**

- OpenAPI operation summaries and descriptions
- Parameter descriptions and examples
- Error response schemas and descriptions
- Top-level README introductions and quick-start examples

**What makes documentation work for agents:**

- **Concrete over abstract.** "Returns a list of items" is vague. "Returns up to 100 items sorted by created_at descending; use the cursor field in the response to fetch the next page" is actionable. The model uses the second form to decide whether it needs to paginate and how.
- **Limitations stated explicitly.** If a search endpoint does not support fuzzy matching, say so. If a write endpoint is eventually consistent with a propagation delay, say so. An agent that does not know about a limitation will encounter it as a surprise mid-task.
- **Examples in error schemas.** An error response schema that includes an example with a recovery hint is read by the model alongside the error it receives. "If you receive this error, you must call authenticate_user first" — put this in the schema, not only in a prose guide.
- **Avoid marketing language.** "The world's most powerful search API" adds noise. Agents optimize for signal. Keep descriptions technical and literal.

> [!info] As of 2026-Q2, several API management platforms (including Kong and AWS API Gateway) support injecting OpenAPI fragments into agent contexts automatically. The quality of your spec description fields directly affects agent behavior in these setups.

@feynman

When an agent reads your API docs, it is reading them the same way it reads a user's question — looking for instructions, not background reading — so write them accordingly.

@card
id: apid-ch13-c012
order: 12
title: Cost Transparency and What Stays the Same
teaser: Agents call APIs in loops at machine speed — endpoints without cost visibility create runaway spend; and despite all the new protocols, the fundamentals from the rest of this book still apply.

@explanation

**Cost transparency for agent consumers:**

Agents operating in loops have no natural stopping point. A human developer hitting a rate limit or an unexpectedly large bill will stop and reconsider. An agent will not, unless it is explicitly given cost information to reason over.

Practical patterns for cost-transparent APIs:

- **Return cost metadata in responses.** A response header or response body field like `X-Request-Cost: 0.0012` or `{ "usage": { "tokens_consumed": 450, "cost_usd": 0.0009 } }` gives the agent (and the orchestration layer) the information to decide whether continued calling is within the user's budget.
- **Quota status in responses.** Include remaining quota in response headers (`X-RateLimit-Remaining`, `X-Cost-Budget-Remaining`). This lets the orchestration layer make early stopping decisions before hitting limits.
- **Expensive operations flagged in the schema.** If a tool is substantially more expensive than others in the set, note it in the description: "This operation processes the full dataset and typically costs 10-50x more than read operations." The model can factor this into whether it calls the tool.

**What does not change:**

Despite the new protocols and patterns in this chapter, the catalog from earlier in this book remains the foundation. REST resource modeling, stable versioning policies, authentication design, gateway routing, observability — none of this is superseded by tool-calling. Agents consume HTTP APIs. They are affected by the same breaking changes, the same versioning mistakes, and the same security holes as any other consumer.

The Refactoring Catalog (Book 1) and AI-Assisted Refactoring (Book 2) are particularly relevant: agents generate and call code. The APIs they interact with will be refactored over their lifetimes, often with AI assistance. The disciplines of backward-compatible change, contract testing, and deprecation hygiene matter more in an agent-populated world, not less — because the cost of a breaking change is now borne by automated workflows that have no mechanism to read a migration guide.

> [!info] As of 2026-Q2, the agent API space is moving quarterly. MCP's specification, provider tool-calling formats, and agent authentication conventions are all active areas of change. The patterns in this chapter represent the current stable center, not a settled spec. Revisit this chapter in roughly nine months.

@feynman

Everything in this book still applies — agents are API consumers, and a breaking change that would confuse a human SDK client will confuse an agent too, except the agent cannot read the migration guide.
