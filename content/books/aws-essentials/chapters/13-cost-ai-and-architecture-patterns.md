@chapter
id: aws-ch13-cost-ai-and-architecture-patterns
order: 13
title: Cost, AI Services, and Architecture Patterns
summary: Understanding AWS costs, leveraging managed AI services, and applying canonical architecture patterns are the skills that separate systems that work in demos from systems that work in production.

@card
id: aws-ch13-c001
order: 1
title: Cost Explorer and Budgets
teaser: You can't optimize what you can't see — Cost Explorer gives you the visibility, and Budgets makes sure you find out before the bill lands.

@explanation

AWS Cost Explorer is your primary lens into what you're spending and where. You can break down costs by service, account, region, usage type, or any custom tag you've applied to your resources. The right-sizing recommendations feature surfaces EC2 instances running at single-digit CPU utilization for weeks — a common source of invisible waste. Savings Plans recommendations show you where you're spending enough on predictable workloads that committing to one- or three-year terms would reduce your bill by 30–60%.

Cost Explorer is retrospective. AWS Budgets is proactive. You set a budget — say $500/month on your production account — and configure alerts at 80% of actual and 100% of forecasted spend. The forecasted threshold is especially useful: if AWS projects you'll hit $600 based on current trajectory, you get alerted mid-month before you've actually overspent.

Budget Actions take this further. You can configure a budget action that automatically attaches an IAM policy or Service Control Policy when a threshold is crossed — effectively putting a hard ceiling on API calls so a runaway Lambda loop can't rack up an unbounded bill.

Key habits to build:
- Tag every resource from day one — Cost Explorer is only as useful as your tagging discipline.
- Set a billing alert before you deploy anything new, not after.
- Check right-sizing recommendations once a quarter; dev environments are the usual offenders.

> [!warning] The default AWS account has no billing alerts configured. A runaway workload or forgotten NAT Gateway can generate a four-figure bill before you even notice. Set up a $50 budget alert on every new account immediately.

@feynman

Cost Explorer is the log aggregator for your bill — it's only as useful as what you've tagged and labeled, just like logs are only searchable by what you've instrumented.

@card
id: aws-ch13-c002
order: 2
title: Trusted Advisor's Five Pillars
teaser: Trusted Advisor is AWS's built-in code review for your account — it scans your configuration and tells you what's insecure, inefficient, or about to break.

@explanation

Trusted Advisor checks your AWS environment against five pillars:

- **Cost Optimization** — underutilized EC2 instances, idle load balancers, unassociated Elastic IPs, Reserved Instance coverage gaps.
- **Performance** — CloudFront cache hit ratios, overutilized EC2 instances, high-latency Route 53 configurations.
- **Security** — open S3 buckets, overly permissive security groups (port 22/3389 open to 0.0.0.0/0), root account MFA not enabled, IAM keys that haven't been rotated in 90+ days.
- **Fault Tolerance** — RDS instances not in Multi-AZ, EC2 instances in a single Availability Zone, S3 buckets with versioning disabled.
- **Service Limits** — resource counts approaching the default quota ceiling.

The catch: the free tier gives you access to only seven core checks, all in the Security and Service Limits categories. The full suite of ~115 checks requires a Business or Enterprise Support plan ($100/month minimum for Business). If you're running a production workload, the Support plan usually pays for itself in the first underutilized EC2 recommendation it surfaces.

Trusted Advisor exposes a programmatic API, so you can integrate findings into your CI pipeline or a Slack bot. The "underutilized EC2 instances" check returns instances with CPU below 10% over 14 days and network I/O below 5 MB — a useful threshold for automated right-sizing workflows.

> [!tip] Even on the free tier, run the security checks on every new account. Open port 22 to the world and an MFA-less root account are the two findings that cost people the most.

@feynman

Trusted Advisor is like `npm audit` for your AWS account — it doesn't catch everything, and the best checks cost money to unlock, but running it is always better than not running it.

@card
id: aws-ch13-c003
order: 3
title: AWS Pricing Model for Common Services
teaser: The sticker price on any one service is rarely the whole story — data transfer and managed infrastructure overhead are where bills quietly multiply.

@explanation

Here are the numbers you need to know before architecting anything:

**S3** — $0.023/GB per month for Standard storage. The storage itself is cheap. The gotchas are request costs ($0.005 per 1,000 PUT requests, $0.0004 per 1,000 GET requests) and data transfer out.

**EC2** — three pricing tiers with real tradeoffs. On-demand: full price, no commitment, best for unpredictable workloads. Savings Plans / Reserved Instances: 30–60% discount in exchange for a 1- or 3-year commitment, best for stable baseline capacity. Spot: up to 90% discount, but AWS can reclaim the instance with 2 minutes notice — fine for batch processing, not for your web server.

**Lambda** — $0.0000166667 per GB-second of compute plus $0.20 per 1 million requests. A function running 512 MB of memory for 1 second costs about $0.0000083 per invocation. At 10 million invocations per month, that's roughly $83 in compute plus $2 in request fees.

**Data transfer** — inbound to AWS is free. Outbound to the internet is $0.09/GB for the first 10 TB/month. Transfers between AWS services in the same region are typically free or near-free; cross-region transfers are $0.02/GB. This is where high-throughput applications get surprised.

**NAT Gateway** — the sleeper cost. $0.045/hour to run (~$32/month just to have it) plus $0.045/GB of data processed. An EC2 instance pulling down container images through a NAT Gateway at 100 GB/month adds $4.50 in data processing fees on top of the hourly charge.

> [!info] The most common bill shock pattern: a developer stands up a NAT Gateway in a dev VPC, forgets it over a weekend, and pays $30–50 for nothing. Use VPC endpoints for S3 and DynamoDB access inside private subnets — they're free and bypass NAT.

@feynman

AWS pricing is like a mobile phone plan — the base rate looks reasonable, but data overage is where the real cost lives.

@card
id: aws-ch13-c004
order: 4
title: Amazon Bedrock for Foundation Model Inference
teaser: Bedrock lets you call state-of-the-art foundation models via API without managing any model infrastructure — but knowing when to use it versus building your own ML pipeline matters.

@explanation

Amazon Bedrock is AWS's managed service for foundation model inference. You call an API and get back a generated response; AWS handles everything below that — model hosting, hardware, scaling. You pay per input and output token rather than for idle GPU time.

The model catalog includes models from multiple providers:
- **Anthropic Claude** (Haiku, Sonnet, Opus) — strong reasoning and code generation.
- **Meta Llama** — open-weight models suitable for on-premises or edge use cases.
- **Mistral** — efficient inference with strong multilingual performance.
- **Cohere** — purpose-built for search, embeddings, and classification.
- **Amazon Titan** — AWS's own models for text generation and embeddings.

The two primary APIs are `InvokeModel` (raw request/response, full control) and the `Converse` API (a unified multi-turn conversation interface that abstracts provider-specific message formats). Use `Converse` for anything that needs conversation history or tool use — it saves you from writing provider-specific adapters.

Two features are worth knowing early: **Guardrails** let you configure content filters, topic blocks, and PII redaction that apply to every request, regardless of which model you're calling. **Knowledge Bases** provide a managed RAG (Retrieval-Augmented Generation) pipeline — you connect an S3 bucket, Bedrock chunks and embeds your documents, and the model retrieves relevant passages at query time without you building the vector store yourself.

When Bedrock wins: you need fast time-to-value, you don't have training data for a custom model, and foundation model performance is sufficient.

> [!tip] Bedrock charges per token, not per second. Optimize prompt length before optimizing for latency — a shorter, well-structured prompt is cheaper and often produces better output than a verbose one.

@feynman

Bedrock is the managed database for AI — you don't run the engine yourself, you just write queries and pay for what you read and write.

@card
id: aws-ch13-c005
order: 5
title: Amazon SageMaker for Custom ML
teaser: When foundation models aren't enough and you need to train, fine-tune, or deploy your own models at scale, SageMaker is the managed ML platform that handles the infrastructure you don't want to manage.

@explanation

SageMaker is AWS's end-to-end managed ML platform. It covers the full lifecycle from experimentation through production.

**Studio** is the notebook environment — a hosted Jupyter interface with access to managed compute. You write your training code here, then hand it off to a Training Job when you're ready to scale beyond a single instance.

**Training Jobs** spin up a cluster of managed EC2 instances (your choice of GPU, CPU, or Trainium), run your training script, save the model artifact to S3, and tear the cluster down. You pay only for the time the job runs — no idle instances between runs.

**Inference endpoints** host your model for real-time prediction. You define the instance type, specify the number of instances, and SageMaker handles load balancing and health checks. **Batch Transform** is the alternative for offline scoring: you point it at an S3 dataset, it processes every record, and writes results back to S3 — no persistent endpoint, no idle cost between jobs.

**SageMaker Pipelines** chains training, evaluation, and deployment steps into a versioned, repeatable MLOps workflow. Combined with the **Model Registry**, you get a structured path from experiment to production with approval gates and version history.

When SageMaker wins over Bedrock: you have proprietary training data, you need a model fine-tuned for a specialized domain, or foundation model performance is meaningfully insufficient for your use case.

> [!info] The most common SageMaker cost trap is forgetting to delete inference endpoints. A single `ml.g4dn.xlarge` endpoint runs ~$0.74/hour — over $500/month if you leave it running after a proof of concept. Set up CloudWatch alarms on endpoint invocation counts and alert when it drops to zero.

@feynman

Bedrock is renting a car; SageMaker is buying a car and maintaining it — the right choice depends on how far you're driving and how specific your requirements are.

@card
id: aws-ch13-c006
order: 6
title: Lambda@Edge and CloudFront Functions
teaser: Running code at the CDN layer means you can modify requests and responses in milliseconds — but Lambda@Edge and CloudFront Functions are not interchangeable tools.

@explanation

Both services execute code at CloudFront edge locations rather than in a central AWS region, which cuts latency for viewers. The similarities end there.

**Lambda@Edge** runs your full Lambda function at the edge. You get Node.js or Python, up to 30 seconds of execution time, access to all four CloudFront event types (viewer request, origin request, origin response, viewer response), and the ability to make network calls to origins or external services. You're billed like a Lambda function — per request and per GB-second. The trade-off is cold starts: the first invocation at each edge location can take hundreds of milliseconds.

**CloudFront Functions** is a lighter runtime: JavaScript only, sub-millisecond execution, 10 KB code limit, no network calls, and only viewer request and viewer response events (not origin events). It's roughly 10x cheaper than Lambda@Edge at scale. No cold starts — the function is always warm.

Practical selection guide:
- **Auth header injection, URL redirects, simple A/B test routing** → CloudFront Functions. Sub-millisecond, cheap, no cold starts.
- **JWT validation against a remote JWKS endpoint** → Lambda@Edge. You need network calls.
- **Origin request manipulation or cache key normalization** → Lambda@Edge. CloudFront Functions can't fire on origin events.
- **Cookie-based feature flags at the edge** → either, depending on whether you need to call an external flag service.

> [!tip] Start with CloudFront Functions for viewer-layer logic. Move to Lambda@Edge only when you hit a constraint — network calls, execution time, or origin events. The cost and latency difference at scale is meaningful.

@feynman

CloudFront Functions is a regex replace at the network layer; Lambda@Edge is a full application process — use the former until you actually need the latter.

@card
id: aws-ch13-c007
order: 7
title: The Well-Architected Framework in Practice
teaser: The six pillars of the Well-Architected Framework are not a compliance checklist — they are the questions that distinguish systems that hold up in production from ones that surprise you at 2 a.m.

@explanation

The Well-Architected Framework gives you six lenses for evaluating any architecture:

**Operational Excellence** — Are you deploying via IaC instead of clicking in the console? Do you have runbooks for your operational procedures? Are you making small, frequent deployments rather than large, risky ones? Operational Excellence is about designing for the humans who run the system, not just the compute that executes it.

**Security** — Is every component operating with least-privilege IAM roles? Is data encrypted at rest (S3, RDS, EBS) and in transit (TLS everywhere)? Are secrets in Secrets Manager, not environment variables? Security is not a feature to add at the end; retrofitting it costs more than building it in.

**Reliability** — Are your stateful components in Multi-AZ configurations? Does your application auto-scale under load? Do you test failure scenarios — what happens when a single AZ goes down? Reliability means assuming failure and designing for recovery, not assuming the happy path.

**Performance Efficiency** — Are you using the right instance types for your workload (Graviton3 for general purpose, GPU instances for ML)? Are you serving static assets through CloudFront instead of directly from EC2? Right-sizing is not a one-time decision — revisit it quarterly as your traffic patterns change.

**Cost Optimization** — Are you using Spot for batch workloads? Have you committed capacity for your stable baseline? Are you deleting idle resources? Cost optimization is an ongoing operational practice, not a single audit.

**Sustainability** — Are you using Graviton processors (up to 60% better energy efficiency than x86)? Are you measuring efficiency metrics (output per CPU-hour) rather than just output? AWS provides per-region carbon intensity data if you need to report emissions.

> [!info] Use the Well-Architected Tool in the AWS console to run a formal review against your workload. It generates a report with prioritized improvement items — useful before a major launch or after a significant incident.

@feynman

The six pillars are the same checklist a senior engineer runs mentally before signing off on a design — the Framework just makes it explicit enough to run on any team, not just the one with the most experience.

@card
id: aws-ch13-c008
order: 8
title: Multi-Tier Web Application Pattern
teaser: The canonical three-tier web architecture on AWS has a specific assembly order — understanding each layer and why it's there prevents the shortcuts that cause production incidents.

@explanation

The canonical multi-tier web application on AWS assembles like this:

**Edge** — CloudFront sits in front of everything. It caches static assets, terminates TLS, and absorbs a significant fraction of your traffic before it touches your origin. Static assets (JavaScript bundles, images, fonts) live in S3 and are served via CloudFront with no compute cost.

**Load balancing** — An Application Load Balancer (ALB) receives the requests that CloudFront passes to origin. It terminates HTTP/2, routes traffic to target groups, and handles health checking. You configure HTTPS termination at the ALB, not at the application tier.

**Application tier** — Auto Scaling EC2 instances or ECS Fargate tasks behind the ALB. Fargate is increasingly the default choice: no EC2 fleet to manage, fine-grained CPU/memory pricing, and the same security model as EC2. Auto Scaling responds to CPU or request-count alarms in CloudWatch.

**Cache tier** — ElastiCache (Redis) in front of the database. Cache session data, computed results, and frequently-read rows. A cache hit costs microseconds and a fraction of a cent; a database read under contention can cost hundreds of milliseconds and degrade the entire tier.

**Data tier** — RDS in Multi-AZ. The standby replica is in a different AZ and fails over automatically with ~60 second RTO when the primary goes down. Read Replicas offload reporting queries.

**Secrets** — Application secrets, database passwords, and API keys live in AWS Secrets Manager. Applications fetch them at startup via the AWS SDK; no secrets in environment variables, Dockerfiles, or source control.

**Observability** — CloudWatch for metrics and alarms; X-Ray for distributed tracing to identify which service is causing latency.

> [!tip] Fargate is almost always the right default for the application tier. You eliminate the EC2 fleet management overhead and get per-second billing. Only move to EC2 if you need specific hardware (GPU), have extreme density requirements, or are committed enough on capacity to justify Savings Plans on EC2.

@feynman

The multi-tier pattern is a separation-of-concerns architecture — each layer does one thing and is independently scalable and replaceable.

@card
id: aws-ch13-c009
order: 9
title: Event-Driven Architecture on AWS
teaser: Event-driven systems decouple producers from consumers, but EventBridge, SNS, SQS, and Kinesis each make different guarantees — picking the wrong one introduces subtle failures that don't surface in development.

@explanation

AWS gives you four primary event-routing primitives, each with different semantics:

**SQS** is a queue: one message, one consumer, guaranteed at-least-once delivery. Messages persist for up to 14 days. You configure a Dead Letter Queue (DLQ) to catch messages that fail processing after N retries — the DLQ is how you catch silent failures rather than losing events. SQS is the right choice when you need reliable delivery and can tolerate some duplication.

**SNS** is a pub/sub bus: one message, many subscribers (fan-out). A single SNS topic can deliver to SQS queues, Lambda functions, HTTP endpoints, and email simultaneously. The canonical SNS→SQS pattern gives you fan-out plus durability: SNS broadcasts to multiple SQS queues, each of which delivers to a different consumer at its own pace.

**EventBridge** is a serverless event bus with rich filtering. You define rules that match event patterns (specific source, detail type, or any field in the event payload), and EventBridge routes to targets. The key advantages over SNS: schema registry, cross-account event routing (Partner Event Sources), and fine-grained content-based filtering. Use EventBridge when you need to route events based on content, integrate AWS service events (EC2 state changes, CodePipeline completions), or connect events across accounts.

**Kinesis Data Streams** is for ordered, high-throughput, replayable event streaming. Records are retained for up to 365 days and can be replayed — something SQS and SNS can't do. Shards give you ordered delivery within a partition key. Use Kinesis when ordering matters, when you need replay capability, or when you're ingesting thousands of events per second per partition.

Decision rule: guaranteed delivery + fan-out → SNS→SQS. Content-based routing or cross-account → EventBridge. Order, replay, or high-throughput streaming → Kinesis. Simple point-to-point → SQS alone.

> [!info] Always configure a DLQ on SQS queues that consume from SNS or EventBridge. Without one, a consumer failure after max retries silently drops the message — there is no visibility into what failed and no way to reprocess it.

@feynman

SQS is a mailbox, SNS is a megaphone, EventBridge is a smart router, and Kinesis is a tape recorder — they all move events, but the guarantee each one makes is completely different.

@card
id: aws-ch13-c010
order: 10
title: AWS Architecture Best Practices
teaser: The decisions that prevent the most serious AWS problems — surprise bills, security breaches, and unrecoverable outages — are almost all made at account setup time, before you deploy anything.

@explanation

Most AWS mistakes are not subtle architectural errors. They're predictable omissions that compound over time. Build these habits from the start:

**Never use the root account day-to-day.** The root account has unbounded permissions and can't be scoped. Create an IAM Identity Center user for all human access. Lock the root account behind MFA and put the credentials somewhere you only retrieve them in an emergency.

**Multi-account per environment.** Dev, staging, and production should be separate AWS accounts under an AWS Organizations hierarchy, not separate VPCs in one account. A compromised dev credential then can't reach production data. A quota exhaustion in dev doesn't affect production. SCPs at the organization level enforce controls across all accounts.

**Use IAM roles, not long-lived credentials.** EC2 instances, ECS tasks, and Lambda functions should authenticate via instance profiles and execution roles — not via access keys embedded in environment variables or source code. Rotating keys that are baked into dozens of services is painful; rotating roles is automatic.

**IaC everything.** Every resource should be reproducible from code — AWS CDK, Terraform, or CloudFormation. A console-only deployment is undocumented, non-reproducible, and one accidental deletion away from an incident. If you clicked it into existence, it's technical debt.

**Tag every resource from day one.** At minimum: `Environment`, `Owner`, `Project`, `CostCenter`. Tags are how Cost Explorer surfaces meaningful breakdowns, how you scope down IAM policies, and how you identify orphaned resources six months later.

**Enable GuardDuty and Security Hub on account creation.** GuardDuty monitors CloudTrail, VPC flow logs, and DNS logs for anomalous behavior — things like unusual API calls from unfamiliar IPs or EC2 instances probing the network. Security Hub aggregates findings from GuardDuty, Macie, Inspector, and other services into a single prioritized list. Both are cheap relative to the cost of a breach.

**Set billing alerts before deploying.** A $50 alert on a new account takes two minutes to configure. You will miss it at least once if you don't.

> [!warning] Skipping multi-account isolation because "it's just a dev environment" is the most common precondition for production data breaches. Blast radius containment is the point. A $1/month account structure is not the thing to optimize away.

@feynman

Account hygiene on AWS is like setting up a new server — you do the hardening before you open the ports, not after you've already deployed to it.
