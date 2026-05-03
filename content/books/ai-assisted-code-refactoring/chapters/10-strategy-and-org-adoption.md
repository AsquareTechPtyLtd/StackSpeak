@chapter
id: aicr-ch10-strategy-and-org-adoption
order: 10
title: Strategy and Org Adoption
summary: AI-assisted refactoring is a capability you build into an organization, not a tool you install — and the patterns that make it stick are platform investment, success metrics, cost transparency, and clear "when not to" guardrails.

@card
id: aicr-ch10-c001
order: 1
title: Capability, Not Tool
teaser: Installing a coding assistant is not adopting AI-assisted refactoring — the difference is whether your organization can run a campaign against a thousand files next Tuesday without a heroic effort.

@explanation

There is a pattern that repeats when organizations "adopt" AI tooling: an engineer gets access to Cursor or Copilot, runs a few impressive demos, and the org declares it has AI-assisted refactoring. Six months later, nothing has changed at the codebase level. The tool exists. The capability does not.

The distinction matters because capability requires infrastructure that a tool alone does not provide:

- Reusable prompt templates for your specific codebase conventions
- Validation gates that catch the errors LLMs make at scale
- A team that owns the pipeline and can respond when campaigns go wrong
- Metrics that let you know whether a campaign succeeded before you merge it
- A track record — the institutional memory of what has worked and what has not

This is not a new idea. In Team Topologies terms (Skelton and Pais), you are building a platform team capability, not deploying a commodity tool. The platform team owns the tooling and abstractions; stream-aligned teams consume them. If every feature team is independently improvising their own prompt engineering for every campaign, you have not built a capability — you have chaos with a neural net attached.

The chapters in this book have built toward this framing. The prompting patterns in ch03, the pipeline architecture in ch04, and the validation strategy in ch06 are all components of a capability. This chapter is about how you organize around that capability and make it last.

> [!info] The organizations that get durable value from AI-assisted refactoring treat it the same way they treat their CI/CD platform — as shared infrastructure that requires investment, ownership, and iteration.

@feynman

Adopting AI-assisted refactoring is like the difference between owning a tractor and running a farm — the tractor is just the part you can point at; the farm is the soil knowledge, the seasonal planning, and the people who know how to use the machine when the field conditions change.

@card
id: aicr-ch10-c002
order: 2
title: Getting Buy-In Through Pilots
teaser: The most durable buy-in comes from a small campaign that delivers a measurable result — not from a slide deck that explains what could be possible.

@explanation

Engineering leadership is skeptical of AI tooling for good reason. The landscape has produced more demos than production wins. The way you change that within your organization is not by presenting a vision — it is by running a small, bounded, measurable campaign and letting the result do the persuasion.

A well-structured pilot has three properties:

- **Bounded scope.** One refactoring type, one service or module, no more than a few hundred files. If the campaign produces a bug, it is recoverable.
- **Pre-agreed success criteria.** Before you run the pilot, define what "worked" means: defect rate post-merge, hours from kickoff to merged PR, engineer-hours spent on review. Write it down.
- **A skeptic in the room.** Include an engineer who is not already a believer. Their objections will surface the real failure modes, and their sign-off carries more weight when you present results.

After a successful pilot, the expansion path follows demonstration, not pitch:

```text
Pilot → Demonstrate → Expand

  ┌─────────┐    metrics    ┌──────────┐    case study   ┌──────────┐
  │  Pilot  │──────────────►│   Demo   │────────────────►│  Expand  │
  └─────────┘  3 campaigns  └──────────┘  to other teams └──────────┘
```

The failure mode is skipping the middle step. A single pilot, even a successful one, does not prove repeatability. Run three small campaigns before you ask other teams to adopt the process. By that point, you have a case study instead of a hypothesis.

> [!warning] Do not oversell the pilot results. If the first campaign took 40 engineer-hours instead of the claimed 4, saying otherwise will destroy credibility when the next team tries to replicate it and finds the real cost.

@feynman

Getting organizational buy-in through a pilot is like learning to swim in the shallow end — the goal is not to demonstrate that you can cross the English Channel, it is to build enough confidence and skill that the deep end feels like a reasonable next step.

@card
id: aicr-ch10-c003
order: 3
title: The Platform Team's Role
teaser: Someone has to own the prompts, the pipelines, and the validation gates as products — if every team owns them independently, you get N slightly-broken versions of the same thing.

@explanation

In a mature AI-assisted refactoring setup, the platform team owns the campaign infrastructure the same way it owns CI/CD. That means:

- **Prompt library maintenance.** Reusable prompt templates for common campaign types (API migration, type annotation, logging standardization) live in a version-controlled repository. The platform team updates them when models change, when the organization's conventions change, or when a prompt is found to produce a common error pattern.
- **Validation gate ownership.** The AST-based checks, the test suite harness, and the LLM-based review step (ch06) are shared infrastructure. A feature team should not need to build a validator from scratch for each campaign — they should be able to call into a validation service the platform team runs.
- **Campaign tooling as a product.** This means a changelog, a deprecation process, a support channel, and SLAs for response time when a campaign is blocked. Platform teams that treat campaign tooling as a side project produce platform tooling that behaves like a side project.

The anti-pattern is a platform team that becomes a bottleneck: every campaign requires a ticket, a two-week wait, and a dedicated platform engineer. The goal is the opposite — the platform team builds the abstractions that make feature teams self-sufficient for routine campaigns, while staying involved for novel or high-risk ones.

This maps to what Skelton and Pais describe as the "X-as-a-Service" topology — the platform provides capabilities that stream-aligned teams can consume without needing to understand the implementation.

> [!tip] Measure your platform team by the rate at which feature teams run campaigns independently. If the platform team is executing every campaign, they are a service bureau, not a platform.

@feynman

A platform team owning campaign infrastructure is like a commercial kitchen's prep station — the station exists so that every chef can start from the same foundation rather than each one building their own mise en place from raw ingredients every shift.

@card
id: aicr-ch10-c004
order: 4
title: Measuring What Actually Matters
teaser: The metrics that make AI-assisted refactoring look good on a dashboard are often the ones most vulnerable to Goodhart's law — measure them anyway, but design them to resist gaming.

@explanation

Goodhart's law: when a measure becomes a target, it ceases to be a good measure. In refactoring campaigns, the obvious metrics are also the most gameable:

- **"Files touched" is meaningless** without tracking how many needed reverting.
- **"Hours saved" is fiction** if the estimate of the manual baseline is pulled from the air.
- **"Campaign velocity" drops** when teams stop running campaigns that are risky or novel in order to inflate their numbers.

The metrics that survive longer-term scrutiny:

- **Defect rate post-merge.** Count the bugs filed against code modified by AI-assisted campaigns in the 30 days after merge, compared to a control group of equivalent manual changes. This is hard to compute but hard to game.
- **Campaigns shipped per quarter.** A campaign that made it through validation, review, and merge. Not "started," not "piloted" — shipped. Trend this quarter over quarter.
- **Revert rate.** The percentage of merged campaign PRs that were partially or fully reverted within 30 days. A healthy number is below 5%. A rising number is an early warning signal.
- **Cost per refactoring.** Token cost plus engineer-hours. This is the denominator in the value equation, and without it, "efficiency gains" are unmeasured.

DORA metrics (deployment frequency, lead time for changes, change failure rate, time to restore service) do not map directly to refactoring campaigns, but change failure rate and time to restore are the right analog for measuring whether campaigns are introducing production incidents.

> [!info] Track revert rate from day one. It is the metric that most directly tells you whether your validation pipeline is calibrated correctly, and it is the first metric a skeptical VP of Engineering will ask for.

@feynman

Designing refactoring metrics that survive Goodhart is like designing a fitness test for hiring — you want it to measure actual capability, not the ability to train specifically for that test, which means making it broad enough that gaming it requires actually being fit.

@card
id: aicr-ch10-c005
order: 5
title: The Cost Model
teaser: A campaign that saves 200 engineer-hours and costs $4,000 in token spend is not obviously a win — and organizations that skip the cost model discover this in the budget review.

@explanation

Every AI-assisted refactoring campaign has a direct token cost that most teams do not track until it becomes a problem. The inputs to a campaign cost model:

- **Token count per file.** Estimate prompt tokens (system prompt + context window for the file) plus completion tokens (the diff output). For a typical 200-line file with a 500-token system prompt, expect 1,000–2,500 tokens per file total.
- **Files in scope.** The number of files the campaign will touch.
- **Model pricing.** As of early 2026, GPT-4o costs approximately $5 per million input tokens and $15 per million output tokens. Claude 3.5 Sonnet is in a similar range. Costs shift frequently — verify before budgeting.
- **Retry rate.** Files that fail validation on the first pass and are retried. A 20% retry rate adds 20% to your cost estimate.

A rough formula for a campaign of 1,000 files:

```text
1,000 files × 2,000 tokens/file × (1 + 0.20 retry rate)
= 2,400,000 tokens

At $10/million tokens (blended input+output):
= $24 direct cost
```

That number is almost always smaller than the engineer-hours alternative. The cost model matters less as a go/no-go gate and more as a forecasting tool: before a campaign starts, the team should be able to say "this will cost approximately $X and take Y hours of engineer review time." That forecast builds credibility and helps prioritize campaigns in a roadmap.

Rate limits are a related operational constraint — large campaigns against rate-limited APIs need to be throttled, which affects campaign wall-clock time. Budget allocation should include headroom for rate-limit retries.

> [!tip] Build your cost estimate before every campaign and log the actual cost after. After five campaigns, your estimates will be accurate enough to include in quarterly planning.

@feynman

Forecasting a campaign's token cost is like estimating a construction project's material spend — you never get it exactly right the first time, but after a few projects you develop intuitions that make the estimate useful enough to plan against.

@card
id: aicr-ch10-c006
order: 6
title: The Internal Codemod Library
teaser: The second time you run the same type of campaign is when you find out whether the first one produced anything reusable — and most teams discover it did not.

@explanation

An internal codemod library is the "we have done this before" repository for AI-assisted campaigns. It typically contains:

- **Prompt templates.** The system prompt and user prompt for each campaign type your organization has run, parameterized for codebase-specific conventions (your module naming conventions, your logging interface, your preferred import ordering).
- **Validation gate configurations.** The AST checks, lint rules, and test-harness configurations that correspond to each campaign type. "Run the API-migration validator" should be a one-line invocation, not a ten-step setup.
- **CI integration hooks.** The GitHub Actions workflow or CI pipeline step that integrates the campaign validator into pull request checks.
- **Past campaign results.** A log of what each campaign produced — how many files touched, defect rate, revert rate, cost. This is the evidence base that makes future estimation credible.

The library pays off on the third campaign of any given type. The first campaign builds the template. The second campaign reveals its gaps. By the third, the template is stable enough that a new engineer can run the campaign without significant guidance.

The failure mode is treating the library as a personal repository maintained by the one engineer who ran the first two campaigns. When that engineer leaves, institutional knowledge leaves with them. The library must be version-controlled, documented, and owned by the platform team, not by an individual.

> [!warning] A prompt template that is not tested against the current model version is a liability, not an asset. When your model provider updates a model or you switch providers, run a regression pass over your template library before the next campaign.

@feynman

An internal codemod library is like a professional kitchen's recipe book — the value is not the individual recipes but the fact that anyone on the team can reproduce the result reliably without reinventing it each time.

@card
id: aicr-ch10-c007
order: 7
title: Training the Team
teaser: The skill gap in AI-assisted refactoring is not knowing how to use an AI tool — it is knowing when a campaign output is correct enough to merge and when it is subtly wrong in a way that will surface three months later.

@explanation

Onboarding engineers to AI-assisted workflows requires closing two distinct skill gaps:

**Operational skills** — the mechanics of running a campaign:
- How to construct a prompt that produces the right diff for a given change type
- How to read validation gate output and distinguish a false positive from a real error
- How to scope a campaign to avoid touching files where the change would be incorrect

**Judgment skills** — the harder ones:
- Recognizing when an LLM has applied a structurally correct transformation that changes runtime semantics
- Knowing which validation failures require a human decision rather than a prompt refinement
- Identifying when a campaign should stop mid-run rather than continue

The curriculum for a new engineer should follow this progression:

- Start as a reviewer on one campaign run by a senior engineer
- Run one small campaign (under 100 files) with senior engineer oversight
- Run one medium campaign (100–500 files) independently, with review of the validation output
- Review the campaign debrief and contribute to the prompt library

Common skill gaps observed in practice: over-trust in validation gates (if the tests pass, it must be fine), under-attention to non-testable behavior (documentation accuracy, log message clarity, error message wording), and difficulty distinguishing LLM hallucinations from legitimate ambiguous cases.

> [!info] The most reliable predictor of campaign quality is the reviewer's experience — not the model version or the prompt complexity. Investing in reviewer training yields higher returns than iterating on prompts.

@feynman

Training an engineer on AI-assisted campaign review is like training a junior doctor to read diagnostic images — the machine produces the output, but knowing which outputs to trust and which to question is the skill that takes time and supervised exposure to develop.

@card
id: aicr-ch10-c008
order: 8
title: When Not to Use AI Refactoring
teaser: The organizations that get the most from AI-assisted refactoring are also the ones with the clearest list of situations where they do not use it.

@explanation

AI-assisted refactoring has genuine failure modes, and the "when not to use it" list is as important as the prompt library:

**Use a catalog refactoring instead** when:
- The change is small enough to apply manually in an afternoon (under ~20 files)
- The refactoring requires deep contextual understanding of the code's intent, not just its structure
- The team needs to understand why each file changes in order to make related decisions (explanation is the primary goal, not execution)

**Use an AST-based codemod instead** when:
- The transformation is purely structural and syntactic — a rename, an import rewrite, an argument reorder
- You need a zero-false-positive guarantee (AST tools either transform correctly or fail; LLMs can produce plausible-but-wrong output)
- The language tooling has a mature codemod ecosystem (JavaScript with jscodeshift, Java with OpenRewrite, Python with LibCST)

**Do not run a campaign when**:
- The code is in a path with no test coverage and no easy way to validate correctness
- The change affects security-critical logic (authentication, authorization, cryptographic operations)
- A production incident is active and the codebase is under incident-response constraints

The general principle: AI-assisted refactoring earns its cost at scale and in ambiguity. Below roughly 50 files, or in high-stakes correctness domains, a simpler tool or a slower process is usually the right answer.

> [!warning] The pressure to use AI tooling for every refactoring — because it is available and it feels fast — is the adoption failure mode that produces the most production incidents. Having an explicit "not for this" list and following it under pressure is a sign of a mature practice.

@feynman

Knowing when not to use AI refactoring is like knowing when not to use a power tool — the speed advantage only holds when the material, the tolerance, and the setup are right; in the wrong context, you just make a bigger mistake faster.

@card
id: aicr-ch10-c009
order: 9
title: The Vendor-Lock Question
teaser: The model you depend on today will be deprecated, repriced, or superseded — and the organizations that keep their options open are the ones that abstracted the model out of their campaign infrastructure.

@explanation

AI-assisted refactoring tooling is built on a model provider relationship that is not stable. In the last two years: OpenAI has deprecated GPT-4 in favor of GPT-4o in favor of o3; Anthropic has released three Claude generations; Google has moved through Gemini variants; open-weight model quality has closed the gap with frontier models for constrained tasks. The model landscape in two years is not predictable.

The organizations that handle this well share a structural property: the model is behind an interface, not embedded in the campaign pipeline.

Practically, this means:

- Prompt templates are tested against a model identifier, not hardcoded to one
- The campaign runner accepts a `--model` parameter or reads from a configuration file
- Validation gates are model-agnostic — they evaluate the output, not the process that produced it
- When a provider releases a new model, you can run your validation suite against it before migrating

The vendor landscape as of early 2026 offers three broad options:
- **Managed API services** (OpenAI, Anthropic, Google) — low ops overhead, no infrastructure, subject to pricing and availability changes
- **Self-hosted open-weight models** (Llama 3, Mistral, Qwen) — full control, higher ops cost, lower per-token cost at scale
- **In-house fine-tuned models** — highest capability for your specific codebase conventions, highest investment, makes sense only above roughly 50 campaigns/year

Custom fine-tunes and volume discount agreements with model providers become worth exploring once your campaign volume is high enough that per-token costs appear in quarterly budget reviews as a line item.

> [!tip] Treat your model provider relationship like your cloud provider relationship: use their managed services for convenience, but design your abstractions so switching is a configuration change, not a rewrite.

@feynman

Abstracting your campaign infrastructure away from a specific model is like writing your application to a database interface rather than hard-coding PostgreSQL-specific SQL — the database might change, and you want the change to be operational rather than architectural.

@card
id: aicr-ch10-c010
order: 10
title: Auditability and Compliance
teaser: In a regulated industry, "an AI changed this code" is not a complete provenance record — and the audit trail needs to survive a SOC 2 review or an incident investigation.

@explanation

In most software organizations, every merged commit has a clear human author. AI-assisted campaigns complicate this: the author of record is the engineer who opened the PR, but the diff was generated by a model. For many teams, this is fine. For teams operating under SOC 2, HIPAA, FedRAMP, or PCI-DSS, it is a question that needs an explicit answer.

The minimum viable audit trail for a regulated environment:

- **Campaign metadata logged per commit.** The model used, the prompt version, the campaign ID, and the engineer who reviewed and approved the output should be recorded — ideally in the PR description or a linked metadata file, not just in a team wiki that will drift.
- **Approval of AI-generated changes is still an explicit human sign-off.** The merge commit should represent a human engineer's review and approval, not an automated merge triggered by CI passing.
- **Model and prompt version pinning.** Being able to answer "what model and what prompt generated this specific change" during an incident investigation requires that both were recorded at campaign time.
- **Data handling of code sent to the model.** In regulated industries, sending code that contains or processes sensitive data through an external model API may itself require review. Some organizations maintain a classification of which modules can be processed through an external API and which require an on-premises or VPC-hosted model.

FedRAMP adds a harder constraint: the model infrastructure itself must be authorized, which as of early 2026 limits options to a small number of approved cloud services.

> [!warning] Do not assume that because an engineer reviewed the diff, the audit trail is complete. Compliance reviewers will ask specifically about the toolchain, and "we used an AI tool" without specifics will generate a finding.

@feynman

Building an audit trail for AI-generated code changes is like maintaining chain of custody for lab samples — the final result matters, but so does the documented record of every step in the process and every hand it passed through.

@card
id: aicr-ch10-c011
order: 11
title: IP, Legal, and Security Review
teaser: Before your first campaign, legal and security need to answer three questions — and leaving those answers until after the campaign is in production is how organizations create liability they did not know they had.

@explanation

Three distinct questions belong in a pre-adoption legal and security review:

**Training data and IP exposure.** Code sent to an external model API may, depending on the provider's terms, be used to train future models. Most enterprise API agreements explicitly opt out of this. Verify your organization's agreement covers it. The secondary question is whether model outputs constitute a derivative work of the model's training data — a live area of law as of 2026, with no settled jurisdiction-wide answer.

**Contributor license agreements and provenance.** Some organizations require that all code committed to their repositories can be traced to a human author who signed a CLA. AI-generated code complicates this. The safest position: the engineer who reviewed and merged the AI output is the author of record and vouches for compliance. Codify this in your contribution guidelines before campaigns begin.

**Security review of the campaign toolchain itself.** The campaign pipeline is a new piece of infrastructure with access to your codebase. That access should go through the same security review you would apply to a new CI/CD component:
- Which credentials does the pipeline hold, and what is the least-privilege scope?
- Where are logs stored, and who has access to them?
- Is the model API call audited, or is there a code path where source files leave your network without logging?

Raising these questions before the first campaign is cheaper than raising them during a security audit of a campaign that has already been running for a year.

> [!info] Most of these questions have reasonable answers that let campaigns proceed — the goal of the review is not to block AI adoption but to document the risk posture and get explicit sign-off before you are operating at scale.

@feynman

Getting ahead of IP and security questions before your first campaign is like having the building inspector review the blueprints before construction — it is far less disruptive than a stop-work order after the walls are up.

@card
id: aicr-ch10-c012
order: 12
title: What Stays Human
teaser: Every capability this book has built toward runs on the same foundation — a human engineer who understands the codebase well enough to know whether the change is correct, not just whether it compiles.

@explanation

The tools described across these ten chapters change the economics of refactoring at scale. They do not change the nature of the decision at the center of every campaign: is this the right change to make, and is this the right change as made?

The first question — which refactoring to apply — is unchanged. The named refactorings from the catalog (Extract Method, Replace Conditional with Polymorphism, Introduce Parameter Object, and all the rest) still need a human to choose between them. An LLM can execute a refactoring you specify. It cannot reliably identify that the correct intervention is not the one you reached for first, or that the code you are about to change is expressing an important invariant in a way that does not survive a mechanical transformation.

The second question — whether a specific transformation is correct as applied — also stays human, even when the toolchain's validation gates are sophisticated. Tests prove that a change preserves observable behavior in the test cases you wrote. They do not prove that the change preserves the behavior that matters in the scenario you did not anticipate.

What changes is the surface area one engineer can cover. A single engineer with a well-built campaign pipeline can apply a validated refactoring to a thousand files in an afternoon. Without the pipeline, the same engineer could cover a dozen. That multiplication of reach is real and valuable.

What does not change is the quality of judgment required at both ends of the process — in the decision to run the campaign and in the review of its output. If anything, the judgment requirement increases, because the cost of a wrong decision is now multiplied by the same factor as the efficiency gain.

The named refactorings still need a human to choose between them. The automation is in the execution, not the understanding.

> [!info] The skill that becomes more valuable as AI-assisted refactoring matures is not prompt engineering — it is the ability to read a thousand-line diff, understand what the campaign intended, and identify the three files where it did not quite get it right.

@feynman

AI-assisted refactoring changes who swings the hammer and how many nails get driven in an hour — it does not change who reads the blueprints and decides which wall should come down.
