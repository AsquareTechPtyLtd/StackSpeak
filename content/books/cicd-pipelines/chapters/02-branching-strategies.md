@chapter
id: cicdp-ch02-branching-strategies
order: 2
title: Branching Strategies and Their CI Cost
summary: Branch model dictates pipeline complexity — trunk-based dev makes high-frequency CI cheap, GitFlow makes it expensive, and merge queues exist to fix the race conditions trunk-based development creates at scale.

@card
id: cicdp-ch02-c001
order: 1
title: The Branching Strategy Decision
teaser: Your branching model is not a version control preference — it is a CI architecture decision that determines how many pipelines you run, how long feedback takes, and how often your main branch is in a deployable state.

@explanation

Martin Fowler's seminal essay "Branching Patterns" (2020) argues that branching strategy is fundamentally about managing the integration problem: how do multiple developers' changes get combined without breaking the product? Every branching model is an answer to that question, and each answer has different CI cost implications.

The four dimensions where branching strategy shapes CI cost:

- **Pipeline count.** How many distinct branches need their own CI runs? A trunk-based team with short-lived feature branches might trigger CI on one branch. A GitFlow team triggers CI on feature/\*, develop, release/\*, and main — multiplying cost.
- **Integration latency.** How long before a developer's change is verified against everyone else's? Trunk-based development minimizes this to hours. Long-lived feature branches can mean integration happens after days or weeks of divergent history.
- **Conflict surface area.** Branches that live long accumulate merge debt. The longer a branch lives, the more likely a merge conflict requires human time to resolve — time that does not show up in pipeline metrics but absolutely shows up in delivery velocity.
- **Main branch health.** Some strategies treat main as always deployable; others treat it as a release target that requires a stabilization phase. CI pipelines are simpler when main is always green.

Jorit van Merode's *CI/CD Pipelines* (2023) explicitly frames branching choice as a pipeline architecture decision, not a developer workflow preference. The pipeline is downstream of the branching model — get the model wrong and the pipeline gets complicated in ways that are hard to fix after the fact.

> [!info] The DORA research (Accelerate, 2018) found that high-performing teams use trunk-based development with short-lived feature branches and have fewer than three active branches at any time. Branch count is a leading indicator, not just a cultural preference.

@feynman

Branching strategy is a decision about when changes get integrated and tested together — and the further apart that integration point is from when the code was written, the more expensive CI becomes.

@card
id: cicdp-ch02-c002
order: 2
title: Trunk-Based Development
teaser: Trunk-based development (TBD) keeps all developers committing to a single shared branch — main — with feature branches that live for hours or at most a few days, making CI the cheapest and simplest it can be.

@explanation

Trunk-based development is not a new idea. Google has practiced it at scale since at least the early 2000s. The 2016 Google "Why Google Stores Billions of Lines of Code in a Single Repository" paper (Potvin and Levenberg) describes a monorepo with a single trunk where thousands of engineers commit, with automated CI running on every change. The practice predates the paper.

The core commitments of TBD:

- **No branch lives longer than a day or two.** Feature branches are short-lived by convention or by enforcement. If a feature takes a week, it is integrated to trunk using feature flags to hide the incomplete work.
- **Main is always in a releasable state.** CI runs on every commit to main. A failing build on main is a P0 incident — the team stops new work until main is green. This is not optional; it is the social contract.
- **Integration happens continuously, not at release.** Every commit is an integration event. Merge conflicts are found within hours, while the context is fresh.
- **Release is decoupled from deployment.** Incomplete features are hidden behind flags, not behind branches. Any commit on main can be deployed; whether users see a feature is a flag decision.

The CI cost advantage of TBD is structural. CI runs on main (always) and on short-lived feature branches (briefly). There is no develop branch, no release branch, no hotfix branch — no parallel pipeline infrastructure required to keep those branches healthy.

The prerequisite that teams miss: TBD requires a fast CI pipeline. If your CI pipeline takes 45 minutes, committing to trunk multiple times a day becomes painful. Fowler's CI article notes that a pipeline longer than 10 minutes creates developer drag on high-frequency integration. TBD and slow CI are incompatible at scale.

> [!tip] Feature flags are not optional in TBD — they are the mechanism that lets incomplete work live on main without affecting users. Without flag infrastructure, TBD degenerates into committing broken code or keeping branches long-lived anyway.

@feynman

Trunk-based development means everyone's code lives together all the time — conflicts surface in hours instead of at release time, and CI only needs to watch one branch.

@card
id: cicdp-ch02-c003
order: 3
title: GitFlow and Why It Costs More CI
teaser: GitFlow's multiple long-lived branches — main, develop, release/*, hotfix/* — multiply your CI surface area: every branch that can be deployed or merged needs its own pipeline, its own test run, and its own failure response protocol.

@explanation

Vincent Driessen published the GitFlow branching model in 2010. It was designed for software with explicit versioned releases — mobile apps, packaged software, libraries with semantic versioning. In that context it made sense. The problem is that most web application teams adopted it without the underlying release model that justified its complexity.

GitFlow's branch taxonomy and its CI implications:

- **main** — represents released code. CI runs here. Failing main is a production incident.
- **develop** — integration branch for features. CI runs here. Failing develop blocks the next release. This is effectively a second trunk with its own health contract.
- **feature/\*** — one per in-progress feature, potentially living for days to weeks. CI runs on each. N active features = N active pipelines.
- **release/\*** — cut from develop when stabilizing for a release. CI runs here during stabilization. Bug fixes on release/\* must be cherry-picked back to develop — a manual, error-prone operation that CI cannot automate reliably.
- **hotfix/\*** — emergency fixes on main. Must be merged to both main and develop. Two pipelines affected, with timing risk: if develop has diverged significantly, the merge is non-trivial.

The hidden cost is integration debt. Features on long-lived branches diverge from develop silently. The CI pipeline on a feature branch tells you the feature builds and passes tests in isolation. It tells you nothing about how it will behave when merged with three other features that have been developing in parallel.

Driessen himself added a note to his original post in 2020: "If your team is doing continuous delivery of software, I would suggest to adopt a much simpler workflow (like GitHub flow) instead of trying to shoehorn git-flow into your team." The model's creator acknowledged it was wrong for most modern web teams.

> [!warning] GitFlow is not wrong — it is wrong for the team context most people apply it to. Versioned mobile app releases with app store cycles have legitimate reasons to use it. Continuously deployed web services do not.

@feynman

GitFlow creates multiple long-lived branches that each need CI coverage, and the longer branches live, the more expensive it gets to integrate the changes from all of them.

@card
id: cicdp-ch02-c004
order: 4
title: Release Branch Strategy
teaser: Release branches are a middle ground — a single long-lived main for development with time-boxed branches cut for stabilization — used correctly, they give teams release control without the full complexity cost of GitFlow.

@explanation

The release branch pattern is common in open-source projects (Kubernetes, Chromium, the Linux kernel) and mobile apps. The model: development happens on main (or a develop branch), and a release branch is cut when the team wants to stabilize a specific version.

How it works in practice:

- A release branch (e.g., release/2.4) is created from main at a feature freeze date.
- Only bug fixes and security patches land on the release branch after cut. New features continue on main.
- CI runs on both main and the release branch. Two active pipelines is manageable.
- Once the release ships, the release branch may be kept alive for patch releases (2.4.1, 2.4.2) or archived.

The CI cost of this model scales with the number of supported release branches. A team supporting three concurrent release versions (common in enterprise software or Kubernetes plugin ecosystems) has four active pipelines: main plus three release branches. Each bug fix may need to be cherry-picked to multiple release branches and CI must verify each.

GitHub uses this model for GitHub Enterprise Server: releases are versioned, maintained independently, and each receives security backports. The engineering cost of maintaining parallel release branches is real and intentional — it is the price of supporting customers on older versions.

For SaaS teams with a single deployed version, release branches are usually unnecessary overhead. The justification for the complexity only appears when customers run the software themselves or when app stores enforce versioning.

> [!info] Kubernetes uses a release branch model (release-1.28, release-1.29, etc.) with automated cherry-pick tooling to reduce the manual cost of backporting fixes across branches. If you are running release branches, automate the cherry-pick workflow or the maintenance cost compounds quickly.

@feynman

A release branch strategy lets you stabilize a version for shipping while development continues on main — but every active release branch is another pipeline you have to keep green.

@card
id: cicdp-ch02-c005
order: 5
title: Short-Lived Feature Branches
teaser: Short-lived feature branches — branches that live less than a day or two — give developers the isolation they need to develop without CI losing the integration feedback that makes continuous integration valuable.

@explanation

Fowler's definition of Continuous Integration is precise: "a software development practice where members of a team integrate their work frequently, usually each person integrates at least daily." A branch that lives for five days is not CI, regardless of how many pipeline runs happen on it.

Short-lived feature branches reconcile two legitimate concerns:

- **Developer isolation.** Developers want to work without being disrupted by changes from teammates mid-task. A branch provides that isolation for the duration of a focused unit of work.
- **Integration feedback.** CI needs to verify that changes work together. The longer isolation lasts, the later the integration feedback arrives.

The discipline required to keep branches short-lived:

- Tasks must be decomposed small enough to complete in a day or two. Large features are delivered incrementally via feature flags, not via long branches.
- Pull requests must be reviewed quickly — a PR sitting for three days waiting for review turns a short-lived branch into a long-lived one. Code review latency is a branching strategy concern, not just an engineering culture concern.
- CI on feature branches must be fast. If CI takes 40 minutes per run and a branch has five push events before merging, a developer is waiting three hours of CI time for a day's work. That is unsustainable.

GitHub Flow, popularized by GitHub's own engineering team, is the canonical form of this pattern: branch from main, commit, open a pull request, get CI passing and review, merge, deploy. The entire cycle is expected to complete in hours.

> [!tip] Branch age is a useful metric. If your repository has feature branches older than three days that have not been merged or abandoned, your development process has a workflow problem that branching strategy cannot fix on its own.

@feynman

Short-lived feature branches give developers a working space without sacrificing the integration feedback CI provides — as long as the branch lives in hours, not days.

@card
id: cicdp-ch02-c006
order: 6
title: Pull Requests vs Merge Requests
teaser: Pull requests (GitHub terminology) and merge requests (GitLab terminology) are the same concept — a proposal to integrate a branch into another — and they are the canonical CI trigger point in modern development workflows.

@explanation

The naming difference is purely vendor terminology. GitHub calls them pull requests (PRs); GitLab calls them merge requests (MRs). Bitbucket uses pull requests. The concept is identical: a developer signals intent to merge a branch and requests review and CI validation before the merge is allowed.

Why PRs/MRs matter as a CI trigger point:

- **Automated gate, not manual gate.** CI running against the merge commit (the prospective result of the merge, not just the branch tip) tells you whether the integration is clean before it happens. This is distinct from CI running on the branch in isolation.
- **Status checks as merge requirements.** GitHub and GitLab both support required status checks — CI jobs that must pass before merge is permitted. This is the mechanism that keeps main green.
- **Review and CI are coupled.** A PR is not ready for merge until both human review and automated CI agree. Separating these — merging without CI, or bypassing review — are the failure modes that required status checks prevent.

GitHub's distinction between PR triggers matters in pipeline configuration. GitHub Actions distinguishes between **pull_request** (triggered from the forked branch, with limited secret access) and **pull_request_target** (triggered in the context of the target repository, with full secret access). Using **pull_request_target** carelessly is a known security vulnerability — it allows forked PRs to access repository secrets.

GitLab Merge Requests add one concept GitHub lacked until recently: the merge trains feature, which is GitLab's implementation of the merge queue pattern (covered in card 10). MRs in GitLab can be configured to join a queue, run CI in sequence with other queued MRs, and only merge if all in-sequence CI passes.

> [!warning] Using pull_request_target in GitHub Actions requires explicit attention to the fork untrusted-code attack vector. Run any code from a fork in the pull_request context (limited permissions) rather than pull_request_target unless you have specific reasons and mitigations in place.

@feynman

A pull request or merge request is where CI and code review meet — the gate before a branch's changes become permanent in main.

@card
id: cicdp-ch02-c007
order: 7
title: Protected Branches and Gates
teaser: Branch protection rules are the enforcement mechanism that turns CI from advisory to mandatory — without them, developers can merge without passing tests, push directly to main, or force-push history into oblivion.

@explanation

A branching strategy without enforcement is a convention. Conventions break under deadline pressure. Protected branches are the mechanism that converts the strategy into a structural guarantee.

What branch protection rules can enforce on GitHub:

- **Require status checks to pass before merging.** Specific CI jobs (linting, unit tests, integration tests, security scans) must succeed. You specify which checks are required — a check being green for unrelated pipelines does not count.
- **Require pull request reviews.** Minimum number of approving reviews, whether stale reviews are dismissed on new pushes, and whether code owners must review files in their designated area (CODEOWNERS enforcement).
- **Require branches to be up to date.** Forces developers to rebase or merge main into their PR before merging. This prevents stale branch merges but increases developer friction and is a common source of repeated CI runs.
- **Restrict who can push.** Only admins or specified users/teams can push to main directly, even when bypassing other protections.
- **Prevent force pushes.** Protects branch history from being rewritten by git push --force, which breaks anyone who has already pulled.

GitLab's equivalent is Protected Branches in project settings, with similar controls. GitLab adds the concept of merge request approval rules that can require approvals from specific groups, which maps more naturally to CODEOWNERS-style requirements.

The "require branches to be up to date" setting deserves special attention. Combined with a team of 10 developers all pushing to active PRs, it creates a liveness problem: by the time your CI passes and you are ready to merge, someone else has merged, and now your branch is stale again. This is the race condition that merge queues exist to solve.

> [!info] GitHub's rulesets (introduced 2023) are the successor to branch protection rules — they apply to multiple branches by pattern, can be applied at the organization level, and support a wider range of enforcement actions including bypass lists for specific actors. If you manage protection rules across many repositories, evaluate rulesets.

@feynman

Branch protection rules make CI mandatory rather than advisory — without them, "CI must pass before merge" is a suggestion that disappears under deadline pressure.

@card
id: cicdp-ch02-c008
order: 8
title: The Repository as Source of Truth
teaser: The repository is not just where code lives — it is the authoritative record of what the software is, what it requires, and how it should be built; every build artifact must be traceable back to a specific commit on a specific branch.

@explanation

In a well-designed CI/CD system, the repository is the single source of truth. Not the artifact registry, not the deployment dashboard, not the ticketing system. The repository. Every deployed version traces back to a commit SHA. Every build traces back to what was checked in.

What "repository as source of truth" requires in practice:

- **Build inputs are pinned.** Dependency versions in your lock file (package-lock.json, Pipfile.lock, go.sum) are committed and reproduced exactly in CI. A build that pulls "latest" of a dependency is not reproducible from the repository.
- **Pipeline definitions are in the repository.** The CI configuration lives in .github/workflows/, .gitlab-ci.yml, or equivalent. Pipeline changes go through the same PR process as code changes and are covered by the same protected branch rules.
- **Deployment configuration is committed.** Kubernetes manifests, Helm values, Terraform — the desired state of every environment is expressed as committed files. This is the GitOps principle: git is the single source of truth for operational state, not just source code.
- **Artifacts are tagged with commit SHAs.** Container images, build artifacts, and deployment packages carry the commit SHA from which they were built. You can always trace what is deployed back to what was committed.

The violation of this principle is easy to spot: "hotfixes" that are made directly in a deployed environment and never committed back to the repository. These create drift between what is running and what the repository says should be running. Drift compounds — the longer it persists, the harder future deployments become because the repository is no longer an accurate picture of production.

> [!warning] Manual changes to production — shell into a server and edit a config, kubectl apply a manifest that was not committed, run a one-off database migration without a tracked script — are the primary way repositories lose their status as source of truth. Preventing them requires both process discipline and tooling (read-only deployments, immutable infrastructure).

@feynman

When the repository is the source of truth, you can reconstruct what is running in any environment just by reading what is committed — and that traceability is what makes debugging, auditing, and rollback tractable.

@card
id: cicdp-ch02-c009
order: 9
title: Merge Conflicts in Long-Lived Branches
teaser: Merge conflicts in long-lived branches are not a git problem or a communication problem — they are a branching strategy tax: the longer a branch lives, the more divergence accumulates, and divergence costs developer time that never shows up in pipeline metrics.

@explanation

Fowler describes the merge conflict problem directly: the longer integration is deferred, the larger the delta between branches grows, and the more expensive — in human cognitive work — the integration becomes. Automated tools can detect a conflict; they cannot resolve it. Resolution requires the developer to understand both sides of the divergence, which requires context that may be days or weeks stale.

The compounding dynamics:

- **Conflict probability increases super-linearly with branch age.** A branch that has been open for three days is not three times as likely to conflict as one open for one day — it is more likely, because every commit to main by every teammate is a new potential conflict source.
- **Conflict resolution is not free.** A developer resolving a complex merge conflict may spend hours understanding changes from teammates before they can correctly integrate. This time is invisible in CI dashboards — it shows as a gap between pushes, not as a failed build.
- **Incorrect conflict resolutions are silent failures.** A merge conflict that was resolved incorrectly — where both sides' intent was not fully understood — produces code that compiles and tests pass, but whose behavior is wrong. This is the most dangerous outcome.

The technical mitigations are limited. Rebase frequently to stay current with main. Keep branches short-lived to minimize divergence. Use feature flags to integrate incomplete features to main so that work does not pile up on a long-lived branch waiting for a feature to be ready.

The organizational mitigation is simpler and more effective: adopt a branching strategy that structurally prevents long-lived branches. Trunk-based development does not eliminate merge conflicts — it makes them small and frequent enough that they are resolved in minutes, not hours.

> [!info] Jez Humble and David Farley in Continuous Delivery (2010) use the term "integration hell" to describe what happens when long-lived branches converge at release time. The phrase is intentionally vivid — teams that have experienced it recognize the description immediately.

@feynman

The longer a branch stays open, the more your teammates' changes pile up that you have not yet integrated with — and when you finally merge, you pay the full cost of all that deferred integration at once.

@card
id: cicdp-ch02-c010
order: 10
title: The Merge Queue Pattern
teaser: Merge queues solve the "branch is up to date" race condition in trunk-based development at scale: instead of requiring each PR to rebase on main independently, the queue serializes merges and runs CI against the exact commit that will land.

@explanation

The race condition is subtle but critical. With protected branch rules requiring branches to be up to date before merging: Developer A and Developer B both rebase on main at 9:00 AM. Both run CI — both pass. Developer A merges at 10:00 AM. Main has now advanced. Developer B's branch is stale. Developer B must rebase, wait for CI to run again, and then try to merge. Meanwhile Developer C may have also merged.

On a high-traffic repository with dozens of active PRs, this creates a liveness problem: a PR can pass CI repeatedly and still fail to merge because the target branch keeps moving. The solution is a merge queue.

How merge queues work:

- A PR is approved and its initial CI passes.
- Instead of merging immediately, the PR is added to the merge queue.
- The queue creates a temporary branch representing main + all queued PRs in sequence.
- CI runs against this temporary branch. The developer sees their PR tested as it will actually land, not tested against a stale main.
- If CI passes, the PR is merged. If CI fails, only the failing PR is removed from the queue; others continue.

GitHub Merge Queue (generally available since 2023) and GitLab Merge Trains (available since GitLab 12.0) implement this pattern. Bors-ng is an open-source bot that implemented the pattern for GitHub before GitHub natively supported it.

The CI cost of merge queues is higher than naive branching: every PR in the queue gets a CI run in addition to its development-phase runs. The tradeoff is correctness — you never merge something that breaks main — and developer time savings from eliminated rebase churn.

> [!tip] Merge queues become necessary at team sizes where three or more PRs merge per hour on a shared branch. Below that threshold, the "up to date" requirement with manual rebasing is usually tractable. Above it, the queue pays for itself in avoided CI thrash.

@feynman

A merge queue lines up approved pull requests and tests each one against the exact state of main it will produce — eliminating the race where two PRs both pass CI separately but break main together.

@card
id: cicdp-ch02-c011
order: 11
title: Conventional Commits for Automation
teaser: Conventional Commits is a lightweight commit message specification that makes commit history machine-readable — enabling automated changelog generation, semantic version bumping, and trigger-based pipeline decisions from commit content alone.

@explanation

Conventional Commits (conventionalcommits.org) is a specification for commit message format, inspired by the Angular commit message convention. The format:

- **feat: add support for OAuth2 PKCE flow** — a new feature. Triggers a minor version bump in semantic versioning.
- **fix: correct token expiry check in refresh handler** — a bug fix. Triggers a patch version bump.
- **feat!: remove deprecated v1 endpoints** — a breaking change (the ! denotes breaking). Triggers a major version bump.
- **chore, docs, test, refactor, perf, ci** — maintenance types that do not trigger version changes.

The pipeline automation this enables:

- **Semantic Release** (the npm tool) analyzes commits since the last release tag, determines the correct next version, generates a CHANGELOG.md, creates a GitHub Release, and publishes the artifact — all from commit messages, with zero human input to the versioning step.
- **Pipeline branching on commit type.** CI pipelines can skip expensive integration tests for commits typed as docs or chore, saving runner time on changes that cannot affect runtime behavior.
- **Automated PR categorization.** GitHub Actions workflows can label PRs by conventional commit type and route them to different review queues.

Enforcement is done at the PR level using a commitlint check in CI. The commitlint GitHub Action validates that all commits on the branch conform to the specification before merging is permitted. A single non-conforming commit in a PR fails the check.

The adoption cost is real. Developers accustomed to writing commit messages like "fix stuff" or "wip" resist the format initially. Squash-merge PRs make adoption easier — developers write one well-formed merge commit from a messy branch rather than conforming every intermediate commit.

> [!info] Conventional Commits works best with squash-merge PRs: the PR title becomes the single commit on main, and only the title needs to conform. This significantly reduces the discipline required from developers during active development.

@feynman

Conventional Commits turns your git log into structured data — and structured data can be processed by tools to automatically version, release, and categorize changes without human judgment.

@card
id: cicdp-ch02-c012
order: 12
title: Choosing a Branching Strategy for Your Team
teaser: The right branching strategy depends on three variables: deployment model (continuous vs versioned releases), team size (10 developers vs 10 teams), and CI pipeline speed — there is no universal answer, but there is a decision framework.

@explanation

The common mistake is choosing a branching strategy based on what you read in a blog post rather than on the actual constraints of your team. Fowler's "Patterns for Managing Source Code Branches" is the most rigorous treatment of this decision, and its conclusion is that context determines the right answer.

The decision variables:

- **Deployment model.** If you deploy continuously to a single production environment (SaaS web app), trunk-based development or GitHub Flow is appropriate. If you ship versioned releases that customers deploy themselves (mobile apps, on-prem software, libraries), release branches or GitFlow may be warranted. The model should match the release cadence.
- **Team size and PR velocity.** Small teams (< 10 developers) can work effectively with simple branch protection and manual rebase discipline. Teams merging 10+ PRs per day need a merge queue to avoid CI thrash. The tooling complexity should match the traffic.
- **CI pipeline speed.** Trunk-based development is practical only if CI runs complete in under 10 minutes. A 30-minute pipeline on every commit to a short-lived branch that merges twice a day means a developer waits an hour of CI time per day on their own branch, plus queue time. Invest in pipeline speed before adopting high-frequency integration practices.
- **Feature flag infrastructure.** Trunk-based development requires a flag system to hide incomplete features on main. If you do not have flag infrastructure and cannot build or buy it, trunk-based development for large features is impractical. GitHub Flow for smaller, shippable units of work may be more realistic.

A practical starting point for most continuously deployed teams: GitHub Flow (main + short-lived feature branches, squash merges, required status checks) with conventional commits enforced via commitlint. Add a merge queue when PR merge rate exceeds three per hour on a shared branch.

The DORA research from Accelerate is directional, not prescriptive: elite performers use trunk-based development or closely approximate it. But the research also shows that the bottleneck is rarely the branching strategy itself — it is usually CI speed, code review latency, or test reliability. Fix the bottleneck, not the convention.

> [!tip] Before changing branching strategies, measure three things: average PR lifetime (branch open to merge), average CI duration, and deployment frequency. These metrics reveal where your actual bottleneck is. A team with 4-day PR lifetimes likely has a code review problem, not a branching problem.

@feynman

Choose your branching strategy based on how often you deploy and how fast your CI runs — not based on what the most famous teams do, because their constraints are probably not your constraints.
