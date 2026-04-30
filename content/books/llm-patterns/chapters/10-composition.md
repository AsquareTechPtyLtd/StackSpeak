@chapter
id: llmp-ch10-composition
order: 10
title: Composition
summary: Wiring the patterns together — pipelines, supervisors, modular components, and the "small things composed" philosophy that scales.

@card
id: llmp-ch10-c001
order: 1
title: Composition Is the Architecture
teaser: Each pattern in this book solves one problem. Real apps need several patterns, wired together. The shape of that wiring is the architecture — and most production wins live there.

@explanation

The first nine chapters covered patterns in isolation: style, grounding, retrieval, capabilities, reliability, action, constraints, safeguards. Each is useful alone for some narrow case. None of them is the architecture of a production app. The architecture is what you get when several patterns plug into each other.

A typical production agent flow:

1. **Input filter** (safeguards) — reject obvious abuse.
2. **Routing** (constraints) — pick the right model tier for this query.
3. **Retrieval** (grounding) — pull relevant context from the corpus.
4. **Generation with structured output** (style + capabilities) — the actual model call.
5. **Validation and self-check** (reliability) — confirm the answer holds up.
6. **Output policy classifier** (safeguards) — block disallowed content.
7. **Audit log** (action) — record what happened.
8. **Response to user** with citations and the work shown.

Each step is one pattern. The composition is what makes the system useful.

> [!info] Most "we should adopt LLM-X" decisions in real teams are about composition shape, not about a single pattern. The team that composes well outperforms the team that picks the trendiest single technique.

@feynman

The Unix pipeline lesson, transposed. `cat` plus `grep` plus `sort` plus `uniq` does almost any text job. None of the four is the program; the pipeline is. Same shape, applied to LLM systems.

@card
id: llmp-ch10-c002
order: 2
title: The Anthropic Composition Philosophy
teaser: "Build effective agents with composable patterns rather than complex frameworks." This is the philosophy that wins in 2026 — and it's been there in software engineering since pipes.

@explanation

Anthropic's "Building Effective Agents" guidance, published in 2024 and still right in 2026, makes a simple claim: the most successful production agents come from small, composable patterns rather than large opinionated frameworks. The patterns it describes — chained calls, routing, parallelisation, evaluator-optimiser, orchestrator-workers — all map onto the same instinct.

Why this works:

- **Composable patterns are debuggable.** Each step has clear inputs, outputs, and an obvious failure mode.
- **Composable patterns are testable.** You can mock one step and unit-test another.
- **Composable patterns survive model changes.** When the underlying model upgrades, you re-test each pattern; you don't rewrite a framework.
- **Composable patterns survive team changes.** A new engineer can read the pipeline top to bottom and understand it.

Frameworks promise productivity at the cost of flexibility. By the time you need the flexibility — and you will — the framework is the problem.

> [!info] Anthropic's recommendation isn't anti-framework; it's pro-clarity. If a framework helps you compose without obscuring the composition, use it. If it hides what's happening behind a "magic" layer, don't.

@feynman

The same lesson the Unix philosophy taught the systems community decades ago. Small tools that do one thing well, glued by simple interfaces. Different decade, same instinct.

@card
id: llmp-ch10-c003
order: 3
title: Five Common Composition Shapes
teaser: Chaining, routing, parallelising, evaluator-optimiser, orchestrator-workers. Most production agents are one of these — or a small combination of two.

@explanation

The shapes worth recognising:

- **Chain** — A → B → C, sequential. Each step's output feeds the next. Used for multi-stage tasks where each stage is well-defined (extract → enrich → format).
- **Route** — input goes to one of several handlers based on a classifier. Used for triage and tier selection.
- **Parallelise** — same input to multiple handlers, results merged. Used for best-of-N, multi-perspective generation, parallel tool calls.
- **Evaluator-optimiser** — a generator produces a draft; a separate evaluator scores or critiques; the cycle repeats until the evaluator approves. Used for high-quality output that benefits from revision.
- **Orchestrator-workers** — one orchestrator decomposes a task and dispatches to specialised workers; workers report back. Used for tasks with heterogeneous subtasks.

Real systems combine these. A research agent might route by query type, then within each type chain retrieval → generation → verification, with parallelisation on the retrieval step.

> [!tip] Draw the shape on a whiteboard before you write code. If you can't draw it, the system is already too complex. Start over with a simpler composition.

@feynman

The five basic data-flow patterns. Once you see them, you spot them everywhere — in distributed systems, in microservice architectures, in build systems. LLM composition rides the same rails.

@card
id: llmp-ch10-c004
order: 4
title: Pipelines Over Free-Form Loops
teaser: A pipeline declares its steps; a free-form agent loop discovers them. Pipelines are easier to debug, cheaper to run, and good enough for most production work.

@explanation

There's a continuum:

- **Pipeline** — fixed sequence of steps. Each step is a known pattern. You can predict the cost and latency before running.
- **Loop** — model decides what to do next at each step. More capable; more expensive; harder to predict.

The honest assessment: most tasks are pipelines. They have a well-defined input, a small set of clearly-needed steps, and a known output. Letting a model decide which steps to take is overhead and unpredictability — for tasks where the steps are already obvious.

Use pipelines when:

- The task is well-defined (extraction, classification, summarisation, structured response).
- The cost ceiling matters.
- The steps are stable across inputs.

Use loops when:

- The task genuinely requires the model to decide what to do.
- Inputs vary widely in shape.
- The cost of letting the model wander is justified by the quality lift.

Many "agents" in production are actually pipelines that the team called agents because the marketing was better. There's nothing wrong with that — the architecture is what matters.

> [!info] "Agentic" is a spectrum, not a binary. The chain is the most predictable end; the open-ended loop is the most flexible. Pick the point that matches the task, not the brand of the framework.

@feynman

The static vs dynamic dispatch trade-off, applied here. Static is faster and easier to reason about; dynamic is more flexible but expensive. The right answer depends on what the program needs to do.

@card
id: llmp-ch10-c005
order: 5
title: Modular Components
teaser: Each step in the pipeline is a function with clean inputs, outputs, and dependencies. Treat them like microservices — they get versioned, tested, and replaced independently.

@explanation

A useful component has:

- **A clear contract** — typed inputs and outputs (Pydantic, dataclasses, structured types).
- **No hidden dependencies** — the function takes what it needs as arguments. No reaching into globals, no implicit state.
- **A clear cost / latency profile** — you know roughly what running this step costs.
- **Testable in isolation** — given the inputs, you can predict the outputs (or score them).
- **Replaceable** — you can swap one implementation for another without changing callers.

A component that depends on the rest of the pipeline being in a specific state is not a component; it's a slice of a monolith. The pipeline architecture only pays off if components are genuinely independent.

```python
@component(name="grounded_qa")
def grounded_qa(question: str, sources: list[Source]) -> Answer:
    prompt = build_prompt(question, sources)
    raw = llm.complete(prompt)
    return parse_answer(raw, sources)
```

The same component can be invoked from a unit test, a notebook, the production pipeline, or another agent's chain. That's the win.

> [!warning] Don't let the framework dictate the component shape. Components should outlive the framework you happen to be using. Plain Python functions with typed inputs and outputs are the most portable.

@feynman

The microservices instinct. Each service has a contract; the architecture is what services exist and how they call each other. LLM components are smaller services on the same principle.

@card
id: llmp-ch10-c006
order: 6
title: Versioning the Pipeline
teaser: Prompts change. Models change. Tools change. If you don't version the pipeline as a unit, you can't tell what shipped on Tuesday from what's running on Friday.

@explanation

A pipeline is the composition of:

- The prompts at each step (versioned).
- The models used (pinned).
- The tools available (catalog version).
- The retrieval indexes (corpus version + embedding model).
- The component implementations (code version).

When any one of these changes, the pipeline's behaviour changes. The team needs a single version pin that captures the whole composition:

```yaml
pipeline_version: 2026.04.28-1
components:
  router:        v3
  retriever:     v7 (corpus 2026-04-25, model voyage-v3)
  generator:     gpt-5-2026-03-14, prompt v12
  verifier:      claude-haiku-4-5, prompt v4
  policy_check:  classifier v9
```

Production runs log the pipeline version. When a metric shifts, you can ask "what changed in pipeline_version Y?" and get a definitive answer.

The discipline pays back the moment something breaks. Without it, "the agent got worse this week" becomes a forensic exercise. With it, it's a diff.

> [!info] Treat the pipeline version like a software release. Tag it. Promote it through environments (dev → staging → canary → prod). Roll back is a config change, not a deploy.

@feynman

The same SemVer hygiene every backend team learned. Pipelines are deployed software; they earn the same discipline.

@card
id: llmp-ch10-c007
order: 7
title: End-to-End Observability
teaser: Per-step logging is necessary; per-pipeline tracing is what makes debugging tractable. One trace ID, every step inside, end-to-end timing and cost.

@explanation

A composed pipeline is a distributed system. Each step is a service call (often to a model provider). Each can fail or slow independently. Each contributes to total cost and latency. The observability surface mirrors that.

The minimum:

- **One trace ID per request.** Every step inside the pipeline tags its logs and metrics with that ID.
- **Per-step latency.** Where time is spent. Which step is the bottleneck.
- **Per-step cost.** Which step is the wallet drain.
- **Per-step error rate.** Which step is fragile.
- **End-to-end success rate.** What fraction of requests produce a usable answer.

LangSmith, Helicone, Braintrust, OpenLLMetry, Logfire, Datadog's LLM observability — all of them solve this category. The difference is integration depth with your stack. Pick one; integrate it before you scale; never look back.

```text
Trace 1f2a3b4c (pipeline_version 2026.04.28-1)
  router         12ms   $0.0001
  retriever     142ms   $0.0008  (12 chunks, top-K from 50)
  generator    2400ms   $0.0421  (1840 input + 230 output tokens)
  verifier      890ms   $0.0028
  policy_check   30ms   $0.0001
  total        3474ms   $0.0459
```

> [!tip] Save raw inputs and outputs at each step in the trace, not just summary metrics. Six months from now you'll want to replay an old failure on a new model; only the raw record lets you do that.

@feynman

Same as APM tools for distributed systems. You don't debug a microservice failure by looking at the average latency; you look at the trace and find which span blew up.

@card
id: llmp-ch10-c008
order: 8
title: Testing Composed Systems
teaser: Test components in isolation; test the pipeline end-to-end; eval against a labelled set. Three layers, each catching different failures. Skip any one and the gaps show up in production.

@explanation

The testing pyramid for an LLM pipeline:

- **Unit tests for components.** Each component, given fixed inputs, produces predictable outputs (or scored outputs). Mock the model when you can; use cheap models for the test runs when you can't.
- **Integration tests for the pipeline.** End-to-end runs on a small fixed set of inputs. Catches wiring errors, schema mismatches, and dependency issues.
- **Eval against a labelled set.** The full pipeline against your real eval set. Quality, latency, cost, refusal rates. Run on every release.

What goes in the unit tests:

- **Schema compliance** — the component returns the typed shape it claims.
- **Edge cases** — empty inputs, malformed inputs, oversize inputs.
- **Failure paths** — what happens when the model errors, when the tool fails, when retrieval returns nothing.

What goes in eval:

- **Quality** — a labelled set of inputs with expected outputs (or scores).
- **Latency** — track p50, p95, p99 over the eval set.
- **Cost** — track per-task spend across the eval.
- **Safety** — should-refuse and should-allow inputs.

> [!info] LLM apps inherit the testing maturity of the rest of the codebase. Teams that ship without tests for traditional code rarely add tests for LLM components. Teams with strong test discipline extend it naturally.

@feynman

The same pyramid every backend team learned. Unit tests for individual functions, integration tests for the wiring, end-to-end tests for the user-visible behaviour. LLM pipelines fit the pattern.

@card
id: llmp-ch10-c009
order: 9
title: When Composition Collapses
teaser: A pipeline that's grown to twenty steps is a sign you're solving the wrong problem. The fix is rarely "add another step"; it's usually "consolidate three steps into one."

@explanation

Pipelines grow. Each new requirement becomes a step; each step ossifies; over time you have a chain that nobody fully understands. The signs that the composition has collapsed under its own weight:

- **No one can draw the pipeline without checking the code.** It's grown beyond what fits on a whiteboard.
- **Adding a feature touches every step.** Each step has implicit dependencies on the others.
- **Step ownership is unclear.** The team can't say which person or sub-team owns each step.
- **Performance regressions can't be localised.** When latency drifts up, the cause spans multiple steps.

The fix is consolidation. Look for steps that are doing the same kind of work and merge them. Look for steps that exist because of historical decisions that no longer apply. Look for "we added this for one customer two years ago" steps and remove them.

A useful rule: a pipeline of more than seven explicit steps is a candidate for refactoring. Above ten, it's an obligation.

> [!warning] Resist the instinct to wrap a sprawling pipeline in a "framework" to hide the complexity. The framework doesn't simplify the system; it hides what needs simplifying.

@feynman

Same lesson as in any codebase. The function that's grown to 500 lines isn't fixable by extracting a helper; it's a sign the abstraction is wrong. Pipelines are the same.

@card
id: llmp-ch10-c010
order: 10
title: A Worked Composition
teaser: A customer-support agent in 2026 stitches together routing, retrieval, generation, verification, and policy check. Roughly 200 lines of code, tens of millions of conversations a year.

@explanation

A concrete sketch:

```python
def support_agent(query: str, user: User) -> Response:
    # 1. Input safety check.
    if input_filter.is_abuse(query):
        return controlled_refusal()

    # 2. Route by query type.
    intent = classifier.classify(query)            # haiku, ~50ms
    if intent == "billing":     handler = billing_pipeline
    elif intent == "tech":      handler = tech_pipeline
    else:                       handler = general_pipeline

    # 3. Run the pipeline. Each is a chain of components.
    response = handler.run(query, user)

    # 4. Output policy check.
    if policy_check.is_violation(response):
        return controlled_fallback()

    # 5. Audit + return.
    audit_log.write(query, response, intent)
    return response
```

Each `handler.run` internally does retrieval, generation, verification, citations. Each pipeline is small (4–6 components), focused, testable. The composition is one router and three pipelines, each composed of a few patterns from earlier chapters.

This shape ships. It runs at scale. It's debuggable. It's the kind of thing teams that succeed in 2026 build — not the magic agent that does everything, but the careful pipeline that does one thing well per intent.

> [!info] You don't see this kind of architecture in conference talks because it's not exciting. You see it in production because it works.

@feynman

The boring system that ships outperforms the elegant system that doesn't. Same lesson as every other corner of software engineering.

@card
id: llmp-ch10-c011
order: 11
title: When To Reach for an Agent vs a Pipeline
teaser: A pipeline answers "what do I do for this kind of input?" An agent answers "what should I do, given this specific input?" Pick by the variability of the input and the steps it warrants.

@explanation

The decision rule:

**Use a pipeline when:**
- The task fits a small set of known patterns. You can enumerate the inputs.
- You can describe in advance which steps will be needed.
- Predictable cost and latency matter.

**Use an agent loop when:**
- Inputs vary widely; one input might need three steps and another fifteen.
- The set of useful actions can't be enumerated in advance.
- The model genuinely benefits from deciding the next step at each turn.

Pipelines are usually right for: classification, extraction, summarisation, structured Q&A, content generation with stable shape. Agents are usually right for: research, debugging, multi-step automation, anything where "what to do next" is itself the hard part.

A trap to avoid: building an agent loop because it's "more flexible" when a pipeline would do. The flexibility is rarely free. Each agent decision is a model call, a token spend, a chance to drift. If the steps are stable, hard-code them.

> [!info] In the agents book in this catalog, this same lesson runs through multiple chapters. The pipeline-vs-agent question is one of the most important architectural decisions; the cost of getting it wrong is months of unnecessary engineering.

@feynman

The static vs dynamic dispatch question, again. Some problems are static and stay that way; some need runtime flexibility. The work is recognising which is which.

@card
id: llmp-ch10-c012
order: 12
title: What This Book Bought You
teaser: A pattern catalog. Names for things your team can now reuse. The wiring instinct that converts patterns into systems. Patterns are leverage; composition is the architecture.

@explanation

A short recap of what each chapter contributed:

- **Pattern Thinking** — the framing. Why patterns and not frameworks, and what kinds of problems each family addresses.
- **Style Control** — output shape, tone, format. The interface between the model and the next step.
- **Grounding** — answers from sources you provide, with citations the user can verify.
- **Retrieval** — finding the right context to ground on, beyond the toy demo.
- **Capabilities** — extending what the model can do via tools, code, vision, computer use.
- **Reliability** — voting, judging, reflecting, validating. Reducing the variance you care about.
- **Action** — the discipline of taking real actions in the world without breaking it.
- **Constraints** — cost, latency, context. The levers that decide whether the system survives scale.
- **Safeguards** — input filters, output validation, policy classifiers, audit logs. Defence in depth.
- **Composition** — wiring it all together into a system that ships.

The chapters work in any order. The composition is what changes the patterns from interesting techniques into a working architecture.

> [!info] You won't use every pattern. Most production systems use three to five, composed cleanly. The skill is recognising which three — and the discipline is composing them carefully enough that the system holds up under real traffic for real users.

@feynman

The book's job was vocabulary. Now you can name what your team is doing, point at where the failures live, and pick the next pattern with intent. From here, the work is the same as any engineering discipline — practice, measure, iterate, ship.
