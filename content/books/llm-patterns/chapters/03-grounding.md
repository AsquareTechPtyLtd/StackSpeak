@chapter
id: llmp-ch03-grounding
order: 3
title: Grounding
summary: Making the model answer from sources you provide, not from training memory — and proving it did, with citations the user can verify.

@card
id: llmp-ch03-c001
order: 1
title: Why Grounding
teaser: A model trained on the public internet doesn't know your private data, and it confidently makes things up about it. Grounding is how you keep that from happening.

@explanation

A foundation model knows what was in its training set. It does not know your customer database, your internal wiki, your product's release notes, or anything that happened after the cutoff date. When a user asks about those, the model has two failure modes available:

- **Refusal** — "I don't have access to that information."
- **Hallucination** — confident-sounding fabrication.

Both are bad outcomes for a product. Refusal feels broken; hallucination is worse because users sometimes don't notice. The model invents a plausible-sounding policy, an API endpoint that doesn't exist, a feature that was deprecated. Real product damage follows.

Grounding fixes this by changing the input. Instead of asking the model "what does our refund policy say about shipping?", you retrieve the relevant policy snippets and put them in the prompt: "Here is the refund policy: [...]. Answer the question based only on this policy." The model has the source; the answer comes from the source; the user can be shown the source.

> [!info] Grounding is mechanically simple — put the source in the prompt — and operationally hard. Most of this and the next chapter is about doing it well at scale.

@feynman

Open-book exam vs closed-book exam. Closed-book, the model writes from memory and sometimes invents. Open-book, the model reads the textbook and cites the page. The mistakes change shape entirely.

@card
id: llmp-ch03-c002
order: 2
title: The Basic Pattern
teaser: Retrieve relevant context, stuff it into the prompt, instruct the model to answer only from it. Three steps. Most production systems are still arguing about how to do each one well.

@explanation

The basic shape, in pseudocode:

```python
def grounded_answer(question: str) -> Answer:
    sources = retrieve(question, top_k=5)        # find relevant context
    prompt = build_prompt(question, sources)     # assemble
    response = model.complete(prompt)            # generate
    return parse_with_citations(response, sources)
```

The prompt looks roughly like this:

```text
You are answering questions using ONLY the sources below.
If the sources do not contain the answer, say "I don't know."
Cite each claim with the source ID in [brackets].

Sources:
[1] <text from doc A>
[2] <text from doc B>
[3] <text from doc C>

Question: <user's question>
```

The whole machine works because of the constraint "answer ONLY from the sources" and the citation requirement. Without those, the model treats the sources as suggestions and falls back to its training memory when convenient.

> [!warning] Saying "use the sources" is not the same as "use ONLY the sources." Pre-2024 prompts often used the weaker phrasing and got mixed-source answers — partly grounded, partly hallucinated. Be explicit.

@feynman

The librarian who looks up the answer in the book versus the friend who guesses. Same question, very different reliability — and the difference is whether the source is actually open in front of them.

@card
id: llmp-ch03-c003
order: 3
title: Citations as Proof
teaser: An answer without a citation is an assertion. With a citation, it's a verifiable claim. Citations turn grounding from "trust me" into "check for yourself."

@explanation

The citation is the load-bearing part of grounding. Without it, you have an answer that *might* be from the source. With it, the user can click through and confirm. The product's trustworthiness rests on this.

Implementation patterns:

- **Inline source IDs** — `[1]`, `[2]` in the model's output, mapping to the retrieved sources.
- **Structured output with claim → source mapping** — each claim is a JSON object that names the supporting source.
- **Provider-native citations** — Anthropic and a few others ship a citations API where the response carries source spans natively, with no parsing.

The citations should map to *spans*, not just whole documents. "According to the Refund Policy" is weaker than "According to section 3.2 of the Refund Policy, paragraph 2." Users who care will check; spans make checking fast.

```python
class GroundedAnswer(BaseModel):
    answer: str
    claims: list[Claim]

class Claim(BaseModel):
    text: str
    source_id: str
    source_span: tuple[int, int]
```

> [!tip] Render citations as clickable links in the UI that scroll the user to the exact span in the source. The friction of "find this in a 30-page doc" is what stops users from verifying.

@feynman

Footnotes in academic papers. The citation isn't decoration — it's how the author proves the claim. Same shape, applied to the model's output.

@card
id: llmp-ch03-c004
order: 4
title: Refusing to Answer
teaser: The model that says "I don't know" when the sources don't cover the question is the model users learn to trust. Refusal is a feature, not a bug.

@explanation

A grounded system has to handle the case where the sources don't contain the answer. The model has three options:

- **Answer correctly from the sources** — the happy path.
- **Hallucinate** — fall back to training memory; bad outcome.
- **Refuse / hedge** — "I don't see that information in the sources I have access to."

The third option is what makes a product reliable. Users learn to trust it because the absence of a confident wrong answer is the absence of a category of failure. The first time a model says "I don't know" honestly is the moment a user stops second-guessing the times it does answer.

You make refusal happen in the prompt:

```text
If the sources below do not contain enough information to answer the question, respond with "I don't have that information in the sources I have access to" and stop. Do not use general knowledge to fill gaps.
```

> [!warning] Refusal can be over-tuned. A model that refuses everything ambiguous is annoying. Calibrate by examining refusals on your eval set — too many means the prompt or the retrieval is off.

@feynman

The expert who says "I'd need to look that up" is more trustworthy than the one who answers everything. Same instinct applies to a grounded model — measured uncertainty is signal.

@card
id: llmp-ch03-c005
order: 5
title: Source Quality Matters More Than Model Quality
teaser: A frontier model with bad sources answers worse than a small model with good sources. If your retrieval pulls noise, no amount of model intelligence saves you.

@explanation

Teams obsess over which model to use and underspend on the retrieval side. The numbers usually disagree with that allocation. A grounded system's quality ceiling is set by:

1. **Whether the right source exists in the corpus** — if it doesn't, no retriever can find it.
2. **Whether the retriever finds it** — if it doesn't, the model can't use it.
3. **Whether the model uses it correctly** — the smallest of the three on most production workloads.

The model contribution is real but bounded. Once retrieval surfaces the right snippet, even a mid-tier model usually produces a correct answer. When retrieval misses or surfaces noise, even a frontier model produces something wrong — and produces it confidently.

> [!info] Eval the retriever separately from the generator. Recall@k on a labelled dataset measures the retriever; quality of grounded answers measures both. The former is easier to fix and has higher leverage.

@feynman

The interpreter who reads the wrong document fluently still gives you wrong answers. Fluency wasn't the bottleneck.

@card
id: llmp-ch03-c006
order: 6
title: Open-Book vs Closed-Book Tasks
teaser: Some tasks need grounding; others don't. The skill is recognising which is which — the wrong choice burns money and quality on each side.

@explanation

Not every task should be grounded. Reaching for retrieval reflexively can make answers worse, slower, and more expensive.

Tasks that genuinely need grounding:

- **Private data** — your customer's account, your team's docs, your product's specs.
- **Recent information** — anything past the model's training cutoff.
- **Cited claims** — answers where the source is part of the answer (legal, medical, compliance).
- **High-precision factual** — the kind where being 95% right is worse than not answering.

Tasks where grounding hurts:

- **General knowledge the model already has** — math, definitions, well-known facts. Retrieval introduces irrelevant context that distracts.
- **Creative work** — writing, brainstorming, exploration. The point is generation, not lookup.
- **Reasoning over the question itself** — "what's a good name for our new feature?" doesn't have a source.

Mixed-mode tasks (some retrieval-needed, some not) require a routing step: classify the question, retrieve only if needed, generate accordingly.

> [!tip] If retrieval can't return relevant sources for the user's question, your prompt should tell the model that — "no sources matched" — rather than handing it irrelevant snippets that it'll feel obligated to use.

@feynman

You don't open a textbook to remember your own phone number. The textbook is the right tool for some questions and the wrong tool for others — picking matters.

@card
id: llmp-ch03-c007
order: 7
title: Combining Grounded and General Answers
teaser: Most real questions blend "what do the sources say" with "what general knowledge applies." The pattern is to ground tightly on the parts that need it and let the model reason on the rest.

@explanation

A pure grounded system is rigid. A pure ungrounded one hallucinates. Most production systems blend, with explicit instructions about which parts of the answer should be grounded and which can use general knowledge.

```text
Answer the question using:
- The sources below for facts about our product, policies, or customer data.
- Your general knowledge for technical concepts, programming, and explanations of standard practices.

Always cite sources for product- or policy-specific claims.
Do not cite sources for general knowledge.

Sources:
[1] <product doc>
[2] <policy snippet>

Question: How do I integrate our SDK with React, and what's our SLA for the auth endpoint?
```

The first half of the answer ("how do I integrate the SDK") is general; the model uses its training. The second half ("our SLA") is specific; the model cites the source. The user gets both, with the appropriate grounding on each.

> [!info] Schemas help here. Structure the response into "explanation" (general) and "policy" (grounded) fields. Each gets the right treatment, and downstream rendering can mark them differently.

@feynman

The doctor who explains how blood pressure works in general (general knowledge) and what your specific reading means (grounded in your chart). Both correct; differently sourced.

@card
id: llmp-ch03-c008
order: 8
title: Verifying the Output Against the Sources
teaser: Generation can drift from sources even with strong grounding instructions. A second pass that checks each claim against the sources catches it.

@explanation

You can ground the model and still get hallucinations. The model is trained to be helpful, and helpfulness includes filling gaps. When the source is ambiguous, the model sometimes resolves ambiguity by inventing a clarification.

The verification step catches this. After generation, you check: does each claim in the answer actually appear in the cited source?

```python
def verify(answer: GroundedAnswer, sources: list[Source]) -> list[Issue]:
    issues = []
    for claim in answer.claims:
        source_text = sources[claim.source_id].text
        # Quick check — substring or paraphrase match.
        if not supported(claim.text, source_text):
            issues.append(Issue(claim=claim, reason="not in source"))
    return issues
```

`supported()` can be a lightweight string match (fast, brittle) or an LLM-as-judge call (slower, more flexible). For production, the judge version is usually worth the cost on the high-stakes tasks; substring matches catch the easy violations.

When verification fails, the runtime can either flag the issue to the user, regenerate with the failure as feedback, or refuse the answer outright.

> [!tip] On critical claims (medical dosages, legal advice, financial figures), refuse rather than hedge when verification fails. A wrong number with a hedge is still a wrong number that someone might act on.

@feynman

Code review for prose. The reviewer doesn't trust that the comment in the PR matches the code; they read both. Verification does the same for grounded outputs.

@card
id: llmp-ch03-c009
order: 9
title: When Sources Disagree
teaser: Two sources contradict. The model can't make a fact be true; it can only be transparent about the disagreement. Surface the conflict to the user.

@explanation

Real corpora contain contradictions: an old policy and a new policy, two engineers' write-ups, an FAQ that wasn't updated when the product changed. A grounded system that picks one source and ignores the other is hiding information from the user.

The pattern is to expose the conflict in the response:

```json
{
  "answer": "There is conflicting information across sources.",
  "claims": [
    {"text": "Refunds within 30 days", "source_id": "policy-v1"},
    {"text": "Refunds within 14 days", "source_id": "policy-v2"}
  ],
  "note": "policy-v2 is more recent (2026-04). Defer to it unless told otherwise."
}
```

Two responsibilities for the agent runtime:

- **Detect the conflict** — comparing claims across sources during generation; flagging when they contradict.
- **Help the user resolve it** — surface dates, source authority, the difference in plain language.

> [!info] Source ranking by recency, authority, or curation status helps the model resolve conflicts without escalating every one to the user. But always preserve the option to surface — a wrong default is worse than a visible disagreement.

@feynman

A senior engineer who finds two PRs proposing opposite changes doesn't quietly merge one. They raise the conflict. Same shape, applied to source disagreements.

@card
id: llmp-ch03-c010
order: 10
title: The Trust UX
teaser: Grounding only delivers trust when the user can see the work. Show sources, show citations, show what was retrieved — and design the UI so verification is one click away.

@explanation

A grounded answer that hides its sources is functionally the same as an ungrounded one for the user. The trust comes from visibility:

- **Show retrieved sources** — even before the answer is generated, surface what was retrieved. Users get a feel for whether the system found relevant material.
- **Show inline citations** — every claim links to its source span.
- **Show "no sources found"** — when retrieval misses, say so. Don't paper over it with a generated answer.
- **Show conflicts** — when sources disagree, surface that the user is now in a judgement call.
- **Show what was excluded** — if you applied filters (date range, document type), say so. Users can adjust.

These move work from the model to the UI, but it's the right place. The UI is where trust gets built or broken.

> [!warning] An app that gives correct grounded answers without showing sources will feel less trustworthy than an app with worse answers but visible work. Trust is perception; sources are the evidence layer.

@feynman

Same lesson as showing the price breakdown on a receipt. The total might be the same; the itemised version is the one customers don't suspect.

@card
id: llmp-ch03-c011
order: 11
title: Extraction vs Generation
teaser: Sometimes you want the model to *return* facts from a document, not write a response *about* the document. That's extraction, and it's strictly better when it fits.

@explanation

Generation: "Write a paragraph about what these sources say." The model produces prose, citing sources, possibly verifying.

Extraction: "Pull these specific fields out of these documents." The model returns a structured object — JSON, key-value pairs — that maps directly to fields the document contains.

When extraction fits the use case, prefer it:

```python
class ContractFields(BaseModel):
    contract_value: float
    start_date: date
    parties: list[str]
    termination_clause: str | None

# Constrained: model returns ContractFields or fails.
fields = client.messages.create(
    tools=[{"name": "extract", "input_schema": ContractFields.model_json_schema()}],
    tool_choice={"type": "tool", "name": "extract"},
    messages=[{"role": "user", "content": contract_text}],
)
```

Why extraction wins where it applies:

- **No prose to generate** — fewer hallucination opportunities.
- **Schema-validated** — the output is type-safe at the boundary.
- **Reusable** — the same structured fields feed downstream systems without re-parsing.
- **Citable structurally** — each field's source span can be a property of the field.

The split: extraction for "what does the doc say"; generation for "explain what the doc means."

> [!tip] You can pipeline both. Extract structured facts first, generate a prose answer that uses the extracted facts as input. The prose part has fewer chances to drift because the facts are already nailed down.

@feynman

Filling out a form versus writing an essay about the form. Both useful; the form is faster and harder to get wrong.

@card
id: llmp-ch03-c012
order: 12
title: When Grounding Isn't Enough
teaser: Grounding fixes "the model doesn't know our data." It doesn't fix bad data, missing data, or questions retrieval can't surface. Recognise its limits before you blame the model.

@explanation

Common cases where grounding meets a wall:

- **The corpus doesn't contain the answer** — the user asked something nobody documented. No retriever can find what isn't there. The right response is "no source covers this."
- **The retrieval missed** — the answer exists in the corpus but the retriever didn't surface it. The next chapter (Retrieval) is mostly about closing this gap.
- **The corpus is wrong** — the documents say something incorrect (out-of-date policy, contradicted spec). Grounding makes the model echo the wrong info confidently.
- **The question requires synthesis across many sources** — basic grounding chunks the corpus and retrieves top-K. If the answer needs reading 50 documents and reasoning across them, the basic pattern doesn't fit; the next chapter's "deep search" patterns do.
- **The user wants a judgement, not a fact** — "should we adopt this policy?" isn't groundable. The corpus has facts; opinions are something else.

Recognising these saves arguing with the model when the model is doing what was asked. The fix lives upstream — better corpus, better retrieval, better question framing — not in tweaking the prompt.

> [!info] If users keep asking the same question and the model keeps refusing, that's a signal: write the answer down and put it in the corpus. Document gaps surface as recurring refusals.

@feynman

The librarian can only hand you books that exist. Grounding has the same constraint. When a question keeps getting "I don't have a source," the answer is to write the source — not to badger the librarian.
