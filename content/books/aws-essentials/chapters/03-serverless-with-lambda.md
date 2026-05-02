@chapter
id: aws-ch03-serverless-with-lambda
order: 3
title: Serverless with Lambda
summary: Lambda is AWS's function-as-a-service offering — you understand how it executes, where it fails, how to size it, and when to reach for Step Functions instead of chaining raw functions.

@card
id: aws-ch03-c001
order: 1
title: Lambda and Event-Driven Execution
teaser: Lambda runs your code in response to events — you don't manage servers, but you still need to understand what "no servers" actually means for your execution model

@explanation

Lambda is AWS's function-as-a-service runtime. You upload code (or a container image), define a handler, and Lambda runs it in response to an event. The function is the unit of deployment: one handler, one purpose, one set of resource limits.

"Serverless" doesn't mean no servers — it means you don't provision, patch, or scale them. AWS manages a fleet of micro-VMs (Firecracker) behind the scenes. What you lose: persistent processes, long-running daemons, in-memory state between invocations. What you gain: zero idle cost, automatic horizontal scaling, no OS patching.

The execution environment lifecycle matters:

- **Init phase** — Lambda downloads your code, starts the runtime, and runs any initialization code outside your handler. This happens once per execution environment.
- **Invoke phase** — your handler is called with the event payload and a context object.
- **Shutdown phase** — the environment is frozen after the invocation completes and may be reused for future invocations, or discarded after a period of inactivity.

A concrete example: an S3 `PutObject` event triggers a Lambda that resizes an uploaded image. Lambda receives a JSON payload describing the bucket and key, your handler downloads the file, processes it, and writes the result. Lambda scales from zero to hundreds of concurrent invocations automatically — no Auto Scaling Group required.

> [!info] The execution environment freeze/thaw cycle is why you can cache clients (database connections, SDK clients) in module-level code — they survive across warm invocations of the same environment.

@feynman

Lambda is like a vending machine for compute — you push the button (event), it dispenses the result, and you never think about who restocked it

@card
id: aws-ch03-c002
order: 2
title: Three Invocation Models
teaser: How you invoke Lambda determines who handles errors and retries — getting this wrong means silently dropped events or cascading failures under load

@explanation

Lambda has three distinct invocation models, each with different error semantics.

**Synchronous** — the caller waits for the response. Examples: API Gateway, Application Load Balancer, Lambda URLs. If the function throws, the error is returned to the caller immediately. Retries are the caller's responsibility. Throttles (429s) propagate back to the caller as errors.

**Asynchronous** — the caller hands off the event and gets a 202 immediately. Examples: S3 event notifications, SNS, EventBridge. Lambda queues the event internally and invokes your function. On failure, Lambda retries twice with exponential backoff (roughly 1 min, then 2 min). After exhausting retries, the event goes to a dead letter queue or destination if configured. You never see the error unless you check CloudWatch or configure a failure destination.

**Stream-based (polling)** — Lambda polls a stream or queue on your behalf. Examples: Kinesis Data Streams, DynamoDB Streams, SQS. Lambda reads batches of records and invokes your function. On failure behavior differs by source: Kinesis/DynamoDB Streams retry the batch until it succeeds or expires (records are ordered; Lambda blocks progress until the batch clears). SQS retries until the message reaches its `maxReceiveCount`, then routes to the DLQ.

Key tradeoff table:
- Synchronous: low latency, caller-managed retries, tight coupling
- Asynchronous: decoupled, managed retries, at-least-once delivery
- Stream-based: ordered (Kinesis/DDB) or unordered (SQS), backpressure handled by batch size

> [!warning] Async invocations that fail silently are a common production bug. If you're using S3 triggers or SNS without a DLQ configured, failed invocations vanish with no alert.

@feynman

It's the difference between a synchronous function call, a fire-and-forget message to a queue, and a background thread reading from a log — same code, completely different failure contract

@card
id: aws-ch03-c003
order: 3
title: Cold Starts — Latency You Don't Control
teaser: The first invocation of a Lambda function pays a startup tax that can range from 100ms to over a second — knowing what drives it is the first step to managing it

@explanation

A cold start happens when Lambda has no warm execution environment to reuse. This triggers the full init phase: downloading your deployment package, starting the runtime process, and running your initialization code. The result is added latency before your handler even begins.

Typical cold start latencies by runtime:
- Node.js / Python: 100–300ms
- .NET / Java: 500ms–1s+
- Container images: 1–3s+ (image pull overhead)

The JVM is the worst offender — class loading and JIT compilation add hundreds of milliseconds. AWS introduced **SnapStart** for Java 21 (and Java 17 with Corretto) to mitigate this: Lambda snapshots the initialized execution environment and restores from that snapshot on cold start, cutting Java cold starts to under 1 second in most cases.

**Provisioned Concurrency** is the blunt-force solution: you pay Lambda to keep N execution environments pre-initialized and warm at all times. Those environments have zero cold start. Cost: you pay for provisioned concurrency per GB-second even when idle, so it's not free.

When cold starts matter most:
- User-facing synchronous APIs (human latency perception ~300ms)
- Latency-sensitive financial or trading workloads

When cold starts don't matter:
- Async background processing (S3, SNS, EventBridge)
- Batch jobs
- Internal tooling

> [!tip] Before paying for Provisioned Concurrency, check if you actually have a cold start problem — use CloudWatch's `Init Duration` metric to measure how often and how long cold starts occur in production.

@feynman

A cold start is like the first compile — every subsequent run uses the cached bytecode, but the first person to the endpoint pays the full build cost

@card
id: aws-ch03-c004
order: 4
title: Lambda Layers — Shared Code Without Shared State
teaser: Layers let you package libraries and shared code separately from your function, but the convenience comes with coupling risks you should understand before going all-in

@explanation

A Lambda layer is a ZIP archive of code, libraries, or data that you attach to a function alongside its deployment package. The layer's contents are extracted to `/opt` in the execution environment and are available to your function at runtime.

Common uses:
- Python/Node.js dependencies (e.g., `numpy`, `boto3` extensions, `axios`)
- Custom runtimes
- Shared utility code across multiple Lambda functions
- Configuration or data files that don't change often

Limits that matter:
- A function can reference **up to 5 layers** simultaneously
- The unzipped size of the function plus all layers must be under **250MB** (or 10GB for container images)
- Layers are versioned — when you publish a new layer version, functions keep using the old version until you update them explicitly

The coupling risk: if 50 functions reference layer version 3 of your shared utilities, updating the layer doesn't automatically update any function. You have to redeploy each one. This creates version drift — different functions running different versions of the same shared code, often invisibly.

```bash
# Attach a layer to a function via CLI
aws lambda update-function-configuration \
  --function-name my-function \
  --layers arn:aws:lambda:us-east-1:123456789:layer:my-utils:7
```

> [!warning] Layers are a distribution mechanism, not a module system. They don't enforce versioning contracts or give you dependency resolution. Treat them as a bundling convenience, not an architecture primitive.

@feynman

A Lambda layer is like a shared `/usr/local/lib` — it's convenient until two functions need different versions of the same library and you realize there's no package manager enforcing compatibility

@card
id: aws-ch03-c005
order: 5
title: Concurrency Limits and Throttling
teaser: Lambda scales automatically — until it hits a limit, at which point it silently throttles your function with a 429, and understanding the three concurrency controls is how you avoid that surprise

@explanation

Lambda concurrency = number of requests being handled simultaneously. Each invocation occupies one unit of concurrency for its duration.

**Account-level concurrency limit:** By default, all Lambda functions in an account/region share a pool of **1,000 concurrent executions**. You can request an increase via AWS Support. If your aggregate concurrency exceeds this, new invocations get throttled.

**Reserved concurrency:** You can allocate a fixed number of concurrent executions to a specific function. This does two things:
- **Guarantees** that function can always scale up to its reserved amount (taken from the account pool)
- **Caps** that function — it cannot exceed the reserved amount even if the account pool has headroom

Reserved concurrency of 0 effectively disables a function (useful for emergency shutoffs).

**Provisioned concurrency:** Pre-initialized environments, already discussed for cold starts. Counts against your reserved concurrency allocation.

**Throttling behavior:** When a function is throttled, Lambda returns a 429 `TooManyRequestsException`. Behavior depends on invocation model:
- Synchronous: 429 returned to caller immediately
- Asynchronous: Lambda retries internally for up to 6 hours
- Stream-based: Lambda retries until the record expires or a bisect-on-error policy isolates the bad batch

**Burst limits:** Lambda can scale from 0 to 500–3,000 new concurrent executions per minute (varies by region), then 500/minute after that. Sudden traffic spikes can hit burst limits before they hit account limits.

> [!tip] Use reserved concurrency to protect downstream systems — if your function hits a database with a 100-connection pool, capping the function at 80 concurrent executions prevents connection exhaustion even during traffic spikes.

@feynman

It's like a connection pool with three dials: total connections in the building, connections reserved for your team's app, and connections you're paying to keep open even at midnight

@card
id: aws-ch03-c006
order: 6
title: Lambda URLs — HTTPS Without API Gateway
teaser: Lambda URLs give your function a dedicated HTTPS endpoint in seconds — useful for simple cases, but knowing the auth and routing limits keeps you from outgrowing them without a plan

@explanation

A Lambda function URL is a dedicated HTTPS endpoint AWS provisions directly for a function, bypassing API Gateway entirely. Format: `https://<random-id>.lambda-url.<region>.on.aws`.

**Auth modes:**
- `AWS_IAM` — callers must sign requests with SigV4. Suitable for internal service-to-service calls where the caller has an IAM role.
- `NONE` — fully public, no auth. Your function must implement its own auth logic if needed. Suitable for public webhooks.

**When Lambda URLs make sense:**
- Single-function webhooks (Stripe, GitHub, Slack)
- Internal microservices called by other AWS services with IAM roles
- Rapid prototyping without standing up an API Gateway stack

**When to use API Gateway instead:**
- You need request/response transformation, custom domain names, usage plans, or rate limiting per API key
- You have multiple Lambda functions behind one domain with path-based routing
- You need a WAF (Web Application Firewall) in front of the endpoint
- You need request validation, mock integrations, or stage management

Lambda URLs support CORS configuration natively — you set allowed origins, headers, and methods directly on the function configuration.

```json
{
  "Cors": {
    "AllowOrigins": ["https://myapp.com"],
    "AllowMethods": ["GET", "POST"],
    "AllowHeaders": ["Content-Type"],
    "MaxAge": 300
  }
}
```

> [!info] Lambda URLs do not support custom domains or path-based routing. If you need `api.myapp.com/v1/users` and `api.myapp.com/v1/orders` to hit different functions, you need API Gateway or a CloudFront distribution in front.

@feynman

A Lambda URL is like binding a function to `localhost:3000` — dead simple, zero ceremony, and the right choice until you need a router

@card
id: aws-ch03-c007
order: 7
title: Step Functions — Orchestration Over Chaining
teaser: When your workflow needs branching, retries, timeouts, or parallel execution, chaining Lambdas with ad-hoc state passing is the wrong architecture — Step Functions is the right one

@explanation

AWS Step Functions is a managed orchestration service. You define a state machine in Amazon States Language (JSON/YAML), and Step Functions executes it, managing state, retries, and transitions between steps.

**Why not just chain Lambdas?** When Lambda A calls Lambda B synchronously, Lambda A's execution context is blocked waiting for B. You're paying for idle compute. Worse, error handling becomes ad-hoc: A's code decides what to do if B fails, and that logic is buried in application code rather than being explicit and observable.

**Step Functions makes orchestration explicit:**

- **Task states** invoke Lambda, ECS, SNS, SQS, Glue, or any AWS service
- **Choice states** branch based on output values — no `if/else` in application code
- **Wait states** pause for a duration or until an external signal (heartbeat pattern)
- **Parallel states** run branches concurrently and wait for all to complete
- **Map states** process arrays of items in parallel

**Standard vs Express workflows:**
- Standard: up to 1 year duration, exactly-once execution semantics, full audit trail in execution history. $0.025 per 1,000 state transitions. Best for business-critical, long-running processes.
- Express: up to 5 minutes, at-least-once semantics, high-throughput (100,000 executions/second). $1 per million executions plus duration. Best for high-volume event processing.

Error handling is declarative:

```json
"Retry": [{ "ErrorEquals": ["Lambda.ServiceException"], "IntervalSeconds": 2, "MaxAttempts": 3, "BackoffRate": 2 }],
"Catch": [{ "ErrorEquals": ["States.ALL"], "Next": "HandleFailure" }]
```

> [!warning] Do not orchestrate Step Functions workflows from within a Lambda function — the Lambda pays for the time spent waiting. Use Step Functions to call Lambdas, not the other way around.

@feynman

Chaining Lambdas for a multi-step workflow is like writing a distributed transaction with try/catch blocks — it works until failure mode number three, and then you wish you had a coordinator

@card
id: aws-ch03-c008
order: 8
title: Runtimes and the Execution Environment
teaser: Lambda's execution environment gives you a predictable OS layer, a `/tmp` directory, and a reuse contract — knowing these lets you write faster functions and avoid a class of subtle bugs

@explanation

Lambda supports managed runtimes for Node.js (20.x, 18.x), Python (3.12, 3.11, 3.10), Java (21, 17, 11), .NET (8, 6), Go (1.x), and Ruby (3.2). You can also bring a custom runtime by providing a `bootstrap` executable that implements the Lambda Runtime API — this is how Rust, C++, and other languages run on Lambda.

Container image support (up to 10GB) lets you package any runtime environment as an OCI image.

**The execution environment:**
- Amazon Linux 2023 base
- `/tmp` directory: 512MB by default, configurable up to **10GB** — the only writable filesystem in the environment
- Read-only: `/var/task` (your function code), `/opt` (layers)
- Environment variables: set at deploy time, available via `process.env` / `os.environ` — do not put secrets here directly; use SSM Parameter Store or Secrets Manager and cache the result

**Execution context reuse pattern:** Lambda may reuse the same execution environment for multiple invocations. Module-level initialization (SDK clients, database connections, in-memory caches) persists across warm invocations. Use this deliberately:

```python
import boto3
# This runs once per execution environment, not per invocation
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('my-table')

def handler(event, context):
    return table.get_item(Key={'id': event['id']})
```

Do not store invocation-specific state at module level — the next invocation will see stale values.

> [!tip] Write to `/tmp` for scratch files (e.g., PDF generation, image processing), but don't assume it's empty — a warm environment carries over `/tmp` contents from the previous invocation. Always generate unique filenames or clean up after yourself.

@feynman

The execution environment is like a worker process that handles one request at a time — between requests it idles, global state is preserved, and you never know if you're getting a fresh worker or a recycled one

@card
id: aws-ch03-c009
order: 9
title: Function Sizing and Pricing
teaser: Lambda memory controls CPU allocation too, not just RAM — and the pricing model rewards you for right-sizing rather than defaulting to 128MB and wondering why everything is slow

@explanation

Lambda's resource model is memory-centric. You allocate memory from **128MB to 10,240MB (10GB)** in 1MB increments. CPU and network bandwidth scale proportionally with memory: at 1,769MB you get the equivalent of one full vCPU, at 3,538MB you get two, and so on.

**Timeout:** Maximum 15 minutes per invocation. For anything longer, use Step Functions with a Lambda activity, ECS Fargate, or Batch.

**Pricing has two components:**

1. **Requests:** $0.20 per million invocations (first 1M/month free)
2. **Duration:** $0.0000166667 per GB-second — memory allocated (in GB) × wall-clock time (in seconds)

Free tier: 400,000 GB-seconds per month, 1M requests per month.

**Example:** A 512MB function that runs for 500ms per invocation, invoked 10 million times per month:
- 0.5GB × 0.5s × 10M = 2,500,000 GB-seconds
- Duration cost: 2,500,000 × $0.0000166667 ≈ $41.67
- Request cost: 10M × $0.0000002 = $2.00
- Total: ~$43.67/month

**vs EC2:** A `t3.small` (2 vCPU, 2GB RAM) costs ~$15/month but runs 24/7 regardless of traffic. Lambda is cheaper for bursty workloads; EC2 is cheaper for sustained high-throughput workloads where Lambda would be running nearly continuously anyway.

Right-sizing: use AWS Lambda Power Tuning (open-source Step Functions state machine) to benchmark your function at multiple memory settings — sometimes doubling memory cuts duration enough that total GB-seconds decreases and your bill drops.

> [!tip] The 128MB default is rarely optimal. A function CPU-bound at 128MB may run 4x faster at 512MB for only 2x the GB-second cost — net cheaper, and with lower latency.

@feynman

Lambda pricing is like renting a GPU by the millisecond — the spec you request changes both the speed and the rate, so the optimal choice isn't always the cheapest tier

@card
id: aws-ch03-c010
order: 10
title: Destinations and Dead Letter Queues
teaser: Async Lambda invocations fail silently by default — destinations and DLQs are how you make failures observable and recoverable instead of invisible data loss

@explanation

When Lambda is invoked asynchronously (S3, SNS, EventBridge) and the function fails after all retries, the event is dropped unless you've configured somewhere for it to go.

**Dead Letter Queues (DLQs):** An SQS queue or SNS topic that receives the original event payload when async invocation exhausts retries. Configured at the function level. The payload includes the original event plus metadata (error message, attempt count). You can re-process DLQ messages manually or with another Lambda.

**Lambda Destinations** (newer, preferred): Instead of just capturing failures, destinations let you route results — both success and failure — to a target. Supported targets: SQS, SNS, EventBridge, another Lambda function.

Difference between DLQs and destinations:

- DLQ only captures failures; destinations capture both success and failure
- Destinations include the full invocation record (request, response, error), not just the original payload
- Destinations are more flexible: you can fan out success events to EventBridge for downstream processing

```json
{
  "DestinationConfig": {
    "OnSuccess": { "Destination": "arn:aws:sqs:us-east-1:123:success-queue" },
    "OnFailure": { "Destination": "arn:aws:sqs:us-east-1:123:failure-queue" }
  }
}
```

**Why this matters operationally:**
- Without a DLQ or failure destination, a bug introduced into a Lambda processing S3 uploads silently drops every event that fails — no error in your application logs, just missing data.
- With a DLQ, those events accumulate in SQS. You fix the bug, redeploy, then replay the DLQ to recover the lost work.
- CloudWatch alarms on DLQ depth (`ApproximateNumberOfMessagesVisible`) give you an early warning before the data loss becomes a customer-visible incident.

> [!warning] Every async Lambda function without a failure destination or DLQ is a silent data loss risk. Configure one before the function goes to production, not after the first incident.

@feynman

A DLQ for async Lambda is like a dead-letter branch in a CI pipeline — the job failed, but the artifact is still there so you can diagnose and re-run it instead of losing the work entirely
