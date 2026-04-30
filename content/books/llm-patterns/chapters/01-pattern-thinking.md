@chapter
id: llmp-ch01-pattern-thinking
order: 1
title: Pattern Thinking
summary: Why building on language models needs its own pattern catalog — and a tour of the families that the rest of the book unpacks.

@card
id: llmp-ch01-c001
order: 1
title: Why Patterns Now
teaser: Every era of software grew its own pattern catalog. We're now ten years into LLM apps and a decade past needing one — same problems keep showing up in different teams' codebases.

@explanation

The Gang of Four book gave object-oriented engineers a shared vocabulary in 1994. Patterns for enterprise apps, REST, microservices, frontend, ML — each crystallised once a generation of engineers had hit the same problems independently. LLM apps are at that point now.

The recurring problems are remarkably consistent across teams:

- Output that's the wrong shape or wrong tone.
- Answers that are confidently wrong.
- Models that don't know your private data.
- Models that can't reach the systems your task touches.
- Costs that grow faster than usage.
- Behaviour that drifts as you change prompts or upgrade providers.

A pattern catalog isn't a magic fix. It's a shorthand. Once "use grounded retrieval here" and "this needs a verifier pass" are phrases your team understands without explanation, conversations move faster and accidents drop.

> [!info] Patterns are descriptive, not prescriptive. They name what's already working in the wild — they don't dictate that every app must use them.

@feynman

Same reason `git rebase` and `merge --squash` are vocabulary. You don't reinvent the workflow on every PR; you point at the pattern and the team knows what you mean.

@card
id: llmp-ch01-c002
order: 2
title: How LLM Apps Differ
teaser: Traditional code is deterministic — same input, same output. LLM apps aren't. Most patterns in this book exist to manage the gap between determinism and probability.

@explanation

A function that returns `42` on Tuesday returns `42` on Wednesday. A model that summarises a paragraph might give you slightly different words on every call, and very different words if the paragraph changes by a comma. The output distribution moves; engineering against it requires a different posture.

What this changes about the way you design:

- **Schemas instead of strings** — the contract between model and consumer has to be explicit, not implicit.
- **Evals instead of unit tests** — assertions are statistical, not exact.
- **Retries with feedback** — a single failure isn't a crash; it's a sample to learn from.
- **Cost as a first-class metric** — the same input can produce wildly different costs depending on how the model decides to think.
- **Versioning the prompt** — the prompt is part of the deployed artifact, same as the binary.

> [!tip] If you're treating an LLM call the way you treat a hash function, you'll discover the difference at 3 AM. Better to internalise it before the page comes in.

@feynman

The shift from compiled code to working with humans. People give you slightly different answers each time, and the system has to be designed around that — not against it.

@card
id: llmp-ch01-c003
order: 3
title: Foundation Models as a Substrate
teaser: You don't train a model for each app any more. You build on top of foundation models the way you build on top of operating systems — and the patterns assume that.

@explanation

Pre-2022, "ML for an app" meant collecting a dataset, training a custom model, and deploying it. The cost was high, the time was long, and the ceiling was modest unless you had Google's data.

Foundation models flipped the curve. A handful of frontier providers — Anthropic, OpenAI, Google, Meta, plus a long tail of open-weight publishers — train large general-purpose models. App builders consume them as APIs or as weights. The custom training step is gone or pushed to the margin (fine-tuning, LoRA adapters).

The implications for patterns:

- The unit of leverage is the prompt and the surrounding system, not the model weights.
- Capability comes from picking the right model and feeding it the right context — not from training.
- Cost and latency tradeoffs become provider-tier choices.
- New model releases change the optimum; the architecture doesn't have to.

> [!info] This is why every pattern in this book treats the model as an abstraction. The patterns work whether you're calling Claude, GPT, Gemini, Llama, or a model the industry hasn't released yet.

@feynman

Same shift as cloud computing. You don't run your own server farm; you stand on top of someone else's. The job becomes "what do you build on top," not "how do you maintain the foundation."

@card
id: llmp-ch01-c004
order: 4
title: The Four Recurring Problems
teaser: Every chapter in this book exists because of one of four problems. Spot which one bites you, and you'll know which family of patterns to reach for.

@explanation

The problems that drive almost every LLM-app design decision:

- **Style and shape mismatch** — the model produces something true but in the wrong format, register, or structure for what you need next.
- **Missing knowledge** — the model wasn't trained on your data, your customer's data, or anything from after its knowledge cutoff.
- **Missing capability** — the model can reason but can't reach external systems, can't run code, can't see images, can't act.
- **Reliability and safety** — the model is right most of the time, and the rest of the time it's confidently wrong, expensive, or unsafe.

The chapters that follow correspond to these:

- **Style** → the style and structured-output patterns.
- **Knowledge** → grounding and retrieval.
- **Capability** → tools, functions, and agents.
- **Reliability** → verification, constraints, safeguards, composition.

Most production failures map cleanly to one of these four. Recognising the family is half the work.

> [!tip] When something feels off and you can't articulate why, check whether the failure is style, knowledge, capability, or reliability. The taxonomy is small enough to memorise and reliable enough to use under pressure.

@feynman

The four-quadrant trick. Most diagnostic frameworks worth using fit on one whiteboard, and "where does my failure live" is one of them.

@card
id: llmp-ch01-c005
order: 5
title: Prompt and Context
teaser: A prompt is the instruction; the context is everything else the model sees with it. Most pattern questions reduce to "what goes in the context, in what shape."

@explanation

The model only sees what you put in front of it. That input is structured into:

- **Instructions** — what the model should do, in what voice, with what constraints.
- **Examples** — demonstrations of the expected behaviour.
- **Retrieved content** — documents, snippets, prior conversation.
- **Tool descriptions** — what's available to call.
- **The user's actual request** — usually the smallest part of the prompt.

Most engineering work in LLM apps lives in deciding what goes into each of these slots — and how. Vague instructions produce vague answers. Too many examples drown the request. Retrieval that pulls the wrong snippet sends the model down the wrong path.

The book's patterns mostly answer "what should be in the context, in what shape, when?" The retrieval chapter answers it for knowledge; the style chapter for tone; the action chapter for tools.

> [!info] Tokens in the context aren't free. They cost money, slow latency, and dilute attention. The pattern question is always "what's the minimum useful context for this task."

@feynman

Same lesson as writing a good ticket. The work the engineer does later depends almost entirely on how clearly the ticket framed it. Models, like engineers, run on the inputs they're given.

@card
id: llmp-ch01-c006
order: 6
title: AI Engineering, Not ML
teaser: Building on foundation models is a different discipline from training models. The skills overlap less than you'd think — and the day-to-day work is much closer to systems engineering than to data science.

@explanation

Classical ML engineering centres on data — collecting it, labelling it, splitting it, training models on it, evaluating against held-out sets. The job is statistical, the artifacts are model weights, the deliverable is a model.

AI engineering, the term Chip Huyen and others popularised, centres on systems. The model is given. The job is to build the prompts, the retrieval, the tool catalog, the evaluation harness, the rollout strategy, the cost controls. The artifacts are prompts, schemas, retrieval indexes, traces.

The distinction matters because:

- The skills required are different. AI engineers need API design, distributed systems, observability — not gradient descent.
- The hiring funnel is different. A great Kaggle competitor and a great AI engineer are not the same person.
- The advice is different. ML "best practices" don't always apply; foundation models break some of the assumptions.

> [!tip] If your team is hiring "ML engineers" to build LLM apps, you're hiring for the wrong skill set. Hire systems engineers and let them learn the LLM-specific patterns; the inverse path is harder.

@feynman

The shift from "I assemble my own PC" to "I build apps on top of laptops." Both are computing; the day-to-day is barely the same job.

@card
id: llmp-ch01-c007
order: 7
title: Patterns in This Book
teaser: Style, grounding, retrieval, capabilities, reliability, action, constraints, safeguards, composition. Each is a family, not a single trick.

@explanation

A high-level tour of the families that follow. Each chapter unpacks a problem area into specific patterns with code, tradeoffs, and when-not-to-use guidance.

- **Style Control** — getting the model to produce output in the tone, format, and structure your downstream consumer expects.
- **Grounding** — making the model answer from sources you specify rather than from training memory.
- **Retrieval** — finding the right context to ground on, at scale, when "just put the document in the prompt" doesn't fit.
- **Capabilities** — extending what the model can do with tools, function calling, and external services.
- **Reliability** — checking, voting, verifying, and structuring output to keep quality steady.
- **Action** — letting the model do things, not just say things, with safety on the action surface.
- **Constraints** — working inside latency, cost, and context-window limits without giving up quality.
- **Safeguards** — guardrails for content, jailbreak resistance, output validation against policy.
- **Composition** — wiring patterns together into pipelines that scale beyond a single model call.

> [!info] You don't need every pattern. Most production apps use three to five. The skill is recognising which three.

@feynman

The pattern catalog, like a kitchen knife set. You'll only reach for two or three regularly; knowing the others exist is what makes the exceptions tractable.

@card
id: llmp-ch01-c008
order: 8
title: Tradeoffs Live in Every Pattern
teaser: A pattern that fixes one problem usually introduces another — latency, cost, complexity, or coupling. The book covers the tradeoffs explicitly because the obvious choice is often wrong.

@explanation

Every pattern has a "cost of using it" that's easy to miss until you're three months in:

- **Retrieval** fixes "the model doesn't know about us" but adds an embedding index, a re-rank step, and corpus maintenance forever.
- **Verification** fixes "the model gets it wrong sometimes" but doubles the model calls and roughly doubles the cost.
- **Tools** fix "the model can't reach our systems" but expand the security surface dramatically.
- **Fine-tuning** fixes "no prompt makes it good enough" but ties you to a model version and adds a retraining cadence.

The pattern descriptions in this book lead with the tradeoff. If the tradeoff isn't worth it for your case, the pattern is a wrong fit, no matter how popular it is in someone else's blog post.

> [!warning] "It's a best practice" is not a tradeoff analysis. Best practices are usually best for the median problem; yours might not be median.

@feynman

The "no free lunch" rule, applied to architecture. Every dependency you add costs you something later — patterns are dependencies you adopt deliberately.

@card
id: llmp-ch01-c009
order: 9
title: Composition Beats Single-Pattern Magic
teaser: Real apps stack patterns. Retrieval feeds grounding; grounding feeds verification; verification feeds the user. Knowing the patterns is necessary; knowing how they compose is sufficient.

@explanation

A simple example pipeline:

1. **User question** lands.
2. **Routing** decides which retrieval index and which model to use.
3. **Retrieval** pulls relevant context.
4. **Grounding** assembles the prompt with citations and instructions.
5. **Generation** produces the draft answer.
6. **Verification** checks the draft for hallucination against the retrieved context.
7. **Style** ensures the format matches the consumer's expectations.
8. **Logging** records the trace for evals.

No single pattern in that flow does the work. Each one solves a slice; the composition solves the user's problem. Most production LLM apps look like this — a small number of well-known patterns wired together carefully.

> [!info] The composition is the architecture. Once teams converge on the patterns, the next moat is wiring them well — observability, fallbacks, cost control across the chain.

@feynman

Like Unix pipes. Each tool does one thing; the pipeline does the work. The patterns in this book are the tools — composition is what builds the application.

@card
id: llmp-ch01-c010
order: 10
title: When Not to Use a Pattern
teaser: A pattern is a hammer. Some problems aren't nails. The chapters call out when reaching for the pattern is wrong — and that section is often the most useful one.

@explanation

A few common mismatches:

- **RAG when fine-tuning is the answer** — if your domain language is too far from the model's training data, retrieval over user-data won't help; the model can't even read what it's pulling.
- **Verification when the task is unverifiable** — if there's no canonical right answer (creative writing, brainstorming), a verifier just adds latency and noise.
- **Multi-agent when one agent works** — covered in the agents book; the same caution applies. Don't decompose unless the seams are real.
- **Tool use when prompting is enough** — if the model can answer from its training (math, definitions, simple reasoning), giving it a calculator tool is overhead, not capability.

The pattern descriptions include explicit "when not to use" sections. Reading them saves more engineering time than reading the "how to use" sections.

> [!tip] When a pattern doesn't fit, the failure mode is often quiet — the system works, but worse than the simpler alternative. The signal is "we added X and quality didn't improve" — listen to it.

@feynman

Same lesson as design patterns in OO code. The Singleton wasn't created to be applied to every class. Knowing the wrong fit is half the catalog.

@card
id: llmp-ch01-c011
order: 11
title: Eval Is the Meta-Pattern
teaser: Every other pattern is bet you're making. Evaluation is how you check whether the bet paid off. Without it, you're guessing — with it, you're engineering.

@explanation

The single thread running through every pattern in this book is evaluation. You can't tell if grounding helped without an eval. You can't ship a verifier without measuring its precision. You can't pick between two retrievers without an eval that compares them on tasks you care about.

A useful eval setup is small and disciplined:

- **A small private set** — 50–200 real tasks from your production logs, anonymised, with expected outputs or quality scores.
- **A judge** — automated where possible (LLM-as-judge or programmatic), with periodic human audit.
- **A trend** — score over time. Every prompt change, model swap, or retrieval tweak runs against it.
- **A surfacing path** — when the score regresses, the team finds out within a day, not a quarter.

The patterns in the chapters that follow assume you have this. Without it, every change is a vibes-based guess.

> [!info] You don't need eval infrastructure to start. You need a spreadsheet of inputs and expected outputs, and the discipline to update it. The platform comes later.

@feynman

The metric that tells you whether your work was good. Without it, you're a chef who never tastes their own food — there's no feedback loop, and the food drifts.

@card
id: llmp-ch01-c012
order: 12
title: How to Read This Book
teaser: Linearly if you're new; non-linearly if you're not. Each chapter stands alone enough to be useful; the order is the natural progression of problems you hit as you scale.

@explanation

The chapters are ordered roughly the way problems show up:

- **Style and structured outputs** come first because they're the first thing that breaks once a demo meets real users.
- **Grounding and retrieval** come next because "the model is wrong about us" is the next big complaint.
- **Capabilities** (tools, functions) are how you stop hallucinated answers and start producing actions.
- **Reliability** patterns come once the basic system works and you need it to keep working.
- **Action** is where agents enter — the model doing things, not just saying them.
- **Constraints, safeguards, and composition** are the late-stage concerns that decide whether the app survives a year.

If you're new, read in order. If you're already shipping and one of the families is biting, skip ahead — each chapter assumes you've read the introduction but not the chapters between it and the one you're on.

> [!info] Some patterns reappear across chapters in slightly different forms. That's not redundancy — it's a hint that the underlying engineering instinct generalises, and recognising it across contexts is part of the skill.

@feynman

A reference book and a textbook in one. Read it cover to cover the first time, and as a chapter-at-a-time lookup forever after.
