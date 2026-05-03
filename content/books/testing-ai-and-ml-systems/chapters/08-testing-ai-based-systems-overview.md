@chapter
id: tams-ch08-testing-ai-based-systems-overview
order: 8
title: Testing AI-Based Systems Overview
summary: Testing an AI system is testing a pipeline — data, model, integration, deployment — not just a function with inputs and outputs, and the test pyramid for ML differs in shape and structure from the classical one.

@card
id: tams-ch08-c001
order: 1
title: The ML Test Pyramid
teaser: The classical test pyramid — many unit tests, fewer integration tests, fewest end-to-end tests — does not transfer to ML systems without significant reshaping; the bulk of defects and testing effort live at a layer the classical pyramid has no name for.

@explanation

The classical software test pyramid rests on a simple assumption: behavior is determined by code, and code can be isolated into functions with deterministic outputs. Testing a unit in isolation is cheap, fast, and exhaustive. Testing the integrated system is expensive and reserved for verification of composition.

ML systems break that assumption in two places. First, behavior is determined by both code and data — a pipeline that is code-correct can produce a broken model if the training data is malformed, mislabeled, or distributed differently from what the model will see at inference time. Second, the model itself is not inspectable as a function — you cannot enumerate its behavior exhaustively, only sample it.

The result is a pyramid that looks different at every layer:

- **Data tests** form the widest base — schema validation, range checks, distribution monitoring, and label integrity checks. These are cheap to run and catch the majority of ML defects in practice.
- **Component tests** cover individual pipeline stages — does the feature transformer produce the right shape? does the training loop converge? These replace classical unit tests.
- **Model tests** check the trained artifact — input/output shape, serialization, basic smoke behavior, and metric thresholds on held-out data.
- **Integration and end-to-end tests** sit at the top as in the classical pyramid, but they now exercise the full data-to-prediction path.

The ISTQB® CT-AI v1.0 syllabus formalizes this structure, emphasizing that ML testing must address data quality, model quality, and system integration as distinct but interdependent concerns.

> [!info] As of 2026-Q2, tools like Great Expectations (data layer), pytest with MLflow (model layer), and DVC pipelines (pipeline layer) have become the practical implementation of this pyramid for most Python-based ML teams.

@feynman

The ML test pyramid is wider at the bottom than you expect because most bugs live in the data and the pipeline, not in the model code itself.

@card
id: tams-ch08-c002
order: 2
title: Pipeline Testing as the New Unit Testing
teaser: In ML, the "unit" worth testing is not the model — it is the data path that leads to it; a model trained on corrupted data cannot be fixed by testing the model.

@explanation

Classical unit testing isolates a function, provides known inputs, and asserts known outputs. The assumption is that behavior is entirely determined by the function under test. In an ML pipeline, a comparable guarantee requires testing the data path: the code that loads, filters, joins, encodes, and transforms training data before the model ever sees it.

Pipeline testing treats each stage of the data path as a testable unit:

- **Data loading code** can be tested with small fixture datasets that exercise schema expectations, type coercions, and missing-value handling.
- **Feature transformation functions** can be tested as pure functions — given this input dataframe, assert this output dataframe, column by column.
- **Train/validation split logic** can be tested to confirm no leakage (validation records do not appear in training data), correct proportions, and reproducibility under a fixed seed.
- **Label encoding and class mapping** can be tested to confirm invertibility and that all expected classes are represented.

In pytest, this translates to standard parametrized tests against small fixtures. A feature transformation test that runs in milliseconds and catches a sign-flip in a normalization formula prevents days of debugging a model that trains but does not generalize.

The practical rule from teams that have scaled ML testing: fix the pipeline tests first. Pipeline defects produce model defects that are indistinguishable from algorithmic problems until you rule out the data path.

> [!tip] Keep pipeline stage functions side-effect-free and stateless wherever possible. A feature transformer that accepts a dataframe and returns a dataframe is trivially testable; one that reads from a database and writes to a cache is not.

@feynman

Pipeline testing in ML is like checking every ingredient and kitchen step before tasting the dish — if the prep work is broken, the recipe cannot save you.

@card
id: tams-ch08-c003
order: 3
title: Test the Pipeline First, Then the Model
teaser: The majority of production ML defects trace back to the data pipeline, not the model architecture — and a model trained on a broken pipeline produces broken predictions that look like model failures.

@explanation

This rule is one of the most counterintuitive findings for teams migrating from classical software testing: when an ML system misbehaves in production, the first investigation target should be the data pipeline, not the model weights, hyperparameters, or architecture.

The reasons are structural:

- **Pipeline defects are silent.** A misjoined table, a wrong date filter, or an off-by-one in a rolling window does not raise an exception during training. The model trains to completion. Metrics on the training set may even look acceptable. The defect only surfaces when predictions fail on real inputs.
- **Pipeline defects are multiplicative.** A label encoding error affects every training example. A feature distribution shift affects every prediction. A single-line bug in a data loader can corrupt an entire training run.
- **Model defects are rare by comparison.** Given a correct pipeline and correctly specified loss function, modern ML frameworks (PyTorch, scikit-learn) rarely have algorithmic bugs. The model does what it is told with the data it receives.

The recommended testing sequence:

1. Write and pass all data loading tests.
2. Write and pass all feature transformation tests.
3. Write and pass train/validation split and leakage tests.
4. Only then train the model and evaluate it.

DVC pipelines and MLflow experiment tracking support this discipline by making each pipeline stage an explicit, versioned artifact that can be tested before downstream stages run.

@feynman

Testing the pipeline before the model is like confirming your scale and measuring cups are accurate before concluding that a recipe is wrong.

@card
id: tams-ch08-c004
order: 4
title: Testing Data-Loading Code
teaser: Data loading is the point where external reality enters your pipeline — and the schema, types, value ranges, and null handling you assume must be asserted, not trusted.

@explanation

Data loading code is the boundary between the world outside your pipeline and the controlled environment inside it. Every assumption you make about the input data is a potential defect waiting to surface: a column that is always present until it isn't, a numeric field that is always positive until a data entry error introduces a negative, a timestamp that is always UTC until a new source joins that is local time.

The testing pattern for data loading has four layers:

**Schema validation.** Assert that required columns are present, that column names match expectations, and that no unexpected columns have been silently added. Great Expectations makes this explicit with `expect_column_to_exist` and `expect_table_columns_to_match_ordered_list`.

**Type validation.** Assert that each column has the expected dtype. A float column silently cast to object because one row contained a string is a common cause of downstream training failures.

**Range and domain validation.** Assert that numeric values fall within physically meaningful bounds (`age >= 0`, `probability between 0 and 1`), that categorical values are members of the expected set, and that date columns fall within the expected time window.

**Missing value validation.** Assert that columns expected to be complete are complete, and that columns allowed to have nulls do not exceed an expected null rate. A sudden spike in null rate in a feature column often indicates an upstream data source change.

In pytest, these translate to fixture-backed tests with small representative datasets that cover the boundary conditions. Great Expectations additionally provides profiling-based expectations that can be generated from historical data and then asserted against new loads as part of a CI pipeline.

> [!warning] Never assume that a data source that was clean last week is clean today. Data loading tests must run on every pipeline execution, not just during initial development.

@feynman

Testing data loading is enforcing a contract at the door — you write down exactly what shape and quality of data you expect, and you reject anything that does not match before it can corrupt the work inside.

@card
id: tams-ch08-c005
order: 5
title: Testing Feature Transformations
teaser: Feature transformations should be testable as pure functions — and the three properties worth asserting are invertibility where applicable, idempotence, and distribution preservation.

@explanation

Feature transformations convert raw data into model inputs. They are among the most bug-prone parts of an ML pipeline because they often involve mathematical operations whose correctness is non-obvious and whose failures are silent.

Three properties are worth asserting explicitly:

**Invertibility.** A transformation that is meant to be reversible should be reversible. If you apply a log transform during training and an inverse-log at inference, a test that round-trips a sample through both should recover the original values within floating-point tolerance. A sign error in the inverse transform will not raise an exception — it will produce numbers that look plausible while being wrong.

```python
def test_log_transform_invertible():
    original = np.array([1.0, 10.0, 100.0, 1000.0])
    transformed = log_transform(original)
    recovered = inverse_log_transform(transformed)
    np.testing.assert_allclose(recovered, original, rtol=1e-6)
```

**Idempotence.** A transformation applied twice should produce the same result as applying it once, unless the transformation is explicitly stateful. Applying a scaler fit on training data to already-scaled data should not silently shift the distribution further.

**Distribution preservation.** A normalization step that maps values to `[0, 1]` should be tested with inputs covering the full expected range to confirm the output range is correct. A test using only "typical" values may miss that extreme values are clipped or wrapped.

In scikit-learn, transformers implement `fit`, `transform`, and `fit_transform`. A common error is applying `fit_transform` to validation or test data instead of only `transform` — a mistake that leaks statistics from the test set into the scaler, artificially inflating performance metrics. This is testable: fit the scaler on training data, assert that the mean and variance used by the scaler match the training set statistics, and assert that those parameters do not change when `transform` is applied to the test set.

> [!info] As of 2026-Q2, scikit-learn's `Pipeline` and `ColumnTransformer` objects make it straightforward to test transformation chains end-to-end by constructing minimal fixture pipelines and asserting output shapes and statistics.

@feynman

A feature transformation test is asking: if I give this function the same input twice, do I always get the same output, and does the output have the properties it is supposed to have?

@card
id: tams-ch08-c006
order: 6
title: Testing the Trained Model Artifact
teaser: A saved model file is a software artifact like any other — and before deploying it, you should assert that it loads correctly, produces output of the right shape, and survives a serialization round-trip intact.

@explanation

The trained model artifact — a `.pkl` file from scikit-learn, a `.pt` checkpoint from PyTorch, or a logged artifact in MLflow — is the output of your training pipeline. It should be tested with the same rigor as any other deployable artifact.

**Input/output shape assertion.** Given a batch of inputs with the correct feature dimensionality, the model should produce an output tensor or array of the expected shape. This catches the most common deployment mismatch: a model trained on 128 features being deployed to a serving environment that sends 127.

```python
def test_model_output_shape(trained_model, sample_batch):
    output = trained_model.predict(sample_batch)
    assert output.shape == (len(sample_batch),), f"Expected ({len(sample_batch)},), got {output.shape}"
```

**Serialization round-trip.** Save the model to disk (or to an MLflow artifact store), reload it, and assert that predictions on a fixed sample are identical before and after. A model that survives a round-trip without silent weight corruption is ready for deployment. A model that does not will produce wrong predictions in production with no error message.

**Output domain assertion.** A classifier's `predict_proba` output should sum to 1.0 per sample (within floating-point tolerance) and contain no negative values. A regression model's output should fall within the physically meaningful range for the target variable. These checks cost one line of pytest and catch numerical instability that would otherwise be invisible.

**Metadata consistency.** An MLflow-logged model carries metadata: the training data version, the hyperparameters, the evaluation metrics. Assert that the metadata accompanying the artifact matches the values recorded during training — this catches cases where a model file has been overwritten by a different training run.

@feynman

Testing a trained model artifact is like testing a built binary — you are not re-running the build, you are confirming that what came out is the right shape, loads correctly, and behaves consistently.

@card
id: tams-ch08-c007
order: 7
title: Integration Testing the Full Pipeline
teaser: Integration testing an ML pipeline means running the entire data-to-prediction path end-to-end with realistic but small data — and asserting that the seams between stages compose correctly.

@explanation

A unit test verifies that each pipeline stage works in isolation. An integration test verifies that they work together. In ML, the integration test is the full pipeline run: load data, transform features, train (or load) the model, and produce predictions — with assertions at the output.

The key design constraint is using realistic but small data. "Realistic" means the fixture dataset has the same schema, column types, value distributions, and edge cases as real production data. "Small" means it runs in seconds, not hours. A 500-row fixture dataset that covers the schema corner cases is more valuable than a 5-million-row sample that takes 40 minutes to process.

What integration tests catch that unit tests miss:

- **Column name mismatches at stage boundaries.** A feature transformer that outputs `user_age_scaled` being consumed by a downstream stage that expects `age_scaled` will not be caught by testing either stage in isolation.
- **Shape mismatches between stages.** A transformer that drops a column for certain input patterns will produce a shape that the model was not trained on.
- **Stale artifact composition.** A model trained against one version of the feature schema being integrated with a pipeline that has since added or removed columns.

With DVC, pipeline stage outputs are versioned and cached. An integration test can be expressed as a DVC pipeline run on a fixture dataset tracked in the repository, with pytest assertions on the final artifact. This also makes the integration test reproducible: any team member running `dvc repro` on the fixture data gets the same result.

> [!tip] Treat the integration test dataset as a first-class artifact, tracked in DVC or your artifact store. A fixture dataset that is stored only locally becomes a team liability when the person who created it leaves.

@feynman

Pipeline integration testing is running the whole assembly line with a small batch of test parts to confirm every handoff works before you run the full production volume.

@card
id: tams-ch08-c008
order: 8
title: Smoke Tests for ML Systems
teaser: A smoke test for an ML system asks one question — does the model produce any output at all on a basic input — and it is the first test that should run after every deployment, in every environment.

@explanation

The smoke test is the simplest meaningful test in an ML system: given a well-formed input, does the model return a prediction without raising an exception? It is not testing for correctness, distribution, or business performance — it is testing that the model is reachable, loaded, and minimally functional.

In an ML context, smoke tests commonly verify:

- The model endpoint returns HTTP 200 (or the in-process function returns without exception) for a hardcoded valid input.
- The output is not null, not NaN, and not an empty array.
- The output has the expected type and shape (e.g., a probability in `[0.0, 1.0]`, not a raw logit).
- Latency is within an order of magnitude of expectation — a model that takes 60 seconds to respond on a single input has a deployment problem, not a performance optimization opportunity.

```python
def test_model_smoke(deployed_model):
    sample_input = SMOKE_TEST_FIXTURE  # hardcoded, checked into the repo
    result = deployed_model.predict(sample_input)
    assert result is not None
    assert not np.isnan(result).any()
    assert result.shape == (1,)
```

Smoke tests should run:

- After every CI build that produces a new model artifact.
- After every deployment to staging or production.
- As a scheduled health check (every 5–15 minutes) in production.

They are not a substitute for deeper functional testing, but they are the fastest signal that something is fundamentally broken — a signal worth having before the monitoring system catches a wave of prediction errors in production traffic.

> [!info] As of 2026-Q2, MLflow Model Serving and BentoML both support configuring health check endpoints that correspond directly to smoke test semantics, making it straightforward to wire smoke tests into deployment pipelines.

@feynman

A smoke test for an ML model is asking the simplest possible question — is anyone home — before asking whether the answer is correct.

@card
id: tams-ch08-c009
order: 9
title: Acceptance Tests for ML Systems
teaser: An ML acceptance test is an agreed metric threshold on a held-out evaluation set — and the threshold, the dataset, and the metric must all be specified before training begins, not after.

@explanation

In classical software, an acceptance test verifies that the system meets specified functional requirements. In ML, the equivalent is a metric acceptance test: the model must achieve at least a specified performance level on a held-out dataset before it is considered acceptable for deployment.

The three elements that must be pinned before training:

**The evaluation dataset.** A fixed, versioned held-out set that is never used for training or validation. In DVC, this is a tracked artifact. In MLflow, it can be logged as part of the experiment. "The test set" is not acceptable if its composition can change between evaluations.

**The metric.** Not accuracy by default — the metric appropriate for the task and the error costs. F1 score, AUC-ROC, mean absolute error, precision at fixed recall, or a custom business metric. The ISTQB® CT-AI v1.0 syllabus emphasizes that metric selection is a stakeholder decision, not a technical one, and must be agreed with the business before the model is trained.

**The threshold.** The minimum acceptable value. This is also a stakeholder decision, informed by the baseline performance of the current system (or human performance), the cost of errors, and the regulatory context. A threshold set after seeing the model's score is not an acceptance criterion — it is rationalization.

In practice, the acceptance test in pytest looks like:

```python
def test_model_acceptance_metrics(trained_model, held_out_dataset):
    y_true, y_pred = evaluate(trained_model, held_out_dataset)
    f1 = f1_score(y_true, y_pred)
    assert f1 >= ACCEPTANCE_THRESHOLD, f"F1 {f1:.4f} below threshold {ACCEPTANCE_THRESHOLD}"
```

This assertion is a gate in CI: the model artifact is not promoted to staging unless it passes.

> [!warning] Acceptance thresholds that are set after training are not acceptance criteria. Lock the metric and the threshold in a configuration file before the first training run, and treat any post-hoc change as a requirements change requiring stakeholder sign-off.

@feynman

An ML acceptance test is a signed contract about what "good enough" means — written before you see the results, not after.

@card
id: tams-ch08-c010
order: 10
title: Deterministic vs Probabilistic Testing
teaser: Some ML behaviors can be asserted exactly; others can only be asserted statistically — and confusing the two leads either to flaky tests that fail randomly or to gaps where real regressions go undetected.

@explanation

Classical software testing is built on determinism: given the same inputs, assert the same output. ML testing must operate in two modes depending on what is being tested.

**Deterministic assertions** are appropriate for:

- Data loading and transformation code (pure functions, no randomness).
- Model output shape and type given a fixed input.
- Serialization round-trips (same weights in, same weights out).
- Behavior under a fixed random seed (training reproducibility).
- Preprocessing pipeline outputs (given the same input dataframe, assert the same output dataframe).

These tests should be written as standard pytest assertions with exact equality or tight tolerances.

**Statistical assertions** are appropriate for:

- Whether a model's performance metric on a test set is above a threshold (the metric itself has sampling variance).
- Whether a distribution of model outputs on a sample of inputs matches an expected distribution.
- Whether a new model is meaningfully better than a baseline, or whether observed differences are within chance variation.

For statistical assertions, the test predicate is not `==` or `>=` in isolation — it is a hypothesis test or a confidence interval. A model achieving F1 of 0.82 on 50 test examples is not reliably better than a model achieving 0.80 on the same set. Statistical significance must be established before claiming a regression or an improvement.

In practice, this means using tools like `scipy.stats` to compute confidence intervals around metric estimates, and treating a statistically significant degradation as a test failure rather than a point-estimate degradation.

The common failure mode is applying exact assertions to probabilistic outputs: a test that asserts `model.predict(x) == 0.743` will fail when the model is retrained with slightly different data, even if the model is better. Fix this by separating the deterministic layer (pipeline code) from the statistical layer (model evaluation).

@feynman

Deterministic ML tests assert what must always be exactly true; statistical ML tests assert what is true with enough confidence to act on — and the difference matters because mixing them up produces either tests that lie or tests that break for no reason.

@card
id: tams-ch08-c011
order: 11
title: Statistical Assertions in ML Tests
teaser: A statistical assertion uses a confidence interval or hypothesis test as the test predicate — replacing the binary pass/fail of exact assertions with a statistically grounded decision about whether observed behavior is within expected bounds.

@explanation

Statistical assertions treat metric values as estimates with uncertainty, not as ground truth. They are the correct tool whenever the quantity being tested has sampling variability — which includes virtually all model evaluation metrics computed on a finite test set.

**Confidence interval approach.** Compute the metric on the test set along with a bootstrap or closed-form confidence interval. Assert that the lower bound of the interval exceeds the acceptance threshold. This prevents a test from passing when the metric estimate happens to be high due to lucky test set composition.

```python
from scipy.stats import bootstrap
import numpy as np

def test_f1_with_confidence_interval(trained_model, held_out_dataset):
    y_true, y_pred = evaluate(trained_model, held_out_dataset)
    scores = np.array([f1_score(y_true[idx], y_pred[idx])
                       for idx in bootstrap_indices(len(y_true), n=1000)])
    lower_bound = np.percentile(scores, 2.5)  # 95% CI lower bound
    assert lower_bound >= ACCEPTANCE_THRESHOLD
```

**Hypothesis test approach.** When comparing two models (current vs challenger), use a paired test (McNemar's test for classification, Wilcoxon signed-rank test for regression) to determine whether observed metric differences are statistically significant before concluding a regression or improvement.

**Distribution tests.** For monitoring model behavior over time, tools like the Kolmogorov-Smirnov test or Population Stability Index (PSI) can assert that the distribution of model outputs on recent data has not shifted significantly from the distribution observed during validation. A PSI above 0.2 is conventionally treated as a significant distribution shift requiring investigation.

The tradeoff is complexity: statistical assertions require more code, more thought about sample sizes, and more careful interpretation than exact assertions. Reserve them for the model evaluation layer; the pipeline data tests should remain deterministic.

> [!info] As of 2026-Q2, the Evidently library provides pre-built statistical drift and performance degradation tests that can be embedded directly in pytest or CI pipelines without requiring manual implementation of hypothesis tests.

@feynman

A statistical assertion in a test is replacing "is the answer exactly right?" with "is the answer right enough, with enough confidence to bet on it?" — which is the appropriate question when the answer has inherent uncertainty.

@card
id: tams-ch08-c012
order: 12
title: Reproducible ML Test Environments
teaser: An ML test that produces different results on different runs, on different machines, or at different times is not a test — it is a source of noise; reproducibility requires fixed seeds, pinned dependencies, and versioned data.

@explanation

Reproducibility in ML testing has three independent requirements, each of which must be satisfied for a test result to be trustworthy.

**Fixed random seeds.** ML training, data shuffling, train/test splitting, and many evaluation procedures are stochastic. A test that does not fix the random seed will produce different results on different runs, making it impossible to distinguish a real regression from sampling variance. In practice:

```python
import numpy as np
import torch
import random

def set_global_seed(seed: int = 42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
```

Call this at the top of every training and evaluation test fixture. Note that GPU operations in PyTorch require additional steps (`torch.use_deterministic_algorithms(True)`) and may carry a performance cost.

**Pinned dependencies.** A model trained with scikit-learn 1.3 and evaluated with scikit-learn 1.4 may produce different numeric results due to algorithm changes between versions. Pin all ML framework versions in a `requirements.txt` or `pyproject.toml` and commit that file to the repository. DVC pipelines support environment locking as part of the pipeline definition.

**Versioned data.** The test dataset must be a versioned artifact, not a query against a live database. A test that queries the training database to build its fixture will produce different fixtures as the database changes, making test results non-comparable over time. DVC tracks dataset versions as content-addressed artifacts; MLflow logs dataset metadata alongside experiment results.

The consequence of not satisfying all three: CI failures that are unrelated to code changes, model metrics that drift without explanation, and debugging sessions that cannot be reproduced by a second engineer.

> [!warning] "It passed on my machine" is the most common symptom of a non-reproducible ML test environment. If a test cannot be reproduced by running `git checkout <sha> && dvc repro`, it is not a reliable test.

@feynman

A reproducible ML test environment is the foundation that makes every other test meaningful — without fixed seeds, pinned dependencies, and versioned data, a passing test tells you nothing about whether the code is correct.
