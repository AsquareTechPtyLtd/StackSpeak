@chapter
id: aiadg-ch03-planning-depth
order: 3
title: Planning Depth
summary: Test-time compute, tree search, and trajectory-based improvement — the techniques that turn a reactive agent into one that thinks ahead.

@card
id: aiadg-ch03-c001
order: 1
title: Reactive vs Deliberate
teaser: A reactive agent answers from instinct. A deliberate agent simulates a few moves ahead before committing. Most production agents are still reactive — and most production failures come from that.

@explanation

A reactive agent reads the state, picks the next tool, executes, repeats. It works for the 80% of tasks that resolve in two or three obvious steps. The other 20% — multi-step reasoning, choices with non-obvious consequences, plans that need to be re-checked against constraints — is where reactivity falls apart. The model commits to step 1 before it has any way to know that step 5 will fail.

A deliberate agent inserts a planning phase: it sketches several possible plans, scores them, picks one, and only then begins execution. The cost is one extra model call. The benefit is that a doomed plan gets rejected before any tool is invoked.

> [!info] On reasoning models (Claude Opus 4.7, GPT-5 with thinking, Gemini 2 Pro), much of "deliberate" planning happens inside the thinking budget — but it's still worth structuring the plan as an explicit artifact so the agent and the human can see it.

@feynman

Reactive is "I'll figure it out as I go." Deliberate is "let me think for ten seconds first." Both ship features; only one ships them on the first try.

@card
id: aiadg-ch03-c002
order: 2
title: Trajectories
teaser: A trajectory is the full record of how an agent reached a result — every thought, tool call, and observation. It's the unit you analyse, score, and learn from.

@explanation

A trajectory is more than a chat transcript. It captures the *why* alongside the *what*: each model thought, each tool call with its arguments, each tool output, each branch the agent considered, each step the agent ultimately took.

Trajectories matter because they're the smallest unit of improvement. You can't make the next agent run better by looking at the final answer alone — you need to see where the previous run got stuck, what tool it called when it shouldn't have, where its plan diverged from reality.

- **Successful trajectories** become few-shot examples or fine-tuning data.
- **Failed trajectories** become regression tests and sources of guard prompts.
- **Borderline trajectories** become the dataset a judge model gets trained or prompted on.

> [!tip] Save trajectories from the start. Storing them is cheap; reconstructing them later is impossible.

@feynman

Like git history versus a single commit message. The commit tells you what shipped; the history tells you why and how — and that's what teaches the next pull request.

@card
id: aiadg-ch03-c003
order: 3
title: Process vs Outcome Rewards
teaser: Score the steps, not just the ending. An agent that gets the right answer for the wrong reason will fail differently next time.

@explanation

Outcome rewards grade only the final result: did the agent solve the task or not. Easy to compute; cheap to score. The problem is that an agent can get a right answer through a wrong process — the same prompt re-rolled would have failed. Outcome rewards can't tell the difference.

Process rewards grade individual steps: was the plan reasonable, did the tool call make sense, was the observation interpreted correctly. They're harder to compute (someone or something has to score every step), but they tell you *why* a trajectory succeeded or failed, which is the part you can actually fix.

The 2025 generation of models — DeepSeek-R1's training, Anthropic's process supervision, OpenAI's o-series — all showed that step-level signals produce more capable reasoners than final-answer rewards alone. The same lesson holds for agent loops in production.

> [!warning] LLM-as-judge for process rewards has its own bias — judges prefer verbose answers. Calibrate your judge against a small human-graded set before trusting it.

@feynman

Outcome rewards grade the test score. Process rewards grade the working. The student who only gets graded on answers is the one who memorises; the one whose working gets read is the one who learns.

@card
id: aiadg-ch03-c004
order: 4
title: Test-Time Compute
teaser: When you can't afford to retrain, throw more thinking at inference. Doubling the thinking budget often beats doubling the parameter count.

@explanation

For most of LLM history, "more capable" meant "bigger model." That changed in 2024. Reasoning models showed that you can hold a model fixed and dramatically improve outputs by letting it think longer at inference time — generating internal traces, exploring alternatives, double-checking work — before it commits to a final answer.

This is *test-time compute scaling*: spending more tokens at inference instead of more parameters at training. It opens a control surface that didn't exist before:

- **Easy task** — short thinking budget; fast response, low cost.
- **Hard task** — long thinking budget; the same model produces dramatically better answers at the cost of latency and tokens.
- **Critical task** — very long budget plus self-verification; the model effectively gets a second-opinion pass for free.

Modern SDKs let you set the budget per call: Claude's `thinking.budget_tokens`, OpenAI's reasoning models with effort levels, Gemini's deep-think modes. Treat it as a knob you tune per workload, not a global setting.

> [!info] On simple tool-routing decisions, thinking is wasted compute. Reserve it for steps where the choice has irreversible consequences.

@feynman

Like giving a senior engineer more time on a hard ticket vs a paper-cut bug. Same engineer, very different output, depending on how much time they're allowed to think.

@card
id: aiadg-ch03-c005
order: 5
title: Tree Search Returns
teaser: MCTS isn't just for AlphaGo anymore. With cheap parallel inference, exploring a tree of possible plans is back on the menu — and beats single-shot reasoning on long-horizon tasks.

@explanation

Monte Carlo Tree Search (MCTS) was the trick that beat humans at Go: at each step, simulate many plausible continuations, score them by how often they lead to wins, and play the move with the best expected outcome. It was too expensive to apply to LLMs in the early days. With 2025-era inference costs and parallel tool calling, it's back.

The pattern for agents:

1. **Expand** — from the current state, generate K candidate next actions in parallel.
2. **Simulate** — for each candidate, do a shallow rollout (a few steps ahead) using a faster, cheaper model.
3. **Score** — evaluate each rollout against the goal.
4. **Pick** — execute the highest-scored candidate. Repeat from the new state.

The depth and width are knobs. Shallow trees with K=3 give "look-ahead by one move." Deeper trees give genuinely strategic agents but spend tokens fast.

> [!tip] Tree search shines when actions are reversible during simulation but expensive in reality. A research agent can simulate ten searches in parallel; a deployment agent should not simulate ten deploys.

@feynman

Chess engines don't decide a move by feel — they try a hundred moves in their head and play the one that doesn't lose. Same trick, applied to plans.

@card
id: aiadg-ch03-c006
order: 6
title: Explore vs Exploit
teaser: A planning agent has to decide whether to refine the plan it has or look for a better one. The bandit framing tells you when to do which.

@explanation

Every planning step is the same dilemma: do I commit more compute to the current best plan (exploit) or sample a new one in case there's something better (explore)? It's the multi-armed bandit problem, and it shows up everywhere — A/B tests, recommendation systems, agent rollouts.

Two heuristics that work in practice:

- **Confidence-bounded** — keep exploring while the gap between the top plan and the second-best is small; commit when one plan dominates by a clear margin.
- **Diminishing returns** — track how much each new sample improves the score; stop sampling when the improvement curve flattens.

A degenerate agent that explores forever never ships. A degenerate agent that exploits forever ships the wrong thing. The good agents tune the trade-off per task — exploration cheap when stakes are high; exploitation cheap when latency matters.

> [!info] You can let the model decide. Tools like "I want to think about this differently" or "stick with this plan" expose the choice as a first-class action the agent can take.

@feynman

The "should I keep iterating on this design or try a totally different one?" question every senior dev has asked at hour four of a hard problem. Bandits formalise the gut feeling.

@card
id: aiadg-ch03-c007
order: 7
title: Self-Verification
teaser: Ask the model to check its own answer in a fresh context. The verification step catches errors the generation step couldn't see.

@explanation

A model in the middle of generating a long answer is too committed to spot its own mistakes. The same model, given the question and the proposed answer in a fresh prompt, will often catch errors that were invisible during generation.

The pattern is two calls:

```text
1. Generation:   prompt → draft answer
2. Verification: prompt + draft → "is this answer correct? what's wrong with it?"
```

Verification is cheap because the model isn't generating much new content — it's reading and judging. It catches arithmetic errors, contradicted claims, missed constraints. For high-stakes outputs, you can iterate: if verification finds issues, regenerate with the criticism in the prompt.

> [!tip] Use a *different* prompt or model for verification when you can. The same model with the same prompt makes the same mistakes; a slight perturbation breaks the correlation.

@feynman

Same as code review by the person who didn't write the code. The author has been staring at the same diff for an hour; the reviewer sees it fresh and catches the off-by-one.

@card
id: aiadg-ch03-c008
order: 8
title: Self-Consistency
teaser: When you can't verify, vote. Run the same prompt N times; pick the answer the model agrees with itself on. Crude, but startlingly effective on reasoning tasks.

@explanation

Self-consistency takes the best-of-N idea and applies it to one model. Generate the answer N times at non-zero temperature. Group the answers by what they actually claim. Pick the cluster with the most votes.

It works because correct reasoning chains tend to converge on the same answer, while incorrect ones diverge in different wrong directions. On math benchmarks, going from N=1 to N=10 can be the difference between 60% and 85% accuracy on the same model.

The catch is that voting only works when answers are *comparable*. For numeric or short-string answers, exact match is fine. For free-form prose, you need a model to cluster semantic equivalents — which is itself a verification step.

> [!info] On reasoning models, the thinking budget partially substitutes for self-consistency. The model is, in a sense, voting against itself internally before it commits.

@feynman

Asking the same question to ten copies of the same engineer and going with the most common answer. Sounds dumb. Works astonishingly well.

@card
id: aiadg-ch03-c009
order: 9
title: Trajectory-Driven Fine-Tuning
teaser: Once you have thousands of trajectories, the good ones become training data. The agent gets better at the tasks you actually run.

@explanation

The 2024–25 wave of "agent reinforcement training" frameworks (ART, RULER, rLLM, and Anthropic's internal pipelines) is built on a simple loop: run the agent on real tasks, score the trajectories, fine-tune the underlying model on the high-scoring ones. Repeat.

The mechanism uses preference learning rather than absolute rewards. Pair a winning trajectory with a losing one on the same task; train the model to prefer the winner. DPO, KTO, and their successors do this without the brittle reward-model machinery of classic RLHF.

What this buys you in production:

- **Domain specialisation** — your agent gets disproportionately better at the tasks your users actually run.
- **Latency wins** — the fine-tuned smaller model often replaces a frontier model with thinking turned on.
- **Compounding quality** — every shipped trajectory is potential training data.

> [!warning] Do not fine-tune on the trajectories of the production model running unmodified. You'll bake in the same blind spots. Use trajectories from a stronger model, human edits, or explicit corrections.

@feynman

Code review by example. After a thousand reviewed PRs, the engineer doesn't need the comments anymore — the patterns are internalised. Same shape, applied to a model.

@card
id: aiadg-ch03-c010
order: 10
title: Distillation From Big to Small
teaser: A frontier model with thinking on solves the task; a small fast model trained on those solutions ships the feature.

@explanation

Distillation is the most cost-efficient improvement path most teams miss. A frontier model — Claude Opus 4.7, GPT-5, Gemini 2 Pro — runs the agent flow with a generous thinking budget. The trajectories it produces are the curriculum. A small, fast model (Haiku 4.5, Mini, Flash) is fine-tuned on those trajectories.

The result: the small model captures most of the reasoning quality of the big one on the specific tasks you trained for, at a fraction of the latency and cost. It won't generalise as broadly, but for production agents that do the same shape of work all day, you don't need broad generalisation.

```text
1. Frontier model + thinking → produce 10K trajectories on real tasks.
2. Filter:                      keep only successful, well-formed ones.
3. Distill:                     fine-tune small model on the filtered set.
4. Deploy:                      small model takes prod traffic; frontier becomes evals + fallback.
```

> [!tip] The cheapest way to do this in 2026 is the platform's managed fine-tuning UI — Anthropic's, OpenAI's, or Google's. You don't need a GPU.

@feynman

Apprenticeship at scale. The senior engineer does a thousand reviews; the junior watches all of them; eventually the junior makes most of the calls and only escalates the weird ones.

@card
id: aiadg-ch03-c011
order: 11
title: Replanning Triggers
teaser: A plan made before the first observation is a guess. Decide upfront when the agent is allowed to throw the plan out and start over.

@explanation

Long-horizon agents tend to over-commit. They draft a six-step plan, find that step two failed, and dutifully attempt steps three through six anyway. Replanning triggers are the explicit checkpoints where the agent stops, re-reads the situation, and asks whether the plan still makes sense.

Triggers worth wiring in:

- **Observation deviation** — a tool returned something the plan didn't anticipate (404, empty result, unexpected schema).
- **Step budget exceeded** — the agent has used more steps than the plan estimated.
- **Confidence drop** — a step's verification score is below threshold.
- **Explicit human signal** — the user replied with a correction or clarification.

When a trigger fires, the agent is forced into a "replan" node: read the goal, read what happened so far, draft a new plan from current state. The old plan goes into trajectory memory but stops controlling action.

> [!info] Replanning is where most agents either become impressive or visibly broken. An agent that stubbornly executes a doomed plan is the one users mock on social media.

@feynman

The senior engineer who notices ten minutes in that the architecture won't work, throws away the half-built code, and starts over — versus the one who keeps building. The first ships a working feature; the second ships a Slack rant.

@card
id: aiadg-ch03-c012
order: 12
title: Picking the Right Depth
teaser: Most tasks don't need MCTS, RL, or self-verification. The skill is recognising the few that do — and making sure those are the only places you spend the depth.

@explanation

This chapter introduced a depth budget you can spend in many forms: thinking tokens, tree-search width, self-verification passes, fine-tuning loops. The temptation is to pile them all on. The result is an agent that costs ten times more than necessary and ships nothing because every iteration takes a minute.

A reasonable progression:

1. **Default** — reactive ReAct loop, no extra depth. Ship it. Measure where it fails.
2. **Add thinking** — turn on the model's thinking budget on the failure cases. Most "the agent is dumb" complaints disappear here.
3. **Add verification** — a single check pass on outputs that have to be right. Cheap, big quality jump.
4. **Add tree search** — only for tasks where the cost of a wrong commit is much bigger than the cost of trying alternatives.
5. **Add fine-tuning** — only when you have thousands of trajectories and a clear domain pattern.

Stop at the level that solves your actual problem. Depth you don't need is just latency.

@feynman

The optimisation lesson, again. Profile first, then optimise the slow part. Most agents are slow because they're doing extra work — and the work is "thinking deeply" about things that didn't need it.
