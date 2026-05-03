@chapter
id: tams-ch09-black-box-testing-of-ai-systems
order: 9
title: Black-Box Testing of AI Systems
summary: Black-box techniques for AI — metamorphic testing, A/B testing, pairwise testing, back-to-back / differential testing — let you exercise a model without ground truth, by relying on relations between outputs instead of fixed expected values.

@card
id: tams-ch09-c001
order: 1
title: The No-Ground-Truth Problem
teaser: Most AI inputs don't have a known correct answer — which breaks the test oracle assumption that traditional testing takes for granted.

@explanation

Classical software testing rests on a simple premise: given input X, there is a correct output Y. Write an assertion, run the test, compare. In AI systems, this assumption usually fails.

Consider an image classifier processing a photo of a partially obscured street sign, or a language model summarizing a legal brief, or a recommender system choosing films for a new user. For any of these inputs, what is the single provably correct output? There isn't one. The space of valid outputs is often large and poorly defined, the model's internal logic is not inspectable, and "correct" can depend on context, user, and time.

This is called the **test oracle problem**: the difficulty of determining whether an observed output is actually correct. It is the central obstacle distinguishing AI testing from testing deterministic systems.

The consequences are practical:

- You cannot write a unit test of the form `assert model(input) == expected_output` for the general case.
- Regression testing requires more than comparing to a previous output — you need to know whether the previous output was any good.
- Test coverage metrics that count executed branches have no meaning when you cannot access the model's internal structure.

Black-box techniques address this by shifting the question from "is this output correct?" to "does the relationship between these outputs make sense?" That shift is the foundation of every technique in this chapter.

> [!info] The test oracle problem is not unique to AI — it also arises in scientific simulations and compilers. AI systems have made it the common case rather than the exception.

@feynman

The no-ground-truth problem means you can test whether a model is consistent and well-behaved without ever needing to know what the single right answer is.

@card
id: tams-ch09-c002
order: 2
title: Metamorphic Testing
teaser: Instead of asking "is this output correct?", metamorphic testing asks "if I change the input in a predictable way, does the output change predictably?" — and that question has an answer even without a known oracle.

@explanation

Metamorphic testing, introduced by T.Y. Chen and colleagues in 1998, is the primary technique for testing without oracles. The core idea is to define **metamorphic relations (MRs)**: properties that must hold between pairs (or groups) of related inputs and their outputs.

The structure of a metamorphic test:

1. Run the model on a seed input `x` to get output `f(x)`.
2. Derive a follow-up input `x'` by applying a transformation to `x`.
3. Based on the known relationship between `x` and `x'`, assert something about the relationship between `f(x)` and `f(x')`.

Example for a sentiment classifier: if you paraphrase a positive sentence while preserving its sentiment, the classifier's output should remain positive. You do not need to know the exact confidence score — only that it should not flip to negative.

Example for a ranking model: if you add noise to an item's features that should be irrelevant to rank (e.g., whitespace in a product description), the item's relative rank among peers should not change significantly.

The technique does not require any labeled data for the follow-up inputs. The original seed output serves as the implicit expected value, and the metamorphic relation encodes what "correct behavior" means in terms of that output.

At scale, metamorphic testing has found bugs in compilers (GCC, LLVM via Csmith), scientific computing libraries (SciPy, MATLAB), and ML frameworks. The technique is supported by the ISTQB® CT-AI v1.0 syllabus as a first-class testing approach for AI systems.

> [!tip] Start by listing properties your model should have — monotonicity, invariance to irrelevant features, symmetry — and each one is a candidate metamorphic relation waiting to be formalized.

@feynman

Metamorphic testing sidesteps the oracle problem by checking that the model behaves consistently when the input is transformed in a way whose effect on the output you can predict.

@card
id: tams-ch09-c003
order: 3
title: Common Metamorphic Relations
teaser: The value of metamorphic testing depends entirely on which relations you choose — and a handful of patterns cover most ML systems.

@explanation

Metamorphic relations (MRs) are not universal — they must be derived from the semantics of the system under test. That said, several patterns recur across problem domains.

**Invariance relations** — the output should not change when the input is transformed in a way that is semantically neutral. Examples:
- For an image classifier: rotating an image of a stop sign by 5 degrees should not change its label.
- For a spam filter: reformatting whitespace in an email should not change the spam decision.
- For a NLP model: adding a semantically empty prefix like "Note: " should not change entity extraction results.

**Monotonicity relations** — increasing (or decreasing) one feature should move the output in a predictable direction. Examples:
- A credit risk model: raising annual income while holding everything else constant should not increase predicted default probability.
- A search ranking model: adding more exact-match keywords to a query should not reduce the relevance score for a document that contains those keywords.

**Permutation relations** — reordering inputs that are semantically equivalent should not change the output. Example: a bag-of-words classifier should produce the same score for "quick brown fox" and "fox brown quick."

**Scaling relations** — multiplying all numerical inputs by a positive constant should leave the output unchanged (for normalized models) or scale it proportionally (for linear models).

**Additive relations** — splitting a document into two halves and classifying each should produce outputs that, when combined, are consistent with classifying the whole.

Choosing the wrong MR — one that the model is not actually required to satisfy — produces false alarms. Before adding an MR to a test suite, verify it against the model's specification.

> [!warning] Not every intuitive invariance is a correct MR. A translation model is not required to preserve sentence length. Validate your MRs against the system's documented behavior before treating violations as bugs.

@feynman

Metamorphic relations are the formalized intuitions about how a model should behave — if you rotate a stop sign image slightly, a good classifier should still call it a stop sign.

@card
id: tams-ch09-c004
order: 4
title: Search-Based Metamorphic Test Generation
teaser: Writing metamorphic relations by hand doesn't scale past a few dozen; search-based techniques automate the discovery of both the relations and the test inputs that violate them.

@explanation

Manual metamorphic relation derivation requires domain knowledge, time, and is inherently incomplete. For complex ML systems — particularly those with high-dimensional inputs like images or text — search-based test generation addresses the scale problem.

The approach uses search or optimization algorithms to find inputs that:
- Satisfy a given metamorphic relation on the surface (the transformation is valid), but
- Produce an output that violates the expected relational property.

Techniques in active use as of 2026-Q2:

**Fuzzing-guided metamorphic testing.** A fuzzer mutates seed inputs, applies the metamorphic transformation to each mutated input, and flags pairs where the relation is violated. Tools like AFL++ adapted for structured inputs (JSON, images) take this approach.

**Genetic algorithms.** A population of input pairs is evolved using a fitness function that rewards large differences between `f(x)` and `f(x')` when the MR predicts they should be equal (or vice versa). This is effective for finding decision-boundary violations.

**Model-guided search.** For differentiable models, gradient information guides the search toward inputs near decision boundaries where metamorphic violations are most likely. This overlaps with adversarial example generation.

**Large-model test synthesis.** As of 2026-Q2, LLMs are being used to generate semantically valid paraphrases and input variants for NLP metamorphic testing — effectively automating the "paraphrase while preserving intent" MR. The risk is that the LLM itself introduces inadvertent semantic shifts that the MR was intended to detect.

The output of any search-based generator requires human triage — not every flagged pair is a genuine violation, since the generator may produce transformations that violate the MR's preconditions.

> [!info] Search-based generation is most valuable when seed inputs are abundant but MR violations are rare — it finds the needles in a large haystack much faster than random sampling.

@feynman

Search-based metamorphic test generation automates the hunt for inputs that break the expected relationships between outputs, using optimization to focus effort where violations are most likely to hide.

@card
id: tams-ch09-c005
order: 5
title: A/B Testing in Production
teaser: A/B testing is not a quality-assurance shortcut — it is a controlled experiment on live traffic, and its validity depends entirely on statistical power you probably haven't calculated.

@explanation

A/B testing (also called online controlled experimentation or split testing) compares two model versions — the control (A) and the treatment (B) — by routing a fraction of real user traffic to each and measuring outcomes. Unlike offline evaluation, it captures real user behavior under real conditions.

The mechanics:
- Traffic is randomly split at the user or session level (not request level, to avoid within-session inconsistency).
- Both variants run simultaneously to eliminate temporal confounds.
- A primary metric (e.g., click-through rate, task completion, user retention) is measured for each group.
- A statistical test (typically a two-sample t-test or Mann-Whitney U) determines whether the observed difference is likely due to the treatment or to chance.

**Statistical power is the most commonly ignored requirement.** Power is the probability of detecting a real effect if one exists. Running an A/B test without a power calculation produces one of two failure modes:
- Stopping too early (underpowered): real effects are missed; A and B look equal when B is actually better.
- Running too long (multiple comparisons inflation): the false positive rate inflates with every check.

As of 2026-Q2, platforms like Statsig and LaunchDarkly provide integrated power calculators and sequential testing frameworks (such as CUPED and mSPRT) that allow continuous monitoring without inflating error rates.

Common pitfalls beyond power:
- **Network effects.** If users interact with each other, contamination between A and B groups is likely. Use cluster-level randomization.
- **Novelty effects.** Users behave differently with new things. Short tests overestimate treatment effects.
- **Metric selection.** Optimizing for the wrong metric (e.g., short-term clicks over long-term retention) produces a winner that harms the product.

> [!warning] "We ran it for a week and B looked better" is not a valid A/B test conclusion unless you calculated the required sample size before starting and did not peek at results mid-run.

@feynman

A/B testing is a live experiment on real users, and its conclusions are only as valid as the statistical discipline used to design it — most informal A/B tests are underpowered and stopped too early.

@card
id: tams-ch09-c006
order: 6
title: Back-to-Back and Differential Testing
teaser: When you have two implementations of the same model — two versions, two frameworks, two serving stacks — running both on the same inputs and comparing outputs finds bugs without any oracle.

@explanation

Back-to-back testing (also called differential testing or N-version testing) runs two or more independently developed implementations of the same system on identical inputs and flags discrepancies. The underlying assumption is that both implementations are unlikely to make the same mistake on the same input in the same way — so disagreement is evidence of a bug in one of them.

In ML contexts, this applies at several levels:

**Framework portability testing.** A model trained in PyTorch is exported to ONNX for serving. Running both on the same input set and comparing outputs detects conversion bugs — quantization errors, op-level numerical differences, shape broadcasting discrepancies — that are invisible from looking at the model definition alone.

**Version regression.** A new model version (v2) should produce outputs consistent with v1 on inputs where v1 is known to perform well. Running both versions on a shared evaluation set and flagging large divergences catches regressions without requiring ground-truth labels. This is a labeled-free regression signal.

**Multi-framework consistency.** The same mathematical model expressed in TensorFlow and JAX should produce numerically equivalent outputs (within floating-point tolerance). Discrepancies indicate an implementation error in at least one.

**Practical tolerance setting.** For floating-point outputs, exact equality is the wrong criterion. A relative tolerance (e.g., `|f_A(x) - f_B(x)| / |f_A(x)| < 1e-5`) is appropriate for continuous scores. For classification outputs, disagreement on the predicted class is a stronger signal than score divergence alone.

The technique produces no false negatives from oracle errors (since there is no oracle), but it does produce false positives when both implementations legitimately produce valid but different outputs (e.g., equivalent but differently ranked recommendations).

> [!tip] Back-to-back testing is particularly effective during ML framework migrations — exporting a model from training to serving is a transformation step that is easy to get wrong and hard to detect without differential comparison.

@feynman

Back-to-back testing finds bugs by running two versions of the same model on identical inputs and treating any disagreement as a signal that something is wrong with at least one of them.

@card
id: tams-ch09-c007
order: 7
title: Shadow Testing
teaser: Shadow testing lets you evaluate a new model against real traffic without exposing users to its outputs — the new model runs in parallel, its outputs are compared internally, and nothing it produces reaches the user.

@explanation

Shadow testing (also called dark launch or shadow mode deployment) is a production testing technique in which a new model receives a copy of real traffic and produces outputs that are logged but never served. The production model's outputs continue to reach users; the shadow model's outputs are evaluated offline.

The mechanics:
- Requests are duplicated at the serving layer: the primary model handles the live request; the shadow model receives the same input asynchronously.
- Both outputs are logged alongside each other.
- Comparison is done offline: automated metrics, human reviewers, or a reference model score both outputs.
- Latency of the shadow model does not affect user experience (since its output is discarded).

What shadow testing is good at:
- **Output distribution shift detection.** If the shadow model produces drastically different distributions of outputs (e.g., more aggressive recommendations, different language register), that is visible before any user sees it.
- **Latency and resource profiling under real load.** The shadow model experiences real traffic volume without real stakes.
- **Confidence calibration comparison.** Comparing confidence scores between production and shadow models reveals calibration differences that offline evaluation sets often miss.

What it cannot do:
- Shadow testing cannot measure user-facing outcomes (click-through rate, task completion). The shadow model never reaches users, so behavioral response is unobservable. For that, you need an A/B test.
- It cannot detect bugs that depend on feedback loops — cases where the model's output feeds back into future inputs.

Shadow testing is often used as the step before an A/B test: validate that the shadow model produces plausible outputs at scale, then gradually shift traffic to it for a controlled experiment.

> [!info] Shadow testing eliminates deployment risk for the evaluation phase but does not replace A/B testing for measuring real-world impact. It answers "does the model behave plausibly?" not "does the model produce better outcomes for users?"

@feynman

Shadow testing runs a new model on real traffic in secret — its outputs are observed and compared but never shown to users, so you can evaluate production-scale behavior without any user-facing risk.

@card
id: tams-ch09-c008
order: 8
title: Pairwise Testing for ML
teaser: Most ML bugs are triggered by combinations of input features, not individual features — pairwise testing provides combinatorial coverage of two-way feature interactions at a fraction of the cost of full factorial testing.

@explanation

Pairwise testing (also called all-pairs testing or 2-way interaction testing) selects a test suite in which every pair of input parameter values appears together at least once. It is based on the empirical observation — replicated across many domains of software testing — that a large fraction of bugs are triggered by combinations of exactly two factors rather than by single factors or higher-order combinations.

For ML systems, the technique applies to:
- **Feature value combinations.** A model that processes structured inputs (age, income, region, account type) may behave unexpectedly when specific pairs of values co-occur, even if it handles each value correctly in isolation.
- **Preprocessing pipeline parameters.** Tokenizer settings, normalization strategies, and imputation methods interact. Pairwise coverage of preprocessing configurations exercises the space efficiently.
- **Serving configuration combinations.** Batch size, quantization level, and hardware backend interact in ways that can produce incorrect outputs.

**Orthogonal Latin Squares and covering arrays** are the mathematical tools for constructing pairwise test suites. A full factorial test of 5 binary parameters requires 32 cases; a pairwise-covering orthogonal array reduces this to 8, with the guarantee that every pair is covered.

Tools that generate covering arrays include ACTS (Automated Combinatorial Testing for Software, maintained by NIST) and the open-source `allpairspy` Python library.

The technique does not guarantee that 3-way or higher interactions are covered. In practice, ML bugs that require 3-way interactions to manifest are less common, but for safety-critical models it is worth extending to 3-way coverage for the highest-risk parameter combinations.

> [!tip] When testing ML preprocessing pipelines, enumerate the discrete options for each step, construct a pairwise covering array with ACTS or allpairspy, and run the model on each combination — this is significantly more thorough than testing each parameter independently.

@feynman

Pairwise testing ensures that every combination of two input parameters has been tested at least once, covering the most common cause of interaction bugs with far fewer test cases than testing all combinations.

@card
id: tams-ch09-c009
order: 9
title: Equivalence Partitioning for ML Inputs
teaser: Grouping inputs into semantic equivalence classes — and testing one representative from each — is the foundation of systematic ML black-box testing; the hard part is defining the partitions.

@explanation

Equivalence partitioning divides the input space into groups (partitions) where the model is expected to behave in the same way for all inputs within a group. One representative per partition is tested, with the assumption that if the model handles the representative correctly, it handles all members of the partition correctly.

For ML systems, partitions are typically defined along semantic rather than syntactic boundaries:

**For image classifiers:**
- Partition by lighting condition (bright daylight, low light, flash)
- Partition by image quality (high resolution, compressed artifact, blurry)
- Partition by subject position (centered, edge-placed, partially occluded)

**For NLP models:**
- Partition by register (formal, informal, colloquial, technical)
- Partition by language variety (American English, British English, Indian English)
- Partition by sentence structure (short declarative, complex subordinate, interrogative)

**For tabular models:**
- Partition by demographic group (when testing for fairness)
- Partition by data provenance (enterprise vs. SMB accounts, if the model may have trained differently on each)
- Partition by missingness pattern (all features present, minority features missing, majority features missing)

The difficulty in ML equivalence partitioning is that the model defines its own decision boundaries, and those boundaries do not necessarily align with human-intuitive semantic categories. A partition you think is equivalent may straddle an internal decision boundary you cannot see.

As of 2026-Q2, one practical approach is to use embedding space clustering to discover partitions empirically — inputs that cluster together in the model's embedding space are candidates for a partition.

> [!info] Human-intuitive equivalence partitions may not align with the model's actual behavior partitions. Always validate partition assumptions against held-out samples before treating a representative result as covering the full partition.

@feynman

Equivalence partitioning groups similar inputs together and tests one from each group, saving effort while ensuring you exercise the model across all meaningfully different input types.

@card
id: tams-ch09-c010
order: 10
title: Boundary Testing for ML
teaser: ML decision boundaries are where the model is most uncertain and most likely to produce wrong or inconsistent outputs — finding and testing them is the highest-leverage single technique in black-box ML testing.

@explanation

In classical software testing, boundary value analysis tests inputs at the edges of equivalence partitions — the maximum, minimum, and values just inside and outside the boundary. For ML systems, the equivalent technique finds inputs near the model's **decision boundary**: the region where the model transitions from one output to another.

Decision-boundary inputs are the most valuable tests for several reasons:
- They are where the model's uncertainty is highest, making them most likely to be sensitive to small perturbations.
- They are where metamorphic relation violations are most likely to occur — a small, semantically neutral change near the boundary is more likely to flip the output than the same change far from it.
- They reveal how much margin the model has on typical inputs. A model with very narrow margins is fragile even if it appears accurate on standard evaluation sets.

**Finding decision-boundary inputs without gradients:**
- Binary search along a line connecting two inputs from opposite classes in feature space. The midpoint that causes the model to flip its prediction is a boundary point.
- Perturbation-based search: systematically modify an input (increase a feature, change a word, alter a pixel region) until the output changes. The minimal change that causes a flip defines the boundary.
- Adversarial example generation (even in a black-box setting) is effectively boundary search — tools like Foolbox support black-box attacks that do not require gradient access.

**What boundary tests reveal:**
- Fragility: if the boundary is very close to typical inputs, the model is easily fooled by minor input variation.
- Fairness issues: if inputs from one demographic group cluster systematically closer to the decision boundary than another, that group receives lower-confidence (higher-risk) predictions.

> [!warning] A model that achieves high accuracy on randomly sampled test sets can still have decision boundaries that are dangerously close to important real-world inputs. Accuracy on random samples does not bound boundary margin.

@feynman

Boundary testing for ML means finding the inputs where the model is on the fence between two outputs — those are the places where small changes cause failures and where the model is most fragile.

@card
id: tams-ch09-c011
order: 11
title: Property-Based Testing for ML
teaser: Property-based testing formalizes invariants the model must satisfy — monotonicity, idempotence, symmetry — and generates hundreds of random inputs to find violations automatically.

@explanation

Property-based testing (PBT) automatically generates test inputs and checks that specified properties hold across all of them. For ML, PBT is the practical tool for operationalizing metamorphic relations and model invariants at scale without writing individual test cases.

The canonical PBT library in Python is **Hypothesis**. Hypothesis generates structured random inputs according to user-defined strategies, shrinks failing examples to their minimal form, and persists failing cases in a database for regression.

Example properties for ML models and how to encode them:

**Monotonicity.** For a loan default risk model, increasing the debt-to-income ratio while holding other features constant should not decrease predicted risk.
```python
@given(st.floats(min_value=0, max_value=2))
def test_risk_monotonic_in_dti(dti):
    base = make_applicant(dti=0.3)
    higher = make_applicant(dti=max(dti, 0.3))
    assert model.predict(base) <= model.predict(higher)
```

**Idempotence.** Applying a preprocessing pipeline twice should produce the same result as applying it once (for normalizers, tokenizers).

**Symmetry.** A document similarity model should return the same score for `(doc_a, doc_b)` and `(doc_b, doc_a)`.

**Output range.** A probability output should always be in `[0.0, 1.0]`.

**Consistency under neutral augmentation.** Adding a meaningless prefix to a text input should not change the output (an invariance MR expressed as a property).

As of 2026-Q2, the Hypothesis `hypothesis-extra` strategies for numpy arrays and pandas DataFrames make it straightforward to generate structured tabular inputs for ML models. The `st.from_type` inference is useful for models that already have typed input schemas (Pydantic models, dataclasses).

PBT is not a replacement for metamorphic testing with semantically motivated relations — it complements it by automating the input generation step once the properties are defined.

> [!tip] Start with the two properties every ML model should have: output range validity and symmetry where applicable. Both are fast to write, cheap to run, and catch implementation bugs that unit tests on fixed inputs miss.

@feynman

Property-based testing gives a model hundreds of random inputs and checks that it never violates the invariants it is supposed to maintain, like always outputting a valid probability or treating symmetric inputs equally.

@card
id: tams-ch09-c012
order: 12
title: Human Eval as Ground Truth
teaser: When no automated oracle exists, human judgment becomes the test oracle — and the cost, consistency, and bias of that judgment become quality attributes of your test suite, not just inconveniences.

@explanation

For many generative AI and open-ended classification tasks — text summarization, dialogue quality, creative output, visual question answering — there is no automated metric that adequately captures output quality. Human evaluation becomes the ground truth. Using it well requires treating the human evaluation process as an engineering problem.

**Consistency is the primary reliability concern.** Inter-annotator agreement (IAA) measures how consistently different human evaluators produce the same rating. Low IAA (below Cohen's kappa of ~0.4) means the evaluation criteria are too subjective or the rater pool is too diverse. Calibration sessions, detailed rubrics with worked examples, and pilot batches with IAA measurement before full-scale evaluation are standard mitigations.

**Cost structures.** Crowdsourced annotation (via platforms like Scale AI or Amazon Mechanical Turk) is cheap per label but high variance. Expert annotation is expensive but necessary for specialized domains (medical, legal, code). LLM-as-judge (using a strong model to rate another model's output) is fast and cheap but introduces the judge model's own biases and is not appropriate when the evaluated model and the judge model share training data.

**Systematic biases in human eval:**
- Position bias: raters favor outputs shown first or last.
- Length bias: longer outputs are often rated higher regardless of quality.
- Familiarity bias: outputs that match the rater's dialect or cultural reference points score higher.

These biases should be controlled through randomized presentation order, blind rating (raters do not know which model produced which output), and explicit rubric criteria that discourage length-as-quality heuristics.

**Coverage vs. depth tradeoff.** A large number of lightly evaluated examples gives broad coverage but misses subtle quality issues. A small number of deeply evaluated examples gives rich signal but may not represent the full input distribution. The right balance depends on what the evaluation is trying to detect.

As of 2026-Q2, the standard pipeline for production LLM evaluation combines automated metrics (BLEU, BERTScore, LLM-as-judge) for initial filtering, followed by human evaluation on a stratified sample of borderline and high-stakes outputs.

> [!warning] LLM-as-judge evaluation is convenient but not equivalent to human ground truth. It is appropriate for fast iteration and automated regression, but not as the sole quality gate for a production release affecting real users.

@feynman

Human evaluation is the oracle of last resort for AI systems — and the quality of your test suite depends not just on what humans are asked to judge, but on how consistently, carefully, and without bias they do the judging.
