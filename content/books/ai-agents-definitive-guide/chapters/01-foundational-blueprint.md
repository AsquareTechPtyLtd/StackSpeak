@chapter
id: aiadg-ch01-foundational-blueprint
order: 1
title: Foundations
summary: What separates an LLM from an agent, and the state-machine paradigm that underpins both.
icon: book

@card
id: aiadg-ch01-c001
order: 1
title: What is an LLM Agent?
teaser: An LLM by itself just predicts text. Wrap it in a loop that can call tools and react to results, and you have an agent.

@explanation

A standalone language model is a single-pass token generator. You give it a prompt, it returns a completion, and the conversation ends. Useful — but confined to whatever it learned during training.

An LLM *agent* embeds the same model in a loop that can act on the world. The agent reasons about the next step, calls a tool to do something, reads the tool's output back into context, and decides again. That feedback loop is what separates the two.

- **Reasoning** — the model proposes the next action.
- **Action** — a tool runs (search, code, an API call).
- **Feedback** — the result re-enters the prompt as new context.
- **Adaptation** — the next reasoning step accounts for the new evidence.

@feynman

Like the difference between a junior dev locked in a room with a notebook and one with Stack Overflow, an IDE, and a debugger. Same person in the seat — the tools and the feedback loop are what produce the work.

@card
id: aiadg-ch01-c002
order: 2
title: Reason → Act → Observe
teaser: The basic agent cycle. Three steps that, looped, turn a static model into something that adapts.

@explanation

Every agent reduces to the same three-step cycle, repeated until the goal is met or a stopping condition fires.

1. **Reason** — given the current state, decide what to do next.
2. **Act** — invoke a tool, run code, query an API.
3. **Observe** — read the result back into context.

The loop continues from there. The model's *next* decision is informed by the *previous* action's outcome. Without the observe step, you have a chatbot. With it, you have something that can correct itself.

@feynman

Like a chef tasting a dish, adjusting the seasoning, and tasting again. Each loop is small; the *sequence* of loops is where intelligence shows up.

@card
id: aiadg-ch01-c003
order: 3
title: Stateless vs Stateful
teaser: Whether the model remembers anything between calls is the line between using an LLM and building an agent.

@explanation

A **stateless** call treats the model as a black box: prompt in, completion out, nothing remembered. Run it twice with the same prompt and you get two independent answers.

```python
llm = ChatOpenAI(model="gpt-5-mini")
response = llm.invoke("What are AI agents?")
print(response.content)
```

A **stateful** workflow keeps a structured memory across turns: messages, tool results, intermediate plans. Each new step starts from where the last one left off.

> [!info] In LangGraph, state is just a TypedDict that nodes read from and write to. Plain Python — no magic.

@feynman

Stateless is a REST endpoint — every request stands alone. Stateful is a session — the server remembers who you are between requests.

@card
id: aiadg-ch01-c004
order: 4
title: Finite State Machine
teaser: The base paradigm of agent control flow. A small vocabulary that scales surprisingly far before you need anything fancier.

@explanation

A finite state machine (FSM) models a system as a small set of named states and the moves between them. The same pattern you've already seen in compilers, network protocols, and form wizards — applied to agent reasoning.

- **State** — a snapshot of what the agent knows right now (messages, progress markers).
- **Event** — something that happened since the last decision (tool returned, user replied).
- **Guard** — a check that decides which transition to take.
- **Action** — work performed during the transition (call a tool, save a checkpoint).
- **Termination** — the condition that ends the run.

FSMs shine when behavior alternates between a few stable modes and you care about being able to resume after a crash — every state is a natural checkpoint.

@feynman

Like a checkout flow: cart → address → payment → review. Each step has guards (*"is the address valid?"*) and actions (*"charge the card"*). Crash at "payment" and you can resume there, not back at "cart".

@card
id: aiadg-ch01-c005
order: 5
title: Hierarchical State Machine
teaser: An FSM whose states can themselves contain states. Solves the spaghetti problem you hit when an FSM grows past a handful of nodes.

@explanation

Once you add planning, reflection, retries, and approval gates, a flat FSM either duplicates logic across edges or becomes a tangle of routes. Hierarchical state machines (HSMs) fix this by letting states *contain* other states.

- **Superstate** — wraps a group of substates, defining shared entry/exit logic and policies.
- **Substate** — a concrete mode that lives inside a superstate and inherits its guards.
- **History marker** — *"remember where I was"* so resuming the superstate lands at the right substate.
- **Parallel region** — child regions that advance independently and rejoin later.

In agent terms, a `WORKING` superstate might contain `PLAN`, `ACT`, and `REFLECT` substates. Rate limits or safety filters defined on the superstate apply to all three for free.

@feynman

Like nesting folders. The parent folder's permissions apply to everything inside it; you don't re-set them on every file.

@card
id: aiadg-ch01-c006
order: 6
title: State Schema
teaser: A typed dict that defines the bus every node reads and writes. The shared memory of an agent graph.

@explanation

In LangGraph, the state schema is just a Python `TypedDict` (or Pydantic model). It declares the keys nodes are allowed to mutate — typically a message list and any progress markers.

```python
class AgentState(TypedDict):
    messages: Annotated[List[BaseMessage], add_messages]
    working_last: str | None
```

The `Annotated[..., add_messages]` is LangGraph's reducer pattern: when two nodes both write `messages`, they're appended rather than overwriting. Custom reducers handle merging for any field.

> [!tip] Keep the schema small. Anything not in the schema can't be persisted by the checkpointer — and anything that *is* in the schema is read by every node, so it pays to be precise.

@feynman

Like a JSON request body that every middleware can read and mutate before the response is sent. The schema is the contract.

@card
id: aiadg-ch01-c007
order: 7
title: Nodes and Edges
teaser: LangGraph's two primitives. Nodes do work; edges decide what runs next.

@explanation

A **node** is a function from state to state. It takes the current snapshot, performs reasoning or a side effect, and returns the keys it changed. The framework merges your return into the shared state.

An **edge** wires the graph. Plain edges always fire (`A → B`); conditional edges run a small router function and return the name of the next node.

```python
def llm_node(state: AgentState) -> AgentState:
    ai = llm.invoke(state["messages"])
    return {"messages": [ai]}

graph.add_node("llm", llm_node)
graph.add_conditional_edges("llm", route, {"tools": "tools", END: END})
```

Nodes stay deterministic in shape — the LLM call inside is non-deterministic, but the *graph topology* is fixed. That's what makes the system auditable.

@feynman

Nodes are React components — each owns a piece of work. Edges are the router — they decide which screen renders next given the URL (state).

@card
id: aiadg-ch01-c008
order: 8
title: Tools
teaser: How an LLM acts on the world. A tool is just a typed function exposed to the model with a description it can read.

@explanation

In LangChain, you mark a function with `@tool` and the framework builds the schema the model sees from the function's name, signature, and docstring. The docstring is *not* optional — it's the description the LLM uses to decide whether to call this tool at all.

```python
@tool("internet_search")
def internet_search(query: str) -> str:
    """Search Google via SerpAPI for up to date information."""
    ...

llm.bind_tools([internet_search], tool_choice="auto")
```

> [!warning] A vague docstring produces invalid tool calls. Treat it like an API description, not a code comment.

@feynman

Like exporting a function from a worker thread. The docstring is the type signature the consumer reads — get it wrong and they call you wrong.

@card
id: aiadg-ch01-c009
order: 9
title: The Tool-Calling Loop
teaser: The minimum viable agent — a `while` loop that lets the model call tools until it stops asking.

@explanation

Before reaching for LangGraph, you can write a stateless agent in ~30 lines. The shape is always the same:

1. Send the conversation to the model.
2. If the response has `tool_calls`, run each tool and append the results.
3. Otherwise, return the final answer.
4. Bound the loop with `max_steps` so a stuck model doesn't burn your budget.

```python
for _ in range(max_steps):
    ai = llm.invoke(messages)
    messages.append(ai)
    if not ai.tool_calls:
        return ai.content
    for call in ai.tool_calls:
        result = tool_map[call["name"]].invoke(call["args"])
        messages.append(ToolMessage(
            content=result,
            tool_call_id=call["id"]
        ))
```

@feynman

Like polling a long-running job until status is *done*. The trick is the timeout — without `max_steps`, a confused model will loop forever.

@card
id: aiadg-ch01-c010
order: 10
title: Memory and Checkpointing
teaser: Save state at every node so the agent can resume — and use thread IDs to keep parallel conversations isolated.

@explanation

A **checkpointer** persists the graph's state after each node runs. On resume, the framework rebuilds the conversation from the last checkpoint. LangGraph's `MemorySaver` does this in-process; production setups use Postgres or Redis.

```python
checkpointer = MemorySaver()
app = graph.compile(checkpointer=checkpointer)

cfg = {"configurable": {"thread_id": "session-1"}}
app.invoke({"messages": [HumanMessage("start")]}, config=cfg)
```

The `thread_id` is the conversation's identity. Same id → continues the same memory. Different id → branches a new conversation that doesn't see the old one. Switching threads is how you let users explore alternatives without contaminating the main path.

@feynman

Like git branches against the same repo. `thread_id` picks the branch; the checkpointer is the object database that holds every commit.

@card
id: aiadg-ch01-c011
order: 11
title: Multi-Agent System (MAS)
teaser: When one agent's responsibilities grow too wide, split the work across specialized agents under a supervisor.

@explanation

A single contributor can build the whole product. Past a certain size, you split into backend / frontend / QA and hire a tech lead. Multi-agent systems mirror this exactly: a supervisor agent routes work to specialized sub-agents.

- **Supervisor** — picks which sub-agent handles the next step.
- **Specialists** — each owns a narrow domain (search, planning, code-writing).
- **Shared state** — the message bus all of them read and write.

Architecturally this is just an HSM: the supervisor is the superstate, specialists are substates. Shared policies (rate limits, safety filters) live on the superstate and apply to all of them.

@feynman

Like a small dev team. You start as a solo IC. You hit a complexity wall, hire specialists, then realize someone has to coordinate them — that's the supervisor agent.

@card
id: aiadg-ch01-c012
order: 12
title: Orchestrated Autonomy
teaser: Today's agents don't redesign their own control graph. They make choices inside a graph you wrote.

@explanation

It's tempting to imagine agents as a `deus ex machina` — a god from the machine that solves your problem with no plumbing. That's not what's deployable today. Real agents are engineered systems with bounded autonomy.

- **Can do** — pick which tool to call, decide if more steps are needed, branch between predefined paths, write small bits of code to determine next steps.
- **Can't do (yet)** — generate new graph topologies on the fly, invent new tools, redefine their own architecture.

The autonomy spectrum runs from a single-guard router (one decision) → tool-calling agent (multi-step reasoning) → MAS (specialists under a supervisor). Almost every shipped system lives in the middle of that spectrum.

@feynman

Like Tesla autopilot. It can change lanes, brake, follow the road you're on. It can't decide where you're going. The framework is yours; the choices inside it are the agent's.

@card
id: aiadg-ch01-c013
order: 13
title: Why Constraints Are Features
teaser: Agents are useful *because* they're bounded. Strip the constraints and you get something that won't ship.

@explanation

Humans don't operate with unconstrained freedom either. Coding standards, project requirements, and code review all bound a developer's choices — and that structure is what makes their output trustworthy.

Agents inherit the same trade-off. The tools you give them, the safeguards you enforce, and the workflow you allow them to operate inside are what make the system safe to deploy. A maximally autonomous agent is also maximally unpredictable — and unpredictability is what gets pulled from production.

> [!info] The AI Scientist v2 had a paper accepted at an ICLR workshop in 2025. Two of its three submissions were rejected, and even the accepted one had methodological gaps. The bounded version that *also* fails on rigor is closer to reality than either the hype or the doomer take.

@feynman

Constraints are guard rails on the highway. They don't slow you down — they're the only reason you can drive 70.
