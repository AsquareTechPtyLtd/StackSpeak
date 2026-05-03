@chapter
id: plf-ch04-self-service-provisioning
order: 4
title: Self-Service Provisioning
summary: Self-service provisioning is the platform-engineering "killer feature" — turning a multi-day ticket into a one-command request — and the design choice between scaffolding, IaC modules, and platform-as-API determines how far self-service can go.

@card
id: plf-ch04-c001
order: 1
title: The Ticket-to-Self-Service Value Proposition
teaser: The platform's value is measured in the time delta between "I need a new service" and "I have a running service" — shrinking that from days to minutes is the core promise.

@explanation

Before a platform team exists, provisioning a new service follows a familiar ritual: file a JIRA ticket, wait for an infrastructure engineer to pick it up, iterate on the requirements over Slack, watch it sit in a queue during a sprint boundary, and finally receive access credentials a week later — if nothing needed revisiting.

The "ticket-to-self-service" framing names this delta explicitly: the time between a developer's request and a running, correctly-configured resource is the platform's primary metric. When that number is a week, developers work around the process — spinning up shadow infrastructure, reusing existing resources incorrectly, or deferring work entirely. When it is two minutes, they use the platform as a natural part of their workflow.

The value proposition is not automation for its own sake. It is the compounding effect of hundreds of developers getting unblocked on the same day they had the need. The platform team's job is to absorb the toil once so every development team never has to absorb it again.

What "self-service" actually means in practice:

- A developer runs a command, fills in a web form, or merges a pull request.
- The platform provisions real infrastructure — cloud resources, secrets, DNS, monitoring — without human involvement.
- The developer has working credentials and endpoints within minutes.
- The result is consistent: the same template, the same security posture, the same naming convention, every time.

The tradeoff is real: building the self-service layer takes significant upfront investment. The platform team must turn tribal knowledge into code, and that code must be maintained. Teams that skip the investment pay the tax on every future provisioning request instead.

> [!info] The single most useful metric for a platform team to track is "time to first deployment for a new service." It makes the value proposition concrete and visible to engineering leadership.

@feynman

Self-service provisioning is like replacing a restaurant order system where you shout at a chef in the back with a touchscreen menu — the kitchen is just as real, but you no longer need a human relay in the middle.

@card
id: plf-ch04-c002
order: 2
title: Service Templates and Scaffolding
teaser: Service templates encode your organization's opinions about how a new service should start — directory layout, CI pipeline, Dockerfile, observability hooks — so developers inherit the right defaults without reading a wiki.

@explanation

The simplest form of self-service provisioning is a service scaffold: a parameterized project template that produces a ready-to-deploy repository when given a service name and a handful of inputs.

**cookiecutter** is the classic approach for this at the file-system level. A `cookiecutter` template is a directory tree with `{{cookiecutter.service_name}}` placeholders throughout. Running `cookiecutter gh:your-org/service-template` prompts the developer for values and renders a fully formed project.

```text
service-template/
  {{cookiecutter.service_name}}/
    src/
    Dockerfile
    .github/
      workflows/
        ci.yml
    helm/
      Chart.yaml
      values.yaml
    README.md
```

**Backstage Software Templates** operate at a higher level. Rather than a CLI tool, they expose a web form in the Backstage developer portal. A template YAML file declares the input fields, the scaffolding steps, and the post-creation actions — such as registering the new service in the catalog, creating the GitHub repository, and triggering an initial CI run.

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: new-service
spec:
  parameters:
    - title: Service Details
      properties:
        name:
          type: string
        owner:
          type: string
  steps:
    - id: fetch
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
    - id: publish
      action: publish:github
      input:
        repoUrl: github.com?owner=my-org&repo=${{ parameters.name }}
    - id: register
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
```

The "new service in 2 minutes" pattern refers to the complete flow: form submission to a working, registered, CI-enabled repository in under 120 seconds. The template is the product; maintaining it as the organization's standards evolve is the platform team's ongoing responsibility.

The risk is template drift — when the template falls behind the current standard, scaffolded services start in a worse state than existing ones. Treat the template as a first-class software artifact: version it, test it, review changes to it.

@feynman

A service template is like a house builder's standard floor plan — customers can pick options and customize finishes, but the structural decisions, plumbing layout, and electrical codes are already baked in before anyone breaks ground.

@card
id: plf-ch04-c003
order: 3
title: IaC Modules as a Platform Product
teaser: When the platform team publishes Terraform modules or Pulumi components as an internal library, they are shipping infrastructure as a product — with an API, versioning, and a contract about what gets created.

@explanation

Infrastructure-as-code modules are the mechanism that lets self-service provisioning scale without requiring every developer to understand cloud provider APIs. The platform team writes the module once, encodes the organization's security and cost defaults into it, and publishes it. Developers call the module with a handful of inputs.

**Terraform module pattern:**

```hcl
module "api_service" {
  source  = "git::https://github.com/my-org/terraform-modules.git//modules/api-service?ref=v2.3.0"

  name        = "payments-api"
  environment = "production"
  cpu         = 512
  memory      = 1024
  port        = 8080
}
```

Behind the module, the platform team controls what actually gets created: an ECS task definition, an ALB target group, security group rules, CloudWatch log groups, an IAM role with least-privilege permissions, and an SSM Parameter Store path for secrets. The developer sees four inputs; the module produces forty resources.

**Pulumi components** achieve the same pattern in a programming language rather than HCL. A `ApiServiceComponent` class can accept typed constructor arguments, validate inputs, and emit any Pulumi resource underneath. Teams that prefer typed interfaces and IDE autocompletion often prefer this model.

The platform team's module library is a product. That means it needs:

- **Versioned releases** — callers pin to `v2.3.0`, not `main`. Breaking changes require a major version bump.
- **A changelog** — so teams know what changed and whether they should upgrade.
- **Validation** — `terraform validate` and policy-as-code checks in CI for every module PR.
- **Documentation** — input/output descriptions generated from code, not maintained separately.

The failure mode is publishing modules that encode yesterday's standards. When the security baseline changes (say, all S3 buckets must enable object-lock), the platform team must update the module and communicate the upgrade path — not assume teams will discover the change on their own.

> [!warning] A module library without a versioning strategy creates a maintenance trap: teams are afraid to update because they don't know what will break, and the module slowly diverges from the standard it was meant to enforce.

@feynman

A platform IaC module is like a building code rolled into a blueprint — the developer specifies how many floors and where the windows go, and the module silently enforces that the walls are load-bearing, the wiring meets spec, and the exits are properly placed.

@card
id: plf-ch04-c004
order: 4
title: GitOps as the Provisioning Channel
teaser: When the desired state of infrastructure lives in a Git repository, a pull request becomes the provisioning request — and the GitOps controller becomes the provisioning engine.

@explanation

GitOps is the operational model where a Git repository is the single source of truth for infrastructure and application state. A controller — Argo CD or Flux — watches the repository and continuously reconciles what is running in the cluster against what the repository declares should be running.

In a self-service context, GitOps flips the provisioning model: instead of a developer running a command to create resources, the developer submits a pull request to a declarative repository. The act of merging the PR is the provisioning request.

**Argo CD** watches a Git repository for Kubernetes manifests (raw YAML, Helm charts, or Kustomize overlays) and applies them to a cluster when the desired state changes. Drift — a resource manually changed in the cluster — is detected and can be auto-remediated.

**Flux** operates on a similar reconciliation loop but has a stronger emphasis on GitOps for image updates and multi-tenancy patterns. Flux's `HelmRelease` and `Kustomization` CRDs let different teams own different subtrees of the state repository.

What a GitOps-based provisioning flow looks like in practice:

```yaml
# A developer submits this file as a PR to the platform-config repo.
# Merging it causes Argo CD to create the namespace, resource quota,
# and network policy in the staging cluster.
apiVersion: v1
kind: Namespace
metadata:
  name: payments-staging
  labels:
    team: payments
    env: staging
```

The benefits over imperative provisioning:

- Every provisioning action is a Git commit — complete audit trail.
- Pull requests enable review and approval before resources are created.
- Accidental deletion is detected and reversed by the reconciliation loop.
- No one needs cluster credentials to provision; they need write access to the repository.

The limitation is that GitOps is natively Kubernetes-centric. Provisioning a cloud database or a DNS record requires extending the model with operators (like Crossplane or External DNS) that translate Kubernetes objects into cloud API calls.

> [!tip] Separate your GitOps repository from your application source repositories. A single "platform config" repo with a directory per team and per environment gives the platform team a clear ownership boundary and makes access control straightforward.

@feynman

GitOps provisioning is like managing a shared office space through a building management system — instead of calling the facilities team, you update the shared floor plan document, and the building automatically reconfigures itself to match.

@card
id: plf-ch04-c005
order: 5
title: Crossplane — Kubernetes as a Cloud Control Plane
teaser: Crossplane extends Kubernetes with custom resource definitions for cloud resources, letting developers provision an S3 bucket or an RDS instance the same way they create a Pod — with a YAML file and kubectl.

@explanation

Crossplane is an open-source project that turns a Kubernetes cluster into a universal cloud provisioning control plane. It installs providers (AWS, GCP, Azure, and others) that register new CRDs in the cluster. Once installed, a developer can create a cloud resource by applying a Kubernetes manifest — no Terraform, no cloud console, no ticket.

The architecture has three layers:

**Providers** — Crossplane providers install the CRDs and the controllers that translate them into cloud API calls. The AWS provider, for example, registers `RDSInstance`, `S3Bucket`, `VPC`, and hundreds of other resource types.

**Composite Resources (XRs)** — Platform teams define their own higher-level abstractions using `CompositeResourceDefinition` (XRD) and `Composition`. A `MySQLDatabase` XR might provision an RDS subnet group, an RDS parameter group, an RDS instance, a security group, and a Secrets Manager secret — all from a single user-facing object.

**Claims** — Namespace-scoped objects that developers create to request a composite resource. The claim is the self-service interface; the composition is the implementation.

```yaml
# A developer applies this in their team namespace.
# Crossplane creates the full RDS stack underneath.
apiVersion: platform.my-org.io/v1alpha1
kind: MySQLDatabase
metadata:
  name: payments-db
  namespace: payments
spec:
  parameters:
    storageGB: 100
    instanceClass: db.t3.medium
    region: us-east-1
```

The appeal for platform teams: the same Kubernetes RBAC, GitOps, and audit infrastructure that governs application workloads now governs cloud resource provisioning. Developers interact with one system instead of two.

The operational overhead is real: Crossplane requires a stable Kubernetes cluster to run on, provider CRDs must be kept in sync with the cloud provider's API, and debugging a failed composition requires understanding both Kubernetes events and cloud provider error messages.

@feynman

Crossplane is like installing a universal remote control for every cloud service — you point it at AWS, GCP, or Azure and press the same buttons regardless of whose infrastructure is underneath.

@card
id: plf-ch04-c006
order: 6
title: Preview Environments
teaser: Per-PR preview environments give every pull request its own ephemeral deployment — the cost is real, but the feedback loop it closes (test against real infra before merging) is often worth it.

@explanation

A preview environment is an ephemeral deployment of a service or application created automatically for each pull request and torn down when the PR is closed. It gives reviewers a live URL to test against, not a screenshot or a staging environment shared with three other open PRs.

The implementation pattern relies on GitOps tooling. When a PR is opened, a CI pipeline renders a namespace-scoped Helm chart or Kustomize overlay with a unique name (often derived from the PR number) and applies it to a preview cluster. When the PR closes, the namespace is deleted.

A typical preview environment includes:

- The application under review, at the PR's commit SHA
- A database seeded with fixture data (not production data)
- Mocked or stubbed external dependencies, or a shared test instance
- Automatic DNS entry: `pr-1234.preview.my-org.io`
- TLS certificate via cert-manager

The cost-value calculation is the honest part. Preview environments are not free:

- Each environment consumes cluster compute while the PR is open.
- Database provisioning for each PR adds provisioning latency and storage cost.
- If PRs are long-lived or the team is large, dozens of environments run simultaneously.

Mitigation strategies: automatic sleep after N hours of inactivity, shared database instances with per-PR schemas rather than per-PR databases, and limits on how many preview environments a team can hold open at once.

The break-even point depends on how often bugs are caught in preview that would have reached staging or production. Teams with complex front-end/backend integration, multi-service interactions, or QA review steps typically find the cost worthwhile. Teams with strong unit test coverage and simple deployment topologies may find the overhead disproportionate.

> [!info] The highest-value use case for preview environments is teams with non-engineer stakeholders (product managers, designers, QA) who need to review changes against a running system, not just a code diff.

@feynman

A preview environment is like building a temporary model home for each proposed floor plan change — buyers can walk through it and react to the actual space before the renovation crew touches the real house.

@card
id: plf-ch04-c007
order: 7
title: Database Provisioning — The Hard Case
teaser: Provisioning stateless compute is solved; provisioning databases in a self-service model is where the hard problems live — persistent state, backup ownership, schema migrations, and upgrade paths do not disappear behind an abstraction.

@explanation

Databases are the most difficult resource category in self-service provisioning because they carry state that outlives the provisioning event. A misconfigured compute pod can be deleted and recreated. A misconfigured database with two years of production data cannot.

The two primary approaches each have genuine drawbacks:

**Managed cloud services (RDS, Cloud SQL, Cloud Spanner):** The cloud provider handles backups, patching, minor version upgrades, and multi-AZ replication. The platform team provisions these via Terraform modules, Crossplane compositions, or an internal API. The developer gets a connection string. The tradeoffs: cost is higher than self-managed, instance-level customization is limited, and developers must understand managed service concepts (parameter groups, maintenance windows, snapshot retention) to use them safely.

**Operator-deployed databases (CloudNativePG, Percona Operator, CockroachDB Operator):** A Kubernetes operator manages a database cluster running in the same cluster as the application. Cost is lower; customization is higher. The tradeoffs: the platform team owns patching, failover testing, and backup validation — work the managed service was handling before. In a self-service model, this complexity is often underestimated until the first production incident.

The problems that neither approach fully solves:

- **Schema migration ownership.** Who runs `alembic upgrade head` — the application CI pipeline or the platform? If the platform, how does it know the migration is safe?
- **Per-PR databases.** Spinning up a real RDS instance per pull request is too slow and too expensive. Teams typically use a shared staging database with per-PR schemas, which introduces isolation and cleanup complexity.
- **Credential rotation.** A self-service flow that creates a database must also provision secrets and arrange for automatic rotation before the credential ages out.

> [!warning] Never let self-service provisioning create a database without also provisioning automated backups, a retention policy, and a path to inject the connection string as a secret. The database without the safety net is worse than no database at all.

@feynman

Self-service database provisioning is like letting tenants install plumbing in their own apartments — you can write clear instructions and provide approved fixtures, but you cannot fully abstract away the fact that a leak in one apartment affects everyone below.

@card
id: plf-ch04-c008
order: 8
title: Secrets Injection During Provisioning
teaser: A self-service flow that provisions a resource but leaves the developer to manually wire up credentials has not eliminated the toil — it has moved it one step downstream.

@explanation

When a platform provisions a database, a message queue, or a cloud storage bucket, the provisioned resource comes with a credential: a connection string, an API key, an IAM role ARN, or an access token. The self-service experience is only complete if that credential is automatically bound to the service that requested the resource, scoped correctly, and rotated without developer intervention.

The standard pattern uses HashiCorp Vault (or a cloud-native equivalent like AWS Secrets Manager) as the secrets backend:

1. During provisioning, the platform writes the generated credential to Vault at a deterministic path (`secret/payments/production/db-password`).
2. Vault policies grant the application's service account read access to that path only — least-privilege by construction.
3. The application retrieves the secret at startup using Vault Agent, the Secrets Store CSI Driver, or the cloud provider's native secrets injection mechanism.

```yaml
# Kubernetes pod annotation pattern for Vault Agent injection
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/agent-inject-secret-db-password: "secret/payments/production/db-password"
  vault.hashicorp.com/role: "payments-production"
```

**Per-environment scoping** is critical. The provisioning flow creates separate secrets for dev, staging, and production — never sharing a credential across environments. The path structure enforces this: `secret/<service>/<environment>/<credential-name>`.

**Automatic rotation** closes the lifecycle. Vault's database secrets engine can generate short-lived, rotated database credentials on demand, eliminating the risk of a long-lived credential leaking. The application never sees a static password; it gets a 1-hour credential that Vault renews.

The integration cost is not zero. Vault requires a stable cluster, a well-understood PKI hierarchy, and audit log retention. The cloud-native alternatives (AWS Secrets Manager with automatic rotation, GCP Secret Manager) reduce operational overhead at the cost of cloud-vendor lock-in.

@feynman

Automatic secrets injection during provisioning is like a new employee automatically receiving a badge that opens exactly the right doors on their first day — instead of filing three separate access requests after they've been hired.

@card
id: plf-ch04-c009
order: 9
title: DNS, Certificates, and Ingress Automation
teaser: A service is not running until it has a URL that resolves correctly over HTTPS — automating DNS and certificate provisioning turns what was a two-hour manual process into a zero-touch side effect of deployment.

@explanation

The last mile of self-service provisioning is network accessibility. A correctly running container with a valid database connection is still not usable until it has a DNS name, a TLS certificate, and an ingress route.

**cert-manager** is the de facto standard for automated TLS certificate provisioning in Kubernetes. It integrates with Let's Encrypt (and other ACME-compatible CAs) to issue and renew certificates automatically. When an `Ingress` resource is annotated with the right issuer reference, cert-manager creates a `Certificate` object, completes the ACME challenge, and stores the resulting TLS secret in the cluster — without human involvement.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: payments-api
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - payments.my-org.io
      secretName: payments-tls
  rules:
    - host: payments.my-org.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: payments-api
                port:
                  number: 8080
```

**Wildcard certificate provisioning** reduces the per-service overhead further. A single `*.staging.my-org.io` certificate, issued once via DNS-01 challenge, covers every preview environment without requiring per-PR certificate issuance.

**External DNS** automates the DNS half. When an `Ingress` or `Service` resource is created in Kubernetes, External DNS watches for the annotation `external-dns.alpha.kubernetes.io/hostname` and creates the corresponding record in Route 53, Cloud DNS, or another configured provider.

The combination — ingress controller + cert-manager + External DNS — means a developer can create an `Ingress` resource and within two minutes have a publicly resolvable HTTPS endpoint, with no involvement from a network or security team.

> [!tip] Use DNS-01 ACME challenges rather than HTTP-01 for wildcard certificates and for clusters that are not publicly reachable. DNS-01 requires write access to your DNS zone but works for any cluster topology.

@feynman

Automated DNS and certificate provisioning is like a new storefront that automatically gets listed in the city directory and receives a verified security seal the moment it opens — the owner never has to file the paperwork separately.

@card
id: plf-ch04-c010
order: 10
title: Resource Quotas and FinOps
teaser: Self-service provisioning without guardrails is self-service bill generation — resource quotas and cost visibility are what prevent a convenient developer tool from becoming a finance department emergency.

@explanation

Self-service provisioning democratizes infrastructure creation. Without constraints, it also democratizes unchecked cost growth. A developer who can spin up a production-grade RDS cluster in two minutes can accidentally leave it running through a weekend. Multiply by a hundred developers and the bill grows before anyone notices.

**Kubernetes resource quotas** enforce limits at the namespace level — the natural boundary for a team or service:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: payments-team-quota
  namespace: payments
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    persistentvolumeclaims: "10"
    count/services.loadbalancers: "2"
```

Beyond Kubernetes quotas, platform teams need cloud-level enforcement:

- **AWS Service Quotas / IAM permission boundaries** — restrict which instance types or resource classes can be provisioned through platform modules. A developer can request an `api-service` module, but the module's allowed instance types are set by the platform, not by the developer.
- **Tagging enforcement** — every provisioned resource carries `team`, `environment`, `service`, and `cost-center` tags. Tools like AWS Config rules or Terraform Sentinel policies reject resources without required tags.
- **Budget alerts** — per-team AWS budgets or GCP budget alerts notify teams and platform engineers when spending crosses thresholds, before the bill arrives.

The FinOps dimension of platform engineering is not just about preventing overruns. It is about giving teams visibility into what their services actually cost, so they can make informed architectural decisions. A team that discovers their preview environments cost $2,000/month often self-corrects without policy intervention.

@feynman

Resource quotas on a self-service platform are like the spending limits on a corporate card — employees can buy what they need without asking permission for every purchase, but the policy prevents a single person from draining the budget before anyone notices.

@card
id: plf-ch04-c011
order: 11
title: Approval Flows for Sensitive Resources
teaser: Not every provisioning request should be instant — the self-service model works best when 80% of requests complete without human involvement, and the remaining 20% follow a lightweight approval flow rather than falling back to an untracked ticket.

@explanation

Full self-service is the goal for standard resources: a new service namespace, a staging database, a message queue, a set of preview environments. But some resources carry enough blast radius or compliance weight that instant provisioning is the wrong default.

Resources that typically warrant approval:

- Production databases above a certain size threshold
- Cross-account IAM roles or resource-based policies
- Public-facing load balancers in a PCI or HIPAA scope
- Anything that creates a permanent, difficult-to-reverse artifact (a new AWS account, a DNS zone delegation)
- Resources whose monthly cost exceeds a configured threshold

The approval flow must live inside the platform, not fall back to email or an untracked JIRA ticket. Common implementations:

**GitHub Pull Request as approval gate.** A self-service request that requires approval creates a branch and opens a PR to the platform configuration repository. CODEOWNERS rules require a platform team member or a designated approver to review the PR before it is merged. Merging triggers GitOps provisioning as normal.

**Backstage workflow with approval step.** A Backstage Software Template can include a wait-for-approval action that pauses the scaffolding pipeline, notifies the approver via a webhook or Slack message, and resumes when the approval is granted in the portal.

The key design principle is that approved and unapproved requests follow the same provisioning path — GitOps, IaC modules, the same audit trail. Approval adds a human gate before provisioning begins, not a parallel manual process.

The failure mode is over-applying approval gates. If 60% of requests require approval, the platform has not eliminated the ticket queue — it has built a better-looking version of it. Approval gates should be reserved for genuine risk, and the threshold should be reviewed as the team's confidence in the platform grows.

> [!info] Track the percentage of provisioning requests that require approval and the median approval latency. Both numbers should trend downward as the platform matures — the first through better defaults, the second through faster approval culture.

@feynman

Approval flows in a self-service platform are like an ATM with a daily withdrawal limit — most transactions complete instantly without anyone's intervention, but the unusual ones trigger a verification step that exists for good reasons.

@card
id: plf-ch04-c012
order: 12
title: The Golden Path Service Blueprint
teaser: The golden path is not a constraint — it is an opinionated, fully integrated service template that makes the right choice the easy choice, and documents clearly what it includes and how to diverge from it intentionally.

@explanation

The "golden path" is a term popularized by Spotify's engineering culture and formalized in the Backstage model. It refers to a complete, opinionated blueprint for a new service that integrates every layer of the platform: scaffolding, IaC, secrets, observability, CI/CD, and documentation.

A mature golden path for a backend API service typically includes:

- **Repository scaffold** — generated from a Backstage Software Template or cookiecutter; includes language-specific project structure, linting, and formatting configuration.
- **CI pipeline** — GitHub Actions or equivalent; runs tests, builds a container image, pushes to the internal registry, and signs the image with cosign.
- **Container manifest** — Kubernetes Deployment with resource requests/limits, liveness/readiness probes, and a pod disruption budget pre-configured.
- **IaC module invocation** — Terraform module call that provisions a database (if needed), a message queue (if needed), and the IAM role for the service's workload identity.
- **Secrets binding** — Vault policy and Kubernetes service account created automatically; the service reads credentials from a mounted secret store volume.
- **Ingress and TLS** — Ingress resource with cert-manager annotation and External DNS hostname label.
- **Observability** — Prometheus `ServiceMonitor` resource pre-wired; structured logging configuration pointing at the central log aggregator; default alert rules for error rate and p99 latency.
- **Backstage catalog entry** — `catalog-info.yaml` at the repository root, automatically registered on creation.

The golden path is not a mandate. A team building a service with unusual requirements (a GPU workload, a stateful streaming job, a service with specific regulatory isolation needs) should be able to diverge from it with documented intent. The platform team's job is to make divergence explicit and auditable, not to prevent it.

The customization boundary is usually expressed as a set of required inputs (team name, service name, environment) and optional overrides (non-default instance sizes, additional IAM permissions, custom domain). Everything else defaults to the platform's current best practice.

> [!tip] Treat the golden path's changelog as a first-class artifact. When the platform team updates the standard (new observability stack, new TLS provider, new secrets injection pattern), teams on the old path need a migration guide, not just a diff.

@feynman

The golden path is like a well-designed IKEA flat-pack — everything you need for the standard configuration is in the box with clear instructions, you can substitute parts if you have a good reason, but most people build exactly what the diagram shows because it already works.
