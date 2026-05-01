@chapter
id: llmp-ch08-constraints
order: 8
title: Constraints
summary: Cost, latency, context limits, memory for long sessions — the practical levers that decide whether the system survives the move from demo to scale.

@card
id: llmp-ch08-c001
order: 1
title: The Three Constraints That Bite
teaser: Cost, latency, and context. Almost every production scaling problem reduces to one of these. Knowing which one is hurting you is the first step.

@explanation

Demos run on a single user, low traffic, and an unbounded budget. Production runs on thousands of users, real traffic, and a balance sheet. The shift breaks systems in three predictable ways:

- **Cost** — input and output tokens cost money. At scale, careless prompts dwarf the engineering budget.
- **Latency** — users feel time-to-first-token. A two-second wait is fine; a fifteen-second wait is product-killing.
- **Context** — context windows are finite. Long conversations, large documents, big tool catalogs all push against the limit.

The patterns in this chapter are about each. None of them are about making the model better; all of them are about fitting the work to the constraint that's actually binding.

> [!info] Profile before you optimise. The constraint you assume is hurting you is often not the one actually hurting you. A 30-second debugging session in your traces saves a week of optimisation in the wrong place.

@feynman

Same lesson as performance work in any system. Don't optimise the loop you think is hot; profile, find the real hot loop, then optimise. LLM apps are no exception.

@card
id: llmp-ch08-c002
order: 2
title: Prompt Caching — The Free Lunch
teaser: The same prefix sent on every call should be cached server-side. Modern providers all support it. Hit rates of 70%+ are normal. The cost reduction is meaningful and the engineering is one parameter.

@explanation

Most agent calls share most of their input: the system prompt, tool descriptions, few-shot examples, retrieved corpus, the conversation up to the latest turn. Without caching, every one of those tokens is processed from scratch on every call.

Prompt caching changes that. The provider stores the cached prefix for some TTL (typically 5 minutes); subsequent calls that start with the same prefix skip the re-processing and pay around 10% of the input price for the cached portion.

```python
# Anthropic — cache_control on a stable block.
client.messages.create(
    model="claude-sonnet-4-6",
    system=[
        {"type": "text", "text": LONG_SYSTEM_PROMPT,
         "cache_control": {"type": "ephemeral"}},
    ],
    tools=tools,                           # also cacheable
    messages=conversation,
)
```

OpenAI auto-caches; Google supports explicit caching; Anthropic uses cache breakpoints. The mechanics differ, the wins are similar.

What to put in the cache:

- **System prompt** — typically 1–10K tokens, never changes per call.
- **Tool descriptions** — large, stable.
- **Few-shot examples** — large, stable.
- **The static parts of the conversation** — the older turns; the new turn is uncached.
- **Retrieved corpus snippets** — when the same docs are reused across many calls.

> [!warning] Cache hits time out. Bursty traffic gets hits; spaced traffic misses. Measure your real hit rate before celebrating the savings — calculate it as `cached_tokens / total_input_tokens` over a representative window.

@feynman

Same idea as Docker layer caching. The base layer doesn't change every build; you'd be insane to rebuild it from scratch each time. Caching prefixes is the same trick, applied to tokens.

@card
id: llmp-ch08-c003
order: 3
title: Picking the Cheapest Model That Works
teaser: Most production traffic doesn't need the frontier model. A routed system that sends the easy 80% to a small model and only escalates to frontier on hard cases halves cost without harming quality.

@explanation

Production traffic is fat-tailed: most queries are easy, a few are hard, and the average gets dragged up by the long tail. A flat "use frontier on every request" stack pays for the worst case on every call. A routed stack pays for it only when warranted.

```text
Classify (haiku, ~50ms, $0.001 / call)
   ├─ trivial   → answer with haiku            ($0.001)
   ├─ standard  → solve with sonnet            ($0.05)
   └─ hard      → solve with opus + thinking   ($0.50)
```

The classifier is itself a cheap model. It reads the request, picks a tier, and dispatches. The classifier can also output a confidence score; below threshold, escalate one tier up.

Real-world wins:

- **70–90% of traffic** routes to the cheapest tier and stays there.
- **The expensive tier** runs only when needed; its budget is amortised across the whole product, not every call.
- **Quality holds** — easy questions answered by a cheap model are still answered correctly.

> [!warning] Routing systems silently degrade. If the classifier drifts (model update, prompt change), traffic shifts between tiers and either cost or quality moves. Track tier distribution as a metric.

@feynman

Same instinct as load balancing. Send the easy work to the cheap server and reserve the expensive one for the work that actually needs it. The cost curve rewards this; the quality curve doesn't punish it.

@card
id: llmp-ch08-c004
order: 4
title: Distillation Into a Small Model
teaser: A frontier model with thinking enabled solves the task; a small fast model trained on those solutions ships the feature. Most steady-state agent work runs on distilled models in 2026.

@explanation

Distillation is the highest-leverage cost-reduction path that most teams haven't shipped yet. The pattern:

1. **Run the frontier model** on real tasks with a generous thinking budget. Save successful trajectories.
2. **Filter** — keep only the good ones (you have an eval set; use it).
3. **Fine-tune a small model** on the filtered trajectories.
4. **Deploy** the small model. The frontier becomes evals, fallback, and curation.

The distilled model captures most of the task-specific reasoning quality of the frontier model on the specific shape of work you trained for. It costs a fraction at inference. It runs faster.

It does not generalise as broadly. It learns the patterns it saw, not new ones. That's fine for steady-state production — your agent does the same shape of work all day; broad generalisation isn't the point.

In 2026, the platform fine-tuning UIs (Anthropic, OpenAI, Google, plus open-weight stacks via Together / Fireworks) handle the heavy lifting. The work is curating the training data, not running the training.

> [!info] Distillation is most effective on narrow, repetitive tasks. The customer-support agent that handles 50 categories of question is a great fit. The general assistant that handles anything is a bad one.

@feynman

Apprenticeship at scale. The senior does a thousand reviews; the junior watches all of them; eventually the junior makes most of the calls and only escalates the weird ones. Same shape, applied to models.

@card
id: llmp-ch08-c005
order: 5
title: Quantisation and Smaller-Variant Models
teaser: Open-weight teams can shrink the model itself — fewer bits per parameter, fewer parameters total. Both shift the cost-quality curve. The skill is picking the right point.

@explanation

Open-weight models can be compressed in two ways:

- **Quantisation** — reduce the precision of each weight (16-bit → 8-bit → 4-bit → lower). Memory drops linearly; quality drops slowly until it falls off a cliff. Modern 4-bit quants (GPTQ, AWQ, GGUF Q4_K_M) preserve most of the original model's quality.
- **Smaller variants** — Llama 4 ships at 8B, 70B, 405B+. DeepSeek-V3 has a smaller "lite." Pick the smallest that hits your quality bar.

The decision tree, in production order:

1. **API model first** — usually cheaper than the operational cost of self-hosting.
2. **Smaller API model** — try the cheaper tier of your provider before going open-weight.
3. **Open-weight, full precision** — when the cost crossover happens (usually >$50K/mo of inference).
4. **Open-weight, quantised** — when GPU memory is the bottleneck or you're scaling to many concurrent users.

Quantisation isn't free. The tail of your eval set will degrade more than the average. Re-run evals after quantising; the gap on the easy 90% is small but the gap on the hard 10% can be meaningful.

> [!info] vLLM, SGLang, and TensorRT-LLM all serve quantised models well. The infrastructure is mature; pick by your team's existing stack rather than chasing benchmarks.

@feynman

The same compression-vs-quality curve as image and video formats. Most production deployments live below the cliff; the work is finding it without falling over.

@card
id: llmp-ch08-c006
order: 6
title: Speculative Decoding
teaser: A small fast model proposes tokens; a big slow model verifies them in parallel. When the small model is right (most of the time), the big model gets through more tokens per second.

@explanation

Speculative decoding is the inference trick that's quietly become standard in 2026 production stacks. The idea: a small "draft" model proposes the next K tokens. The large "target" model evaluates all K in parallel (one forward pass). Tokens the target agrees with are accepted; the first disagreement triggers a re-roll from there.

Why it works:

- The target model's forward pass on K tokens is barely more expensive than a forward pass on 1 token (parallelism wins).
- The draft model is much cheaper than the target on each token it proposes.
- When the draft is mostly right, you get K tokens for the price of one target step.

Real-world speedups: 2–4× on typical workloads. No quality loss — accepted tokens are still validated by the target.

You don't usually implement this yourself. It's built into the inference engines (vLLM, TGI, TensorRT-LLM) and into the API providers' serving stacks. As an app builder, you benefit transparently from latency reductions providers ship.

> [!info] Some providers expose draft-model selection as a parameter. Most just bake it in. Either way, your latency improves; the engineering is at the inference layer.

@feynman

A typist who writes ahead and a proof-reader who validates in batches. The typist is fast and occasionally wrong; the proof-reader catches the mistakes in one pass instead of after every word. Output rate goes up; correctness holds.

@card
id: llmp-ch08-c007
order: 7
title: Streaming for Perceived Latency
teaser: Total latency matters less than time-to-first-token. Streaming makes a 15-second response feel like a 1-second one — the perceptual win is enormous and the engineering is one flag.

@explanation

A 15-second response that arrives all at once feels broken. The same 15-second response, streamed token by token, feels alive — the user reads as the model writes. The total time is identical; the experience is not.

```python
with client.messages.stream(
    model="claude-sonnet-4-6",
    messages=messages,
) as stream:
    for chunk in stream.text_stream:
        send_to_frontend(chunk)
```

Streaming changes the metric you optimise for: time-to-first-token (TTFT), not total time. The optimisation moves shift accordingly:

- **Reduce TTFT** — shorter system prompts, more aggressive caching, smaller context.
- **Tolerate longer total time** — for long-form responses, streaming hides a lot of latency.
- **Show progress on tool calls** — even when the model is mid-tool-call, surface what's happening ("Searching docs...").

> [!tip] Streaming requires the frontend to render incrementally. Make sure your UI doesn't buffer the whole response — that defeats the win. Server-sent events or WebSockets, not request-response.

@feynman

The radio show that fades in versus the one that hits play after the entire episode is recorded. The episode is the same; one feels like it's broadcasting now and one feels like it's waiting on a producer.

@card
id: llmp-ch08-c008
order: 8
title: Context-Window Math
teaser: A million-token window is impressive on paper and expensive in practice. Cost and latency both grow with input size. The rule remains: retrieve focused context, don't dump everything.

@explanation

By 2026, 1M+ token windows are common. The temptation is to throw the whole codebase, the whole document, the whole knowledge base into the prompt every call. The math fights back:

- **Cost is linear.** A 500K-token input at $3/MTok input is $1.50 per call. Multiplied by traffic, this dwarfs other costs.
- **Latency grows with input.** Time-to-first-token increases roughly linearly with input length on most serving stacks. A million-token call can take 30+ seconds before the first token comes out.
- **Long-context recall is imperfect.** Models still miss details in the middle of long documents. The "needle in a haystack" benchmarks pass; the harder "needle while doing other work" tasks degrade.
- **Cache hits help, but only on stable prefixes.** If the long context changes per call, caching doesn't save you.

The practical rule stays: retrieve focused context, don't paste everything. The retrieval chapter covered the patterns; the constraint chapter is the reason they matter.

> [!info] When you genuinely need lots of context — long-running conversations, large documents — pair the long input with prompt caching. Cache the document; only the new question is uncached. Costs drop by 70%+ on the input side.

@feynman

Loading the entire codebase into your IDE doesn't make you a better engineer; you read the part that matters. Same instinct, applied to context windows.

@card
id: llmp-ch08-c009
order: 9
title: Long Conversations Need Memory Strategies
teaser: A 100-turn chat overflows even a million-token window if you keep everything verbatim. Pick a memory strategy upfront — summarisation, retrieval over history, structured state.

@explanation

A naive chat keeps every turn forever. After 50 turns, it doesn't fit. After 200, you can't even afford to send what fits. The patterns for managing long history:

- **Summarisation** — older turns get rolled up into a running summary. The model loses verbatim detail but keeps the gist.
- **Retrieval over history** — embed every turn; on a new question, retrieve the most relevant prior turns, drop the rest.
- **Structured state** — track key facts in a typed object (user preferences, ongoing tasks, decisions made). The state is small and stable; the verbatim history can be discarded.
- **Hybrid** — recent turns verbatim, older ones summarised, plus structured state for facts that must persist.

The right pattern depends on the conversation shape:

- **Customer support** — facts matter (account number, order ID). Use structured state, plus the recent few turns.
- **Coding assistant** — recent code matters most. Sliding window of last K turns; older turns retrieved on demand.
- **Long-running research** — summary plus retrieval; the conversation might span hours or days.

> [!warning] The summary is a lossy compression. Critical facts can get lost if the summariser is sloppy. Test the summariser on hard cases before relying on it in production.

@feynman

The same pattern as taking notes in a long meeting. You don't transcribe every word; you capture decisions, action items, and context. The model's working memory needs the same discipline.

@card
id: llmp-ch08-c010
order: 10
title: Long-Term Memory Across Sessions
teaser: A user who came back yesterday should get a system that remembers them. Long-term memory is a different store from conversation history — and it has its own retrieval shape.

@explanation

Within a session, the conversation history is the memory. Across sessions, it isn't — every new session starts fresh unless you explicitly persist what to carry forward.

What goes in long-term memory:

- **Stable user facts** — preferences, settings, role, prior decisions.
- **Ongoing context** — projects in flight, tasks in progress, deadlines.
- **Notable events** — the time the user asked X, the bug they reported, the feature they requested.

The store looks different from a conversation log:

- **Indexed by user, not by session.**
- **Updated incrementally** — each session can write back new facts.
- **Retrieved on session start** — the system pulls relevant memory for the current conversation, not the whole memory blob.
- **Curated, not accumulated** — old memories age out or get summarised; the store doesn't grow unboundedly.

```python
class UserMemory:
    user_id: str
    facts: list[Fact]            # structured
    summaries: list[Summary]     # rolled-up older context
    embeddings: VectorIndex      # for semantic recall

def start_session(user_id, current_query):
    memory = load_memory(user_id)
    relevant = memory.retrieve(current_query, k=5)
    return build_prompt(current_query, relevant)
```

> [!tip] Show users what's in their memory. The product that lets them edit, delete, or correct stored facts is the product that gets trusted with sensitive information. Hidden memory is creepy memory.

@feynman

The CRM system, but for an agent. The salesperson doesn't recall every customer from memory; they look up the file before the call. Same shape, applied to a long-running assistant.

@card
id: llmp-ch08-c011
order: 11
title: Batching at Scale
teaser: For non-interactive workloads — overnight content generation, bulk classification, eval runs — batch APIs cut cost by 40–50% with no quality loss. Use them.

@explanation

Most providers offer batch APIs: submit a large list of requests; the provider runs them on flexible scheduling and returns results within 24 hours. The catch is the latency; the win is the price — typically 40–50% cheaper than synchronous calls.

When to use:

- **Bulk classification** — labelling a million tickets, tagging a corpus, scoring a backlog.
- **Content generation at scale** — overnight pre-generation of recommendations, summaries, reports.
- **Eval runs** — running your eval set against 10 prompt variants. No user is waiting; the cost saving is huge.
- **Backfills** — re-running an old workload with a new prompt or model.

When not to:

- **Interactive workloads** — user is waiting; latency matters.
- **Real-time pipelines** — batch APIs don't fit streaming use cases.
- **Volatile inputs** — if the input changes within the 24-hour window, the batch result is stale.

```python
# Anthropic batch — submit, poll, retrieve.
batch = client.messages.batches.create(
    requests=[
        {"custom_id": f"req-{i}",
         "params": {"model": "claude-haiku-4-5", "messages": [{"role": "user", "content": q}]}}
        for i, q in enumerate(queries)
    ]
)
# ... wait, then retrieve results ...
```

> [!info] Mix online and batch in your stack. Use batch for what can wait; reserve synchronous calls for what users see. Most production systems have plenty of work that can wait.

@feynman

Same logic as off-peak compute. The work that doesn't have to run now should run when it's cheaper. Batching is the cheap shift, applied to model inference.

@card
id: llmp-ch08-c012
order: 12
title: Picking the Right Constraint to Optimise
teaser: Cost, latency, and context don't all matter equally for every product. The skill is recognising which constraint is binding — and not optimising the others until it stops.

@explanation

Constraints fight each other. Reducing latency often costs more (faster models, more aggressive parallelism). Reducing cost often costs latency (cheaper models, more cached prefixes that occasionally miss). Reducing context costs quality (less retrieval, smaller windows).

The product decides which constraint matters most:

- **Real-time chat / coding assistant** — latency is everything. TTFT under 1 second is table stakes; total response time under 5s for most queries.
- **Async batch generation** — cost dominates. Latency doesn't matter; quality and price per task do.
- **Long-context document analysis** — context window dominates. Cost and latency are second-order; getting the right info into the prompt is first.
- **High-volume customer support** — cost per task. A 10% cost reduction across millions of conversations beats a frontier-model upgrade.

Optimise the binding constraint. Leave the others alone until the binding one is solved. The team that tries to optimise all three simultaneously usually ships nothing.

> [!info] Constraint priorities change as the product matures. Latency is often the demo blocker; cost is the scale blocker; context is the long-tail blocker. Different constraints will be binding at different stages of the product's life.

@feynman

The production engineer's question: which dimension is the bottleneck right now? Optimise that one. The others will become bottlenecks later, in their own time — and you'll have a clearer head to optimise them when they do.
