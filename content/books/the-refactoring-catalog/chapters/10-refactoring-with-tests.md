@chapter
id: rfc-ch10-refactoring-with-tests
order: 10
title: Refactoring with Tests
summary: A test suite is the safety net that makes refactoring an engineering practice rather than a wish — and when the safety net is missing, characterization tests, golden masters, and seam-based isolation are how you build one before you touch the code.

@card
id: rfc-ch10-c001
order: 1
title: Tests Are the Safety Net
teaser: Without a test suite, refactoring is not an engineering activity — it is an act of hope, and hope is not a strategy.

@explanation

Martin Fowler defines refactoring as a behavior-preserving transformation. That word — *preserving* — is load-bearing. You cannot know whether behavior was preserved without something to compare against. That something is your test suite.

The rule is simple: no tests, no refactoring. The corollary is equally simple: with good tests, refactoring stops being scary and becomes routine.

What a test suite gives you:

- **A fast feedback loop.** You run the suite after every small step. If something breaks, the breakage is contained to the last change — you revert one step, not two hours of work.
- **Reviewability.** A PR that changes internal structure but keeps all tests green is reviewable. A PR that says "I cleaned things up, trust me" is not.
- **Permission to move fast.** Counter-intuitively, the team with the strong test suite ships changes faster, because individuals stop second-guessing every touch.

The rule has deliberate exceptions. Pure renames in a statically typed language (Swift, Java, Kotlin, TypeScript) performed by a reliable IDE refactoring tool are generally safe without tests — the compiler verifies the rename for you. Simple inline or extract operations in the same category carry similar low risk. Recognize these for what they are: narrow carve-outs for mechanical transformations, not a license for untested structural change.

> [!warning] "I'll add tests after I refactor" is a trap. You cannot write tests to verify behavior you've already changed. Tests must come before the transformation, not after.

@feynman

Refactoring without tests is like editing a live electrical panel without turning off the breaker — technically possible, but every touch is a gamble rather than a controlled action.

@card
id: rfc-ch10-c002
order: 2
title: What "Covered Enough to Refactor" Means
teaser: Line coverage tells you which code was executed during tests; mutation testing tells you whether those tests would notice if the code were wrong.

@explanation

The 80% line coverage threshold cited across style guides is a floor, not a destination. A test that calls a function without asserting anything contributes to line coverage while providing zero safety. The metric that matters is whether your tests can *detect bugs*.

Coverage types in order of signal quality:

- **Line coverage** — was this line executed? Cheap to measure with tools like JaCoCo (Java/Kotlin), Coverage.py (Python), or Istanbul/c8 (JavaScript/TypeScript). Useful as a sanity check. Easy to game.
- **Branch coverage** — was each branch of every conditional taken in at least one test? Stronger signal, particularly for complex conditionals.
- **Mutation testing** — a tool introduces small bugs (mutants) into your code — flipping `>` to `>=`, deleting a return statement, replacing `&&` with `||` — and checks whether your test suite catches each mutation. A mutation that survives means your tests wouldn't notice that particular bug. Mutation score is the percentage of killed mutants.

A codebase with 90% line coverage and 45% mutation score is not safe to refactor. A codebase with 75% line coverage and 80% mutation score probably is.

For the safety-net purpose, aim for:

- 80%+ branch coverage on the paths you're about to change
- Mutation score above 70% on the same scope — checked with Stryker (JS/TS), PIT (Java/Kotlin), or Mutmut (Python)

> [!info] Running mutation tests on a full codebase is slow — Stryker on a large TypeScript project can take 10–30 minutes. Run mutation testing scoped to the module you're about to refactor, not the whole repo.

@feynman

Line coverage is like checking whether every seat in a theatre was sat in; mutation testing is like checking whether the audience would have noticed if the actor flubbed their lines.

@card
id: rfc-ch10-c003
order: 3
title: Characterization Tests
teaser: Before touching legacy code, write tests that document what the system actually does — not what it should do — so any change you make that alters behavior is immediately visible.

@explanation

Michael Feathers coined the term in *Working Effectively with Legacy Code* (2004). A characterization test is not a correctness test — it does not assert that the code is right. It asserts that the code behaves the way it currently behaves, bugs and all.

The workflow:

1. Call the code under test and capture its current output.
2. Write an assertion that hard-codes that output.
3. Run the test. It passes, because you asserted exactly what the system produces today.
4. Now refactor. If any characterization test breaks, you changed observable behavior — intentionally or not.

```python
# Legacy function with unknown behavior — maybe buggy, but it's in production
def apply_discount(price, customer_type, quantity):
    # ... 80 lines of nested conditionals nobody understands

# Characterization test: capture what it does today, not what it should do
def test_apply_discount_bulk_premium_characterization():
    result = apply_discount(100.0, "premium", 50)
    assert result == 73.5   # whatever it actually returned — we checked manually

def test_apply_discount_standard_single_characterization():
    result = apply_discount(100.0, "standard", 1)
    assert result == 100.0  # no discount applied in this case, apparently
```

The honest cost: characterization tests freeze the current bugs. If `apply_discount` miscalculates premium bulk discounts, your characterization test will pass when you accidentally preserve that miscalculation. Fix the bug and the test breaks — which is the right moment to update the assertion deliberately and document the fix.

> [!tip] Name characterization tests explicitly with `_characterization` or `_legacy` as a suffix so the team knows these tests describe current behavior, not specified behavior.

@feynman

Writing characterization tests is like taking a plaster cast of a broken bone before you set it — you're capturing the exact current state so you can see precisely what changed.

@card
id: rfc-ch10-c004
order: 4
title: The Sprout Method Pattern
teaser: When a function is too tangled to test, you extract the new logic you need to add into a separate, testable method and call it from the original — leaving the legacy code untouched.

@explanation

Also from Michael Feathers' *Working Effectively with Legacy Code*. The Sprout Method pattern addresses the specific problem of adding new behavior to untestable legacy code without making things worse.

The steps:

1. Identify where in the existing method the new logic belongs.
2. Write the new logic as a standalone method (the sprout) with a clear, testable interface.
3. Call the sprout from the original method.
4. Write tests for the sprout in isolation.

```java
// Before: addShippingCost is 200 lines of untestable legacy code
public void processOrder(Order order) {
    // ... 200 lines of untestable legacy code
    // You need to add a tax calculation here
}

// After: sprout the new logic into a testable method
public void processOrder(Order order) {
    // ... same 200 lines, untouched
    order.setTax(calculateTax(order.getSubtotal(), order.getRegion()));
}

// The sprout — fully testable in isolation
BigDecimal calculateTax(BigDecimal subtotal, Region region) {
    return subtotal.multiply(region.getTaxRate());
}
```

What you gain: the new behavior is tested, the legacy code is untouched, and you haven't made the existing mess harder to understand. What you don't gain: the existing method is still untested and still a mess. Sprout Method is a beachhead, not a full refactoring.

> [!info] Sprout Method is explicitly a temporary strategy. The goal is to stop the bleeding — once you have characterization tests on the surrounding code, you can refactor the whole method properly.

@feynman

The Sprout Method is like adding a clean new extension to a building you can't yet renovate — you attach the fresh structure to the old one at a well-defined joint, and the old building's problems don't infect the new wing.

@card
id: rfc-ch10-c005
order: 5
title: The Wrap Method and Wrap Class Patterns
teaser: When you can't modify a method's internals at all — because the risk is too high or the coupling too deep — you wrap it in a new layer that you can test.

@explanation

Also from Feathers' *Working Effectively with Legacy Code*. Where Sprout Method adds new logic inside an existing method, Wrap Method adds new behavior around it — before or after — without touching the body.

**Wrap Method:** Create a new method that calls the original and adds behavior around it. The original remains unchanged.

```typescript
// Original — works in production, nobody wants to touch it
function saveUserRecord(user: User): void {
    // ... complex legacy persistence logic
}

// Wrap Method — adds audit logging around the original
function saveUserRecordWithAudit(user: User): void {
    auditLog.record("save_attempt", user.id);
    saveUserRecord(user);
    auditLog.record("save_complete", user.id);
}
```

**Wrap Class (Decorator pattern):** When the unit of wrapping is a whole class rather than a single method. You create a new class that holds a reference to the original and delegates to it, adding behavior at the boundary.

```typescript
class AuditingUserRepository implements UserRepository {
    constructor(private inner: UserRepository, private log: AuditLog) {}

    save(user: User): void {
        this.log.record("save", user.id);
        this.inner.save(user);
    }

    findById(id: string): User | null {
        return this.inner.findById(id);
    }
}
```

Wrap Class is structurally identical to the Decorator pattern from the Gang of Four. The new class is fully testable with a mock or stub for the inner dependency.

> [!tip] Prefer Wrap Class over Wrap Method when you need to add behavior to multiple methods of the same type — each additional method gets the wrapper for free rather than requiring a separate wrapped version.

@feynman

Wrapping a legacy class is like putting a new control panel in front of an old machine — you interact with the clean new interface, it sends signals to the old machinery behind it, and you never have to open the old machine's casing.

@card
id: rfc-ch10-c006
order: 6
title: Seams
teaser: A seam is any place in a codebase where you can substitute behavior without editing the code that uses it — and finding seams is how you make untestable code testable.

@explanation

Michael Feathers introduced the seam concept in *Working Effectively with Legacy Code*. The core idea: every point where behavior can vary without changing the call site is a seam you can use to inject a test double.

Feathers identifies three types:

- **Object seam** — the most common in object-oriented code. The class accepts an interface or a collaborator through its constructor or a setter. Swap the real dependency for a test double in tests.
- **Link seam** — in compiled languages, substitute a different implementation at link time (or, in JVM terms, swap a JAR on the classpath).
- **Preprocessing seam** — substitute behavior at the preprocessor stage. Less common in modern OO code.

Object seams are what modern dependency injection is built on. Making them explicit is the goal.

```python
# No seam — FX rate is fetched inside the function, untestable
def calculate_total(order):
    rate = requests.get("https://api.fx.example/usd").json()["rate"]
    return sum(item.price for item in order.items) * rate

# With object seam — fx_rate is injected, function is now testable
def calculate_total(order, fx_rate: float):
    return sum(item.price for item in order.items) * fx_rate

# Test — no network call needed
def test_calculate_total():
    order = Order(items=[Item(price=10.0), Item(price=20.0)])
    assert calculate_total(order, fx_rate=1.25) == 37.5
```

Identifying seams before refactoring tells you how much surgery you need to do before the code can even be tested. A class with no seams is a class that must be partially rewritten before it can be safely refactored.

> [!warning] The absence of seams is not an accident — it's usually the accumulated result of tight coupling, global state, and static method calls. Finding seams means asking: "Where does this code reach outside itself?"

@feynman

A seam is like the zipper in a costume — it looks seamless from the outside, but it's the one point where you can open things up and swap what's inside without altering the costume's visible shape.

@card
id: rfc-ch10-c007
order: 7
title: Golden Master and Approval Testing
teaser: When the expected output of a function is too complex to specify as assertions, capture a snapshot of what it produces today and use that snapshot as the oracle.

@explanation

Golden master testing (also called approval testing or snapshot testing) is the technique of capturing the actual output of a system and storing it as the reference. Future test runs compare against that reference. Any difference — any at all — fails the test and requires deliberate approval of the new output.

This is particularly useful when:

- The output is large or structured (HTML, JSON, XML, formatted reports)
- Behavior is so complex that writing individual assertions would take longer than the refactoring itself
- You're wrapping a legacy system that has no existing tests

```java
// JUnit 5 with ApprovalTests library
@Test
void testInvoiceRendering() {
    Invoice invoice = new Invoice(/* ... */);
    String rendered = invoiceRenderer.render(invoice);
    Approvals.verify(rendered);
    // On first run: saves rendered output to a .approved.txt file
    // On subsequent runs: compares to the saved .approved.txt
}
```

Tools:

- **Approvals.NET / ApprovalTests** — Java, C#, Python, Ruby. The canonical approval testing library. First-run approval workflow built in.
- **Touca** — captures function outputs over time, compares runs, surfaces regressions. Better suited for continuous monitoring than one-time characterization.
- **Vitest / Jest snapshot testing** — JavaScript/TypeScript. `expect(output).toMatchSnapshot()` is golden master testing under a different name.

The honest tradeoff: golden masters are brittle. Any legitimate change to output format — a field renamed, whitespace adjusted, a date format changed — breaks the test and demands manual approval. On a frequently changing output, approval tests become friction rather than safety. Reserve them for stable, complex outputs.

> [!warning] Approving a changed snapshot without reading it carefully is the golden master anti-pattern. The entire value of approval tests depends on a human reviewing every diff before clicking approve.

@feynman

A golden master test is like photographing your desk before you reorganize it — if you can't remember how you had things, you can compare against the photo to see exactly what changed.

@card
id: rfc-ch10-c008
order: 8
title: Mutation Testing as the Coverage Signal
teaser: Mutation testing is the only coverage metric that asks the right question — not "was this code run?" but "would your tests notice if this code were wrong?"

@explanation

A mutation testing tool works by generating many slightly broken versions of your source code (mutants), running your test suite against each one, and reporting which mutants survived — meaning no test failed when the code was wrong.

Common mutation operators:

- Replace `>` with `>=` (boundary condition mutations)
- Negate a boolean expression
- Delete a return statement
- Replace `+` with `-` or `*`
- Remove a method call

Tools by ecosystem:

- **Stryker** for JavaScript / TypeScript — `npx stryker run`; runs tests in parallel; HTML report.
- **PIT (Pitest)** for Java / Kotlin — Maven/Gradle plugin; incremental mode for large codebases.
- **Mutmut** for Python — `mutmut run`; integrates with pytest; caches results.
- **Infection** for PHP.

Interpreting results: a mutation score of 80%+ on the files you're about to refactor is a reasonable signal that the tests are meaningful. A score below 50% means roughly half of all detectable logic bugs would go unnoticed by your current suite.

The real cost is time. Stryker on a 10,000-line TypeScript codebase can take 20–40 minutes. Strategies to manage this:

- Run mutation tests only on the module being refactored, not the whole repo
- Use Stryker's `--incremental` flag or PIT's `--sourceDirs` scoping
- Run mutation tests in CI on a nightly schedule, not on every push

> [!info] You don't need a perfect mutation score before refactoring — you need a score high enough for the specific module you're touching. Scope mutation runs tightly to control cost.

@feynman

Mutation testing is like a spell-checker that deliberately introduces typos into your document and then checks whether your proofreader catches each one — rather than just confirming that the proofreader showed up.

@card
id: rfc-ch10-c009
order: 9
title: The "Trust the IDE Refactoring Tool" Trap
teaser: IDE-automated refactorings are reliable enough to justify skipping tests in narrow cases — but they are not infallible, and knowing when to trust them is itself a skill.

@explanation

Modern IDEs — IntelliJ IDEA, VS Code with TypeScript language server, Xcode, ReSharper — perform semantic refactorings that understand the type system rather than performing text substitution. For statically typed languages, a rename refactoring in IntelliJ is not a find-and-replace; it resolves all references through the type graph.

The cases where IDE refactoring tools are safe enough without tests:

- **Rename** (symbol, method, class) in Java, Kotlin, TypeScript, Swift — the compiler will fail the build if any reference was missed.
- **Inline** a trivial function (zero branches, single return value) in a statically typed language.
- **Extract method** on a pure expression with no side effects.

The cases where IDE refactoring tools have failed in practice:

- Renaming across reflection-based code (`Class.forName("MyClass")`, serialization annotations, Spring `@Bean` names). The IDE does not analyze string literals.
- Refactoring code that uses dynamic dispatch or duck typing in dynamically typed languages (Python, Ruby, JavaScript without TypeScript).
- Extract refactorings that silently change the scope of a variable or the order of side effects.
- Cross-language usages — a Swift class name referenced as a string in a plist or an Objective-C bridging header.

The test for whether to trust the tool: "Does the compiler see every usage?" If the answer is no — because of strings, reflection, dynamic dispatch, or external config — do not skip the tests.

> [!tip] After any IDE-driven refactoring, run the full build and test suite before committing. The few seconds this takes catches the rare but real case where the tool got it wrong.

@feynman

Trusting an IDE rename without running tests is like trusting autocorrect with a legal document — it is right almost all of the time, and the one time it is wrong matters more than the thousand times it wasn't.

@card
id: rfc-ch10-c010
order: 10
title: Refactoring Test Code
teaser: Test code is code — the same smells that degrade production code degrade your test suite, and a messy test suite provides less safety than a clean one.

@explanation

Tests that are hard to read are tests that are hard to trust. When a failing test requires 20 minutes to diagnose because the setup is buried in a base class three levels up and the assertion uses a custom matcher that isn't documented, the test is not functioning as a safety net — it's functioning as an obstacle.

Common smells in test code:

- **Mystery guest** — a test depends on external state (a file, a database row, a shared fixture) that is not set up in the test itself. The cause of a failure is invisible.
- **Eager test** — a single test asserts too many things, making the failure message unhelpful.
- **Chatty test** — a test that logs extensively to pass, masking the real assertion.
- **Duplicated setup** — identical `// Arrange` blocks copy-pasted across 20 tests, meaning a single schema change requires 20 edits.
- **Sensitive equality** — asserting full object equality when only one field is relevant to the behavior under test.

The DAMP principle (Descriptive and Meaningful Phrases) over DRY in test code:

- Each test should be readable in isolation — a developer should be able to understand what it tests and why it might fail without reading other files.
- Duplication in test setup is acceptable when it makes each test self-contained. The cost of reading a repeated `buildOrder()` call in every test is lower than the cost of chasing an inherited fixture.
- Extract helpers for repeated logic — but keep them in the same test file, not a distant base class.

Apply the same refactoring discipline to tests: rename, extract, inline, consolidate. Run the suite before and after to confirm behavior is preserved.

> [!tip] The test for a good test: a developer who has never seen the codebase should be able to read the test name, the arrange block, and the assertion and understand precisely what behavior is being verified.

@feynman

Refactoring your tests is like sharpening the knife before you cook — the knife still cuts either way, but a sharp one gives you control and precision, while a dull one makes every cut a gamble.

@card
id: rfc-ch10-c011
order: 11
title: Continuous Testing in the IDE
teaser: Running your test suite manually is a practice; having it run automatically on every save is a tightened feedback loop that changes how you work.

@explanation

The further a test failure is from the change that caused it, the harder it is to reason about. Continuous testing closes that gap to near zero.

What it means in practice:

- **IntelliJ IDEA / Android Studio** — enable "Run tests automatically" (the auto-test toggle in the Run toolbar). Tests re-run after each file save. The green/red status appears in the gutter. Available for JUnit 5 (Java/Kotlin) and pytest (via Python plugin).
- **Vitest** — `npx vitest --watch` runs in watch mode, re-running only affected tests after each file change. Sub-second feedback on typical unit tests.
- **pytest-watch** — `ptw` (pytest-watch) or `pytest-xdist` with the `--looponfail` flag. Re-runs failing tests first after each change.
- **Jest** — `jest --watch` or `jest --watchAll` for the same pattern.

The workflow shift:

1. Make one small transformation (rename, extract, inline).
2. The suite re-runs automatically.
3. Green: proceed. Red: revert and understand.

Each step is 30–90 seconds of work, not 10 minutes. The granularity changes from "refactoring session" to "individual transformation," which is what the strangler-fig approach to legacy code requires.

The constraint: continuous testing only works if the suite is fast. A suite that takes 8 minutes to run cannot run on every save. The test pyramid — many fast unit tests, fewer slow integration tests — is not just a coverage strategy, it's what makes continuous testing viable.

> [!info] Keep your unit test suite under 30 seconds to get real value from continuous testing. If it's slower, identify and isolate the slow tests — they are almost always integration or I/O-dependent tests that belong in a separate slow suite.

@feynman

Continuous testing in the IDE is like turning on spell-check as you type — instead of discovering all the errors at the end when you print the document, you see each one the moment it appears.

@card
id: rfc-ch10-c012
order: 12
title: The "No Tests, No Refactoring" Rule and Its Exceptions
teaser: The rule is a principle, not a commandment — knowing when it applies in full and when deliberate exceptions are warranted is part of using it correctly.

@explanation

The no-tests-no-refactoring rule exists to protect you from a specific failure mode: making structural changes that you believe are behavior-preserving but that silently alter edge cases, error handling, or concurrency behavior. The test suite is the verification mechanism.

The rule applies in full when:

- The change involves moving logic between methods or classes
- The change alters control flow, conditionals, or early returns
- The codebase is dynamically typed or heavily reliant on runtime behavior
- The change is in production-critical paths

The deliberate exceptions — cases where the rule can be relaxed with clear eyes:

- **IDE rename in a statically typed language** — the compiler verifies all references; still run a build + tests after.
- **Reorder imports / auto-format** — no semantic change; nothing further required.
- **Extract a function with no side effects in a statically typed language** — the type checker verifies the signature; run a build after.
- **Add a purely additive new parameter with a default value** — existing call sites are unaffected; still run a build + tests.

The pragmatic test for any exception: "If this change introduced a bug, how would I know?" If the answer is "the compiler would catch it," the exception is likely sound. If the answer is "I wouldn't know without running the system," you're back under the main rule.

The meta-principle: treat the exceptions as a budget. Using one exception on a rename is reasonable. Using five exceptions in sequence on a complex restructuring is how "mostly safe" becomes "shipped a regression."

> [!warning] The exceptions above assume a statically typed language and a trustworthy IDE refactoring tool. In Python, Ruby, or JavaScript without TypeScript, the compiler safety net does not exist — the main rule applies with less room for exception.

@feynman

The no-tests-no-refactoring rule is like the rule that you always tie in before climbing — experienced climbers know the specific conditions where a short unroped move is acceptable, but that knowledge is earned through discipline, not skipped past.
