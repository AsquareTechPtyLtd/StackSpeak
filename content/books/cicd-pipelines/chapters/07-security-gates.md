@chapter
id: cicdp-ch07-security-gates
order: 7
title: Security Gates in the Pipeline
summary: DevSecOps as design, not bolted-on stage — SAST/DAST/SCA placement, secret scanning, dependency pinning, Sigstore signing, and SLSA L2/L3 build attestations that make the pipeline itself the security boundary.

@card
id: cicdp-ch07-c001
order: 1
title: DevSecOps as Pipeline Design
teaser: DevSecOps is not a scanning stage bolted to the end of the pipeline — it is a design philosophy that treats security as a structural property of the delivery system, not a checkpoint before release.

@explanation

The term DevSecOps emerged from a simple observation: security checks performed at release time are almost useless. By the time code reaches the release gate, it has accumulated weeks of decisions — library choices, API designs, secrets handling patterns — that a scanner can identify but a team cannot easily unwind. The cost to fix a vulnerability found at release is, by industry estimates, 10 to 100 times greater than fixing it at the point the code was written.

The correct framing is not "add security to DevOps" but "design the delivery pipeline such that insecure software cannot progress through it." This is a pipeline design problem, not a security tooling problem. Tools are necessary but insufficient: a Snyk scan that blocks on critical CVEs but whose results are never reviewed is theater. A Trivy scan that runs on every commit but whose findings route to a security queue that nobody owns is noise.

Executive Order 14028 (Improving the Nation's Cybersecurity, May 2021) formalized this shift for US federal software suppliers: it mandates that agencies use only software that complies with NIST secure software development practices, and that suppliers provide attestations of their software supply chain. The EO made pipeline-embedded security a compliance requirement, not just a best practice. The OWASP CI/CD Security Top 10 published in 2022 further codified the attack surface of CI/CD systems themselves.

- **Security as a structural property** — security gates are first-class pipeline stages, not optional post-deploy audits. The pipeline is the enforcement mechanism.
- **Fail-closed by default** — a security gate that can be bypassed without an audit trail is not a gate. Design bypass as an exception with approval and logging, not as a convenience.
- **Findings require owners** — every security finding that surfaces from the pipeline must route to a team or person with the authority and responsibility to act on it. Unowned findings are ignored findings.
- **Security gates must be fast** — a SAST scan that adds 30 minutes to the CI pipeline will be disabled under pressure. Design for sub-5-minute gates in the hot path; move thorough scans to scheduled or merge-triggered runs.

> [!info] OWASP CI/CD Security Top 10 (2022) identifies "Insufficient Pipeline-Based Access Controls" (CICD-SEC-2) and "Insufficient Artifact Integrity Validation" (CICD-SEC-4) as the two most exploited CI/CD attack vectors in documented supply chain incidents. Both are pipeline design failures, not tool failures.

@feynman

DevSecOps means security is baked into how the pipeline is designed, not added as a scan at the end. The pipeline itself becomes the enforcement mechanism that prevents insecure software from advancing.

@card
id: cicdp-ch07-c002
order: 2
title: Shift-Left Security
teaser: Shift-left security is the practice of moving security checks as close to the point of code creation as possible — pre-commit hooks, IDE linting, and PR-time scanning — so that vulnerabilities are caught when the cost to fix them is lowest.

@explanation

"Shift left" is a reference to the pipeline diagram: stages flow left to right, from commit through build, test, security, and deploy. Shifting security left means moving security checks toward the left edge of that diagram — closer to where code is written and farther from where it ships.

The IBM Systems Science Institute study (widely cited in the security industry) quantified the cost differential: a defect found in the requirements or design phase costs roughly $100 to fix; the same defect found in production costs between $10,000 and $100,000. The same amplification applies to security vulnerabilities. A hardcoded secret caught by a pre-commit hook takes 30 seconds to remove. The same secret caught after it has been pushed to a public repository requires credential rotation, audit log review, customer notification, and potentially regulatory disclosure.

The shift-left security stack, ordered from leftmost to rightmost:

- **IDE plugins** — Snyk, SonarLint, and Semgrep IDE extensions surface findings as the developer types. Zero pipeline cost; zero feedback delay. Drawback: optional, developer-controlled.
- **Pre-commit hooks** — git hooks that run before a commit is recorded locally. Gitleaks, detect-secrets, and TruffleHog prevent secrets from entering the repository history. The pre-commit framework (pre-commit.com) manages hook installation and versioning.
- **Pull request gates** — SAST and dependency scans run on the diff introduced by the PR. Findings are surfaced as PR comments, and the PR cannot merge if findings exceed configured thresholds. This is the primary enforcement layer.
- **Post-merge scans** — full repository scans on merge to main. Catch issues that pre-commit hooks missed (developer bypassed hooks) or that require full dependency graph analysis.
- **Scheduled deep scans** — nightly DAST, container image scanning against updated CVE databases, and license compliance checks. These are too slow for the PR path but catch vulnerabilities that postdate the original build.

> [!warning] Pre-commit hooks are a developer tool, not a security control. Git hooks can be bypassed with git commit --no-verify. Never rely on pre-commit hooks as the sole enforcement mechanism for a policy that must hold. They reduce friction; the pipeline gate enforces the policy.

@feynman

Shift-left security means catching security problems as close to when the code was written as possible — ideally before it's even committed — because the earlier you catch a problem, the cheaper and easier it is to fix.

@card
id: cicdp-ch07-c003
order: 3
title: Static Analysis (SAST) in CI
teaser: SAST analyzes source code for security vulnerabilities without executing it. Placed in the CI pipeline, it acts as a continuous security code review — catching injection flaws, insecure deserialization, and hardcoded credentials before they ship.

@explanation

Static Application Security Testing (SAST) operates on source code, bytecode, or binary artifacts. It applies pattern matching, taint analysis, and semantic analysis to identify security vulnerabilities: SQL injection, cross-site scripting, insecure cryptography, hardcoded credentials, path traversal, and dozens of other classes of vulnerability catalogued by OWASP and CWE.

Common SAST tools and their design characteristics:

- **Semgrep** — rule-based, language-agnostic, extensible. Rules are written in YAML and can be authored by the team to encode organization-specific patterns. Semgrep CI runs in under 60 seconds on most codebases, making it viable for the PR hot path.
- **CodeQL** — semantic analysis engine from GitHub. Converts code to a queryable database and runs QL queries against it. Significantly more precise than pattern matchers for interprocedural vulnerabilities. Slower (5-20 minutes for large codebases) — best placed on merge to main, not PR commits.
- **Bandit** — Python-specific. Fast, lightweight, widely adopted in Python CI pipelines. Configurable severity thresholds via .bandit configuration file.
- **Gosec** — Go-specific. Checks for G-series rules (G101 hardcoded credentials, G201 SQL injection, G304 file path traversal). Integrates with Go toolchains natively.

A GitHub Actions step running Semgrep on every pull request:

```yaml
- name: Run Semgrep SAST
  uses: returntocorp/semgrep-action@v1
  with:
    config: >-
      p/owasp-top-ten
      p/secrets
      p/ci
  env:
    SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}
```

SAST placement strategy: fast rule-based tools (Semgrep, Bandit) belong in the PR gate. Semantic analyzers (CodeQL) belong in the post-merge stage. Both findings must be triaged — a SAST result that is dismissed without review is a false negative the team has manufactured.

> [!warning] SAST has false positive rates that vary significantly by tool and codebase. An unconfigured SAST tool in a blocking gate will produce enough noise to erode developer trust within weeks. Invest in tuning: configure severity thresholds, add suppressions for confirmed non-issues with justification comments, and review the rule set quarterly.

@feynman

SAST reads your source code looking for patterns that indicate security vulnerabilities, without actually running the code. Think of it as an automated security code reviewer that runs on every pull request.

@card
id: cicdp-ch07-c004
order: 4
title: Dependency Scanning (SCA)
teaser: Software Composition Analysis scans the third-party libraries in your project against known vulnerability databases. It answers the question your SAST tool cannot: is the code you didn't write putting you at risk?

@explanation

The Log4Shell vulnerability (CVE-2021-44228, CVSS 10.0) demonstrated at scale what security practitioners already knew: the biggest risk surface in modern software is not code you write — it is code you depend on. A single vulnerable transitive dependency buried five levels deep in a dependency graph can expose every application that includes it, regardless of how well those applications are coded.

Software Composition Analysis (SCA) tools resolve a project's full dependency graph — direct and transitive — and check each component against vulnerability databases including the National Vulnerability Database (NVD), GitHub Advisory Database, OSV (Open Source Vulnerabilities), and vendor-specific feeds.

Key SCA tools and their integration points:

- **Snyk** — commercial, with a free tier. Integrates with GitHub, GitLab, and CLI. The snyk test command exits non-zero when vulnerabilities exceed the configured severity threshold, making it directly usable as a pipeline gate.
- **Trivy** — open source (Aqua Security). Scans container images, filesystems, git repositories, and SBOM files. Supports multiple output formats including SARIF, JSON, and table. Widely used in Kubernetes-native pipelines.
- **Dependabot / Renovate** — automated dependency update PRs. Not strictly SCA scanning, but the remediation layer: when a new CVE is published, these tools open a PR to update the affected package without manual intervention.
- **OWASP Dependency-Check** — open source, well-established, supports Java, .NET, Node.js, Python. Suitable for regulated environments where commercial tools face procurement friction.

```bash
# Trivy: scan a container image, fail on CRITICAL CVEs
trivy image \
  --exit-code 1 \
  --severity CRITICAL \
  --ignore-unfixed \
  myapp:${{ github.sha }}

# Snyk: test dependencies, fail on high severity
snyk test --severity-threshold=high
```

SCA gate design decisions: what severity threshold triggers a pipeline failure, what to do about vulnerabilities that have no available fix (--ignore-unfixed in Trivy), and how to handle accepted risks (suppress with documented justification and expiry date). These are policy decisions that belong in the pipeline design document, not ad-hoc in individual YAML files.

> [!info] Blocking on every CRITICAL and HIGH CVE without an --ignore-unfixed flag will stop your pipeline for vulnerabilities in transitive dependencies that have no remediation path. Start with --ignore-unfixed, track unfixed vulns in your risk register, and implement a mandatory review cycle (e.g., 30 days).

@feynman

SCA scans every library your project imports — not just the top-level ones, but all the libraries those libraries depend on — and checks them against a database of known vulnerabilities. It covers the code you didn't write.

@card
id: cicdp-ch07-c005
order: 5
title: Secret Scanning and Pre-Commit Hooks
teaser: A secret committed to a git repository is not private — it is permanently exposed to everyone with repository access, and potentially to anyone with access to the hosting provider. Secret scanning at every layer, from pre-commit to CI to historical audit, is the only adequate response.

@explanation

Secrets — API keys, OAuth tokens, database passwords, TLS private keys, AWS credentials — are the single most consequential type of accidental exposure in CI/CD systems. Unlike a vulnerability in a library, a leaked secret requires no exploitation expertise: it is immediately usable by anyone who finds it. And unlike vulnerable code, a secret committed to git history cannot be remediated by a patch: the git object is immutable. Once pushed, the only safe response is to rotate the credential.

The layered defense for secret prevention:

- **Pre-commit hooks** — Gitleaks and detect-secrets run locally before the commit is recorded. Install via the pre-commit framework. Gitleaks ships with a comprehensive ruleset covering over 150 secret patterns. Configure in .gitleaks.toml with custom patterns for internal credential formats.
- **CI secret scanning** — TruffleHog, Gitleaks in CI mode, or GitHub's built-in secret scanning run on every push. This catches secrets introduced by developers who bypassed pre-commit hooks (git commit --no-verify) or who committed from environments where hooks were not installed.
- **Historical scanning** — gitleaks detect --source=. --no-git scans the full repository history when first enabled or after a repository is acquired. Establishes a clean baseline.
- **Provider-side push protection** — GitHub, GitLab, and Bitbucket all offer push protection that blocks pushes containing detected secrets server-side. This is the last-resort enforcement layer and requires no developer tooling installation.

```bash
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

# Run Gitleaks in CI (exits non-zero on detected secrets)
gitleaks detect \
  --source . \
  --log-opts "HEAD~1..HEAD" \
  --redact \
  --exit-code 1
```

> [!warning] When a secret is found in git history, follow these steps without exception: (1) revoke and rotate the credential immediately — do not wait to assess impact; (2) audit access logs for the credential from its introduction date; (3) use git-filter-repo or BFG to remove the secret from history and force-push; (4) notify affected parties per your incident response policy. History rewrite alone is insufficient — the secret was already exposed.

@feynman

A password or API key in a git commit is immediately compromised — git history is forever. Secret scanning runs at every layer (your local machine, the CI pipeline, and the git hosting server) to catch secrets before they become permanent.

@card
id: cicdp-ch07-c006
order: 6
title: CI Secrets Management
teaser: CI pipelines need credentials to function — to push images, deploy to cloud, sign artifacts. How those credentials are stored, scoped, rotated, and audited determines whether the pipeline is a security asset or a single point of compromise.

@explanation

Every CI pipeline that interacts with external systems — a container registry, a cloud provider, an artifact store, a deployment target — requires credentials. The question is not whether CI will hold secrets, but how safely it holds them. The OWASP CI/CD Security Top 10 identifies "Insufficient Credential Hygiene" (CICD-SEC-6) as one of the most frequently exploited vulnerabilities in pipeline attacks.

CI secrets management patterns, ordered from least to most secure:

- **Hardcoded in YAML** — immediately compromised if the repository is ever public or the CI system is breached. Never acceptable.
- **CI platform secret stores** — GitHub Actions Secrets, GitLab CI Variables, CircleCI Contexts. Secrets are encrypted at rest and injected as environment variables at runtime. Access is restricted to specific workflows or environments. Adequate for most use cases; rotation is manual.
- **External secret managers** — HashiCorp Vault, AWS Secrets Manager, GCP Secret Manager. Secrets are retrieved at runtime by the pipeline with a short-lived token. Supports automatic rotation, fine-grained access policies, and full audit logs. Preferred for production pipelines.
- **OIDC federation (keyless auth)** — GitHub Actions, GitLab CI, and CircleCI all support OIDC tokens that allow pipelines to authenticate to cloud providers (AWS, GCP, Azure) without storing any long-lived credential. The CI platform presents a short-lived OIDC token; the cloud provider validates it and issues a temporary credential scoped to that specific workflow run.

```yaml
# GitHub Actions: keyless AWS auth via OIDC (no stored credentials)
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/ci-deploy-role
      aws-region: us-east-1
      # No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY needed
```

OIDC federation eliminates the largest class of CI credential theft: the static, long-lived key that a compromised runner can exfiltrate and use indefinitely. An OIDC token is valid for minutes and can only be used by the specific workflow that requested it. Adopt OIDC for all cloud provider authentication where supported.

> [!info] Scope every CI credential to the minimum required permissions for the specific job that needs it. A job that pushes a container image needs registry write access — not ECR admin, not IAM management. Apply least-privilege at the role or token level, not just at the secret store level.

@feynman

CI pipelines need passwords and tokens to do their work. The key is never storing long-lived credentials when you can use short-lived ones: OIDC lets your pipeline prove who it is to a cloud provider without ever storing a secret key.

@card
id: cicdp-ch07-c007
order: 7
title: SBOM Generation as a Build Artifact
teaser: A Software Bill of Materials is a machine-readable inventory of every component in a software artifact — its name, version, license, and known vulnerabilities. Generating one at build time transforms a snapshot into a searchable, auditable record of what shipped.

@explanation

The SBOM concept predates Executive Order 14028, but the EO made it prominent in the industry by requiring that all software sold to US federal agencies include an SBOM as of 2023. The NTIA minimum elements specification and CISA guidance define what an SBOM must contain: supplier name, component name, version, unique identifiers, dependency relationships, SBOM author, and timestamp.

Two SBOM formats have emerged as standards:

- **SPDX (Software Package Data Exchange)** — the Linux Foundation standard, now an ISO/IEC standard (ISO 5962:2021). Used widely in open source toolchains. Syft, the SPDX tools, and FOSSA produce SPDX output.
- **CycloneDX** — OWASP-governed, JSON/XML. Designed with security use cases in mind: native support for vulnerability enumeration, service dependencies, and hardware bills of materials. Supported by Syft, cdxgen, and Trivy.

Generating an SBOM with Syft at build time and attaching it to the container image:

```bash
# Generate SBOM in CycloneDX JSON format
syft myapp:${{ github.sha }} \
  -o cyclonedx-json=sbom.cyclonedx.json

# Attach the SBOM as an OCI attestation using cosign
cosign attest \
  --predicate sbom.cyclonedx.json \
  --type cyclonedx \
  myapp@$IMAGE_DIGEST

# The SBOM is now verifiable alongside the image
```

An SBOM generated at build time and attached to the image serves multiple purposes: vulnerability management (re-scan the SBOM when new CVEs are published to identify affected artifacts without rebuilding), license compliance (automated detection of GPL code in a proprietary product), and incident response (when a zero-day is announced, scan all SBOMs in the registry to find affected images in minutes rather than days).

> [!info] An SBOM stored as a separate file in an artifact repository is useful but fragile — the link between the SBOM and the artifact it describes depends on file naming conventions. Attaching the SBOM as an OCI attestation (via cosign attest) binds it cryptographically to the image digest, making the relationship tamper-evident and discoverable by tooling.

@feynman

An SBOM is an ingredient list for your software — every library, tool, and component that went into the build, with its exact version. Generating it automatically at build time means you always know what's in what you shipped.

@card
id: cicdp-ch07-c008
order: 8
title: SLSA: Supply-Chain Levels for Software Artifacts
teaser: SLSA is a security framework that defines four levels of supply chain integrity for software artifacts. At SLSA L2, builds are isolated and their provenance is signed. At SLSA L3, the build platform itself is the root of trust — not the developer.

@explanation

SLSA (pronounced "salsa") is a Google-originated framework for software supply chain security, now governed by the OpenSSF (Open Source Security Foundation). It was designed in direct response to incidents like SolarWinds (2020), where attackers compromised the build system to inject malicious code into signed, legitimate artifacts. The attack succeeded because artifact signing proved only that the artifact came from the organization — not that the build process was uncompromised.

SLSA defines four levels, each adding stronger guarantees about the build process:

- **SLSA L1** — the build process is documented and produces provenance (a record of how the artifact was built). Provenance may be self-attested. Provides visibility; no tamper protection.
- **SLSA L2** — provenance is generated by the build service (not the developer) and signed. Builds run on a hosted build platform (GitHub Actions, Google Cloud Build). A compromised developer workstation cannot forge provenance. This is the practical target for most organizations.
- **SLSA L3** — the build service is hardened: the build definition is non-forgeable, the build environment is ephemeral and isolated, and the provenance is generated by a trusted, independently verifiable component of the build platform. GitHub Actions achieves L3 for artifacts built with the official SLSA GitHub Generator.
- **SLSA L4** — two-party review of all build definition changes, hermetic builds with no network access, reproducible outputs. Currently aspirational for most organizations; the SLSA spec notes that L4 is not yet fully achievable with existing tooling.

A provenance document at SLSA L2 records:

```json
{
  "_type": "https://in-toto.io/Statement/v0.1",
  "predicateType": "https://slsa.dev/provenance/v0.2",
  "subject": [{
    "name": "ghcr.io/myorg/myapp",
    "digest": { "sha256": "abc123..." }
  }],
  "predicate": {
    "builder": { "id": "https://github.com/actions/runner" },
    "buildType": "https://github.com/slsa-framework/slsa-github-generator/generic@v1",
    "invocation": {
      "configSource": {
        "uri": "git+https://github.com/myorg/myapp@refs/heads/main",
        "digest": { "sha1": "def456..." },
        "entryPoint": ".github/workflows/release.yml"
      }
    }
  }
}
```

> [!info] SLSA provenance is built on the in-toto attestation framework (in-toto.io), which predates SLSA and provides the envelope format and signing specification. SLSA defines what must be in the provenance; in-toto defines how it is signed and verified. Understanding both is necessary to implement the full stack.

@feynman

SLSA is a graded security framework for proving how software was built. At the higher levels, a trusted build platform generates a signed receipt (provenance) that proves the artifact came from unmodified source code via an uncompromised build process — not just from your organization.

@card
id: cicdp-ch07-c009
order: 9
title: Sigstore and Cosign for Artifact Signing
teaser: Sigstore is a free, open infrastructure for signing software artifacts without managing long-lived signing keys. Cosign, its command-line tool, makes keyless signing using OIDC identity the default — any artifact, any registry, any CI system.

@explanation

Traditional artifact signing required managing cryptographic key pairs: generating them, storing the private key securely, rotating them periodically, distributing the public key for verification, and handling revocation. For most organizations, the key management overhead was prohibitive enough that signing was skipped. Sigstore was designed to eliminate that overhead entirely.

The Sigstore project (sigstore.dev), hosted by the Linux Foundation and supported by Google, Red Hat, and Chainguard, provides three components:

- **Cosign** — CLI tool for signing and verifying container images and other artifacts. Supports both keyless (OIDC-based) and keyed signing modes.
- **Fulcio** — a certificate authority that issues short-lived code signing certificates bound to an OIDC identity (a GitHub Actions workflow, a Google account, a GitHub user). The certificate is valid for 10 minutes — long enough to sign the artifact; too short to be useful if stolen.
- **Rekor** — a tamper-evident transparency log that records every signing event. Every signature produced by Fulcio is logged in Rekor with a timestamp. This creates an auditable, append-only record of what was signed, by whom, and when — analogous to Certificate Transparency for TLS.

Keyless signing in a GitHub Actions workflow:

```yaml
- name: Sign container image with cosign
  uses: sigstore/cosign-installer@v3

- name: Sign the image
  run: |
    cosign sign \
      --yes \
      ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
  env:
    COSIGN_EXPERIMENTAL: "1"  # enables keyless mode

# Verification at deploy time:
# cosign verify \
#   --certificate-identity-regexp="https://github.com/myorg/myrepo/.github/workflows/.*" \
#   --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
#   ghcr.io/myorg/myapp@sha256:abc123
```

Verification is the purpose of signing. A signed image that is deployed without verifying the signature is unsigned from a security perspective. Verification must happen at deploy time — in the Kubernetes admission controller, in the CD pipeline, or in the policy engine — not just at signing time.

> [!info] Cosign is now the de facto standard for container image signing in the cloud-native ecosystem. It is integrated into Docker Hub, GitHub Container Registry, and the major cloud provider registries. The SLSA GitHub Generator uses cosign internally to sign provenance attestations.

@feynman

Cosign lets you sign a container image to prove it came from a specific build process, without managing any cryptographic keys. The identity of the CI workflow acts as the signing key, and every signing event is logged in a public, tamper-evident record.

@card
id: cicdp-ch07-c010
order: 10
title: Provenance Attestations
teaser: A provenance attestation is a signed, machine-readable claim about how a software artifact was produced — what source commit, what build command, what environment. It transforms a container image from a black box into a verifiable record of its own origin.

@explanation

An attestation is a statement about an artifact: "this image was built from commit abc123, using Dockerfile at path Dockerfile, by GitHub Actions workflow release.yml, at 2024-01-15T14:23:00Z." A provenance attestation is a specific category of attestation that records how an artifact was produced — its build inputs, build environment, and build process.

The in-toto attestation framework provides the envelope: a standardized JSON structure with a subject (the artifact being attested), a predicate type (what kind of claim this is), and a predicate (the claim itself). SLSA provenance is an in-toto attestation with predicateType set to the SLSA provenance URI.

Generating SLSA provenance attestations using the official SLSA GitHub Generator:

```yaml
jobs:
  build:
    outputs:
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

  provenance:
    needs: build
    permissions:
      actions: read
      id-token: write
      packages: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v1.10.0
    with:
      image: ghcr.io/${{ github.repository }}
      digest: ${{ needs.build.outputs.image-digest }}
    secrets:
      registry-username: ${{ github.actor }}
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

The generated provenance document is attached to the container image as an OCI attestation and signed with cosign. Anyone pulling the image can verify the provenance:

```bash
# Verify SLSA provenance at deployment time
cosign verify-attestation \
  --type slsaprovenance \
  --certificate-identity-regexp="https://github.com/slsa-framework/slsa-github-generator/" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/myorg/myapp@sha256:abc123 | \
  jq '.payload | @base64d | fromjson | .predicate'
```

> [!info] OCI registries that support the Referrers API (OCI spec 1.1+) store attestations as referrers of the image manifest. This means the attestation travels with the image across registry copies — a critical property for supply chain verification in multi-registry deployments.

@feynman

A provenance attestation is a signed receipt that says exactly how and where a container image was built — the source code commit, the build tool, and the build environment. It lets anyone verify the claim without trusting the person making it.

@card
id: cicdp-ch07-c011
order: 11
title: Policy as Code (OPA, Kyverno)
teaser: Policy as Code moves security and compliance rules out of wikis and spreadsheets and into the pipeline, where they are version-controlled, testable, and automatically enforced. OPA and Kyverno are the two dominant engines for expressing and evaluating these policies.

@explanation

Security policies that live in documents are aspirational. Security policies that live in code are enforced. Policy as Code is the practice of expressing organizational security and compliance requirements as machine-evaluable rules that run in the pipeline or at cluster admission time, automatically blocking non-compliant artifacts from progressing.

Open Policy Agent (OPA) is a general-purpose policy engine from Styra (now CNCF graduated). Its policy language, Rego, is a declarative query language for expressing policies over structured data. OPA evaluates a policy against an input document (a container image config, a Kubernetes manifest, an API request) and returns a decision.

```rego
# OPA policy: deny container images without a verified SLSA provenance attestation
package pipeline.security

import future.keywords.if
import future.keywords.in

default allow := false

allow if {
  # Image must have a signed provenance attestation
  some attestation in input.attestations
  attestation.predicateType == "https://slsa.dev/provenance/v0.2"
  attestation.verified == true

  # Builder must be the official GitHub Actions SLSA generator
  attestation.predicate.builder.id ==
    "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v1.10.0"
}

deny[msg] if {
  not allow
  msg := sprintf("Image %v lacks verified SLSA L3 provenance", [input.image])
}
```

Kyverno is a Kubernetes-native policy engine that operates as an admission controller. It expresses policies as Kubernetes custom resources (no Rego required), making it more accessible for platform teams already fluent in Kubernetes manifests.

```yaml
# Kyverno policy: require signed images from the internal registry
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-image-signature
      match:
        any:
          - resources:
              kinds: [Pod]
      verifyImages:
        - imageReferences: ["ghcr.io/myorg/*"]
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/myorg/myapp/.github/workflows/*"
                    issuer: "https://token.actions.githubusercontent.com"
```

> [!info] Use OPA/Conftest for pipeline-time policy evaluation (before the image is deployed) and Kyverno for cluster admission control (when the image is deployed). Both layers are necessary: pipeline policy prevents non-compliant images from reaching the registry; admission control prevents them from running even if they reach the registry by other means.

@feynman

Policy as Code means your security rules are written in a programming language, checked into version control, and automatically enforced by the pipeline or the cluster. Instead of a policy document that says "images must be signed," you have code that refuses to deploy unsigned images.

@card
id: cicdp-ch07-c012
order: 12
title: The Security Pipeline Anti-Pattern
teaser: The security pipeline anti-pattern is treating security as a dedicated pipeline stage that runs last, is the first to be skipped under pressure, and whose findings go to a queue no one owns. Security embedded this way is security in name only.

@explanation

The security pipeline anti-pattern is so prevalent it deserves a formal description. It follows a recognizable lifecycle: a security team mandates that every pipeline include a security scan. An engineer adds a Snyk scan as the final stage before deployment. The scan runs. Findings appear. Nobody is sure what to do with them. Under the next deadline, someone sets the scan to warn-only. Later, it is moved to a parallel job so it does not block deployment. Eventually it is in a nightly cron job that nobody reviews. The pipeline has a security stage. The pipeline has no security.

The failure modes that characterize the anti-pattern:

- **Security as the final stage** — placing security checks last means they run after the team has committed to releasing. The social pressure to ship overrides the security signal. Security must be embedded at multiple points in the pipeline, not concentrated at the end.
- **Warn-only mode** — a security gate configured to warn but not fail is not a gate; it is a log statement. Every security check must have a defined threshold that triggers a pipeline failure. "We'll look at findings on Fridays" is not an enforcement policy.
- **No findings owner** — security findings that route to a shared inbox, a Jira board with a "security" label, or a Slack channel nobody monitors will age indefinitely. Every category of finding must have a named team with an SLA for response.
- **Bypass without audit** — a security gate that can be bypassed without creating an audit record provides no assurance. Bypasses must require explicit approval, generate an audit log entry, and trigger a review within 24 hours.
- **Tools without process** — adding Trivy, Semgrep, Gitleaks, and cosign to a pipeline without defining what each tool's findings mean for the release decision is tooling theater. Each tool's output must connect to a defined action: block, fix within N days, accept with documented risk.

The correct model is that the security posture of a codebase is a property of the pipeline design — not the output of a scanner. SAST at the PR gate, SCA with defined severity thresholds, secret scanning at pre-commit and CI, SBOM generation at build, provenance attestation at sign, and policy verification at deploy: these are design decisions that make the pipeline the security boundary. Scanners are the instrumentation; the pipeline is the enforcement mechanism.

> [!warning] The OWASP CI/CD Security Top 10 (CICD-SEC-7) describes "Insecure System Configuration" as a common finding: security tooling installed but not tuned, running in non-blocking mode, or reporting to destinations nobody monitors. A security audit that checks for the presence of tooling without evaluating its configuration and enforcement posture provides false assurance.

@feynman

Security bolted to the end of the pipeline — running last, set to warn-only, with findings nobody owns — is not security. It is a checkbox that gives false confidence. Real security is embedded throughout the pipeline and blocks progress when its conditions are not met.
