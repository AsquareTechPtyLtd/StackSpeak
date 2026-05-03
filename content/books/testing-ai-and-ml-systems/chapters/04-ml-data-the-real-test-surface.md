@chapter
id: tams-ch04-ml-data-the-real-test-surface
order: 4
title: ML Data: The Real Test Surface
summary: In ML systems, data IS the test surface — quality, distribution, balance, privacy, leakage, and labels are where most production bugs originate, and where the tester has the most leverage.

@card
id: tams-ch04-c001
order: 1
title: Data Is the Test Surface
teaser: In traditional software, bugs live in code; in ML systems, most bugs live in data — the training set is the program, and testing it is the tester's primary job.

@explanation

A conventional software bug is a logic error in code: fix the code, the bug is gone. An ML system externalizes its logic into data. The model learns decision boundaries, patterns, and heuristics from examples — which means the data is where most of the defects actually live.

The practical implication for testers is a shift in focus:

- **Code review is not enough.** A syntactically and logically correct training pipeline can still produce a broken model if the data feeding it is wrong.
- **The test surface is the dataset.** Checking that the data pipeline runs without error is table stakes. Testing what it produces — its statistical properties, its label distribution, its coverage of real-world inputs — is where the real work is.
- **Data defects compound.** A 2% label error rate on 10 million examples is 200,000 wrong training signals. A small systematic bias in how samples were collected can become a large performance gap in a specific user segment.

Research consistently confirms this: a 2021 study by Sambasivan et al. ("Everyone wants to do the model work, not the data work") found that data quality issues, not modeling choices, were the dominant cause of AI system failures across five countries and many domains.

The tester's leverage is highest here. Catching a data issue before training is far cheaper than catching it after a model is deployed to production users.

> [!info] As of 2026-Q2, the field increasingly uses the term "data-centric AI" to describe the practice of systematically improving dataset quality rather than endlessly tuning model architecture.

@feynman

In ML, the training data is the source code — if it is wrong, no amount of correct pipeline code makes the model right.

@card
id: tams-ch04-c002
order: 2
title: Data Quality Dimensions
teaser: Data quality is not a single property — it is at least five distinct dimensions, each with its own failure mode and its own testing approach.

@explanation

Tools like Great Expectations formalize data quality checks around a set of dimensions. Testers need a mental model of what each dimension means in practice:

**Accuracy** — do the values in the dataset correctly reflect reality? An age column that contains dates instead of integers is an accuracy failure. A fraud label that was applied to a legitimate transaction is an accuracy failure.

**Completeness** — are there missing values where values are required? A text classification dataset missing 30% of its labels is incomplete. Incompleteness is not always noise — it can be systematic (e.g., a scraping failure that preferentially missed one geographic region).

**Consistency** — do values conform to expected formats and constraints, and are they internally consistent across related fields? A record with `signup_date > purchase_date` violates consistency. A categorical field with both `"male"` and `"Male"` as distinct values is a consistency failure.

**Freshness** — is the data recent enough to reflect current reality? A recommendation model trained on user behavior from 18 months ago may have learned patterns that no longer hold, especially in fast-moving domains like e-commerce or news.

**Relevance** — does the data actually cover the use cases the model will encounter in production? A model for detecting offensive language trained entirely on English text is not relevant to a multilingual deployment.

Each dimension requires separate test assertions. Great Expectations supports codifying these as executable expectations that run in CI against every new batch of training data.

@feynman

Data quality is like checking a shipment of parts before assembly — accuracy means the parts are the right parts, completeness means none are missing, consistency means they all fit the same spec, freshness means they haven't corroded, and relevance means they're for the product you're actually building.

@card
id: tams-ch04-c003
order: 3
title: Label Quality
teaser: Labels are the ground truth your model learns from — errors in labels are directly baked into the model's behavior, and they are the most under-tested part of most ML pipelines.

@explanation

Label quality failures are particularly dangerous because they are invisible to most standard monitoring. A model trained on noisy labels can achieve good aggregate metrics while making systematically wrong predictions on specific subgroups or edge cases.

The main sources of label error:

- **Ambiguous labeling instructions.** If two annotators reading the same instructions reach different conclusions about the same example, the instructions are underspecified. Agreement rate (inter-annotator agreement, or IAA) should be measured and reported.
- **Annotator drift.** Annotators apply criteria more loosely over time, especially on long labeling projects. Periodic re-annotation of a fixed gold standard set detects this.
- **Unclear edge cases.** Examples that fall on the boundary of two categories are the hardest to label consistently and contribute disproportionately to model errors.
- **Systematic annotator bias.** If one annotator handles all examples from a specific domain, their personal heuristics become embedded in the training data.

Tester responsibilities in labeling quality:

- Audit the labeling instructions before annotation begins. Vague instructions produce vague labels.
- Measure IAA on a sample. Cohen's Kappa above 0.7 is a common acceptance threshold for production annotation projects.
- Spot-check labels on a stratified random sample — not just a random sample. A 1% error rate distributed evenly is very different from a 10% error rate concentrated in one class.

@feynman

A label is the answer key for your model's exam — if the answer key is wrong, a perfect student will learn the wrong answers.

@card
id: tams-ch04-c004
order: 4
title: Class Imbalance
teaser: When 95% of your training examples belong to one class, a model that predicts that class for everything achieves 95% accuracy while being useless — class imbalance is a testing concern, not just a modeling concern.

@explanation

Class imbalance is the condition where the training distribution is dominated by one or more majority classes, with minority classes severely under-represented. It is endemic to real-world problems: fraud transactions, equipment failures, rare diseases, and adversarial inputs are all rare by definition.

The deceptive accuracy problem: a binary classifier trained on a dataset that is 95% negative achieves 95% accuracy by predicting "negative" for every input. Accuracy is not a useful metric here — you need precision, recall, F1, and ideally the area under the ROC or precision-recall curve.

Common mitigations, each with tradeoffs:

- **Oversampling (SMOTE, random)** — duplicate or synthetically generate minority class examples. Risk: the model can overfit to the oversampled minority distribution.
- **Undersampling** — remove majority class examples. Risk: you discard potentially useful training signal.
- **Class weighting** — assign higher loss weight to minority class errors. Simple to implement; preserves the full dataset. Often the first thing to try.
- **Augmentation** — generate new minority examples through transformations (image flips, text paraphrasing). Domain-specific and requires domain knowledge to do correctly.

Tester's role: measure the class distribution before training begins. Flag imbalance ratios above 10:1 for explicit mitigation. Require that evaluation reports include per-class metrics, not just aggregate accuracy.

> [!warning] Aggregate accuracy on an imbalanced test set is a misleading metric. Always require per-class precision, recall, and F1 in evaluation reports, and ensure the test set preserves the real-world class distribution.

@feynman

Class imbalance is like training a fraud detector mostly on legitimate transactions — it learns that "legitimate" is the safe answer and calls everything legitimate, which is technically good at the metric but catastrophic for the actual problem.

@card
id: tams-ch04-c005
order: 5
title: Distribution Shift
teaser: A model trained on last year's data may be evaluated accurately against last year's held-out test set and still fail in production — because the world changed, and the training distribution no longer matches what the model encounters.

@explanation

Distribution shift is the condition where the statistical properties of the data used in production differ from the data used for training. It is one of the most common causes of model degradation after deployment and one of the hardest to catch in pre-deployment testing.

Two principal types:

**Covariate shift** — the distribution of inputs `P(X)` changes, but the relationship between inputs and outputs `P(Y|X)` stays the same. Example: a spam classifier trained when "cryptocurrency" was rare will see the word much more frequently in production without the word becoming a more reliable spam signal.

**Concept drift** — the relationship `P(Y|X)` itself changes over time. Example: a loan default model trained before a recession may have learned that certain income levels predict low default risk — during the recession, that relationship breaks down. Concept drift cannot be fixed by collecting more data from the old distribution; it requires new data from the new regime.

Testing implications:

- Temporal splits for evaluation (train on months 1–10, test on months 11–12) detect covariate shift better than random splits.
- Monitoring input feature distributions at serving time and alerting when they deviate from training distributions is the primary production defense.
- Regular model refresh cycles are the only reliable mitigation for concept drift.

> [!info] As of 2026-Q2, production ML platforms increasingly include built-in distribution monitoring. Testing should verify that these monitors are configured, have alerting thresholds, and are actually connected to an on-call rotation.

@feynman

Distribution shift is training a self-driving car in summer and finding it struggles in winter — it learned from sunshine, and the world changed underneath it.

@card
id: tams-ch04-c006
order: 6
title: Train/Test Contamination
teaser: If any information from the test set leaks into the training set, your evaluation metrics are optimistic lies — and the model may fail badly on new data that the test set was supposed to represent.

@explanation

Train/test contamination (commonly called data leakage) occurs when examples from the evaluation set are also present in, or correlated with, the training set. It is a data pipeline defect, not a model defect — and it is surprisingly common in practice.

Common sources of leakage:

- **Duplicate records.** The same example appears in both splits because deduplication was not performed before splitting. This is frequent with web-scraped datasets.
- **Near-duplicates.** Records that differ only in whitespace, capitalization, or minor formatting pass a string-equality deduplication check but represent the same underlying example.
- **Temporal leakage.** A random split of time-series data allows future information to appear in the training set. An event on day 100 should never train a model that is evaluated on day 50.
- **Preprocessing leakage.** Normalization or feature scaling computed on the full dataset (including test) and then applied during training. The test statistics are baked into the training transform.
- **Target leakage.** A feature that is causally downstream of the label is included as a training feature — e.g., using the "fraud resolved" flag to predict fraud.

Detection: compute the overlap between training and test sets using exact hashes after normalization. For near-duplicate detection, MinHash or SimHash provides approximate membership testing at scale. For temporal leakage, verify that all training example timestamps precede the evaluation window.

@feynman

Data leakage is like giving students the exam answers during the practice test — their practice scores look great, but it tells you nothing about whether they can actually perform on a test they haven't seen.

@card
id: tams-ch04-c007
order: 7
title: Data Versioning
teaser: "I trained on the data" is not a reproducible statement — data versioning tools like DVC, lakeFS, and MLflow Datasets make training runs auditable and datasets first-class artifacts.

@explanation

Code versioning with git is standard practice. Data versioning is not — yet data changes are at least as likely to cause model behavior changes as code changes. Without versioning, you cannot reproduce a past training run, audit what data a model was trained on, or roll back after a bad data update.

The main tools and their approaches:

**DVC (Data Version Control)** — git-like versioning for large files and directories. Data is stored in a remote (S3, GCS, Azure Blob, etc.), and git tracks a `.dvc` pointer file. Reproducing a past experiment requires checking out the pointer file and pulling the data. Works well for file-system-oriented workflows.

**lakeFS** — a version control layer on top of object storage. Provides git-like branching, commits, and merging semantics at the lake level. Teams can create a branch of the data lake for an experiment without duplicating storage. Merging validated changes back to main follows the same review process as code.

**MLflow Datasets** — part of MLflow's experiment tracking. Attaches dataset metadata (source, hash, schema, version) to every training run, so each experiment record includes the exact data that produced it.

Testing responsibilities:

- Verify that every training run records the dataset version it consumed.
- Verify that the data version in the model card matches the data version in the experiment log.
- Test rollback: given a previous model version's experiment ID, can you reproduce the training data exactly?

@feynman

Data versioning is like version control for your training ingredients — without it, you cannot reproduce a past dish or explain why this batch tastes different from the last one.

@card
id: tams-ch04-c008
order: 8
title: Synthetic Data
teaser: Synthetic data can expand a training set, cover rare edge cases, and protect privacy — but when the generator does not reflect reality, the model learns from a fiction.

@explanation

Synthetic data is artificially generated data used to supplement or replace real data. It has become an important tool in ML pipelines as privacy regulations constrain access to real data and as rare-event classes require more examples than are naturally available.

Use cases where synthetic data helps:

- **Rare event augmentation** — generating additional examples of minority classes (anomalies, failure modes, rare diseases) that are statistically under-represented in real data.
- **Privacy-preserving training** — generating records with the same statistical properties as real PII-containing data, without the PII.
- **Testing edge cases** — generating adversarial or boundary inputs that are unlikely to appear naturally in collected data.

Where synthetic data creates risk:

- **Distribution gap.** If the generator was trained on biased real data, the synthetic data inherits the bias. You cannot use synthetic data to fix a biased real dataset without first fixing the generator.
- **Mode collapse.** Generative models (GANs, VAEs, LLMs used as data generators) can produce samples that cluster in a subset of the real distribution, underrepresenting tail cases.
- **Feedback loops.** Training a model on synthetic data generated by a previous version of the same model introduces circular learning — artifacts of the generator become features the learner relies on.

Tester's responsibility: verify that synthetic data passes the same distributional checks as real data, that its source and generation method are documented, and that evaluations include real-data-only holdout sets to measure the actual gap.

> [!warning] A model evaluated only on synthetic data has never been tested on reality. Always maintain a real-data holdout set as the definitive evaluation benchmark, regardless of how much synthetic data was used in training.

@feynman

Synthetic data is a practice partner — it can sharpen your skills and fill gaps in your training, but a fight against a practice partner who always moves predictably does not prepare you for the unpredictability of a real opponent.

@card
id: tams-ch04-c009
order: 9
title: Privacy in Training Data
teaser: PII in a training dataset is not just a compliance risk — it is a testing concern, because models can memorize and reproduce sensitive data at inference time.

@explanation

Language models and other sequence-based models have been shown to memorize training data verbatim, including names, email addresses, phone numbers, and in some cases API keys and credentials. This is not a theoretical risk: researchers have demonstrated extraction of training data from GPT-2, GPT-3, and several open models by querying them with specially constructed prompts.

Privacy techniques at the data level:

**PII scrubbing** — identifying and removing or replacing personally identifiable information before training. Tools include Presidio (Microsoft) and custom regex pipelines. Scrubbing is imperfect; named entity recognition misses novel names and domain-specific identifiers.

**Differential privacy (DP)** — adding calibrated noise to the training process (DP-SGD) such that the presence of any individual training example cannot be inferred from the model's outputs. Provides a formal mathematical privacy guarantee. The tradeoff: DP training typically degrades model accuracy, especially for minority subgroups — the privacy budget must be chosen deliberately.

**Federated learning** — training on data that never leaves the device or data silo. The model aggregates gradients rather than raw examples. Testing concern: gradient inversion attacks can reconstruct training inputs from gradients, so federated learning is not a complete privacy solution without additional defenses.

Tester's role:

- Audit training datasets for PII before they enter the pipeline, using automated scanning.
- Verify that scrubbing coverage is reported and meets the acceptable residual rate.
- For DP systems, verify that the privacy budget (epsilon) is documented and reviewed by a privacy team.

@feynman

PII in training data is like accidentally binding someone's diary into a textbook — even if no one plans to read it, the information is now embedded in copies distributed everywhere.

@card
id: tams-ch04-c010
order: 10
title: Annotation Tools and Workflows
teaser: The labeling workflow is part of the test surface — tools like Label Studio, Snorkel, and Doccano shape how labels are produced, and the tester's role includes auditing the process, not just the output.

@explanation

Annotation tools provide the interface through which human annotators assign labels to raw examples. The choice of tool and the design of the workflow directly affect label quality.

**Label Studio** — open-source annotation platform supporting images, text, audio, video, and time series. Configurable templates, multi-annotator support, inter-annotator agreement calculation, and integration with ML-assisted pre-labeling. As of 2026-Q2, it is one of the most widely used open-source options for custom annotation workflows.

**Snorkel** — a programmatic labeling framework where labels are produced by "labeling functions" (heuristics, external knowledge bases, weak classifiers) rather than human annotators. The framework models the accuracy of each labeling function and combines them. Reduces the cost of large-scale labeling but introduces a different quality concern: the quality of the labeling functions themselves.

**Doccano** — open-source annotation tool focused on text tasks (sequence labeling, text classification, relation extraction). Simpler than Label Studio, easier to self-host, suitable for smaller teams.

The tester's role in annotation workflows:

- Review the labeling schema and instructions before annotation begins. Ambiguous instructions are the root cause of most label noise.
- Audit a sample of completed labels against the gold standard before the full dataset is consumed by training.
- For Snorkel-style workflows, test the labeling functions independently — each function should be evaluated for precision, recall, and coverage.
- Verify that the annotation tool records who labeled what and when, creating an audit trail.

@feynman

An annotation tool is the assembly line for your training data — the quality of the output depends as much on how the line is designed as on the skill of the workers on it.

@card
id: tams-ch04-c011
order: 11
title: Bias Detection in Datasets
teaser: A dataset that looks balanced overall can still encode systematic bias against specific subgroups — tools like Aequitas, Fairlearn, and IBM AIF360 make pre-training bias visible before it is baked into a model.

@explanation

Dataset bias refers to systematic disparities in how well a dataset represents different groups or how consistently it applies labels across groups. Bias at the data level becomes bias at the model level — and bias in model outputs translates directly into real-world harm for affected groups.

Pre-training bias auditing tools:

**Aequitas** — an open-source audit toolkit that computes fairness metrics across demographic slices of a dataset. Metrics include false positive rate disparity, false negative rate disparity, and selection rate disparity. Produces a report showing which groups are at elevated risk of unfair treatment under the current data distribution.

**Fairlearn** — a Microsoft Research open-source library that includes both assessment tools (dashboard, metrics) and mitigation algorithms. Its `MetricFrame` class enables computing any sklearn-compatible metric disaggregated by a sensitive attribute, making group-level performance gaps visible at a glance.

**IBM AIF360 (AI Fairness 360)** — a comprehensive toolkit with over 70 fairness metrics and 11 bias mitigation algorithms. Supports pre-processing (data-level), in-processing (training-level), and post-processing (prediction-level) interventions.

Tester responsibilities:

- Identify protected attributes (race, gender, age, geography, disability status) before dataset review begins.
- Run at least one pre-training audit tool and document group-level representation and label distribution by group.
- Flag disparities in label rates across groups — e.g., if one demographic has a 40% higher false-positive label rate than another, that is a data defect, not a model defect.

> [!info] As of 2026-Q2, several jurisdictions (EU AI Act, US Executive Order on AI) require documented bias assessments for high-risk ML systems. Pre-training dataset audits are the first step in that documentation chain.

@feynman

Bias in a dataset is like a map drawn by someone who only traveled certain roads — the roads they took are detailed and accurate, while the roads they skipped are blank or wrong, and a navigator relying on it will do fine on familiar routes and fail on the ones that were left out.

@card
id: tams-ch04-c012
order: 12
title: The Data Audit
teaser: A data audit is the structured process a tester runs before signing off on a training dataset — it covers provenance, quality, distribution, leakage, privacy, and bias in a documented, repeatable way.

@explanation

The data audit is the ML equivalent of a code review for the training dataset. It should happen before training begins, not after a model fails in production.

A practical data audit checklist covers six areas:

**Provenance** — where did the data come from? Is the source documented? Is the collection method reproducible? Are there licensing or consent constraints that restrict its use?

**Quality** — has Great Expectations or an equivalent tool been run? Are accuracy, completeness, consistency, and freshness assertions in place and passing? Are the assertions version-controlled and run in CI?

**Distribution** — what is the class distribution? What is the distribution of key features by demographic subgroup? Is the temporal range of the data appropriate for the deployment window?

**Leakage** — has the train/test split been verified for exact and near-duplicate overlap? For time-series problems, is the split temporal? Has preprocessing been computed on the training set only?

**Privacy** — has the dataset been scanned for PII? What is the residual PII rate? If differential privacy is required, is the privacy budget documented?

**Bias** — have protected attributes been identified? Has an audit been run with Aequitas, Fairlearn, or IBM AIF360? Are group-level label distribution disparities within acceptable bounds?

The output of a data audit is a written artifact — a data card or dataset report — that travels with the model through its lifecycle. A model should not proceed to training without a completed and signed-off data audit.

> [!tip] Treat the data audit as a blocking gate, not a post-hoc document. Catching a data provenance issue or a leakage bug before training saves the cost of retraining, re-evaluating, and potentially recalling a deployed model.

@feynman

A data audit is a pre-flight checklist for your training dataset — you do not take off and hope nothing is wrong, you verify each system before the engines start.
