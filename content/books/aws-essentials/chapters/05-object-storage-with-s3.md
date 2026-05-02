@chapter
id: aws-ch05-object-storage-with-s3
order: 5
title: Object Storage with S3
summary: S3 is AWS's foundational object store — understanding its data model, storage classes, access controls, and performance characteristics lets you use it correctly for everything from simple file hosting to high-throughput data pipelines.

@card
id: aws-ch05-c001
order: 1
title: S3 Fundamentals: Buckets and Objects
teaser: S3 stores data as objects inside buckets — and the flat namespace, globally unique naming, and 5TB object ceiling have real implications for how you design around it.

@explanation

S3's data model has two layers:

- **Bucket** — a globally named container in a single AWS region. The name must be unique across every AWS account on the planet. If `my-app-assets` is taken by anyone, it's taken. Buckets have no fixed capacity — you can store unlimited objects in a single bucket.
- **Object** — a key-value pair. The key is the full path string (e.g., `images/2024/jan/photo.jpg`). The value is the binary data, up to **5TB per object**. Metadata (Content-Type, custom headers) travels alongside the value.

The namespace looks hierarchical — S3 renders `/`-delimited keys as folders in the console — but there are no real directories. `images/2024/jan/photo.jpg` is a single flat string. Listing objects with a prefix is a string scan, not a directory traversal. This matters when you're writing tooling that walks S3 "folders": you're filtering a flat list, not recursing a tree.

Practical constraints to internalize:

- Objects up to **5GB** can be uploaded in a single PUT request. Anything larger requires multipart upload.
- The 5TB per-object ceiling is a hard limit — there's no workaround.
- Bucket names must be DNS-compliant: lowercase letters, numbers, hyphens, 3–63 characters.
- You cannot rename an object — copy to the new key, then delete the old one.

> [!info] Because bucket names are globally unique, most teams prefix with their organization or AWS account ID (e.g., `acme-prod-media-assets`) to avoid collisions and clarify ownership.

@feynman

A bucket is like a git remote — globally addressable, flat internally, and everyone shares the same namespace whether they know it or not.

@card
id: aws-ch05-c002
order: 2
title: Storage Classes: Matching Cost to Access Frequency
teaser: S3 has seven storage classes that trade retrieval speed and availability for price — picking the wrong one either wastes money or slows your application down.

@explanation

S3 storage classes are priced on three dimensions: storage GB/month, per-request cost, and retrieval fee (if any). The right class depends on how often you read the object and how fast you need it back.

- **S3 Standard** — default class. High availability (99.99%), 3+ AZ replication, no retrieval fee. Use for actively accessed data. Highest per-GB storage cost.
- **S3 Intelligent-Tiering** — AWS monitors access patterns and automatically moves objects between a Frequent Access tier (Standard pricing) and an Infrequent Access tier (IA pricing). Small monthly monitoring fee per object. No retrieval fee. Best when your access patterns are unpredictable.
- **S3 Standard-IA** (Infrequent Access) — same 3-AZ durability as Standard, but lower storage price with a per-GB retrieval fee and a 30-day minimum storage charge. Use for backups or disaster recovery files you rarely read.
- **S3 One Zone-IA** — same as Standard-IA but stored in a single AZ. ~20% cheaper than Standard-IA. Data is lost if that AZ is destroyed. Use only for reproducible data (thumbnails, derived assets).
- **S3 Glacier Instant Retrieval** — millisecond retrieval, similar to Standard-IA pricing but cheaper storage. Minimum 90-day storage charge. Good for archive data accessed a few times a year.
- **S3 Glacier Flexible Retrieval** — retrieval takes minutes to hours (Expedited: 1–5 min at extra cost; Standard: 3–5 hrs; Bulk: 5–12 hrs free). Much cheaper storage than Instant. Use for true archives with no latency requirement.
- **S3 Glacier Deep Archive** — lowest cost storage on S3 (~$0.00099/GB/month). Retrieval takes 12–48 hours. Designed for compliance archives you might never actually retrieve.

> [!warning] Glacier classes have minimum storage durations (90 days for Glacier Instant, 180 days for Deep Archive). Deleting before the minimum still charges for the full minimum — factor this into your lifecycle math.

@feynman

Choosing a storage class is the same tradeoff as choosing between RAM, SSD, spinning disk, and tape — you're trading access latency and retrieval cost for cheaper storage, and the right call depends entirely on your read pattern.

@card
id: aws-ch05-c003
order: 3
title: S3 Versioning and Accidental-Delete Recovery
teaser: Versioning makes S3 a time machine for your objects — every overwrite and delete is reversible, but every version is also billed, so it's a deliberate choice.

@explanation

When you enable versioning on a bucket, S3 preserves every version of every object rather than overwriting in place. Each version gets a unique version ID — a long alphanumeric string like `3/L4kqtJlcpXroDTDmJ+rmSpXd3dIbrHY+MTRCxf3vjVBH40Nr8X8gdRQBpUMLUo`.

What happens on deletion: S3 does not erase the object. It inserts a **delete marker** — a zero-byte placeholder that becomes the current version. A GET request returns 404 because the marker is on top, but the real data is still there. To recover, delete the delete marker and the previous version resurfaces.

What this costs: every version is stored independently and billed at its full size. A 100MB file modified 50 times across a year stores 5GB of version history. This surprises teams that enable versioning without a lifecycle rule to expire old versions.

Key features enabled by versioning:

- **MFA Delete** — requires a second factor (hardware MFA device) to permanently delete a version or change the versioning state. Protects against compromised credentials deleting audit-critical data.
- **Replication** — cross-region replication (CRR) and same-region replication (SRR) both require versioning to be enabled on source and destination.

> [!tip] Pair versioning with a lifecycle rule that expires non-current versions after N days (e.g., 30 days). You get recovery capability for recent mistakes without paying for indefinite version history.

@feynman

Delete markers in S3 are like soft deletes in a database — the row is still there, just filtered out of normal queries, and recovery is a targeted UPDATE away.

@card
id: aws-ch05-c004
order: 4
title: Lifecycle Rules: Automating Tier Transitions and Expiration
teaser: Lifecycle rules let S3 manage object aging automatically — moving cold data to cheaper storage and deleting expired objects without you writing a single cron job.

@explanation

A lifecycle rule is a bucket-level policy that triggers transitions or expirations based on object age. Rules apply to all objects, or you can scope them to a prefix (`logs/`) or tag (`env=prod`).

**Transition actions** move objects to a cheaper storage class after N days since creation (or N days since becoming a non-current version for versioned buckets). Example: transition to Standard-IA at 30 days, then Glacier Flexible Retrieval at 90 days.

**Expiration actions** permanently delete objects after N days. For versioned buckets, expiration on current versions inserts a delete marker; you need a separate rule to expire non-current versions and delete markers.

**Multipart upload cleanup** is easy to overlook. If an application initiates a multipart upload and crashes before completing, the in-progress parts sit in your bucket accumulating storage charges but never becoming an accessible object. A lifecycle rule with `AbortIncompleteMultipartUpload` after 7 days cleans these up automatically.

Transition order constraints: S3 requires moves to go down the cost ladder (Standard → Standard-IA → Glacier), never up. The minimum time in Standard before transitioning to Standard-IA is 30 days.

A practical multi-tier example:
- Day 0: uploaded as S3 Standard
- Day 30: auto-transition to Standard-IA
- Day 90: auto-transition to Glacier Flexible Retrieval
- Day 365: auto-delete

> [!info] Lifecycle rules run once per day, not instantly. An object set to expire "after 1 day" might persist for up to 48 hours depending on when the rule evaluates.

@feynman

Lifecycle rules are database TTLs for storage — you declare intent once and the system handles the cleanup, rather than writing a background job you'll eventually forget to maintain.

@card
id: aws-ch05-c005
order: 5
title: Multipart Upload: Reliable Large Object Transfers
teaser: Multipart upload is how S3 handles objects over 5GB and how you get parallel throughput and resumability for anything over 100MB.

@explanation

A standard S3 PUT has a 5GB hard ceiling. For larger objects — or for reliability on flaky networks — multipart upload is the mechanism. It works in three phases:

1. **Initiate** — call `CreateMultipartUpload`, receive an `UploadId` that ties the parts together.
2. **Upload parts** — send each part as a separate `UploadPart` request, receiving an ETag per part. Parts can be sent in parallel from multiple threads or machines. Minimum part size is **5MB** (except the last part, which can be any size). Maximum 10,000 parts, so a 1TB object needs parts of at least 100MB.
3. **Complete** — call `CompleteMultipartUpload` with the ordered list of part ETags. S3 assembles the object atomically. Until this call succeeds, the object does not exist in the bucket.

You can also abort an in-progress upload with `AbortMultipartUpload`, which discards all uploaded parts and stops billing.

Why use it even below 5GB:
- Parts upload in parallel — 10 parallel 100MB parts saturate available bandwidth better than one sequential 1GB PUT.
- Resumability — if a part fails, retry just that part, not the whole object.
- The AWS SDKs (boto3, the Go SDK, etc.) handle multipart automatically at a configurable threshold, typically 8MB or 100MB.

> [!warning] Until `CompleteMultipartUpload` is called, the parts are invisible in the bucket but fully billable. A crash during upload leaves orphaned parts charging you indefinitely — add the AbortIncompleteMultipartUpload lifecycle rule.

@feynman

Multipart upload is chunked transfer encoding for object storage — same idea as streaming a large HTTP response in pieces instead of buffering the whole thing before sending.

@card
id: aws-ch05-c006
order: 6
title: Presigned URLs: Temporary Access Without Policy Changes
teaser: Presigned URLs grant time-limited access to a private S3 object using your IAM credentials — no bucket policy changes, no public access, no proxy server required.

@explanation

A presigned URL is a regular HTTPS URL with query-string parameters that encode the IAM identity, the operation (GET or PUT), the target object, and an expiry timestamp, all signed with the caller's credentials. Anyone with the URL can perform that operation until the URL expires — no AWS credentials of their own required.

**GET presigned URLs** are the most common use case: give a user a temporary download link to a private file. The URL expires after the configured window (seconds to 7 days depending on the signing method). After expiry, the URL returns a 403.

**PUT presigned URLs** allow direct browser-to-S3 uploads without routing the file through your server. The client uploads directly to S3; your server never sees the bytes. This is the standard pattern for user avatar uploads, document ingestion, or any large file workflow.

Permissions boundary: the presigned URL inherits the permissions of the IAM identity that created it. If that role loses access to the object, existing URLs stop working immediately — the URL is a signature, not a cached grant. If the role is an IAM user with long-lived credentials, a presigned URL can be valid for up to 7 days. If the role is an assumed STS role, the URL expires when the STS session expires, even if you set a longer TTL.

Common expiry patterns:
- User download links: 15 minutes
- Upload URLs for a form flow: 1 hour
- Pre-generated sharing links: 24–48 hours max

> [!warning] Treat presigned URLs like bearer tokens — anyone who has the URL can use it. Log their generation, use the shortest viable expiry, and avoid sharing them over plaintext channels.

@feynman

A presigned URL is like a signed JWT — your identity backs the claim, it expires on a schedule, and anyone holding it is granted whatever it says, no questions asked.

@card
id: aws-ch05-c007
order: 7
title: S3 Select: SQL Queries Directly on Stored Objects
teaser: S3 Select lets you filter rows and columns from CSV, JSON, or Parquet objects using SQL expressions, so you pay to transfer only the data you actually need.

@explanation

Without S3 Select, reading part of an object means downloading the whole thing — a 10GB CSV to extract 500 rows costs you 10GB of GET transfer and your application's time to parse it. S3 Select pushes the filtering into S3 itself. You send a SQL expression; S3 returns only the matching subset.

What it supports:
- **Formats:** CSV, JSON (newline-delimited), and Parquet (columnar).
- **SQL subset:** SELECT, WHERE, LIMIT. Aggregate functions like COUNT, SUM, MIN, MAX. No JOINs, no subqueries.
- **Compression:** Gzip and Bzip2 for CSV and JSON. Parquet has native column pruning which makes it the most cost-efficient format for this use case.

Cost model: you're billed for data scanned (the full object is read from disk) and data returned (the filtered output). Scanning a 10GB file to return 1MB still charges for 10GB scanned — the savings come from reduced transfer cost and client-side processing time, not from reduced disk reads on S3's end.

When S3 Select is not the right tool:
- Queries across multiple objects — S3 Select operates on a single object per call.
- Complex analytics — use **Amazon Athena** instead. Athena runs distributed queries across thousands of S3 objects, supports full SQL, and is built on Presto/Trino under the hood. The cost model is similar ($5/TB scanned) but Athena scales horizontally across objects.

> [!tip] Parquet is the best input format for S3 Select: columnar storage means S3 only reads the columns your query touches, not the full row, which meaningfully reduces the bytes-scanned charge.

@feynman

S3 Select is like a database index scan instead of a full table scan — you still open the file, but you exit early once you have what you need.

@card
id: aws-ch05-c008
order: 8
title: S3 Access Control: Three Layers, One Right Answer
teaser: S3 has three access control mechanisms and one of them is obsolete — understanding how bucket policies, IAM policies, and Block Public Access interact prevents both over-permissioning and locked-out buckets.

@explanation

Access to an S3 object is evaluated by combining three layers:

**IAM policies** (identity-based) — attached to the IAM user, role, or group making the request. Defines what that identity can do across all S3 resources. This is where you control which services in your account can read which buckets.

**Bucket policies** (resource-based) — attached directly to the bucket. Evaluated regardless of the requester's IAM policy. The primary tool for cross-account access: a bucket policy can explicitly allow `arn:aws:iam::OTHER_ACCOUNT_ID:root` to perform actions on your bucket. Also used to enforce HTTPS-only access or restrict access to specific VPC endpoints.

**ACLs** (Access Control Lists) — the original S3 access model, predating IAM. Object-level grants to AWS accounts or predefined groups. AWS now recommends **disabling ACLs** entirely via the bucket Ownership Controls setting (`BucketOwnerEnforced`). Modern access patterns are better expressed through bucket policies and IAM policies.

**Block Public Access** — four settings (configurable at account and bucket level) that override any policy or ACL that would make objects publicly accessible. Turning all four on means no policy or ACL change can accidentally expose data to the internet. This should be on for every bucket that doesn't explicitly need to serve public content. AWS enables it by default on new buckets created after April 2023.

Least-privilege checklist:
- Grant `s3:GetObject` on specific prefixes, not `s3:*` on `arn:aws:s3:::*`.
- Use condition keys (`aws:SourceVpc`, `aws:PrincipalOrgID`) to narrow bucket policies.
- Enable Block Public Access at the account level to catch misconfigured buckets before they matter.

> [!warning] A bucket policy that allows public access and Block Public Access both enabled will result in a 403, not public access — Block Public Access wins. But if you then disable Block Public Access, the bucket becomes public immediately. The order of operations matters.

@feynman

IAM policy plus bucket policy is like firewall rules at two layers — both have to allow the traffic, and if either blocks it, the request fails, regardless of what the other one says.

@card
id: aws-ch05-c009
order: 9
title: S3 Event Notifications and EventBridge Integration
teaser: S3 can emit events when objects are created or deleted — use native notifications for simple fan-out to Lambda or SQS, and EventBridge when you need flexible routing or multiple consumers.

@explanation

S3 emits events on meaningful state changes. The most common event types:

- `s3:ObjectCreated:*` — covers PUT, POST, COPY, and CompleteMultipartUpload.
- `s3:ObjectRemoved:*` — covers DELETE and deleting a versioned object.
- `s3:ObjectRestore:*` — when a Glacier object is restored.
- `s3:Replication:*` — replication failures and status changes.

**Native S3 event notifications** send events directly to one of three targets: **SQS queue**, **SNS topic**, or **Lambda function**. Configuration lives on the bucket. You can filter by prefix and suffix (e.g., only `images/` prefix, only `.jpg` suffix). The limitation: one notification configuration per event type per destination — you can't fan out to multiple Lambda functions without going through SNS first.

**EventBridge integration** is the more powerful option. Enable it on the bucket (one checkbox), and all S3 events flow into EventBridge's default event bus. From there, you define rules with content-based filtering (any S3 event field, not just prefix/suffix) and route to multiple targets simultaneously — Lambda, Step Functions, SQS, SNS, API Gateway, another bus. EventBridge also provides a 24-hour replay window if a target is temporarily unavailable.

When native notifications are enough:
- Single Lambda triggered by uploads — simpler to reason about, fewer moving parts.
- High-volume, latency-sensitive pipelines where you want to skip the EventBridge hop.

When to use EventBridge:
- Multiple downstream consumers of the same event.
- Routing based on object metadata or event content beyond prefix/suffix.
- Cross-account or cross-region event delivery.

> [!info] EventBridge adds a small additional latency (~1 second typical) compared to native notifications. For most use cases this is irrelevant, but in sub-second processing pipelines it's worth measuring.

@feynman

Native S3 notifications are point-to-point function calls; EventBridge is a message bus with a routing table — choose based on how many consumers need to know and how complex the routing logic is.

@card
id: aws-ch05-c010
order: 10
title: S3 Performance Patterns for High-Throughput Workloads
teaser: S3's default request-rate limits are generous but not unlimited — prefix spreading, Transfer Acceleration, and byte-range fetches are the three tools that get you past the ceiling.

@explanation

S3 automatically scales to handle high request rates, but the scaling unit is the **prefix** — the leading segment of the object key up to the first `/`. Each prefix supports:

- **3,500 PUT/COPY/POST/DELETE requests per second**
- **5,500 GET/HEAD requests per second**

At those rates, a single prefix is unlikely to be a bottleneck for most workloads. Where teams hit limits: high-volume pipelines that write everything under one prefix (e.g., `events/` as the only prefix for millions of log files per second).

**Prefix spreading** distributes load by introducing variety in the leading key segment. Instead of `logs/2024-01-15-00001.gz`, use hashed or randomized prefixes: `a3f/2024-01-15-00001.gz` and `b2c/2024-01-15-00002.gz`. Each unique prefix gets its own rate limit budget. Five distinct prefixes give you 27,500 GET/s.

Note: the old advice to use random hex prefixes predated S3's automatic scaling improvements (pre-2018). Today, S3 scales automatically to traffic patterns within a prefix over time — random prefixes help when you need to burst immediately without a warm-up period.

**S3 Transfer Acceleration** routes uploads through AWS CloudFront edge locations. Instead of connecting from a client in Tokyo to a bucket in us-east-1 over the public internet, the client connects to the nearest edge, which routes the transfer over AWS's backbone. Transfer Acceleration costs extra per GB and is only worth enabling when the geographic distance and network path genuinely limit throughput — typically for global end-user uploads. Benchmark first with the S3 Transfer Acceleration Speed Comparison tool before committing.

**Byte-range fetches** download different parts of an object in parallel using the HTTP `Range` header. A 1GB file can be split into ten 100MB ranges and downloaded in parallel from ten threads, then reassembled locally. The same technique powers parallel ETL reads of large Parquet or CSV files. No special S3 configuration required — it's a standard HTTP feature that S3 supports natively.

> [!tip] For large file downloads, byte-range fetches are almost always worth implementing. The speedup is proportional to the number of parallel ranges, limited by your available bandwidth and the overhead of reassembly.

@feynman

Prefix spreading in S3 is the same idea as sharding a database by a hash key — you distribute load across independent partitions so no single one becomes the bottleneck.
