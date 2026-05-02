@chapter
id: cte-ch03-asking-better-questions
order: 3
title: Asking Better Questions and Evaluating Claims
summary: Engineering is full of claims — vendor benchmarks, "best practices," blog post architectures. Knowing what questions to ask before accepting any claim separates engineers who reason from evidence from those who cargo-cult from authority.

@card
id: cte-ch03-c001
order: 1
title: The Socratic Questioning Pattern
teaser: Three questions — "What do you mean by X?", "How do you know?", and "What evidence supports that?" — cut through vague technical claims faster than any debugging tool.

@explanation

Socratic questioning is a structured method for testing claims by exposing the assumptions underneath them. In engineering discussions, claims arrive constantly: "microservices are more scalable," "this query is slow," "Redis would fix the latency." Most are stated as facts. Most contain hidden assumptions.

The three-question sequence:

- **"What do you mean by X?"** — forces the speaker to define their terms precisely. "Scalable" means something different to the person thinking about throughput and the person thinking about team autonomy. Until terms are defined, the conversation is about different things.
- **"How do you know?"** — asks for the source and mechanism. Is this from observation, measurement, documentation, or intuition? Is it from your system or from something you read about a different system?
- **"What evidence supports that?"** — asks for the data. Not the feeling or the intuition, but the concrete artifact: the benchmark number, the profiler output, the graph.

Applied in sequence, these three questions collapse most hand-waving in a design meeting. They are not confrontational — they are the minimum due diligence any claim deserves before it shapes architectural decisions.

> [!tip] Ask these questions of your own claims before stating them out loud. "What do I actually mean by 'faster' here, and do I have numbers?" catches weak reasoning before it becomes a design record.

@feynman

The same three questions a scientist asks before accepting any result — define the terms, name the method, show the data.

@card
id: cte-ch03-c002
order: 2
title: Distinguishing Facts, Assumptions, and Opinions
teaser: Most technical discussions mix all three without labeling them — separating them is the first step toward knowing which parts of an argument are load-bearing.

@explanation

In any technical discussion, three kinds of statements appear, usually unlabeled:

- **Facts** are statements that can be verified against evidence. "The p99 latency on this endpoint is 420ms." "PostgreSQL uses MVCC for concurrency control." Facts are checkable; if wrong, they can be corrected with data.
- **Assumptions** are statements treated as true for the purpose of the argument, but not verified. "We expect traffic to double in six months." "The third-party API will remain available." Assumptions drive decisions; they deserve explicit acknowledgment and a plan for when they're wrong.
- **Opinions** are judgments shaped by values, experience, or preferences. "Monorepos are easier to maintain." "Kubernetes is too complex for this team." Opinions are not wrong — experienced opinions carry real signal — but they are not facts and should not be presented as such.

How to apply this in practice:

- When someone states something as a fact, ask whether it is actually verified or inferred.
- When you find an assumption in a design doc, name it explicitly and ask what happens if it's false.
- When you give your own opinion, label it: "This is my read of the situation, not a measured result."

A design document that explicitly separates these three categories is significantly more useful than one that blends them — because it shows exactly which claims the design depends on and where the risks live.

> [!info] The most expensive assumptions are the ones that were mistaken for facts. Naming them costs nothing; discovering them after the system is built costs everything.

@feynman

Like separating the known values, the guesses, and the preferences in an equation — you can only solve for the right thing if you know which terms are fixed.

@card
id: cte-ch03-c003
order: 3
title: Evaluating Vendor Claims
teaser: A vendor benchmark is marketing until you know what was measured, at what scale, against what baseline, and who paid for the study.

@explanation

Vendor claims follow predictable patterns: "10x faster," "99.99% uptime," "zero-configuration." These are not lies in most cases — they are measurements taken under conditions that favor the product. Your job is to find the conditions.

Four questions to ask before trusting any vendor claim:

- **What was measured?** Throughput is not latency. P50 is not P99. Sequential reads are not random reads. The metric being claimed may not be the metric that matters for your workload.
- **At what scale?** A benchmark that holds at 10GB may not hold at 10TB. A latency number measured on one node may not hold in a distributed configuration. Scale changes which bottleneck dominates.
- **Against what baseline?** "10x faster" than what, specifically? A straw-man configuration, an older version of a competitor, or a like-for-like comparison under identical conditions? The baseline defines the claim.
- **Who funded it?** A vendor-funded study is not automatically wrong, but the incentive structure shapes which comparisons get published and which get shelved. Third-party benchmarks from neutral organizations or peer-reviewed sources carry more weight.

The right response to a promising vendor claim is not skepticism that prevents evaluation — it is a structured test in your environment, with your workload, at your scale. The claim is a hypothesis; your benchmark is the test.

> [!warning] "Works great at Company X" from a vendor case study is a testimonial, not a benchmark. Company X had a different workload, team, and context. Their result does not transfer to your system automatically.

@feynman

Like a clinical trial — the drug company's own study is data, but you want the independent replication before you prescribe.

@card
id: cte-ch03-c004
order: 4
title: Evaluating Benchmarks
teaser: A benchmark result without its five supporting facts — workload, hardware, configuration, comparison baseline, and measurement method — cannot be trusted or reproduced.

@explanation

Benchmarks are the most rigorous form of technical evidence — and the most easily misrepresented. A well-reported benchmark answers five questions. If any answer is missing, the result is incomplete.

The five questions:

- **What workload was used?** Read-heavy, write-heavy, mixed? What key distribution — uniform random, Zipfian, sequential? A workload that doesn't match yours produces a number that doesn't predict your performance.
- **What hardware was it run on?** CPU, RAM, disk type, network topology. The difference between NVMe and spinning disk, or between 10GbE and 25GbE, can dominate the result for I/O-bound workloads.
- **What was the configuration?** Default settings or tuned? Connection pool size, cache size, write-ahead log settings. Benchmarks run with default settings on a system that requires tuning are measuring the defaults, not the system's capability.
- **What is the comparison baseline?** The same system at a prior version? A competing product at its tuned configuration? A naive implementation that no serious practitioner would use?
- **How was the measurement taken?** Cold cache or warm cache? Single-threaded or concurrent clients? What was the think time? How was variance handled — median, mean, or percentiles? One run or multiple?

A benchmark that answers all five is reproducible — someone else can run it and get the same result. A benchmark that omits one or more of these is anecdote in a chart.

> [!info] The TPC benchmarking standards (TPC-C, TPC-H, TPC-DS) exist precisely because the industry needed a forcing function for benchmark reproducibility. When a database vendor publishes TPC results, you can compare them. When they publish their own format, you cannot.

@feynman

Like a chemistry experiment — you need the full protocol to repeat it; a result without a method is a story, not science.

@card
id: cte-ch03-c005
order: 5
title: Evaluating "Best Practices"
teaser: A best practice is someone else's solution to a problem they had in a context that may have nothing to do with yours — context, scale, and publication date all matter.

@explanation

"Best practices" are among the most misused terms in software. The phrase implies universal applicability, but every practice emerged from a specific context, solved a specific problem, and was written down at a specific moment in time.

Four questions to ask before adopting any best practice:

- **Whose context?** The company that published this had a specific team size, product type, traffic profile, and engineering culture. A best practice from a 500-engineer FAANG organization may produce unnecessary complexity in a 5-engineer startup — and vice versa.
- **What problem did it solve?** "Trunk-based development is a best practice" makes sense when you understand the problem it solves: long-lived feature branches create merge hell at scale. If your team doesn't have long-lived branches or a scale problem, the practice may not buy you anything.
- **When was it written?** Practices written in 2015 may assume infrastructure, tooling, and deployment patterns that have since been superseded. "Always use a message queue to decouple services" was better advice before synchronous service meshes with circuit breaking existed.
- **For what scale?** Many practices that are correct at 10 million daily active users add complexity that is a liability at 10,000. Practices that are correct at 10,000 may not hold at 10 million. Scale is one of the strongest modifiers of which solution is correct.

The underlying question is always: does the problem this practice solves exist in my system? If not, the practice is cargo-culting — adopting a solution without the problem it was built to solve.

> [!tip] When a team member cites a best practice to end a discussion, treat it as an opening, not a closing. "That's the practice — what's the problem it solves?" is always a valid question.

@feynman

Like a medical treatment guideline — correct for the studied population, but a doctor still checks whether the patient in front of them fits the study criteria.

@card
id: cte-ch03-c006
order: 6
title: Reasoning from First Principles
teaser: Deriving a solution from fundamentals instead of from authority is expensive — but it's the only reliable method when no precedent fits your constraints.

@explanation

First-principles reasoning means starting from the foundational constraints of a problem and deriving the solution, rather than asking "what did others do in this situation?" Elon Musk's framing — break the problem to its fundamental truths, then reason up — is a reasonable engineering definition.

When first-principles reasoning is worth the effort:

- **No precedent exists** — you are working in a genuinely novel technical space where patterns haven't formed yet.
- **The available precedents don't fit** — every reference solution was built for a different scale, a different workload, or a different constraint set.
- **The cost of a wrong pattern is high** — re-architecting a system that was built around an ill-fitting pattern is significantly more expensive than the upfront reasoning to get the foundation right.
- **The problem is definitionally constrained** — physics, math, or protocol specifications give you ground truth to reason from, rather than convention.

When first-principles reasoning is probably not worth it:

- A well-fitting pattern exists and its failure modes are documented.
- The system is exploratory and will change before it matters.
- Time pressure makes iteration cheaper than derivation.

First principles is not the default mode — it is the tool you reach for when authority fails you. The goal is knowing when to use it, not using it everywhere as a sign of intellectual rigor.

> [!tip] A useful heuristic: start with the constraints that cannot change (latency budget, consistency requirement, regulatory mandate), then derive the solution space from those. That is first-principles reasoning without the overhead of rejecting all prior knowledge.

@feynman

Like a navigator who knows enough physics to calculate a position without GPS — it's slower than using the satellite, but you can do it when the satellite isn't there.

@card
id: cte-ch03-c007
order: 7
title: The Five Whys for Root Cause Analysis
teaser: Asking "why" five times in a row moves an incident review from blaming a person or a tool to finding the structural condition that made the failure possible.

@explanation

The five whys technique, formalized by Taiichi Ohno at Toyota, is a disciplined method for drilling below the immediate symptom of a failure to its structural cause. In software engineering, it is most useful in incident postmortems and debugging sessions where the first answer to "what happened" is a symptom, not a cause.

The structure:

1. State the observable symptom: "The deployment pipeline failed."
2. Ask why: "Because the integration test suite timed out."
3. Ask why again: "Because the test database was unresponsive."
4. Ask why again: "Because the database connection pool was exhausted."
5. Ask why again: "Because the test runner spawned 40 parallel workers against a pool sized for 10."
6. Ask why the pool was sized for 10: "Because no one updated the test environment configuration when the team added parallel test execution."

The structural cause — missing configuration governance for the test environment — is the actionable finding. "The deployment pipeline failed" is not. Fixing only the symptom (rerunning the pipeline) does nothing to prevent recurrence.

Practical limits of the technique:

- Five is a heuristic, not a rule. Stop when you reach a cause that is actionable and structural.
- Not every chain is linear — some failures have multiple contributing causes. The five whys can branch.
- The technique works best in a blameless culture. If "why" is being used to find a person to blame, the answers will stop at the human closest to the failure.

> [!warning] The five whys fails when the team stops at the first technical cause. "The server ran out of memory" is usually a symptom, not a cause. Keep asking.

@feynman

Like peeling layers off an onion — the symptom is the skin, and the structural cause is several layers in; stop too early and you're just polishing the outside.

@card
id: cte-ch03-c008
order: 8
title: The Burden of Proof
teaser: In a technical debate, the burden of proof lies with whoever is proposing a change — and knowing how to apply this constructively prevents endless argument cycles.

@explanation

The burden-of-proof principle: whoever makes a positive claim bears the responsibility for supporting it. In formal logic, this is "onus probandi." In engineering, it means the person proposing an architectural change, a new tool, or a departure from existing practice has the obligation to support that proposal with evidence — not the obligation of the other parties to disprove it.

Applied constructively in technical debates:

- **The proposer brings evidence first.** If you are proposing migrating from PostgreSQL to Cassandra, you need the benchmark comparison, the capacity projection, and the failure mode analysis. The team's job is to evaluate your evidence, not to prove you wrong without seeing it.
- **"Absence of evidence is not evidence of absence" — but it still shifts the burden.** If no one has measured whether the current system can handle the projected load, the question is open and belongs on the investigation list before any migration decision.
- **Extraordinary claims require extraordinary evidence.** "This will reduce our infrastructure cost by 80%" requires a detailed cost model. "This should be marginally faster" requires a quick benchmark. Calibrate the evidence requirement to the size of the claim.
- **The burden shifts with new evidence.** Once a proposer brings solid evidence, the burden moves to those who disagree — they now need counter-evidence, not just skepticism.

The failure mode is using burden of proof as a veto — demanding infinite evidence to block any change, rather than asking for evidence proportional to the claim. That is obstruction, not rigor.

> [!info] A constructive framing: "What would it take to convince you this is the right call?" asked early in a technical debate makes the evidence standard explicit before anyone spends time gathering the wrong data.

@feynman

Like a court's presumption of innocence — the claim needs support before the decision is made, but the bar for evidence should match the stakes of the verdict.
