@chapter
id: tams-ch02-quality-characteristics-for-ai-based-systems
order: 2
title: Quality Characteristics for AI-Based Systems
summary: AI systems have quality characteristics that classical software doesn't — flexibility, autonomy, evolution, bias, ethics, side-effects — and the testing strategy is shaped by which of these matter for the system under test.

@card
id: tams-ch02-c001
order: 1
title: Why the Classical Quality Model Falls Short for AI
teaser: Classical software quality models assume deterministic behavior and stable specifications — assumptions that break down the moment a model learns from data and can produce outputs that were never explicitly programmed.

@explanation

The ISO 25010 quality model — covering correctness, reliability, efficiency, usability, and related characteristics — was designed for software whose behavior is fully specified by a programmer. AI-based systems break several of those assumptions.

Where the mismatch shows up:

- **Correctness becomes probabilistic.** A classical function either returns the right value or it doesn't. An AI classifier returns a confidence score. "Correct" often means "correct most of the time, within a defined error bound, on a specified population."
- **Specification is incomplete by design.** AI systems are trained to generalize from examples, not to execute a specification. There is no requirements document that covers every input the model will ever see.
- **Behavior changes after deployment.** A shipped binary does not change unless redeployed. An AI system with online learning, fine-tuning, or model updates can behave differently tomorrow than it does today, even if no engineer touched the code.
- **Emergent properties matter.** Bias, fairness, and side-effects are not bugs in individual functions — they are systemic properties that only appear when you look at output distributions across populations or over time.

AI testing extends classical testing rather than replacing it. Correctness on known inputs, performance, security, and reliability are still tested. But the AI quality model adds a second layer of characteristics specific to learned behavior.

> [!info] As of 2026-Q2, the ISTQB CT-AI v1.0 syllabus frames AI quality around five additional characteristics beyond the classical model: flexibility, autonomy, evolution, bias, and side-effects. This chapter covers all five plus several closely related properties.

@feynman

Classical quality testing checks that a machine built to a blueprint matches the blueprint; AI quality testing also checks that a machine that built its own blueprint built a safe one.

@card
id: tams-ch02-c002
order: 2
title: Flexibility — Handling the Unexpected Input
teaser: Flexibility is the degree to which an AI system handles inputs it was never trained on — and a brittle system that fails silently on out-of-distribution input is more dangerous than one that fails loudly.

@explanation

A classical program given an unexpected input typically throws an exception, returns a defined error code, or halts — the failure is explicit. An AI system given an out-of-distribution input typically produces a confident-looking output anyway, because the model has no mechanism to say "I don't know."

Flexibility testing asks:

- Does the system produce useful output on inputs that are near but outside the training distribution?
- When the system cannot handle an input, does it degrade gracefully — returning low confidence, abstaining, or escalating to a human — rather than hallucinating a plausible-but-wrong answer?
- Does performance degrade smoothly as inputs move further from the training distribution, or does it cliff-edge at some boundary?

Testing strategies:

- **Out-of-distribution (OOD) test sets** — inputs constructed to sit outside the training domain, used to measure how gracefully the system fails.
- **Perturbation testing** — systematically vary input features (lighting, rotation, typos, tone, dialect) to find the edges of reliable behavior.
- **Confidence calibration checks** — verify that stated confidence scores actually predict accuracy. A model is well-calibrated if, among inputs it rates at 80% confidence, roughly 80% are actually correct.

Graceful degradation is the design target. A system that abstains when uncertain is safer than one that always answers.

> [!warning] High accuracy on a held-out test set does not guarantee flexibility. If the test set was drawn from the same distribution as training data, it tells you nothing about out-of-distribution behavior.

@feynman

Flexibility is what separates a model that knows what it knows from one that confidently makes things up whenever a question falls outside its experience.

@card
id: tams-ch02-c003
order: 3
title: Autonomy — Acting Without a Human in the Loop
teaser: Autonomy measures how much an AI system decides and acts on its own; the higher the autonomy, the higher the stakes when it gets something wrong, and the harder it is to test every consequential path.

@explanation

An AI system can sit anywhere on a spectrum from fully supervised to fully autonomous:

- **Human-in-the-loop:** The system makes recommendations; a human decides and acts. A spam filter that flags email but lets the user confirm before deletion.
- **Human-on-the-loop:** The system acts automatically but a human monitors and can intervene. A fraud detection system that blocks a transaction but notifies a human analyst.
- **Fully autonomous:** The system decides and acts without human review. A self-driving vehicle's emergency braking.

Testing implications scale with autonomy level:

- At low autonomy, a wrong recommendation is annoying. At high autonomy, a wrong decision has real-world consequences (financial loss, physical harm, legal liability) that cannot be undone.
- Test coverage must extend to rare but consequential scenarios. For a fully autonomous system, "what happens in the worst 0.1% of inputs" is more important than average-case accuracy.
- Human override mechanisms need to be tested as thoroughly as the AI decision path — if operators cannot intervene effectively, the oversight model breaks down.
- **Autonomous systems require explicit scope constraints.** Testing must verify that the system acts only within its defined authority and does not take actions outside its intended domain.

There is no universally correct autonomy level. The right level depends on error cost, latency requirements, and operator capacity. Testing must be calibrated to the level chosen.

@feynman

Autonomy testing is about making sure the system knows where its lane ends — and stays in it even under pressure.

@card
id: tams-ch02-c004
order: 4
title: Evolution — The System That Changes After You Ship It
teaser: An AI system that learns from production data or receives fine-tuning updates after deployment is not the same system it was at launch — and classical regression testing, designed for stable code, does not handle this well alone.

@explanation

Software evolution in classical systems is controlled: a developer changes code, tests run, a release ships. AI evolution can be continuous and less visible — model weights shift as production data is incorporated, fine-tuning runs update behavior, or a new base model is swapped in.

Forms of post-deployment evolution:

- **Online learning:** The model continuously updates its weights from live production data. Behavior can drift within hours.
- **Periodic retraining:** A new model version is trained on accumulated production data on a schedule (weekly, monthly). Behavior changes at each training cycle.
- **Fine-tuning:** A pre-trained base model is adapted to a new task or domain. The new model may behave very differently on edge cases even if core task performance is similar.
- **Model replacement:** The underlying model (e.g., a vendor-provided LLM) is updated by a third party with no action from the AI system's operators.

Testing implications:

- **Regression test suites must be versioned** alongside the model, not just the code. A regression suite built for model v1.2 may be inadequate for v1.5 because the failure modes have shifted.
- **Behavioral anchors** — a curated set of inputs with expected outputs — should be run after every model update to detect unintended behavior change.
- **Drift monitoring** replaces the assumption that behavior is stable. Production input distributions must be tracked; when they shift significantly from the training distribution, model performance is at risk.

> [!warning] If a third-party model you depend on updates silently, you may ship a regression without touching a line of your own code. Pinning model versions and running behavioral tests on updates is essential.

@feynman

A system that learns after deployment is like an employee who quietly rewrites their own job description — useful if they improve, dangerous if no one checks.

@card
id: tams-ch02-c005
order: 5
title: Bias — Systematic Error Toward or Against Subgroups
teaser: Bias in AI systems is not a bug in one prediction but a systematic pattern in the distribution of errors — certain groups consistently receive worse outcomes — and it is invisible to tests that only measure aggregate accuracy.

@explanation

A model can achieve 95% aggregate accuracy while being meaningfully less accurate for specific demographic groups. If the underserved group is a minority in the test set, aggregate metrics hide the disparity entirely. Bias testing makes the distribution of errors explicit.

Categories of bias origin:

- **Training data bias.** The training set over- or underrepresents certain groups, causing the model to have less exposure to — and therefore lower performance on — those groups.
- **Label bias.** Human annotators who created training labels bring their own biases. A dataset labeled by a homogeneous group may encode systematic judgments that are not universal.
- **Historical bias.** The real-world data reflects historical discrimination. A hiring model trained on past hiring decisions learns to replicate those decisions, including any systematic exclusion.
- **Measurement bias.** Proxy variables (zip code, school name) correlate with protected attributes and allow indirect discrimination even when protected attributes are removed from the feature set.

Testing for bias requires:

- Disaggregating performance metrics by demographic group or subgroup of interest.
- Defining fairness criteria explicitly — there are multiple mathematically incompatible definitions (demographic parity, equal opportunity, calibration) and the choice among them is a product and ethics decision, not a purely technical one.
- Testing on data that adequately represents the subgroups that matter, not just the majority population.

> [!info] As of 2026-Q2, no single fairness metric is universally accepted. Testing teams should document which fairness definition was used and why — and surface disagreements with product owners before deployment, not after.

@feynman

Bias testing is asking not just "how often is the model wrong?" but "who does the model wrong most often?"

@card
id: tams-ch02-c006
order: 6
title: Ethics — Testing as a Line of Defense
teaser: Ethical quality requirements — fairness, privacy, harm avoidance, accountability — are not soft guidelines; they can be specified, operationalized into test cases, and made part of the definition of done.

@explanation

Ethics is not separate from testing; it is a quality dimension that can be specified and verified like performance or reliability. The key is translating abstract ethical principles into testable requirements.

Ethical requirements that can be operationalized:

- **Fairness.** "The false negative rate for protected group A must not exceed the false negative rate for protected group B by more than 5 percentage points." This is measurable.
- **Privacy.** "The model must not reproduce verbatim training data in its outputs." This can be tested with membership inference and data extraction probes.
- **Harm avoidance.** "The system must not generate content that meets the definition of hate speech in our harm taxonomy." This requires a labeled test set of harmful examples and a pass/fail threshold.
- **Consent and scope.** "The system must only process data types the user explicitly opted into." This is a functional requirement that can be verified.
- **Accountability.** "For every decision above a defined consequence threshold, a human-auditable explanation must be generated and retained." Testable.

The testing team's role is to:
- Participate in translating ethical principles into concrete, testable acceptance criteria during requirements.
- Build test suites that cover ethical failure modes alongside functional and performance suites.
- Escalate ethical risks found in testing to decision-makers before deployment, not as a post-launch retrospective.

Testing is one layer of ethics enforcement, not the only one. It cannot substitute for ethical design, diverse training data, or post-deployment monitoring — but it is a necessary layer.

@feynman

Testing for ethics means writing down what "harmful" and "unfair" look like in this specific system, then checking whether the system does those things.

@card
id: tams-ch02-c007
order: 7
title: Side-Effects — Unintended Consequences Beyond the Task
teaser: A side-effect is any impact the AI system has on its environment beyond the intended task — from energy cost to dependency creation — and testers are responsible for surfacing them, not just verifying task performance.

@explanation

Classical software testing focuses on whether the system does what it was designed to do. Side-effect testing asks what else the system does that it was not designed to do, or what real-world costs it incurs that were not part of the design intent.

Categories of AI side-effects relevant to testing:

- **Computational and energy cost.** Large model inference has measurable carbon footprint and financial cost per request. Testing at scale should report inference cost per prediction, not just accuracy — a model that is 2% more accurate but 10x more expensive may be the wrong choice.
- **Dependency creation.** Users who rely on an AI recommendation engine may lose the ability to perform that judgment independently over time. This is a long-term side-effect that is hard to test but should be flagged during design review.
- **Feedback loops.** A recommendation system that influences what users do will change the distribution of future training data. A test environment that does not model this feedback loop will miss degradation that only appears in production.
- **Unintended optimization.** A system optimizing for a proxy metric (click-through rate, engagement time) may achieve its measured goal while causing harm on unmeasured dimensions (misinformation spread, user anxiety). Testing must check the gap between the optimized metric and the underlying intent.
- **System-level interactions.** An AI component embedded in a larger system may affect other components in ways that are invisible when the component is tested in isolation.

> [!tip] When reviewing acceptance criteria, explicitly ask: "What does this system do beyond the task?" The answer is often "nothing" — but asking the question surfaces the cases where it isn't.

@feynman

Side-effect testing is checking not just whether the system solved the problem it was given, but what it broke, consumed, or changed in the process of solving it.

@card
id: tams-ch02-c008
order: 8
title: Performance Characteristics for AI — Beyond Latency and Throughput
teaser: AI systems have classical performance concerns (latency, throughput) plus a layer of model-specific performance — quality degrades under load, under distribution shift, and as inputs push toward the model's decision boundaries.

@explanation

Classical performance testing measures response time and resource consumption. AI performance testing adds a second axis: does model quality (accuracy, precision, recall, calibration) hold up under the conditions that classical performance testing creates?

Performance characteristics specific to AI:

- **Latency with quality decay.** Batching and quantization — common techniques for improving throughput — can reduce model quality. Performance testing must measure the accuracy impact of performance optimizations, not just the speed gain.
- **Throughput ceiling.** AI inference on GPU/TPU hardware has non-linear scaling behavior. At peak load, models may be throttled or fall back to slower inference paths, affecting both latency and quality.
- **Quality under adversarial load.** Deliberate adversarial inputs injected at scale (data poisoning in production, prompt injection in LLM-based systems) can degrade model quality beyond the effect of legitimate peak load alone.
- **Cold-start and warm-up.** Some models require warm-up inference passes before reaching stable accuracy. Load tests that measure only steady-state miss the cold-start penalty.
- **Ensemble and cascade latency.** Many production AI systems use multiple models in sequence (a fast classifier routes to a slower high-accuracy model). End-to-end latency testing must cover the full pipeline, not individual components.

Resource usage is also a quality characteristic: memory footprint, GPU utilization, and inference cost per prediction should be reported as first-class outputs of performance testing, not afterthoughts.

> [!info] As of 2026-Q2, large language model inference cost is typically reported per 1,000 tokens processed. Establishing cost-per-query baselines in performance testing lets teams detect regressions introduced by model updates.

@feynman

AI performance testing asks two questions simultaneously: how fast is it, and how good is it when it's fast — because the answer to the second often changes when you push on the first.

@card
id: tams-ch02-c009
order: 9
title: Adaptability — Surviving Distribution Shift
teaser: Adaptability is the system's ability to maintain acceptable quality when the real-world data it sees in production diverges from what it was trained on — and this divergence is not an edge case but an inevitability.

@explanation

Distribution shift is the gap between the distribution of data a model was trained on and the distribution it encounters in production. It occurs because:

- The world changes (user behavior, language, market conditions).
- The system's own outputs change user behavior (feedback loop).
- The deployment context differs from the training context (a model trained on desktop text applied to mobile input).
- The system is repurposed for a domain adjacent to but distinct from its training domain.

Types of distribution shift:

- **Covariate shift.** The distribution of input features changes, but the relationship between inputs and outputs remains the same. A customer churn model trained in 2022 encounters a different economic environment in 2025.
- **Concept drift.** The underlying relationship between inputs and the correct output changes. "Spam" looked different in 2010 than it does today — a spam filter trained in 2010 without updates will degrade not because the inputs changed but because the definition of the target changed.
- **Label shift.** The prevalence of each class in the population changes. A medical screening model trained when a condition was rare will underperform when prevalence rises.

Testing for adaptability:

- Define acceptable quality thresholds and the monitoring cadence to check them.
- Build test sets that intentionally represent distribution shift scenarios — time-shifted data, geographic variants, adversarial reformulations.
- Test the retraining pipeline, not just the model. How quickly can the system be updated when drift is detected? Does the retraining pipeline itself introduce new risks?

@feynman

Adaptability testing is asking: when the world stops looking like the training data, how long does it take the system to notice, and how bad does it get before it recovers?

@card
id: tams-ch02-c010
order: 10
title: Transparency and Explainability — Can You See Why?
teaser: Explainability is a quality characteristic and a testing tool at the same time — a system you can inspect is easier to test, easier to debug when wrong, and able to meet the regulatory requirements that black-box systems cannot.

@explanation

Transparency in an AI system means there is a pathway from an output back to an understandable account of why the system produced it. Explainability is often used interchangeably, though some frameworks distinguish them:

- **Transparency:** the internal structure of the model is visible and interpretable (white-box models like decision trees or linear regression).
- **Explainability:** post-hoc methods produce human-readable explanations of a model's decisions, even for opaque models (SHAP, LIME, attention visualization).

Why it matters for testing:

- An explainable system can have its decision logic reviewed for plausibility. A model that claims "income" is the most important feature for a loan decision is easier to audit than one whose top feature is an inscrutable learned embedding.
- Explanations can surface bias. If a model explanation shows that a protected attribute (or a close proxy) is a top driver of decisions, that is a bias test finding.
- Regulators increasingly require explanation capability. In financial services, healthcare, and hiring, "the model said so" is not a legally acceptable decision justification in many jurisdictions as of 2026.
- Unexplainable failures are harder to debug. When a model fails on a specific input, an explanation helps isolate whether the failure is a data quality issue, a feature encoding error, or a model generalization problem.

The tradeoff is real: the most accurate models (deep neural networks, large ensembles) tend to be the least transparent. Testing must verify that whatever explainability mechanism is offered is accurate — a misleading explanation is worse than no explanation.

> [!warning] Explainability methods like SHAP and LIME produce approximations of model behavior, not exact accounts. Testing should verify that explanations are locally faithful to the model, not taken as ground truth about why the model works.

@feynman

Explainability testing checks that the model's stated reason for a decision is actually the real reason — not a plausible story it generated after the fact.

@card
id: tams-ch02-c011
order: 11
title: Trustworthiness — The Composite Characteristic
teaser: Trustworthiness is not a single test to run but a judgment about whether the system is reliable enough, fair enough, safe enough, and transparent enough to be deployed in its intended context — it is earned by passing all the other quality tests together.

@explanation

Trustworthiness is the meta-characteristic that organizations, regulators, and end users evaluate when deciding whether to rely on an AI system. It is composite: a system is trustworthy to the extent that it scores acceptably on the individual characteristics that matter for its deployment context.

The components of trustworthiness, and which AI quality characteristics they draw on:

- **Reliability:** The system performs its task consistently and correctly over time. Draws on accuracy, robustness, and adaptability.
- **Safety:** The system does not cause harm. Draws on side-effect analysis, adversarial robustness, and autonomy constraints.
- **Fairness:** The system does not systematically disadvantage subgroups. Draws on bias testing and ethical requirements.
- **Privacy:** The system does not expose data it should not. Draws on privacy testing and data governance.
- **Transparency:** The system's behavior can be understood and audited. Draws on explainability.
- **Accountability:** Decisions can be attributed and reviewed. Draws on logging, explainability, and governance.

Trustworthiness is always contextual. A model used for music recommendations requires a different trust threshold than one used for medical triage. Testing must be calibrated to the stakes of the deployment context, not to an absolute standard.

The testing team's contribution to trustworthiness is producing evidence: documented test coverage, test results across quality dimensions, and unresolved risks. Deployment decisions are made by humans who weigh that evidence — but they cannot weigh evidence that was not collected.

@feynman

Trustworthiness is the answer to "should we deploy this?" — and testing's job is to make sure that answer is based on evidence, not optimism.

@card
id: tams-ch02-c012
order: 12
title: Mapping Quality Characteristics to Test Strategy
teaser: Not every AI system needs every quality test — the right test strategy comes from matching the system's risk profile, autonomy level, and deployment context to the quality characteristics that matter most for that specific case.

@explanation

A complete test strategy for an AI system starts by asking: which quality characteristics are most consequential for this system, and what is the cost of failure on each?

A practical mapping by system class:

- **High-stakes autonomous decision systems** (medical diagnosis, loan approval, parole decisions):
  - Bias and fairness testing is mandatory — errors fall disproportionately on already-vulnerable groups.
  - Explainability is required for auditability and regulatory compliance.
  - Adaptability testing is critical — the deployment population may differ from training data.
  - Side-effect analysis must include feedback loops and dependency creation.

- **Consumer recommendation systems** (content feeds, product recommendations, search ranking):
  - Bias testing for filter bubbles and over-representation of certain content.
  - Side-effect testing for engagement optimization harms.
  - Flexibility testing for cold-start and new-user scenarios.
  - Performance testing for latency at scale.

- **Developer and internal tooling** (code completion, log analysis, anomaly detection):
  - Flexibility and adaptability are the primary concerns — codebases and log formats evolve constantly.
  - Side-effects include developer over-reliance and incorrect-but-plausible output.
  - Trustworthiness bar is lower than patient-facing systems, but not zero.

- **Generative AI systems** (text, code, image generation):
  - Harm avoidance testing for prohibited content categories.
  - Bias testing in generated output distributions.
  - Privacy testing for training data memorization.
  - Explainability is limited by architecture — test what you can, document what you cannot.

The strategy should be documented before testing begins, reviewed with product owners and risk stakeholders, and revisited whenever the model, training data, or deployment context changes.

> [!tip] A test strategy that tries to cover every quality dimension with equal depth will be too expensive to run and too slow to ship. Prioritize by failure cost, not by completeness.

@feynman

Mapping quality to strategy is the discipline of deciding which failures would be catastrophic — and making sure those are the failures you tested hardest for.
