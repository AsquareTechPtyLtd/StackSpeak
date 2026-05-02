@chapter
id: depc-ch11-ml-ai-integration-patterns
order: 11
title: ML and AI Integration Patterns
summary: Feature pipelines, point-in-time correctness, training/serving consistency, vector pipelines, embedding generation, and RAG-supporting transforms — the patterns data engineers own when ML goes to production.

@card
id: depc-ch11-c001
order: 1
title: The Data Engineer's Role in ML Systems
teaser: ML systems need data in forms that differ from analytics — time-correct joins, reproducible training sets, low-latency serving features. These are data engineering problems, not model problems.

@explanation

Machine learning models depend on data pipelines just as dashboards do, but the requirements differ in important ways:

- **Point-in-time correctness:** a model trained on "what we knew at the time" must join features to the state of the world at prediction time, not today's state. Using current values for historical training data produces feature leakage.
- **Training/serving consistency:** the feature transformations applied to training data must be identical to those applied at inference time. Drift between the two produces models that perform well in training and poorly in production.
- **Throughput vs latency duality:** training pipelines move large volumes efficiently; serving pipelines must retrieve features for a single entity in milliseconds.
- **Reproducibility:** a training run from six months ago must be exactly reproducible. This requires point-in-time snapshots, not a "latest" view.

Data engineers who understand these requirements can build pipelines that serve ML teams correctly. Data engineers who don't ship feature pipelines that produce leakage or inconsistency — and the model team discovers the problem months later.

> [!info] LLM-era data engineering (2026) adds vector pipelines and RAG-supporting transforms to these classical ML requirements. The foundational patterns apply; the output shapes and destinations are new.

@feynman

Like the difference between a snapshot for a report vs a snapshot for a transaction — the use case determines what "correct" means.

@card
id: depc-ch11-c002
order: 2
title: Feature Pipelines
teaser: A feature pipeline computes and serves input signals for ML models — with the added constraint that the same feature logic must run identically during training and serving.

@explanation

A **feature pipeline** produces the inputs (features) that a model consumes. It differs from a standard transformation pipeline in that:

1. Features must be computable **at prediction time** (low latency, single-entity lookup).
2. The same feature logic must run **at training time** (batch, arbitrary historical window).
3. Feature values must be **point-in-time correct** — computed as of the event's timestamp, not today.

Feature pipeline architecture:

**Batch feature computation:** run a Spark or dbt job to compute features for all entities as of a given date. Write results to a feature store or warehouse. Used for training and for offline model evaluation.

**Online feature serving:** pre-compute feature values on a schedule and write to a low-latency store (Redis, DynamoDB, Feast online store). At inference time, fetch the latest feature values by entity key in under 10ms.

**Streaming features:** compute feature values from streaming events (last-N-clicks, session-level aggregates) using Flink or Spark Streaming. Write to both the online store (for serving) and the offline store (for training).

Feature store tools: Feast (open source), Tecton, Vertex AI Feature Store, SageMaker Feature Store, Databricks Feature Store.

Without a feature store, training features are computed in a Jupyter notebook and serving features are computed in application code — drift between the two is almost guaranteed.

> [!tip] Define feature transformations in shared Python functions, not inline notebook code. The same function is called by both the training pipeline and the serving pipeline, eliminating transformation drift.

@feynman

Like a shared library that both the test suite and the production service import — the logic is guaranteed identical because it's the same code.

@card
id: depc-ch11-c003
order: 3
title: Point-in-Time Correctness
teaser: When building a training dataset, join features as of the label timestamp — not the current timestamp. Using today's feature values for historical predictions is the most common form of feature leakage.

@explanation

**Point-in-time correctness** (also called temporal consistency) means every feature in a training row reflects the state of the world at the time the label was generated — not the state of the world when the training data was assembled.

The leakage scenario: you're training a churn model. The label is "did this customer churn in month 3?" The features include "customer's current tier." If the customer upgraded their tier in month 2 (after churning), the training data shows the post-churn tier against the churn label — a data leak. The model learns a correlation that won't exist at inference time.

How to implement point-in-time joins:

```sql
-- Point-in-time correct join: get the customer's tier as of the observation date
SELECT t.customer_id, t.observation_date, c.tier
FROM training_events t
JOIN (
  SELECT customer_id, tier, valid_from, valid_to
  FROM customer_history
) c
  ON t.customer_id = c.customer_id
  AND t.observation_date BETWEEN c.valid_from AND c.valid_to
```

This requires SCD Type 2 history in the feature tables — exactly why SCD Type 2 exists.

Feature stores automate point-in-time joins as a first-class operation. Tecton and Feast support `get_historical_features(entity_df, feature_list, timestamp_col)` natively.

> [!warning] A model that achieves unusually high training accuracy but disappoints in production is a strong signal of feature leakage. Audit the training features for point-in-time correctness before investigating the model architecture.

@feynman

Like a detective who must only use clues available before the crime, not after — any future information contaminating the training set is a leak.

@card
id: depc-ch11-c004
order: 4
title: Training-Serving Skew
teaser: When training features are computed differently from serving features, the model trains on data it will never see in production. The result is a model that evaluates well and deploys badly.

@explanation

**Training-serving skew** occurs when the feature transformations applied during training differ from those applied at inference time. It's one of the most common causes of production ML underperformance.

Common causes of skew:

- **Different code paths:** training uses a pandas transform in a notebook; serving uses a SQL query in an API. The logic is "the same" but implementation differences produce different values.
- **Missing value handling:** training imputes nulls with the mean; serving returns 0 for missing values. The model never saw 0 in training.
- **Normalization scale mismatch:** training normalizes a feature using statistics from the training set; serving uses hardcoded constants from months ago. New data ranges are outside the training distribution.
- **Timezone differences:** training computes "day of week" in UTC; serving computes it in the user's local timezone.
- **Different table versions:** training reads from a warehouse snapshot; serving reads from a database that has since been updated.

Prevention:
- Define feature transformations in a single function callable from both training and serving pipelines.
- Validate serving features against training feature distributions during deployment.
- Log serving features; compare the distribution to the training distribution weekly.
- Use a feature store where training and serving use the same registered feature computation.

> [!tip] Log the actual feature values used at inference time. Comparing the distribution of live features against training features is the most reliable detection mechanism for skew that slips through during deployment.

@feynman

Like a recipe where the training version uses butter and the production version uses margarine — similar in theory, different in practice, and the taste test exposes the difference.

@card
id: depc-ch11-c005
order: 5
title: Vector Pipeline Patterns
teaser: LLM-era systems need vector embeddings stored in vector databases — a new pipeline shape that sits alongside traditional analytical data pipelines.

@explanation

**Vector pipelines** generate, store, and maintain vector embeddings — dense numerical representations of text, images, or other data — for use in semantic search, retrieval-augmented generation (RAG), and recommendation systems.

The pipeline stages:

**Generation:** a source document (product description, customer support ticket, knowledge base article) is passed to an embedding model (OpenAI `text-embedding-3-large`, Cohere Embed v3, Google Vertex Embedding API, or a locally-hosted model like `nomic-embed-text`). The model returns a dense vector, typically 768-3072 dimensions.

**Storage:** vectors are written to a vector database or vector-capable store. Options: Pinecone, Weaviate, Qdrant, pgvector (Postgres extension), Chroma, Milvus, Snowflake Cortex Search, BigQuery Vector Search.

**Refresh:** when source documents change, the embeddings must be regenerated. A change-detection pipeline monitors the source, identifies changed records, re-embeds, and upserts to the vector store.

**Metadata:** vectors alone are not useful for filtering. Store structured metadata alongside vectors (document ID, source system, date, tags) to enable pre- and post-filtering.

Operational considerations:
- Embedding generation is compute-intensive. Batch in groups of 100-1000 documents; don't embed one at a time.
- Embedding model changes are breaking. If you switch from one model to another, all vectors must be regenerated — they're not interchangeable.
- Dimension cardinality matters for storage cost. A 3072-dimension embedding is 4× larger than a 768-dimension one.

> [!info] As of 2026, vector search is becoming a standard capability in existing data stores (Postgres with pgvector, Snowflake Cortex) rather than requiring a separate vector database. Evaluate whether an existing store suffices before adding infrastructure.

@feynman

Like a full-text search index, but for semantic similarity instead of keyword matching — the pipeline generates the index; queries use it to find conceptually similar records.

@card
id: depc-ch11-c006
order: 6
title: RAG-Supporting Transforms
teaser: Retrieval-Augmented Generation systems need well-chunked, freshness-maintained, metadata-rich document stores. Preparing that store is a data engineering problem.

@explanation

**RAG (Retrieval-Augmented Generation)** systems combine a language model with a retrieval step: given a user's question, retrieve the most relevant documents from a knowledge base, then pass them to the LLM as context.

The quality of a RAG system depends heavily on the quality of the knowledge base, which is a data pipeline problem.

Chunking strategy:
- Documents must be split into chunks that are the right size for the context window and semantically coherent. A chunk that cuts a sentence in half produces poor retrieval quality.
- Fixed-size chunks (512 tokens) are simple but lose semantic boundaries.
- Semantic chunking splits on natural boundaries (paragraphs, sections, topic shifts). Better quality; harder to implement.
- Hierarchical chunks: store both small chunks (for precise retrieval) and parent chunks (for context around the retrieved section). The retriever returns small chunks; the LLM receives the parent chunk.

Metadata enrichment:
- Add structured metadata to each chunk: source document, section heading, date last modified, document type.
- Metadata enables filtered retrieval: "search only in documentation published after 2025."

Freshness maintenance:
- Source documents change. A RAG system querying outdated embeddings produces hallucinations or incorrect answers.
- Implement a change-detection pipeline that monitors source documents, re-embeds changed ones, and upserts to the vector store.

> [!tip] The fastest path to improving RAG quality is usually improving chunking and metadata, not switching LLMs. A well-structured knowledge base outperforms a better model on a poorly-structured one.

@feynman

Like a well-indexed library — the retrieval quality depends more on how the catalog is organized than on how fast the librarian reads.
