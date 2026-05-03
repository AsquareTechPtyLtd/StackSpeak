@chapter
id: tams-ch06-bias-fairness-and-explainability
order: 6
title: ML — Bias, Fairness, and Explainability
summary: Bias, fairness, and explainability are the three quality characteristics that turn AI testing from a technical discipline into a regulated one — and the metrics, tools, and tradeoffs are different enough from classical metrics that testers need a separate toolkit.

@card
id: tams-ch06-c001
order: 1
title: Fairness Is Not One Thing
teaser: "Fairness" in ML has at least six mathematically distinct definitions — and satisfying one often makes it impossible to satisfy another.

@explanation

When a regulator, an auditor, or a product manager says a model must be "fair," they are making an underspecified demand. The machine learning literature has formalised at least six distinct fairness criteria — demographic parity, equalized odds, predictive parity, individual fairness, calibration, and counterfactual fairness — and each captures a different moral intuition about what equal treatment means.

This is not a gap waiting to be filled by a better definition. The Kleinberg-Mullainathan-Raghavan impossibility result (2016) proves that most of these definitions cannot hold simultaneously when base rates differ across groups. Any project that requires a model to be "fair" must begin by choosing which fairness definition it is optimising for and accepting that others will be violated — sometimes severely.

The practical consequence for testers:

- **Fairness requirements must be stated precisely** in the acceptance criteria, not left as "the model must be unbiased."
- **Testing against a single metric does not establish fairness overall.** Report the values of all major fairness metrics even if only one is a hard requirement.
- **Stakeholders disagree** on which definition is correct. That disagreement is a product and legal risk, not a testing question — but testers surface it by reporting the full picture.

Tools such as Fairlearn and IBM AIF360 compute multiple fairness metrics simultaneously, making it straightforward to expose conflicts during evaluation.

> [!warning] A model that passes one fairness metric while failing others is not a "partially fair" model — it is a model that satisfies one definition and violates others. Report all metrics, not just the one that passes.

@feynman

Fairness in ML is like "healthy eating" — everyone agrees it matters, but the moment you define it precisely enough to measure, you find that optimising for one definition (low sodium) can conflict with another (high protein), and the right balance depends on whose values you are serving.

@card
id: tams-ch06-c002
order: 2
title: Protected Attributes and Legal Context
teaser: Protected attributes are the input features — or proxies for them — whose use in predictions is constrained by law, and testing must account for indirect discrimination as well as direct.

@explanation

A protected attribute is a characteristic that anti-discrimination law prohibits using as a basis for consequential decisions. The specific list varies by jurisdiction and context:

- **United States:** Title VII of the Civil Rights Act (1964) covers race, color, religion, sex, and national origin in employment. Fair Housing Act adds similar protections for housing. Age Discrimination in Employment Act covers age (40+). The Equal Credit Opportunity Act adds further protections in lending.
- **European Union:** GDPR Article 9 designates race, ethnic origin, political opinions, religion, trade union membership, health, sex life, and sexual orientation as "special category" data requiring explicit consent or another lawful basis for processing. The EU AI Act (as of 2026-Q2, fully applicable for high-risk systems) requires bias testing and logging for high-risk AI systems as defined in Annex III.
- **UK:** Equality Act 2010 defines nine protected characteristics including age, disability, gender reassignment, race, religion, sex, and sexual orientation.

Two forms of discrimination matter for testing:

- **Direct discrimination:** The protected attribute is used explicitly as a model feature.
- **Indirect discrimination (proxy discrimination):** A correlated feature — postal code, name, browsing history — effectively encodes the protected attribute without naming it.

Testing for indirect discrimination requires more than inspecting the feature list. It requires measuring outcome disparities across protected groups even when the protected attribute itself is absent from training.

@feynman

A protected attribute is like a question you are legally prohibited from asking in a job interview — but ML models can still effectively ask that question by learning from features that are highly correlated with the answer.

@card
id: tams-ch06-c003
order: 3
title: Demographic Parity
teaser: Demographic parity requires that the model's positive prediction rate is equal across groups — it is the simplest fairness definition and the easiest to game.

@explanation

Demographic parity (also called statistical parity or group fairness) states that the proportion of positive predictions must be equal across protected groups. If a hiring model predicts "will be hired" for 40% of male applicants, it must also predict "will be hired" for 40% of female applicants.

Formally, for groups A and B:

P(Y_hat = 1 | group = A) = P(Y_hat = 1 | group = B)

What demographic parity does:

- It is interpretable to non-technical stakeholders and regulators.
- It can be measured without knowing the true labels — useful when ground truth is itself biased.
- It is the basis for the "80% rule" (four-fifths rule) in US EEOC employment guidance, which flags adverse impact when the selection rate for a protected group is below 80% of the highest group's rate.

What demographic parity does not fix:

- It does not account for actual qualification differences between groups if those differences are legitimate and not themselves the product of historical discrimination.
- A model can satisfy demographic parity while having very different error rates across groups — approving equally many people from each group while denying the most-qualified members of one group and the least-qualified members of another.
- It can be satisfied trivially by a random classifier, or by adjusting predictions arbitrarily at the group level without improving model accuracy.

Fairlearn's `MetricFrame` class and IBM AIF360's `BinaryLabelDatasetMetric` both measure demographic parity as a standard output.

@feynman

Demographic parity is like requiring a school to admit equal percentages of students from every neighborhood — it ensures equal representation at the door, but says nothing about whether the admissions decisions were individually fair or accurate.

@card
id: tams-ch06-c004
order: 4
title: Equalized Odds
teaser: Equalized odds requires equal true positive rates and equal false positive rates across groups — it is the harder fairness criterion because it conditions on the true outcome.

@explanation

Equalized odds, defined by Hardt et al. (2016), requires that both the true positive rate (TPR) and the false positive rate (FPR) are equal across protected groups. It is a stricter criterion than demographic parity because it conditions on the actual ground-truth label.

Formally, for groups A and B, and ground truth Y:

P(Y_hat = 1 | Y = 1, group = A) = P(Y_hat = 1 | Y = 1, group = B)  [equal TPR]
P(Y_hat = 1 | Y = 0, group = A) = P(Y_hat = 1 | Y = 0, group = B)  [equal FPR]

Why it is harder:

- It requires knowledge of the true outcome, which may itself be contaminated by historical bias in labelling.
- It is impossible to satisfy equalized odds, demographic parity, and predictive parity simultaneously when base rates differ across groups — this is the core of the impossibility result.

Variants of equalized odds are used as the primary criterion in high-stakes contexts:

- **Equal opportunity** is a relaxed version that requires only equal TPR (you get the benefit if you deserve it equally), while ignoring FPR.
- **Equalized odds** is preferred when both false positives and false negatives impose meaningful harms — for example, a recidivism model that both wrongly imprisons innocents and wrongly releases dangerous individuals.

Testing for equalized odds requires a test dataset with reliable ground-truth labels for all groups being compared, which is a data quality requirement as much as a metric computation.

> [!info] "Equal opportunity" (equal TPR only) is often more achievable than full equalized odds and is the right target when false positives and false negatives have asymmetric costs.

@feynman

Equalized odds is like requiring that a medical test catch the same percentage of sick patients and produce the same percentage of false alarms in every demographic group — it is not enough that the test is used equally; it must perform equally.

@card
id: tams-ch06-c005
order: 5
title: Predictive Parity and the COMPAS Controversy
teaser: Predictive parity requires equal precision across groups — the COMPAS recidivism case showed that satisfying it is compatible with dramatically unequal false positive rates.

@explanation

Predictive parity (also called calibration across groups) requires that when a model predicts a positive outcome, it is correct at the same rate for all groups. If a model labels someone as "high risk of reoffending," that label should be equally accurate regardless of the defendant's race.

Formally:

P(Y = 1 | Y_hat = 1, group = A) = P(Y = 1 | Y_hat = 1, group = B)

The COMPAS controversy (ProPublica, 2016) is the defining case study. ProPublica's analysis of the COMPAS recidivism scoring tool used by US courts found:

- Black defendants were nearly twice as likely as white defendants to be falsely flagged as high risk (false positive rate disparity).
- White defendants were more likely to be incorrectly labelled low risk and go on to reoffend (false negative rate disparity).

Northpointe (the vendor) and researchers Dieterich, Cowgill, and colleagues responded that COMPAS did satisfy predictive parity — the accuracy of the "high risk" label was roughly equal across racial groups. Both analyses were correct. The dataset had different base rates of recidivism across groups, which makes equalized odds and predictive parity mathematically incompatible. Each side was measuring a different criterion.

The COMPAS case is now a canonical example used in ISTQB® CT-AI materials to illustrate that fairness metric selection is a normative (value-laden) choice, not a purely technical one.

> [!warning] Satisfying predictive parity does not imply equal error rates. When base rates differ across groups, meeting one of these criteria mathematically prevents meeting the other.

@feynman

Predictive parity says a weather forecaster is fair if "70% chance of rain" is equally accurate in every city — but two cities can have equal forecast accuracy while one city's residents are caught in far more unexpected downpours than the other's.

@card
id: tams-ch06-c006
order: 6
title: The Fairness-Impossibility Result
teaser: Kleinberg et al. proved that when base rates differ across groups, no classifier can simultaneously satisfy calibration, equal false positive rates, and equal false negative rates — you must choose.

@explanation

In 2016, Jon Kleinberg, Sendhil Mullainathan, and Manish Raghavan published a formal proof that three seemingly reasonable fairness criteria cannot be simultaneously satisfied except in degenerate cases. The same result was independently established by Chouldechova (2017).

The three criteria in conflict:

1. **Calibration (predictive parity):** The score means the same thing across groups.
2. **Balance for the positive class (equal TPR):** Qualified individuals are identified at equal rates.
3. **Balance for the negative class (equal FPR):** Unqualified individuals are wrongly flagged at equal rates.

The impossibility holds whenever the prevalence of the positive outcome (the base rate) differs across groups. This is nearly always the case in real-world socially consequential prediction tasks — crime, credit, disease, job performance — because those outcomes reflect historical inequality, economic disparity, and measurement bias.

Implications for testing:

- **There is no "fair" model in the absolute sense** when base rates differ. There is only a model that satisfies specific, chosen criteria and violates others.
- **Acceptance criteria must state which fairness definition applies.** A test that checks one definition and declares the model "fair" is incomplete.
- **The choice of fairness definition is a policy decision**, not a technical one. It belongs in the product specification, not the test script.

The result does not mean fairness is impossible. It means fairness requires explicit value choices, and those choices have distributional consequences that testing must document.

@feynman

The fairness impossibility result is like trying to design a grading curve that gives every demographic group the same average grade, the same pass rate, and the same proportion of As — it is mathematically blocked when the groups start with different score distributions, so you have to decide which equality matters most.

@card
id: tams-ch06-c007
order: 7
title: Bias Mitigation Techniques
teaser: Bias can be addressed before training (pre-processing), during training (in-processing), or after training (post-processing) — each has different tradeoffs in accuracy cost, regulatory legibility, and implementation difficulty.

@explanation

Bias mitigation techniques fall into three phases of the ML pipeline:

**Pre-processing (data-level):**
Modify the training data before model training. Techniques include:
- **Reweighting** — assign higher sample weights to underrepresented or disadvantaged group members so the model sees them as more important during training. IBM AIF360 implements several reweighting and resampling strategies.
- **Disparate impact remover** — transforms feature values to reduce correlation with the protected attribute while preserving rank ordering.
- **Learning fair representations (LFR)** — encodes data into a representation that obfuscates the protected attribute while retaining predictive signal.

**In-processing (model-level):**
Add fairness as a constraint or regularisation term during training.
- **Fairness constraints** — use a constrained optimisation framework that penalises disparities in TPR, FPR, or demographic parity. Fairlearn's `ExponentiatedGradient` and `GridSearch` estimators implement this approach.
- **Adversarial debiasing** — add an adversarial branch to the model that is trained to predict the protected attribute; the main model is penalised for making its representation useful to the adversary.

**Post-processing (prediction-level):**
Adjust model outputs after training without changing the model itself.
- **Threshold tuning** — apply different classification thresholds per group to equalise a chosen fairness metric. This is the most interpretable approach and is easy to audit, but requires access to group membership at prediction time.
- **Reject option classification** — for predictions near the decision boundary, shift the prediction in the direction that benefits the disadvantaged group.

> [!tip] Post-processing threshold tuning is often the fastest path to demonstrable fairness improvement in a deployed system, but regulators may scrutinise explicit group-based threshold differences as a form of disparate treatment — confirm legal review before deployment.

@feynman

Bias mitigation is like correcting a skewed scale: you can fix the raw ingredients before they go on the scale (pre-processing), recalibrate the mechanism while it is being built (in-processing), or apply a correction factor to every reading it produces (post-processing) — each option works, but each touches a different part of the system.

@card
id: tams-ch06-c008
order: 8
title: Explainability — Global vs Local, Intrinsic vs Post-hoc
teaser: Explainability methods differ on two axes — whether they explain the whole model or a single prediction, and whether the explanation is built in or bolted on after training.

@explanation

Explainability describes the degree to which the internal workings of a model can be understood and communicated. The ML testing literature distinguishes two orthogonal dimensions:

**Global vs local:**
- **Global explanations** describe the overall behaviour of a model: which features matter most on average, how feature values relate to the output across the whole dataset. Decision tree depth, linear regression coefficients, and feature importance plots are global.
- **Local explanations** describe a single prediction: why did the model assign this specific person a low credit score? SHAP and LIME both produce local explanations, though SHAP can be aggregated for global views.

**Intrinsic vs post-hoc:**
- **Intrinsic explainability** means the model is interpretable by design — linear regression, logistic regression, shallow decision trees, and rule-based systems. You can read the model itself. Intrinsic models trade off expressiveness: they are often less accurate on complex problems.
- **Post-hoc explainability** means training an opaque model (gradient boosted trees, deep neural networks) and then applying a separate method to approximate or describe its behaviour — SHAP, LIME, Captum, saliency maps. The explanation is an approximation, not the model itself.

Why this matters for testing:

- An intrinsic explanation can be directly verified — you can check that the model uses features in the expected direction. A post-hoc explanation is itself an ML artefact and can be inaccurate or misleading; it requires its own validation.
- Regulated contexts (EU AI Act high-risk, GDPR right to explanation) typically require local explanations for individual decisions. Testing must confirm that the explanation system produces coherent, stable, and accurate attributions.

@feynman

Global explainability tells you how a weather forecasting system makes predictions in general; local explainability tells you exactly why it predicted rain on your specific street at 3pm — and for a regulated decision, the local explanation is the one that ends up in court.

@card
id: tams-ch06-c009
order: 9
title: SHAP — Shapley Values for Feature Attribution
teaser: SHAP assigns each feature a contribution to a specific prediction based on Shapley values from cooperative game theory — it is the most theoretically principled post-hoc explanation method and the most computationally expensive.

@explanation

SHAP (SHapley Additive exPlanations), introduced by Lundberg and Lee (2017), computes the contribution of each feature to an individual prediction by averaging that feature's marginal contribution across all possible orderings in which it could be introduced.

The Shapley value for feature i is:

phi_i = sum over all subsets S not containing i of [|S|! * (n - |S| - 1)! / n!] * [f(S union {i}) - f(S)]

Where f(S) is the model's prediction using only features in subset S. In plain terms: for each way you could assemble the feature set, measure how much adding feature i changes the prediction, then take the weighted average.

Properties that make SHAP useful for regulated settings:

- **Efficiency:** The contributions sum to the difference between the prediction and the expected model output, ensuring no "missing" attribution.
- **Symmetry:** Features with identical contributions receive identical attributions.
- **Dummy:** Features that have no effect on any prediction receive zero attribution.
- **Linearity:** Contributions from additive model components can be summed.

Model-specific variants make SHAP tractable in practice:
- **TreeSHAP** — exact, polynomial-time computation for tree-based models (XGBoost, LightGBM, scikit-learn trees). This is the fast path.
- **DeepSHAP / GradientSHAP** — for neural networks; uses DeepLIFT or gradient backpropagation as an approximation.
- **KernelSHAP** — model-agnostic; slower, sampling-based.

The SHAP Python library is the standard implementation. Captum provides SHAP-equivalent attribution for PyTorch models.

@feynman

SHAP is like calculating each person's contribution to a group project by trying every possible order in which people could have joined the team and averaging how much the outcome improved each time that person showed up — rigorous, fair, and exhausting to compute by hand.

@card
id: tams-ch06-c010
order: 10
title: LIME — Local Surrogate Explanations
teaser: LIME explains a single prediction by fitting a simple interpretable model to perturbed inputs around it — it is faster and model-agnostic, but the explanation is a local approximation, not a ground truth.

@explanation

LIME (Local Interpretable Model-agnostic Explanations), introduced by Ribeiro, Singh, and Guestrin (2016), explains an individual prediction by generating a neighbourhood of perturbed inputs around it, getting predictions from the black-box model for each, and fitting a simple interpretable model (typically a sparse linear model) to that local dataset.

The process for a single prediction x:

1. Generate N samples by perturbing the input x (e.g., masking words in text, superpixel regions in images, or adding noise to tabular features).
2. Get the black-box model's prediction for each perturbed sample.
3. Weight samples by their proximity to x.
4. Fit a sparse linear model to the (perturbed input, prediction) pairs.
5. Report the linear model's coefficients as the explanation.

Key properties and limitations:

- **Model-agnostic:** Works with any black-box model — no access to gradients or internals required.
- **Locally faithful:** The explanation accurately describes the model in the neighbourhood of x, but may not hold globally.
- **Instability:** Two runs of LIME on the same prediction can produce different explanations because the neighbourhood sampling is random. Testing LIME-based explanation systems should include stability checks across repeated runs.
- **Neighbourhood definition is consequential:** How you perturb tabular features (marginal vs conditional sampling) affects what "similar" means and can produce misleading explanations.

LIME is available as the `lime` Python package. It handles tabular, text, and image data with different perturbation strategies per modality.

> [!info] LIME's instability is a known limitation. If your regulated system uses LIME, test that explanation variance across runs is within acceptable bounds before relying on it for audit trails.

@feynman

LIME explains a black-box model the way you might explain a complicated foreign city by drawing a rough map of just the few blocks around where you are standing — accurate and useful for your immediate location, but not a reliable guide to the whole city.

@card
id: tams-ch06-c011
order: 11
title: Counterfactual Explanations
teaser: A counterfactual explanation answers "what is the minimum change to my input that would flip the model's decision?" — it is the explanation format most directly useful to the person affected by a decision.

@explanation

A counterfactual explanation does not explain why a model made a decision in terms of internal weights or feature importances. Instead, it presents an alternative scenario: "If your income had been $5,000 higher and your loan term two years shorter, the application would have been approved."

This framing has several advantages in regulated contexts:

- **Actionable:** The person receiving a negative decision learns what they can change, which aligns with GDPR's "right to explanation" and "right not to be subject to automated decision-making" requirements.
- **No model access required:** Counterfactual methods only need to query the model as a black box, making them model-agnostic.
- **Legally legible:** A counterfactual is more directly understandable to a judge, regulator, or affected person than a vector of Shapley values.

Properties a good counterfactual must satisfy:

- **Validity:** The counterfactual actually flips the prediction.
- **Proximity:** The change from the original input is as small as possible.
- **Sparsity:** As few features as possible are changed.
- **Plausibility:** The counterfactual is a realistic input (you cannot explain a credit decision by suggesting the applicant change their age to 200).
- **Actionability:** Changes are limited to features the person can actually control.

Wachter, Mittelstadt, and Russell (2017) formalised counterfactual explanations for ML. DiCE (Diverse Counterfactual Explanations, Microsoft) is a commonly used implementation that generates multiple diverse counterfactuals simultaneously.

@feynman

A counterfactual explanation is like a loan officer saying "if you had applied for $10,000 less and had one more year of credit history, we would have approved you" — it tells you not why you were refused, but what would have made you succeed.

@card
id: tams-ch06-c012
order: 12
title: Auditability for Regulated AI
teaser: The EU AI Act classifies certain AI systems as high-risk and requires documented bias testing, explanation capabilities, human oversight, and record-keeping — and as of 2026-Q2, those requirements are actively enforced for systems that went to market after August 2026.

@explanation

As of 2026-Q2, the EU AI Act is the most comprehensive binding regulation on AI systems globally. It introduces a risk-based classification:

- **Unacceptable risk** (prohibited): Real-time biometric surveillance in public spaces, social scoring by governments, subliminal manipulation.
- **High risk** (Annex III): AI used in biometric identification, critical infrastructure, education (admissions, assessment), employment (hiring, promotion), essential services (credit, insurance), law enforcement, migration, and justice. High-risk systems require conformity assessment before market entry.
- **Limited/minimal risk:** Most commercial AI; subject to transparency obligations but not pre-market assessment.

What auditors check for high-risk systems (as of 2026-Q2):

- **Risk management documentation** — a formal risk management system maintained throughout the lifecycle.
- **Data governance records** — training, validation, and test dataset documentation including known limitations and potential biases.
- **Technical documentation** — system purpose, design choices, performance metrics, and known limitations filed before deployment.
- **Logging and record-keeping** — high-risk systems must automatically log events sufficient to identify risks and enable post-market monitoring.
- **Human oversight provisions** — mechanisms allowing a human to override, correct, or shut down the system.
- **Bias and fairness test results** — documented evaluation on the protected characteristics relevant to the use case.
- **Explanation capabilities** — ability to produce explanations for individual decisions on request from a regulatory body or affected individual.

GDPR Article 22 adds a parallel requirement: individuals subject to solely automated decisions with legal or similarly significant effects have the right to a meaningful explanation and the right to contest the decision.

Tools such as IBM AIF360, Fairlearn, Aequitas, and Microsoft's InterpretML are referenced in technical guidance as appropriate for generating the documented bias evaluations regulators expect.

> [!warning] As of 2026-Q2, GDPR's right-to-explanation obligation applies immediately upon deployment for any automated decision with legal or significant effects on individuals in the EU — it does not wait for a conformity assessment. A system without a working explanation pathway is non-compliant on day one.

@feynman

Auditability for regulated AI is like the safety dossier required before a new drug reaches pharmacy shelves — the medicine might work perfectly, but without documented testing, logged outcomes, and a clear protocol for withdrawing it if something goes wrong, it cannot legally be sold.
