@chapter
id: aiadg-ch04-picking-models
order: 4
title: Picking Models
summary: Which model where, when frontier is overkill, when small isn't enough, and how to compose a team of models without burning budget.

@card
id: aiadg-ch04-c001
order: 1
title: Frontier, Mid, Small
teaser: Three tiers do most of the work in production agents. Knowing which tier each step belongs in is the cheapest performance gain you can ship.

@explanation

The 2026 model landscape lines up neatly into three buckets:

- **Frontier** — Claude Opus 4.7, GPT-5, Gemini 2 Pro. Top reasoning, top tool use, top cost. Use for the steps where being right matters more than being fast.
- **Mid** — Claude Sonnet 4.6, GPT-5 mini, Gemini 2 Flash. The workhorses. Good enough for most production traffic, fast, affordable.
- **Small / fast** — Claude Haiku 4.5, GPT-5 nano, Gemini Flash-Lite. Sub-second responses, cents per million tokens. For routing, classification, and the first pass of anything.

Production agents almost never use one tier. They route: small models triage and dispatch, mid models do the steady work, frontier models handle the cases where the mid model is uncertain or the stakes are high.

> [!info] Don't pick by benchmark scores alone. The model that's #1 on AIME is not necessarily the one you want answering customer support questions.

@feynman

Same rule as picking engineers for tasks. The principal engineer doesn't write every PR; the intern doesn't lead the architecture review. You match the level of the work to the level of the person.

@card
id: aiadg-ch04-c002
order: 2
title: Reasoning Models vs Base Models
teaser: A reasoning model thinks before it answers. A base model answers immediately. The right choice depends on whether the task rewards deliberation.

@explanation

Reasoning models — Claude with thinking enabled, GPT-5 with reasoning effort, DeepSeek-R1 lineage — produce internal chain-of-thought traces before final answers. They're disproportionately better at math, multi-step planning, and code reasoning. They're disproportionately worse at latency and per-call cost.

Base (non-thinking) models respond from the first token. For chat, simple Q&A, formatting, classification, and most tool routing, they're actually better — cheaper, faster, and the extra thinking would be wasted on a one-step decision.

Rules of thumb:

- **Use reasoning** for: planning, debugging, math, hard code generation, decisions where the answer needs to be checkable.
- **Use base** for: chat, classification, lightweight tool calls, anything user-facing where latency is felt.

> [!tip] Many SDKs let you toggle thinking per request. Treat it as a flag your agent flips when the task warrants it, not a global setting.

@feynman

Reasoning models are the ones who say "let me think about it and get back to you." Base models are the ones who answer in the meeting. Both are useful — depends entirely on what you asked them.

@card
id: aiadg-ch04-c003
order: 3
title: Open Weights vs API
teaser: API models are easier to ship; open-weight models are easier to control. The choice is about what you optimise for — speed of iteration or sovereignty over the stack.

@explanation

API models (Anthropic, OpenAI, Google) come with no infra cost, automatic upgrades, frontier capability, and a strict provider relationship. Open-weight models (Llama 4, Qwen 3, DeepSeek-V3, Mistral) come with no per-token bill, full control over deployment, custom fine-tuning, and an ops cost you have to staff for.

The decision factors that actually matter:

- **Data residency / privacy** — if user data can't leave your VPC, open weights win by default.
- **Spend ceiling** — open weights become cheaper than APIs above ~$50K/mo of inference, and the curve gets steeper.
- **Capability ceiling** — APIs still lead on the hardest reasoning and the best tool use; open weights have closed the gap on most everyday tasks.
- **Fine-tuning shape** — APIs offer managed fine-tuning; open weights offer total flexibility (LoRA, full fine-tune, custom architectures).

> [!warning] "We'll switch to open weights when traffic scales" is a common plan. Most teams that say it never do, because the API lock-in deepens with every prompt that's tuned to the model's quirks.

@feynman

Cloud vs on-prem, but for models. The cloud's faster to start; the on-prem version is yours forever. Pick based on which side of "we depend on this provider" you can live with.

@card
id: aiadg-ch04-c004
order: 4
title: MoE — Sparse but Big
teaser: Mixture-of-experts models look huge on paper but only activate a fraction per token. They're how open-weight teams compete with frontier dense models.

@explanation

A traditional dense model uses every parameter on every token. A mixture-of-experts (MoE) model has many "expert" sub-networks but a router that activates only a few per token. So a 200B-parameter MoE might run at the speed of a 30B dense model — most parameters sit idle most of the time.

DeepSeek-V3, Qwen3-MoE, Mixtral, and several frontier closed models use this. The benefits:

- **Capacity at inference cost** — total parameters keep growing while active parameters stay flat.
- **Specialisation** — different experts can handle different domains (code, language, math) without bloating each token's compute.

The catch: MoEs are harder to serve. Routing imbalances, memory layout, and batched inference all get fussier than for a comparable dense model. Frameworks have caught up (vLLM, SGLang, TensorRT-LLM all handle MoE well in 2026), but the ops burden is real.

> [!info] As an agent builder, you mostly don't care whether the model is MoE or dense. The provider abstracts it. The exception is open-weight self-hosting, where MoE meaningfully changes your serving stack.

@feynman

A consultancy with specialists. Not every project needs the cryptography expert or the database expert. The router — the project manager — pulls in only the people the current ticket actually needs.

@card
id: aiadg-ch04-c005
order: 5
title: Context Window Math
teaser: A million-token context is impressive on paper and expensive in practice. The cost and latency curve is steep — and "more context" is rarely the right fix.

@explanation

By 2026, 1M-token windows are standard at the frontier (Claude, Gemini 2 Pro, GPT-5). Some models go further. The temptation is to throw the whole codebase, the whole document, the whole knowledge base into the prompt every call.

The math fights back:

- **Cost** — input tokens are cheaper than output tokens, but cost scales linearly. A 1M-token prompt at $3/MTok input is $3 *per call*.
- **Latency** — time-to-first-token grows roughly linearly with input length on most serving stacks. A 500K-token call can take 30+ seconds before the first token comes out.
- **Quality** — long-context recall is real but imperfect. Models still miss things in the middle of long documents. The "needle in a haystack" benchmarks pass; the "needle in three haystacks while writing an essay" tasks degrade.

The practical pattern stays: retrieve focused context, don't dump everything.

> [!tip] Prompt caching changes this math substantially. If the same prefix is reused across calls, the cached portion costs ~90% less. Cache the system prompt, the doc set, the tool descriptions — anything stable.

@feynman

Loading the entire codebase into your IDE doesn't make you a better engineer. You read the part that's relevant. Same lesson, applied to context.

@card
id: aiadg-ch04-c006
order: 6
title: Prompt Caching
teaser: The prefix you reuse on every call should be cached. It's the single biggest cost reduction available to most agents and almost nobody ships day-one with it.

@explanation

Modern providers cache long prompt prefixes server-side. The next call that starts with the same prefix skips re-tokenising and re-attending to those tokens — you pay maybe 10% of the input cost on the cached portion. Anthropic, OpenAI, and Google all expose this; the API surface differs.

For agents this is a giant win because most agent calls share massive structure:

- The system prompt (1–10K tokens, identical every call).
- The tool descriptions (5–50K tokens, identical every call).
- Few-shot examples (1–20K tokens, identical every call).
- The conversation history up to the latest turn (grows, but each turn extends the previous prefix).

Only the new user message and the running tail of state are uncached. On a typical agent, you're paying full price for maybe 5% of the tokens.

```python
# Anthropic example — cache_control on a stable block.
messages.create(
    model="claude-opus-4-7",
    system=[
        {"type": "text", "text": LONG_SYSTEM_PROMPT,
         "cache_control": {"type": "ephemeral"}},
    ],
    tools=tools,  # also cacheable
    messages=conversation,
)
```

> [!warning] Cache hits time out (typically 5 minutes). Bursty traffic hits the cache; spaced traffic misses it. Worth measuring real hit rates before celebrating the savings.

@feynman

Same idea as Docker layer caching. The base layer doesn't change every build; you'd be insane to rebuild it from scratch each time. Cached prefixes are the same trick for tokens.

@card
id: aiadg-ch04-c007
order: 7
title: Fine-Tuning vs Prompting
teaser: Fine-tuning is for when prompting can't do the job — usually because the task is high-volume, narrow, and quality-sensitive. Most teams reach for it too early.

@explanation

The 2026 hierarchy of intervention, in order of cost:

1. **Better prompt** — clearer instructions, structured output, examples in the prompt. Free, instant.
2. **Few-shot examples** — 3–10 demonstrations of the right output shape. Cheap, reversible.
3. **Tool design** — clearer tool names, better descriptions, tighter schemas. Cheap, structural.
4. **Retrieval** — pull relevant context per request instead of putting it all in the prompt. Moderate effort.
5. **Fine-tuning** — train the model on your task-specific data. Expensive, slow, irreversible.

Fine-tuning earns its place when prompting and retrieval have both maxed out and you're still on the wrong side of quality. Common signs: you can't fit enough examples in context, the model keeps drifting from a tone you can't seem to specify, or you have a domain language with no overlap to the model's training data.

> [!info] LoRA / adapters are the cheap entry point. They're a small set of new parameters layered on top of the base model — fast to train, easy to swap. Full fine-tunes are the heavy artillery, reserved for cases where adapters aren't enough.

@feynman

Don't rewrite the framework when you can change the config. Don't fine-tune when you can prompt. The expensive option goes last, not first.

@card
id: aiadg-ch04-c008
order: 8
title: Embeddings as Their Own Tier
teaser: Embedding models aren't downsized chat models. They're a different tool, optimised for similarity rather than generation, and most agent stacks need at least one.

@explanation

Embedding models — Voyage, OpenAI's `text-embedding-3`, Cohere Embed v4, Anthropic's voyage acquisition family — output dense vectors that capture semantic meaning. They're cheap (orders of magnitude cheaper per call than generation), small, and you cannot ask them to write a sonnet.

What agents use them for:

- **Retrieval** — embed the query, embed the corpus, find the top-K closest documents. The first half of any RAG system.
- **Similarity gating** — "have we seen a question like this before?" Used for caching, deduplication, routing.
- **Clustering** — group conversations or trajectories by topic without explicit labels.

The model selection question for embeddings is mostly: "what's the cheapest one with acceptable retrieval quality on my domain?" Benchmark on your own data; public MTEB rankings rarely predict in-domain performance.

> [!tip] Re-embed when you change embedding models. Vectors from one model are not compatible with another. The migration cost is real and easily forgotten in budget conversations.

@feynman

Different tool for a different job. Embedding models are the index in the back of the book; generation models are the chapters. You need both, but you don't ask the index to write prose.

@card
id: aiadg-ch04-c009
order: 9
title: Routing — Cheap Triage, Expensive Substance
teaser: Send every request through the cheap model first. Only escalate when the cheap model can't confidently handle it. The savings are 5–10× without quality loss on most workloads.

@explanation

Routing is the single highest-leverage optimisation in any production agent. The pattern:

1. **Classify** — small model reads the request and tags it: trivial, standard, hard.
2. **Dispatch** — trivial → small model answers directly; standard → mid model handles; hard → frontier (with thinking on).
3. **Confidence check** — the small model can also output a confidence score; below threshold, escalate one tier up.

Real production traffic is fat-tailed: most queries are easy, a few are hard, and the average gets dragged up by the long tail. A flat "use frontier for everything" stack pays for the worst case on every request. A routed stack pays for it only when needed.

```text
classify       (haiku 4.5, ~50ms, $0.001)
   │
   ├─ trivial  → answer directly                     (haiku, fast, ~$0.001)
   ├─ standard → solve with tools                    (sonnet, ~$0.05)
   └─ hard     → solve with thinking + verification  (opus 4.7 + check, ~$0.50)
```

> [!warning] Routing systems silently degrade. If the classifier drifts (model update, prompt change), traffic shifts between tiers and either cost or quality moves. Monitor tier distribution as a metric.

@feynman

A triage nurse before the surgeon. The surgeon's not the bottleneck because of the bandwidth, they're the bottleneck because of the cost. Triage keeps the surgeon doing only what only they can do.

@card
id: aiadg-ch04-c010
order: 10
title: Composing a Team
teaser: Different models for different roles in the same agent. Cheap model drafts, mid model verifies, frontier intervenes only on disagreement.

@explanation

Beyond routing entire requests, you can compose models *within* one request. Different models play different roles in the same loop:

- **Drafter** — fast model produces the first attempt. Most outputs are good enough as-is.
- **Verifier** — mid model checks the draft against the goal, flags problems.
- **Resolver** — frontier model intervenes only when the verifier rejects the draft, or when the verifier and drafter disagree.

This pattern shows up everywhere in production: code generation (small drafts, big reviews), customer support (small responds, big handles escalations), research agents (small searches, big synthesises). It works because verifying is cheaper than generating, and most generations don't need a senior touch.

> [!tip] The verifier model should be different from the drafter when possible — same-model self-checks have correlated blind spots. Cross-model checks catch errors a self-check would miss.

@feynman

The pull-request workflow, but for tokens. The author writes; the reviewer reads; the staff engineer is consulted only on the conflicts. You don't need three of the most expensive engineers on every PR.

@card
id: aiadg-ch04-c011
order: 11
title: Benchmarks Lie, Build Your Own
teaser: Public benchmarks are useful for ruling things out, not for picking. Build a 50-task private eval that mirrors your actual workload and run it on every candidate model.

@explanation

Public benchmarks (MMLU, GPQA, SWE-bench, AIME, BFCL) measure something. They measure it on data the model providers also measure on, which means models are increasingly tuned to the public eval surface. By the time a model ships with a "92% on SWE-bench" claim, that number tells you almost nothing about how it'll handle your tickets.

What works instead is a small, private, in-domain eval:

1. **Sample** — pull 50–200 real tasks from your production logs. Anonymise.
2. **Grade** — mark expected outputs (or relative quality scores). Humans, not models.
3. **Run** — every candidate model goes through this exact set on every consideration.
4. **Maintain** — update it monthly. Tasks shift; eval rot is real.

Once you have it, model decisions take an hour, not a week. New model drops? Run the eval. Cost negotiation? Run the eval. The eval, not the marketing, is your source of truth.

> [!info] If you can't tell the difference between two models on your eval, you should be using the cheaper one. The capability gap that matters is the one your users feel.

@feynman

Don't pick a database based on TPC-C benchmarks; pick one based on whether your queries run fast on your data. Same lesson, same shape, different tier of the stack.

@card
id: aiadg-ch04-c012
order: 12
title: When the Model Is Not the Problem
teaser: Most "the model is dumb" complaints are actually prompt, tool, or data problems wearing a costume. Verify the model is the bottleneck before paying to upgrade it.

@explanation

Teams reach for a more expensive model the moment quality drops. It's almost never the right move on the first try. The four things to check before swapping models:

- **The prompt** — is the task framed clearly? Is the output schema specified? Are the examples actually demonstrating what you want?
- **The tools** — do tool names and descriptions tell the model when to use them? Are arguments well-named? Are error messages from tools informative?
- **The context** — is the model getting the information it needs? Is retrieval pulling the right snippets? Is recent state actually being passed in?
- **The data** — is your eval set representative? Are the failures clustered around a specific input shape that's underrepresented in training?

When all four are good and you still have a quality gap, *then* upgrade the model. More often than not, the gap closes from the cheaper end of the menu.

> [!warning] Model upgrades have hidden costs. New models behave differently in subtle ways — they emphasise different parts of the prompt, prefer different tool-use shapes, fail in different ways. Treat every upgrade as a re-evaluation, not a drop-in.

@feynman

Buying a faster laptop never fixes the bug. Same lesson — when something doesn't work, the answer is usually further down the stack than you want to look.
