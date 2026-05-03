@chapter
id: aicr-ch04-pipelines-for-mass-refactoring
order: 4
title: Pipelines for Mass Refactoring
summary: A mass refactoring is a pipeline — discovery, transform, validate, review, land — and the pipeline shape determines whether the campaign ships or stalls.

@card
id: aicr-ch04-c001
order: 1
title: The Five-Stage Pipeline
teaser: Every mass refactoring that ships follows the same five-stage shape — and every one that stalls skipped at least one of them.

@explanation

Treat a mass refactoring as a data pipeline, not a series of manual edits. The stages are always the same:

```text
discovery → transform → validate → review → land
```

Each stage is its own loop. Discovery finds the work. Transform applies it. Validate confirms nothing broke. Review adds a human checkpoint. Land merges the result. The stages run in order, but each can iterate independently — you can tighten your discovery query without re-running transforms, or tighten your validation gate without touching the LLM call.

Where campaigns fail:

- **Skipping discovery calibration.** Starting transforms on thousands of files before verifying the query is accurate.
- **No validation gate.** Merging LLM-generated diffs that silently break the type system.
- **Giant landing batches.** A single PR touching 800 files that sits in review for three weeks while the codebase drifts underneath it.
- **No idempotency.** A partial failure mid-campaign leaves the codebase half-transformed with no safe way to resume.

The pipeline framing gives you something to reason about when a campaign stalls. Which stage is the bottleneck? Which stage is producing bad output? Most failures are traceable to a specific stage boundary.

@feynman

A mass refactoring campaign is like an assembly line — each station has one job, bad output from one station poisons every station downstream, and the line only moves as fast as its slowest stage.

@card
id: aicr-ch04-c002
order: 2
title: Discovery: Finding the Work
teaser: The quality of your discovery query determines the scope of your campaign — a loose query wastes compute; a tight one misses half the call sites.

@explanation

Discovery means finding every file, function call, or pattern you intend to change. The two most useful tools are `ast-grep` for structural AST queries and `semgrep` for rule-based pattern matching. Ripgrep works for simple text patterns but is blind to syntax structure.

```bash
# Find all direct dict-access patterns that should be .get() calls
ast-grep --pattern 'config["$KEY"]' --lang python --json \
  | jq -r '.[].file' | sort -u > candidates.txt

# Semgrep example: find deprecated API call sites
semgrep --config rules/deprecated-api.yaml --json src/ \
  | jq -r '.results[].path' | sort -u >> candidates.txt
```

The cost of a bad discovery query compounds through the whole campaign:

- **Too broad:** transforms run on files that don't need changes; the LLM still generates a diff, which you still have to validate and review. Wasted tokens, wasted CI time.
- **Too narrow:** you ship the campaign, consider it done, and the remaining call sites keep accumulating until someone finds them in a bug report.

Always run the discovery query and manually inspect the first ten results before committing to a wide run. Count the false-positive rate. If it's above 5–10%, tighten the query first.

> [!warning] A discovery query that matches 2,000 files when the real target is 200 means you will generate, validate, and review ten times more diffs than you need to.

@feynman

Writing a discovery query is like writing a search warrant — too vague and you're searching houses that have nothing to do with the case; too narrow and the suspect walks because you missed the room the evidence was in.

@card
id: aicr-ch04-c003
order: 3
title: Sampling: Calibrate Before Going Wide
teaser: Pick five to ten representative files, refactor them manually or with a first-pass prompt, and verify the output before you run the transform on thousands.

@explanation

Before running a transform across the full candidate list, pull a representative sample. "Representative" means: a file from each major pattern variant your discovery query matched, including edge cases (files with unusual imports, files that are already partially migrated, files with dense comment blocks).

The sampling workflow:

1. Pick 5–10 files from your candidate list spanning the shape of the variation.
2. Run the transform on them.
3. Read every diff manually.
4. Ask: does the output consistently match what you intended? Are there systematic errors?
5. Adjust the prompt, then re-run the sample.
6. Repeat until the sample output has no systematic errors.

What you learn during sampling you cannot learn any other way:

- Edge cases your prompt doesn't handle (multi-line call sites, call sites inside f-strings, call sites inside type annotations).
- Hallucinations that look plausible but are wrong.
- Formatting drift that your linter will flag later.

Running the full campaign without sampling is the most common cause of the "90% done, stuck at 10%" problem — the bulk of files transform cleanly, but the remaining 10% all share a structural pattern that the prompt handles badly, and you discover this only when you're staring at hundreds of failing diffs.

> [!tip] Document the sample output alongside the prompt. When you re-run the campaign three months later with a newer model, the sample acts as a regression test for prompt quality.

@feynman

Calibrating on a sample before going wide is like test-fitting a new production mold on ten units before you stamp out ten thousand — the cost of adjusting the mold on ten is nothing compared to the cost of scrapping ten thousand.

@card
id: aicr-ch04-c004
order: 4
title: Batching Strategies
teaser: Batch size affects review cost, revert cost, and how badly the campaign ages — and there is no universally correct answer.

@explanation

Three common batching patterns and their tradeoffs:

```text
file-by-file     → smallest blast radius, slowest to merge, highest PR overhead
PR of 50 files   → reviewable in one sitting, easy to revert, good default
PR of 1000 files → fast to land if the campaign is high-confidence, catastrophic to revert
```

**File-by-file** makes sense when the changes are risky or the codebase has strict per-file ownership. The review cost is real: one PR per file for a 500-file campaign means 500 PRs. Use this pattern only when each file genuinely needs individual review.

**50-file PRs** is the practical default for most campaigns. A reviewer can scan 50 diffs in a focused session, the CI cost is manageable, and reverting 50 files is survivable if something is wrong.

**Giant PRs** (300+ files) are appropriate only when: (1) the transform is purely mechanical and fully validated by CI, (2) the team has explicitly agreed to trust the pipeline over individual diff review, and (3) you have a tested revert procedure. Without all three, giant PRs stall in review while the main branch drifts — creating merge conflicts that then require another automated pass to resolve.

The merge-conflict cost of slow campaigns is underappreciated. A 1,000-file PR that takes two weeks to review will have conflicts in hundreds of files if the main branch is active. At that point, the rebase itself requires another automated step, which requires another validation pass, which costs more time than the batch savings bought you.

> [!info] Batch size is a campaign-scoped parameter, not a per-team preference. Set it based on the confidence level of the transform, the activity rate of the main branch, and the capacity of the review team.

@feynman

Choosing your batch size is like choosing how many packages to load onto one delivery truck — put too few on and the fleet never clears the warehouse; put too many on and a single broken axle means the whole day's delivery is sitting on the side of the road.

@card
id: aicr-ch04-c005
order: 5
title: The Transform Stage
teaser: The transform is the LLM call itself — and its reliability depends on concurrency limits, retry strategy, and how deterministically you've constrained the prompt.

@explanation

The transform stage takes a file from the candidate list and produces a diff. Structurally:

```python
async def transform(file: Path, semaphore: asyncio.Semaphore) -> Diff | None:
    async with semaphore:
        content = file.read_text()
        prompt = build_prompt(content)
        try:
            response = await llm_client.complete(prompt, model="...", temperature=0)
            return parse_diff(response, original=content)
        except RateLimitError:
            await asyncio.sleep(backoff())
            return await transform(file, semaphore)  # retry
        except TransformError as e:
            log_failure(file, e)
            return None  # skip and report
```

Key implementation concerns:

- **Concurrency.** Most LLM APIs enforce request-per-minute and token-per-minute limits. Use a semaphore to cap concurrent requests. A safe default is 5–10 concurrent requests; tune based on your API tier.
- **Temperature.** Set to 0 for code transforms. You want deterministic output, not creative variation.
- **Retry strategy.** Rate limit errors are transient — exponential backoff with jitter recovers cleanly. Model errors (malformed output, context length exceeded) are not transient — log them and skip rather than retrying.
- **Output parsing.** Validate that the response is a well-formed diff before writing anything to disk. An LLM that returns a prose apology instead of a diff should produce a logged failure, not a corrupted file.

@feynman

Running the transform stage is like running a print job across a large printer fleet — you throttle submissions to match throughput, retry on paper jams, and log which pages came out blank rather than sending the corrupted ones to the binding machine.

@card
id: aicr-ch04-c006
order: 6
title: Validation Gates
teaser: Every transform must pass a minimum validation gate before the diff is written — and the gate must be meaningful enough to catch regressions, not just confirm the file still parses.

@explanation

The validation gate runs immediately after a transform produces a diff. A gate that only checks "does the file compile?" is too weak. A gate that runs the full production test suite is too slow for per-file execution. The right gate is layered:

```text
layer 1: parse / compile check   → catches syntax errors and broken imports
layer 2: type check (fast)       → catches type regressions (mypy --fast, tsc --noEmit)
layer 3: unit tests for the file → catches behavioral regressions in that module
layer 4: integration tests       → run at the PR level, not per-file
```

Tool invocations for layers 1–3:

```bash
# Python
mypy --fast path/to/file.py && python -m pytest tests/unit/test_file.py -q

# TypeScript
tsc --noEmit && vitest run src/module.test.ts

# Go
go vet ./... && go test ./pkg/module/...
```

Failure-handling policy: if a file fails layers 1–2, skip it, log it, and continue the campaign. Do not apply a diff that breaks the type system — silent regressions discovered weeks later are far more expensive than acknowledged failures discovered now.

Failures at layer 3 require judgment: a broken unit test may indicate the transform is wrong, or it may indicate the unit test was testing an implementation detail that the refactor intentionally changed. Log the failure and flag it for human review rather than auto-skipping.

> [!warning] Running transforms without a type-check gate is the most reliable way to ship a mass refactoring that looks done on the surface and breaks in production three sprints later.

@feynman

Validation gates are the quality inspection station on the assembly line — you catch defective parts now, at the cost of one inspection per part, rather than catching them later at the cost of a full recall.

@card
id: aicr-ch04-c007
order: 7
title: The Review Stage
teaser: Human review is a checkpoint, not a bottleneck — and the goal is to structure it so a reviewer can establish confidence in the campaign without reading every diff.

@explanation

The review stage sits between validation and landing. Its purpose is to establish human confidence that the pipeline is producing correct output — not to read every single diff as if it were written by hand.

The practical review structure for a well-validated campaign:

- **Sample review:** reviewer reads 10–20 randomly selected diffs end-to-end. If these look correct, the rest are trusted.
- **Edge case review:** reviewer reads every diff that the validation gate flagged or that came from files with unusual structure.
- **Statistical review:** reviewer checks aggregate metrics — what fraction of files succeeded, what fraction failed, what was the distribution of diff sizes. Anomalies (a file that changed 400 lines when every other file changed 5) are investigation targets.

The goal is calibrated confidence, not exhaustive verification. Chapter 7 covers review-at-scale strategy in depth — including how to structure sampling, how to use coverage-guided review, and how to set campaign-level approval thresholds.

What matters here: build the review stage into the pipeline before the campaign starts. A campaign that ships without a review stage is not a validated campaign — it's a bet.

> [!info] The review stage is not just for catching bugs. It's also how the team builds confidence in LLM-assisted transforms as a repeatable practice, which matters for the next campaign.

@feynman

The review stage is like a spot-check audit of a production run — you don't weigh every box, but you weigh enough boxes from enough positions in the run to be confident the filling machine is calibrated correctly.

@card
id: aicr-ch04-c008
order: 8
title: Landing Strategy
teaser: One giant PR moves fast until it stalls; many small PRs move slowly but never stall — and the right choice depends on how long the campaign takes relative to the activity rate of main.

@explanation

"Landing" means merging the transforms into the main branch. The landing strategy is a function of campaign confidence and main-branch activity:

```text
campaign confidence   main-branch activity   → strategy
high                  low                    → few large PRs (50–200 files each)
high                  high                   → many small PRs (20–50 files each)
medium                any                    → small PRs with mandatory human review
low                   any                    → file-by-file with full review
```

The merge-conflict cost grows with campaign duration. If your campaign is spread across two weeks and the main branch has 50 commits per day, every open PR is accumulating merge conflicts continuously. At high-activity repositories, campaigns older than three days often need a rebase pass before they can land at all.

Mitigation strategies:

- **Compact the campaign.** Run all transforms in a short window (overnight, over a weekend) and land PRs in the same window.
- **Feature flag the transform.** Land the transformed code behind a flag; flip the flag separately. This allows landing without immediate behavioral impact.
- **Auto-merge on green.** For high-confidence, fully-validated campaigns, configure the PR to auto-merge when CI passes. This removes the human latency bottleneck from landing.

The worst outcome is a campaign that takes three weeks to review, accumulates hundreds of merge conflicts, and then requires a second automated pass to resolve conflicts — effectively running the campaign twice.

@feynman

Landing a mass refactoring is like docking a fleet of ships — the longer they sit in the harbor queue, the more the tide changes, and eventually you're re-navigating the whole approach.

@card
id: aicr-ch04-c009
order: 9
title: The Four Loops Pattern
teaser: Discovery, transform, validate, and review are each an independent loop — and treating them as independent is what lets you fix one stage without re-running everything.

@explanation

Each stage in the pipeline is not a one-shot step — it's a loop. The loops can iterate independently:

```text
discovery loop:   tighten query → re-run query → inspect sample → tighten again
transform loop:   run transforms → inspect failures → adjust prompt → re-run failures
validate loop:    run gates → fix gate config → re-run gates on cached diffs
review loop:      reviewer flags issues → re-transform flagged files → re-validate → re-review
```

This independence is what makes large campaigns manageable. If the discovery query was too broad, you don't re-run transforms — you re-run the discovery loop and filter the candidate list. If 8% of transforms failed the type check, you don't re-run the whole campaign — you isolate the failing files, adjust the prompt for their pattern, and re-run the transform loop on that subset.

Practically, this means your pipeline script should be structured so each stage can be invoked independently with a file list as input:

```bash
./pipeline.sh discover            # write candidates.txt
./pipeline.sh transform candidates.txt  # write diffs/
./pipeline.sh validate diffs/     # write validated/ and failures.txt
./pipeline.sh review validated/   # produce PRs
```

Coupling the stages tightly — one monolithic script that runs everything end-to-end with no resume capability — means every partial failure forces a full re-run.

> [!tip] Build resume capability into every stage. Store intermediate state (candidate lists, generated diffs, validation results) in files on disk, not only in memory.

@feynman

The four loops pattern is like separating the editorial process of a newspaper into independent desks — the photographers, writers, copy editors, and layout team can each iterate their work without blocking or re-doing one another's.

@card
id: aicr-ch04-c010
order: 10
title: Idempotency
teaser: Running the pipeline twice on the same input should produce the same output — without idempotency, a partial failure leaves your codebase in a state you can't reason about.

@explanation

An idempotent pipeline is one where running it a second time on already-transformed files produces no new changes. This property matters in two situations: resuming after partial failure, and re-running after a hotfix lands on main while your campaign is in flight.

Achieving idempotency requires each stage to be idempotent:

- **Discovery:** the query runs against the current state of the code. If a file was already transformed, it will no longer match the discovery pattern, and the pipeline will not re-transform it.
- **Transform:** if a diff already exists on disk for a file, skip the LLM call. If the file's content matches the already-applied output, produce an empty diff.
- **Validate:** running the gate twice on the same diff produces the same pass/fail result.
- **Land:** git apply on an already-applied patch is a no-op (or a clear error), not silent corruption.

```python
def transform_if_needed(file: Path, output_dir: Path) -> None:
    diff_path = output_dir / f"{file.stem}.patch"
    if diff_path.exists():
        return  # idempotent: skip already-generated diffs
    diff = run_transform(file)
    diff_path.write_text(diff)
```

The failure mode of non-idempotent pipelines: a campaign runs 700 files successfully, crashes on file 701, and now 700 files are in an intermediate state. Without idempotency, the safe recovery is to revert all 700 changes and start over. With idempotency, you resume from file 701.

@feynman

An idempotent pipeline is like a road resurfacing crew that checks the road condition before laying asphalt — they don't repave a section that was already resurfaced yesterday, and if the machine breaks down mid-street, they pick up exactly where they left off tomorrow.

@card
id: aicr-ch04-c011
order: 11
title: Observability
teaser: A campaign without visible progress metrics is a campaign where problems hide until they're expensive — instrument every stage before you start the run.

@explanation

Observability for a refactoring campaign means knowing, at any point during execution: how many files have been discovered, how many transforms have been attempted, how many passed validation, how many are in review, and how many have landed.

Minimum instrumentation:

```python
# Structured log line per file
{
  "file": "src/auth/login.py",
  "stage": "transform",
  "status": "success",
  "diff_lines": 12,
  "tokens_used": 840,
  "duration_ms": 1430
}
```

From structured logs you can derive a dashboard (even a simple terminal one) that shows campaign velocity and failure patterns:

```text
campaign: deprecate-config-access   2026-05-03 14:22
discovered:  1842 files
transformed:  934 / 1842  (50.7%)   failures: 23
validated:    891 / 934   (95.4%)   failures: 43
landed:       612 / 891   (68.7%)
```

What observability surfaces that log-reading does not:

- Failure clusters (23 of the 43 validation failures are in `src/legacy/` — a structural pattern, not random noise).
- Velocity drops (transform rate fell from 80/min to 12/min — rate limiting is kicking in).
- Staleness (the campaign has not moved in 6 hours — something upstream is blocked).

Publish the dashboard somewhere the team can see it. A campaign that only the author can observe is a campaign that can't be handed off, resumed by someone else, or post-mortemed if it goes wrong.

> [!info] Token usage per file is a useful campaign metric — a file that consumed 10x the average tokens is worth investigating manually before its diff lands.

@feynman

Instrumenting a refactoring campaign is like putting a progress tracker on a construction project — without it you can't tell whether you're behind schedule, which subcontractor is the bottleneck, or whether the team actually stopped working three days ago.

@card
id: aicr-ch04-c012
order: 12
title: Reproducibility
teaser: A campaign you can't reproduce is a campaign you can't debug — capture the prompt, the model version, and the code snapshot before you run anything.

@explanation

Reproducibility means: given the same inputs, the same pipeline produces the same outputs. For a refactoring campaign, inputs are: the discovery query, the prompt template, the model and its version, the model parameters (temperature, max tokens), and the exact state of the codebase at the time the campaign ran.

Minimum reproducibility record:

```json
{
  "campaign_id": "deprecate-config-access-2026-05-03",
  "discovery_query": "config[\"$KEY\"]",
  "prompt_template": "prompts/dict-to-get.txt",
  "prompt_sha": "a3f9e2b",
  "model": "claude-sonnet-4-6",
  "temperature": 0,
  "max_tokens": 4096,
  "codebase_commit": "9fb85d5",
  "run_date": "2026-05-03T14:00:00Z"
}
```

Store this record in the repository alongside the campaign artifacts. The cost of capturing it is minutes. The cost of not having it:

- A validation failure two weeks after the campaign lands. Was it caused by the transform or by a separate change? Without the codebase commit, you can't isolate it.
- A newer model produces different output on the same prompt. You can't compare unless you know what model produced the original diffs.
- A team member asks to re-run the campaign on a newly added module. Without the prompt and model version, they're starting from scratch — and may produce diffs that are inconsistent with the ones already merged.

Reproducibility is also what makes post-mortems tractable. Campaigns that can't be reproduced can't be improved — they just recur with the same failure modes.

> [!tip] Commit the campaign manifest to a `campaigns/` directory in the repository. Future team members (and future you) will need it.

@feynman

A reproducibility record for a refactoring campaign is like the lab notebook in a chemistry experiment — without it, a result that didn't go as expected is just a mystery, not a problem you can isolate and fix.
