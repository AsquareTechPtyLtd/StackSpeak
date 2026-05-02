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

@card
id: depc-ch11-c007
order: 7
title: Feature Store Architecture
teaser: A feature store centralizes feature computation, storage, and serving so that training and inference use the same values from the same pipeline.

@explanation

A **feature store** is a system that manages the full lifecycle of ML features: computation, storage, versioning, serving, and monitoring. It exists specifically to solve the training-serving consistency problem structurally rather than through discipline.

Two storage layers in every feature store:

**Offline store:** a warehouse or lake table that holds historical feature values for every entity at every point in time. Used for training dataset assembly and batch scoring. Optimized for throughput — millions of rows, arbitrary time windows.

**Online store:** a low-latency key-value store (Redis, DynamoDB, Cassandra, BigTable) that holds the latest feature values per entity. Used for real-time inference. Optimized for latency — sub-10ms retrieval by entity key.

The same feature pipeline writes to both. This is the guarantee that eliminates skew: one definition, two storage targets.

Feature store capabilities:
- **Point-in-time queries:** `get_historical_features(entity_df, feature_list, timestamp_col)` joins features as-of the label timestamp automatically.
- **Feature versioning:** different model versions can pin to different feature versions without pipeline changes.
- **Feature monitoring:** track distribution drift between training-time and serving-time feature values.
- **Feature sharing:** feature A computed by team X can be reused by team Y without recomputing.

Open-source options: Feast, Hopsworks. Managed: Tecton, Databricks Feature Store, Vertex AI Feature Store, SageMaker Feature Store.

> [!info] The feature store's value multiplies as the number of ML models grows. One model with a feature store is overhead. Ten models sharing features from one store is compounding leverage.

@feynman

Like a shared API layer for data — instead of each service reimplementing the same database query, they all call the same endpoint that's been validated and monitored.

@card
id: depc-ch11-c008
order: 8
title: Online Feature Serving
teaser: Real-time inference needs feature values in milliseconds — a latency requirement that batch pipelines and warehouses cannot meet.

@explanation

**Online feature serving** delivers pre-computed feature values to an inference service with sub-10ms latency. The values are computed ahead of time by the feature pipeline and stored in a low-latency store; the inference service reads by entity key.

The architecture:
1. Feature pipeline computes features (hourly, or streaming near-real-time).
2. Results are written to the online store (Redis, DynamoDB, Cassandra, Bigtable).
3. At inference time, the model service calls `feature_store.get_online_features(entity_ids)`.
4. The feature store returns the latest values for those entities.

Latency budget: a typical recommendation or fraud-detection model has a 50-100ms total response budget. Feature retrieval must fit within 5-10ms to leave room for the model forward pass.

Freshness tradeoffs:
- **Batch-populated online store:** features computed hourly and pushed. Simple, predictable, slightly stale.
- **Streaming-populated online store:** features updated within seconds of source events. Lower staleness, higher infrastructure cost.
- **Request-time computation:** features computed on each request. No staleness; often too slow for sub-10ms budgets; justified only for features that can't be pre-computed.

Redis data modeling for online features: hash per entity (`HGETALL user:1234` returns all feature values for user 1234). Pipeline batch reads for efficient multi-entity retrieval.

> [!warning] Online store freshness is easy to forget. A fraud model that retrieves 1-hour-old transaction counts for a real-time fraud decision may be making the decision with stale signals. Document and monitor online store lag.

@feynman

Like a CDN cache for data — pre-computed and distributed close to the consumer so retrieval is fast, with a pipeline refreshing the cached values on a schedule.

@card
id: depc-ch11-c009
order: 9
title: Offline Feature Computation
teaser: Training datasets need feature values over historical time ranges — a batch computation problem that's separate from serving but must use identical transformation logic.

@explanation

**Offline feature computation** generates feature values for arbitrary historical windows, used to build training datasets and run batch model scoring.

How it differs from standard data pipelines:
- Must support point-in-time joins (features as-of a label timestamp).
- Must be reproducible (same feature values for the same training run, months later).
- Must use the same transformation logic as online serving.

Execution patterns:

**Full historical recompute:** compute features for all entities over all time. Most accurate; expensive; needed when feature definitions change.

**Incremental offline computation:** compute features for new entities and time periods only; append to the offline store. Cheaper but requires careful watermarking to avoid gaps.

**Snapshot tables:** take daily snapshots of entity state. Point-in-time joins use the snapshot as-of the label date. Simple to implement; less granular than event-level history.

Training dataset assembly using Feast:
```python
training_df = feature_store.get_historical_features(
    entity_df=labels_df,       # has entity_id and label_timestamp
    features=["user_stats:total_purchases", "user_stats:days_since_last_order"],
).to_df()
```

The offline store is typically a Parquet table on S3 or a warehouse table, partitioned by date. New feature runs append to it. Point-in-time queries scan the relevant partitions.

> [!tip] Store the offline feature computation job alongside model training code in the same repository. Keeping them in sync is a team discipline problem; keeping them in the same repo makes divergence visible in PRs.

@feynman

Like building a historical record before writing a report — you gather the state of the world at each relevant moment before you analyze patterns across them.

@card
id: depc-ch11-c010
order: 10
title: Streaming Feature Pipelines
teaser: Some features must be computed from live event streams in near-real-time — session-level aggregates, recent activity counts — and batch jobs can't deliver the freshness they require.

@explanation

**Streaming feature pipelines** compute feature values from event streams (Kafka, Kinesis, Pub/Sub) using a stream processing framework (Flink, Spark Streaming, Bytewax), writing results to both the online store and the offline store.

Use cases that require streaming features:
- User session activity in the last 10 minutes (fraud detection, recommendations).
- Real-time transaction velocity (how many transactions in the last hour).
- Live inventory levels (e-commerce pricing and availability).
- Network latency spikes (infrastructure anomaly detection).

The dual-write pattern: a streaming feature job writes to:
1. The online store (Redis/DynamoDB) for real-time serving.
2. The offline store (S3/warehouse) for training data and backfill.

Windowing in streaming features:
- **Tumbling windows:** non-overlapping fixed windows (count per 5-minute bucket).
- **Sliding windows:** overlapping windows (count in the last 60 minutes, computed every minute).
- **Session windows:** windows defined by user inactivity gaps.

Flink example for a sliding window feature:
```java
stream
  .keyBy(event -> event.userId)
  .window(SlidingEventTimeWindows.of(Time.hours(1), Time.minutes(5)))
  .aggregate(new TransactionCountAggregator())
  .addSink(featureStoreSink);
```

> [!warning] Streaming features require stream processing expertise to operate. Flink cluster management, checkpointing, watermark configuration, and consumer lag monitoring are non-trivial. Evaluate batch features with acceptable staleness before committing to streaming.

@feynman

Like a live sports scoreboard — updated continuously from the event stream, not recomputed from the final boxscore.

@card
id: depc-ch11-c011
order: 11
title: Embedding Generation Strategies
teaser: Generating millions of embeddings efficiently requires batching, model selection tradeoffs, and a refresh strategy — embedding in a loop one-at-a-time is the wrong starting point.

@explanation

**Embedding generation** converts source records (documents, product descriptions, user profiles) into dense vectors using an embedding model. At production scale, the generation strategy determines cost, latency, and quality.

Model selection tradeoffs:

**API-based models** (OpenAI `text-embedding-3-large`, Cohere Embed v3, Google `text-embedding-004`): No infrastructure required; best quality for general text; billed per token; vendor dependency; round-trip latency of ~50-200ms per batch.

**Self-hosted models** (`nomic-embed-text`, `bge-large-en-v1.5`, `e5-large-v2`): Infrastructure required (GPU recommended); lower per-token cost at scale; no external API dependency; slightly lower quality than frontier models for some domains.

Batching is critical for throughput:
```python
# Wrong: 100,000 API calls
for doc in documents:
    embed(doc)

# Right: 1,000 batches of 100
for batch in chunks(documents, size=100):
    embed_batch(batch)  # one API call per batch
```

OpenAI's embedding API supports up to 2048 inputs per batch. Cohere supports up to 96 texts per call. Always use the maximum batch size.

Incremental refresh: only regenerate embeddings for changed documents. Maintain a hash of each document's content; recompute only when the hash changes. Full regeneration is required when switching embedding models — vectors from different models are not comparable.

Dimension considerations: `text-embedding-3-large` at 3072 dimensions is 4× the storage cost of 768 dimensions. Use dimensionality reduction (MRL — Matryoshka Representation Learning) if the quality difference at 1024 dimensions is acceptable.

> [!tip] Profile embedding generation cost before committing to a model. 10 million documents at 500 tokens each = 5 billion tokens. At $0.13/million tokens, that's $650 for the initial batch alone — worth knowing before you start.

@feynman

Like resizing images for different use cases — you pick the resolution that balances quality and storage cost, and you only reprocess when the source changes.

@card
id: depc-ch11-c012
order: 12
title: Vector Database Selection
teaser: Dedicated vector databases, existing databases with vector extensions, and warehouse-native vector search each fit different scale, cost, and operational profiles.

@explanation

**Choosing where to store vectors** is an architectural decision that has different answers for different scales and operational environments.

**pgvector (Postgres extension):** store vectors alongside relational data in an existing Postgres database. Supports exact and approximate nearest-neighbor search (IVFFlat, HNSW indexing). Best for: under 1 million vectors, teams already running Postgres, need to combine vector search with relational filters in a single query.

**Dedicated vector databases** (Pinecone, Qdrant, Weaviate, Chroma, Milvus): purpose-built for vector search at scale. HNSW or DiskANN indexing. Designed for hundreds of millions of vectors. Managed (Pinecone, Weaviate Cloud) or self-hosted. Best for: large-scale semantic search, production RAG, teams without existing vector-capable infrastructure.

**Data warehouse native** (BigQuery Vector Search, Snowflake Cortex Search): vector search built into the warehouse query engine. Run similarity search alongside SQL analytics in one place. Best for: teams already on that warehouse, search over structured + unstructured data combined, no new infrastructure to manage.

**Redis with vector search module:** in-memory vector store. Sub-millisecond retrieval. Best for: online feature stores, real-time recommendation where latency is critical.

Decision factors:
- **Volume:** pgvector at 10M vectors is slower than a dedicated store at the same volume.
- **Update frequency:** frequently-updated vectors favor databases with efficient upsert (Qdrant, Weaviate); Pinecone has slower write throughput.
- **Metadata filtering:** all production-grade stores support pre-filter by metadata; verify the filter performance matches your cardinality.

> [!info] As of 2026, pgvector with HNSW indexing handles 5-10M vectors competently. Beyond that, dedicated stores have a clear performance advantage.

@feynman

Like choosing a database engine — the best one depends on your query patterns, scale, and what you're already running, not on which has the most features.

@card
id: depc-ch11-c013
order: 13
title: RAG Knowledge Base Maintenance
teaser: A RAG system is only as current as its knowledge base. Stale embeddings produce wrong answers. Keeping the vector store fresh is a data engineering problem, not a model problem.

@explanation

**RAG freshness maintenance** is the operational discipline of keeping a vector knowledge base synchronized with its source documents as they change, are added, or are deleted.

The staleness problem: a customer support RAG system is built from a documentation corpus. Months later, product features change and old documentation is updated. Without a refresh pipeline, the RAG system returns answers based on superseded documentation.

Refresh strategies:

**Full regeneration:** delete all existing vectors and regenerate from scratch on a schedule (weekly, monthly). Simple; consistent; expensive at large scale; guarantees currency.

**Change-detection refresh:** monitor source documents for changes (metadata timestamp, content hash). Re-embed only changed documents; upsert to the vector store. More efficient; requires reliable change detection.

**Event-driven refresh:** source documents publish change events (CMS webhook, git commit hook, database CDC). The embedding pipeline consumes events and refreshes affected vectors in near-real-time. Lowest staleness; most operational complexity.

Deletion handling: when source documents are deleted, their vectors must be removed from the vector store. Track a mapping of `document_id → vector_id`. On source deletion, delete the corresponding vectors.

Monitoring freshness:
- Track the distribution of `source_document_last_modified` for all documents in the vector store.
- Alert when the p95 age exceeds the acceptable staleness threshold.
- Separately track documents that have been updated in the source but not yet re-embedded.

> [!warning] A RAG knowledge base without a refresh pipeline is a snapshot, not a system. It's accurate on day one and drifts silently from there.

@feynman

Like maintaining a search index — you don't build it once and walk away; you run incremental updates every time the source corpus changes.
