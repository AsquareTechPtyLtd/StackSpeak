@chapter
id: tams-ch07-ml-frameworks-and-test-tooling
order: 7
title: ML Frameworks and Test Tooling
summary: The 2026 ML test toolkit divides into four categories — data validation, model validation, fairness/explainability, and end-to-end behavior testing — and a tester's literacy with the dominant tool in each category is what makes test plans concrete instead of abstract.

@card
id: tams-ch07-c001
order: 1
title: The Four-Category Framework for ML Test Tooling
teaser: Every ML test tool fits one of four roles — validating incoming data, validating trained model behavior, assessing fairness and explainability, or monitoring end-to-end behavior in production — and a test plan that ignores any category has a blind spot.

@explanation

Categorizing ML test tools before you pick them prevents two common mistakes: treating one tool as a substitute for work it was never designed to do, and assembling a toolchain with redundant coverage in one area and none in another.

The four categories, with what each is responsible for:

**Data validation** — does this dataset conform to the schema, statistical distribution, and quality constraints my model was designed to receive? Failures here are caught before training or inference begins.

**Model validation** — does the trained model behave correctly across the range of inputs it will encounter? Covers functional correctness, performance metrics, regression testing between model versions, and robustness to adversarial or edge-case inputs.

**Fairness and explainability** — does the model produce systematically different outcomes across protected groups, and can those outcomes be traced back to input features in a way that a human can interrogate?

**End-to-end behavior and drift monitoring** — once in production, is the model still seeing the data it was trained on, and are its predictions still consistent with expectations? This is the category most often absent in test plans for models that have already launched.

A tester's job is to have at least one concrete tool and one set of executable tests for each category. Abstract commitments to "monitor for drift" are not a test plan.

> [!info] As of 2026-Q2, the data validation and model validation categories have the most mature open-source tooling. Fairness tooling is usable but still fragmented, and LLM-specific end-to-end evaluation is the fastest-moving area by a wide margin.

@feynman

Think of the four categories as the four questions every ML test plan must answer: is the data right, does the model work, is it fair, and is it still working tomorrow.

@card
id: tams-ch07-c002
order: 2
title: The Training Framework Landscape
teaser: PyTorch, TensorFlow/Keras, scikit-learn, and JAX each occupy a distinct niche — a tester who understands what each is built for knows where its failure modes live and what instrumentation is native versus bolted on.

@explanation

Knowing which training framework a model was built in matters for testing because each framework shapes what observability you get for free and where you have to instrument manually.

**PyTorch** is the dominant research and production framework as of 2026. Its eager execution model (operations run immediately, not compiled to a graph) makes it easy to add assertions and logging mid-forward-pass. Most new model architectures appear in PyTorch first. The tradeoff: deployment requires extra steps (TorchScript or ONNX export) that introduce their own failure surfaces.

**TensorFlow / Keras** remains widely deployed in production, particularly in organizations that adopted it before PyTorch's ascendance. TensorFlow Serving and TFX provide mature, opinionated deployment and pipeline tooling. Keras is the high-level API most practitioners interact with. Testing challenge: graph-mode execution can make debugging harder unless eager mode is enabled explicitly.

**scikit-learn** is the standard for classical ML — tabular data, tree-based models, linear methods, preprocessing pipelines. Its `Pipeline` abstraction is testable with standard Python tooling and integrates cleanly with data validation libraries. Most production ML that handles structured data with low latency requirements still uses scikit-learn.

**JAX** occupies the research frontier — hardware-accelerated NumPy with composable function transforms. Testing JAX models requires more manual scaffolding; the ecosystem is less mature and assumes deeper framework familiarity.

> [!info] As of 2026-Q2, if you are testing a new large model, it is almost certainly PyTorch. If you are testing a production tabular-data system built before 2022, it is very likely scikit-learn or TensorFlow.

@feynman

The training framework is the workshop where the model was built — and knowing which workshop it came from tells you which tools are native to that environment and which you have to bring yourself.

@card
id: tams-ch07-c003
order: 3
title: Hugging Face Transformers
teaser: Hugging Face Transformers is the de-facto hub for pre-trained NLP and vision models — and for testers, the key facts are what the Hub's model cards do and don't guarantee, and where fine-tuning introduces new failure surfaces.

@explanation

Hugging Face Transformers provides a unified API to download, run, and fine-tune thousands of pre-trained models from the Hugging Face Hub. As of 2026, it is the default starting point for any NLP or computer vision task using transformer-based architectures.

What testers need to know:

**Model cards are self-reported.** Each model on the Hub has a model card documenting training data, intended use, limitations, and (sometimes) evaluation metrics. Model cards are written by the model author and are not independently verified. A model card that claims strong performance on a benchmark does not mean the model will perform acceptably on your specific distribution of inputs.

**Fine-tuning changes the model's behavior in ways the base model's evaluations do not cover.** When an organization fine-tunes a Hub model on proprietary data, the original model card evaluations are no longer directly applicable. Testing must be repeated on the fine-tuned version against the actual deployment distribution.

**The `pipeline` abstraction hides preprocessing.** Hugging Face's high-level `pipeline()` function bundles tokenization, inference, and decoding. This convenience is also a testing blind spot: if the preprocessing behavior changes between library versions, the output changes silently unless you have version-locked integration tests.

**Dataset versioning via the `datasets` library.** The companion `datasets` library makes it straightforward to load standard benchmark datasets — which supports reproducible evaluation. Testers should load evaluation datasets programmatically rather than from snapshots to catch distribution drift in benchmark datasets.

> [!warning] As of 2026-Q2, Hugging Face Hub hosts over 900,000 models. There is no automated quality gate at publication. Any testing standard you require must be applied by your team, not assumed from the Hub.

@feynman

The Hugging Face Hub is a vast library of model blueprints — useful, mostly documented, but with no librarian checking whether any particular blueprint will work safely for your specific building.

@card
id: tams-ch07-c004
order: 4
title: Data Validation Tools
teaser: Great Expectations, Pandera, and Pydantic each prevent the same root failure — a model receiving data it was not trained to handle — but at different layers of the stack and with different ergonomics.

@explanation

Data quality failures are responsible for a large fraction of ML production incidents: the model behaves exactly as trained, but the training data assumptions no longer match the production data. Data validation tools make those assumptions explicit and executable.

**Great Expectations** defines "expectations" — logical assertions about a dataset — in code and generates human-readable HTML documentation as a side effect. It supports profiling an existing dataset to auto-generate an initial expectation suite, then re-running that suite against new data in CI or at inference time. Well-suited for large batch pipelines and teams that need to share data contracts across roles (engineering, data science, analytics). Steeper learning curve; the checkpoint and datasource abstractions require investment to understand.

**Pandera** is schema validation for pandas DataFrames (and compatible with Polars and PySpark). Schemas are defined as Python classes or decorators, which integrates naturally into pytest-based test suites. Lower overhead than Great Expectations for teams already using pytest extensively. Best for teams where data scientists write their own tests.

**Pydantic** is a general-purpose data validation and settings library that has become the standard for validating structured data at API and service boundaries in Python. For ML systems serving predictions via REST APIs, Pydantic models on request and response objects catch schema drift early. Less suited for statistical distribution checks; strong for structural and type-level validation.

The choice is not exclusive. A common pattern is Pydantic for API boundary validation, Pandera for DataFrame validation inside pipelines, and Great Expectations for broader data contract documentation.

> [!info] As of 2026-Q2, Pandera v0.19+ supports Pydantic v2 integration, allowing schemas to serve dual roles — structural validation via Pydantic and statistical validation via Pandera.

@feynman

Data validation tools are the spec sheet for your model's diet — they encode exactly what inputs the model was designed to eat and alert you the moment something different shows up on the plate.

@card
id: tams-ch07-c005
order: 5
title: Model Validation Tools — Deepchecks, Giskard, Evidently AI
teaser: Deepchecks automates suite-level model checks, Giskard scans for vulnerabilities and bias with a scan-and-remediate workflow, and Evidently AI spans both model validation and production monitoring — each is better in a different part of the testing lifecycle.

@explanation

These three tools sit in the model validation category but have meaningfully different strengths.

**Deepchecks** runs a battery of built-in checks (train-test comparison, feature drift, label drift, performance disparity across segments, data leakage indicators) and produces a structured HTML report. It is best used in the pre-deployment phase, immediately after training, to surface common ML correctness issues that developers often miss. The built-in check suite is the fastest path from "model trained" to "structured evidence of no obvious problems." Limitation: checks are generic; they do not replace domain-specific tests that encode your system's acceptance criteria.

**Giskard** is oriented toward vulnerability scanning — it probes models for hallucinations (for LLMs), bias, robustness failures, and data leakage using a combination of automated scans and an SDK for defining custom test scenarios. It includes a test catalog and a CI integration so that scan results block deployment pipelines when thresholds are violated. Strongest for LLM and classification use cases. As of 2026, the LLM scan suite is the most actively developed part of the library.

**Evidently AI** covers both pre-deployment model evaluation and production monitoring. Its report and test suite API generates visual reports on model performance, data drift, and data quality, and the same test logic can run in CI (offline) or against live prediction logs (online). It is the best choice when a single tool needs to serve both the evaluation-before-release and the monitor-after-release workflows.

> [!info] As of 2026-Q2, Deepchecks and Giskard both have commercial cloud tiers alongside their open-source cores. The open-source versions are sufficient for most pre-deployment testing use cases.

@feynman

Think of Deepchecks as the pre-flight checklist, Giskard as the adversarial stress test, and Evidently AI as the continuous flight recorder — all three are useful, but at different moments in the journey.

@card
id: tams-ch07-c006
order: 6
title: Drift Detection and Production Monitoring
teaser: Evidently AI, WhyLabs, Arize, and Fiddler each detect the moment a deployed model's data or predictions diverge from expectations — the difference between them is where they sit in your infrastructure and how much you pay for that position.

@explanation

Model drift is the gradual or sudden degradation in a deployed model's relevance that results from changes in the data it receives, the labels it predicts, or the relationship between the two. Without dedicated monitoring, drift is invisible until it produces a downstream incident.

**Evidently AI** (open source) computes drift metrics on data and predictions by comparing a reference window against a current window. It supports Kolmogorov-Smirnov tests, Population Stability Index, and Jensen-Shannon divergence among others. It runs as a Python library against whatever data store you already use, which means it integrates with little infrastructure overhead. The tradeoff: alerting, scheduling, and visualization pipelines are your responsibility to build.

**WhyLabs** is a managed observability platform built around the open-source `whylogs` profiling library. `whylogs` generates compact statistical profiles of data and model outputs (histograms, quantile sketches, cardinality estimates) and sends them to the WhyLabs cloud. Drift alerts are configured in the UI and trigger on computed deltas between profiles. Best fit for teams that want drift detection without building alerting infrastructure.

**Arize AI** targets production model observability with an emphasis on slice-level performance monitoring — it tracks metrics not just at the population level but across user segments, feature value ranges, and embedding clusters. Strongest for teams that need to tie model underperformance back to specific data subgroups.

**Fiddler AI** includes drift detection as part of a broader explainability and model performance management platform. Strongest in regulated industries where explainability and audit trails are compliance requirements, not just engineering choices.

> [!info] As of 2026-Q2, Evidently AI's open-source library is the pragmatic starting point for teams that want to own their monitoring stack. WhyLabs is the lowest-friction managed option for teams without dedicated MLOps engineers.

@feynman

Drift detection tools are the blood pressure cuff for your deployed model — they do not diagnose the disease, but they flag the vital sign that tells you something is changing before the patient collapses.

@card
id: tams-ch07-c007
order: 7
title: Fairness Testing Tools — Aequitas, Fairlearn, IBM AIF360
teaser: Aequitas measures disparities in model outcomes across groups, Fairlearn provides both metrics and mitigation algorithms, and IBM AIF360 offers the broadest catalog of fairness metrics and bias mitigation methods — all three work at different points in the ML lifecycle.

@explanation

Fairness tools serve two distinct roles: measuring whether a disparity exists and providing mechanisms to reduce it. A tester's primary concern is measurement; a tester who also has agency in model development will care about mitigation options too.

**Aequitas** (University of Chicago) is a Python library and web app for auditing classification model bias across demographic groups. It computes a set of group-level fairness metrics (false positive rate parity, false negative rate parity, false discovery rate, and others) and generates an "audit report" comparing outcomes across subgroups of a protected attribute. Best used in the post-training, pre-deployment phase when you have model outputs and demographic attributes. Straightforward API with minimal configuration overhead.

**Fairlearn** (Microsoft, open source) provides fairness metrics similar to Aequitas but adds a `reductions` module with constraint-based mitigation algorithms that can be applied during training. For testers, the `MetricFrame` class is the most relevant object: it computes any sklearn-compatible metric sliced by a sensitive feature column, making it easy to integrate into an existing model evaluation workflow.

**IBM AIF360** (AI Fairness 360) offers the largest catalog of both fairness metrics and bias mitigation algorithms of the three libraries — covering pre-processing (modifying training data), in-processing (modifying the training algorithm), and post-processing (modifying predictions) interventions. More comprehensive but also more complex to configure; best suited for teams conducting formal fairness audits rather than quick checks.

Important constraint all three share: they require that protected attributes be present in the evaluation dataset. If demographic data is not collected, group fairness metrics cannot be computed.

> [!warning] As of 2026-Q2, none of these tools resolve the question of which fairness definition applies to your system — that is a product and legal decision, not a library call. The tools compute; they do not decide.

@feynman

Fairness tools are measurement instruments, not moral arbiters — they tell you whether your model treats groups differently, but deciding whether that difference is acceptable requires human judgment and context.

@card
id: tams-ch07-c008
order: 8
title: Explainability Libraries — SHAP, LIME, Captum, ELI5
teaser: SHAP provides theoretically grounded feature attributions for any model, LIME explains individual predictions via local approximations, Captum targets PyTorch models with gradient-based methods, and ELI5 offers fast readable explanations for classical ML — each trades fidelity, speed, and generality differently.

@explanation

Explainability libraries answer the question: which input features contributed most to this specific prediction, and by how much? For testers, they support two activities — validating that the model is relying on sensible features (not proxies or artifacts), and debugging specific prediction failures.

**SHAP** (SHapley Additive exPlanations) decomposes a prediction into feature contributions using a game-theoretic framework. The `TreeExplainer` variant is fast for tree-based models; the `KernelExplainer` is model-agnostic but slow. SHAP values are globally consistent — the same feature importance calculation works across the training population and for individual predictions. The tradeoff: for large models or KernelExplainer, computation is expensive. Best tool for model-level feature importance analysis.

**LIME** (Local Interpretable Model-agnostic Explanations) explains a single prediction by training a simple interpretable model on a perturbed sample around that input. Model-agnostic and works with tabular, text, and image data. Faster than KernelSHAP for single-instance explanations. The weakness: LIME explanations are locally approximate and can be unstable — running LIME twice on the same input can produce different attributions.

**Captum** is PyTorch-native and provides gradient-based attribution methods (Integrated Gradients, DeepLIFT, GradCAM, and others). For neural networks in PyTorch, Captum gives richer attributions than SHAP or LIME because it has direct access to the model's computational graph. Limited to PyTorch models.

**ELI5** provides fast, human-readable feature importance for classical scikit-learn models and some gradient-boosted tree implementations. Lower fidelity than SHAP but fast to run and easy to integrate into automated reports.

> [!info] As of 2026-Q2, SHAP is the most cited explainability library in audit and compliance contexts. If an explainability report will be reviewed by a regulator or legal team, SHAP's formal Shapley value foundation is the most defensible choice.

@feynman

Explainability tools are the magnifying glass on a model's reasoning — they show you which features it leaned on for a specific decision, but the magnifying glass does not tell you whether that reasoning was appropriate.

@card
id: tams-ch07-c009
order: 9
title: LLM Evaluation Frameworks
teaser: Promptfoo, DeepEval, Inspect, Ragas, and OpenAI Evals each tackle the fundamental problem of LLM testing — that outputs are probabilistic text, not deterministic values — but with different target users, evaluation paradigms, and levels of framework lock-in.

@explanation

Evaluating LLM outputs requires frameworks purpose-built for the problem: answers are free-form text, correctness cannot be reduced to a binary comparison, and the same prompt can produce different outputs on different runs.

**Promptfoo** is a prompt testing and evaluation CLI and library. It runs a prompt template against a set of test cases and evaluates each output against configurable assertions — exact match, contains, regex, LLM-graded rubrics, or custom JavaScript functions. Produces structured pass/fail reports. Well-suited for prompt regression testing in CI: any change to a prompt is tested against the full assertion suite before deployment. Strong developer ergonomics.

**DeepEval** is a Python framework modeled after pytest. It provides built-in metric classes (faithfulness, answer relevancy, contextual recall for RAG, toxicity, bias, hallucination) that can be used as test assertions and run via `deepeval test run`. Good integration with CI and has a managed platform for tracking evaluation results over time.

**Inspect** (UK AI Safety Institute) is an open-source evaluation framework designed for rigorous capability and safety evaluation of LLMs. It emphasizes reproducibility and structured logging of every evaluation run. More appropriate for systematic capability audits than day-to-day prompt regression testing.

**Ragas** specializes in RAG (retrieval-augmented generation) pipeline evaluation — it measures faithfulness (does the answer follow from the retrieved context?), answer relevancy, context precision, and context recall. If the system under test uses RAG, Ragas should be on the toolchain.

**OpenAI Evals** provides a framework for defining and running evaluation suites against any model through a standard API. Useful when comparing multiple model providers or model versions.

> [!warning] As of 2026-Q2, LLM evaluation frameworks are evolving faster than any other category in this chapter. Promptfoo and DeepEval have both had significant API changes within the last 12 months. Pin versions in CI.

@feynman

LLM evaluation frameworks solve the problem of testing a system whose correct answer is "it depends" — they replace binary assertions with graded rubrics that can still fail a test suite.

@card
id: tams-ch07-c010
order: 10
title: Notebook-Based Testing — pytest-notebook and nbval
teaser: Most ML development happens in Jupyter notebooks, and most Jupyter notebooks have no automated tests — pytest-notebook and nbval are the two main tools that bring standard test tooling to the notebook environment, each with a different execution model.

@explanation

Jupyter notebooks are the dominant development environment for ML experimentation, and they accumulate untested logic because standard pytest does not execute `.ipynb` files. Two tools address this gap:

**nbval** runs a Jupyter notebook cell by cell and compares the actual output of each cell against the stored output in the notebook file. If a cell's output changes, the test fails. This makes nbval useful for regression testing notebooks that have stable, deterministic outputs — such as data processing notebooks or model evaluation notebooks where the same inputs should always produce the same results. The limitation: many ML notebooks have stochastic outputs (random seeds not fixed, training loss that varies slightly), which produces false failures unless those cells are tagged to skip comparison.

**pytest-notebook** takes a more configurable approach, allowing per-cell test decorators and supporting cell-level assertions via notebook metadata. It integrates more naturally with pytest's fixture and plugin ecosystem. Better suited for notebooks where fine-grained control over what is asserted is needed.

Practical constraints both tools share:

- Notebooks must have been previously executed and saved with outputs for nbval to compare against. A notebook with cleared outputs cannot be validated this way.
- Cell execution order matters. Any notebook that produces correct results only when cells are run in a specific non-sequential order will be difficult to test reliably.
- Long-running training cells in CI will time out. Testing notebooks with non-trivial training loops requires either mocking the training or testing on a stripped-down dataset.

> [!info] As of 2026-Q2, the pragmatic pattern is to use notebooks only for exploration and to promote finalized logic into Python modules tested with standard pytest. nbval and pytest-notebook are backstops for notebooks that must remain as notebooks.

@feynman

Testing a Jupyter notebook is like testing a recipe by actually cooking it — you run every cell in order and check that the kitchen looks the same at the end, which only works if the recipe is deterministic enough to cook the same way twice.

@card
id: tams-ch07-c011
order: 11
title: ML CI Tools — DVC, MLflow, and GitHub Actions
teaser: DVC makes ML pipelines reproducible by versioning data and pipeline steps alongside code, MLflow tracks experiments so model versions are auditable, and GitHub Actions ML extensions wire both into standard CI — together they make "which model, trained on which data, with which hyperparameters" a question with a concrete answer.

@explanation

The testability of a machine learning system depends on reproducibility: you cannot run a regression test if you cannot reconstruct the exact conditions under which the model was originally validated.

**DVC** (Data Version Control) extends Git to track large files, datasets, and pipeline stages. A `dvc.yaml` file defines the DAG of pipeline stages (data preprocessing, feature engineering, training, evaluation), and DVC records the hash of every input and output at each stage. This means any change to data or code is detectable: `dvc repro` re-runs only the stages invalidated by the change, and `dvc diff` shows what changed between two pipeline runs. For testers, DVC provides the audit trail that answers "was this model trained on the same data as the last release?"

**MLflow** tracks experiments — each training run logs parameters, metrics, artifacts (model files, evaluation plots), and the environment. The model registry provides a workflow for moving a model from "candidate" to "staging" to "production" with version numbers. For testers, the key capability is comparing two model versions: any performance regression between the registered staging model and the current candidate is surfaced by querying the MLflow tracking server.

**GitHub Actions** (and GitLab CI equivalents) can trigger DVC pipeline runs and MLflow experiment logging on pull requests, making model evaluation a blocking CI check. The `iterative/setup-dvc` and community MLflow actions reduce the integration overhead.

> [!info] As of 2026-Q2, DVC and MLflow are not competing tools — they address different problems and are frequently used together in the same pipeline.

@feynman

DVC and MLflow together make an ML system auditable in the same way that git makes code auditable — you can always answer what was running, when, and what inputs produced it.

@card
id: tams-ch07-c012
order: 12
title: Tester-as-Prompt-Engineer — Promptfoo Eval Workflows
teaser: Building evaluation datasets is the foundational skill for LLM testing — and Promptfoo's prompt-iteration workflow treats test-case authorship and prompt tuning as a single loop, turning the tester into an active participant in model behavior, not just a verifier after the fact.

@explanation

For LLM systems, the tester's role expands beyond verification into evaluation dataset construction and adversarial test case design. The prompt itself is a parameter of the system, and changes to it change observable behavior — which means regression testing must be built around structured evaluation datasets, not manual spot checks.

**The Promptfoo workflow in practice:**

1. Define prompt templates with variable slots in a `promptfooconfig.yaml` file.
2. Author test cases as a list of variable-input and expected-output pairs — each case is one row in the eval.
3. Configure assertions per test case: exact string containment, regex, model-graded rubrics via a separate LLM as judge, or custom JavaScript.
4. Run `promptfoo eval` to execute all prompts against all cases and produce a pass/fail report.
5. When a prompt change is proposed, re-run the full eval suite and treat regressions as blocking.

**Building the eval dataset is the hardest part.** An eval dataset has no value if it only covers cases the developer has already handled. Effective eval datasets include:

- Happy-path inputs that should always succeed.
- Boundary cases that expose ambiguity in the prompt instructions.
- Adversarial inputs designed to elicit failures — jailbreak attempts, inputs that exploit known weaknesses in the model, inputs that are semantically equivalent but phrased to confuse.
- Regression cases: any production failure that has been observed should be added to the eval dataset immediately.

**Tester contribution:** A tester who understands the system's domain and failure modes is better positioned to author adversarial eval cases than a developer focused on the happy path. This is the primary way testing expertise adds value in LLM development beyond running an existing suite.

> [!info] As of 2026-Q2, Promptfoo supports over 25 model providers including OpenAI, Anthropic, Google, Mistral, and local Ollama models, so eval suites are portable across provider evaluations.

@feynman

Building an LLM eval dataset is the same skill as writing a good test suite for any software system — the challenge is imagining the inputs that will break things, not just the inputs that are supposed to work.
