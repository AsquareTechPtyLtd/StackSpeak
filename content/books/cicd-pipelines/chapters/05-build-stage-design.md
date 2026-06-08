@chapter
id: cicdp-ch05-build-stage-design
order: 5
title: Build Stage Design
summary: Compile vs package vs containerize, build determinism, hermetic builds, remote build caches, and SBOM generation as a build-time artifact — turning the build stage from a black box into an auditable, reproducible boundary.

@card
id: cicdp-ch05-c001
order: 1
title: What "Build" Really Means
teaser: "Build" in CI/CD is not a synonym for "compile" — it is a broad boundary that transforms source code into a versioned, verifiable artifact ready for the rest of the pipeline to act on.

@explanation

In casual usage, "the build" refers vaguely to whatever a CI server does with your code. In pipeline design, it has a precise meaning: the build stage is the single boundary at which source transforms into artifact. Everything upstream of this boundary is code; everything downstream is artifact.

This boundary carries several responsibilities:

- **Transformation.** Source code in its raw form cannot be deployed. The build stage converts it into a form that can: a compiled binary, a JAR, a container image, a Lambda zip, a Helm chart.
- **Verification.** The act of building is itself a test: if the build fails, the source is demonstrably broken. Compilation errors, missing dependencies, and broken asset pipelines surface here.
- **Versioning.** Every artifact produced by the build must carry a unique, immutable identifier — a semantic version, a Git SHA, or a content-addressed hash — so the rest of the pipeline can reason about what, exactly, it is acting on.
- **Provenance capture.** The build stage is where you record what went in (source commit, dependency versions, build toolchain version) so that you can reconstruct, audit, or challenge the artifact later.

The SLSA (Supply chain Levels for Software Artifacts) framework formalizes this: a build platform must produce artifacts with a signed provenance attestation that records the build inputs, the build environment, and the outputs. Without that provenance, the artifact is an untraceable black box.

The practical implication: any action taken after the build stage — testing, scanning, deploying — operates on the *artifact*, never on source again. A pipeline that re-compiles during the deploy stage has broken this contract and introduced the possibility that what was tested is not what was deployed.

> [!info] The build stage is not just a step — it is an architectural boundary. Every property of the artifact (its identity, its reproducibility, its security posture) is decided here. Treating it as a black box is how organizations lose traceability.

@feynman

"Build" means: take source code and produce a versioned, verifiable package that the rest of the pipeline can hand around without ever touching source again.

@card
id: cicdp-ch05-c002
order: 2
title: Compile vs Package vs Containerize
teaser: Compiling, packaging, and containerizing are three distinct build operations that are often conflated — understanding which one you are doing, and in what order, is prerequisite to designing a build stage that is fast, reproducible, and auditable.

@explanation

Most non-trivial build stages perform all three operations, but they operate at different layers of abstraction and have different reproducibility and caching properties.

- **Compile.** Translates source code into executable machine code or an intermediate representation (JVM bytecode, WASM, LLVM IR). The inputs are source files and compiler flags; the outputs are object files, class files, or a native binary. For interpreted languages, this step is absent or trivially thin (e.g., syntax checking, type checking with mypy or tsc).
- **Package.** Collects compiled outputs, static assets, configuration templates, and runtime dependencies into a distributable unit. A JAR assembles class files and a manifest. A Python wheel bundles modules and metadata. An npm tarball captures transpiled JS and package.json. The package is the deployable artifact for non-containerized runtimes.
- **Containerize.** Wraps a package — along with its OS-level runtime dependencies — in an OCI-compliant image. The Dockerfile (or equivalent Buildpacks config) layers a base image, installs system packages, copies the application package, and defines the entrypoint. The result is a self-contained, portable unit of deployment.

The ordering matters: compile first, package second, containerize last. Inverting these (e.g., running compilation inside the final container image layer) tends to produce large, cache-unfriendly images that include build toolchains in the production artifact.

Docker multi-stage builds address this by separating the build environment from the runtime environment. A *builder stage* installs the compiler and dependencies and runs the compilation. A *runtime stage* starts from a minimal base image and copies only the compiled output. The final image contains no compiler, no source, no build cache — only the binary and its runtime dependencies.

Bazel and Buck treat all three operations as declared graph nodes. A `cc_binary` rule compiles; a `pkg_tar` rule packages; an `oci_image` rule (via rules_oci) containerizes. Each step is independently cacheable and auditable.

> [!warning] Including build tools (compilers, bundlers, test runners) in the production container image is a common misconfiguration. It bloats the image, expands the attack surface, and means the production artifact differs structurally from what should be deployed.

@feynman

Compile turns source into machine-readable code; package bundles it for distribution; containerize wraps it with its runtime environment. These are separate steps, not one monolithic "build."

@card
id: cicdp-ch05-c003
order: 3
title: Build Artifacts as the Pipeline Currency
teaser: The artifact is the unit of exchange across every stage of the pipeline — it is what gets tested, scanned, promoted, and deployed. Treating it as fungible or optional destroys traceability.

@explanation

A CI/CD pipeline is best understood as a series of quality gates, each of which takes an artifact as input and either approves it for the next gate or rejects it. The artifact is the only thing that passes between stages. Source code does not flow past the build boundary.

This has concrete design implications:

- **One build, many deployments.** An artifact built from a given commit should be deployed identically to staging, pre-production, and production. Rebuilding from source for each environment introduces the possibility that the builds differ — a class of bug that is extremely difficult to diagnose.
- **Identity through the pipeline.** The artifact's identifier (SHA256 digest for container images, content hash for Bazel outputs) must be verifiable at every stage. A test stage that cannot confirm it is testing the exact artifact that will be deployed is performing expensive theater.
- **Artifacts carry metadata.** OCI image labels, JAR manifest attributes, and Bazel build metadata attach structured data to the artifact: the commit SHA, the build timestamp, the CI job ID, the author. This metadata is the audit trail for production incidents.
- **Artifacts enable rollback.** If the artifact from the previous release is available in an artifact repository, rollback is an artifact promotion — not a rebuild. This is substantially faster and eliminates the risk that the rollback build differs from the original.

The in-toto framework (adopted by SLSA) makes this explicit by requiring a signed attestation for each step in the supply chain. Each stage that receives an artifact verifies the attestation from the previous stage before proceeding. An artifact without a verifiable attestation chain is treated as untrusted.

The practical failure mode: pipelines that re-run `docker build` in the deploy stage because they did not store the artifact from the build stage. The second build will differ from the first if any dependency has changed — including the base image.

@feynman

The artifact is what passes through every pipeline gate. If you rebuild it at each stage, you can no longer prove that what you tested is what you deployed.

@card
id: cicdp-ch05-c004
order: 4
title: The Artifact Repository
teaser: An artifact repository is the single source of truth for versioned, immutable build outputs — it is the mechanism by which artifacts travel through pipeline stages, environments, and time.

@explanation

An artifact repository (also called an artifact registry) is a content-addressed, versioned store for build outputs. It is distinct from source control (which stores code) and from a container runtime (which runs images). It is the transit system for artifacts.

The major categories and their canonical tools:

- **Container registries.** OCI-compliant registries store and serve container images and OCI artifacts. Options: Docker Hub, AWS ECR, Google Artifact Registry, GitHub Container Registry (ghcr.io), Harbor (self-hosted). Images are addressed by digest (SHA256) and tagged with human-readable labels.
- **Language-ecosystem repositories.** Maven Central and Sonatype Nexus for JVM artifacts; PyPI and devpi for Python wheels; npm registry for JavaScript packages; crates.io for Rust. These often host both public dependencies and internal private packages.
- **Generic binary stores.** JFrog Artifactory and Sonatype Nexus support arbitrary binary artifacts — Helm charts, Terraform modules, Lambda ZIPs, and anything that doesn't fit a language-specific format.
- **Bazel remote cache and CAS.** Bazel's content-addressable storage (CAS) stores intermediate build outputs keyed by content hash, enabling fine-grained artifact reuse across builds and machines.

The critical property of an artifact repository is **immutability**. Once an artifact is published at a given version or digest, it must not be modified. Mutable artifacts break the premise that a given identifier always refers to the same content — which breaks reproducibility, rollback, and audit trails simultaneously.

Artifact repositories also serve as the gating mechanism for promotion. An artifact that has not been published to the repository has not passed the build stage. An artifact that has been moved to a "production-approved" repository has passed all quality gates. Promotion is an administrative action on the repository, not a rebuild.

> [!tip] Enable immutable tags in your container registry (ECR's "image tag immutability," for example) to prevent overwriting. A mutable "latest" tag in production is a known incident waiting to happen.

@feynman

An artifact repository is the warehouse where every build result is stored with a permanent address — the pipeline picks artifacts up from there, rather than rebuilding them each time.

@card
id: cicdp-ch05-c005
order: 5
title: Build Caches and Their Limits
teaser: A build cache stores intermediate outputs so that unchanged inputs can be skipped — but a cache that is shared incorrectly, invalidated poorly, or trusted blindly can silently corrupt builds or create false security.

@explanation

Build caches exist to make incremental builds fast. Instead of recompiling every file from scratch on every push, a cache stores the output of each compilation unit. If the input to that unit — the source file, its dependencies, the compiler version, the flags — has not changed, the cached output is used directly.

The three common cache mechanisms in CI:

- **Dependency caches.** npm's node_modules, pip's .pip cache, Maven's .m2 repository. These are typically stored by the CI platform between runs, keyed on lockfile hash. They eliminate re-downloading packages, not re-compiling code.
- **Layer caches.** Docker's layer cache reuses intermediate image layers if the Dockerfile instruction and its inputs haven't changed. BuildKit (Docker's modern build backend) adds parallel layer execution and mount-based caches. The cache is invalidated sequentially: any changed layer invalidates all layers above it.
- **Build tool caches.** Gradle's build cache, Bazel's local cache, Cargo's incremental compilation. These operate at finer granularity than layer caches — individual compilation units — and produce more reliable cache hits on partial code changes.

The limits of build caches are significant:

- **Staleness.** A cache that is not invalidated when the build environment changes (new compiler version, new base image) will serve outputs that were produced by a different toolchain than the one nominally in use.
- **Poisoning.** A shared build cache that does not verify the integrity of cached entries can serve a maliciously or accidentally modified output. This is a supply chain risk, not a correctness risk.
- **Non-determinism leakage.** A build that embeds timestamps, random seeds, or hostname information in its outputs will produce cache misses that defeat the purpose of caching — and cache hits that serve subtly wrong outputs.

> [!warning] Caches do not substitute for artifact repositories. A cache miss falls through to rebuilding; a missing artifact from the repository is a pipeline failure. Design your pipeline so it works correctly with a cold cache — the cache is a performance optimization, not a correctness dependency.

@feynman

A build cache is an optimization: skip work whose inputs haven't changed. It is not a storage system for artifacts and not a substitute for deterministic builds.

@card
id: cicdp-ch05-c006
order: 6
title: Remote Build Caches at Scale
teaser: Remote build caches let every developer and every CI machine share a single pool of cached build outputs — eliminating redundant compilation across an engineering organization and making monorepo-scale builds tractable.

@explanation

Local build caches are scoped to a single machine or a single CI runner. If two developers each change a different file in a large monorepo, they each rebuild the entire project from scratch on their next run — even though most of the compiled outputs from yesterday's shared CI run are identical.

Remote build caches solve this by externalizing the cache to a network-accessible content-addressable store. Every build — local or CI — looks up cache entries by input hash. A hit is a download; a miss triggers compilation and an upload, making the result available to all future builds with the same inputs.

The major implementations:

- **Bazel Remote Cache.** Bazel's Remote Execution API (REAPI) defines a standard protocol for content-addressable storage and optional remote execution. Compatible backends include Google Cloud Storage (with bazel-remote as a proxy), BuildBuddy, EngFlow, and Buildkite's Remote Cache service. Cache keys are derived from the action graph hash — inputs, command, and environment variables.
- **Gradle Build Cache.** Gradle supports a remote build cache backed by a Gradle Enterprise server (now Develocity) or any HTTP endpoint. Task outputs are stored by input hash and shared across CI agents.
- **Turborepo and Nx.** JavaScript monorepo tools that implement remote caching as a first-class feature. Turborepo's remote cache (hosted by Vercel or self-hosted) distributes task outputs across machines. Nx Cloud provides the same with detailed build analytics.
- **Buck2 remote cache.** Meta's Buck2 uses the same REAPI protocol as Bazel, enabling compatibility with the same cache backend infrastructure.

Security considerations for remote caches are non-trivial. The cache backend must:

- Verify TLS for all cache reads and writes — an unauthenticated cache is a cache poisoning vector.
- Enforce write authentication so only trusted CI systems can populate the cache.
- Optionally enforce content digest verification on reads (Bazel does this by default when `--remote_verify_downloads` is set).

> [!info] A well-configured Bazel remote cache can reduce monorepo CI times from 30+ minutes to under 5 minutes by sharing compiled outputs across the entire team. The prerequisite is build determinism — a non-deterministic build defeats remote caching entirely.

@feynman

A remote build cache is a shared pool of previously computed build outputs — when your inputs match what someone else already built, you download the result instead of recomputing it.

@card
id: cicdp-ch05-c007
order: 7
title: Build Determinism
teaser: A deterministic build produces byte-for-byte identical outputs every time it is run with the same inputs — this property is the foundation of caching, reproducibility, and supply chain security.

@explanation

Determinism is a weaker property than reproducibility (which we will cover in the next card) but a prerequisite for it. A build is deterministic if running it twice with identical inputs — same source, same toolchain, same flags — produces identical outputs.

Determinism breaks down in several common ways:

- **Timestamps.** Many build tools embed the build timestamp in generated outputs: Java JAR manifests, Go binaries, webpack bundle comments. The same source at two different times produces different bytes.
- **File system ordering.** Tools that iterate over directory contents may process files in different orders depending on the OS and filesystem. This produces different link ordering, different archive entry ordering, or different initialization sequences.
- **Non-stable map and set iteration.** Go deliberately randomizes map iteration order across runs. Code generators or build plugins that serialize map contents without sorting will produce different outputs on each run.
- **Absolute paths.** Debug symbols and DWARF data embed the absolute path of source files. A build from /home/alice/project and a build from /home/bob/project produce different binaries even with identical source.
- **Random seeds.** Some optimizers (Closure Compiler, ProGuard) use randomization in name mangling or layout. Without a fixed seed, outputs vary.

Bazel enforces determinism by design. Every action runs in a sandbox with no access to the ambient environment (no timestamps, no hostname, no environment variables outside an explicit allowlist). Outputs that violate this — for example, a genrule that calls `date` — will produce non-deterministic results that bypass caching.

The Go toolchain achieved deterministic builds in 1.13 by normalizing build identifiers and stripping absolute paths by default. Docker BuildKit introduced `SOURCE_DATE_EPOCH` support, allowing layer timestamps to be fixed to the commit date rather than the build time.

> [!tip] To test for determinism, run your build twice in a row with identical inputs and diff the outputs with sha256sum. Any difference indicates a non-determinism source. The diffoscope tool can pinpoint where two binary artifacts diverge.

@feynman

A deterministic build gives you the same output bytes every time you provide the same inputs. Without this, caches break and you cannot verify that two builds of the same commit are equivalent.

@card
id: cicdp-ch05-c008
order: 8
title: Hermetic Builds
teaser: A hermetic build is one that cannot read from or write to anything outside its explicitly declared inputs and outputs — hermiticity is what makes determinism achievable at scale and what closes the most common supply chain attack vectors.

@explanation

Hermiticity is a stricter property than determinism. A build can be deterministic by coincidence — if its implicit environmental dependencies happen to be stable. A hermetic build is deterministic *by construction*: it structurally cannot access anything it has not declared.

Bazel implements hermiticity through action sandboxing. Every build action (compilation, code generation, linking) runs in a sandbox with:

- A read-only view of only the declared input files.
- A writable scratch directory for output files.
- No network access (by default) — dependencies must be pre-fetched and declared.
- A filtered environment with only the variables declared in the action definition.

Actions that attempt to read undeclared files or access the network fail immediately. This forces every dependency to be explicit — which is annoying to set up and invaluable at scale.

Nix takes hermiticity further into the system level. A Nix derivation specifies its build inputs as cryptographic hashes of packages in the Nix store. The build environment is constructed from exactly those packages — no system-installed compiler, no ambient library, no PATH inheritance. Two machines with the same Nix expression will build from identical toolchains even if they are running different Linux distributions.

The supply chain security benefit is concrete. A non-hermetic build that reaches out to the network during build time can fetch a dependency that has been modified since the lockfile was generated — a category of attack executed against the Python ecosystem multiple times (the *event-stream* npm compromise being a canonical example). A hermetic build cannot make that network call at all.

> [!info] SLSA level 3 requires that the build platform prevent builds from accessing the network and injecting arbitrary environment variables. Hermetic builds are the implementation mechanism for meeting that requirement.

@feynman

A hermetic build is one that can only see what it declared it would need — no ambient system files, no network calls, no inherited environment variables. Everything that goes in is listed; everything that comes out is verified.

@card
id: cicdp-ch05-c009
order: 9
title: Reproducible Builds
teaser: A reproducible build is one that can be independently re-executed by a third party — starting from the same source — and produce bit-for-bit identical outputs, enabling independent verification of the artifact without trusting the original build system.

@explanation

The Reproducible Builds project (reproducible-builds.org), founded in collaboration with Debian, Tor, and Bitcoin Core, defines reproducibility as the ability of independent parties to verify that a published binary corresponds to the claimed source code. This is a stronger guarantee than determinism: it means anyone, anywhere, with access to the source and the build specification can reproduce the artifact.

Why this matters:

- **Trust without access.** A user downloading a binary from a package registry cannot inspect the build system that produced it. If the build is reproducible, they can verify the binary against the source themselves, without trusting the distributor's CI infrastructure.
- **Detecting build-time compromise.** A compromised CI system (XcodeGhost, SolarWinds, 3CX) injects malicious code into artifacts at build time. If independent builders reproduce the binary and get a different hash, the compromise is detectable.
- **Verifying the supply chain.** SLSA level 4 requires that the build be reproducible: two independent builds from the same source must match. This makes supply chain attestations independently verifiable.

The prerequisites for reproducibility extend beyond determinism: the build environment itself must be reproducible. This means:

- Pinned toolchain versions (not "latest gcc" or "latest node").
- Pinned base images with content-addressed digests, not mutable tags.
- SOURCE_DATE_EPOCH set to a deterministic value (typically the commit timestamp).
- Archived build dependencies (no live network fetches from package registries).

Nix is the toolchain most closely associated with reproducible builds in practice. A Nix flake pins the entire build graph — including the compiler — to cryptographic hashes. Building a Nix flake on two different machines with two different OSes produces identical outputs (modulo OS-level differences in the kernel ABI, which Nix's *impure* inputs explicitly model).

@feynman

A reproducible build lets anyone independently verify that a binary matches its source — you don't have to trust the build system; you can rerun it yourself and check.

@card
id: cicdp-ch05-c010
order: 10
title: SBOM Generation at Build Time
teaser: A Software Bill of Materials (SBOM) is a machine-readable inventory of every component in an artifact — libraries, transitive dependencies, license identifiers — and the build stage is the only moment in the pipeline where it can be generated accurately.

@explanation

An SBOM (Software Bill of Materials) is a structured document that declares what an artifact is made of. In the way a manufactured product has a bill of materials listing every component and subcomponent, a software artifact has an SBOM listing every library, framework, and transitive dependency — along with their versions and known vulnerability identifiers.

The two dominant SBOM formats are:

- **SPDX (Software Package Data Exchange)** — an ISO standard (ISO/IEC 5962:2021) originally developed by the Linux Foundation. Supports JSON, YAML, RDF, and tag-value formats.
- **CycloneDX** — developed by OWASP. JSON and XML formats. More widely adopted in commercial tooling and better integrated with vulnerability databases.

Build time is the correct moment to generate the SBOM because it is the only moment when the full dependency graph is resolved and verifiable:

- The lockfile has been consulted; transitive dependencies are known.
- The compiler has run; unused dependencies may have been excluded.
- The container image layers are being assembled; system packages are enumerable.

Common SBOM generation tools by ecosystem:

- **Syft (Anchore)** — scans container images and filesystems to produce CycloneDX or SPDX SBOMs. Runs as a post-build step against the final image.
- **Trivy** — vulnerability scanner that also produces SBOMs. Can scan images, filesystems, and git repositories.
- **cdxgen** — generates CycloneDX SBOMs from language manifest files (package.json, pom.xml, Cargo.toml) with deep dependency resolution.

Once generated, the SBOM should be attached to the artifact as an OCI attestation using Cosign (`cosign attest --type cyclonedx`). This links the SBOM to the image digest cryptographically and allows downstream tools to verify and consume it without a separate out-of-band lookup.

> [!info] US Executive Order 14028 (2021) mandates SBOMs for software sold to the US federal government. SBOM generation is no longer optional for enterprise vendors — building it into the CI pipeline is the only operationally sustainable approach.

@feynman

An SBOM is an ingredient list for your software artifact. You generate it at build time because that's the moment you know exactly what went in.

@card
id: cicdp-ch05-c011
order: 11
title: Immutable Infrastructure as a Build Output
teaser: When infrastructure configuration is compiled into an artifact at build time — rather than configured at deploy time — the infrastructure itself becomes reproducible, auditable, and promotable through environments.

@explanation

Immutable infrastructure is the practice of never modifying a running system in place. Instead, when a change is required, a new artifact is built from a new definition, deployed to replace the old one, and the old one is terminated. The key insight is that the artifact — not the running instance — is the source of truth.

This principle extends the build stage's responsibility beyond application code:

- **VM images (AMIs, Azure managed images).** Packer builds machine images from a declarative template. The image captures the OS, installed packages, configuration files, and application binaries at a specific commit. Deploying means launching a new instance from the new image, not ssh-ing into an existing one to upgrade it.
- **Container images.** The OCI image format is the dominant immutable infrastructure artifact. A container image is a layered, content-addressed bundle. Once built, it is never patched in place — it is replaced by a new image.
- **Helm charts and Kubernetes manifests.** Rendered Helm charts and kustomize outputs can be treated as build artifacts: render once at build time (with pinned values), store in the artifact repository, deploy the rendered manifest. Avoids environment-specific rendering at deploy time.

The pipeline implication is significant: if the artifact is truly immutable, promotion is the pipeline's core mechanism. The same container image digest that passed integration tests in staging is the exact artifact deployed to production. No rebuild, no re-render, no reconfiguration — just a new pointer in the artifact repository.

Immutability also simplifies rollback. Since the previous artifact is stored in the registry with its original digest, reverting a production deploy is an artifact promotion in reverse — pulling the last known-good digest back into service.

> [!warning] Mutable infrastructure artifacts defeat the purpose of artifact promotion. If a Helm chart is rendered differently for production than it was for staging (different values files, different templating), you are not promoting the artifact — you are building a new, untested one.

@feynman

Immutable infrastructure means your infrastructure is baked into an artifact at build time and never changed in production — when something needs updating, you build a new artifact and replace the old one.

@card
id: cicdp-ch05-c012
order: 12
title: Artifact Promotion Through Environments
teaser: Artifact promotion is the practice of advancing the same, unchanged artifact through a sequence of environments by changing its registry location or metadata — not by rebuilding it — maintaining the integrity of everything tested upstream.

@explanation

Artifact promotion is the mechanism by which a build output moves through the pipeline without being rebuilt. The artifact produced in the build stage is the artifact that reaches production — every stage between build and production examines and approves it, but none of them modify it.

In practice, promotion is implemented through one of three mechanisms:

- **Registry re-tagging.** An OCI image is initially pushed to a staging repository (e.g., myregistry/app:sha-abc123). After passing all quality gates, it is tagged or copied to a production repository (e.g., myregistry-prod/app:sha-abc123). The image digest is unchanged; only its location changes. Tools: `crane copy`, `skopeo copy`, AWS ECR replication.
- **Promotion policies in artifact repositories.** JFrog Artifactory and Sonatype Nexus support repository promotion policies: an artifact in a "ci" repository is promoted to a "release" repository when manually or automatically triggered. The binary is identical; the repository context changes.
- **Metadata-driven promotion.** Cosign and Sigstore attestations can record the passage through each quality gate as a signed attestation on the artifact. A deploy tool that requires a "security-scan-passed" attestation and a "integration-test-passed" attestation before deploying is implementing metadata-driven promotion.

The critical principle: promotion is an administrative act, not a technical one. The digest of the artifact does not change. Any system that changes the artifact as part of promotion has broken the chain of custody.

In a SLSA-compliant pipeline, each promotion step is itself attested: a signed statement recording that this artifact, identified by this digest, passed this quality gate at this timestamp, authorized by this identity. The chain of attestations constitutes an auditable record of the artifact's journey from source to production.

The practical benefit: when an incident occurs in production, the audit trail answers "what is running, when did it get there, who authorized it, and what tests did it pass?" without requiring anyone to reconstruct that information manually.

> [!tip] Use image digests, not tags, for deployments. A tag like "v1.2.3" can be overwritten; a digest like "sha256:abc123..." is immutable. Kubernetes deployments specified by digest are immune to tag mutation bugs.

@feynman

Artifact promotion means the same binary that passed your tests in staging is the exact binary deployed to production — you change where it lives in the registry, not what it is.
