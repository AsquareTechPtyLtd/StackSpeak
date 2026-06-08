@chapter
id: cicdp-ch12-tools-landscape
order: 12
title: Tools Landscape
summary: GitHub Actions vs GitLab Pipelines vs CircleCI vs Buildkite vs Jenkins — managed runners vs self-hosted, cost models, vendor lock-in vectors, and the calculus of when to switch tools vs when to invest in the one you have.

@card
id: cicdp-ch12-c001
order: 1
title: The CI/CD Tool Decision Framework
teaser: Choosing a CI/CD tool is not a popularity contest — it is an engineering decision with organizational, financial, and operational consequences. A structured framework prevents the decision from being driven by inertia, marketing, or whichever engineer wrote the first pipeline.

@explanation

The CI/CD market in 2026 spans managed SaaS platforms, self-hosted open-source systems, and hybrid models. No single tool is universally correct. The right tool for a two-person startup shipping a web app is not the right tool for a regulated enterprise with 500 engineers and a dedicated platform team.

A decision framework that has survived tool cycles and market shifts evaluates candidates on five axes:

- **Integration surface.** How tightly does the tool integrate with your source control host, artifact registry, and deployment targets? Friction at integration boundaries is a tax paid on every pipeline run.
- **Execution model.** Managed runners, self-hosted runners, or a hybrid. Each carries different cost curves, security postures, and operational burdens. This axis alone eliminates or selects most candidates.
- **Configuration paradigm.** YAML-based declarative, Groovy DSL, Go code, or graphical. Configuration paradigm determines maintainability at scale and the steepness of the learning curve.
- **Vendor lock-in surface.** Which behaviors are expressed in proprietary syntax versus portable abstractions? Lock-in is not automatically bad, but it must be quantified and accepted deliberately.
- **Total cost of ownership.** Build-minute pricing, self-hosted operational overhead, and the hidden cost of pipeline maintenance time. Sticker price and TCO diverge significantly depending on scale and usage patterns.

A secondary set of questions disciplines the selection process:

- What is the cost of switching away from this tool in two years? Can you estimate it honestly?
- Does the team's existing expertise map to this tool's model, or are you buying a retraining burden?
- Does this tool have a viable path for the scale you expect to reach, not just the scale you have today?

> [!warning] This chapter frames what to evaluate, not what to use. Tool capabilities, pricing, and market position shift rapidly. Any specific recommendation made in 2026 may be outdated by the time you read it. Apply the framework to the current state of the tools you are evaluating.

@feynman

Picking a CI/CD tool well means evaluating integration fit, runner model, configuration style, lock-in risk, and real cost — not just going with whatever is popular or already in use.

@card
id: cicdp-ch12-c002
order: 2
title: GitHub Actions: Strengths and Constraints
teaser: GitHub Actions is the dominant managed CI/CD platform for open-source and GitHub-native teams. Its marketplace, seamless SCM integration, and low barrier to entry are genuine strengths — but its YAML verbosity, runner cost at scale, and tight GitHub coupling are real constraints that must be evaluated honestly.

@explanation

GitHub Actions reached general availability in 2019 and has since become the default CI/CD choice for most teams that already host source code on GitHub. The integration is frictionless by design: push to a repository, add a workflow file under `.github/workflows/`, and the pipeline runs. There is no separate CI account to provision, no webhook to configure, no token to manage.

Genuine strengths worth weighing:

- **GitHub Marketplace.** Thousands of reusable Actions exist for common tasks — Docker builds, cloud deployments, security scanners, notification integrations. The ecosystem accelerates initial pipeline setup significantly.
- **Reusable workflows and composite actions.** Both mechanisms allow pipeline logic to be extracted into shared libraries and versioned independently, reducing the snowflake pipeline problem at scale.
- **OIDC federation.** GitHub Actions supports OpenID Connect token exchange with AWS, GCP, and Azure, enabling keyless, short-lived credential acquisition without storing long-lived secrets. This is a significant security advantage.
- **Environments and protection rules.** Named environments with required reviewers and deployment wait timers provide built-in approval gate functionality without external tooling.

Constraints that matter at scale:

- **YAML verbosity.** Complex pipelines expressed in GitHub Actions YAML grow unwieldy. The lack of native templating forces workarounds — composite actions, reusable workflows, matrix strategies — each adding cognitive overhead.
- **GitHub dependency.** GitHub Actions is tightly coupled to GitHub. Migrating source control off GitHub means rebuilding every pipeline. The tool is free only if the platform is free.
- **Managed runner cost at scale.** GitHub-hosted runners are priced per minute, with larger machines (8-core, 16-core) at significant multipliers. Organizations running thousands of builds per day frequently find self-hosted runners necessary to control spend.
- **Concurrency limits.** Free and team plan accounts have concurrent job limits that can create queue pressure during peak build loads.

@feynman

GitHub Actions is the easiest CI to start with if you're already on GitHub — the integration is seamless and the marketplace is huge. The cost and complexity tradeoffs emerge at scale, and its tight GitHub coupling is a lock-in vector you need to accept deliberately.

@card
id: cicdp-ch12-c003
order: 3
title: GitLab Pipelines: Integrated Platform
teaser: GitLab CI/CD is not just a CI tool — it is the pipeline layer of a vertically integrated DevSecOps platform. Its depth of integration across source control, issue tracking, container registry, and security scanning is a genuine differentiator; the tradeoff is platform breadth that can feel like bloat for teams with simpler needs.

@explanation

GitLab's CI/CD system is architecturally distinct from GitHub Actions in one important way: it was designed as part of a unified platform from the start, not added on top of an existing source control product. Every pipeline in GitLab has first-class access to the merge request, the issue tracker, the container registry, the artifact repository, and the built-in security scanners — without configuration.

What GitLab does distinctively well:

- **Auto DevOps.** GitLab can detect application type and generate a complete build, test, scan, and deploy pipeline automatically. For standardized application types, this eliminates pipeline authoring entirely.
- **Security scanning built-in.** SAST, DAST, dependency scanning, container scanning, and secret detection are native capabilities, not marketplace integrations. Security findings flow directly into merge request views.
- **DAG pipelines.** GitLab supports directed acyclic graph job ordering with the `needs:` keyword, allowing jobs to run as soon as their specific dependencies complete rather than waiting for an entire stage to finish. This can significantly reduce total pipeline wall time.
- **Self-managed deployment option.** GitLab offers a fully self-hosted deployment (GitLab CE/EE) that organizations with strict data sovereignty requirements can run in their own infrastructure. This is a meaningful option that GitHub does not offer at comparable maturity.

Constraints to evaluate:

- **Configuration complexity.** GitLab CI YAML has a rich feature set — includes, extends, rules, needs, trigger — that is powerful but has a steep learning curve. Large pipelines can become difficult to reason about.
- **Platform lock-in.** Teams that invest heavily in Auto DevOps, GitLab security scanners, and GitLab Environments are deeply integrated with the platform. Migrating away requires rebuilding significant pipeline infrastructure.

> [!info] GitLab is the strongest choice when an organization wants a single vendor for source control, CI/CD, and security scanning. The integration depth justifies the learning investment for teams that use the full platform.

@feynman

GitLab CI is the pipeline layer of a full DevSecOps platform — SCM, registry, security scanning, and deployment all integrated. That depth is the point, and accepting it means accepting the platform.

@card
id: cicdp-ch12-c004
order: 4
title: CircleCI: Speed and Configuration
teaser: CircleCI built its reputation on fast feedback loops and a configuration model that felt less like YAML torture than Jenkins. Its orb ecosystem, Docker-first execution model, and resource class flexibility make it a strong option for teams that treat pipeline speed as a first-class concern.

@explanation

CircleCI predates GitHub Actions by several years and occupied the "not Jenkins" space before managed CI became commoditized. It introduced several ideas that are now standard: configuring pipelines via a file committed alongside source code, Docker-native job execution, and per-job resource class selection.

Distinctive strengths:

- **Resource class flexibility.** CircleCI allows individual jobs to specify precise resource classes — from small (1 CPU, 2 GB RAM) to 2xlarge+ (20 CPU, 40 GB RAM) — without changing the runner model. Teams can right-size compute per job rather than accepting a one-size runner.
- **Orbs.** CircleCI's Orb ecosystem is a versioned, parameterized package system for reusable pipeline configuration. Orbs are more composable than GitHub Actions marketplace actions for some use cases, with explicit versioning and namespacing.
- **Docker layer caching.** CircleCI has native Docker Layer Caching (DLC) that persists image build layers between runs. For teams building Docker images frequently, DLC meaningfully reduces build time.
- **Source control agnosticism.** CircleCI integrates with GitHub, GitLab, and Bitbucket. Teams that want to decouple their CI choice from their SCM choice have more flexibility with CircleCI than with platform-native options.

Constraints worth weighing:

- **Managed-first model.** CircleCI's self-hosted runner support (Runner) exists but is less mature and less capable than its managed offering. Teams with strict data-residency requirements may find it limiting.
- **Pricing at scale.** CircleCI's credit-based pricing model can be opaque. Organizations with unpredictable build volume benefit from careful modeling before committing to a plan.
- **Market position.** As GitHub Actions matured and GitHub usage grew, CircleCI's differentiation narrowed. Evaluate whether the specific features that differentiate CircleCI justify the separate toolchain for your context.

@feynman

CircleCI pioneered config-as-code CI and built a strong model for fine-grained compute resource selection per job. Its value today depends on whether you need its specific differentiation over platform-native alternatives.

@card
id: cicdp-ch12-c005
order: 5
title: Buildkite: Hybrid Self-Hosted Model
teaser: Buildkite inverts the managed CI model: the control plane is SaaS (Buildkite's servers), but the build runners live entirely in your infrastructure. This hybrid approach gives organizations data sovereignty and custom hardware without the operational burden of running a fully self-hosted CI system.

@explanation

Buildkite's architecture is architecturally unusual among CI/CD tools. The pipeline definition, trigger logic, and web UI are hosted by Buildkite. The agents that actually execute builds run in your own infrastructure — your AWS account, your bare-metal servers, your Kubernetes cluster. Build artifacts, secrets, and source code never leave your network.

Where this model excels:

- **Custom hardware builds.** Teams building for GPU workloads, embedded systems, macOS apps, or ARM targets can attach purpose-built machines as Buildkite agents. No managed CI provider can match the hardware flexibility of running your own agents.
- **Data sovereignty.** Source code, build outputs, and secrets never transit Buildkite's infrastructure. For organizations with regulatory or contractual requirements around data residency, this is often the decisive factor.
- **Scale without cost shock.** Buildkite charges per seat (users), not per build minute. Organizations running large volumes of builds can autoscale their own agent pools without per-minute charges accumulating.
- **Agent elasticity.** Buildkite's agent autoscaler (open source) integrates with AWS, GCP, and Azure auto-scaling groups. Agent count scales with queue depth, and agents terminate after jobs complete.

Operational costs to account for:

- **You run the agents.** Agent patching, base image maintenance, networking, and autoscaler configuration are your operational responsibility. Teams without infrastructure engineering capacity may find this burden outweighs the benefits.
- **Pipeline configuration model.** Buildkite pipelines are defined partly in YAML and partly via dynamic step generation using scripts or API calls. The dynamic model is powerful but requires disciplined patterns to avoid configuration sprawl.

> [!info] Buildkite is a strong fit for organizations that have outgrown managed CI on cost or compliance grounds but do not want the full operational overhead of Jenkins. The split control-plane/data-plane model is architecturally elegant for this use case.

@feynman

Buildkite's control plane is hosted SaaS, but your build agents run in your own infrastructure. You get a polished UI and scheduling without sending code or artifacts to a vendor — at the cost of managing the agents yourself.

@card
id: cicdp-ch12-c006
order: 6
title: Jenkins: The Legacy Workhorse
teaser: Jenkins is the most widely deployed CI/CD server in the world and also the most operationally demanding. Its plugin ecosystem is unmatched in breadth; its security model, configuration-as-XML origin, and maintenance overhead are genuine liabilities. Understanding when Jenkins is the right answer — and when it is just the inherited answer — is a real engineering judgment.

@explanation

Jenkins began as Hudson at Sun Microsystems in 2004 and has been continuously maintained since. Its longevity is a testament to its extensibility and to the cost of migration — not necessarily to superior design. Organizations that adopted Jenkins in 2010-2015 often still run it not because it is the best choice but because the migration cost has never been authorized.

Where Jenkins remains genuinely strong:

- **Plugin breadth.** Jenkins has over 1,800 plugins. Integration targets that are not supported by newer tools — legacy VCSes, on-premises artifact stores, niche deployment targets — frequently have Jenkins plugins. No modern managed CI tool matches this breadth.
- **Fully self-hosted.** Jenkins runs entirely within your own infrastructure. For organizations with air-gapped environments or complete network isolation requirements, Jenkins (or Tekton) may be the only viable option.
- **Groovy DSL expressiveness.** Jenkinsfile (declarative or scripted pipeline) is more programmatically expressive than YAML-based systems for sufficiently complex pipeline logic. Teams with sophisticated conditional branching or dynamic stage generation sometimes find this an advantage.

Liabilities that must be assessed honestly:

- **Operational burden.** Jenkins requires dedicated operational effort: server patching, plugin compatibility management, agent provisioning, backup and recovery. The hidden cost of Jenkins is the engineer-hours spent keeping it running.
- **Security model complexity.** Jenkins' security surface is large. Misconfigured Jenkins instances have historically been a significant attack vector. Hardening Jenkins correctly requires ongoing expertise.
- **Plugin dependency risk.** Plugin interdependencies create upgrade risk. A Jenkins instance with 50 plugins has a combinatorial compatibility matrix that can make routine upgrades into multi-day projects.
- **Acquisition cost.** Jenkins itself is free. The operational cost is not. Before choosing Jenkins on cost grounds, model the engineering time required to operate it versus the subscription cost of a managed alternative.

@feynman

Jenkins is the most flexible self-hosted CI tool available and the most operationally demanding. It is often the inherited answer rather than the right answer — before accepting it, honestly evaluate whether the migration cost is actually higher than the ongoing maintenance cost.

@card
id: cicdp-ch12-c007
order: 7
title: Tekton and Kubernetes-Native CI
teaser: Tekton is a Kubernetes-native CI/CD framework that models pipelines as Kubernetes custom resources. It is not a managed service — it is a building block. Teams that want to compose custom CI infrastructure on Kubernetes without vendor lock-in find it compelling; teams that want a batteries-included experience find it demanding.

@explanation

Tekton, originally from Google and now a CNCF project, reframes CI/CD primitives as Kubernetes objects. Tasks, Pipelines, PipelineRuns, and TaskRuns are Custom Resource Definitions (CRDs). The pipeline scheduler is Kubernetes itself. Build execution happens in pods.

The architectural implications are significant:

- **No proprietary runtime.** Tekton's execution model is Kubernetes. Teams already operating Kubernetes clusters do not add a new operational domain — they add CRDs to an existing platform. Build infrastructure is managed using the same tools (Helm, kubectl, GitOps operators) as application infrastructure.
- **Portability.** A Tekton pipeline that runs on EKS runs on GKE, on AKS, or on an on-premises cluster without modification. The pipeline definition is cloud-agnostic.
- **Composability.** Tekton Tasks can be sourced from the Tekton Hub — a community catalog — and assembled into pipelines. Versioned, reusable task definitions can be shared across teams as Kubernetes resources.
- **Foundation for platform teams.** Tekton is frequently the foundation layer underneath higher-level CI tools — Red Hat OpenShift Pipelines, Jenkins X, and custom internal developer platforms are built on Tekton. If your organization is building an internal CI platform, Tekton is worth evaluating as the execution engine.

Where Tekton is a poor fit:

- **No Kubernetes expertise.** Tekton is not beginner-friendly. It requires solid Kubernetes knowledge to operate, debug, and maintain. Teams without Kubernetes expertise should not adopt Tekton hoping to learn both simultaneously.
- **No built-in UI or UX.** Tekton's native dashboard is minimal. Pipeline observability, trigger management, and developer-facing views require additional tooling (Tekton Dashboard, third-party integrations).

> [!info] Tekton is a CNCF graduated project with significant industry backing. It is the infrastructure layer, not the user experience layer — evaluate it accordingly. Teams that adopt it typically build a developer-facing abstraction on top.

@feynman

Tekton treats pipelines as Kubernetes resources — your CI/CD runs as pods in a cluster you control. It is a powerful, portable foundation with no vendor lock-in, but it requires Kubernetes expertise and provides very little out of the box.

@card
id: cicdp-ch12-c008
order: 8
title: Argo Workflows for Pipeline Orchestration
teaser: Argo Workflows is a Kubernetes-native workflow engine with a DAG-first design. It is more general-purpose than a pure CI tool — data pipelines, ML training runs, and batch jobs run on the same engine as build pipelines. Understanding where its generality is an asset and where it is complexity overhead is the key evaluation question.

@explanation

Argo Workflows (CNCF graduated) defines workflows as Kubernetes CRDs with explicit support for DAG (directed acyclic graph) and step-based execution patterns. It was designed for data science and ML workflows before finding adoption as a CI/CD orchestration layer, particularly in organizations that had already adopted Argo CD for GitOps deployments.

What distinguishes Argo Workflows in a CI/CD context:

- **DAG-native execution.** Argo Workflows expresses dependency graphs natively in the workflow spec. Complex fan-out and fan-in patterns — parallel test shards that converge into a single report — are first-class constructs, not workarounds.
- **Argo suite synergy.** Organizations using Argo CD for GitOps delivery often adopt Argo Workflows for CI to reduce platform surface area. The shared Argo UI, RBAC model, and operational patterns create meaningful operational efficiency.
- **Artifact management.** Argo Workflows has native artifact passing between workflow steps — output artifacts from one step are automatically available as input artifacts to dependent steps, with pluggable backends (S3, GCS, Artifactory).
- **Script and container flexibility.** Individual workflow steps can be arbitrary container images or inline scripts. The execution model imposes no constraints on what the step does — the step is just a container.

Where to be cautious:

- **Developer experience gap.** Argo Workflows has a steeper on-ramp than GitHub Actions or CircleCI. A developer wanting to run a build does not intuitively reach for a workflow YAML file. Wrapping Argo in a developer-facing abstraction is typically necessary.
- **General purpose is also unfocused.** The generality that makes Argo Workflows suitable for ML pipelines also means it lacks CI-specific features — PR integration, test reporting, code coverage display — that purpose-built CI tools provide out of the box.

@feynman

Argo Workflows is a Kubernetes workflow engine that handles CI pipelines, ML training jobs, and data processing on the same platform. It is powerful and flexible, but requires more setup than a purpose-built CI tool and lacks CI-specific developer experience features.

@card
id: cicdp-ch12-c009
order: 9
title: Dagger: Programmable Pipelines
teaser: Dagger reframes the pipeline problem: instead of writing YAML that configures a CI runner, you write code in a real programming language (Go, Python, TypeScript, PHP) that defines pipeline behavior. The same code runs locally and in CI. The value proposition is reproducibility and the elimination of "works on my machine, fails in CI" divergence.

@explanation

Dagger (open-sourced in 2022 by Docker cofounder Solomon Hykes) takes a fundamentally different approach to pipeline definition. Rather than a pipeline DSL or YAML configuration, pipeline logic is expressed in general-purpose programming languages via the Dagger SDK. The SDK wraps a portable, container-based execution engine (powered by BuildKit) that runs identically on a developer's laptop and in a CI runner.

The core value proposition:

- **Local and CI parity.** A Dagger pipeline invoked locally and the same pipeline invoked in GitHub Actions or CircleCI runs the same container-based steps with identical behavior. The runner is a thin shell; the pipeline logic lives in your code.
- **Real language tooling.** Pipeline logic written in Go or TypeScript gets IDE support, type checking, unit tests, and code review — capabilities that YAML configuration cannot provide. A bug in your pipeline definition is a compilation error, not a runtime surprise.
- **CI-agnostic portability.** A Dagger pipeline is not written for GitHub Actions or GitLab CI — it is written for Dagger and can be invoked from any CI runner with a single command. Migrating CI platforms becomes a matter of updating a few lines of trigger configuration, not rewriting pipeline logic.
- **Caching at the BuildKit layer.** Dagger inherits BuildKit's content-addressed caching. Unchanged steps are automatically cached without explicit cache configuration — the build system infers what needs to run.

Where to weigh the tradeoffs:

- **Adoption cost.** Teams must learn Dagger's SDK abstractions alongside their pipeline logic. The initial investment is higher than adding a YAML file to a repository.
- **Ecosystem immaturity.** Dagger is younger than every other tool in this chapter. Evaluate its production maturity against your organization's tolerance for adopting tools that are still evolving rapidly.

> [!info] Dagger represents a conceptual shift worth understanding even for teams that do not adopt it. The question it asks — "why should CI behavior differ from local behavior?" — is a useful lens for evaluating any CI/CD setup.

@feynman

Dagger lets you write pipeline logic in a real programming language instead of YAML — and the same code runs on your laptop and in CI. The promise is that what works locally is exactly what runs in the pipeline.

@card
id: cicdp-ch12-c010
order: 10
title: Managed Runners vs Self-Hosted
teaser: The choice between managed runners and self-hosted runners is one of the highest-leverage infrastructure decisions in pipeline design. It determines cost structure, security posture, hardware flexibility, and operational burden simultaneously. The right answer depends on build volume, compliance requirements, and infrastructure capacity — not on which option is abstractly better.

@explanation

A **build runner** is the compute environment where a pipeline job executes. Every CI/CD tool has a runner model, and the choice between managed (vendor-hosted) and self-hosted fundamentally changes the economics and security profile of your pipeline.

Managed runners: what you pay for and what you get:

- **Zero operational overhead.** The vendor provisions, patches, and retires runner instances. You do not manage OS updates, agent software, or capacity planning — the vendor handles elastic scaling.
- **Per-minute cost.** Every build minute is metered and billed. At low build volume this is economical; at high volume — thousands of build minutes per day — the cost can exceed a self-hosted model by a significant margin.
- **Vendor-defined hardware.** Managed runners offer a menu of resource classes. If your build requires a specific GPU, a specific macOS hardware generation, or a specific ARM board, managed runners may not provide it.
- **Code transits vendor infrastructure.** Source code, build secrets, and artifacts are processed on vendor-managed machines. This is acceptable for most workloads but incompatible with some regulatory and contractual requirements.

Self-hosted runners: the tradeoffs that matter:

- **Infrastructure cost replaces per-minute cost.** Self-hosted runners pay cloud or hardware costs plus engineering time for operation. The break-even point against managed runners depends on utilization rate — a self-hosted runner sitting idle is pure waste.
- **Operational responsibility.** You patch the runner OS, update the agent software, manage base images, and handle capacity planning. This requires dedicated infrastructure engineering investment.
- **Hardware and network flexibility.** Self-hosted runners can access private network resources (internal package registries, on-premises services, VPN-protected deployments) and use specialized hardware (GPUs, Apple Silicon, high-memory machines) that managed runners do not offer.

> [!info] Many organizations operate a hybrid model: managed runners for most CI work (PR builds, unit tests) and self-hosted runners for specific workloads requiring private network access, specialized hardware, or high build volume. Design the runner model per workload, not per organization.

@feynman

Managed runners cost per minute and require no ops work. Self-hosted runners cost infrastructure and engineering time but unlock hardware flexibility, private networking, and lower per-build cost at high volume. Most mature teams run both.

@card
id: cicdp-ch12-c011
order: 11
title: Cost Models and Build-Minute Economics
teaser: CI/CD costs are frequently underestimated because they scale with engineering activity — every new developer, every new microservice, and every new test adds build load. Understanding the cost model of your CI platform before you scale is significantly cheaper than discovering it after.

@explanation

CI/CD platforms use several distinct pricing models. Understanding which model applies to your tool — and what usage patterns drive cost — is a prerequisite for making the runner and platform decision rational.

- **Per-minute pricing (GitHub Actions, CircleCI).** Charged for the wall-clock time that a job runs on a managed runner. Larger resource classes carry a minute multiplier (a 4-core runner may cost 2x a 2-core runner per minute). The cost lever is pipeline duration — every minute saved in pipeline optimization directly reduces the bill.
- **Per-seat pricing (Buildkite, some GitLab tiers).** Charged per user who has access to the platform, regardless of build volume. Favorable for teams with high build throughput; unfavorable for large teams with low activity.
- **Compute-cost pass-through (self-hosted).** The CI tool itself is free (Jenkins, Tekton) or cheap (Buildkite agent). You pay for the underlying compute (EC2 instances, GCE VMs, bare metal). The cost model is infrastructure utilization — the lever is autoscaling efficiency.

Build-minute economics: where the hidden costs live:

- **Idle concurrency.** Self-hosted runner fleets with poor autoscaling hold idle machines that cost money without producing work. Autoscaler tuning (scale-to-zero, scale-up latency tolerance) determines idle cost.
- **Unnecessary parallelism.** Running 20 parallel test jobs is not always faster than 4 if the bottleneck is build time, not test time. Over-parallelism inflates runner-minute costs without proportional speed improvements.
- **Redundant builds.** Multiple commits to the same branch in quick succession can trigger separate pipeline runs for each. Cancelling superseded runs automatically is a direct cost-saving configuration available in most tools.
- **Cache misses.** Dependency installation accounts for 20-40% of pipeline time in many projects. Cache invalidation on every run — due to misconfigured cache keys or cache key instability — re-pays that cost repeatedly.

> [!warning] Model your current build volume (builds/day, average duration, concurrency) against the pricing model before committing to a platform. A team running 2,000 builds/day at 8 minutes average duration will see drastically different cost outcomes across pricing models — and the difference grows with scale.

@feynman

CI costs scale with pipeline duration, build frequency, and concurrency. Per-minute, per-seat, and compute-passthrough models produce very different bills at the same build volume. Model the math before choosing the platform.

@card
id: cicdp-ch12-c012
order: 12
title: Vendor Lock-in and Migration Paths
teaser: Every CI/CD tool creates lock-in. The question is not whether lock-in exists but where it lives, how deep it runs, and whether the value exchanged for it is worth the switching cost. Teams that evaluate lock-in explicitly make better platform decisions than teams that discover it during a forced migration.

@explanation

CI/CD lock-in is not monolithic — it operates on several layers simultaneously. Identifying each layer gives you a realistic switching cost estimate and informs which investments in portability are worth making.

The lock-in layers, from shallow to deep:

- **Trigger and YAML syntax (shallow).** Pipeline trigger configuration and job syntax are unique to each tool. Moving from GitHub Actions to GitLab CI requires rewriting workflow files. This is real work but bounded and mechanical — it does not require rethinking pipeline logic.
- **Marketplace integrations (medium).** GitHub Actions marketplace actions, GitLab CI/CD templates, and CircleCI Orbs are tool-specific. Replacing them requires finding or building equivalent integrations on the destination platform.
- **Platform features (deep).** Capabilities that are native to one platform and have no direct equivalent elsewhere — GitLab Auto DevOps, GitHub Environments with required reviewers, Buildkite's dynamic pipeline generation. Pipeline logic built on these features must be rebuilt from scratch when migrating.
- **Organizational process lock-in (deepest).** Teams adapt processes to tool capabilities: approval workflows built around a specific environment model, security reviews wired to platform-specific audit logs, compliance evidence generated from platform-specific APIs. Organizational process dependencies are often invisible until migration is attempted.

When to switch tools vs when to invest in what you have:

- **Switch when the tool cannot meet a fundamental requirement.** Data residency, hardware requirements, compliance controls, or scale limits that the current tool structurally cannot address are legitimate migration triggers.
- **Invest when the problem is configuration, not the tool.** Slow pipelines, high costs, and poor developer experience are frequently configuration problems solvable within the current tool. Migrating to a new tool with the same configuration patterns produces the same problems.
- **Reduce lock-in proactively where portable abstractions exist.** Pipeline logic encapsulated in container images, Makefiles, or language-native task runners runs on any CI system. Investing in these portable layers reduces switching cost without forcing a migration.

> [!info] The most durable CI/CD investment is encapsulating pipeline logic in portable, tested code — scripts, containers, task runners — that can be invoked from any CI runner. The trigger layer (the YAML) becomes thin and replaceable. The execution layer becomes a durable organizational asset.

@feynman

Every CI tool locks you in somewhere — syntax, marketplace integrations, platform features, or organizational processes. Identify where your lock-in lives before you commit, and invest in portable execution layers (containers, scripts, task runners) to keep the switching cost bounded.
