@chapter
id: llmp-ch02-style-control
order: 2
title: Style Control
summary: Tone, format, vocabulary, and structure — the patterns for getting a model to produce output that fits the consumer downstream of it, not just output that's "correct."

@card
id: llmp-ch02-c001
order: 1
title: Style Is a Contract
teaser: A correct answer in the wrong style is a failure for the system that consumes it. Style isn't aesthetics — it's the interface between the model and the next step.

@explanation

Style control covers everything about a response other than the literal information: tone, vocabulary, length, format, structure, voice, reading level. Two responses can convey the same facts and still be unusable for different reasons. One is too verbose for a chat UI; the other doesn't match your brand voice; the third returns markdown instead of JSON.

The downstream consumer dictates the contract. A summary headed for a Slack message has a different style budget than one headed for a press release. A response that becomes the next step's input needs structure your parser can rely on; a response shown directly to a user needs prose a person can read.

The chapter's patterns trade off in three dimensions:

- **Strictness** — how hard the constraint is enforced.
- **Flexibility** — how much of the model's natural strength survives the constraint.
- **Cost** — how many extra tokens, calls, or runtime work the pattern adds.

> [!info] Most "the model is dumb" complaints in production are actually style mismatches. Same answer, different shape — and the shape is what failed the user.

@feynman

Same lesson as REST API contracts. The data is identical; whether the consumer can use it depends entirely on the shape it arrives in.

@card
id: llmp-ch02-c002
order: 2
title: Structured Outputs Replace Most Hand-Tuning
teaser: If your downstream needs JSON, ask for JSON via a schema, not by saying "please return JSON." Structured outputs are universally supported now and they make 80% of style problems vanish.

@explanation

Pre-2024 you'd put "respond as valid JSON, no extra text" in the system prompt and pray. The model usually obeyed and occasionally produced markdown-wrapped JSON, trailing prose, or a stray comment. Every team built the same brittle parsing layer around it.

In 2026, structured outputs are a first-class API feature on every major provider. You hand the model a JSON Schema (or Pydantic model, or Zod, or the SDK's native type); the model is constrained to produce a valid value. No prose to parse around. No "please respond in JSON" rituals.

```python
from pydantic import BaseModel
from anthropic import Anthropic

class Decision(BaseModel):
    label: Literal["spam", "ham"]
    confidence: float
    reasoning: str

response = client.messages.create(
    model="claude-haiku-4-5",
    tools=[{"name": "classify", "input_schema": Decision.model_json_schema()}],
    tool_choice={"type": "tool", "name": "classify"},
    messages=[...],
)
result = Decision.model_validate(response.content[0].input)
```

Same pattern with OpenAI's `response_format`, Gemini's `response_schema`, structured-outputs in open-weight models via grammars. The output is always parseable; the parser layer disappears.

> [!tip] Structured outputs work best when the schema is small. A 30-field schema forces the model to fabricate values for fields it doesn't have evidence for. Mark optional what's optional.

@feynman

Strong typing for a thing that used to be a stringly-typed mess. The compiler — in this case the SDK — refuses anything that doesn't match the type.

@card
id: llmp-ch02-c003
order: 3
title: Grammars and Constrained Decoding
teaser: When a schema isn't expressive enough, drop down to a grammar — a formal language that constrains the model's output token by token. Slower, fussier, but absolute.

@explanation

Schemas (JSON Schema, Pydantic) handle most cases. Some don't fit cleanly: SQL queries that must parse, regex patterns that must compile, code in a specific dialect, structured logs in a custom format. For these, constrained decoding via a grammar is the heavy artillery.

The mechanics: at each generation step, the runtime computes which tokens would produce a string that's still valid under the grammar. Tokens that would break the grammar get masked out (logits set to negative infinity); the model picks among only the legal ones.

Tools that ship grammars in 2026:

- **Open-weight inference engines** — vLLM and SGLang both support GBNF and similar grammar formats out of the box.
- **Outlines** — Python library that constrains any HF model to a regex, JSON schema, or context-free grammar.
- **llama.cpp** — has had GBNF support for a while; widely used for local inference.

Grammars have a cost: they slow generation (the runtime checks legality every token) and they can produce stilted text if the grammar is too tight. Reach for them when the consumer's parser is non-negotiable.

> [!warning] Grammars guarantee the *shape* of the output. They don't guarantee the *content* is right. A grammar-constrained SQL query parses; it might still query the wrong tables.

@feynman

The difference between asking someone to write valid Python and giving them a syntax-checking IDE that won't let them type something invalid. Both produce Python; only one rules out a category of errors entirely.

@card
id: llmp-ch02-c004
order: 4
title: Few-Shot Style Transfer
teaser: To make the model write like X, show it three examples of X. Few-shot is the cheapest way to bend voice, format, and structure together — and the result usually beats describing the style in words.

@explanation

You can describe a style ("formal, second-person, no contractions") and the model will approximate it. You can show three examples of the actual style, and the model will mimic it more accurately than your description suggested. Examples carry information that explanations leak.

The pattern:

```text
Examples of the format we want:

Q: How do I cancel my subscription?
A: I can help with that. Go to Account → Billing → Cancel. Your access continues until your billing period ends on Mar 15.

Q: I was charged twice.
A: I'm sorry about that. I see the duplicate charge from Mar 8. I've issued a refund — it'll appear in 3–5 business days.

Q: Why is the app slow?
A: <model fills in here, matching the style above>
```

Three is usually enough. More than five often hurts because it eats tokens without adding new information. Choose examples that span the range you want covered — happy path, edge case, unhappy path — not three near-duplicates.

> [!tip] Examples are also where you smuggle in subtle constraints. If every example uses bullets, the model uses bullets. If every example signs off the same way, the model signs off the same way. You don't need to mention either rule in the prompt.

@feynman

Faster than reading a style guide. You glance at three good examples and absorb the pattern; you'd skim ten pages of a "voice and tone" manual and get less.

@card
id: llmp-ch02-c005
order: 5
title: System Prompt as Voice Anchor
teaser: The system prompt is where voice and persona live. Keep it terse, opinionated, and stable — and the model carries that voice through long conversations almost without drift.

@explanation

The system prompt is the first thing the model reads on every turn. It's where you set the model's posture: who it is, who it's talking to, what tone it strikes, what topics it engages with. Done well, it's 200–500 tokens that shape every response that follows.

What works in system prompts:

- **A short identity statement** — "You are a careful, terse code-review assistant."
- **A few don'ts** — "Do not speculate about reasoning the user didn't share. Do not suggest changes outside the diff."
- **A format default** — "Default to bullet points unless the user asks for prose."
- **A worked example or two** — when explanation isn't enough.

What doesn't work:

- **Walls of rules** — by rule fifty the model is paying attention to the wrong half of them.
- **Ambiguous tone instructions** — "be friendly but professional but concise but thorough" produces averaged mush.
- **Trying to encode policy** — security and authorisation belong in code, not in the system prompt.

> [!info] Hash and version your system prompt. When something behaves differently this week than last, you want to know whether the prompt changed.

@feynman

The system prompt is the team's style guide, condensed into something the model reads on every PR. Long ones are ignored; short, opinionated ones get followed.

@card
id: llmp-ch02-c006
order: 6
title: Persona Prompts — Use With Caution
teaser: "You are a senior software engineer" sometimes helps and often doesn't. Personas are a blunt tool for a sharp problem; reach for them when the alternative is worse, not first.

@explanation

The persona prompt — telling the model it's a senior engineer, a doctor, a lawyer, a pirate — is one of the oldest tricks. It does sometimes change behaviour:

- **Vocabulary** — domain-specific terms appear more readily.
- **Posture** — confidence, hedging, assumed expertise.
- **Tone register** — formal vs casual, terse vs expansive.

It also has costs:

- **Hallucinated authority** — "as a doctor" can produce more confident wrong answers, not fewer.
- **Off-task drift** — a "pirate" assistant talks like a pirate even when the user clearly wants direct help.
- **Eval rot** — adding a persona changes responses across every test case; what improved on the eval set might have regressed on something you didn't measure.

Better than a persona, in most cases:

- **Describe the behaviour you want** — "respond with the level of detail a senior engineer would write in a code review" instead of "you are a senior engineer."
- **Use few-shot examples** — they capture the persona without the side effects.
- **Tune the structured output** — if the issue is format, fix the format directly.

> [!warning] In safety-critical domains (medical, legal, financial), persona prompts can mask uncertainty in dangerous ways. The model is not actually a doctor; pretending otherwise removes a useful guardrail.

@feynman

The "imagine you are X" trick works in some negotiations and embarrasses you in others. Same in prompting — sometimes it gets you the answer; sometimes it gets you a confidently wrong one in costume.

@card
id: llmp-ch02-c007
order: 7
title: Reading-Level and Vocabulary Control
teaser: Asking the model to "explain like I'm five" is unreliable. Setting an explicit reading-level target with examples is reliable. The difference matters when your audience is real.

@explanation

Vague reading-level instructions ("simple", "easy", "for beginners") get vague compliance. Explicit constraints land more consistently:

- **Target audience** — "Audience: developers with 0–2 years of Python experience."
- **Vocabulary boundary** — "Avoid jargon: REST, ORM, idempotent. If you need them, define inline."
- **Sentence-length cap** — "Average sentence under 20 words."
- **Reading level** — "Target: 8th-grade reading level (Flesch-Kincaid 8)."
- **Concrete grounding** — "Use a real-world analogy in every paragraph that introduces a new concept."

Combine with one or two examples that demonstrate the level. You'll get cleaner, more consistent output than from any single instruction alone.

For products that serve multiple audiences (kids, professionals, novices), the reading level becomes a parameter — different prompts per persona, same model. Don't try to encode all audiences in one prompt; the model averages.

> [!tip] If you're shipping content that'll be read in a non-native-English market, also constrain the kind of metaphors and idioms allowed. "Bases loaded" doesn't translate; "fully booked" does.

@feynman

The same skill as good technical writing for a specific audience. The bar is what your reader can absorb in a minute, not what you can express in a paragraph.

@card
id: llmp-ch02-c008
order: 8
title: Length Control
teaser: "Be concise" produces lengthy paragraphs about being concise. Length lands when you specify it numerically — words, sentences, bullets — and back it with a soft schema.

@explanation

Length is one of the easier knobs to turn — but only if you turn it explicitly. Vague instructions barely move the needle:

- "Be brief" — model writes a normal-length response with one extra "in summary" sentence.
- "One sentence" — usually obeyed; sometimes ignored when the model thinks two sentences are needed.
- "Around 50 words" — fairly accurate.
- "At most 50 words. Stop at the first complete sentence past 40." — accurate and predictable.

For structured outputs, length is a schema concern: cap array lengths, cap string fields with `maxLength`, give the parser a known upper bound. The model respects schema bounds more reliably than prose instructions.

For chat and prose, layer two signals: a soft instruction in the prompt and a `max_tokens` in the API call. The instruction shapes content; the limit prevents runaways.

> [!warning] `max_tokens` cuts the response mid-sentence when hit. If you set it tight, also instruct the model to be brief — otherwise you'll get truncation, not concision.

@feynman

Length is a budget. State the budget; the writer fits the work to it. State no budget; the writer expands to fill whatever space they imagine you want.

@card
id: llmp-ch02-c009
order: 9
title: Multi-Turn Consistency
teaser: A model that nails the voice on turn one drifts by turn five. The patterns that hold style across a conversation are different from the ones that set it on a single response.

@explanation

Long conversations stress style control because every new user turn nudges the model. The voice you set in the system prompt fights the voice the user brings. Drift accumulates: more verbose by message ten, more casual by message twenty, less aligned with your brand by message fifty.

Patterns that fight drift:

- **Re-anchor periodically** — every K turns, re-inject a short reminder of voice in the system prompt or as a meta-message.
- **Name the voice in tools** — when the model emits structured outputs, the schema shapes the voice for that step. Reset to baseline.
- **Trim the conversation** — long histories include the model's own earlier drift, which it then matches. Summarise older turns; keep the system prompt's voice canonical.
- **Penalise drift in evals** — score voice consistency across a multi-turn conversation, not just on the first response.

> [!info] On reasoning models, voice tends to drift faster because the thinking phase generates more text. Setting a voice in the thinking budget too — or excluding thinking from voice scoring — keeps evaluations clean.

@feynman

Same problem as keeping a code style consistent across a long PR. The first hundred lines look great; by line eight hundred the style has slid. The fix isn't strength; it's checkpoints.

@card
id: llmp-ch02-c010
order: 10
title: Reverse Style — Match an Unknown Voice
teaser: When the target voice is "the way our team writes" and you can't articulate the rules, give the model examples and ask it to extract the style first. Then apply.

@explanation

Sometimes the style you want isn't in your head — it's in a corpus. Internal docs your team has written. The brand's existing blog posts. The way a previous human author handled a column. The style is implicit; describing it would take longer than reading examples.

The two-step pattern:

1. **Extract** — feed the model 5–10 representative examples and ask it to describe the style explicitly: tone, length, structure, vocabulary, voice. The output is a generated style guide.
2. **Apply** — use the generated style guide as part of the system prompt for new content. Optionally include the examples too.

This decouples capturing the style from using it. You produce the style guide once; you reuse it across many generations. When the corpus shifts (new brand voice, new author), you re-run extraction.

> [!tip] The extracted style guide is also useful documentation. Read it. If it captures something nobody on the team had explicitly written down, that's a signal it's worth keeping in your knowledge base.

@feynman

The difference between training a new hire by reading them rules and by handing them ten examples and saying "match this." The second works better — and the new hire writes the rules down for the next person on the way through.

@card
id: llmp-ch02-c011
order: 11
title: Picking by Outcome, Not by Rule
teaser: You can describe the style you want or you can let the data tell you which style works. Sometimes the second answer beats anything you'd have written down.

@explanation

For some tasks the "best" style isn't a rule you know up front — it's whatever makes the user click, accept, copy, or convert. This is especially true for marketing copy, search-result headings, support replies, generated subject lines.

The pattern: generate several variants in different styles, run them past your users (live or via a judge), pick what wins. Repeat. Over time the winning style emerges from the data, often in a shape you wouldn't have predicted.

```text
Variant A (formal):       "Your subscription has been processed."
Variant B (warm):         "Thanks for joining — you're all set."
Variant C (action-first): "All set. Your access starts now."
```

The winning style ships; the losing styles inform the next round. This is structurally an A/B test, but applied to copy generated by a model rather than copy written by a human.

> [!warning] Optimising for clicks can drift toward clickbait. Add a quality floor — refusal to generate misleading or sensational variants — or you'll learn the model's worst instincts the hard way.

@feynman

Same idea as evolutionary product design. You don't always know what wins; you let users decide and propagate the winners. The designer's job becomes curation, not specification.

@card
id: llmp-ch02-c012
order: 12
title: Picking the Right Style Pattern
teaser: Schema-first when shape matters. Few-shot when voice matters. System prompt for posture. Grammar for hard guarantees. Most apps use two of these together.

@explanation

A short decision guide:

- **Output is consumed by code** → structured outputs / schemas. Don't parse prose.
- **Output is read by humans, voice matters** → system prompt + few-shot examples. Two sentences plus three examples beats a paragraph of style guidelines.
- **Output must conform to a strict format that schemas can't express (SQL, code, custom DSL)** → grammar / constrained decoding.
- **Style needs to mimic an existing corpus** → reverse style transfer (extract then apply).
- **Best style is empirical** → generate variants, A/B them, learn the winner.

Most production apps use two together. A support agent: structured outputs for the action it takes (ticket update, refund issued), few-shot prose style for the message it shows the customer. A coding assistant: grammar for the code, system-prompt voice for the explanation.

> [!info] None of these patterns are about asking the model to "try harder." They're about constraining or demonstrating in a way the model can act on. The work is in the input, not in the model.

@feynman

The carpenter's rule. Don't sand for hours when a jig would set the angle right the first time. Most "style problems" are jig problems — set the constraint properly and they stop being problems.
