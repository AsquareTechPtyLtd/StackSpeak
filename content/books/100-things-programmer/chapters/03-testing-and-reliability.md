@chapter
id: ttp-ch03-testing-and-reliability
order: 3
title: Testing and Reliability
summary: A test suite is only as valuable as what it actually verifies — this chapter covers the structure, discipline, and tradeoffs that separate a suite that catches real bugs from one that just creates the impression of safety.

@card
id: ttp-ch03-c001
order: 1
title: The Testing Pyramid
teaser: Unit tests at the bottom, integration in the middle, E2E at the top — the shape is not arbitrary, it's an investment model with fast feedback at the base and high-fidelity verification at the peak

@explanation

The pyramid's shape encodes a specific tradeoff: speed and isolation vs. realism and scope.

**Unit tests (base — most):** Fast, isolated, deterministic. A function under test with no external dependencies. Run in milliseconds. You should have hundreds. They catch logic errors cheaply and give you fast feedback during development.

**Integration tests (middle — fewer):** Slower, test real interactions between components — your service calling a real database, your parser consuming real file input. Run in seconds. You might have dozens. They catch interface mismatches and integration assumptions that unit tests miss.

**E2E tests (top — fewest):** Slowest, most realistic. Drive the whole system like a user would. Run in minutes. You want as few as necessary to cover critical paths. They catch failures in the assembled system that no lower layer can see.

The point of the pyramid shape is not just the count — it's the investment ratio. If your test suite is inverted (more E2E than unit tests), you get slow feedback, high maintenance cost, and fragile tests tied to UI details that change often. A team at Google famously maintained a 70/20/10 split (unit/integration/E2E) and found that most regressions were caught at the unit layer for a fraction of the cost.

> [!info] An inverted pyramid is a warning sign: the team is paying E2E prices for coverage that should be bought with unit tests.

@feynman

Same principle as caching — the fastest layer handles the most requests, the expensive layer handles only what the cheap layer can't.

@card
id: ttp-ch03-c002
order: 2
title: What Makes a Good Unit Test
teaser: A test that just confirms current behavior without asserting what's correct is documentation, not a safety net — good tests are specifications written in code

@explanation

There's a difference between a test that catches regressions and one that merely documents what the code currently does. The second kind passes when the code is wrong, which is worse than having no test — it creates false confidence.

A good unit test:

- **Tests behavior, not implementation.** It asserts what the function produces, not how it produces it. If you refactor the internals without changing the contract, the test should still pass. Tests that assert which private methods were called are fragile and tell you nothing meaningful.
- **Tests one thing.** If the test fails, the failure should point immediately at the problem. A test that exercises five behaviors tells you something is wrong without telling you what.
- **Reads as a specification.** The test name should complete the sentence "when X, it should Y." If you deleted all the source code and kept the tests, could someone rebuild the behavior?
- **Only mocks what genuinely needs isolating.** If a dependency is fast, deterministic, and in-process, mocking it adds complexity without adding isolation value.

A test that asserts `result != nil` catches nothing useful. A test that asserts `result == .failure(.unauthorized)` for a specific input is a specification of behavior that will break if someone changes the error path.

> [!warning] Tests that exist only to increase coverage numbers are worse than no tests — they create the illusion of safety while letting real bugs through.

@feynman

A unit test that confirms current behavior without checking correctness is like a type annotation that says `Any` — technically present, practically useless.

@card
id: ttp-ch03-c003
order: 3
title: Test-Driven Development
teaser: TDD is a design tool first and a testing strategy second — the red/green/refactor loop forces you to think about the interface before you think about the implementation

@explanation

TDD has three steps: write a failing test (red), write the minimum code to make it pass (green), then clean up without breaking anything (refactor). The loop is short — minutes, not hours.

Where TDD earns its reputation:

- **Complex, unfamiliar logic.** When you don't know the shape of the solution, writing the test first forces you to think clearly about inputs, outputs, and edge cases before getting tangled in implementation details. This is where TDD produces its clearest design benefits.
- **Well-defined contracts.** Parsing, validation, SRS scheduling formulas, state machines — anywhere the specification is crisp, TDD converts the spec directly into executable tests before you write a line of logic.

Where TDD gets in the way:

- **UI and visual work.** You can't write a meaningful failing test for "the button should feel right at this size." Exploratory UI work is better driven by iteration and visual feedback.
- **Truly exploratory code.** When you're spiking to discover what's even possible, writing tests first adds friction before you understand what you're building. Write the spike, then extract and test the stable parts.

TDD does not guarantee good tests. It's possible to write bad tests test-first just as easily as after. The value is the constraint it places on design — you can't write a test-first test for a function that has six required dependencies without noticing that the design is painful.

@feynman

Writing the test first is like designing the API before the implementation — it forces you to think about how the thing will be used before you think about how to build it.

@card
id: ttp-ch03-c004
order: 4
title: Flaky Tests
teaser: One flaky test in a suite of a hundred doesn't affect just that test — it poisons the entire suite by training engineers to ignore red signals

@explanation

A flaky test is one that passes and fails non-deterministically on the same code. It is not a minor inconvenience; it is an active liability.

The damage a flaky test does:

- Engineers learn to re-run the suite when they see a failure instead of investigating. This trains the habit of ignoring red signals.
- A test that sometimes passes on broken code is worse than no test — it may green-light a bad deploy.
- When engineers start skipping or disabling flaky tests, the effective coverage of the suite drops silently.

Common sources of flakiness:

- **Timing dependencies.** Tests that sleep for a fixed duration and assume external work completes in time. Replace with explicit waits or dependency injection of a controllable clock.
- **Shared mutable state.** Tests that modify a global, a database, or a file and depend on the order of execution or prior cleanup. Each test should own its setup and teardown.
- **External services.** Tests that call real network endpoints and fail when the network is slow or the service is down. These are not unit tests; they're integration tests that should be isolated or run in a separate suite.

The rule is binary: fix it or delete it. A disabled flaky test is a broken test that doesn't warn you it's broken. "We'll fix it later" is the same as "we won't fix it."

> [!warning] A team that tolerates flaky tests has implicitly decided that their CI signal is advisory, not mandatory. That decision has a cost every time a flaky test masks a real failure.

@feynman

A flaky test in a CI pipeline is like a smoke detector with a dead battery — it gives you the feeling of safety without the actual protection.

@card
id: ttp-ch03-c005
order: 5
title: Testing the Right Things
teaser: 90% coverage with assertions that only check happy paths is not 90% of your reliability — it's close to 0%, because production failures live in the paths you didn't test

@explanation

Code coverage measures which lines executed, not whether the assertions were meaningful. A test that calls every function but only asserts on the sunny-day output creates a high coverage number with low actual reliability.

The surfaces that are routinely under-tested:

- **Error paths.** What happens when the database is unavailable? When the input is malformed? When the token is expired? These paths are often not tested because they're harder to trigger, but they're the ones that produce production incidents.
- **Edge cases.** Off-by-one errors at boundaries (0 items, 1 item, max items), empty input, nil/null, zero values, the first and last element. Most logic bugs live at edges.
- **Concurrent access.** Race conditions between reads and writes are nearly impossible to catch without tests designed specifically for concurrent execution. They appear only under load in production.

The question to ask about any test: "If the behavior I'm asserting changed in a bad way, would this test fail?" If the answer is no, the test is not providing coverage in any meaningful sense.

High coverage with weak assertions is specifically dangerous because it blocks the feeling of urgency to improve test quality — the metrics look fine. A team with 80% coverage and strong assertions about error paths is more reliable than one with 95% coverage and tests that only check that functions return non-nil values.

> [!tip] After writing a test, ask: what would have to change in the implementation to make this test pass while the feature is still broken? If the answer is "nothing much," the test is too weak.

@feynman

High coverage with weak assertions is like logging every request but only recording the HTTP status — the volume looks reassuring, but you'd never catch a bug from the data.

@card
id: ttp-ch03-c006
order: 6
title: Mocking and Test Doubles
teaser: Fakes, stubs, mocks, and spies serve different purposes — choosing the wrong one for the job either makes the test too brittle or lets integration bugs through

@explanation

Test doubles are objects that stand in for real dependencies during a test. Using the right type for the job is not pedantry — it affects whether the test is fragile and what bugs it can catch.

- **Stub:** Returns fixed values. Use when you want to control what a dependency returns without caring what it received. A stub `userRepository` that always returns the same user.
- **Fake:** A simplified working implementation. A `FakeDatabase` that stores values in memory instead of on disk. Cheaper than the real dependency, but it actually works. Use when you need realistic behavior at low cost.
- **Mock:** Verifies interactions — that a method was called, with which arguments, how many times. Use sparingly: mocks test implementation details, not behavior, so they break when you refactor even if behavior is unchanged.
- **Spy:** Like a mock, but wraps the real object rather than replacing it. Lets you assert on calls while still executing real logic.

The danger of over-mocking: a test that mocks every dependency can pass even when the real integration is broken. You've tested that your code calls the interface correctly, not that the interface does what you expect.

The guiding principle is "mock only what you own." Don't mock third-party libraries — write a thin adapter you own, and mock that. Don't mock language primitives. Don't mock things that are fast and deterministic in-process.

@feynman

Over-mocked tests are like testing a circuit with all the components replaced by simulated ones — the simulation passes, but you don't know if the real parts work together.

@card
id: ttp-ch03-c007
order: 7
title: Integration Tests vs Contract Tests
teaser: Integration tests verify that two systems work together; contract tests verify that they agree on the interface — and the latter can run in milliseconds without standing up either system

@explanation

Integration tests are valuable but expensive. To test that your service correctly calls a payment API, you either stand up a real test environment or use a sandbox. Either way, the test is slow, dependent on environment stability, and breaks when the external service has an outage.

Contract testing solves this differently. Instead of testing the full interaction, you define the contract — the agreed interface between producer and consumer — and verify each side against that contract independently.

**Consumer-driven contract testing (Pact)** works like this:
1. The consumer writes tests that describe what requests it will make and what response shape it requires.
2. Pact records these as a "pact file" (the contract).
3. The provider runs its own tests against the pact file, verifying that it can satisfy the consumer's requirements.

Each side tests independently. No shared environment needed. Tests run in milliseconds.

Where integration tests still win: when you need to verify the full runtime behavior end-to-end, not just the interface agreement. Contract tests verify that the producer *could* satisfy the consumer; integration tests verify that it *does* under real conditions.

In practice: use contract tests to decouple teams and get fast feedback on interface changes; use integration tests to verify real behavior at critical seams. Don't use integration tests as a substitute for contract tests just because the former are more familiar.

> [!info] Contract tests are the better tool for catching breaking API changes early — they fail the moment a producer changes a field the consumer depends on, not when a full integration suite runs.

@feynman

Contract tests are like agreeing on a function signature in a type-checked language before either side writes the implementation — both sides know if they've violated the agreement without needing to run together.

@card
id: ttp-ch03-c008
order: 8
title: Fail Fast
teaser: A bug caught at compile time costs minutes; the same bug caught in production costs hours and may cost users — fail fast is the principle of making errors loud, early, and close to their source

@explanation

The fail-fast principle: detect errors as early as possible and surface them loudly, rather than allowing the system to continue running in a degraded or undefined state.

The detection hierarchy, from cheapest to most expensive:

- **Compile time:** The type checker rejects invalid programs before any code runs. A function that requires a non-optional but receives an optional fails here. Cost: seconds.
- **Test time:** A failing test surfaces a bug before it ships. Cost: the test suite run time, measured in minutes.
- **Runtime (assertion/precondition):** A `precondition` or `assert` that crashes the process immediately when an invariant is violated. Noisy, but at least it fails at the callsite rather than silently propagating corrupt state.
- **Production:** The bug ships. Real users are affected. The failure may be silent or intermittent. Debugging requires reproducing a production state. Cost: hours to days, plus user impact.

Precondition checks and assertion guards operationalize fail-fast in code. Instead of silently producing a wrong result when a function receives invalid input, you crash loudly at the point where the invariant was violated. This makes the callsite visible and the bug easy to locate.

The alternative — defensive code that silently handles invalid state and keeps running — produces failures far from their source. By the time something visibly breaks, the original violation is buried under layers of subsequent operations.

> [!info] Fail fast is not about crashing in production — it's about ensuring that invalid states are impossible to silently propagate. Move the assertion as close to the callsite as possible.

@feynman

Failing fast is like throwing an exception at the exact line that receives bad input, rather than returning a sentinel value that corrupts five layers of state before anything breaks visibly.

@card
id: ttp-ch03-c009
order: 9
title: Regression Tests
teaser: A bug that isn't covered by a test is a promise to your users that you will ship that bug again — regression tests are the record of what was broken and proof that it's fixed

@explanation

A regression is a bug that recurs. The scenario is common: a bug is found, fixed, and closed — then surfaces again three months later because someone refactored the code path without knowing the original failure existed.

The practice:

1. A bug is reported or discovered.
2. **Before** touching the code, write a test that reproduces the failure. The test should fail on the current (buggy) code.
3. Fix the bug. The test now passes.
4. Commit both the fix and the test together.

This sequence is not optional overhead — it's the only reliable way to ensure the fix is correct and to prevent the bug from returning. Without the failing test, "fixed" means "doesn't reproduce in the five minutes I spent checking." With the test, it means something verifiable.

The regression test is also the specification of what was wrong. Six months from now, someone reading the test can understand:
- What the erroneous input or state was
- What the incorrect behavior was
- What the correct behavior should be

A team that ships bug fixes without regression tests will see the same bugs recur. The correlation is not coincidental — the same structural conditions that produced the bug the first time will produce it again if the fix isn't validated by something that runs continuously.

> [!tip] If you find yourself writing "fix: prevent X from happening again" in a commit message without a corresponding test, the fix is incomplete.

@feynman

A bug fix without a regression test is like patching a memory leak without adding a leak detector — it might hold for now, but nothing will catch it when it comes back.

@card
id: ttp-ch03-c010
order: 10
title: Tests Are Part of the Feature
teaser: Shipping code without tests is not "moving fast" — it's shipping incomplete work that transfers the maintenance cost onto every engineer who touches that code after you

@explanation

The framing "we'll add tests later" is nearly always wrong, for two structural reasons. First, later never comes — there is always something more urgent, and tests for shipped code don't get written. Second, code written without tests is often structured in ways that make it hard to test retroactively. The dependencies are entangled, the logic is buried in views, and the edge cases were never specified precisely enough to write assertions against them.

The definition of done includes tests. This is not a team culture aspiration — it's an engineering constraint. Code without tests has an unknown correctness property. It's in a superposition of working and broken until something exercises it, usually in production.

The social contract on a team that takes reliability seriously:

- A PR that adds logic without tests is not ready for review.
- A review that passes a PR without tests is accepting incomplete work.
- "It's a small change" is not an exemption — bugs live in small changes.

The team that treats tests as optional accumulates what you might call a test-shaped hole in their reliability: a growing region of the codebase where the team has no signal about correctness and can't refactor safely. This is not free — it compounds. Each new change in that region adds risk, because there's no harness to catch regressions.

The cost of adding tests to a feature is lowest when the feature is being written. It scales up sharply after the code is shipped and the mental model is cold.

> [!warning] "We'll add tests later" has the same expected value as "we won't add tests." Budget for testing at the same time as the feature — it is part of the feature.

@feynman

Shipping without tests is like deploying without monitoring — you'll only find out something is wrong when a user tells you, and by then the damage is done.
