@chapter
id: est-ch02-specification-based-testing
order: 2
title: Specification-Based Testing
summary: Specification-based testing — equivalence partitioning, boundary value analysis, decision tables, state-transition testing — is the discipline of designing tests from requirements rather than from code, and it's what separates "I tested the happy path" from "I covered the input space".

@card
id: est-ch02-c001
order: 1
title: Design Tests from Spec, Not Code
teaser: Black-box testing treats the system as an opaque box and derives tests from what it's supposed to do — not from how it does it — which is the only way to catch requirements-level gaps before writing a single line of implementation.

@explanation

The distinction between black-box and white-box testing is not about access to source code — it's about what drives your test design.

**Black-box (specification-based) testing** derives tests from the specification: inputs, outputs, and the rules that connect them. You don't look at the implementation. The goal is to verify that the system does what it's supposed to do across the full range of inputs the spec describes.

**White-box (structural) testing** derives tests from the code: branches, paths, conditions. It answers "did I execute every line?" not "did I handle every meaningful input?"

Why the distinction matters:

- A test suite built entirely from the code can achieve 100% branch coverage while completely missing a behavior the spec requires — because if the behavior isn't implemented, there's no branch to cover.
- Specification-based tests find requirements gaps. Structural tests find implementation gaps. You need both, but specification-based testing comes first: you can't write meaningful structural tests for something you haven't specified.
- When requirements change, specification-based tests break because the contract changed. When you refactor, structural tests break because the paths changed. These are different signals and you want both.

The practical workflow Aniche recommends:

1. Read the spec thoroughly before opening a code editor.
2. Identify all meaningful input categories.
3. Write tests for each category.
4. Only then look at the code to see if the implementation suggests additional edge cases you missed.

> [!tip] "Test what it should do, not what it does" is the core principle. If your tests pass because you read the source to find inputs that make it pass, you're validating the implementation, not the specification.

@feynman

Black-box testing is like testing a vending machine by putting in every combination of coins and button presses to see what comes out — you don't open the machine to trace the wiring; you verify the contract from the outside.

@card
id: est-ch02-c002
order: 2
title: Equivalence Partitioning
teaser: Instead of testing every possible input — an impossible task — equivalence partitioning groups inputs into classes where the system should behave identically, then tests one representative from each class.

@explanation

The fundamental problem with exhaustive testing is that input spaces are effectively infinite. A function that accepts a string has trillions of valid inputs. Equivalence partitioning is the practical answer: if two inputs cause the system to behave in the same way, testing one of them is sufficient.

**A partition** is a set of inputs where the system's behavior is expected to be equivalent. If a bug exists for one input in the partition, it should manifest for all inputs in that partition — and if it doesn't, your partition was drawn incorrectly.

Example: a function `calculateShipping(weight: number)` with these rules:
- Under 1 kg: flat $3
- 1–10 kg: $3 + $1 per kg
- Over 10 kg: $15 + $0.50 per kg over 10

The partitions are:
- Negative weight (invalid input)
- Zero weight (boundary — invalid or edge of valid, depending on spec)
- 0.001 to 0.999 (valid, first tier)
- 1.0 to 10.0 (valid, second tier)
- 10.001 and above (valid, third tier)

One test per partition is the discipline. Testing `weight = 5` and `weight = 7` and `weight = 8` all fall into the same partition — that redundancy adds no information.

Partitions must be:
- **Complete** — every possible input belongs to exactly one partition.
- **Disjoint** — no input belongs to two partitions simultaneously.

The hardest part is identifying partitions for invalid inputs. Most developers test the happy path and skip the invalid partitions entirely. The spec defines what should happen for bad inputs (throw an exception, return an error code, silently ignore) and those behaviors need testing too.

> [!info] A common mistake is defining partitions too narrowly — essentially listing individual test cases rather than classes of behavior. If you can't articulate why two inputs should behave differently, they're in the same partition.

@feynman

Equivalence partitioning is like a bouncer who checks ID: once you've verified that the rule "must be 21 or older" works correctly for one 19-year-old and one 25-year-old, testing it with fifty 19-year-olds and fifty 25-year-olds tells you nothing new.

@card
id: est-ch02-c003
order: 3
title: Boundary Value Analysis
teaser: Bugs cluster at the edges of partitions — the off-by-one, the wrong comparison operator, the fence-post error — so boundary value analysis deliberately targets the values at and around every partition boundary.

@explanation

Equivalence partitioning tells you which classes to test. Boundary value analysis tells you *which values within and around those classes* to choose. The empirical observation — backed by decades of defect data — is that errors concentrate at boundaries: where one partition ends and another begins.

For a boundary between two partitions, the standard points to test are:

- **On-point** — the exact value at the boundary itself.
- **Off-point** — one step outside the boundary (the first value in the adjacent partition).
- **In-point** — a representative value well inside the valid partition.

For the shipping example with the 1 kg boundary:
- `weight = 0.999` (in-point for the under-1-kg partition)
- `weight = 1.0` (on-point — which tier does this belong to?)
- `weight = 1.001` (off-point — confirmed in the second tier)

The `= ` vs `> ` vs `>=` mistake is the canonical boundary bug. A developer writes:

```python
def get_tier(weight: float) -> str:
    if weight < 1:
        return "tier_1"
    elif weight <= 10:   # intended: < 10, should exclude 10
        return "tier_2"
    else:
        return "tier_3"
```

Equivalence partitioning with `weight = 5` catches nothing. Boundary value analysis with `weight = 10.0` catches the off-by-one immediately.

For continuous numeric inputs, the step size for "off-point" depends on the data type. For integers, off-by-one is `value ± 1`. For floats, it's the smallest distinguishable increment that makes business sense (often one unit of the least significant digit in the spec).

> [!warning] Every boundary in every partition deserves its own on-point and off-point tests. A spec with five numeric ranges has at least eight boundary values worth testing explicitly.

@feynman

Boundary value analysis is why bridge engineers test the bridge at exactly its rated load limit and slightly over — not just at half capacity — because structural failures don't happen in the middle of the safe range, they happen at the edge.

@card
id: est-ch02-c004
order: 4
title: Decision Tables
teaser: When behavior depends on combinations of conditions, decision tables enumerate every meaningful combination systematically — catching the case your if-else chain forgot to handle.

@explanation

Some behaviors can't be reduced to independent input partitions. When the output depends on multiple conditions simultaneously, you need a way to reason about combinations. Decision tables are the tool.

A decision table has:
- **Conditions** — the inputs or predicates that affect behavior (rows in the top half).
- **Actions** — the expected outputs or behaviors (rows in the bottom half).
- **Rules** — columns, where each column specifies one combination of condition values and the resulting action.

Example: a feature gate that controls whether a user sees a promotional banner:

Conditions:
- User is a new account (joined within 30 days): Y / N
- User has made at least one purchase: Y / N
- Current date is within a promotional period: Y / N

That gives 2³ = 8 possible combinations. Written out:

- New + no purchase + promo period → show banner
- New + no purchase + no promo → show banner (new users always get it)
- New + has purchase + promo → show banner
- New + has purchase + no promo → hide banner (purchased, no promo reason)
- Not new + no purchase + promo → show banner
- Not new + no purchase + no promo → hide banner
- Not new + has purchase + promo → show banner
- Not new + has purchase + no promo → hide banner

The table forces you to specify behavior for every combination. The act of filling it in frequently reveals that the spec is ambiguous or missing cases — the "new account with a purchase during a promo period" column that nobody thought about.

Decision tables work best when:
- The number of conditions is small (2–5). Beyond that, combinatorial testing tools are more practical.
- Business rules are complex and condition-dependent.
- The spec authors are domain experts who can validate the table directly.

> [!tip] If building the decision table surfaces a cell where you don't know what the expected behavior should be, that's a requirements gap — find out before writing a single test.

@feynman

A decision table is like a flowchart compressed into a spreadsheet: instead of tracing paths through branches one at a time, you list every possible combination of conditions in columns and read off what should happen for each.

@card
id: est-ch02-c005
order: 5
title: State-Transition Testing
teaser: When the system under test has internal states that affect how it responds to inputs, testing individual inputs in isolation is insufficient — you need to cover the state machine's edges, not just its nodes.

@explanation

Some systems behave differently in response to the same input depending on their current state. A shopping cart, an authentication flow, a file upload lifecycle, a TCP connection — these all have states, and the expected behavior is a function of both the input and the current state.

State-transition testing works by:
1. Identifying all states the system can be in.
2. Identifying all valid transitions (input → new state + output).
3. Identifying all invalid transitions (inputs that should be rejected in a given state).
4. Writing tests that traverse the state machine, checking both transitions and rejection behavior.

Example: a simple order lifecycle:

```
PENDING → (confirm) → CONFIRMED
CONFIRMED → (ship) → SHIPPED
SHIPPED → (deliver) → DELIVERED
CONFIRMED → (cancel) → CANCELLED
PENDING → (cancel) → CANCELLED
```

Tests to write:
- Valid path: `PENDING → CONFIRMED → SHIPPED → DELIVERED`
- Valid cancellation from `PENDING`
- Valid cancellation from `CONFIRMED`
- Invalid: attempt to cancel a `SHIPPED` order (should fail or throw)
- Invalid: attempt to deliver a `PENDING` order (skip states)
- Invalid: attempt to ship a `CANCELLED` order

The invalid transitions are the ones developers most often forget to test. Business logic that prevents invalid state transitions is real business logic — it needs test coverage.

Coverage criteria for state machines:
- **State coverage** — every state is visited at least once.
- **Transition coverage** — every valid transition is exercised at least once.
- **Transition-pair coverage** — every pair of consecutive transitions is exercised (stronger, catches bugs in sequences).

> [!info] For complex workflows, draw the state diagram explicitly before writing tests. The act of drawing it often reveals missing states or unhandled transitions that the implementation silently ignores.

@feynman

State-transition testing is like verifying a traffic light system: you don't just check that green means go — you check every transition, including what happens if someone tries to skip from red directly to green without going through yellow.

@card
id: est-ch02-c006
order: 6
title: Domain Testing — Combining Partitions Across Inputs
teaser: When a function has multiple independent input parameters, the number of partition combinations grows multiplicatively — domain testing is the discipline of choosing which combinations actually need to be tested.

@explanation

Equivalence partitioning handles single inputs cleanly. Reality is messier: most functions take multiple parameters, and each parameter has its own partitions. The question is whether you need to test every combination of partitions across all parameters, or whether you can get away with testing them independently.

Consider a function `applyDiscount(price: number, userType: string, couponCode: string | null)`:

- `price` has partitions: negative, zero, valid positive, unreasonably large.
- `userType` has partitions: "standard", "premium", "employee", invalid string.
- `couponCode` has partitions: null (no coupon), valid coupon, expired coupon, invalid format.

Testing every combination: 4 × 4 × 4 = 64 tests. Many of those combinations add no value — the behavior for an invalid `userType` with a valid coupon is the same as with an expired coupon.

Domain testing provides a principled approach:

- **Test each partition for each variable at least once** (this is the minimum — catches single-variable bugs).
- **For variables that interact**, test the combinations of their boundary values explicitly.
- **For independent variables**, the "most interesting value" strategy works: pick one interesting value from each variable and vary one at a time while holding others at representative values.

The honest tradeoff: domain testing requires judgment about which variables interact. Getting this wrong means missing interaction bugs. The interaction between `price` and `couponCode` is probably significant (a $5 coupon on a $3 item needs a rule). The interaction between `userType` and `couponCode` may also be significant (employees can't stack coupons). These interactions need explicit combination tests; truly independent variables don't.

> [!warning] There is no mechanical rule that tells you which variables interact — that knowledge comes from reading the spec carefully and asking domain experts. "Test them independently unless the spec says they interact" is the default, not the guarantee.

@feynman

Domain testing is like tasting a recipe: you don't try every possible combination of all ingredients in all proportions — you taste the finished dish, then adjust one ingredient at a time to find the edges, focusing extra attention on ingredients whose flavors are known to clash or amplify each other.

@card
id: est-ch02-c007
order: 7
title: Pairwise and Combinatorial Testing
teaser: When the input space explodes beyond what domain testing can manually tame, combinatorial testing tools like ACTS and AllPairs generate the smallest test set that exercises every pair (or t-tuple) of parameter values at least once.

@explanation

The combinatorial explosion problem: a system with 10 boolean parameters has 2¹⁰ = 1024 possible combinations. With 10 parameters that each take 5 values: 5¹⁰ = ~10 million. You cannot test all of them.

**Pairwise testing** (a specific case of combinatorial testing) is based on the empirical observation that most bugs are triggered by interactions between two parameters, not ten. If you guarantee that every pair of parameter values appears in at least one test case, you catch a large fraction of real-world bugs with a dramatically smaller test set.

Tools that generate pairwise test suites:
- **ACTS** (Automated Combinatorial Testing for Software) — from NIST, free, handles t-way covering arrays for any t.
- **AllPairs** — simpler tool, widely available.
- **Pict** — Microsoft's pairwise tool, handles constraints (e.g., "if A=1 then B cannot be X").

Example: 4 parameters with 3 values each. Full factorial: 81 tests. Pairwise covering array: typically 9–12 tests.

The tradeoff is honest:
- Pairwise testing guarantees coverage of all 2-way interactions. It does *not* guarantee coverage of 3-way or higher-order interactions.
- Bugs triggered only by a specific 3-way combination will be missed by pairwise testing.
- 3-way (or t-way for larger t) covering arrays can be generated, but the test count grows with t.
- In practice, pairwise is a good default; 3-way is justified when the domain is known to have complex multi-parameter interactions (hardware compatibility testing is a classic example).

```java
// Example: testing a UI rendering function with combinatorial inputs
// Parameters: theme (light/dark/high-contrast), fontSize (small/medium/large),
//             locale (en/fr/ja), displayMode (compact/roomy)
// Full factorial: 3×3×3×2 = 54 tests
// Pairwise covering array: ~12 tests, generated by ACTS
```

> [!info] Pairwise testing is not a substitute for equivalence partitioning and boundary value analysis — it's a layer on top for multi-parameter systems where manual combination selection becomes infeasible.

@feynman

Pairwise testing is like quality-checking a factory's outputs by ensuring every machine has been paired with every other machine at least once in your sample — you can't test every possible assembly sequence, but if every two-machine combination is covered, most assembly-interaction defects will surface.

@card
id: est-ch02-c008
order: 8
title: Use Case Testing
teaser: Use case testing validates complete end-to-end scenarios the way a real user experiences them — bridging the gap between unit-level input coverage and the system-level behavior the spec actually promises.

@explanation

Equivalence partitioning and boundary value analysis are excellent at testing individual functions. They don't naturally test sequences of operations, multi-step workflows, or the interaction between components as a user navigates a feature.

Use case testing starts with the user-facing scenarios in the spec — "user registers an account," "user places an order with a coupon," "user attempts checkout with an expired payment method" — and writes tests that exercise those flows end-to-end.

The structure of a use case test:

- **Preconditions** — the system state before the scenario starts.
- **Main success scenario** — the happy path steps.
- **Alternative flows** — variations and branches the spec identifies.
- **Exception flows** — what happens when steps fail.

```typescript
// Use case: "User checks out with a valid coupon"
describe("checkout with coupon", () => {
  it("applies discount and confirms order", async () => {
    // Precondition: cart with 2 items, valid coupon SAVE10 in system
    const cart = await buildCart([item1, item2]);
    const result = await checkout(cart, { coupon: "SAVE10", payment: validCard });

    expect(result.status).toBe("confirmed");
    expect(result.totalCharged).toBe(cart.subtotal * 0.9);
    expect(result.couponApplied).toBe("SAVE10");
  });

  it("rejects checkout when coupon is expired", async () => {
    const cart = await buildCart([item1]);
    await expect(
      checkout(cart, { coupon: "OLDCODE", payment: validCard })
    ).rejects.toThrow("Coupon expired");
  });
});
```

Use case tests are particularly valuable for:
- Scenarios that cross component or service boundaries.
- Multi-step workflows where state accumulates between steps.
- Acceptance criteria that can only be verified end-to-end.

The tradeoff: use case tests are slower, harder to isolate when they fail, and more expensive to maintain than unit tests. They should complement, not replace, lower-level specification-based tests.

> [!tip] Derive use case tests directly from the acceptance criteria in the spec. If a scenario is in the spec and has no corresponding test, that scenario is untested by definition.

@feynman

Use case testing is like a dress rehearsal: you don't just verify that each actor knows their lines individually — you run the whole scene in sequence to find the moments where the transitions between actors break down.

@card
id: est-ch02-c009
order: 9
title: The Negative Cases Discipline
teaser: Negative tests — verifying that the system correctly rejects invalid inputs and fails safely — are the easiest part of specification-based testing to skip and among the most valuable to have when something goes wrong in production.

@explanation

Every partition of invalid inputs in your equivalence analysis implies a negative test: a test that verifies the system behaves correctly when given something it should not accept. The discipline is actually writing these tests, not just the valid-input cases.

Negative cases cover three categories:

**Invalid inputs the spec explicitly addresses:**
- Null or missing required parameters.
- Out-of-range numeric values.
- Malformed strings (wrong format, too long, wrong encoding).
- Unauthorized operations (calling an API endpoint without required permissions).

**Invalid state transitions** (from state-transition testing):
- Attempting to cancel an already-delivered order.
- Calling a method that requires initialization before `init()` has been called.

**Invalid combinations of valid inputs:**
- A start date that is after the end date.
- A quantity of zero when the spec says "must be at least 1."

```python
# Easy to write, easy to skip:
def test_negative_price_raises():
    with pytest.raises(ValueError, match="Price must be positive"):
        calculate_shipping(price=-10.0, weight=2.0)

def test_empty_username_raises():
    with pytest.raises(ValueError, match="Username cannot be empty"):
        create_user(username="", email="test@example.com")
```

The failure mode in production: a system that doesn't explicitly reject invalid inputs either silently corrupts state (stores a negative balance), propagates the error further from the source (the error surfaces in an unrelated component three calls later), or behaves in undefined ways that differ across environments.

Negative tests also document the contract: they make it explicit that the function promises to raise a `ValueError` for negative prices, not just return `-1` or `None` silently.

> [!warning] The most dangerous negative cases are the ones where the system appears to succeed but produces a subtly wrong result — no exception thrown, no error returned, just incorrect behavior. These only show up if you assert on the output, not just on the absence of a crash.

@feynman

Negative testing is the equivalent of checking that a locked door actually resists being opened — not just that the lock looks engaged; a door that appears locked but opens when pushed fails in exactly the scenario where the lock was needed.

@card
id: est-ch02-c010
order: 10
title: Spec-Based vs Example-Based Testing — When Each Fits
teaser: Specification-based testing derives test cases systematically from input classes; example-based testing picks concrete, illustrative cases from experience — both have their place, and conflating them leads to either over-testing or under-coverage.

@explanation

**Specification-based testing** (the subject of this chapter) is systematic: you analyze the spec, identify partitions, identify boundaries, identify valid and invalid classes, and derive a test for each. The process is reproducible — two engineers working from the same spec should arrive at similar test cases.

**Example-based testing** is intuition-driven: you pick concrete scenarios from experience, from bugs you've seen before, from "this kind of input breaks things in my experience." It's what most developers do naturally, and it's valuable — experienced engineers have useful pattern recognition about where systems tend to fail.

The tradeoffs:

- Spec-based testing scales to unfamiliar domains. You don't need to have seen a bug before to derive the test for the boundary between tier 1 and tier 2 of a shipping calculator.
- Example-based testing captures domain knowledge that the spec may not explicitly state. "Strings with embedded null bytes break this parser" is not in most specs, but an experienced engineer adds that test.
- Spec-based testing is auditable: you can trace each test back to a requirement. Example-based testing produces tests that can feel arbitrary to reviewers who lack the context.

The practical synthesis: use specification-based techniques as the primary method for deriving your test suite. Add example-based tests on top — regression tests for bugs that have occurred, tests for known failure patterns in your domain, tests for inputs the spec doesn't cover but which you know the system will encounter.

> [!info] Property-based testing (e.g., Hypothesis in Python, fast-check in TypeScript) is a form of spec-based testing automated: you define the invariant and the tool generates examples. It finds boundary violations that neither manual method reliably catches.

@feynman

Spec-based testing is a map drawn from the terrain's contours; example-based testing is notes scrawled by someone who has hiked that trail before — you want both, because the map tells you where the cliffs are and the notes tell you where the trail washes out every spring.

@card
id: est-ch02-c011
order: 11
title: Spec Inputs That Change Behavior Silently
teaser: Null, empty string, zero, extreme numeric values, Unicode edge cases, and timezone-sensitive timestamps are a class of inputs that consistently produce unexpected behavior — the spec often leaves them underspecified, which means they need explicit attention.

@explanation

A recurring failure pattern in specification-based testing: the spec describes the happy path with clear examples and leaves a class of real-world inputs either unspecified or ambiguously specified. These inputs don't obviously belong to "invalid" partitions — they're technically valid but carry semantics that the implementation frequently handles incorrectly.

The canonical list of inputs to always consider:

**Null / absent values:**
- `null`, `undefined`, empty string `""`, missing JSON key — these are four different things with different semantics in most systems, and developers conflate them constantly.

**Numeric extremes:**
- `0`, `-0`, `Integer.MAX_VALUE`, `Double.MAX_VALUE`, `Infinity`, `NaN` — IEEE 754 has many surprises.

**Empty collections:**
- An empty list where the spec says "process each item" — does the function return an empty result, or throw, or return null?

**Unicode and encoding:**
- A username containing `\0` (null byte), emoji (`\u{1F600}`), right-to-left text, or characters that normalize differently in NFC vs NFD.
- String length: does "length" mean bytes, code units, or code points? These differ for multi-byte characters.

**Timezone-sensitive timestamps:**
- "Today" at 23:59 in UTC is "tomorrow" in UTC+1. Functions that compute "days since X" or "is this date in the future?" are silently wrong for specific timezone inputs.

```typescript
// A test suite that looks complete but misses critical inputs:
describe("formatUsername", () => {
  it("handles normal input", () => expect(formatUsername("alice")).toBe("Alice"));
  it("handles empty string", () => expect(formatUsername("")).toBe(""));   // or throw?
  it("handles whitespace-only", () => expect(formatUsername("   ")).toBe(""));
  it("handles emoji", () => expect(formatUsername("alice🚀")).toBe("Alice🚀"));
  it("handles null byte", () => expect(() => formatUsername("ali\0ce")).toThrow());
});
```

The habit to build: for any function that accepts strings, numbers, or timestamps, run through this list mentally before considering the test suite complete.

> [!warning] "The spec didn't say what to do with null" is not a defense — it's a gap. When the spec is silent, the correct response is to ask, decide, document the decision, and test it.

@feynman

These edge inputs are like stress-testing a bridge with unusual loads the spec never mentioned — an empty truck, a truck with an asymmetric load, a truck in a crosswind — because the real world sends inputs the spec authors never thought to describe.

@card
id: est-ch02-c012
order: 12
title: Test Coverage of the Spec
teaser: Code coverage measures how much of the implementation a test suite exercises; spec coverage measures how much of the requirements a test suite exercises — the second is harder to quantify but more important to reason about.

@explanation

Line coverage and branch coverage are objectively measurable: a tool instruments the code and reports a percentage. Spec coverage has no equivalent automated measurement, but the concept is just as real and more directly connected to quality.

**Spec coverage asks:** for every behavior described in the requirements, is there at least one test that verifies that behavior? And — harder — for every partition of inputs, boundary value, and state transition implied by the spec, is there a test that exercises that case?

Why it's harder to quantify:

- The spec is natural language (or user stories, or acceptance criteria), not code. There's no static analysis tool that parses "users with premium accounts get 10% off" and emits a coverage report.
- The spec may be incomplete, inconsistent, or ambiguous. "Complete spec coverage" of an ambiguous spec is not achievable.
- Different engineers will decompose the same spec into different numbers of test cases. There's no canonical count to measure against.

What you can do in practice:

- **Trace tests to requirements.** A comment or tag like `// covers: req-47, pricing-rule-3` makes the mapping explicit and auditable.
- **Use the techniques in this chapter as a checklist.** For each input, did you identify partitions? Did you add boundary tests? For multi-input functions, did you consider interactions?
- **Review test intent, not just test count.** A file with 50 tests that all use the same input partition has worse spec coverage than a file with 12 tests that each target a distinct partition.

The analogy to mutation testing: mutation testing is a proxy for spec coverage — if you inject a bug by changing `>=` to `>` and no test fails, your suite has a gap at that boundary regardless of what your line coverage number says.

> [!info] The practical target is not "100% spec coverage" — it's "no partition in the spec is completely untested." Prioritize coverage of partitions over coverage of lines.

@feynman

Spec coverage is like checking that a contract has been fulfilled: you don't just count the paragraphs you read — you go through each clause and ask whether there's evidence in the test suite that this specific commitment was actually verified.
