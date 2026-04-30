@chapter
id: llmp-ch04-retrieval
order: 4
title: Retrieval
summary: How to actually find the right context to ground on — embeddings, hybrid search, re-ranking, chunking, and the retrieval patterns that work past the toy demo.

@card
id: llmp-ch04-c001
order: 1
title: Retrieval Is Search With Different Tradeoffs
teaser: Vector search isn't magic; it's keyword search's cousin with different failure modes. Most production retrieval combines both — and adds a re-ranker on top.

@explanation

The 2023 wave of "use a vector database" advice papered over a question old search engineers had been answering for decades: how do you find the right document for a query? Embeddings shifted the geometry but didn't replace the discipline.

Two flavours of search, with different strengths:

- **Keyword (BM25, TF-IDF)** — matches literal terms. Strong on rare names, exact phrases, technical jargon. Misses paraphrase.
- **Semantic (vector embeddings)** — matches meaning. Strong on paraphrase, synonyms, conceptual queries. Misses exact-match anchors when meaning drifts.

Production retrieval is mostly the union: run both, merge results, re-rank with a model. The hybrid approach beats either alone on almost every benchmark and almost every real workload.

> [!info] Search relevance has been studied for decades. The new tooling didn't invalidate the old lessons. Borrow from search before reinventing them.

@feynman

The library has a card catalog (keywords) and a librarian who knows what books are about (semantics). Walking past one to use the other is theatre; walking up to both is how you actually find the book.

@card
id: llmp-ch04-c002
order: 2
title: Embeddings — What They Are, Briefly
teaser: An embedding is a vector that places similar text near similar text. The model maps your query and your corpus into the same space, and you find the nearest neighbours.

@explanation

A text embedding model takes a string and outputs a fixed-size vector — typically 768 to 3072 dimensions. The vectors are arranged so that semantically similar strings land near each other. The geometry is the whole game.

The pipeline:

1. **Embed your corpus** — every document (or chunk) gets a vector. Stored alongside the text.
2. **Embed the query** — same model, runtime call.
3. **Find nearest neighbours** — usually cosine similarity, top-K.
4. **Return the matching chunks** — text plus metadata.

Key choices:

- **Embedding model** — Voyage v3, OpenAI `text-embedding-3-large`, Cohere v4, BGE / Nomic open-weight. Performance varies meaningfully by domain; benchmark on yours.
- **Vector store** — Pinecone, Qdrant, Weaviate, pgvector, Turbopuffer. Most are competent; pick on ops and integration, not raw speed.
- **Distance metric** — cosine for normalised vectors (the default), dot product when scale matters.

> [!warning] Re-embed when you change models. Vectors from different models live in different spaces; mixing them produces nonsense neighbours.

@feynman

A library where books are arranged so similar ones sit next to each other. Walk to the section you care about; the relevant ones are within arm's reach. The embedding model decides what "similar" means.

@card
id: llmp-ch04-c003
order: 3
title: Hybrid Search
teaser: Keyword + semantic, with a fusion step. Both lists ranked; merge them; pass the top to a re-ranker. The two-line upgrade that makes most basic-RAG systems noticeably better.

@explanation

Hybrid retrieval runs a keyword query and a semantic query, then combines the results. The combination strategies that work:

- **Reciprocal Rank Fusion (RRF)** — each result's score is `1 / (k + rank_in_list)` summed across both lists. Tunable, robust, almost embarrassingly simple. The default for most production systems.
- **Score normalisation + weighted sum** — more flexible but requires per-system tuning.
- **Cascade** — keyword first, semantic to fill gaps when keyword recall is low.

```python
def hybrid_search(query: str, k: int = 20) -> list[Hit]:
    bm25_hits = bm25_index.search(query, k=k)
    vector_hits = vector_index.search(embed(query), k=k)
    return rrf_merge(bm25_hits, vector_hits, k=k)
```

The win is on queries where one method has a blind spot. "What does our docs say about ICMP?" — keyword nails it because "ICMP" is rare; semantic alone might pull packet-related docs that don't mention the term. "What's the difference between supervised and unsupervised learning?" — semantic shines; keyword pulls noise.

> [!tip] Open-weight options like Qdrant and Weaviate ship hybrid out of the box. pgvector + Postgres full-text is a perfectly fine hybrid setup if you already have Postgres.

@feynman

Two specialists looking at the same problem and pooling their answers. Each catches what the other misses; the combined list outperforms either alone.

@card
id: llmp-ch04-c004
order: 4
title: Re-Ranking
teaser: Top-K from search is a coarse pass. A re-ranker reads the query and each candidate together and produces a sharper score. Cheap to add, large quality jump.

@explanation

A retriever returns the top 50 chunks based on rough similarity. Most of them are vaguely relevant; only 5 actually answer the query. A re-ranker reads the query and each candidate together and outputs a precise relevance score. Pass only the top-K from the re-ranker to the generator.

```python
candidates = hybrid_search(query, k=50)
reranked = rerank_model.score(query, [c.text for c in candidates])
top_k = sorted(candidates, key=lambda c: -reranked[c.id])[:5]
```

Two re-ranker types in 2026:

- **Cross-encoder rerankers** — Cohere Rerank v3, BGE rerankers, Voyage rerank-2. Read query + candidate together. Slow per call, but parallelisable across candidates.
- **LLM-as-judge** — prompt a small model to score relevance. More flexible (you can ask for "scored on whether it answers the user's specific question"), more expensive, often better quality.

Re-ranking is the highest-ROI improvement most basic-RAG systems can make. Recall@50 is usually high; precision@5 is where systems fall down.

> [!info] Re-rank only what you'll show. If the model needs the top 5 chunks, retrieve 50 and rerank to 5 — not retrieve 5 and rerank 5. The wider the candidate pool, the more the reranker has to work with.

@feynman

The hiring funnel. The recruiter brings 50 résumés; the hiring manager re-reads the top 10 carefully. The recruiter's job is recall; the manager's job is precision. Both matter.

@card
id: llmp-ch04-c005
order: 5
title: Chunking — More Than Splitting Text
teaser: How you cut your documents determines what retrieval can find. Bad chunking puts the answer in one chunk and the question's keywords in another — and recall craters.

@explanation

Chunking is the silent disaster in basic RAG. Default text splitters (1000 chars, 200 overlap) work fine on prose and fail on structured documents — code, tables, formatted manuals, anything where structure carries meaning.

Strategies that produce better retrieval:

- **Semantic chunking** — split at natural boundaries (paragraphs, sections, list items) rather than character counts. Embedding-based splitters detect topic shifts.
- **Hierarchical chunks** — index small chunks for retrieval precision, but include a parent context (the surrounding paragraph or section) when feeding the model.
- **Structure-aware** — code by function or class; tables by row with the header included; markdown by heading.
- **Overlap with intent** — overlap to preserve context across boundaries, not as a generic safety margin.

The chunk you index is not always the chunk you generate from. A common pattern:

```text
1. Index small chunks (200–500 tokens) for tight semantic matching.
2. On retrieval, expand each hit to its parent (the section it belongs to).
3. Pass parents to the generator — full context, but found via the precise hit.
```

> [!warning] Re-chunking the corpus is expensive. Pick a chunking strategy you can live with for months; changing it means rebuilding the entire index.

@feynman

The size of the index card you write matters. A card too small misses the surrounding context; a card too big buries the relevant detail. Different documents want different sizes.

@card
id: llmp-ch04-c006
order: 6
title: Query Rewriting and HyDE
teaser: The user's question and the document's wording often don't match. Rewriting the query — or generating a hypothetical answer to embed instead — closes the gap.

@explanation

Users ask "how do I cancel my plan?" Documents say "Subscription Termination Policy". Embedding similarity is decent, but not great. Two patterns close the gap:

**Query rewriting**: an LLM rewrites the user's question into 2–4 alternate phrasings. Each is embedded; results are merged.

```text
User: "how do I cancel my plan?"
Rewrites:
  - "subscription cancellation"
  - "terminating an account"
  - "ending recurring billing"
```

**HyDE (Hypothetical Document Embeddings)**: generate a hypothetical answer to the question (the model invents what a good answer would look like), then embed *that* and use it as the query. The hypothetical answer often reads more like the actual document than the question does.

```text
User: "how do I cancel my plan?"
Hypothetical: "To cancel your subscription, navigate to Account → Billing →
              Cancel Subscription. Your access continues until..."
Embed the hypothetical, search with that vector.
```

Both add an LLM call before retrieval. Both improve recall on queries where vocabulary mismatch is the bottleneck. HyDE works particularly well on technical or specialised corpora.

> [!info] Query rewriting and HyDE compose. Generate two rewrites and one HyDE response, embed all three, search for each, merge with RRF. The recall floor rises noticeably.

@feynman

The bilingual translator. The user speaks one dialect; the document speaks another. Someone has to translate before search can match — these patterns are the translator.

@card
id: llmp-ch04-c007
order: 7
title: Filters and Metadata
teaser: Pure vector search treats the corpus as one undifferentiated cloud. Real corpora have dates, authors, document types, access permissions. Filter first; rank in the filtered set.

@explanation

Almost every production corpus has metadata that should constrain retrieval before similarity is computed:

- **Time** — only docs from after some date.
- **Authority** — official docs vs. drafts; current policy vs. archived.
- **Type** — FAQs vs. tickets vs. release notes.
- **Permission** — what this user is allowed to see.
- **Topic / tag** — domain or category.

Filtering at the index level is much faster than filtering after retrieval. Vector stores all support metadata filters; design the schema upfront so common filters are indexed.

```python
results = index.search(
    query_vector,
    filter={
        "and": [
            {"published_after": "2025-01-01"},
            {"doc_type": ["faq", "policy"]},
            {"access_level": {"$lte": user.access_level}},
        ],
    },
    k=10,
)
```

The access-control filter especially matters. A retrieval that returns documents the user shouldn't see has leaked information through the side door, and the model will helpfully include it in the answer.

> [!warning] Don't rely on the prompt to enforce permissions. "Don't show docs the user can't see" in the system prompt is a wish; metadata filtering at retrieval is enforcement.

@feynman

The same instinct as a SQL `WHERE` clause before a `JOIN`. Restrict the search space first; rank what's left. Order matters — both for speed and for safety.

@card
id: llmp-ch04-c008
order: 8
title: Multi-Step (Agentic) Retrieval
teaser: One retrieval, one answer is fine for simple questions. Hard questions need iteration: retrieve, read, refine the query, retrieve again. The "deep research" pattern in two lines.

@explanation

A single retrieval works when the answer fits in one chunk. Many real questions don't:

- "What's our refund policy for international orders shipped to the EU under our enterprise plan?"
- "What changed between v2 and v4 in the auth flow, and which of those changes is in the current release?"
- "Compare our SLA terms across the last three contract templates."

Single-shot retrieval misses these because no chunk contains the full answer. Multi-step retrieval breaks them into sub-queries, retrieves for each, and synthesises:

```text
Plan:
  1. Retrieve refund policy for international orders.
  2. Retrieve EU-specific overlays.
  3. Retrieve enterprise-plan terms.
  4. Synthesise an answer that respects all three.
```

The model drives the loop: read what came back, decide what to retrieve next, repeat until the answer is complete or the budget is exhausted. This is structurally an agent (the previous book covers the loop mechanics).

> [!info] Anthropic's deep-research pattern, OpenAI's "Deep Research" mode, and a wave of open-source equivalents all use this shape. They burn 10–100× the tokens of a single retrieval and produce dramatically better answers on hard questions.

@feynman

Same lesson as breaking down a hard ticket. You don't open one Stack Overflow tab for a complicated bug; you open six, in series, each one informed by what you read in the last.

@card
id: llmp-ch04-c009
order: 9
title: GraphRAG and Structured Knowledge
teaser: When the corpus has explicit relationships — entities, references, citations — turn it into a graph and walk it. Especially useful for "what's connected to X" questions.

@explanation

Pure vector retrieval treats every chunk as independent. Some corpora carry rich relationships: code (function calls function), legal docs (clauses reference clauses), product specs (features depend on features), Wikipedia-style content (articles link to articles). When relationships matter, a graph beats a vector store.

GraphRAG (popularised by Microsoft Research and now broadly available) builds a knowledge graph from the corpus:

1. Extract entities and relationships during indexing — "Feature A depends on Service B", "Policy v2 supersedes Policy v1".
2. Store as a graph, alongside the vector index.
3. At retrieval, walk the graph from the entity in the query — pull connected nodes, not just similar text.

The shape of question this helps with:

- "What features depend on the auth service?"
- "Which contracts reference clause 4.2?"
- "What's downstream of this code change?"

> [!warning] Graph extraction is hard. Entity extraction at corpus scale needs an LLM, costs real money, and is not perfect. Reach for graph approaches when the corpus structurally needs them — don't impose graph thinking on prose.

@feynman

The difference between searching a library by title and following the citation chain. Both useful; for "what was influenced by this paper," the citation chain is irreplaceable.

@card
id: llmp-ch04-c010
order: 10
title: Index Freshness
teaser: A static index ages. Documents change, products evolve, policies update. The index that's a month behind is silently surfacing wrong answers.

@explanation

Most teams build the index once and forget it. The corpus moves on. Six months later, retrieval is pulling deprecated content and the model is confidently citing it.

The freshness mechanisms that actually work:

- **Webhook on write** — when a doc is updated in the source-of-truth system (Notion, Confluence, GitHub), a webhook triggers re-embedding of just that doc.
- **Periodic full re-index** — a scheduled job (nightly, weekly) walks the corpus, re-embeds anything that's changed since last run.
- **Time-decay scoring** — newer documents get a relevance boost; old ones can still be retrieved but rank lower by default.
- **Soft delete with redirect** — when a doc is replaced, keep the old entry indexed but flag it as superseded; retrieval can choose to skip it or surface the redirect.

For high-stakes retrieval (legal, medical, compliance), the answer should include the document version and date. Stale answers are sometimes worse than no answer.

> [!info] Track "time since last index" as a metric. When it grows past your tolerance, the answers start drifting. The user complaint that follows is downstream of an index that wasn't kept fresh.

@feynman

Same hygiene as keeping documentation in sync with code. The drift is silent until someone notices something's wrong; by then it's been wrong for a while.

@card
id: llmp-ch04-c011
order: 11
title: Evaluating Retrieval Independently
teaser: Bad answers can come from bad retrieval or bad generation. If you don't measure them separately, you'll spend a month tweaking the wrong layer.

@explanation

Most teams eval the end-to-end pipeline: question in, answer out, judge scores it. The score is a blend of retrieval quality and generation quality, and you can't tell which moved when the score changes.

Split the eval:

- **Retrieval eval** — for each labelled query, did the retriever return the right documents in the top-K? Measure recall@k, MRR (mean reciprocal rank), nDCG. Run this independently of the generator.
- **Generation eval** — given the *right* sources (manually picked), does the generator produce a correct, well-grounded answer? Run with curated context, not retrieved context.
- **End-to-end eval** — the actual production path. Score blends both.

Now when end-to-end drops, you can ask "did retrieval drop?" and "did generation drop?" — separately. Almost always one is the culprit; you fix that layer.

```text
End-to-end score down  →  retrieval recall down  →  query-rewriter regressed
End-to-end score down  →  generation precision down  →  prompt template changed
```

> [!tip] Build the labelled retrieval set incrementally. Each time a user reports a bad answer, label the right docs for that query. Over months you accumulate a real evaluation set tuned to your corpus.

@feynman

Same as separating frontend bugs from backend bugs. "The button is broken" could be either; debugging starts with figuring out which.

@card
id: llmp-ch04-c012
order: 12
title: When Not to Use a Vector Database
teaser: Sometimes a SQL `LIKE`, a full-text index, or even a single hard-coded string of context beats the whole RAG stack. Pick the smallest tool that solves your problem.

@explanation

Reaching for a vector database is the new "let's add Kubernetes." Sometimes correct; often overkill. The cases where a simpler tool wins:

- **Tiny corpus (< 10K chunks)** — a SQL full-text index or even an in-memory Python list with sklearn cosine similarity is fast, simple, and free of operational overhead.
- **Highly structured queries** — if the query is "find tickets matching customer ID = X with severity ≥ 2", that's SQL, not retrieval.
- **Single document, fits in context** — if the corpus is "this 50-page PDF," put the whole thing in the prompt with caching turned on. The retrieval step is friction.
- **Strong keyword anchor** — exact-match queries on rare terms (product SKUs, error codes) are better served by a keyword index than vectors.
- **Real-time / freshness-critical** — vector index updates lag; for "latest news in the last hour," a streaming search engine fits better.

The reflex to reach for a vector DB has cost teams real money in storage, ops, and complexity for cases where simpler tools were already in their stack.

> [!info] Start with the simplest retrieval that could possibly work. Move up the stack only when you can articulate the failure of the current layer. "RAG" is not a default architecture; it's a technique with preconditions.

@feynman

The "use SQLite first" instinct. Most apps that built distributed systems on day one regretted it; the same pattern applies to retrieval. Match the tool to the actual problem.
