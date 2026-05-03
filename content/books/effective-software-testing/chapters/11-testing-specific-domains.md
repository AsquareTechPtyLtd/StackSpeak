@chapter
id: est-ch11-testing-specific-domains
order: 11
title: Testing Specific Domains
summary: Testing the same general way for every kind of code is a category error — concurrency, performance, security, databases, and UI each demand a different toolkit, and knowing which technique fits which class of bug is half the practice.

@card
id: est-ch11-c001
order: 1
title: Different Domains, Different Toolkits
teaser: Applying the same testing technique to every class of code is a reliable way to miss the bugs that class is most likely to produce.

@explanation

Unit tests and integration tests are table stakes. They catch logic errors, wrong return values, and broken contracts. But the bugs that bring down production systems — corrupted shared state, degrading latency under load, SQL injection, flaky mobile gestures — largely slip through those nets. Not because the tests are bad, but because the technique is mismatched to the domain.

The core insight from Aniche is that each domain has a characteristic failure mode, and the right technique is chosen by reasoning about what can go wrong in that domain, not by habit.

Consider the differences:

- A concurrency bug requires coordinated thread scheduling to manifest — a normal unit test, which runs sequentially, cannot trigger it.
- A performance bug may not appear until you put 10,000 concurrent users on a system — a single-threaded test is blind to it.
- An injection vulnerability requires an adversary supplying unexpected input — conventional tests supply expected input.
- A UI regression is visual — an assertion on a data model cannot detect it.

The practical consequence is not that you need more tests, but that you need the right tests. Investing heavily in unit tests for a database access layer while skipping Testcontainers gives you false confidence. Running thousands of functional UI tests while ignoring Playwright's network intercept capabilities leaves a whole class of edge cases untouched.

> [!info] A test suite that covers only one domain of concern is incomplete regardless of its line coverage number. Coverage measures what lines were executed, not what failure modes were exercised.

@feynman

You wouldn't use a thermometer to measure blood pressure — different problems require instruments matched to what you're actually trying to detect.

@card
id: est-ch11-c002
order: 2
title: Concurrency Tests
teaser: Race conditions and deadlocks are timing-dependent — a passing test only proves the scheduler happened to order things safely that run, not that it always will.

@explanation

Concurrency bugs are the hardest class to test reliably. The same code can pass thousands of test runs and then corrupt state on the one run where the OS scheduler interleaves threads differently. Two categories dominate:

**Race conditions** occur when two threads read and write shared state without coordination. The result depends on execution order. The common symptom is a value that is "mostly right" — correct in 999 runs, wrong in the thousandth.

**Deadlocks** occur when two threads each hold a lock the other needs and neither can proceed. The symptom is a hang, not a crash — tests time out rather than fail with an exception.

Tools for surfacing these:

- **Microsoft Coyote** (formerly P#) controls the scheduler during test execution, systematically exploring thread interleavings that random scheduling would rarely hit. It turns non-deterministic concurrency bugs into reproducible failures.
- **Go's built-in Race Detector** (`go test -race`) instruments memory accesses and reports races at runtime. It works without special test logic — just add the flag.
- **Jepsen** is the standard for distributed systems: it runs real network partitions, clock skews, and node failures against running databases and verifies linearizability guarantees. It's the right tool when the "concurrency" is across nodes rather than threads.

The honest limitation: no tool gives you certainty. Coyote and the Race Detector dramatically improve detection rates, but a concurrency test that passes is still probabilistic evidence, not proof. The right response is to run these suites repeatedly in CI and to treat intermittent failures with high urgency — they are signals, not noise.

> [!warning] An intermittent ("flaky") test that sometimes fails is almost never a test infrastructure problem. It is almost always a real concurrency bug that only manifests under certain scheduling conditions.

@feynman

Testing concurrent code with a single-threaded test is like testing a roundabout by sending cars through it one at a time — the dangerous behavior only appears when multiple cars arrive simultaneously.

@card
id: est-ch11-c003
order: 3
title: Performance Tests
teaser: Latency and throughput are correctness properties — a system that returns wrong answers slowly has two bugs, not one.

@explanation

Performance testing is often treated as a late-stage "polish" activity rather than a first-class quality concern. The result is systems that pass every functional test and then collapse under realistic load. Aniche argues that performance should be treated as a correctness property: if your SLA says p99 latency under 200 ms, a response in 800 ms is a bug.

Four test types with distinct purposes:

- **Load tests** verify behavior at the expected peak load. Does the system hold its SLAs when 500 concurrent users are active?
- **Stress tests** push beyond expected peak to find the breaking point. At what load does the system fail, and does it fail gracefully or catastrophically?
- **Soak tests** (endurance tests) run at normal load for hours or days. They catch memory leaks, connection pool exhaustion, and log file growth that only appear over time.
- **Spike tests** apply a sudden sharp load increase. They test autoscaling behavior and the system's ability to recover after a burst.

The main tools in this space:

- **k6** (Grafana) uses JavaScript test scripts, integrates cleanly into CI, and has excellent threshold assertions for pass/fail gates.
- **Locust** uses Python scripts and has a web UI for real-time monitoring; better for teams comfortable in Python.
- **Gatling** uses Scala DSL and produces detailed HTML reports; common in JVM-centric organizations.

The key discipline is asserting on thresholds, not just running the test. A k6 script that runs without a `thresholds` block produces numbers but no pass/fail signal. Build performance gates into CI so regressions are caught at merge time.

> [!tip] A soak test run overnight catches an entire class of resource leak bugs that would otherwise appear only in production two weeks after a deploy.

@feynman

A performance test is a stress test for your assumptions — you're not asking "does this work?" but "does this still work when a hundred people do it at once, for eight hours straight?"

@card
id: est-ch11-c004
order: 4
title: Memory and Resource Tests
teaser: A leak that loses 1 MB per request looks harmless in a unit test and catastrophic after a week of production traffic.

@explanation

Memory leaks and resource exhaustion bugs have a unique property: they are invisible at the unit or integration level and only emerge under time or scale. A file handle that is never closed passes every functional assertion. A growing cache that is never evicted looks fine for the first thousand requests. The failure arrives much later, often as an out-of-memory crash or a "too many open files" error on a Saturday night.

Classes of resource bug:

- **Memory leaks** — objects allocated and never freed (in GC languages, references held that prevent collection).
- **File descriptor leaks** — files, sockets, or database connections opened and never closed.
- **Thread leaks** — threads spawned and never joined or terminated.
- **Connection pool exhaustion** — a pool that maxes out because connections are borrowed but not returned.

Tools by platform:

- **Valgrind** (C/C++) instruments memory access at the instruction level, reporting leaks, invalid reads, and use-after-free errors. It slows execution significantly but finds bugs that no other tool will.
- **Java Flight Recorder (JFR)** is the JVM's built-in low-overhead profiler. Combined with JDK Mission Control, it shows heap allocation rates, garbage collection pressure, and live object counts over time. Running JFR during a soak test is the standard way to catch slow leaks on the JVM.
- **Heap profilers** (YourKit, async-profiler, Instruments on Apple platforms) take allocation snapshots you can diff across time to find what is growing.

The practical pattern for catching leaks in CI is to assert on process metrics during soak-style runs: if RSS memory grows by more than X MB over N minutes at steady load, fail the test. This is coarse but catches the most damaging leaks automatically.

> [!info] Heap profilers produce enormous amounts of data. The useful workflow is to take a snapshot before a workload, run the workload, take a second snapshot, and diff — looking for object counts that grew without bound.

@feynman

A memory leak is like a slow drip into a bucket — each drip is invisible, but given enough time the bucket overflows, and by then it's far too late to find the original leak without a lot of cleanup.

@card
id: est-ch11-c005
order: 5
title: Security Tests
teaser: Security bugs are not logic errors — they are inputs an attacker constructs that your functional tests never supply, which is exactly why functional test suites miss them.

@explanation

Functional tests assume well-formed, expected inputs. An attacker's job is to supply inputs that are technically valid but semantically dangerous. This gap is why systems with high code coverage and comprehensive test suites still get breached.

The two most prevalent classes of vulnerability:

**Injection attacks** — SQL injection, XSS, command injection, path traversal. The attacker inserts executable code or special characters into an input field the application later interprets rather than treating as data. A test that sends `user@example.com` as an email address will never catch a SQL injection vulnerability; the attack requires sending `user@example.com'; DROP TABLE users; --`.

**Authentication and authorization bypass** — accessing resources or operations without the required identity or permissions. These often require testing state sequences (unauthenticated → partially authenticated → requesting protected resource) rather than individual requests.

The primary tools:

- **OWASP ZAP** is an open-source web application scanner. It acts as a proxy, intercepts traffic, and actively fuzzes inputs for injection and auth issues. The baseline scan is suitable for CI gates.
- **Burp Suite** is the professional tool of choice for manual penetration testing. Its intruder and scanner features support deep, targeted probing.
- **Semgrep** does static analysis, searching source code for patterns associated with known vulnerability classes (unsanitized inputs, insecure cipher modes, hardcoded credentials). It runs in CI and produces findings before code ever runs.

The honest tradeoff: automated scanners find known patterns reliably but miss novel logic vulnerabilities. Pen testing by a human expert finds things no scanner will catch, but it is expensive and point-in-time. The right posture is automated scanning in CI plus periodic manual reviews.

> [!warning] A passing security scan is not a certificate of safety — it means the tool found no patterns it was designed to find. Novel vulnerabilities, business logic flaws, and misconfigured access policies require human analysis.

@feynman

Security testing is the practice of thinking like someone who is actively trying to break your system — which requires deliberately supplying inputs your own tests would never produce.

@card
id: est-ch11-c006
order: 6
title: Fuzz Testing
teaser: Fuzzing generates massive volumes of unexpected inputs automatically, finding crashes and corruptions that no human would think to write as test cases.

@explanation

Fuzzing (fuzz testing) is the practice of feeding programs large quantities of random, malformed, or mutated inputs and observing whether they crash, hang, or produce incorrect output. It occupies a unique niche: it finds bugs in input-handling code that neither unit tests (which use expected inputs) nor security scanners (which apply known patterns) will catch.

How modern coverage-guided fuzzing works: the fuzzer starts with a seed corpus of valid inputs, then mutates them (bit flips, byte insertions, truncations) and monitors which mutations reach new code paths via coverage instrumentation. Mutations that increase coverage are retained and fuzzed further. Over millions of iterations, the fuzzer builds a corpus of inputs that exercises deep code paths — and when one of those paths contains a null pointer dereference, an integer overflow, or an out-of-bounds access, the fuzzer reports the exact input that triggered it.

The main tools:

- **AFL** (American Fuzzy Lop) is the original coverage-guided fuzzer; it operates on C/C++ binaries and has an extensive ecosystem of follow-on tools (AFL++, WinAFL).
- **libFuzzer** is LLVM's built-in fuzzer, integrated directly into the compiler toolchain. It is the standard approach for fuzzing C/C++ library code; Google's OSS-Fuzz uses it extensively.
- **Atheris** wraps libFuzzer for Python code, making coverage-guided fuzzing accessible to Python libraries and services.

What fuzzing finds that other techniques miss: buffer overflows, format string bugs, integer overflows at edge values, parser crashes on malformed input, and encoding/decoding bugs triggered by specific byte patterns. These are exactly the vulnerabilities that attackers manually probe for.

The tradeoff: fuzzing requires significant CPU time (effective campaigns run for hours or days) and a seed corpus that is representative of valid input structure. It is also output-blind by default — it finds crashes and hangs, but not semantic correctness errors (wrong output that does not crash).

> [!tip] Integrate fuzzing into CI as a nightly or weekly job, not a one-time activity. The value compounds as the corpus grows and mutations explore more code paths over time.

@feynman

Fuzzing is like hiring a very fast, tireless, slightly unpredictable intern to pound on your API's inputs for hours — the intern does not know what the right answer is, but they will very quickly find anything that makes the system break.

@card
id: est-ch11-c007
order: 7
title: Database Tests
teaser: An in-memory SQLite substituted for PostgreSQL is a lie dressed as a test — the query semantics, constraint behavior, and transaction isolation differ enough to miss real bugs.

@explanation

Database tests occupy difficult middle ground: too slow to run as unit tests, too important to skip. The common shortcut is to replace the real database with an in-memory fake (H2, SQLite) for speed. The problem is that each database engine has subtly different behavior:

- `GROUP BY` semantics differ between SQLite and PostgreSQL.
- Window functions, CTEs, and recursive queries have engine-specific behavior.
- Constraint enforcement timing (deferred vs immediate) varies.
- `RETURNING` clauses, upsert syntax, and JSON operators are dialect-specific.
- Transaction isolation levels behave differently across engines.

A test suite that passes against SQLite and fails against the real PostgreSQL in production is worse than no test suite — it provides false confidence.

**Testcontainers** is the standard solution. It starts a real database instance in a Docker container as part of the test run, runs your tests against it, and tears it down afterward. The database is the same engine, same version, same configuration as production. Testcontainers has first-class support for PostgreSQL, MySQL, MongoDB, Redis, Kafka, and dozens more. Startup adds 5–15 seconds per test suite, which is a reasonable cost for accuracy.

The complementary pattern is **transactional rollback**: wrap each test in a database transaction, perform the test operations, assert, then roll back rather than commit. The database is left clean for the next test without expensive truncation or re-seeding. Most testing frameworks have built-in support for this pattern.

The limits of transactional rollback: it cannot test code that itself manages transactions, or code that uses multiple connections, or behavior that only manifests at commit time (such as constraint triggers that fire on commit).

> [!info] Testcontainers requires Docker to be available in the test environment. Most CI platforms (GitHub Actions, GitLab CI) support Docker-in-Docker, but this is worth verifying before adopting Testcontainers as a team standard.

@feynman

Testing your PostgreSQL queries against SQLite is like rehearsing a speech in English and then delivering it in French — the sentences look similar written down, but the details that matter are different.

@card
id: est-ch11-c008
order: 8
title: Web and UI Tests
teaser: Playwright and Cypress give you real browser automation — but the page-object pattern is what keeps those tests maintainable when the UI inevitably changes.

@explanation

Web UI tests verify the full stack through a real browser. They catch bugs that no unit test can: incorrect DOM rendering, broken event handlers, form submission failures, and CSS-driven layout issues that make a button invisible or unreachable. The tradeoff is cost: they are slower to run, more brittle to UI changes, and harder to debug than lower-level tests.

The primary tools:

- **Playwright** (Microsoft) supports Chromium, Firefox, and WebKit in a single API. It has a strong async model, excellent network interception capabilities, and built-in auto-waiting that eliminates most explicit sleeps. It supports TypeScript, JavaScript, Python, Java, and C#.
- **Cypress** runs in-browser (Chromium only) and has a distinctive real-time test runner UI that makes debugging straightforward. Its trade-off is single-browser support and a less flexible async model compared to Playwright.

**The page-object pattern** is the critical design decision for maintainable UI tests. Instead of sprinkling `page.click('#login-btn')` selectors throughout every test, you encapsulate each page or component as a class with named methods:

```
class LoginPage {
  async fillCredentials(user, password) { ... }
  async submit() { ... }
  async getErrorMessage() { ... }
}
```

When the login button's selector changes, you update one class rather than every test that clicks it. Without page objects, UI test suites become unmaintainable after the third major refactor.

**Visual regression testing** compares screenshots pixel-by-pixel against approved baselines. Tools:

- **Percy** (BrowserStack) integrates with Playwright and Cypress, captures snapshots, and presents diffs for human approval.
- **Chromatic** is designed for Storybook-based component libraries and catches visual regressions at the component level before they reach full E2E tests.

> [!tip] Keep your UI test suite small and focused on critical user journeys — login, checkout, core workflow. A large suite of UI tests that covers every edge case is expensive to maintain and often slower to run than its value justifies.

@feynman

A UI test is like having a real user sit at the keyboard and click through your application — it is the most accurate simulation you have, but also the most expensive one to run and maintain.

@card
id: est-ch11-c009
order: 9
title: Mobile Tests
teaser: Mobile testing introduces a combinatorial device-and-OS matrix that no emulator farm fully covers — real devices remain necessary for the bugs that matter most.

@explanation

Mobile testing has the same layers as web testing — unit, integration, E2E — but with an additional dimension: the device-OS matrix. An app may behave correctly on an iPhone 16 running iOS 18.1 and crash on an iPhone 14 running iOS 17.5 due to a framework behavior change. This combinatorial explosion is what makes mobile testing expensive.

The primary tools:

- **XCUITest** (Apple) is the native iOS and macOS UI automation framework. It integrates tightly with Xcode, runs against both simulators and real devices, and is the only tool with full access to Apple's accessibility tree for reliable element targeting. It is the correct choice for any iOS project — not optional.
- **Espresso** (Google) is the equivalent for Android. It runs in the same process as the app, making it faster than other Android frameworks, and integrates with Android Studio natively.
- **Maestro** is a cross-platform mobile testing tool with a YAML-based DSL. It runs against both iOS and Android simulators/emulators and real devices. Its value proposition is simplicity — tests are easier to write and read than native XCUITest or Espresso, at the cost of some flexibility.

**Simulator vs. real device:** Simulators and emulators cover the majority of functional test scenarios and are essential for CI. But they cannot reproduce GPS behavior, camera access, hardware-specific rendering, cellular network conditions, or certain low-memory behaviors. Real device testing — whether via in-house devices or cloud farms (Firebase Test Lab, BrowserStack App Automate) — remains necessary for release verification.

The practical CI strategy is to run XCUITest or Espresso against the simulator on every pull request and run a real-device sweep against a representative matrix before each release.

> [!info] Device cloud farms reduce the management burden of maintaining a real-device lab, but they add cost per test minute and can introduce network latency that affects test timing. Budget accordingly.

@feynman

Testing a mobile app on only one simulator is like testing a website in only one browser — you have confirmed it works somewhere, but not that it works for the users who matter.

@card
id: est-ch11-c010
order: 10
title: Accessibility Tests
teaser: Accessibility failures are functional defects — a screen reader user who cannot complete checkout has encountered a bug, not a design preference.

@explanation

Accessibility (a11y) is frequently treated as a documentation concern or a compliance checkbox rather than a correctness property. The consequence is that bugs that prevent users with disabilities from completing core workflows ship alongside functional features and are not caught until an audit or complaint.

The spectrum of accessibility testing:

**Automated static analysis** catches a well-defined subset of WCAG violations: missing alt text on images, form fields without labels, insufficient color contrast ratios, missing ARIA roles on interactive elements, and duplicate IDs. These checks are cheap, fast, and should run on every CI build.

The primary tools:

- **axe-core** (Deque) is an open-source JavaScript library that runs in-browser. It integrates with Playwright, Cypress, and Jest. A single `checkA11y()` call after rendering a page flags all detectable WCAG violations.
- **Pa11y** is a command-line tool and CI-friendly wrapper around axe-core and HTML_CodeSniffer. It is easy to add to a build pipeline without test framework integration.
- **Lighthouse** (Google) runs in Chrome DevTools and CI (via `lighthouse-ci`). Its accessibility audit is a subset of axe-core's checks but is paired with performance, SEO, and best-practices audits, making it a useful overall quality gate.

The hard limit of automated tools: they detect roughly 30–40% of WCAG violations. Missing keyboard navigation flows, illogical focus order, confusing screen reader announcements, and cognitive load issues require manual testing with actual assistive technologies (VoiceOver, NVDA, JAWS). Automated testing is necessary but not sufficient.

> [!warning] An automated a11y tool reporting zero violations does not mean your product is accessible. It means the tool found no issues in the category of issues it checks. Manual testing with a screen reader is required for meaningful coverage.

@feynman

Accessibility testing is checking whether your application works for users whose experience of it is fundamentally different from your own — and that requires both automated checks and actually using the tools those users depend on.

@card
id: est-ch11-c011
order: 11
title: Localization and i18n Tests
teaser: Pseudo-locales and RTL layout checks automate the class of bugs that only appear in languages developers did not test in — at a fraction of the cost of maintaining full translated test suites.

@explanation

Internationalization (i18n) bugs are invisible until they are catastrophic. A string that is fine in English might overflow its container in German (strings can run 30–40% longer), display backwards in Arabic, render incorrectly when a format string argument is reordered for grammatical reasons, or produce incorrect dates and numbers due to locale-specific formatting assumptions.

Manually testing every locale is not scalable once a product supports more than a handful of languages. The automated techniques that scale:

**Pseudo-localization** replaces characters in translated strings with accented or extended Unicode equivalents (e.g., "Hello World" becomes "[Ħéļļö Ŵörļð]") without requiring actual translation. The result is a string that is slightly longer, uses characters from outside ASCII, and is visually distinct from untranslated text. Running your test suite against pseudo-locale catches:

- Hardcoded English strings that bypass the i18n pipeline (they appear unchanged while everything else is accented).
- Layout containers that break under slightly longer text.
- Code that assumes ASCII and fails on multi-byte characters.

**RTL (right-to-left) layout testing** verifies that the UI mirrors correctly for Arabic, Hebrew, and similar scripts. The most common failure is a layout that mirrors its text direction but leaves icons, progress indicators, or navigation arrows pointing in the wrong direction. This requires UI automation with an RTL locale applied.

**Format assertions** verify that dates, numbers, currencies, and plurals render correctly for specific locales. A test that asserts `formatDate(date, 'en-US')` produces "05/03/2026" and `formatDate(date, 'de-DE')` produces "03.05.2026" catches format code bugs before translators or users encounter them.

> [!info] Pseudo-localization is one of the highest-ROI testing techniques in i18n — it requires no translation budget, runs as part of a normal test suite, and catches most of the bugs that human translators would otherwise find during QA.

@feynman

Pseudo-localization is a way of asking your app, "are you actually using translations, or just pretending to?" — without needing to pay a single translator.

@card
id: est-ch11-c012
order: 12
title: Compliance Tests
teaser: Encoding regulatory requirements as executable assertions converts a manual audit process into a repeatable CI gate — and catches regressions before they become violations.

@explanation

Compliance with HIPAA, PCI-DSS, GDPR, SOC 2, and similar frameworks is often treated as a periodic audit exercise rather than an engineering discipline. The result is that compliance properties are verified infrequently, regressions between audits are invisible, and engineers lack fast feedback about whether a code change introduces a violation.

The shift Aniche argues for is treating compliance requirements as assertions: concrete, executable, and runnable in CI.

Concrete examples by domain:

**HIPAA (Protected Health Information):**
- Assert that PHI fields are encrypted at rest — check encryption configuration as part of infrastructure tests.
- Assert that audit log entries are produced for every access to PHI records.
- Assert that PHI is never written to application logs (scan log output in test runs for known PHI patterns).

**PCI-DSS (Payment Card Data):**
- Assert that credit card numbers are never stored in full — write a test that processes a payment and verifies the stored value is a masked or tokenized form.
- Assert that TLS versions below 1.2 are rejected by your payment endpoints.
- Assert that cardholder data fields are absent from application logs.

**GDPR:**
- Assert that deletion requests result in the actual removal (or anonymization) of records across all data stores.
- Assert that consent records exist for each marketing communication sent.

Tools that support automated compliance checking:

- **Chef InSpec** and **Open Policy Agent (OPA)** allow compliance rules to be expressed as code and evaluated against infrastructure and application state.
- **Semgrep** custom rules can encode source-level patterns (e.g., detecting code paths where PHI fields are passed to log statements).

The honest limitation: not all compliance requirements are automatable. Organizational controls (security training records, vendor agreements, physical access logs) require human audit. The value of automated compliance tests is not replacing audits but ensuring that the technical controls that can be tested are always tested.

> [!tip] Start by encoding the three or four compliance rules that have caused audit findings before — the rules where a regression has hurt you. That gives you the highest-ROI compliance test suite without requiring a full compliance-as-code program on day one.

@feynman

Compliance tests are the difference between checking your seatbelt once a year during inspection and having a light that tells you every time you forget to put it on — the rule is the same, but one catches violations continuously and one catches them only when someone looks.
