@chapter
id: tams-ch05-ml-functional-performance-metrics
order: 5
title: ML Functional Performance Metrics
summary: Accuracy is the metric that lies most often — and choosing the right metric for the system, knowing what each obscures, and reading a confusion matrix correctly are core skills for any tester signing off on an AI release.

@card
id: tams-ch05-c001
order: 1
title: Why Accuracy Lies
teaser: A model that predicts "not fraud" for every transaction can hit 99.9% accuracy on a fraud dataset — and catch zero frauds; accuracy is only honest when classes are balanced and errors cost the same.

@explanation

Accuracy — the fraction of all predictions that are correct — is the most intuitive metric and the most dangerous default. Its failure mode has two distinct causes.

**Class imbalance.** When one class represents a tiny fraction of the data, a model that never predicts that class still scores high. A medical screening dataset where 1% of patients have a rare condition rewards a model that labels everyone "healthy" with 99% accuracy. The model is useless, and accuracy conceals that completely.

**Asymmetric error costs.** Even with balanced classes, not all mistakes are equal. In a security context, a false negative (missing a real intrusion) may cost far more than a false positive (investigating a benign event). Accuracy treats both errors identically.

The practical consequence for testers:

- Before accepting accuracy as the exit criterion for an ML release, ask: what is the class distribution in production data?
- Ask: what does it cost to miss a positive versus to flag a false positive?
- If the answer to either question is "it's not balanced" or "costs differ," accuracy alone is insufficient and a more targeted metric must be chosen.

scikit-learn surfaces this easily: `sklearn.metrics.accuracy_score` will happily report 0.99 on a dataset where the minority class has zero correct predictions. Always pair it with a confusion matrix and at minimum one class-specific metric.

> [!warning] Reporting accuracy as the sole metric on an imbalanced dataset is a common way for a model to pass evaluation while failing in production. Require a breakdown by class before signing off.

@feynman

Accuracy lies whenever one type of mistake matters far more than another, or whenever one outcome is far rarer than the other.

@card
id: tams-ch05-c002
order: 2
title: The Confusion Matrix
teaser: The confusion matrix breaks every binary classification result into four cells — true positives, false positives, true negatives, and false negatives — and every classification metric is a formula built from those four numbers.

@explanation

For a binary classifier with a "positive" and "negative" class, every prediction falls into one of four outcomes:

```
                  Predicted Positive    Predicted Negative
Actual Positive        TP                    FN
Actual Negative        FP                    TN
```

- **TP (True Positive):** Model said positive, reality is positive. A correct alarm.
- **FP (False Positive):** Model said positive, reality is negative. A false alarm. Also called a Type I error.
- **FN (False Negative):** Model said negative, reality is positive. A missed detection. Also called a Type II error.
- **TN (True Negative):** Model said negative, reality is negative. A correct dismissal.

The total number of predictions is TP + FP + FN + TN. Accuracy is simply (TP + TN) / total.

Reading a confusion matrix in practice:

- Large FN count relative to TP: the model is missing real positives — dangerous in medical diagnosis or fraud detection.
- Large FP count relative to TN: the model is over-alerting — costly in spam filters or intrusion detection where analyst time is finite.
- A perfectly symmetric off-diagonal means errors are evenly distributed across types; asymmetry signals a systematic bias in one direction.

In scikit-learn: `sklearn.metrics.confusion_matrix(y_true, y_pred)` returns a 2x2 array in the layout above. `sklearn.metrics.ConfusionMatrixDisplay` renders it visually.

@feynman

The confusion matrix is the scoreboard beneath the scoreboard — it shows not just how often the model was right, but which specific kinds of wrong it made.

@card
id: tams-ch05-c003
order: 3
title: Precision
teaser: Precision answers the question "when the model fires an alarm, how often is it right?" — it measures the quality of positive predictions, and low precision means users learn to ignore the alerts.

@explanation

Precision is defined as:

```
Precision = TP / (TP + FP)
```

It is the fraction of predicted positives that are actually positive. A model with precision of 0.90 means that 90% of the items it flags are genuine positives — and 10% are false alarms.

Where precision matters most:

- **Spam filtering.** A spam filter with low precision sends legitimate email to junk. Users stop trusting the filter and disable it.
- **Recommendation systems.** Low-precision recommendations mean users see mostly irrelevant suggestions. Engagement drops.
- **Search ranking.** A search engine that returns mostly irrelevant results at the top has a precision problem.

Precision is blind to false negatives. A model that flags only one item — and gets it right — has precision of 1.0, regardless of how many real positives it missed. This is why precision is never evaluated in isolation.

In scikit-learn: `sklearn.metrics.precision_score(y_true, y_pred)`. For multi-class, specify `average='macro'`, `'micro'`, or `'weighted'` — the choice changes the result significantly.

The failure mode of optimizing solely for precision: the model becomes overly conservative, refusing to flag anything unless it is almost certain. Recall collapses. This is often what happens when a threshold is set too high.

@feynman

Precision measures how much you can trust the model when it says "yes" — a precise model that cries wolf rarely, but one with low precision cries wolf so often no one listens.

@card
id: tams-ch05-c004
order: 4
title: Recall (Sensitivity)
teaser: Recall answers the question "of all the real positives in the data, how many did the model actually catch?" — and low recall means real problems are slipping through undetected.

@explanation

Recall (also called sensitivity or true positive rate) is defined as:

```
Recall = TP / (TP + FN)
```

It is the fraction of actual positives that the model correctly identified. A recall of 0.85 means the model found 85% of the real positives and missed 15%.

Where recall matters most:

- **Medical diagnosis.** Missing a cancer case (false negative) has far graver consequences than an unnecessary follow-up (false positive). Systems like screening tools are optimized for high recall even at the cost of precision.
- **Fraud detection.** Missing fraudulent transactions lets damage accumulate; extra manual reviews are a tractable cost.
- **Safety-critical anomaly detection.** A sensor that misses a fault condition (high FN) is more dangerous than one that generates occasional false alerts.

Recall is blind to false positives. A model that flags every single item has recall of 1.0 — it missed nothing — but precision is likely terrible. This is the boundary case of a threshold set to zero (predict positive always).

In scikit-learn: `sklearn.metrics.recall_score(y_true, y_pred)`. The same averaging considerations as precision apply to multi-class settings.

> [!warning] Systems where missing a positive has severe consequences must have explicit recall floor requirements in the test exit criteria — not just an overall accuracy target.

@feynman

Recall measures how good the model is at finding the things it needs to find — a model with high recall lets very few real positives escape, even if it raises some false alarms along the way.

@card
id: tams-ch05-c005
order: 5
title: The Precision/Recall Tradeoff
teaser: Precision and recall are not independent — moving the classification threshold up increases precision and decreases recall; moving it down does the opposite; choosing the threshold is a product and risk decision, not a modeling one.

@explanation

Most classifiers do not output a hard class label directly. They output a probability score (e.g., 0.73 for "positive"), and a threshold — often 0.5 by default — converts that score into a label. Adjusting the threshold shifts the balance between precision and recall.

The tradeoff, stated directly:

- **Raise the threshold** (e.g., 0.5 to 0.8): the model only fires when it is highly confident. Fewer false positives — precision rises. But more real positives fall below the threshold and are missed — recall falls.
- **Lower the threshold** (e.g., 0.5 to 0.2): the model fires more readily. More real positives are caught — recall rises. But more false alarms are generated — precision falls.

This tradeoff is visualized in the Precision-Recall curve: a plot of precision (y-axis) against recall (x-axis) across all thresholds. A model with no skill produces a flat line at the baseline precision. A better model bows toward the upper-right corner.

The threshold is not a technical decision — it encodes a business judgment about relative error costs. For a tester, the questions to ask at release time are:

- Has the business defined the acceptable FP rate and FN rate independently?
- Has the threshold been set to satisfy those requirements — not simply left at the default 0.5?
- Has this threshold been validated on a held-out test set, not the validation set used for tuning?

In scikit-learn: `sklearn.metrics.precision_recall_curve(y_true, y_scores)` returns arrays that can be plotted directly.

@feynman

The precision/recall tradeoff is like adjusting a burglar alarm's sensitivity — turn it up and it triggers on the wind (false positives spike); turn it down and a real burglar can walk past it (false negatives spike).

@card
id: tams-ch05-c006
order: 6
title: F1 Score
teaser: The F1 score is the harmonic mean of precision and recall — it gives a single number that balances both, but because it weights them equally it can mislead when the costs of false positives and false negatives differ.

@explanation

F1 is defined as:

```
F1 = 2 * (Precision * Recall) / (Precision + Recall)
```

Equivalently: `F1 = 2*TP / (2*TP + FP + FN)`.

Why the harmonic mean rather than the arithmetic mean? The harmonic mean punishes extreme imbalances more severely. A model with precision 1.0 and recall 0.01 has an arithmetic mean of 0.505, which sounds passable. Its harmonic mean (F1) is 0.02 — correctly reflecting that the model is nearly useless.

When F1 is a good choice:

- Binary classification tasks where false positives and false negatives have roughly equal cost.
- Tasks where you want a single number to compare model versions, and the class distribution is moderately balanced.
- Information retrieval and NLP benchmarks, where F1 is a longstanding convention.

When F1 is the wrong choice:

- When FP and FN costs are asymmetric. In that case, use the generalized Fbeta score: `F_beta = (1 + beta^2) * (Precision * Recall) / (beta^2 * Precision + Recall)`. A beta greater than 1 weights recall more heavily; less than 1 weights precision.
- When the negative class also matters. F1 entirely ignores true negatives. For tasks where correct dismissals have value, consider Matthews Correlation Coefficient (MCC) instead.

In scikit-learn: `sklearn.metrics.f1_score(y_true, y_pred)`, `sklearn.metrics.fbeta_score(y_true, y_pred, beta=2.0)`.

@feynman

The F1 score is a single report card grade that blends precision and recall — useful for quick comparisons, but it quietly assumes both types of error are equally costly, which is often not true.

@card
id: tams-ch05-c007
order: 7
title: AUC-ROC
teaser: The ROC curve shows how a classifier's true positive rate and false positive rate change across every possible threshold — and AUC summarizes that into one number that is independent of any specific threshold choice.

@explanation

The Receiver Operating Characteristic (ROC) curve plots:

- **Y-axis:** True Positive Rate (TPR = Recall = TP / (TP + FN))
- **X-axis:** False Positive Rate (FPR = FP / (FP + TN))

across every threshold from 0 to 1. Each point on the curve represents a different threshold setting. A perfect classifier reaches the top-left corner (TPR = 1, FPR = 0). A random classifier traces the diagonal (TPR = FPR at all thresholds).

The Area Under the ROC Curve (AUC-ROC, often just "AUC") summarizes the entire curve as a single scalar:

- **AUC = 1.0:** Perfect classifier — some threshold achieves zero FPR with 100% TPR.
- **AUC = 0.5:** No better than random guessing.
- **AUC < 0.5:** Worse than random — suggests inverted labels or a serious model defect.

What AUC measures, intuitively: given a randomly chosen positive example and a randomly chosen negative example, AUC is the probability that the classifier assigns a higher score to the positive example.

AUC-ROC is threshold-independent and scale-invariant, making it useful for comparing models regardless of operating point. However, it has a known weakness: on heavily imbalanced datasets, a model can achieve high AUC while performing poorly on the minority class. The false positive rate denominator (FP + TN) is dominated by the large negative class, masking how many positives are actually being caught relative to how many positives exist.

In scikit-learn: `sklearn.metrics.roc_auc_score(y_true, y_scores)`, `sklearn.metrics.roc_curve(y_true, y_scores)`.

@feynman

AUC-ROC asks: across every possible alarm threshold, how well does this model rank real positives above real negatives — the closer the score to 1.0, the better the model is at separating the two classes regardless of where you set the cutoff.

@card
id: tams-ch05-c008
order: 8
title: AUC-PR
teaser: The Precision-Recall curve and its area under the curve (AUC-PR) surface the performance of a classifier on the minority class directly — making it the right choice when positive examples are rare and AUC-ROC is overly optimistic.

@explanation

The Precision-Recall (PR) curve plots precision (y-axis) against recall (x-axis) across all thresholds, and AUC-PR is the area under that curve. A higher AUC-PR indicates a model that maintains high precision as recall increases.

Why AUC-PR outperforms AUC-ROC on imbalanced data:

The ROC curve's x-axis is False Positive Rate: FP / (FP + TN). With a large TN pool (many negatives), FPR can remain low even when FP counts are substantial — the denominator absorbs the problem. The PR curve replaces FPR with precision: TP / (TP + FP). Precision is directly sensitive to false positives and has no TN term. It cannot be inflated by a large negative class.

Baseline comparison:

- For AUC-ROC, the random baseline is always 0.5.
- For AUC-PR, the random baseline equals the fraction of positives in the dataset. For a 1% positive rate dataset, a random classifier has AUC-PR of 0.01. A model with AUC-PR of 0.35 is far better than random, even though 0.35 sounds low.

When to prefer AUC-PR:

- Fraud detection, rare disease screening, anomaly detection, or any task where positive examples represent less than 10-20% of the dataset.
- When the operational cost of false positives is high and the actual precision at operating recall levels is the primary concern.

In scikit-learn: `sklearn.metrics.average_precision_score(y_true, y_scores)` computes AUC-PR via the trapezoidal rule. `sklearn.metrics.precision_recall_curve` returns the raw arrays.

> [!info] If your dataset has fewer than 10% positive examples, treat AUC-PR as your primary ranking metric for model comparison and AUC-ROC as secondary context.

@feynman

AUC-PR is the honest version of AUC-ROC for rare-event problems — it strips out the easy wins against the massive sea of true negatives and forces the model to prove it can find the needles, not just avoid the haystack.

@card
id: tams-ch05-c009
order: 9
title: Specificity and False Positive Rate
teaser: Specificity — the true negative rate — and its complement, the false positive rate, measure how well the model avoids false alarms; they are often overlooked but essential in high-stakes screening and security contexts.

@explanation

Specificity (True Negative Rate) is defined as:

```
Specificity = TN / (TN + FP)
```

It answers: of all the actual negatives, what fraction did the model correctly label as negative? A specificity of 0.95 means the model correctly clears 95% of true negatives and generates false alarms on only 5%.

False Positive Rate (FPR) is the complement:

```
FPR = FP / (FP + TN) = 1 - Specificity
```

Where specificity matters:

- **Medical screening.** A test with high recall but low specificity sends many healthy patients for expensive and stressful follow-up procedures. For a population-scale screening program, even 5% FPR across millions of tests is a significant operational burden.
- **Intrusion detection systems (IDS).** Security analysts have finite capacity. A system with low specificity generates so many false alerts that real incidents are buried in noise — alert fatigue is a well-documented failure mode.
- **Content moderation.** Incorrectly flagging legitimate user content (high FPR) damages user trust and creates legal exposure.

The standard way to jointly evaluate TPR and specificity across thresholds is the ROC curve, where the x-axis is FPR and the y-axis is TPR. Any movement along the ROC curve that improves TPR will degrade specificity and increase FPR — the fundamental tradeoff.

Precision and specificity are often confused. Precision focuses on the predicted positive pool; specificity focuses on the actual negative pool. They ask different questions and can move independently.

@feynman

Specificity measures how good the model is at clearing innocent cases — a low-specificity system cries wolf so often it overwhelms the people responsible for responding.

@card
id: tams-ch05-c010
order: 10
title: Threshold Selection and Calibration
teaser: Most classifiers output probabilities, not class labels — and the threshold that converts a probability into a decision is a tunable parameter that encodes business risk preferences, not a number that should stay at 0.5 by default.

@explanation

A classifier like logistic regression or a neural network with a softmax output does not actually decide classes — it outputs a score between 0 and 1. The classification threshold is applied afterward to produce a hard label. The default of 0.5 is arbitrary and rarely optimal for production use.

**Threshold selection in practice:**

The precision-recall curve and the ROC curve both show model behavior across every possible threshold. The appropriate operating threshold is the one where the resulting precision and recall (or TPR and FPR) satisfy the business requirements. This is a business decision that testers should demand is documented explicitly.

Common threshold selection strategies:

- **Fixed business constraint:** "We cannot miss more than 5% of fraud cases." Set the threshold at the point where recall = 0.95 on the validation set.
- **Equal error rate (EER):** The threshold where FPR equals FNR. Common in biometric systems.
- **F-score maximization:** Set the threshold that maximizes F1 or Fbeta on the validation set.
- **Cost-sensitive selection:** Given explicit FP cost and FN cost, find the threshold that minimizes expected cost.

**Calibration** is a related concept: a well-calibrated model means that a predicted probability of 0.7 actually corresponds to about 70% of examples in that bin being positive. A poorly calibrated model may output high confidence scores that do not correspond to real probabilities, making threshold selection unreliable. Reliability diagrams (calibration curves) and the Brier score assess calibration. `sklearn.calibration.CalibratedClassifierCV` and `sklearn.calibration.calibration_curve` are the relevant tools.

> [!warning] Deploying a model with the default threshold of 0.5 without examining the operating precision and recall at that threshold on production-representative data is an incomplete release process.

@feynman

The classification threshold is the dial that converts a model's probability scores into actual decisions — and leaving it at 0.5 because that is the default is like setting the speed limit based on what number is printed on the speedometer rather than the road conditions.

@card
id: tams-ch05-c011
order: 11
title: Regression Metrics — MAE, MSE, RMSE, and R²
teaser: Regression models predict continuous values, not classes — and the choice between MAE, MSE, and RMSE is really a choice about how much to penalize large errors, while R² tells you how much of the variance the model actually explains.

@explanation

For regression tasks (predicting a number rather than a label), classification metrics do not apply. The standard metrics are:

**MAE — Mean Absolute Error:**
```
MAE = mean(|y_true - y_pred|)
```
Every error contributes proportionally to its magnitude. Robust to outliers. Easy to interpret — "on average, predictions are off by X units." Use when large errors are not disproportionately worse than small ones.

**MSE — Mean Squared Error:**
```
MSE = mean((y_true - y_pred)^2)
```
Squares each error before averaging, so large errors contribute far more than small ones. Heavily penalizes outliers. Commonly used as a training loss for the same reason: gradient descent will work hard to eliminate large errors.

**RMSE — Root Mean Squared Error:**
```
RMSE = sqrt(MSE)
```
Restores the units to the original scale (same units as the target variable). More interpretable than MSE. Still penalizes large errors more heavily than MAE. Use when large errors are genuinely worse and you want the metric in the original unit scale.

**R² — Coefficient of Determination:**
```
R^2 = 1 - (SS_res / SS_tot)
```
Measures the proportion of variance in the target that the model explains. An R² of 0.85 means the model accounts for 85% of the variance. R² = 1.0 is a perfect fit; R² = 0.0 means the model is no better than predicting the mean; R² can be negative if the model is worse than predicting the mean.

R² is scale-independent, useful for comparing models on different datasets, but it does not indicate whether the absolute prediction errors are acceptable for the business use case.

In scikit-learn: `sklearn.metrics.mean_absolute_error`, `mean_squared_error`, `root_mean_squared_error` (sklearn 1.4+), `r2_score`.

@feynman

Regression metrics all measure how far predictions land from reality — MAE counts distance fairly, RMSE punishes overshoots heavily, and R² tells you how much of the target's natural variation the model actually explains.

@card
id: tams-ch05-c012
order: 12
title: Multi-Class and Multi-Label Metrics — Micro vs Macro Averaging
teaser: When a model classifies across three or more classes, or assigns multiple labels at once, the averaging strategy you choose — micro or macro — can change the reported metric dramatically, and the wrong choice hides poor performance on minority classes.

@explanation

**Multi-class classification** has one label per example from three or more classes (e.g., image classification: cat / dog / bird). Metrics like precision, recall, and F1 must be extended from the binary case.

Two primary averaging strategies:

**Macro averaging** — compute the metric independently for each class, then take the unweighted mean:
```
Macro F1 = mean(F1_class1, F1_class2, ..., F1_classN)
```
Every class contributes equally to the final score, regardless of how many examples it has. A minority class with 50 examples has the same weight as a majority class with 50,000. Macro averaging is honest about minority class performance and will surface failures there — but the metric can be driven down by rare classes that may matter less operationally.

**Micro averaging** — aggregate TP, FP, and FN counts across all classes first, then compute the metric from the aggregate:
```
Micro F1 = 2 * sum(TP_i) / (2 * sum(TP_i) + sum(FP_i) + sum(FN_i))
```
Micro averaging weights each example equally, so majority classes dominate the result. A model that is excellent on the large classes but terrible on small classes will still score well under micro averaging.

**Weighted averaging** — like macro, but each class is weighted by its support (number of examples). A middle ground, but can still obscure poor minority class performance.

**Multi-label classification** assigns zero or more labels to each example (e.g., a news article tagged "politics", "economy", and "health" simultaneously). This requires label-by-label evaluation followed by an appropriate aggregation, and metrics like Hamming loss (fraction of labels that are incorrectly predicted) and subset accuracy (fraction of examples where every label is exactly right) become relevant.

Pitfalls for testers:

- Always ask: which averaging is being reported? Micro F1 on an imbalanced dataset may look excellent while the minority class has recall near zero.
- Report per-class metrics alongside the aggregate — `sklearn.metrics.classification_report(y_true, y_pred)` does this in one call.
- For multi-label: confirm that subset accuracy versus partial-match credit is appropriate for the use case.

In scikit-learn: `sklearn.metrics.f1_score(y_true, y_pred, average='macro')`, `average='micro'`, `average='weighted'`. For multi-label: `sklearn.metrics.multilabel_confusion_matrix`, `hamming_loss`.

@feynman

Macro averaging grades each class like a student in a class of equals; micro averaging grades the whole school by counting every correct answer, so the big classes set the curve — and the struggling minority class can fail invisibly.
