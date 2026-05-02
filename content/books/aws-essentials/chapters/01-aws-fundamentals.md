@chapter
id: aws-ch01-aws-fundamentals
order: 1
title: AWS Fundamentals
summary: Before you deploy a single resource, you need to understand how AWS is physically organized, who is responsible for what, how to navigate the control plane, and the financial and architectural model underneath everything.

@card
id: aws-ch01-c001
order: 1
title: AWS Global Infrastructure Hierarchy
teaser: AWS isn't one data center — it's a layered physical hierarchy, and understanding where your workload lives determines its availability, latency, and compliance story

@explanation

AWS organizes its physical infrastructure into four nested layers, each serving a different purpose:

- **Regions** — geographically distinct areas, each containing multiple isolated data centers. As of 2024 there are 33 launched regions (e.g., `us-east-1`, `eu-west-1`). You explicitly choose which region your resources live in. Data does not leave a region unless you configure it to.
- **Availability Zones (AZs)** — physically separate data centers within a region, connected by low-latency private fiber. Each region has 2–6 AZs. Distributing resources across multiple AZs is the primary mechanism for surviving a facility failure.
- **Edge Locations** — CDN and DNS endpoints for services like CloudFront and Route 53. There are 400+ edge locations globally. They cache content close to end users but do not run general compute.
- **Local Zones** — AWS infrastructure placed inside major metro areas (e.g., Los Angeles, Chicago) to deliver single-digit millisecond latency for latency-sensitive applications like game streaming or real-time rendering. They are extensions of a parent region.

The hierarchy matters because failure domains follow it. An AZ failure should not affect another AZ in the same region. A region failure should not affect another region. When you design for high availability, you're deciding which layer your redundancy spans.

> [!info] "Multi-AZ" and "multi-region" are not synonymous. Multi-AZ protects against a data center failure. Multi-region protects against a regional outage or disaster — and comes with significantly more operational complexity.

@feynman

A Region is the city, an Availability Zone is a separate building in that city with its own power grid, and an Edge Location is a local delivery depot — each layer handles a different failure radius

@card
id: aws-ch01-c002
order: 2
title: The Shared Responsibility Model
teaser: AWS secures the cloud infrastructure; you secure everything you put inside it — and the line shifts depending on which service type you're using

@explanation

The Shared Responsibility Model defines who owns what in the security and compliance picture. The core split:

- **AWS is responsible for** the security *of* the cloud: physical facilities, hardware, the hypervisor, the global network backbone, and the managed service control planes. If an AWS data center floods or a hypervisor has a kernel vulnerability, that's AWS's problem.
- **You are responsible for** the security *in* the cloud: your data, your identity and access configuration, your OS patches, your network settings, your application code, and your encryption choices.

The line shifts based on service type:

- **IaaS (e.g., EC2):** You manage the guest OS, runtime, middleware, and application. AWS manages the hardware and hypervisor. You patch your own instances.
- **PaaS (e.g., RDS, Elastic Beanstalk):** AWS manages the OS and database engine patching. You manage data, access controls, and application config.
- **SaaS (e.g., S3 as a fully managed service):** AWS manages almost the entire stack. You manage data classification, bucket policies, and access control.

The most common compliance failure is customers assuming AWS handles more than it does. An EC2 instance with an unpatched OS is your problem, not AWS's — regardless of how well AWS protects the hardware underneath it.

> [!warning] "We're on AWS" is not a compliance answer. The shared responsibility model means your organization still owns a substantial portion of your security posture. Which portion depends on exactly which services you use and how.

@feynman

It's like renting office space — the landlord secures the building and maintains the electrical systems, but you're still responsible for locking your office door and securing what's inside

@card
id: aws-ch01-c003
order: 3
title: The AWS Service Map
teaser: AWS has 200+ services, but they cluster into about a dozen categories — knowing the map stops you from missing an obvious tool or reinventing something AWS already manages

@explanation

AWS services group into recognizable categories. You don't need all of them, but you need to know they exist:

- **Compute** — EC2 (virtual machines), Lambda (serverless functions), ECS/EKS (containers), Fargate (serverless containers), Lightsail (simplified VMs)
- **Storage** — S3 (object storage), EBS (block volumes for EC2), EFS (managed NFS), Glacier (archival)
- **Networking** — VPC (private networks), Route 53 (DNS), CloudFront (CDN), ELB/ALB (load balancers), Direct Connect (private circuits)
- **Databases** — RDS (managed relational: Postgres, MySQL, etc.), Aurora (AWS-native relational), DynamoDB (managed NoSQL), ElastiCache (managed Redis/Memcached), Redshift (data warehouse)
- **Security & Identity** — IAM (access control), KMS (key management), Secrets Manager, WAF, Shield (DDoS), GuardDuty (threat detection)
- **Developer Tools** — CodeBuild, CodePipeline, CodeDeploy, Cloud9, X-Ray (tracing)
- **ML/AI** — SageMaker (ML platform), Bedrock (foundation models), Rekognition, Transcribe, Polly
- **Management & Monitoring** — CloudWatch (metrics/logs/alarms), CloudTrail (API audit log), Config (resource inventory/compliance), Systems Manager

The mental model that helps: for any workload, identify which category it falls into, then evaluate the 1–3 AWS services in that category rather than scanning all 200+.

> [!tip] CloudTrail and CloudWatch solve different problems. CloudTrail records who called which AWS API and when (audit log). CloudWatch monitors resource metrics and application logs (operational telemetry). You almost always need both.

@feynman

Same as knowing the stdlib before reaching for a package — you won't use every module, but knowing the shape of what exists stops you from writing something AWS already ships

@card
id: aws-ch01-c004
order: 4
title: The IAM Root Account and Why You Lock It Away
teaser: The root account has unrestricted access to everything in your AWS account, including the ability to delete all IAM policies, close the account, and override SCPs — it's the one credential you never use day-to-day

@explanation

Every AWS account has a root user tied to the email address used to create it. Root has capabilities that no other identity in the account can have, including:

- Closing the AWS account
- Changing the account's support plan
- Restoring IAM permissions after an accidental lockout
- Accessing billing information regardless of IAM policies
- Removing MFA from the account
- Managing certain S3 bucket policies after the bucket was locked

The problem is that if root credentials are compromised, no IAM policy, SCP, or permission boundary can stop the attacker. Root bypasses all of them.

The correct pattern:

1. Create the root user with a strong, unique password.
2. Enable MFA on the root user immediately — use a hardware key (YubiKey) or a TOTP app, not SMS.
3. Create an IAM user or SSO identity with `AdministratorAccess` for day-to-day admin work.
4. Store root credentials in a password manager or vault. Access root only for the handful of tasks that require it.
5. Set a billing alert or CloudWatch alarm for any root login.

This is the "break-glass" pattern: the root credential is sealed except for genuine emergencies, and any use of it should generate an alert.

> [!warning] AWS recommends not creating access keys for the root user at all. If root access keys exist on your account, delete them. They're permanent elevated credentials with no scope limit and no easy audit trail.

@feynman

The root account is like the physical master key to a data center — you lock it in a safe, document where the safe is, and investigate any time it's touched

@card
id: aws-ch01-c005
order: 5
title: AWS CLI Setup and Multi-Account Profiles
teaser: The AWS CLI is the lowest-common-denominator control plane — and using named profiles from day one means you never accidentally run a destructive command in the wrong account

@explanation

The AWS CLI lets you interact with every AWS service from the terminal. Installation is straightforward (`brew install awscli` on macOS, or via the official installer on other platforms). The critical setup step is `aws configure`:

```bash
aws configure
# AWS Access Key ID: AKIA...
# AWS Secret Access Key: ...
# Default region name: us-east-1
# Default output format: json
```

This writes to `~/.aws/credentials` and `~/.aws/config`. The problem with using only the default profile is that every AWS command you run targets the same account unless you explicitly override it.

Named profiles solve this:

```bash
aws configure --profile dev
aws configure --profile prod
```

Then scope every command to a profile:

```bash
aws s3 ls --profile dev
aws ec2 describe-instances --profile prod
```

Or set a session-level default:

```bash
export AWS_PROFILE=dev
```

For organizations using AWS SSO (IAM Identity Center), use `aws configure sso --profile dev` instead of static keys. SSO-based credentials are short-lived (typically 8 hours) and don't require storing long-term access keys on disk.

> [!tip] Set your shell prompt to display `$AWS_PROFILE` when it's set. A prompt that reads `(prod) $` before every command is a low-cost guard against running a dev-targeted script against production.

@feynman

Named profiles are like separate kubeconfig contexts — switching explicitly between them means a fat-finger in one terminal window doesn't blow up a different environment

@card
id: aws-ch01-c006
order: 6
title: Console vs CLI vs SDKs vs IaC — Picking the Right Tool
teaser: Each AWS control-plane tool optimizes for a different use case — mixing them without intention produces infrastructure that's half-managed, half-manual, and impossible to reproduce

@explanation

AWS exposes the same underlying APIs through four interfaces. Knowing which to reach for:

**AWS Management Console** — a web UI. Best for: exploring a new service, reading metrics and logs, one-time operations that don't need to be repeatable, and debugging. Worst for: anything you'll need to do more than once. The Console produces no record of what you did and no artifact you can review.

**AWS CLI** — a terminal tool. Best for: scripting, automation, CI/CD pipelines, quick one-liners during incidents, and anything you want logged in shell history. Worse than IaC for: managing the full lifecycle of complex infrastructure, because shell scripts don't track state.

**AWS SDKs** (Python's `boto3`, JavaScript's `@aws-sdk`, Go, Java, etc.) — programmatic API access from application code. Best for: application-level AWS interactions (e.g., uploading to S3, reading from DynamoDB, publishing to SQS). Not the right tool for: provisioning infrastructure — that's IaC.

**CloudFormation / CDK / Terraform** — Infrastructure as Code. Best for: provisioning and managing infrastructure in a reproducible, reviewable, version-controlled way. CloudFormation is AWS-native; CDK compiles higher-level constructs to CloudFormation; Terraform is provider-agnostic. IaC is the right long-term home for any infrastructure that needs to be recreated, reviewed, or audited.

The failure mode is using the Console to set up infrastructure and the SDK to manage it, leaving no IaC artifact. The next time you need to recreate the environment, you start from memory.

> [!info] The Console is an excellent learning tool and a poor production tool. Start in the Console to understand a service, then codify what you built in IaC before treating it as production.

@feynman

The Console is a REPL — great for exploration, but you wouldn't ship production code by running ad-hoc commands in a REPL with no source file

@card
id: aws-ch01-c007
order: 7
title: AWS Accounts and AWS Organizations
teaser: Starting with a single AWS account is normal; staying with one is a trap — Organizations gives you the multi-account structure that makes security, billing, and policy enforcement tractable at scale

@explanation

A single AWS account is a flat blast radius. If a credential is compromised, an IAM policy is misconfigured, or a runaway script deletes resources, everything in the account is at risk. There's also no natural boundary between production and development environments.

AWS Organizations solves this by providing a hierarchy of accounts managed from a single management account:

- **Management account** — the root of the org. Owns the master billing relationship and can apply SCPs. Should contain almost no workload resources.
- **Organizational Units (OUs)** — logical groupings of accounts (e.g., `Production`, `Development`, `Security`, `Sandbox`). Policies applied to an OU inherit down to member accounts.
- **Member accounts** — individual AWS accounts enrolled in the org. Each is a separate blast radius.

Common account patterns:
- A dedicated `Log Archive` account that receives CloudTrail logs from all accounts (with no write access from other accounts)
- A dedicated `Security` account for GuardDuty, Config aggregation, and security tooling
- Separate `Dev`, `Staging`, and `Prod` accounts for each product line

AWS Control Tower can bootstrap this structure with opinionated defaults. Landing zones from Control Tower give you logging, guardrails, and account vending from a template.

> [!tip] Even if you're a solo developer, create at least two accounts: one for experimentation/learning and one for anything production. The cost is zero — AWS accounts are free to create, you pay only for resources.

@feynman

A single AWS account for everything is like running your entire company on one Linux user with root access — it works until it doesn't, and then it really doesn't

@card
id: aws-ch01-c008
order: 8
title: Service Control Policies in AWS Organizations
teaser: SCPs are preventive guardrails that apply before IAM — they define the maximum permissions any identity in an account can have, regardless of what IAM grants

@explanation

SCPs (Service Control Policies) are attached to OUs or individual accounts in AWS Organizations. They do not grant permissions — they restrict the maximum permissions available to any IAM principal (users, roles, even the account's own administrators) within the scoped account.

The key behavior: an action requires both an SCP that allows it AND an IAM policy that allows it. If the SCP denies it, IAM can't override it. If IAM grants it but the SCP doesn't allow it, the action is denied.

Common SCP use cases:

- Prevent any account in the `Production` OU from disabling CloudTrail
- Restrict all accounts to specific regions (e.g., deny any API call outside `us-east-1` and `eu-west-1` for data residency compliance)
- Prevent IAM users from creating IAM admin roles without going through a central process
- Block certain high-risk actions (e.g., `ec2:DeleteVpc`, `s3:DeleteBucket`) in production accounts

Example SCP to deny CloudTrail deletion:

```json
{
  "Effect": "Deny",
  "Action": [
    "cloudtrail:StopLogging",
    "cloudtrail:DeleteTrail"
  ],
  "Resource": "*"
}
```

SCPs do not apply to the management account — which is one reason the management account should have no workloads.

> [!warning] SCPs apply to every IAM identity in the account, including the account's own administrators. A poorly written SCP that denies `iam:*` can lock all human access out of an account. Test SCPs in a non-critical account first.

@feynman

An SCP is like a VLAN or firewall rule that sits outside the application — no matter what the app tries to do, it can't route traffic the network layer prohibits

@card
id: aws-ch01-c009
order: 9
title: AWS Pricing Fundamentals
teaser: AWS pricing isn't complicated once you internalize the four purchase models and understand that the free tier is a learning tool, not a cost management strategy

@explanation

AWS charges for resources in four main purchase models:

- **On-Demand** — pay per unit of time or usage, no commitment. The default and the most expensive per-unit rate. Correct for: unpredictable workloads, development environments, anything you'll run for less than a month.
- **Reserved Instances / Reserved Capacity** — commit to 1 or 3 years in exchange for up to 72% discount over on-demand. Correct for: stable, predictable baseline workloads (e.g., a production RDS instance that runs 24/7). Wrong for: anything that might be replaced, resized, or shut down before the term ends.
- **Savings Plans** — a more flexible commitment model than Reserved Instances. Commit to a consistent spend level (e.g., $10/hour) in exchange for discounts. Compute Savings Plans apply across EC2, Fargate, and Lambda automatically.
- **Spot Instances** — bid on unused EC2 capacity at up to 90% discount. The catch: AWS can reclaim the instance with 2 minutes notice. Correct for: fault-tolerant batch jobs, CI/CD workers, stateless horizontally scaled services. Wrong for: stateful databases, anything that can't handle abrupt termination.

Free tier traps to know:
- The 12-month free tier expires silently; a t2.micro you spun up during the trial period starts billing at month 13.
- Some services are "always free" (Lambda: 1M requests/month). Most are not.
- Data transfer costs are separate and often not covered by the free tier.

> [!tip] Turn on AWS Cost Explorer and set a billing alert at $5 the day you create an account. The alert costs nothing and will catch runaway resources before they become a surprise bill.

@feynman

On-demand pricing is like renting a car by the hour — flexible but expensive; reserved pricing is the annual lease — cheaper per day, but you're paying whether you drive it or not

@card
id: aws-ch01-c010
order: 10
title: The AWS Well-Architected Framework
teaser: The Well-Architected Framework is six lenses for evaluating any cloud workload — use it as a checklist before you ship and a diagnostic when something goes wrong

@explanation

AWS published the Well-Architected Framework as a structured way to evaluate whether a cloud workload is built correctly. It has six pillars, each representing a dimension of quality:

- **Operational Excellence** — can you run and improve the workload over time? Covers deployment automation, observability, runbook quality, and post-incident improvement. Key question: if you're paged at 3am, can your team diagnose and resolve the issue without the original author?
- **Security** — are you protecting data and systems at every layer? Covers identity, infrastructure protection, data protection, detective controls, and incident response. Key question: if one credential is compromised, what's the blast radius?
- **Reliability** — does the workload recover from failures automatically? Covers fault isolation, redundancy, backups, and change management. Key question: if an AZ fails, what happens to the user experience?
- **Performance Efficiency** — are you using the right resources at the right scale? Covers resource selection, scaling strategies, and reviewing resource choices as AWS adds options. Key question: are you running a c5.4xlarge because it's right, or because it's what you provisioned two years ago?
- **Cost Optimization** — are you spending only what you need? Covers resource right-sizing, purchase model selection, and identifying waste. Key question: what's running that you forgot about?
- **Sustainability** — are you minimizing environmental impact? Covers maximizing resource utilization, using managed services that scale to zero, and right-sizing to reduce idle capacity.

AWS provides a free Well-Architected Tool in the console that walks you through questions for each pillar and produces a findings report.

> [!info] You don't need to score perfectly on all six pillars at launch. The framework is most valuable as a deliberate tradeoff tracker: "we're accepting this reliability risk now, and here's when we'll revisit it."

@feynman

The six pillars are like the six axes on a radar chart for code quality — you're rarely maxed out on all of them simultaneously, but naming which ones you've deprioritized is the difference between a known tradeoff and a hidden risk
