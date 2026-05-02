@chapter
id: aws-ch10-iam-and-security
order: 10
title: IAM and Security
summary: IAM is the authorization backbone of AWS — every API call is an IAM decision — and understanding how policies, roles, and the broader security toolchain fit together is what separates "it works" from "it's defensible."

@card
id: aws-ch10-c001
order: 1
title: IAM Fundamentals and Policy Evaluation
teaser: Every AWS API call is authorized by IAM — and by default, if a permission isn't explicitly granted, the answer is always no.

@explanation

IAM has four building blocks: **users** (human identities with long-term credentials), **groups** (collections of users for bulk permission assignment), **roles** (identities assumed temporarily — no long-term credentials), and **policies** (JSON documents that define what is allowed or denied).

A policy document has a fixed structure:

- **Version** — always `"2012-10-17"` (the only version that supports all modern features)
- **Statement** — an array of one or more permission blocks
- **Effect** — `"Allow"` or `"Deny"`
- **Action** — the specific AWS API operations (e.g., `"s3:GetObject"`, `"ec2:*"`)
- **Resource** — the ARN(s) the action applies to; use `"*"` for any resource
- **Condition** — optional key-value tests that further restrict when the statement applies

The evaluation order has one hard rule: **an explicit Deny always wins**, regardless of how many Allows exist elsewhere. If no statement explicitly allows an action, the implicit default is Deny. This means the permission evaluation isn't "does any policy allow this?" — it's "does any policy deny this first, and if not, does any policy allow it?"

A practical example: if a role has an S3 full-access policy attached but a Service Control Policy denies `s3:DeleteObject` at the organization level, the delete call fails — the SCP denial wins every time.

> [!info] The implicit deny default is your safety net. New principals start with zero permissions, which means a misconfigured role that's too permissive is a configuration error you added — not a default you failed to remove.

@feynman

IAM evaluation is like a firewall ruleset — the first explicit match wins, deny rules trump allow rules, and if nothing matches, the packet is dropped.

@card
id: aws-ch10-c002
order: 2
title: IAM Roles and AssumeRole
teaser: Roles are how AWS services, applications, and cross-account workloads get permissions without storing long-term credentials anywhere.

@explanation

Unlike users, roles have no password and no access keys that live indefinitely. Instead, a principal (a user, service, or application) calls the **STS AssumeRole API**, receives temporary security credentials (access key ID, secret access key, session token) that expire — typically in 1 hour but configurable up to 12 hours — and uses those credentials for the duration of the session.

The workflow:
1. You create a role with a **trust policy** specifying who is allowed to assume it (the principal — e.g., `"Service": "ec2.amazonaws.com"` or another AWS account ID).
2. The requester calls `sts:AssumeRole` with the role ARN.
3. STS validates the trust policy and issues temporary credentials.
4. The requester uses those credentials until they expire, then refreshes.

**EC2 instance profiles** are the mechanism that wires a role to an EC2 instance. You attach a role to an instance profile, attach the instance profile to the instance, and the EC2 metadata service at `169.254.169.254/latest/meta-data/iam/security-credentials/` vends auto-rotating temporary credentials to code running on the instance. The AWS SDK handles rotation transparently — your application never holds static credentials.

**Cross-account role assumption** works the same way: Account A trusts Account B in the role's trust policy; a principal in Account B calls AssumeRole on the Account A role ARN and gets scoped access across the account boundary.

> [!warning] If your application uses hardcoded IAM user credentials instead of an instance profile or role, that's a security debt item. Static credentials don't rotate, can be leaked in source control, and can't be revoked without disrupting the service.

@feynman

An IAM role is a valet key — it gives temporary, scoped access to the car without handing over the master key that opens everything forever.

@card
id: aws-ch10-c003
order: 3
title: IAM Policy Types and the Evaluation Logic
teaser: AWS has five distinct policy types, and knowing which layer each operates at is what determines whether a permission actually works end-to-end.

@explanation

The five policy types and where they attach:

- **Identity-based policies** — attached to users, groups, or roles. Define what that principal can do. The most common type.
- **Resource-based policies** — attached directly to a resource (S3 bucket policy, Lambda resource policy, KMS key policy, SQS queue policy). Define who can access that resource and from where. Unlike identity-based policies, resource-based policies can grant access to principals in other AWS accounts without requiring AssumeRole.
- **Permission boundaries** — an IAM managed policy attached to a user or role that sets the maximum permissions that identity can ever have. Even if the identity's attached policies allow more, the boundary caps it. Used to safely delegate IAM permission management without letting a delegated admin grant themselves god-mode access.
- **Session policies** — passed inline during AssumeRole or AssumeRoleWithWebIdentity to further restrict what the resulting session can do. The session gets the intersection of the role's policies and the session policy.
- **Service Control Policies (SCPs)** — applied at the AWS Organizations level (on OUs or accounts). Define the maximum permissions available to any principal in that account. SCPs never grant permissions directly — they only restrict. The final effective permissions are the intersection of what the SCP allows and what identity/resource policies grant.

The effective permission is the intersection of all applicable policy types. To allow an action end-to-end: the SCP must not deny it, the identity-based policies (and permission boundary, if set) must allow it, and if there's a resource-based policy with a condition, that must also be satisfied.

> [!tip] Permission boundaries are the right tool when you need to delegate IAM administration to a team or developer without giving them the ability to escalate their own privileges. Set the boundary first, then let them manage policies within it.

@feynman

The five policy types are like nested security doors — every door has to open, and a lock on any one of them stops you regardless of how many other doors are propped open.

@card
id: aws-ch10-c004
order: 4
title: Least Privilege in Practice
teaser: "Least privilege" sounds obvious in theory, but most AWS accounts drift toward over-permissioned roles over time — because it's faster to add permissions than to audit and remove them.

@explanation

The correct starting point for any new role is zero permissions, then add the specific actions and resources the workload actually needs. In practice, most teams do the inverse — start with a broad managed policy like `AmazonS3FullAccess` and never revisit it.

Tools that help you get to least privilege and stay there:

**IAM Access Analyzer** has a feature called "Generate policy based on CloudTrail activity." Point it at a role and a time range (e.g., 90 days), and it produces a policy that includes only the actions actually called and the specific resource ARNs accessed. This is the fastest path from "working but over-permissioned" to "minimum necessary."

**The `aws:RequestedRegion` condition key** lets you restrict an IAM permission to specific AWS regions. For example, if your workload only runs in `us-east-1` and `eu-west-1`, you can add a Deny statement with `aws:RequestedRegion` not in that list. This prevents a compromised credential from being used to spin up resources in exotic regions.

The distinction between "works" and "minimum necessary" matters operationally: over-permissioned roles are a blast radius problem. If credentials leak or a service is compromised, the scope of what an attacker can do is exactly the scope of the role's permissions. A role that can only read from two specific S3 buckets is a contained incident; a role with `"Action": "s3:*", "Resource": "*"` is not.

> [!info] IAM Access Analyzer's unused access findings are available free for 180 days of CloudTrail history. Schedule a quarterly review in new accounts before permission creep becomes entrenched.

@feynman

Least privilege is like a production database user with SELECT only on the tables the app actually reads — not because you expect malice, but because scope limits damage when something goes wrong.

@card
id: aws-ch10-c005
order: 5
title: AWS Organizations and SCPs
teaser: Service Control Policies are the one IAM mechanism that even an account's root user cannot override — they're guardrails applied from outside the account.

@explanation

AWS Organizations structures accounts into a hierarchy: a **management account** (formerly master account) at the top, **Organizational Units (OUs)** as folders, and **member accounts** as leaves. You apply SCPs to OUs or directly to accounts, and they affect every IAM principal in that scope — including the account root user.

Two SCP strategies:

**Deny-list (default).** AWS ships a default `FullAWSAccess` SCP that allows everything. You then attach additional SCPs that explicitly deny what you want to prohibit (e.g., deny leaving the organization, deny disabling GuardDuty, deny creating resources outside approved regions). This is the most common approach because it's incremental — you start permissive and add restrictions.

**Allow-list.** Remove `FullAWSAccess` and explicitly enumerate the services and actions allowed. Every service not listed is implicitly denied. This is much stricter and harder to maintain, but appropriate for high-security environments like financial services where the default posture should be deny-everything.

Example deny-list SCP that enforces region restriction:
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": ["us-east-1", "eu-west-1"]
    }
  }
}
```

SCPs do not affect the management account itself — only member accounts. This is a reason to keep the management account nearly empty and do all actual work in member accounts.

> [!warning] SCPs affect the root user of member accounts. A compromised root user in a well-SCP'd account cannot disable GuardDuty or exfiltrate to other regions if the SCP blocks it. This is a strong reason to apply SCPs proactively, not reactively.

@feynman

SCPs are the constitution — individual accounts can pass their own laws, but nothing they do can contradict the constitution, and the constitution is edited from outside their jurisdiction.

@card
id: aws-ch10-c006
order: 6
title: Secrets Manager vs Parameter Store
teaser: Both services store secrets — the difference is in rotation, cost, and how much infrastructure you're willing to manage yourself.

@explanation

**AWS Secrets Manager** is purpose-built for credentials that need to rotate. It stores arbitrary JSON secrets, supports automatic rotation via a built-in Lambda function for RDS, Redshift, and DocumentDB (or custom Lambda for anything else), supports cross-account access via resource policies, and versions secrets so a rotation failure doesn't instantly break running applications. Cost: approximately $0.40 per secret per month plus $0.05 per 10,000 API calls.

**Systems Manager Parameter Store** stores strings and SecureStrings (encrypted via a KMS key you specify). The **Standard tier** is free up to 10,000 parameters with up to 4KB each. Advanced tier extends to 8KB and adds parameter policies (like auto-expiration). Parameter Store has no built-in rotation — you write the rotation logic yourself.

When to use each:

- **Secrets Manager:** database credentials, API keys that rotate, credentials shared across multiple accounts, anything where you want managed rotation and are willing to pay $0.40/month per secret.
- **Parameter Store:** application configuration that doesn't rotate (feature flags, environment-specific config), secrets where you want to manage rotation yourself or accept manual rotation, teams with tight cost constraints.

Applications retrieve secrets at runtime via the AWS SDK (`secretsmanager:GetSecretValue` or `ssm:GetParameter`) using the IAM role attached to the service. The pattern for containers is to fetch the secret at startup and cache it for the lifetime of the process, refreshing before the cache TTL if Secrets Manager rotation is active.

> [!tip] Never put a plaintext secret in an environment variable that lands in a CloudFormation template, a container image, or a log. Fetch it from Secrets Manager or Parameter Store at runtime using the instance/task role.

@feynman

Secrets Manager is the managed key-rotation service with a monthly fee; Parameter Store is the free config drawer where you handle rotation yourself.

@card
id: aws-ch10-c007
order: 7
title: AWS KMS and Envelope Encryption
teaser: KMS never gives you your plaintext data key — it encrypts the key for you, so your data is protected even if someone gets the ciphertext.

@explanation

**AWS Key Management Service (KMS)** manages cryptographic keys and performs encryption operations. You never export the key material for customer master keys (CMKs) — KMS performs the encrypt/decrypt operations inside hardware security modules (HSMs), and the key material never leaves.

Two types of CMKs:
- **AWS managed keys** — created and managed by AWS on your behalf for a specific service (e.g., `aws/s3`, `aws/ebs`). You can't change the key policy or rotate them on demand. Free to use; charged only per API call.
- **Customer managed keys (CMKs)** — you create and control these. You write the key policy (who can use it, who can administer it), you can enable automatic annual rotation, and you can schedule deletion (7–30 day waiting period). Cost: $1/month per key plus $0.03 per 10,000 API calls.

**Symmetric vs asymmetric keys:** Symmetric keys (AES-256) are used for encrypt/decrypt within AWS services. Asymmetric keys (RSA or ECC) are used when you need to give external parties a public key to encrypt data that only your private key can decrypt.

**Envelope encryption** is how KMS scales to large data:
1. Your application calls KMS to generate a data key. KMS returns both a plaintext data key and an encrypted copy of that key.
2. Your application encrypts your data using the plaintext data key (in memory), then discards the plaintext key.
3. You store the encrypted data alongside the encrypted data key (e.g., in S3 object metadata).
4. To decrypt, you call KMS to decrypt the data key, then use the plaintext data key to decrypt your data.

KMS never sees your actual data — only the data key. This pattern is what S3, EBS, RDS, and most AWS services use internally when you enable SSE-KMS.

> [!info] The `aws:kms` condition key on S3 bucket policies lets you require that objects are uploaded with SSE-KMS using a specific CMK. Without this, a user could upload objects using SSE-S3 (AWS-managed key) and bypass your key policy controls.

@feynman

Envelope encryption is like locking your documents in a box and putting the key in a separate lockbox — KMS holds the master key that unlocks the lockbox, but it never sees the documents.

@card
id: aws-ch10-c008
order: 8
title: AWS CloudTrail — API Call Logging
teaser: CloudTrail answers "who did what and when" for every AWS API call — and without it, you're investigating incidents with no logs to look at.

@explanation

CloudTrail logs every API call made in your AWS account: who made the call (user/role ARN), from what IP, at what time, to which service and action, with what parameters, and whether it succeeded. This covers calls made from the console, CLI, SDKs, and other AWS services acting on your behalf.

Two event categories:
- **Management events** — control plane operations: creating/deleting resources, modifying IAM policies, changing VPC configuration. Logged by default in the 90-day console Event History. Every account gets this for free, but it's read-only in the console and isn't sent to S3 unless you create a trail.
- **Data events** — data plane operations: S3 object-level reads/writes (`GetObject`, `PutObject`), Lambda function invocations, DynamoDB item-level activity. These are high-volume and disabled by default because enabling them in a busy S3 bucket generates enormous log volume and associated cost.

**Creating a Trail** exports events to an S3 bucket for long-term retention beyond 90 days. You should create a **multi-region trail** (one configuration that captures events in all regions) to prevent blind spots in regions you don't actively use. Enable CloudTrail log file validation so you can cryptographically verify logs weren't tampered with after delivery.

**CloudTrail Insights** watches your management event traffic and alerts on statistically unusual API call rates — for example, a spike in `TerminateInstances` calls that deviates from your baseline. It costs extra but is the fastest way to detect account compromise or runaway automation.

> [!warning] CloudTrail is enabled by default for management events, but the 90-day console history cannot be exported, queried programmatically, or retained beyond 90 days. Create a trail to S3 on day one — the storage cost is trivial compared to investigating an incident without logs.

@feynman

CloudTrail is the security camera footage for your AWS account — the default gives you 90 days of recordings you can watch in the console, but creating a trail is like plugging in an external hard drive so you keep everything.

@card
id: aws-ch10-c009
order: 9
title: GuardDuty and Security Hub
teaser: GuardDuty detects threats automatically using ML across your logs; Security Hub aggregates all your security findings into one place so you're not checking five dashboards.

@explanation

**Amazon GuardDuty** is a continuous threat detection service. You enable it per account/region and it starts consuming VPC Flow Logs, CloudTrail management events, DNS query logs, and (optionally) Kubernetes audit logs and S3 data events — without you having to configure log routing or build detection logic. GuardDuty uses ML models and curated threat intelligence (known malicious IPs, domains, TOR exit nodes) to generate findings with severity ratings.

Example GuardDuty findings you'll actually see:
- `Recon:EC2/PortProbeUnprotectedPort` — an instance is being port-scanned from an unusual source
- `CryptoCurrency:EC2/BitcoinTool.B` — an instance is communicating with Bitcoin mining infrastructure
- `UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.B` — a console login from a Tor exit node
- `Exfiltration:S3/AnomalousBehavior` — an IAM entity is reading an unusual volume of S3 objects

GuardDuty also includes **malware scanning** for EBS volumes attached to EC2 instances when a suspicious finding is triggered.

**AWS Security Hub** is the aggregation layer. It collects findings from GuardDuty, Amazon Inspector (vulnerability scanning), Amazon Macie (sensitive data discovery in S3), AWS Config compliance findings, IAM Access Analyzer, and supported third-party tools. It normalizes them into the AWS Security Finding Format (ASFF), scores them, and maps them to security standards (CIS AWS Foundations, AWS Foundational Security Best Practices, PCI DSS).

The Security Hub + GuardDuty combination is the starting point for any AWS security posture: GuardDuty detects active threats, Security Hub gives you the unified view with compliance scoring.

> [!info] GuardDuty has a 30-day free trial per account per region. The cost scales with the volume of logs processed — for a typical small-to-medium AWS account, expect $50–$200/month once the trial ends. Enable it in the management account and delegate to an audit account in Organizations to aggregate findings across all member accounts.

@feynman

GuardDuty is the motion sensor that alerts on specific suspicious activity; Security Hub is the security operations panel that shows you all the alerts from all the sensors in one place.

@card
id: aws-ch10-c010
order: 10
title: AWS Config — Continuous Configuration Recording
teaser: Config answers "what did this resource look like at 3 PM last Tuesday?" — a different question than CloudTrail, and equally important for compliance and incident investigation.

@explanation

**AWS Config** continuously records the configuration state of your AWS resources — EC2 instances, security groups, S3 buckets, IAM roles, RDS instances, and hundreds of others. Every time a resource's configuration changes, Config captures a new configuration snapshot and stores the history in S3.

The core capability is the **configuration timeline**: you can see every configuration state a resource has ever been in, with timestamps. This answers post-incident questions like "was this security group open to the internet when the breach occurred?" or "what was the IAM policy attached to this role six months ago?" CloudTrail tells you *who made the API call*; Config tells you *what the resource looked like as a result*.

**Config rules** evaluate whether resources comply with your policies:
- **AWS managed rules** — pre-built checks for common compliance scenarios: `restricted-ssh` (no security groups allow port 22 from 0.0.0.0/0), `s3-bucket-public-read-prohibited`, `iam-password-policy`, `encrypted-volumes`. There are over 200 managed rules.
- **Custom rules** — Lambda functions that Config invokes when a resource configuration changes. You write the evaluation logic; Config calls your function with the current configuration and expects a COMPLIANT/NON_COMPLIANT response.

**Remediation actions** let you attach an SSM Automation document to a rule, so when a resource is evaluated as non-compliant, Config can automatically trigger the remediation (e.g., close the overly permissive security group rule). You can configure this as manual (one-click from the console) or automatic.

AWS Config is often required for compliance frameworks: SOC 2, PCI DSS, HIPAA, and ISO 27001 audits typically ask for continuous configuration recording and evidence of config rule enforcement.

> [!tip] Enable Config in every region you use, even regions where you have minimal resources. An attacker who compromises credentials often pivots to low-activity regions precisely because there's less monitoring — Config + GuardDuty in all regions closes that gap.

@feynman

CloudTrail is the call log that tells you who dialed and when; Config is the account history that shows you what the account looked like after every call.
