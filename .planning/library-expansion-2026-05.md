# Library Expansion — May 2026

**Date:** 2026-05-02
**Status:** **Decisions locked.** Ready to begin Phase 1 authoring.
**Scope:** 11 books from screenshots, spanning data engineering, visualization, communication, project management, and soft-skills

---

## Locked Decisions (2026-05-02)

✅ **Recommendations approved.** Phasing as proposed below.
✅ **Freshness constraint added.** Where source content is outdated, augment with current 2026 tools, frameworks, and best practices. The card content is original prose informed by the source's structure — not a literal rewording — so we're free to bring it up to date.

### Source-staleness flags

Source books vary in how much updating is needed. Marked here so the author has it in mind chapter-by-chapter:

| Book | Source year | Staleness | Update areas |
|------|-------------|-----------|--------------|
| Data Engineering Pattern Catalog | 2025 | Low | Confirm lakehouse-era patterns; add AI/LLM integration patterns |
| DuckDB in Action | 2024 | **Medium** | DuckDB 1.0+ released since publication; cover MotherDuck, modern Iceberg integration |
| Effective Data Visualization (Wilke) | 2019 | **High** | ggplot2 examples date well; add Observable Plot, Vega-Lite, web-native visualization |
| Communication Patterns (Read) | 2024 | Low | Add AI-augmented communication patterns, modern docs-as-code tooling |
| Communicating with Data (Knaflic) | 2019 | **Medium** | Principles evergreen; add modern dashboard patterns, real-time viz, mobile-first |
| Critical Thinking *(Shortcut)* | 2023 | Low | Touch on AI-era critical thinking |
| EI *(Shortcut)* | 2023 | Low | Touch on remote/async communication realities |

**Update philosophy** — keep the source's structural framing where it still serves; replace specific tool examples and practices with what a 2026 practitioner would actually reach for.

---

---

## Current Library State

After "Engineering Data Systems" landed, the library holds 4 books:

| Book | Chapters | Cards | Theme |
|------|----------|-------|-------|
| AI Agents (Definitive Guide) | 7 | 85 | LLMs / agents |
| LLM Patterns | 10 | 120 | LLMs / patterns |
| Software Architecture | 16 | 160 | Architecture |
| Engineering Data Systems | 13 | 153 | Data engineering |

**Total: 46 chapters, 518 cards.** Centered on backend + AI + data engineering for developers.

---

## Source Inventory — 11 Candidate Books

### Group A — Data Engineering / Data Specialty (3 books)
Strong fit. Builds on the data-engineering foundation we just shipped.

1. **Data Engineering Design Patterns** — Bartosz Konieczny (O'Reilly)
   *Pattern catalog for solving recurring data engineering problems.*
2. **Data Engineering for Beginners** — Chisom Nwokwu (Wiley)
   *Hands-on roadmap for aspiring data engineers — fundamentals.*
3. **DuckDB in Action** — Mark Needham, Michael Hunger, et al. (Manning)
   *Embedded analytical SQL database — practical usage.*

### Group B — Data Visualization (2 books)
Good fit. Visualization is adjacent to data engineering and analytics-engineering work.

4. **Fundamentals of Data Visualization** — Claus O. Wilke (O'Reilly)
   *Principles for making informative and compelling figures.*
5. **Storytelling with Data: Let's Practice!** — Cole Nussbaumer Knaflic (Wiley)
   *Practice-driven companion to communicating with data.*

### Group C — Cloud Platform Specialty (1 book)
Niche fit. Microsoft Fabric is one cloud's data platform — narrower audience than the others.

6. **The Definitive Guide to Microsoft Fabric** — Christopher Maneu, Emilie Beau, Jean-Pierre Riehl + 2 more (Packt)
   *Microsoft Fabric end-to-end — discovery to production architectures.*

### Group D — Communication & Writing (1 book)
Strong fit. Communication is universal for developers, fills a gap in current library.

7. **Communication Patterns** — Jacqui Read (O'Reilly)
   *Patterns for technical communication, aimed at developers and architects.*

### Group E — Project Management (2 books)
Stretchy fit. PM is adjacent to engineering but the standard PMBOK audience is broader. Worth discussing whether to include.

8. **A Guide to the Project Management Body of Knowledge (PMBOK Guide) — Eighth Edition** — Project Management Institute
   *The PMI standard for project management — foundational reference.*
9. **Head First PMP** — Jennifer Greene, Andrew Stellman (O'Reilly)
   *PMP exam prep / project management primer in the Head First style.*

### Group F — Soft Skills Shortcuts (2 books)
Mixed fit. The Shortcut format is shorter than full books. May want to treat as a distinct content type or combine.

10. **Improve Your Critical Thinking Skills** — Charles Humble (InfoQ Shortcut)
    *Short selection on critical thinking for engineers.*
11. **Improve Your Emotional Intelligence to Communicate Better** — Curtis Newbold (InfoQ Shortcut)
    *Short selection on EI for technical communication.*

---

## Audience-Fit Analysis

The current library is developer-centered (backend, AI/ML, data, architecture). Mapping the new candidates against that:

| Book | Audience Fit | Rationale |
|------|--------------|-----------|
| Data Engineering Design Patterns | **High** | Direct sequel to Engineering Data Systems |
| Data Engineering for Beginners | **Medium** | Overlaps with Engineering Data Systems intro chapters |
| DuckDB in Action | **High** | DuckDB is rising rapidly; tool-specific but evergreen |
| Fundamentals of Data Visualization | **High** | Visualization is a gap; principles-based, evergreen |
| Storytelling with Data | **Medium-High** | More business-leaning than the Wilke book |
| Microsoft Fabric | **Low-Medium** | Vendor-specific; narrower audience |
| Communication Patterns | **High** | Cross-cutting skill; gap in library |
| PMBOK Guide | **Medium** | Standard reference; less developer-specific |
| Head First PMP | **Medium** | Exam-focused; useful but narrow |
| Critical Thinking (Shortcut) | **Medium-High** | Universal soft skill |
| EI Shortcut | **Medium-High** | Universal soft skill |

---

## Proposed Title Renames

Following the convention from "Engineering Data Systems" — keep the meaning, change the wording. Original title in italics for reference.

| # | Original | **Proposed Rename** |
|---|----------|---------------------|
| 1 | *Data Engineering Design Patterns* | **The Data Engineering Pattern Catalog** |
| 2 | *Data Engineering for Beginners* | **Starting in Data Engineering** |
| 3 | *DuckDB in Action* | **Working with DuckDB** |
| 4 | *Fundamentals of Data Visualization* | **Effective Data Visualization** |
| 5 | *Storytelling with Data: Let's Practice!* | **Communicating with Data** |
| 6 | *The Definitive Guide to Microsoft Fabric* | **Building on Microsoft Fabric** |
| 7 | *Communication Patterns* | **Communication Patterns for Engineers** |
| 8 | *PMBOK Guide (8th Ed)* | **The Project Management Standard** |
| 9 | *Head First PMP* | **Project Management Foundations** |
| 10 | *Improve Your Critical Thinking Skills* | **Critical Thinking for Engineers** |
| 11 | *Improve Your EI to Communicate Better* | **Emotional Intelligence at Work** |

User can override any of these.

---

## Outstanding Decisions Before Authoring

These need answers before any cards get written.

### D1 — Scope: which books to include?

The **strong-fit cluster** (1, 3, 4, 7) plus **medium-fit** (2, 5, 10, 11) feels like a natural Phase 1 of 8 books.

The **stretchy ones** (6 Microsoft Fabric, 8 PMBOK, 9 Head First PMP) raise questions:
- **Microsoft Fabric** — is StackSpeak's audience meaningfully on Fabric? If <20% of users care, probably skip.
- **PMBOK + Head First PMP** — overlapping content. Pick one, not both. PMBOK is the source-of-truth reference; Head First is the friendlier intro. **Recommend: pick Head First, skip PMBOK** (unless cert-focused users are a target).

### D2 — Shortcut format

The two InfoQ Shortcuts (~30-50 pages each in source) are smaller than full books. Two paths:

- **Option A** — Treat each as a small standalone book (~3-5 chapters, ~30-50 cards each)
- **Option B** — Combine into one "Soft Skills for Engineers" book covering both topics + perhaps add more topics later
- **Option C** — Skip them; soft skills don't fit the technical book pattern

**Recommend: Option A** — keep them separate since they have distinct authors and topics. Mark them with a `category: shortcut` field if we want to badge them differently in UI.

### D3 — Chapter density per book

Existing books range 7-16 chapters / 85-160 cards each. For the new ones:

- **Full-scope books** (1, 3, 4, 7, 8/9) — match existing density (~10-15 chapters, ~120-160 cards)
- **Beginner-focused books** (2) — lighter scope (~6-8 chapters, ~60-80 cards) since content overlaps with Engineering Data Systems
- **Practice-focused** (5) — skill-driven; smaller (~6-8 chapters, ~60-80 cards)
- **Shortcuts** (10, 11) — short (~3-5 chapters, ~30-50 cards each)
- **Microsoft Fabric** (6) — depends; if included, full scope

### D4 — Order of authoring

Two strategies:

- **Breadth-first** — one chapter from each book first, then the rest. Lets you spot-check style across diverse topics quickly.
- **Depth-first** — finish one book before starting the next. Cleaner mental context per book; faster to first ship.

**Recommend: depth-first**, in priority order (D1 results dictate the order).

### D5 — Author byline / attribution

The current books don't show original authors in the catalog (the `author` field is null on existing entries). For the rephrased books we're authoring, that's appropriate. Worth confirming the policy:

- **Confirm: don't list original authors.** The cards are original prose inspired by the source's structure.
- **Possibly: add `inspiredBy` field** to credit the source publicly. Optional.

### D6 — Cover icons + accent colors

Each book needs a cover icon (SF Symbol) and accent hex. Proposed first pass — user can override:

| Book | Icon | Accent |
|------|------|--------|
| Data Engineering Pattern Catalog | `square.grid.3x3.fill` | `#2A8C8B` (teal) |
| Starting in Data Engineering | `arrow.right.to.line` | `#3B7A57` (forest) |
| Working with DuckDB | `bird` | `#FFC107` (amber) |
| Effective Data Visualization | `chart.bar.fill` | `#C84A50` (red) |
| Communicating with Data | `chart.line.uptrend.xyaxis` | `#1E40AF` (deep blue) |
| Building on Microsoft Fabric | `cube.transparent` | `#0078D4` (MS blue) |
| Communication Patterns for Engineers | `bubble.left.and.bubble.right` | `#7B61FF` (purple) |
| Project Management Foundations | `checklist` | `#5C6BC0` (indigo) |
| Critical Thinking for Engineers | `brain` | `#E91E63` (pink) |
| Emotional Intelligence at Work | `heart.text.square` | `#FF6B35` (coral) |

---

## Recommended Phasing

Based on audience fit + "depth-first" recommendation:

### Phase 1 — Strong fit (do first)
1. **The Data Engineering Pattern Catalog** — sequel to Engineering Data Systems; high reuse of recently-authored vocabulary
2. **Working with DuckDB** — popular, evergreen, tool-specific but transferable
3. **Effective Data Visualization** — fills visualization gap; foundational
4. **Communication Patterns for Engineers** — fills soft-skills/communication gap; cross-cutting

### Phase 2 — Medium fit (next)
5. **Communicating with Data** — visualization → communication bridge
6. **Critical Thinking for Engineers** *(shortcut)* — short, fast to author
7. **Emotional Intelligence at Work** *(shortcut)* — short, fast to author

### Phase 3 — Optional / deferred (decide later)
8. **Starting in Data Engineering** — only if value beyond Engineering Data Systems is clear
9. **Project Management Foundations** *(Head First PMP)* — only if PM-curious developers are a target audience
10. **Building on Microsoft Fabric** — only if Microsoft-cloud users are a meaningful slice
11. **The Project Management Standard** *(PMBOK)* — recommend skipping; Head First covers same ground accessibly

---

## Effort Estimate

Based on the Engineering Data Systems benchmark (13 chapters, 153 cards, ~64K words of prose):

| Book | Est. Chapters | Est. Cards | Est. Words |
|------|---------------|------------|------------|
| Data Engineering Pattern Catalog | 12-15 | ~140-170 | ~55-65K |
| Working with DuckDB | 10-12 | ~110-140 | ~45-55K |
| Effective Data Visualization | 10-12 | ~120-150 | ~45-55K |
| Communication Patterns | 10-12 | ~110-140 | ~40-50K |
| Communicating with Data | 6-8 | ~60-80 | ~25-30K |
| Critical Thinking *(shortcut)* | 4-5 | ~30-40 | ~12-15K |
| EI *(shortcut)* | 4-5 | ~30-40 | ~12-15K |
| Starting in Data Engineering | 6-8 | ~60-80 | ~25-30K |
| Project Management Foundations | 12-15 | ~130-160 | ~50-60K |
| Microsoft Fabric | 12-15 | ~130-160 | ~50-60K |

**Phase 1 total** (4 books): ~480-600 cards, ~185-225K words.
**All 11 books**: ~1,030-1,260 cards, ~400-485K words.

For reference, autonomous authoring of Engineering Data Systems (153 cards) took roughly one extended session. Phase 1 would be 3-4 such sessions.

---

## Authoring Workflow (Per Book)

### Context management rule (locked)
Write **one chapter per agent context**. Never accumulate multiple chapters in a single context window. A full book (~13 chapters × 12 cards × 250 words) is ~40K words — enough to cause measurable quality degradation in later chapters if written in one pass.

**Why this matters:** context rot produces shallower cards, merged concepts, and weaker Feynman analogies in later chapters. The first 3 chapters look great; chapters 10–13 look like survey content. Per-chapter contexts eliminate this entirely.

### Execution model
For each chapter: spawn a fresh agent → write the chapter file → save to disk → agent done. No agent writes more than one chapter. Chapters can be parallelised (up to the number of chapters in the book) or written sequentially — either is fine as long as each chapter gets its own context.

### Per-book flow

1. **Confirm structure with user** — title rename, chapter spine, density target
2. **Author chapters in parallel or sequence, one agent per chapter** — each agent receives: book prefix, chapter number/title, the required content items for that chapter, and the DSL rules. Agent writes one chapter file and exits.
3. **Quality-check first and last chapters** — compare card density and concept separation. If last chapters are weaker, rewrite with fresh agents.
4. **Build → sync → verify** — `node scripts/build-books.js`, `./scripts/sync-books.sh`, `xcodebuild`
5. **Commit per book** — single commit per finished book; clean history

### Per-chapter agent prompt must include
- Book prefix and chapter ID/order
- Chapter title and summary
- The specific content items this chapter must cover (subset of the book's coverage list)
- DSL format rules (inline, not by reference — agents don't share context)
- One-concept-per-card rule and 10–15 card density target
- A path to one reference chapter file to read for tone
- Instruction to write exactly one file and report card count when done

---

## Risks & Open Questions

- **Source recency** — some books (e.g. Microsoft Fabric, PMBOK 8th Ed) have rapidly-evolving subject matter; cards may go stale faster than evergreen ones.
- **Audience drift** — adding PM and PMBOK content shifts the library away from "developer reference" toward "general professional development." Worth a deliberate decision.
- **Volume cost** — at ~$X per author session × N books, the cumulative cost is non-trivial. Worth phasing rather than committing to all 11 up front.
- **Library navigation** — at 4 books today, a flat list is fine. At 10-15, will users want category filtering (data, AI, soft skills, PM)? Possible follow-up.

---

## Tone & Style Guide (Locked — Apply To Every Book)

Established by Engineering Data Systems and treated as the contract for all subsequent books.

### Voice
- **Editorial-minimalist.** Confident, direct, technical. No marketing cheer. No emojis (unless explicitly demanded by a card's content).
- **Second person.** "You" + "the team" + "your pipeline." Not "we." Not "the reader."
- **Concrete over abstract.** Name specific tools, specific failure modes, specific numbers ("5-10× compression," "single-digit ms latency"). Vague generalities make weak cards.
- **Honest about tradeoffs.** Every recommendation surfaces what it costs. No silver bullets.
- **No preaching.** Avoid "you should" / "you must." Prefer "the team that does X tends to..." or "the failure mode is..."

### Card structure (DSL)

```
@card
id: <book-prefix>-ch<NN>-c<NNN>
order: N
title: Title Case But Punchy (no full sentences)
teaser: A single hook sentence. Promises what the card pays off.

@explanation

The body. 150-300 words. Mix prose and bullet lists.
- Lists when enumerating peers (formats, tools, options).
- Prose when explaining a concept or trade-off.

> [!info] / [!tip] / [!warning] One-liner callouts at most one per card.

Code blocks where they actually clarify. Languages used: sql, python, go, ts/tsx, rust, swift, kotlin, bash, yaml, dockerfile, http, gherkin, css, json. Skip language for ASCII diagrams (use `text`).

@feynman

A single-sentence analogy bridging the concept to a familiar dev/eng experience. Punchy. Closes the card.
```

### Field rules per card
- **id** — `<book-prefix>-ch<NN>-c<NNN>` (3-digit card number for room to grow). Book prefixes locked below.
- **order** — sequential within chapter, starting at 1.
- **title** — Title Case, ~3-7 words, no terminal punctuation.
- **teaser** — one sentence, ~15-30 words, no period at end is fine.
- **explanation** — 150-300 words. Single chapter has 8-15 cards (typical) or more.
- **callouts** — `info` (general note) · `tip` (actionable) · `warning` (failure mode). Max one per card.
- **codeExample placement** — inside `@explanation`, never in @feynman.
- **feynman** — exactly one sentence; punchy; analogizes to a familiar concept.

### One concept per card (non-negotiable)
Each card covers **exactly one concept**. If a card explains two things, it must be split into two cards. This is the single most important rule for card quality — merged concepts produce shallow coverage of both.

Signals a card needs splitting:
- The title uses "and" or "/" to name two concepts.
- The explanation spends a paragraph on sub-topic A, then pivots to sub-topic B.
- The Feynman analogy doesn't quite fit because the card is really about two different things.
- A reader could reasonably ask "but what about X?" after reading — and X was already in the card, buried.

**Target density:** 10–15 cards per chapter for full books. 8–12 for Phase 2 medium books. 6–10 for shortcuts (InfoQ format).
A chapter that lands under 8 cards is a signal that concepts have been merged rather than individually covered.

### Content quality bar
- Every card pays off its teaser.
- Every card surfaces tradeoffs, not just capabilities.
- Every card includes either a concrete example, a specific tool name, or a specific number — at least one.
- Cards that read as generic survey content get rewritten.
- Avoid "in 2026" or year-specific tags except where calling out very recent shifts.

### Cross-book consistency
- Same callout vocabulary (info / tip / warning).
- Same DSL structure across all books.
- Same approximate density (10-15 cards per chapter for full books; 6-10 for shortcuts).
- Same opening pattern: chapter 1, card 1 establishes the foundational definition.
- Same closing pattern: final chapter recaps + points forward.

### Book prefix registry
- Engineering Data Systems → `eds-`
- Data Engineering Pattern Catalog → `depc-`
- Working with DuckDB → `wdd-`
- Effective Data Visualization → `edv-`
- Communication Patterns for Engineers → `cpe-`
- Communicating with Data → `cwd-`
- Critical Thinking for Engineers → `cte-`
- Emotional Intelligence at Work → `eiw-`
- Starting in Data Engineering → `side-`
- Project Management Foundations → `pmf-`
- Building on Microsoft Fabric → `bmf-`
- AWS Essentials → `aws-`
- Azure Essentials → `azr-`
- 100 Things Every Programmer Should Know → `ttp-`
- 100 Things Every Data Engineer Should Know → `tde-`

---

## Per-Book Content Coverage (Locked)

For each Phase 1 + Phase 2 book, the topic areas authoring MUST cover. Treats the planning doc as the contract — nothing in this list gets quietly dropped during writing.

### Book 1 — The Data Engineering Pattern Catalog (`depc-`)

Source: *Data Engineering Design Patterns* (Konieczny). Pattern-catalog format — each chapter covers one family of recurring problems and the patterns that solve them.

**Required content coverage:**

- **Pattern thinking for data systems** — what makes a "pattern" vs a one-off; when patterns help and when they hurt.
- **Ingestion patterns** — batch refresh, CDC, log shipping, event sourcing, push-based webhooks, polling cursors, snapshot+stream hybrid.
- **Storage layout patterns** — bronze/silver/gold layering, slowly-changing-dimension storage, partitioning strategies, file-size optimization, hot/warm/cold tiering.
- **Transformation patterns** — staging-then-mart, idempotent writes, late-arriving data handling, deduplication, replay-friendly transforms.
- **Modeling patterns** — Kimball star, Data Vault, wide tables, one-big-table, anchor modeling, time-series modeling.
- **Quality and validation patterns** — schema-on-write contracts, expectation testing, quarantine zones, circuit breakers, anomaly detection.
- **Orchestration patterns** — DAG decomposition, dynamic task generation, sub-DAGs vs task groups, sensors vs schedulers, idempotency-first design.
- **Observability patterns** — lineage emission, metrics-first pipelines, freshness SLAs, data-quality dashboards, on-call ergonomics.
- **Cost-control patterns** — query result caching, materialized vs virtual, partition pruning, tier downgrade automation, FinOps tagging.
- **Security & governance patterns** — column masking, row-level security, audit-log tee-off, classification propagation, deletion cascades.
- **ML/AI integration patterns** — feature pipelines, point-in-time correctness, training/serving consistency, vector pipeline patterns *(2026 update)*, embedding generation, RAG-supporting transforms *(2026 update)*.
- **Anti-patterns** — small-files explosion, monolithic transforms, untested SQL, manual backfills, schema drift handling-by-null.
- **Pattern selection guide** — when to compose, when to skip, when patterns become anti-patterns at scale.

**2026 freshness updates:** add LLM/AI integration patterns; modern lakehouse patterns (Iceberg-native); semantic-layer patterns; cost-aware patterns reflecting real cloud bills.

### Book 2 — Working with DuckDB (`wdd-`)

Source: *DuckDB in Action*. Practical guide to the embedded analytical SQL database.

**Required content coverage:**

- **What DuckDB is and isn't** — embedded vs server, OLAP-only positioning, when to reach for it.
- **Installation and basic usage** — CLI, Python bindings, JS/WASM, JVM, R, Go bindings *(2026 ecosystem)*.
- **SQL dialect** — what's standard, what's DuckDB-specific (FROM-first SELECT, GROUP BY ALL, friendly type coercion).
- **File format support** — Parquet, CSV, JSON, Iceberg *(2026 update)*, Delta *(2026 update)*, Excel.
- **Querying remote data** — HTTPFS, S3/GCS/Azure direct, predicate pushdown to remote storage.
- **Performance characteristics** — vectorized execution, columnar processing, memory-vs-disk tradeoffs.
- **DuckDB extensions** — official + community extensions, when to use each.
- **Joins and aggregations at scale** — DuckDB's strengths for analytical workloads.
- **Persistence** — in-memory vs file-backed databases, attaching multiple databases.
- **Working with massive files** — streaming reads, larger-than-memory queries.
- **DuckDB in pipelines** — as a transform layer, as a local-first analytics engine, as a CI testing layer.
- **DuckDB and pandas/Polars** — interop, when each wins.
- **Vectorized UDFs** — Python and SQL functions.
- **MotherDuck and managed DuckDB** *(2026 update)* — cloud-native DuckDB, hybrid execution.
- **DuckDB 1.0+ stability commitments** *(2026 update)* — what changed, what's locked.
- **Comparison to alternatives** — vs SQLite (analytical), vs Pandas, vs Polars, vs Spark, vs warehouses.
- **Production use cases** — embedded analytics, lake-format query engine, ML feature engineering, edge analytics.
- **Common gotchas** — concurrency limits, cross-platform file handling, memory configuration.

**2026 freshness updates:** DuckDB 1.0/1.1 features; MotherDuck and DuckLake; Iceberg/Delta integration; Polars interop maturity.

### Book 3 — Effective Data Visualization (`edv-`)

Source: *Fundamentals of Data Visualization* (Wilke, 2019). Principles of clear charting; ggplot2-heavy in source.

**Required content coverage:**

- **Why visualization matters** — speed of comprehension, discovery vs communication.
- **Mapping data to aesthetics** — position, color, size, shape, transparency.
- **Color use** — sequential, diverging, qualitative palettes; colorblind-safe; semantic color.
- **Visualizing amounts** — bars, lollipops, dot plots; ordering matters.
- **Visualizing distributions** — histograms, density plots, violin plots, box plots, ridgeline plots.
- **Visualizing proportions** — pie charts (when ok), stacked bars, treemaps, parallel sets.
- **Visualizing many distributions** — small multiples, faceted plots.
- **Visualizing two variables (x-y)** — scatterplots, line charts, smoothed lines.
- **Visualizing many variables** — pairs plots, correlation matrices, parallel coordinates.
- **Visualizing geographic data** — choropleths, cartograms, point maps.
- **Visualizing uncertainty** — error bars, confidence bands, quantile dot plots.
- **Working with overlapping data** — jittering, transparency, 2D density.
- **Trend visualization** — time series done well, smoothing without misleading.
- **Annotation and labeling** — direct labels, callouts, titles that interpret.
- **Visual hierarchy and clutter removal** — what to remove, the data-ink ratio.
- **Misleading visualizations** — truncated axes, area illusions, dual y-axes, 3D distortion.
- **Modern web visualization** *(2026 update)* — Observable Plot, Vega-Lite, deck.gl, D3 v7, Plotly, Apache ECharts.
- **Notebook-native visualization** *(2026 update)* — Marimo, Hex, Observable; reactive viz.
- **AI-generated chart critique** *(2026 update)* — LLMs for chart review and accessibility checks.
- **Accessibility** — alt text, screen-reader-friendly, color contrast for chart elements.
- **Chart selection guide** — picking the right chart for your question.
- **Tooling landscape** — when to reach for ggplot2, matplotlib, Vega-Lite, Tableau, BI tools.

**2026 freshness updates:** modern web/notebook tooling; reactive notebooks; AI-assisted chart selection and critique; mobile-first dashboards.

### Book 4 — Communication Patterns for Engineers (`cpe-`)

Source: *Communication Patterns* (Read). Cross-cutting communication skills for developers and architects.

**Required content coverage:**

- **Why communication is engineering work** — code is half; communication is the other.
- **Knowing your audience** — who's reading, what context they bring, what they need to walk away with.
- **Visual communication patterns** — diagrams that earn their place; UML in moderation; C4 model.
- **C4 model in depth** — system context, container, component, code-level diagrams.
- **Modeling notation** — when to use UML, when to use sketches, when to use BPMN, when to invent your own.
- **Writing patterns** — doc-as-code, ADRs (architecture decision records), RFCs, design docs.
- **The pyramid principle** for technical writing — answer first, support second, detail third.
- **Async communication patterns** — Slack vs email vs meeting vs doc; default to async; when to escalate to sync.
- **Meeting patterns** — what meetings are for, what they're not for; running meetings well; killing meetings.
- **Cross-team communication** — translating between teams; shared vocabulary; bridge documents.
- **Documentation maintenance** — docs that stay current; docs as part of the definition of done; docs reviewed in PRs.
- **Diagrams that don't rot** — diagrams-as-code (Mermaid, PlantUML, Excalidraw, structurizr).
- **Stakeholder communication** — engineers vs PMs vs execs; tailoring depth and framing.
- **Bad-news communication** — incident comms, RCA writing, project-status escalation.
- **Storytelling structures** — situation/complication/question/answer; problem/solution/tradeoff.
- **Pull-request communication patterns** — PR descriptions that get merged; responding to review.
- **Whiteboarding patterns** — interview/design-review whiteboarding effectively.
- **Remote/distributed communication** *(2026 update)* — async-first conventions, time-zone respectful patterns.
- **AI-augmented communication** *(2026 update)* — LLMs for drafting, reviewing, summarizing; their limits; the editor's role.
- **Common anti-patterns** — wall-of-text PRs, meeting-driven development, stale docs, jargon overload.

**2026 freshness updates:** AI-augmented drafting/review patterns; modern docs-as-code tooling; distributed-team realities.

### Book 5 (Phase 2) — Communicating with Data (`cwd-`)

Source: *Storytelling with Data: Let's Practice!* (Knaflic, 2019). Practice-driven applied visualization.

**Required content coverage:**

- **Story before chart** — what question are you answering, for whom.
- **Stripping the chart** — removing clutter; the bar chart most people should default to.
- **Color as a tool, not decoration** — drawing attention; using gray as background.
- **Annotation as the message** — the title that says what the chart shows.
- **Chart sequencing in a presentation** — building up complexity, walking the audience through.
- **Live presentation vs sent doc** — different communication shapes need different chart styles.
- **Dashboard patterns** — what dashboards are for, what they're not.
- **Real-time dashboard patterns** *(2026 update)* — live ops dashboards, when freshness matters.
- **Mobile-first chart design** *(2026 update)* — small screens, touch interaction.
- **Common pitfalls** — pie-chart abuse, dual axes, 3D effects, misleading scales, decorative chart junk.
- **Critique workshop** — applying the lens to existing charts.
- **Building habits** — practicing well, getting feedback, iterating.

### Book 6 (Phase 2) — Critical Thinking for Engineers (`cte-`)

Source: InfoQ Shortcut. Short — 4-5 chapters, 30-40 cards.

**Required content coverage:**

- **What critical thinking means in tech** — not negativity, not contrarianism; structured reasoning.
- **Cognitive biases that bite engineers** — confirmation bias, anchoring, sunk cost, availability, recency.
- **Asking better questions** — Socratic questioning patterns for design and code review.
- **Distinguishing facts, assumptions, and opinions** — in tech debates, in postmortems, in planning.
- **Evaluating claims** — vendor pitches, blog posts, benchmarks, "best practices."
- **Reasoning from first principles** — when to use, when it's overkill.
- **Critical thinking in code review** — beyond style; questioning structure and assumptions.
- **Critical thinking in incident response** — staying analytical under pressure.
- **AI-era critical thinking** *(2026 update)* — evaluating LLM output, recognizing hallucination, knowing when to defer.
- **Practicing the skill** — deliberate practice; team norms.

### Book 7 (Phase 2) — Emotional Intelligence at Work (`eiw-`)

Source: InfoQ Shortcut. Short — 4-5 chapters, 30-40 cards.

**Required content coverage:**

- **Why EI is engineering work** — not soft, load-bearing.
- **Self-awareness** — recognizing your own state; the bias toward action when reflection is needed.
- **Self-regulation** — responding rather than reacting; the slack channel reply you don't send.
- **Empathy in technical settings** — understanding upstream/downstream perspectives; the user's actual problem.
- **Reading the room** — meeting dynamics, async tone, recognizing distress at distance.
- **Giving feedback** — the SBI model; specific, behavioral, impact-focused.
- **Receiving feedback** — separating message from messenger; using even bad delivery.
- **Difficult conversations** — disagreement, performance, conflict resolution.
- **Building trust** — small consistent acts; the foundation of cross-team work.
- **Async/remote EI** *(2026 update)* — reading tone in writing; preserving signal in distributed teams.
- **EI in incident comms** — staying calm under pressure; managing stakeholder anxiety.
- **Burnout recognition** — in self and team.

---

## Phase 1 Order (Locked)

Authoring order, depth-first:

1. **The Data Engineering Pattern Catalog** *(in progress next)*
2. **Working with DuckDB** *(updated to DuckDB 1.0+ era)*
3. **Effective Data Visualization** *(updated with modern web-native tooling)*
4. **Communication Patterns for Engineers**

Then Phase 2 (Communicating with Data + 2 Shortcuts) → Phase 3 (deferred decisions revisited).

---

## Phase 3 — Cloud + Programmer Wisdom Books (Locked)

Four new books approved (2026-05-03):

| Book | ID | Prefix | Chapters | Cards | accentHex | coverIcon |
|------|----|--------|----------|-------|-----------|-----------|
| AWS Essentials | `aws-essentials` | `aws-` | 13 | ~143 | `#FF9900` | `cloud.fill` |
| Azure Essentials | `azure-essentials` | `azr-` | 12 | ~132 | `#0078D4` | `cloud.fill` |
| 100 Things Every Programmer Should Know | `100-things-programmer` | `ttp-` | 10 | 100 | `#E040FB` | `chevron.left.forwardslash.chevron.right` |
| 100 Things Every Data Engineer Should Know | `100-things-data-engineer` | `tde-` | 10 | 100 | `#66BB6A` | `cylinder.split.1x2` |

### Execution Rule (5-at-a-time)

**Never run more than 5 background agents simultaneously.** Each agent writes exactly one chapter file then exits. Launch in batches of 5; wait for all 5 to complete before launching the next batch. After each batch, spot-check card counts — any chapter under density target gets a fresh expansion agent before proceeding.

---

### Book 8 — AWS Essentials (`aws-`)

13 chapters, 10–11 cards each (~143 total). 10 cards/chapter minimum.

| Ch | Title | Key topics |
|----|-------|-----------|
| 01 | AWS Fundamentals | Regions, AZs, edge locations, the Shared Responsibility Model, IAM root account, service categories, AWS CLI basics |
| 02 | Compute with EC2 | Instance types/families, AMIs, purchasing options (on-demand/spot/reserved/savings plans), placement groups, user data, EBS vs instance store |
| 03 | Serverless with Lambda | Event-driven execution, invocation models (sync/async/stream), cold starts, layers, concurrency limits, Lambda URLs, Step Functions |
| 04 | Containers on AWS | ECS (EC2 vs Fargate), EKS, App Runner, ECR, task definitions, service auto-scaling, sidecars pattern |
| 05 | Object Storage with S3 | Buckets, storage classes (Standard/IA/Glacier tiers), versioning, lifecycle rules, multipart upload, presigned URLs, S3 Select, access patterns |
| 06 | Block, File, and Archive Storage | EBS volume types, EFS vs FSx, AWS Backup, S3 Glacier Deep Archive, DataSync, Snow family |
| 07 | Networking with VPC | VPCs, subnets (public/private), route tables, internet gateways, NAT gateways, security groups vs NACLs, VPC peering, PrivateLink, Transit Gateway |
| 08 | Traffic Management and CDN | ALB vs NLB, Route 53 routing policies, CloudFront distributions, WAF basics, Global Accelerator |
| 09 | Databases on AWS | RDS (multi-AZ, read replicas), Aurora serverless, DynamoDB (partition key design, GSIs), ElastiCache, Redshift basics, DocumentDB |
| 10 | IAM and Security | IAM users/roles/policies, assume-role patterns, AWS Organizations, SCPs, Secrets Manager vs Parameter Store, KMS, CloudTrail |
| 11 | Data and Analytics | Glue (catalog + ETL), Athena, Kinesis (Streams/Firehose/Data Analytics), EMR, Lake Formation, OpenSearch, MSK |
| 12 | Observability and IaC | CloudWatch (metrics/logs/alarms), X-Ray, CloudFormation vs CDK vs Terraform on AWS, SSM, AWS Config, Service Catalog |
| 13 | Cost, AI Services, and Architecture Patterns | Cost Explorer, Budgets, Trusted Advisor, Bedrock, SageMaker basics, Well-Architected pillars, common multi-tier architecture patterns |

### Book 9 — Azure Essentials (`azr-`)

12 chapters, 10–11 cards each (~132 total). 10 cards/chapter minimum.

| Ch | Title | Key topics |
|----|-------|-----------|
| 01 | Azure Fundamentals | Regions, availability zones, resource groups, subscriptions, management groups, Azure Resource Manager, portal + CLI + Bicep basics |
| 02 | Compute: VMs and App Service | VM sizes/series, availability sets vs zones, scale sets, Azure Bastion, App Service plans, deployment slots, WebJobs |
| 03 | Serverless with Azure Functions | Hosting plans (Consumption/Flex/Premium), triggers, bindings, Durable Functions, Logic Apps comparison |
| 04 | Containers on Azure | AKS, Container Apps, Container Instances, Azure Container Registry, KEDA-based scaling, Dapr sidecar |
| 05 | Storage | Blob (tiers, lifecycle, ADLS Gen2), Queue Storage, Table Storage, Files, managed disks, SAS tokens, shared access policies |
| 06 | Networking with VNet | VNets, subnets, NSGs, ASGs, VNet peering, Private Endpoints, VPN Gateway, ExpressRoute, Azure DNS |
| 07 | Traffic Management and CDN | Azure Load Balancer, Application Gateway (+ WAF), Front Door, Traffic Manager, Azure CDN |
| 08 | Databases | Azure SQL (elastic pools, hyperscale), Cosmos DB (partition key design, consistency levels), PostgreSQL Flexible Server, Redis Cache, Synapse Analytics |
| 09 | Identity and Security | Azure AD (Entra ID), RBAC, managed identities, Key Vault, Defender for Cloud, Policy, Blueprints, PIM |
| 10 | Data and Analytics | Azure Data Factory, Event Hubs, Stream Analytics, Databricks on Azure, Purview, HDInsight, Azure OpenAI Service integration |
| 11 | Observability and IaC | Azure Monitor, Log Analytics, Application Insights, Bicep vs ARM vs Terraform, Azure DevOps pipelines, GitHub Actions on Azure |
| 12 | Cost, AI, and Architecture Patterns | Cost Management + Advisor, Reservations, Azure AI services, Azure OpenAI, Landing Zones, common PaaS architecture patterns |

### Book 10 — 100 Things Every Programmer Should Know (`ttp-`)

10 chapters × 10 cards = 100 cards. Based on the "97 Things Every Programmer Should Know" O'Reilly collection, renamed to "100 Things" with 3 extra cards authored fresh.

**3 additions (new cards, not from source):**
- "Treat AI-generated code like a PR from a stranger" — review it with the same skepticism; understand before merging
- "Observability is a design decision, not a retrofit" — instrument from day one; logs/metrics/traces are architecture
- "Write for the maintainer who has no context" — the reader is future-you at 2am with no memory of this codebase

| Ch | Title | Focus |
|----|-------|-------|
| 01 | Code as Communication | Readability, naming, intent, comments that add not repeat, the cost of clever |
| 02 | Design Principles | DRY, SOLID, YAGNI, the right abstraction level, coupling vs cohesion |
| 03 | Testing and Reliability | Unit vs integration vs e2e, TDD mindset, test what matters, flaky tests, fail fast |
| 04 | Performance and Efficiency | Profile before optimizing, algorithmic complexity, memory vs CPU tradeoffs, caching right |
| 05 | Security Fundamentals | Input validation, least privilege, secrets management, dependency risk, threat modeling basics |
| 06 | Collaboration and Code Review | PR etiquette, review mindset, giving and receiving feedback, shared ownership |
| 07 | Developer Tooling and Productivity | Editor fluency, CLI habits, debugging systematically, local environment discipline |
| 08 | Data and State | State management, data structures that match the problem, immutability benefits, the cost of mutation |
| 09 | Career and Professional Growth | Deliberate practice, T-shaped skills, communication as a skill, knowing when to ask |
| 10 | Modern Engineering (2026) | AI-generated code review, observability as design, writing for maintainers, staying current without chasing hype |

### Book 11 — 100 Things Every Data Engineer Should Know (`tde-`)

10 chapters × 10 cards = 100 cards. Based on the "97 Things Every Data Engineer Should Know" O'Reilly collection, renamed to "100 Things" with 3 extra cards authored fresh.

**3 additions (new cards, not from source):**
- "Treat your data pipeline like production software" — version it, test it, monitor it, on-call it
- "Build LLM-ready pipelines from the start" — chunking, embedding, metadata, structured outputs are data engineering problems
- "The local-first analytics mindset — DuckDB before Spark" — reach for the simpler tool first; scale only when you must

| Ch | Title | Focus |
|----|-------|-------|
| 01 | Data Engineering Foundations | What data engineers do, pipeline thinking, the modern data stack, responsibility boundaries |
| 02 | Data Storage and Formats | Parquet, ORC, Avro, Delta/Iceberg, choosing a format, compression tradeoffs |
| 03 | Data Pipeline Design | Idempotency, late-arriving data, exactly-once semantics, pipeline contracts |
| 04 | Data Quality and Testing | Expectations, schema enforcement, anomaly detection, testing dbt models |
| 05 | Orchestration and Scheduling | DAG design, dependency management, sensors, retries, idempotent tasks |
| 06 | Streaming and Real-Time | Kafka fundamentals, event sourcing, windowing, stateful processing, Lambda vs Kappa |
| 07 | Data Governance and Security | Lineage, cataloging, column masking, row-level security, access audit, PII handling |
| 08 | Cloud Data Platforms | Warehouse vs lakehouse, BigQuery/Redshift/Snowflake tradeoffs, cost-per-query patterns |
| 09 | Analytics Engineering and Modeling | dbt basics, star vs wide table, semantic layer, metrics consistency across reports |
| 10 | Modern Data Engineering (2026) | Production pipeline mindset, LLM-ready pipeline design, local-first analytics with DuckDB |

---

## Current Status (as of 2026-05-03)

Books committed to library (11 total):

| Book | Prefix | Chapters | Cards |
|------|--------|----------|-------|
| Engineering Data Systems | eds- | 13 | 153 |
| The Data Engineering Pattern Catalog | depc- | 13 | ~156 |
| Working with DuckDB | wdd- | 13 | 162 |
| Effective Data Visualization | edv- | 13 | 130 |
| Communication Patterns for Engineers | cpe- | 12 | 144 |
| Communicating with Data | cwd- | 10 | 120 |
| Critical Thinking for Engineers | cte- | 5 | 39 |
| Emotional Intelligence at Work | eiw- | 5 | 39 |
| AI Agents (Definitive Guide) | — | 7 | 85 |
| LLM Patterns | — | 10 | 120 |
| Software Architecture | — | 16 | 160 |

**Pending (Phase 3):** aws-essentials (13 ch), azure-essentials (12 ch), 100-things-programmer (10 ch), 100-things-data-engineer (10 ch) = 45 chapters total.

---

## Next Concrete Step

Start Phase 3 books. Launch 5 agents at a time (one chapter per agent). Order:

**Batch 1 (first 5 agents):**
1. aws-essentials ch01
2. aws-essentials ch02
3. azure-essentials ch01
4. azure-essentials ch02
5. 100-things-programmer ch01

Continue in batches of 5 until all 45 chapters are done. After each book, run:
```
node scripts/build-books.js && ./scripts/sync-books.sh
```
Then verify card counts and commit.
