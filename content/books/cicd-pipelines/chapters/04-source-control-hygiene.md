@chapter
id: cicdp-ch04-source-control-hygiene
order: 4
title: Source Control Hygiene as Pipeline Foundation
summary: Conventional commits, signed commits, codeowners, protected branches, and commit-graph hygiene — the version-control disciplines that make `git bisect` work and pipelines deterministic.

@card
id: cicdp-ch04-c001
order: 1
title: The Commit as a Unit of Change
teaser: A commit is not a save point — it is a unit of intention. Well-scoped commits make code review tractable, `git bisect` effective, and CI pipelines meaningful.

@explanation

Every CI/CD pipeline is built on top of a commit graph. The quality of that graph directly determines how useful the pipeline is for diagnosis when things break. A pipeline that triggers on every push can still be nearly useless if commits are sprawling, undescribed, or mixed in purpose.

The atomic commit principle:

- **One logical change per commit.** If a commit message requires "and" to describe, it should probably be two commits.
- **The commit should pass tests in isolation.** A bisect that lands on a commit which doesn't compile or doesn't pass tests is useless for diagnosis.
- **Commit message subject is a statement of intent, not a description of diff.** "Fix null pointer in PaymentService" tells reviewers what changed. "Update PaymentService.java" tells them nothing.

The downstream pipeline implications are concrete. When a build fails on a commit, the failure message and the commit message together should be enough for any engineer to start investigating — without reading the diff. When a regression appears in production, \`git bisect\` can only narrow the root cause to a commit range if each commit in that range is meaningful and self-contained.

Common anti-patterns and why they break pipelines:

- *"WIP" or "temp" commits pushed to shared branches* — trigger CI on broken intermediate states, wasting compute and creating noise.
- *Multi-feature commits* — make rollback all-or-nothing, forcing you to revert good changes alongside bad ones.
- *Whitespace-and-logic commits mixed together* — make code review and \`git blame\` noise-heavy.

The working practice: stage hunks, not files. \`git add -p\` lets you commit the refactor separately from the behavioral change, even if you made both edits at the same time. This discipline is especially valuable in teams where squash-merge is not used — every commit in a long-lived branch lands verbatim in the main branch history.

> [!tip] A commit that passes CI in isolation is the basic unit of a reliable pipeline. Anything that cannot stand alone is technical debt in your commit graph.

@feynman

A commit is a unit of intention: it should say what changed, why it changed, and be complete enough that reverting it undoes exactly one thing.

@card
id: cicdp-ch04-c002
order: 2
title: Pull Request Discipline
teaser: A pull request is the primary review surface in a CI/CD workflow — its scope, description, and linked context determine whether reviewers can meaningfully evaluate correctness or are just approving diffs.

@explanation

Pull requests (or merge requests in GitLab) are where the human review loop intersects with the automated pipeline. How you scope and describe a PR determines how fast it moves through review, how useful CI feedback is, and how easy it is to revert if it introduces a regression.

The anatomy of a high-quality PR:

- **Focused scope.** One feature, one fix, or one refactor. A PR touching 15 files across 4 concerns will sit in review limbo — reviewers don't know where to start.
- **Meaningful description.** What problem does this solve? Why this approach? Are there alternatives you considered and discarded? Link to the ticket or issue.
- **Test evidence.** For non-trivial changes, include what you tested manually and what automated tests cover the new behavior.
- **Breaking change callouts.** If the PR changes an API contract, database schema, or environment variable, call it out explicitly in the description — reviewers and downstream systems need to know.

PR size and review latency are inversely correlated. Research from teams at Google and Microsoft consistently shows that PRs under 400 lines of diff get reviewed faster, receive more actionable feedback, and introduce fewer defects than large PRs. The goal is not to artificially limit line count but to scope changes so that each PR represents a reviewable unit of intent.

The CI pipeline connection:

- *Require CI to pass before merge* — the PR review and the CI check are complementary gates. Neither alone is sufficient.
- *Use required status checks* — configuring which CI jobs must pass before merge (lint, unit tests, build) makes the gate explicit and auditable.
- *Draft PRs for early feedback* — GitHub's draft PR feature lets you trigger CI and share work in progress without opening it for merge. This decouples feedback loops from the formal review gate.

> [!info] The PR description is written once but read many times — during review, during incident investigation, and during onboarding. Write it for the reader six months from now, not just today's reviewer.

@feynman

A pull request is a proposal for a change — the description, scope, and tests are the case you make for why the main branch should include this change.

@card
id: cicdp-ch04-c003
order: 3
title: CODEOWNERS and Required Reviewers
teaser: CODEOWNERS maps file paths to responsible teams, enabling automated reviewer assignment and making review requirements enforceable by the VCS platform rather than by convention.

@explanation

A CODEOWNERS file (supported natively by GitHub, GitLab, and Bitbucket) declares which team or individual is responsible for each path in the repository. When a PR touches a path with a declared owner, that owner is automatically requested as a reviewer — and protected branch rules can require their approval before merge.

Syntax example for GitHub:

```text
# CODEOWNERS
# Root .github/ config requires platform team review
/.github/                    @org/platform-team

# All Terraform infrastructure requires infra review
/infra/                      @org/infrastructure

# Payment module requires security and payments team
/src/payments/               @org/security @org/payments

# Any CI pipeline changes require platform sign-off
/.github/workflows/          @org/platform-team

# Docs can be reviewed by anyone, default to tech-writers
/docs/                       @org/tech-writers
```

The last matching pattern wins, so order matters — place more specific patterns after general ones. This is the inverse of .gitignore.

Why CODEOWNERS matters for CI/CD:

- **Pipeline configuration is high-blast-radius.** A change to a GitHub Actions workflow file that introduces an environment variable leak or disables a security gate should require platform team review. Without CODEOWNERS, that PR can slip through with any approval.
- **Prevents implicit ownership drift.** Without CODEOWNERS, critical paths accumulate implicit owners — the person who happens to review the most PRs. When that person leaves, ownership is undocumented. CODEOWNERS makes ownership explicit and version-controlled.
- **Enables cross-team dependencies.** Shared library paths, API contracts, and configuration schemas that multiple teams depend on can require sign-off from all consuming teams, preventing unilateral breaking changes.

CODEOWNERS is effective only when paired with protected branches that enforce "Require review from Code Owners." Without that enforcement, CODEOWNERS is informational only — reviewers are suggested but not required.

> [!warning] CODEOWNERS on the .github/workflows/ path is frequently overlooked. Any engineer who can push a workflow change can potentially exfiltrate secrets or bypass deployment gates. This path should always require elevated review.

@feynman

CODEOWNERS is a map from file paths to responsible people — when a PR touches those files, those people are automatically required to approve before merge.

@card
id: cicdp-ch04-c004
order: 4
title: Protected Branches and Branch Rules
teaser: Protected branch rules are the enforcement layer for source control hygiene — they make CI requirements, review counts, and CODEOWNERS policies machine-enforceable rather than culture-dependent.

@explanation

A protected branch is a branch with restrictions on who can push to it, what conditions must be met before a merge, and whether the branch history can be rewritten. In GitHub, these are configured under "Branch protection rules" (classic) or "Rulesets" (newer, repo and org level).

Core rules to enforce on main/production branches:

- **Require pull request reviews before merging.** Set minimum required approvals (typically 1-2) and optionally require re-review when new commits are pushed.
- **Require status checks to pass.** List specific CI job names (e.g., \`lint\`, \`unit-tests\`, \`build\`) that must complete successfully. Without listing specific jobs, the rule is unenforceable.
- **Require branches to be up to date before merging.** Prevents a PR from merging if it is stale — its CI results are from a base that has since changed.
- **Require code owner review.** Enforces CODEOWNERS — the PR cannot merge without approval from the designated owner of every touched path.
- **Disallow force pushes.** Prevents history rewriting on shared branches. A force push can remove commits that CI has already validated, undermining the audit trail.
- **Require signed commits.** Enforces that every commit merged to main has a verified cryptographic signature.

GitHub Rulesets (introduced in 2023) extend these rules to the organization level. A ruleset applied at the org level applies to all repositories matching a pattern, making it possible to enforce CI requirements uniformly across a fleet of repos without configuring each one individually.

Branch strategy and protection interact:

- *Trunk-based development* — protect \`main\` strictly; feature branches are short-lived and merge frequently. CI speed is critical because the feedback loop is tight.
- *GitFlow* — protect both \`main\` and \`develop\`; release branches may have their own lighter rules. More complex to configure correctly.

> [!tip] "Require status checks" with no specific jobs listed is a no-op — any green check satisfies it. Always enumerate the exact job names you intend to enforce.

@feynman

Protected branches are the mechanism that turns your team's review and CI policies from social conventions into technical enforcement — you cannot merge without satisfying the rules.

@card
id: cicdp-ch04-c005
order: 5
title: Conventional Commits in Practice
teaser: Conventional Commits is a specification for structured commit messages that enables automated changelog generation, semantic versioning, and commit-graph analysis — without requiring manual changelog maintenance.

@explanation

The Conventional Commits specification (conventionalcommits.org) defines a lightweight structure for commit messages. The format is:

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Standard types and their meaning:

- **\`feat\`** — a new feature (triggers a MINOR version bump in semver tools)
- **\`fix\`** — a bug fix (triggers a PATCH version bump)
- **\`chore\`** — maintenance that doesn't change production code (dependency updates, tooling)
- **\`docs\`** — documentation changes only
- **\`refactor\`** — code restructuring without behavioral change
- **\`ci\`** — changes to CI/CD pipeline configuration
- **\`BREAKING CHANGE\`** — in the footer, signals a breaking API change (triggers a MAJOR version bump)

Real examples:

```text
feat(auth): add OAuth2 PKCE flow for mobile clients

Implements RFC 7636. The previous implicit flow is deprecated
but still functional for backward compatibility.

Closes #4821

---

fix(payments): handle null currency code in Stripe webhook

Stripe sends null for zero-decimal currencies. Previous code
threw NullPointerException before charge was recorded.

---

ci: add SAST scan to PR pipeline

BREAKING CHANGE: pipeline now fails on high-severity findings.
Existing open PRs will need to resolve findings before merge.
```

What tooling enables:

- *Automated CHANGELOG generation* — tools like \`semantic-release\`, \`release-please\`, and \`git-cliff\` parse commit history and generate changelogs grouped by type.
- *Automated version bumping* — \`semantic-release\` determines the next semver version from commits since the last tag, eliminating manual versioning decisions.
- *Commit-message linting in CI* — \`commitlint\` can be run as a CI step or git hook to reject non-conforming messages at author time.

> [!info] Conventional Commits pays off most in libraries and APIs with external consumers. For internal services with no semver contract, the main value is commit-graph readability and automated changelogs.

@feynman

Conventional Commits is a structured format for commit messages — by prefixing commits with \`feat:\` or \`fix:\`, tools can automatically determine version numbers and generate changelogs from your git history.

@card
id: cicdp-ch04-c006
order: 6
title: Signed Commits and Authentication
teaser: Commit signing verifies that a commit was authored by who the metadata claims — without it, the author field in git history is easily forged, undermining auditability and supply chain integrity.

@explanation

Git's author and committer fields are free-form strings set by local configuration. Nothing in the protocol prevents a developer from setting \`git config user.email ceo@yourcompany.com\` and committing under someone else's identity. Commit signing closes this gap by cryptographically binding each commit to a key the signer controls.

Three signing mechanisms are in common use:

- **GPG (PGP) signing** — the original method. The developer generates a GPG keypair, uploads the public key to GitHub/GitLab, and signs commits with \`git commit -S\`. GitHub displays a "Verified" badge on signed commits. Requires GPG installed and configured; key management adds friction.
- **SSH commit signing** — added in Git 2.34 (2021). Uses the SSH key the developer already has for authentication, eliminating the need for a separate GPG key. Configured with \`git config gpg.format ssh\`. GitHub and GitLab both support this.
- **Gitsign (Sigstore)** — keyless signing via OIDC. The developer authenticates with their identity provider; Sigstore issues a short-lived signing certificate. No long-lived keys to manage. Integrates well with GitHub Actions and enterprise SSO.

Configuring SSH signing (the simplest modern approach):

```bash
# Configure git to use SSH for signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true

# Verify a signed commit
git log --show-signature -1
```

Why signed commits matter for CI/CD pipelines:

- **Supply chain integrity.** SLSA (Supply chain Levels for Software Artifacts) Level 2 requires that provenance can be traced to authenticated sources. Signed commits are part of that chain of custody.
- **Audit defensibility.** In a security incident, "who merged this commit" needs to be cryptographically verifiable, not just metadata that anyone could have written.
- **Bot and automation distinction.** CI systems that auto-merge dependency updates (Dependabot, Renovate) can be configured to sign commits with a dedicated machine key, distinguishing automated changes from human-authored ones in the history.

> [!info] GitHub Actions runners sign commits made through the API automatically. If your pipeline creates commits (e.g., version bumps, generated files), those commits are signed without additional configuration.

@feynman

Signing a commit is like notarizing it — it attaches a cryptographic proof that only you could have created this commit, making the author field in git history trustworthy rather than just a name string.

@card
id: cicdp-ch04-c007
order: 7
title: Git Hooks for Local Validation
teaser: Git hooks run scripts at defined points in the git workflow — pre-commit and commit-msg are the two that enforce hygiene before a commit ever reaches the remote, making CI feedback faster by catching issues locally.

@explanation

Git hooks are shell scripts (or any executable) placed in \`.git/hooks/\`. Git invokes them at specific lifecycle events. The catch: \`.git/\` is not committed, so hooks are not shared across developer machines automatically. \`pre-commit\` (the framework) and \`husky\` (for Node.js projects) solve this by managing hook installation from a config file that is committed.

The two most useful hooks for CI/CD hygiene:

- **\`pre-commit\`** — runs before the commit is created. Use it for: formatting (Black, Prettier, gofmt), linting (flake8, ESLint, shellcheck), secret scanning (detect-secrets, gitleaks), and file size checks.
- **\`commit-msg\`** — runs after the developer writes the commit message but before the commit is finalized. Use it for: enforcing Conventional Commits format, checking for issue tracker references, rejecting generic messages like "fix" or "update".

A \`.pre-commit-config.yaml\` using the \`pre-commit\` framework:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        args: ["--maxkb=500"]
      - id: detect-private-key

  - repo: https://github.com/psf/black
    rev: 23.12.0
    hooks:
      - id: black

  - repo: https://github.com/commitizen-tools/commitizen
    rev: v3.13.0
    hooks:
      - id: commitizen
        stages: [commit-msg]
```

Installing hooks for a new clone:

```bash
pip install pre-commit
pre-commit install          # installs the pre-commit hook
pre-commit install --hook-type commit-msg  # installs commit-msg hook
```

The pre-commit vs CI distinction:

- *Pre-commit hooks are fast and local* — they run in seconds against only changed files and give immediate feedback. They are not a security gate (developers can bypass with \`--no-verify\`).
- *CI runs the authoritative check* — it cannot be bypassed, runs in a clean environment, and its results are the official gate for merge.

> [!warning] Never make pre-commit hooks the only validation layer. \`git commit --no-verify\` skips all hooks. CI must re-run the same checks as the authoritative gate.

@feynman

Git hooks are scripts that run automatically at git events — a pre-commit hook catches formatting and linting issues before you push, so CI doesn't have to be the first place you learn your code doesn't pass.

@card
id: cicdp-ch04-c008
order: 8
title: Configuration File Conventions (YAML, JSON)
teaser: CI pipelines consume configuration files — YAML for workflows, JSON for schemas and manifests. Consistent structure, validation, and naming conventions reduce pipeline failures caused by configuration drift.

@explanation

Modern CI/CD systems are configured almost entirely through files committed to the repository. GitHub Actions uses YAML in \`.github/workflows/\`. Kubernetes manifests are YAML. Docker Compose, Helm values, Renovate config, and pre-commit config are all YAML or JSON. The quality of these files directly determines pipeline reliability.

YAML hazards that cause silent pipeline failures:

- **Indentation errors.** YAML is indentation-sensitive. A step indented incorrectly may be silently dropped from a job definition without an error.
- **Implicit type coercion.** YAML interprets unquoted \`yes\`, \`no\`, \`true\`, \`false\`, \`on\`, \`off\` as booleans. A value like \`country: NO\` (Norway ISO code) becomes \`country: false\` unless quoted.
- **Anchor abuse.** YAML anchors (\`&\`) and aliases (\`\*\`) enable DRY configuration but create deeply non-obvious references that are hard to trace when they fail.
- **String vs number ambiguity.** Port numbers, version strings, and IDs should be quoted when their type matters to the consuming tool.

Validation approaches:

- **JSON Schema validation** — tools like \`ajv\` (CLI) and \`check-jsonschema\` (pre-commit hook) validate YAML and JSON files against a schema before they are committed. GitHub Actions workflow files have a published schema at \`schemastore.org\`.
- **yamllint** — a configurable YAML linter that catches syntax errors, inconsistent indentation, trailing spaces, and line length violations. Run it as a pre-commit hook and in CI.
- **actionlint** — specific to GitHub Actions workflows, catches references to undefined secrets, invalid job dependencies, and incorrect context expressions that yamllint alone misses.

```yaml
# .pre-commit-config.yaml additions for config validation
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        args: ["-d", "{extends: relaxed, rules: {line-length: {max: 120}}}"]

  - repo: https://github.com/rhysd/actionlint
    rev: v1.7.1
    hooks:
      - id: actionlint
```

> [!tip] Add JSON Schema bindings to your editor (VS Code's YAML extension auto-fetches schemas from schemastore.org) to catch YAML errors before even running a pre-commit hook.

@feynman

CI pipelines are defined in YAML — if that YAML is invalid or structurally wrong, the pipeline silently misbehaves. Validating config files before commit is the cheapest way to catch those failures.

@card
id: cicdp-ch04-c009
order: 9
title: Linting at the Source
teaser: Linting is the first automated quality gate — catching style violations, potential bugs, and security antipatterns at edit time and pre-commit prevents them from entering CI queues and code review at all.

@explanation

A linter is a static analysis tool that examines source code without executing it, flagging issues ranging from stylistic violations (inconsistent indentation) to semantic problems (unused variables, unreachable code) to security antipatterns (SQL concatenation, hardcoded credentials). Linting is the cheapest form of automated quality checking: it runs in milliseconds with no infrastructure.

Common linters by language and domain:

- **Python:** \`ruff\` (fast, replaces flake8/isort/pyupgrade), \`pylint\` (deeper semantic analysis), \`mypy\` (type checking)
- **JavaScript/TypeScript:** \`ESLint\` (highly configurable, plugin ecosystem), \`oxlint\` (Rust-based, 50-100x faster)
- **Go:** \`golangci-lint\` (meta-linter that runs ~50 linters with a single config)
- **Shell scripts:** \`shellcheck\` (catches common bash pitfalls: unquoted variables, \`\[ \]\` vs \`\[\[ \]\]\`, \`cd\` without error check)
- **Terraform/HCL:** \`tflint\`, \`trivy\` (security-focused), \`checkov\` (policy-as-code)
- **Dockerfiles:** \`hadolint\` (checks for best practices: pinned base images, no \`apt-get upgrade\`, non-root USER)

The layered linting model:

- *Editor integration (real-time)* — LSP-based linting as you type. Zero latency, zero process required.
- *Pre-commit hook (at commit time)* — catches issues before they leave the developer's machine. Should run only on changed files for speed.
- *CI lint job (authoritative, on PR)* — runs the full lint suite on the entire codebase in a clean environment. This is the gate that cannot be bypassed.

Configuration management for linters should be committed to the repository — \`.eslintrc\`, \`ruff.toml\`, \`.golangci.yml\`. This ensures every developer and every CI run uses identical rules. Linter version should also be pinned (in \`requirements.txt\`, \`package.json\`, or a pre-commit hook rev) to prevent rule drift as tools release new checks.

> [!info] Introducing linting to an existing codebase: run with \`--fix\` to auto-correct formatting violations first, then commit the baseline. Enabling rules incrementally (starting with errors, then warnings) reduces adoption friction.

@feynman

Linting is automated code review for style and common mistakes — it runs instantly, costs nothing, and catches the issues that waste reviewers' time on obvious feedback.

@card
id: cicdp-ch04-c010
order: 10
title: Why git bisect Needs Clean History
teaser: `git bisect` binary-searches your commit history to find the commit that introduced a regression — but it only works if commits are atomic, pass tests, and represent a single logical change.

@explanation

\`git bisect\` is one of git's most powerful diagnostic tools, yet most teams rarely use it — typically because their commit history makes it impractical. Understanding why reveals exactly what clean history enables.

How bisect works:

```bash
git bisect start
git bisect bad HEAD          # current commit has the bug
git bisect good v2.1.0       # this tag was known-good

# git checks out the midpoint commit
# run your test to check if bug exists
./run-test.sh
git bisect good              # or: git bisect bad

# repeat until git identifies the first bad commit
git bisect reset             # return to original HEAD
```

Bisect performs a binary search — with 1000 commits between good and bad, it finds the culprit in at most 10 steps. But each step requires checking out a commit and running a test. This only works if:

- **Every commit in the range compiles and starts.** If bisect lands on a broken intermediate commit, you cannot determine good vs bad — the test result is undefined.
- **Each commit represents one logical change.** If a commit bundles a refactor, a feature, and a bug fix, finding that commit is the culprit tells you nothing specific about what to revert.
- **The test can be automated.** \`git bisect run ./test.sh\` fully automates the search. Without a reliable automated test, bisect requires a human at each step.

History patterns that break bisect:

- *Merge commits that introduce conflicts resolved ad-hoc* — the conflict resolution itself can introduce bugs that are invisible in the parent commits.
- *"WIP" commits pushed to main* — compile failures at intermediate points mean bisect cannot determine good/bad.
- *Squash-all merges without meaningful per-commit tests* — squashing is only helpful if each squashed unit is still testable.

> [!tip] The CI/CD connection is direct: a pipeline that validates each commit individually (not just the final PR state) produces a history where bisect is always usable. Require-branches-to-be-up-to-date rules partially address this.

@feynman

\`git bisect\` finds the exact commit that broke something by binary search — but only if every commit in between actually builds and passes tests. Messy history turns bisect from a 10-step diagnosis into an impossible one.

@card
id: cicdp-ch04-c011
order: 11
title: Pre-Commit Checks vs CI Checks
teaser: Pre-commit and CI checks serve different purposes in the pipeline: pre-commit is a fast, developer-side feedback loop; CI is the authoritative, tamper-resistant gate. Both are necessary; neither replaces the other.

@explanation

A common mistake is treating pre-commit hooks and CI checks as redundant. They are not — they operate at different points in the workflow, have different security properties, and serve different feedback latency needs.

Comparing the two layers:

- **Pre-commit: when it runs.** Locally, at \`git commit\` time, before the commit is created. Feedback is immediate — seconds.
- **CI: when it runs.** On the remote, triggered by a push or PR. Feedback arrives in minutes. The developer may have moved on to other work.
- **Pre-commit: security model.** Developer-controlled. Bypassed with \`git commit --no-verify\`. Cannot be enforced as a merge gate.
- **CI: security model.** Platform-controlled. Runs in an isolated environment. Required status checks cannot be bypassed by the committer (only by admins overriding branch protection).
- **Pre-commit: scope.** Typically runs on staged files only (changed files), not the full codebase. Fast by design.
- **CI: scope.** Runs the full suite on the complete codebase from a clean checkout. Catches issues pre-commit misses (cross-module type errors, integration test failures).

What belongs in pre-commit (fast, local):

- Auto-formatting (Black, Prettier, gofmt) — deterministic, instant, no context needed
- Trailing whitespace, end-of-file newline fixers
- YAML/JSON syntax validation
- Secret scanning (gitleaks, detect-secrets) — catches the most obvious cases
- Commit message format (commitlint)

What belongs only in CI (authoritative):

- Full test suite (unit, integration, end-to-end)
- Security scanning (SAST, dependency vulnerability checks)
- Build and artifact creation
- Cross-module type checking (TypeScript full compilation, mypy full-check)

> [!info] The goal is to move feedback left — catching issues as early as possible. But "as early as possible" for security gates is still CI, not pre-commit. The two layers are complementary, not interchangeable.

@feynman

Pre-commit hooks are the fast, skippable first pass a developer runs locally; CI is the slow, mandatory, tamper-resistant second pass the platform runs on every push. You need both.

@card
id: cicdp-ch04-c012
order: 12
title: Source Control Anti-Patterns
teaser: The most damaging source control behaviors are not malicious — they are pragmatic shortcuts that compound over time: long-lived branches, force-pushed history, unreviewed merges, and leaked secrets baked into commit graphs.

@explanation

Source control anti-patterns degrade pipelines in two ways: they create immediate failures (a force push destroys audit history) and they accumulate as technical debt that makes future pipeline work harder (a 3-week-old feature branch is 3 weeks of divergence to resolve). Recognizing the patterns is the first step to enforcing against them.

The canonical anti-patterns:

- **Long-lived feature branches.** Branches that live for weeks diverge from main and accumulate complex merge conflicts. CI on the branch tests a reality that no longer reflects main. The merge itself becomes a high-risk event. Trunk-based development with feature flags is the mitigation.
- **Force-pushing shared branches.** \`git push --force\` on a branch other developers have checked out rewrites history they depend on. It also destroys the commit graph CI has already validated. Protected branches with "disallow force push" prevent this.
- **Bypassing CI on merge.** Repository admins can override required status checks. This is occasionally necessary (emergency hotfix) but should leave an audit trail. Routine admin bypasses indicate the CI pipeline is too slow or unreliable to enforce — which is the actual problem to fix.
- **Secrets committed to history.** API keys, passwords, and private keys committed to git are compromised — even if the commit is immediately reverted. The secret is in the commit graph, accessible to anyone with clone access. The fix requires rotating the credential AND purging the history with \`git filter-repo\` (not \`git filter-branch\`, which is deprecated). Secret scanning in pre-commit and CI prevents this from happening.
- **Generated files committed alongside source.** Build artifacts, compiled outputs, and auto-generated files committed to the repository create merge conflicts with no semantic content and bloat the clone size. \`.gitignore\` and CI that regenerates outputs are the answers.
- **Inconsistent merge strategies.** A repository where some PRs are squash-merged, some are merge-committed, and some are rebased produces an incoherent history. Pick one strategy and enforce it via protected branch settings.

Detecting anti-patterns systematically:

- *\`git log --oneline --graph\` reveals history shape* — excessive merge commits, parallel long-lived branches, and octopus merges are visible immediately.
- *\`gitleaks detect --source .\`* scans the full commit history for leaked secrets, not just the current working tree.

> [!warning] A committed secret is not fixed by a revert commit. The credential must be rotated immediately (assume compromise from the moment of push) and the history must be purged with \`git filter-repo\` before the repository is considered clean.

@feynman

Source control anti-patterns are the habits that seem harmless in the moment — skipping review, keeping a branch open for weeks, force-pushing to save time — but collectively make your pipeline unreliable and your history unreadable.
