@chapter
id: tams-ch03-machine-learning-a-testers-perspective
order: 3
title: Machine Learning — A Tester's Perspective
summary: The ML lifecycle is a sequence of testable artifacts — data, features, model, deployment, monitoring — and a tester's job is to know which controls operate at each stage and where the leverage is.

@card
id: tams-ch03-c001
order: 1
title: The Five-Stage ML Lifecycle
teaser: Every ML system passes through the same five stages — data, training, evaluation, deployment, monitoring — and each stage produces artifacts a tester can inspect, challenge, and gate.

@explanation

Most software testing asks: "Does the code do what the spec says?" ML testing asks a harder question: "Does the learned behavior do what the data implied it should?" That shift in framing changes everything about where you apply controls.

The five stages, and what a tester sees at each:

- **Data collection and labeling.** The inputs that shape everything downstream. Testable artifacts: raw datasets, label distributions, annotation guidelines, inter-annotator agreement scores.
- **Feature engineering.** The transformation of raw data into model inputs. Testable artifacts: feature pipelines, schema contracts, unit tests on individual transformations.
- **Training.** The optimization loop that adjusts model weights. Testable artifacts: loss curves, gradient checks, reproducibility logs, hyperparameter configurations.
- **Evaluation.** The measurement of model quality against held-out data. Testable artifacts: evaluation scripts, metric definitions, confusion matrices, benchmark comparisons.
- **Deployment and monitoring.** The live system serving predictions. Testable artifacts: model artifacts, serving infrastructure, prediction logs, drift alerts.

The leverage is not evenly distributed. Defects introduced in the data stage are the most expensive — they propagate silently through training and evaluation and only surface in production. Defects introduced at deployment are visible but often urgent. Testers who understand the lifecycle invest most of their effort upstream, where changes are cheap.

> [!info] As of 2026-Q2, tools like MLflow and DVC have made lifecycle tracking standard practice at mature ML teams, but many organizations still treat each stage as an isolated handoff rather than a connected audit trail.

@feynman

The ML lifecycle is an assembly line where the raw material is data, and a flaw in the ore contaminates every part made from it.

@card
id: tams-ch03-c002
order: 2
title: Data Collection and Labeling
teaser: The quality of a model's labels sets a ceiling on model quality that no training algorithm can break through — and annotation errors are harder to find than code bugs because they hide in plain sight as plausible-looking data.

@explanation

A label is a human judgment recorded as a number or category. Every label carries the risk of error: the annotator misread the instruction, the instruction was ambiguous, or the task is genuinely hard. That risk compounds across millions of examples.

Sources of labeling error:

- **Ambiguous guidelines.** If two annotators reading the same guideline would produce different labels, the model receives conflicting signal. The fix is clarifying the guideline before labeling, not after.
- **Label noise.** Systematic errors from a single annotator (one person who consistently miscategorizes edge cases) are more dangerous than random noise because they look like a valid pattern to the model.
- **Proxy labels.** When the true label is unobservable (e.g., "user intent"), teams substitute a measurable proxy (e.g., "user clicked"). The model learns the proxy, not the intent.

What good labels look like:

- **High inter-annotator agreement (IAA).** Cohen's kappa above 0.8 is a common bar for categorical tasks. Kappa below 0.6 signals that the task definition needs rework before more data is collected.
- **Documented disagreement resolution.** When annotators disagree, the resolution process (majority vote, expert review, adjudication) should be recorded, not silently applied.
- **Label distribution audits.** If 98% of examples are class A and 2% are class B, the model will learn to predict A almost always. A tester should flag severe imbalances before training.

> [!warning] Low inter-annotator agreement is not a data problem — it is a specification problem. Sending ambiguous tasks back to annotators produces more noise, not less. Fix the guideline first.

@feynman

Labeling data is like instructing a jury — if the instructions are vague, twelve reasonable people will reach twelve different verdicts, and the verdict recorded is not truth but noise.

@card
id: tams-ch03-c003
order: 3
title: Feature Engineering
teaser: Features are a programmer's choice, not a fact of nature — and a poorly chosen feature can silently teach a model to cheat by encoding information the model should not have access to at inference time.

@explanation

Raw data almost never goes directly into a model. Feature engineering transforms it: scaling numbers, encoding categories, extracting signal from text, aggregating time series. Every transformation is a decision about what information to present to the learner.

Common feature engineering mistakes:

- **Irrelevant features.** Adding features that have no causal relationship to the target introduces noise and increases overfitting risk. More features is not always better.
- **Feature leakage (see dedicated card).** Including information in a feature that would not be available at prediction time. This is the most dangerous error because it inflates evaluation metrics while producing a model that fails in production.
- **Unbounded or unnormalized numeric features.** A model trained on income values ranging 20,000–200,000 will behave unpredictably when it sees 2,000,000 during deployment. Normalization or clipping is a testable contract between the pipeline and the model.
- **Schema drift.** The feature pipeline produces a column named `user_age_days` today and `user_age` tomorrow. Without schema validation, the model silently receives the wrong input.

Testing feature pipelines with scikit-learn and similar tools:

- Write unit tests for individual transformers: given a known input, assert the expected output.
- Test edge cases: empty strings, nulls, extreme values, unseen categories.
- Version your feature schemas and assert on column names and dtypes at pipeline entry and exit.

> [!tip] Treat a feature pipeline as production software: schema contracts, unit tests, and versioning are not optional once the pipeline feeds a model that affects users.

@feynman

A feature is a question you choose to ask the data — and if you ask the wrong question, or a question you wouldn't be able to ask in production, the model learns to answer a question that doesn't exist in the real world.

@card
id: tams-ch03-c004
order: 4
title: Train / Validation / Test Split
teaser: Splitting your data into three non-overlapping sets is the foundational discipline of model evaluation — the test set is sacred, and touching it before final evaluation breaks the only unbiased estimate you have.

@explanation

The purpose of splitting data is to evaluate how the model performs on examples it has never seen. This simulates the deployment condition, where the model will always be answering questions it was not explicitly trained on.

The canonical splits:

- **Training set** (typically 70–80%). The examples the model learns from. Gradient updates, weight adjustment, and pattern extraction all happen here.
- **Validation set** (typically 10–15%). Used during training to tune hyperparameters and decide when to stop training (early stopping). The model never trains directly on these examples, but the engineer does — they make decisions based on validation metrics, which introduces indirect information leakage.
- **Test set** (typically 10–15%). Used exactly once, after all development decisions are finalized, to report the final model performance. Any decision made based on test set metrics (including "this model is better than the last one") invalidates the test set as an unbiased estimate.

The alternative — cross-validation — partitions the training data into k folds, trains k models each leaving one fold out, and averages performance across folds. scikit-learn's `KFold`, `StratifiedKFold`, and `TimeSeriesSplit` implement common variants. Cross-validation produces more stable estimates from smaller datasets but is computationally expensive and is not a replacement for a held-out test set.

One critical constraint: **splits must respect data structure.** If your data contains multiple rows from the same user, those rows must stay together in a single split. Splitting by row while mixing the same user across train and test is a form of data leakage.

> [!warning] The test set is a one-time-use scientific instrument. Every time you peek at test metrics and adjust your model, you are using the test set as a second validation set and your reported performance is optimistic.

@feynman

The test set is the final exam — you can study as much as you want using practice problems, but the moment you study from the actual exam paper, your grade no longer measures what you learned.

@card
id: tams-ch03-c005
order: 5
title: Data Leakage
teaser: Data leakage occurs when information from outside the training window contaminates model inputs — it is the most common cause of models that look excellent in evaluation and fail immediately in production.

@explanation

Leakage is silent: it inflates your evaluation metrics by allowing the model to access information it would not have at inference time. The model learns a shortcut, the shortcut is tested on similar data, the metrics look great, and the shortcut is unavailable when the model goes live.

Two main forms:

**Target leakage.** A feature encodes the label, directly or indirectly. Example: predicting hospital readmission and including "discharge medications" as a feature — this is only documented after the readmission decision has been made. The model learns to read the future because the training data was assembled retrospectively.

**Train-test contamination.** Test examples are used, directly or indirectly, to make decisions during training. Common causes:
- Normalizing the entire dataset (train + test) and then splitting. The test set's mean and standard deviation influence the training normalization.
- Performing feature selection on the full dataset before splitting. The selected features are chosen partly because they correlate with the test set labels.
- Deduplication after splitting, which may remove test examples that are very similar to training examples but also removes training examples that are very similar to test examples.

How to detect leakage:

- Suspiciously high accuracy on evaluation (near-perfect on a hard task is a red flag, not a green one).
- A feature that correlates more strongly with the label than prior knowledge would suggest it should.
- Model performance degrades sharply when evaluated on data from a different time period than the training data.

The fix is procedural: apply all preprocessing steps (normalization, imputation, feature selection) only to the training split, then apply the learned parameters to the validation and test splits without refitting.

> [!warning] Any preprocessing step that "looks at" the test set before it is evaluated is a form of leakage. Fit on train, transform on test — never fit on both.

@feynman

Data leakage is like a student who memorizes the answer key — their test score looks perfect, but they learned nothing that transfers to a new exam.

@card
id: tams-ch03-c006
order: 6
title: Testing Inside the Training Pipeline
teaser: Training is not a black box — gradient checks, loss curve inspection, and early stopping are testable behaviors that surface training bugs before they become deployed model bugs.

@explanation

Most testers treat training as opaque: data goes in, a model comes out. That framing misses a class of bugs that only manifest during the learning process and are invisible once training ends.

Testable behaviors inside training:

**Gradient checks.** A numerical gradient check (perturbing each weight and measuring the change in loss) verifies that the analytical gradient your framework computes matches the actual mathematical gradient. PyTorch's `torch.autograd.gradcheck` implements this. A failing gradient check means the model is not learning what you think it is — typically a custom loss function or layer has an incorrect derivative.

**Loss curve inspection.** Training loss should decrease monotonically (with noise). Validation loss should decrease initially, then plateau or rise as the model overfits. A validation loss that never decreases indicates the model is not learning from the training data at all — typically a data pipeline bug, not a model architecture bug.

**Overfitting a single batch.** Before running a full training job, verify that the model can achieve near-zero loss on a single batch. If a model cannot overfit 32 examples, there is a fundamental bug in the forward pass, the loss computation, or the optimizer configuration.

**Early stopping.** A mechanism that halts training when validation loss stops improving for a configurable number of steps (patience). This is both a training technique and a testable guard: the stopping criterion should be verified to activate correctly under conditions that simulate overfitting.

In TensorFlow and PyTorch, training callbacks expose hooks for each of these checks. MLflow allows logging of loss curves and hyperparameters as experiment artifacts that can be compared across runs.

> [!tip] "Overfit a single batch first" is the fastest debugging technique in ML. If the model cannot memorize 32 examples, no amount of data will fix the underlying bug.

@feynman

Testing a training pipeline is like checking that a furnace can get hot before loading it with ore — if it cannot produce heat on demand, more fuel will not solve the problem.

@card
id: tams-ch03-c007
order: 7
title: Evaluation Methodology
teaser: A single accuracy number hides almost everything a tester needs to know — the distribution of errors, the cost of different error types, and whether the model works at all for underrepresented subpopulations.

@explanation

Accuracy measures the fraction of correct predictions. For a dataset where 95% of examples are class A, a model that always predicts A achieves 95% accuracy and is completely useless. Any evaluation methodology that reports only accuracy on an imbalanced dataset is misleading.

Metrics that reveal what accuracy conceals:

- **Precision and recall.** Precision answers "when the model predicted positive, how often was it right?" Recall answers "of all true positives, how many did the model find?" These have a tradeoff: optimizing precision suppresses false positives; optimizing recall suppresses false negatives. The right balance depends on the cost of each error type.
- **F1 score.** Harmonic mean of precision and recall. Useful as a single number when both matter equally.
- **Confusion matrix.** For multi-class problems, shows the full distribution of correct and incorrect predictions across all class pairs. Errors often cluster in specific class pairs, revealing systematic model weaknesses.
- **ROC curve and AUC.** For binary classifiers that output probability scores, measures performance across all possible decision thresholds. An AUC of 1.0 means perfect separation; 0.5 means random.
- **Sliced evaluation.** Measuring performance separately for each subpopulation (by demographic, device type, input length, etc.). A model with 90% overall accuracy that has 60% accuracy on a specific user segment has a serious problem that aggregate metrics hide.

The evaluation methodology — which metrics, which dataset, which slices — should be defined before training begins, not chosen after seeing results.

> [!warning] Choosing evaluation metrics after seeing results is p-hacking for ML. Define your success criteria before you look at the numbers.

@feynman

Reporting only accuracy on an ML model is like reporting only the average grade on an exam — you have learned nothing about whether any student understood any specific topic.

@card
id: tams-ch03-c008
order: 8
title: Hyperparameter Tuning
teaser: Hyperparameter tuning is necessary, but it creates a meta-overfitting risk — the more you tune on the validation set, the more the validation set's quirks are baked into the final model.

@explanation

Hyperparameters are configuration choices that are not learned from data: learning rate, number of layers, regularization strength, batch size, dropout rate. They control how a model learns, rather than what it learns.

Common search strategies:

- **Grid search.** Evaluates every combination of a predefined hyperparameter grid. Exhaustive and easy to reason about, but the number of evaluations grows exponentially with the number of hyperparameters. scikit-learn's `GridSearchCV` implements this.
- **Random search.** Samples hyperparameter combinations randomly. Counterintuitively, random search finds good configurations faster than grid search when only a few hyperparameters matter significantly — because it explores more distinct values for each dimension. scikit-learn's `RandomizedSearchCV` implements this.
- **Bayesian optimization.** Builds a probabilistic model of the hyperparameter-to-validation-loss relationship and uses it to propose the next configuration to evaluate. More efficient than random search for expensive training runs. Tools include Optuna (as of 2026-Q2, widely used for deep learning workflows).

The meta-overfitting risk: every tuning iteration uses the validation set as feedback. After enough iterations, the chosen hyperparameters are partially overfit to the validation set's specific characteristics. This is why the test set must remain untouched during tuning — the validation set absorbs the overfitting pressure, and the test set provides the final unbiased estimate.

Mitigations:
- Use k-fold cross-validation for hyperparameter search rather than a single validation split.
- Limit the number of tuning iterations to what computational budget and the dataset size justify.
- Report the tuning budget (number of configurations evaluated) alongside final metrics.

> [!info] As of 2026-Q2, automated hyperparameter optimization is increasingly bundled into ML platforms, which can obscure the meta-overfitting risk if engineers treat the reported validation metrics as ground truth.

@feynman

Tuning hyperparameters against a validation set is like adjusting a recipe each time you taste it — at some point you are not cooking better food, you are cooking food that tastes good to this specific taster in this specific mood.

@card
id: tams-ch03-c009
order: 9
title: Model Serialization and Deployment
teaser: A trained model is an artifact that must be serialized, versioned, and tested as rigorously as application code — the serialization format you choose determines portability, security risk, and what you can inspect.

@explanation

When training ends, the model's learned parameters are written to disk. How they are written determines what can be done with them and what risks they carry.

Common serialization formats:

- **pickle / joblib.** Python-specific. scikit-learn models are typically serialized this way. Fast and convenient, but insecure: loading an untrusted pickle file executes arbitrary code. Never load a pickled model from an untrusted source.
- **ONNX (Open Neural Network Exchange).** Framework-neutral binary format. A PyTorch model exported to ONNX can be loaded and served by ONNX Runtime without a PyTorch installation. Enables deployment environments that differ from the training environment. Testable: the ONNX graph can be validated and the outputs compared against the original framework to detect export bugs.
- **TorchScript.** Compiles a PyTorch model to an intermediate representation that can be loaded without Python. Used for mobile and embedded deployment. Export bugs (where the TorchScript model produces different outputs than the original) are a known failure mode and must be caught by output comparison tests.
- **SavedModel (TensorFlow).** TensorFlow's native serialization. Bundles model architecture, weights, and preprocessing into a single directory. Supports serving via TensorFlow Serving.

Testing the serialized artifact:

- Load the artifact in the target serving environment and compare outputs against training-environment outputs on a fixed set of inputs. Numerical differences above a tolerance threshold are a bug, not an acceptable consequence of serialization.
- Verify that the model artifact is versioned and that the version is logged alongside all evaluation metrics in MLflow or an equivalent experiment tracker.
- Test model loading under memory and latency constraints representative of the production serving environment.

> [!warning] Pickle-based models are code execution vulnerabilities. Treat a `.pkl` file in a production artifact store as you would a binary from an untrusted source — verify its provenance before loading.

@feynman

Serializing a model is like printing a recipe — the printed version must produce the same dish as the original, and you should test it before you hand it to the kitchen.

@card
id: tams-ch03-c010
order: 10
title: Production Monitoring and Drift Detection
teaser: A model that was accurate on the day it shipped becomes less accurate over time as the world changes around it — and without monitoring, that decay is invisible until users start complaining.

@explanation

Models are trained on historical data. Production data is generated in a present that increasingly diverges from that history. This divergence — drift — is not a bug in the model, it is an inevitable property of the relationship between a static artifact and a changing world.

Two primary drift types:

- **Data drift (covariate shift).** The distribution of model inputs changes. Example: a fraud detection model trained on 2023 transaction patterns receives 2025 transaction patterns with new payment methods and new fraud patterns. The model was never trained to recognize them.
- **Concept drift.** The relationship between inputs and labels changes. Example: a sentiment classifier trained on pre-pandemic restaurant reviews encounters post-pandemic reviews where the language and reference points for "good" and "bad" experiences have shifted.

What to monitor in production:

- **Prediction distribution.** Log the distribution of model outputs over time. A sudden shift in the fraction of high-confidence positive predictions is an early signal that input distribution has changed.
- **Input feature distributions.** Compare the statistical distribution of each feature against the training distribution. Population Stability Index (PSI) is a common metric; a PSI above 0.2 conventionally signals significant drift.
- **Ground truth labels (where available).** For applications where labels are eventually observed (e.g., loan default 90 days after origination), compare the model's predicted probabilities against the realized outcomes. This is the most reliable signal of model degradation.

As of 2026-Q2, tools such as Evidently AI, WhyLabs, and Arize provide production monitoring pipelines that automate distribution comparison and alerting. MLflow's model registry supports tagging models as "staging," "production," or "archived," providing a lifecycle management framework alongside experiment tracking.

> [!info] Models do not fail — they degrade. A degrading model produces no errors, no exceptions, and no alerts unless monitoring is explicitly built to detect it.

@feynman

A deployed model without monitoring is like a navigation system that was programmed once and never updated — it still gives confident directions, but it is increasingly directing you down roads that no longer exist.

@card
id: tams-ch03-c011
order: 11
title: A/B Testing for ML Models
teaser: Replacing one model with another in production is a hypothesis — and A/B testing is the discipline of testing that hypothesis under real traffic before committing to the change.

@explanation

Offline evaluation (metrics on a held-out test set) answers "which model is better on historical data?" A/B testing answers the harder question: "which model produces better outcomes for real users under real conditions?" These questions often have different answers.

Mechanics of ML A/B testing:

- **Traffic split.** A fraction of users (the treatment group) receives predictions from model B; the remainder (the control group) continues receiving predictions from model A. Assignment must be deterministic and stable: the same user should always see the same model during the experiment.
- **Metric selection.** Define the primary metric (the one decision will be based on) before the experiment begins. Business metrics (conversion rate, churn rate, error rate) are preferable to model metrics (accuracy, AUC) because they measure the actual impact on users.
- **Statistical power.** The minimum sample size needed to detect a given effect size at a given significance level. Running an underpowered experiment (too few users, too short a duration) produces results that are indistinguishable from noise. Power calculators require specifying the minimum detectable effect (MDE) — the smallest improvement that would be meaningful to act on.
- **Duration.** Experiments must run long enough to capture weekly seasonality and to reach the target sample size. Stopping early when results look promising (peeking) inflates false positive rates.

Common mistakes:

- Measuring only online proxy metrics (click-through rate) and not downstream business outcomes (purchase completion).
- Failing to account for novelty effects: users may engage differently with a new experience simply because it is new, not because it is better.
- Running too many simultaneous A/B tests that interact with each other in unmeasured ways.

> [!tip] Define the MDE before you design the experiment. "We want to detect a 1% improvement in conversion" requires a very different sample size than "we want to detect a 10% improvement."

@feynman

A/B testing a model is like running a controlled clinical trial — you cannot know whether the treatment works by looking at patients who chose it themselves; you have to randomly assign treatment and control to measure the true effect.

@card
id: tams-ch03-c012
order: 12
title: Reproducibility in ML
teaser: An ML experiment that cannot be reproduced is not a result — it is an anecdote, and building production systems on anecdotes is how teams end up with models they cannot retrain, debug, or improve.

@explanation

Reproducibility means that given the same code, data, and configuration, two training runs produce the same model. In practice, complete bit-for-bit reproducibility is difficult to achieve in distributed training, but functional reproducibility — where two models trained from the same checkpoint produce indistinguishable predictions — is an achievable and necessary standard.

Sources of irreproducibility:

- **Random seeds not fixed.** Weight initialization, data shuffling, and dropout are stochastic operations. Without fixing random seeds, results vary across runs. PyTorch requires setting `torch.manual_seed`, `torch.cuda.manual_seed_all`, and `numpy.random.seed` as well as `PYTHONHASHSEED` in the environment. TensorFlow uses `tf.random.set_seed`.
- **Floating-point nondeterminism.** GPU operations are not guaranteed to be deterministic due to parallel reduction order. PyTorch's `torch.use_deterministic_algorithms(True)` enables deterministic mode at the cost of some performance.
- **Unversioned dependencies.** A model trained with scikit-learn 1.3 may produce different results with scikit-learn 1.5 due to changes in algorithm implementations. Pinning dependency versions in `requirements.txt` or a `conda` environment file is not optional for reproducible ML.
- **Unversioned data.** If the training dataset is modified between runs, results are not comparable. DVC (Data Version Control) tracks datasets and their associated model experiments together, ensuring that a given model version is permanently linked to the exact data version that produced it.

MLflow addresses code and configuration: it logs the git commit hash, the full hyperparameter set, and the trained artifact together, so any historical run can be reconstructed. DVC extends this to data versioning, linking dataset snapshots to experiments in a way that survives dataset mutations.

As of 2026-Q2, the combination of MLflow for experiment tracking and DVC for data versioning represents the practical baseline for reproducibility in production ML teams.

> [!tip] Log the git commit hash, all random seeds, the full dependency manifest, and a hash of the training dataset as part of every training run. This costs seconds and makes debugging weeks faster.

@feynman

Reproducibility in ML is the scientific method applied to software — a result you cannot reproduce is a result you cannot trust, and a model you cannot retrain from scratch is infrastructure you do not actually control.
