@chapter
id: est-ch03-structural-testing-and-coverage
order: 3
title: Structural Testing and Code Coverage
summary: Code coverage is the most-cited and most-misunderstood test metric — the difference between line coverage, branch coverage, MC/DC, and mutation coverage is the difference between "I touched the code" and "I actually tested it".

@card
id: est-ch03-c001
order: 1
title: Structural vs Spec-Based Testing
teaser: Spec-based tests ask "does the code do what the requirements say?"; structural tests ask "did the tests actually exercise the code?" — you need both questions answered to have confidence.

@explanation

Spec-based (black-box) testing drives test cases from requirements, contracts, and expected behavior. You don't look at the implementation; you ask: given these inputs, should I get this output? It catches cases where the code doesn't match the specification.

Structural (white-box) testing works from the source code itself. You look at branches, paths, and conditions and ask: are there lines, decisions, or states my spec-based tests never reached? It catches gaps in your test suite — code that exists but is never exercised.

Neither approach dominates the other:

- Spec-based tests can miss dead code and defensive branches that the spec never anticipated.
- Structural tests can achieve 100% line coverage with assertions so weak they prove nothing about correctness.

The effective workflow treats them as complements. Write spec-based tests first — derive them from requirements, boundary values, and equivalence partitions. Then run a coverage tool and use the report not to chase a number, but to discover areas the requirements never drove you to test. Investigate uncovered code, decide whether it needs a test or should be deleted, and act on the finding.

> [!info] Coverage tools are a gap-finder, not a quality score. Their job is to point you at code your spec-based tests missed — not to tell you that your tests are good.

@feynman

Spec-based testing checks that the map matches the territory; structural testing checks that you actually walked every road on the map.

@card
id: est-ch03-c002
order: 2
title: Line Coverage
teaser: Line coverage tells you which source lines were executed during your test suite — the most widely reported metric and the easiest one to satisfy without actually testing anything meaningful.

@explanation

Line coverage (also called statement coverage) is the ratio of executable lines touched during a test run to total executable lines. A tool like JaCoCo for Java, Coverage.py for Python, Istanbul/c8 for JavaScript and TypeScript, or SimpleCov for Ruby instruments the bytecode or source and counts executions per line.

Consider this function:

```python
def discount(price, is_member):
    if is_member:
        return price * 0.9
    return price
```

A single test calling `discount(100, True)` achieves 100% line coverage — every line runs. But the branch where `is_member` is `False` is never tested. If someone introduces a bug on that return path, line coverage won't catch it.

Line coverage is a useful baseline metric because it is cheap to collect and easy to understand. A codebase at 20% line coverage has a serious testing gap. But a codebase at 90% line coverage may have critical branches completely untested.

The common failure mode: engineering teams set a line coverage threshold in CI, developers write trivial tests that execute code without asserting outcomes, and the metric goes green while meaningful test coverage stays flat.

> [!warning] Line coverage measures execution, not verification. A test that calls every line but asserts nothing will score 100% and catch zero bugs.

@feynman

Line coverage is like confirming you turned on every light switch in a house — it doesn't tell you which lights actually work.

@card
id: est-ch03-c003
order: 3
title: Branch Coverage
teaser: Branch coverage requires every decision point in the code to be taken in both directions — true and false — making it significantly stronger than line coverage for finding logic gaps.

@explanation

Branch coverage (also called decision coverage) tracks whether each outcome of a conditional has been exercised. Every `if`, `else`, ternary operator, `switch` case, and short-circuit expression is a branch. Full branch coverage requires tests that take each branch in both the true and false direction.

Using the same example:

```python
def discount(price, is_member):
    if is_member:          # branch: True AND False must both be tested
        return price * 0.9
    return price
```

100% branch coverage requires at least two tests: one with `is_member=True` and one with `is_member=False`. Line coverage lets you off with one.

Branch coverage is a stronger guarantee because it forces you to consider the alternative path at every decision point. It will catch cases where the else branch is missing, incorrect, or raises an unhandled exception that line coverage never reaches.

Most coverage tools report branch coverage alongside line coverage. In JaCoCo, the report shows yellow diamonds for partially covered branches and green for fully covered ones. In Istanbul/c8, the `B` column in the summary is branch coverage.

The remaining gap: branch coverage says nothing about compound conditions. The expression `if (a && b)` has two branches (true/false), but branch coverage doesn't require you to test the case where `a` is true and `b` is false separately.

@feynman

Branch coverage checks that you've driven a road both ways — forward and in reverse — not just that you've been on it once.

@card
id: est-ch03-c004
order: 4
title: Path Coverage
teaser: Path coverage requires every unique execution path through a function to be exercised — the theoretically complete metric that becomes combinatorially impossible the moment you have a few conditionals.

@explanation

A path is a unique sequence of branches from function entry to function exit. For a function with `n` independent boolean conditions, the number of paths is at most `2^n`. Three conditions yield up to eight paths. Ten conditions yield up to 1,024.

```python
def process(a, b, c):
    if a:
        do_a()
    if b:
        do_b()
    if c:
        do_c()
```

This function has `2^3 = 8` independent paths. A loop with a variable number of iterations adds infinite paths. Path coverage is undecidable for real programs with loops.

This makes path coverage practically useless as a CI metric for anything beyond small, pure functions. It exists primarily as a theoretical upper bound — a way to understand why weaker metrics like branch coverage are necessary approximations.

Where path coverage is applied in practice: safety-critical functions with a small, bounded set of inputs and no loops. Avionics firmware functions or medical device state machines might be small enough to enumerate all paths, and the stakes justify the effort.

For most application code, branch coverage is the pragmatic substitute. It catches the most consequential path gaps without requiring exponential test counts.

> [!info] The gap between branch coverage and path coverage is real but usually not worth closing for general application code. Prioritize branch coverage and supplement with property-based testing when exhaustive path enumeration matters.

@feynman

Path coverage asks you to walk every possible route through a maze — which is feasible for a small maze but turns into a lifetime project once the maze has ten branching corridors.

@card
id: est-ch03-c005
order: 5
title: Condition Coverage
teaser: Condition coverage requires every individual boolean sub-expression within a compound condition to be evaluated as both true and false — catching bugs that branch coverage misses entirely.

@explanation

Branch coverage treats a compound condition as a single decision. Condition coverage goes one level deeper and treats each boolean operand as an independent coverage target.

```java
if (user.isActive() && user.hasPermission("write")) {
    allowAccess();
}
```

Branch coverage requires two tests: one where the whole condition is true and one where it is false. Condition coverage requires four tests to cover all combinations of `isActive()` and `hasPermission("write")` independently.

This matters when each sub-expression has its own logic path. If `hasPermission` contains a bug that only surfaces when `isActive()` is false but `hasPermission` is still called, branch coverage will never expose it — the short-circuit evaluation means the second operand might never be evaluated in the false branch.

Condition coverage comes in several sub-varieties depending on whether it also requires each condition to independently affect the outcome (that is the step up to MC/DC). Standalone condition coverage without that independence requirement can still be satisfied by test cases where a condition's value doesn't actually change the outcome of the decision.

Most mainstream tools report condition coverage alongside branch coverage. JaCoCo tracks it in its branch counter. Istanbul reports it via the `C` (conditions) column when configured.

@feynman

Condition coverage audits each ingredient in a recipe separately — not just whether the dish turned out right, but whether you actually tasted the salt, the sugar, and the acid on their own.

@card
id: est-ch03-c006
order: 6
title: MC/DC — Modified Condition/Decision Coverage
teaser: MC/DC requires each condition in a decision to independently affect the outcome — the aviation and medical-device standard that proves your tests are not just touching code but actually controlling it.

@explanation

MC/DC was formalized in RTCA DO-178C (Software Considerations in Airborne Systems and Equipment Certification), the standard governing avionics software. It is also required under IEC 62304 for Class C medical device software. These domains mandate it because in safety-critical code, weak coverage lets bugs hide in compound logic.

For a decision with `n` conditions, MC/DC requires `n + 1` test cases (rather than `2^n` for full condition coverage). The key rule: for each condition, there must be a pair of test cases where that condition's value is the only thing that changed, and the outcome of the decision changed as a result.

```java
// Decision: (a && b)
// MC/DC requires 3 tests, not 4:
// Test 1: a=true,  b=true  → outcome=true
// Test 2: a=false, b=true  → outcome=false  (a independently affects result)
// Test 3: a=true,  b=false → outcome=false  (b independently affects result)
// Test 4: a=false, b=false → redundant for MC/DC
```

What MC/DC proves that weaker metrics don't: each condition in the decision is actually wired to the outcome. It rules out the scenario where a condition is always overshadowed by another operand's value and could be deleted from the predicate without any test failing.

For general application code, MC/DC is usually overkill. But for authentication logic, financial calculations, or any function where a wrong condition value has severe consequences, applying MC/DC discipline to the test design is a meaningful quality upgrade.

> [!info] MC/DC is not a metric you switch on in a coverage tool and get for free — it is a test design technique. You reason about which test cases achieve independence, then write them deliberately.

@feynman

MC/DC checks that every switch on a control panel actually controls something — not just that someone toggled it, but that toggling it made a real difference to the outcome.

@card
id: est-ch03-c007
order: 7
title: The 100% Coverage Antipattern
teaser: Chasing 100% coverage as a goal produces tests that hit every line without verifying anything — because the metric rewards execution, not correctness.

@explanation

The pressure to hit a coverage number produces predictable failure modes:

**Tests without assertions.** A test that constructs an object, calls every method, and never asserts anything can push coverage to 100%. It will not catch a single regression.

```python
# This test achieves 100% line coverage and tests nothing:
def test_calculator():
    c = Calculator()
    c.add(1, 2)
    c.subtract(5, 3)
    c.divide(10, 2)
    # no assertions
```

**Trivial happy-path tests.** Exercising every line with a single, easy input ignores edge cases, boundary values, and error branches. Coverage says green; the production system crashes on null inputs.

**Deleting untested code to raise the percentage.** If the coverage denominator shrinks, the ratio goes up. Teams have been known to remove legitimate defensive branches because no test covers them, rather than writing the test.

**The perverse incentive.** Once 100% becomes a target, developers optimize for the target. The result is a test suite that looks healthy in CI and provides almost no protection against regressions.

The correct use of a coverage metric is as a floor — a minimum bar that prevents gross neglect — combined with code review discipline that evaluates what the tests actually assert. 80% branch coverage with meaningful assertions is more valuable than 100% line coverage with none.

> [!warning] A coverage number without assertion review is a vanity metric. The question is not "did the test run this line?" but "would this test fail if this line were wrong?"

@feynman

Hitting 100% coverage without real assertions is like checking every box on a safety inspection checklist without actually looking at the equipment — the paperwork is clean and the machine might still explode.

@card
id: est-ch03-c008
order: 8
title: Coverage Thresholds in CI
teaser: A coverage threshold in CI is a useful floor that prevents unreviewed coverage drops — but set it as a ratchet, not a ceiling, and never let it substitute for reviewing what the tests actually assert.

@explanation

A CI coverage gate fails the build when coverage drops below a configured percentage. It prevents new code from being merged without tests and makes coverage regressions visible immediately.

Configuring a threshold in common tools:

```yaml
# JaCoCo in Maven pom.xml
<rule>
  <element>BUNDLE</element>
  <limits>
    <limit>
      <counter>BRANCH</counter>
      <value>COVEREDRATIO</value>
      <minimum>0.80</minimum>
    </limit>
  </limits>
</rule>
```

```json
// Istanbul / c8 in package.json
"c8": {
  "branches": 80,
  "lines": 85,
  "functions": 90
}
```

The policy tradeoffs:

- **Set it too high (95%+):** Teams game it with assertion-free tests. Legacy codebases that start below the threshold will never reach it and the gate becomes a permanent failure.
- **Set it too low (50%):** The gate is toothless. It stops a complete absence of testing but not a gradual decay.
- **Ratchet approach:** Start at your current coverage level, prevent drops, and raise the threshold quarterly as the suite matures. This stops regression without requiring an immediate rewrite of legacy code.

A threshold on branch coverage is more valuable than a threshold on line coverage. Requiring 80% branch coverage means more of your decisions have been tested in both directions. Line coverage at 80% can be satisfied while leaving entire branches untouched.

@feynman

A CI coverage threshold is like a minimum height requirement for a roller coaster — it stops the most dangerous situations but doesn't tell you whether the person who got on is ready for the ride.

@card
id: est-ch03-c009
order: 9
title: Coverage Tools by Ecosystem
teaser: Every major language has a first-class coverage tool — JaCoCo for Java, Istanbul/c8 for JavaScript and TypeScript, Coverage.py for Python, SimpleCov for Ruby — and knowing what each one actually measures matters as much as knowing it exists.

@explanation

**JaCoCo (Java/Kotlin/Groovy):** The standard for JVM languages. Instruments bytecode directly, integrating with Maven, Gradle, and most CI platforms. Reports line, branch, instruction, complexity, and method coverage. The HTML report shows covered/partially-covered/uncovered lines with branch diamonds. Widely used in Spring and Android projects.

**Istanbul / c8 (JavaScript / TypeScript):** Istanbul instruments source code via Babel; c8 uses Node.js's built-in V8 coverage and is faster with no transpilation overhead. Both integrate with Jest, Vitest, and Mocha. The `nyc` CLI wraps Istanbul for standalone use. Reports statements, branches, functions, and lines. TypeScript source maps work in both.

**Coverage.py (Python):** The standard Python coverage tool. Run with `coverage run -m pytest` then `coverage report` or `coverage html`. Supports branch coverage via the `--branch` flag — without it, only line coverage is measured. The `.coveragerc` file or `pyproject.toml` controls exclusions and minimum thresholds.

**SimpleCov (Ruby):** A gem that hooks into Ruby's `Coverage` module. Add it to your `spec_helper.rb` or `test_helper.rb` and it produces an HTML report after your test suite runs. Configurable minimum percentage and per-group thresholds for different parts of the codebase.

Each tool has its own definition of "branch" — a ternary operator may count as a branch in one tool and not in another. Before interpreting numbers across ecosystems, read what the specific tool actually counts.

> [!tip] Always enable branch coverage explicitly — it is off by default in Coverage.py and not the default view in many Istanbul configurations. Line-only coverage is the weakest signal available.

@feynman

Coverage tools are the speedometers of your test suite — each car has one, they all measure roughly the same thing, but you still need to know whether you're reading miles per hour or kilometres per hour.

@card
id: est-ch03-c010
order: 10
title: Mutation Testing as the Better Signal
teaser: Mutation testing introduces deliberate bugs into your code and checks whether your tests catch them — revealing exactly what coverage can never show: whether your assertions are strong enough to detect a change.

@explanation

A mutation testing tool makes small automated changes (mutations) to the source code — flipping a `>` to `>=`, changing `+` to `-`, deleting a return statement — and then runs your test suite against each mutated version. If your tests fail, the mutant is "killed." If your tests pass on the mutated code, the mutant "survived."

```java
// Original
if (age >= 18) { return true; }

// Mutant: boundary flip
if (age > 18) { return true; }
```

If no test calls this function with `age == 18`, the mutant survives. Your coverage is 100%. Your test suite is useless at the boundary.

**Tools:**

- **Stryker** — JavaScript/TypeScript and C#. Well-maintained, integrates with Jest and Vitest, has a dashboard UI.
- **PIT (PITest)** — Java/Kotlin. The standard for JVM mutation testing. Integrates with Maven and Gradle. Incremental mode runs only mutations on changed code.
- **Mutmut** — Python. Simple CLI, good integration with pytest.

The mutation score is the percentage of mutants your tests killed. A mutation score below 60% on critical business logic is a serious quality signal. A mutation score above 80% on core logic is meaningful confidence.

Mutation testing is slow — each mutant requires a full test run. Run it in a nightly pipeline or on a targeted subset of critical modules, not on every PR.

> [!info] Mutation testing is the answer to "does my 95% coverage actually mean anything?" A project with 95% line coverage and a 40% mutation score has tests that execute code without controlling it.

@feynman

Mutation testing is the difference between asking "did the alarm go off?" and asking "would the alarm go off if someone actually broke in?" — it introduces the actual threat and checks whether the system responds.

@card
id: est-ch03-c011
order: 11
title: Coverage of Test Code
teaser: Test code is not typically measured by production coverage tools — but it has its own quality problem: dead test helpers, never-executed setup paths, and copy-pasted assertions that nobody verifies.

@explanation

Production coverage tools measure how much of your production code your tests execute. They generally exclude the test files themselves from measurement — and for good reason: measuring coverage of tests with other tests is circular.

But test code has structural quality issues that coverage cannot see:

**Dead test helpers.** A shared `TestFactory` or `fixtures.py` module accumulates helper methods. Some are used; many are not. Unlike production code, they rarely get deleted because no one is sure if removing them will break something.

**Unreachable setup paths.** A `setUp` or `beforeEach` block may contain conditional logic that was needed for one test and then became stale as the test evolved. The condition is never false; the alternative path is never taken.

**Copy-pasted tests.** Structural duplication in test files means a bug in one copy survives in another. This is invisible to production coverage tools.

**What mutation testing does here:** Running mutation testing surfaces surviving mutants, which often correspond to test code that is structurally present but logically disconnected from the assertion it was meant to protect. A surviving mutant is a test that doesn't assert the right thing — a structural problem in test code, visible indirectly through mutation score.

The practical discipline for test code quality is code review, not coverage tooling: assert that every test has a meaningful assertion, that setup code is used, and that helpers are either used or deleted.

@feynman

Asking coverage tools to validate test quality is like using a spell-checker to evaluate whether an argument is logically sound — it can catch certain surface problems but it cannot tell you if the logic actually works.

@card
id: est-ch03-c012
order: 12
title: Coverage Isn't Testing
teaser: The meta-lesson of the entire chapter: high coverage with weak assertions proves only that the tests ran — it says nothing about whether they would catch a bug.

@explanation

Coverage metrics answer one question: did execution reach this code? They cannot answer: does a test failure occur when this code is wrong?

This distinction is the central insight of structural testing. Consider:

```python
def calculate_tax(income, rate):
    return income * rate

def test_calculate_tax():
    result = calculate_tax(1000, 0.2)
    assert result is not None   # this assertion covers the line
                                # but would pass if the result were 999
```

The test achieves 100% line coverage. If `calculate_tax` were changed to `return income + rate`, the test would still pass. The coverage number never moved, and the bug went undetected.

This failure pattern scales:

- Tests that assert type rather than value
- Tests that assert a list is non-empty rather than checking its contents
- Tests that catch `Exception` and pass rather than checking the specific condition

The three-part discipline that makes structural testing actually useful:

1. Use coverage to find code your tests never reached — then decide whether to test it or delete it.
2. Use mutation testing to find tests that don't catch bugs — then strengthen the assertions.
3. Review test assertions in code review as rigorously as you review the logic under test.

Coverage is not a destination. It is a map of where you haven't been. The work is writing tests that would actually fail when the code is wrong — and no tool gives you that for free.

> [!warning] A test suite with 95% coverage and weak assertions is more dangerous than one with 70% coverage and strong assertions — it creates false confidence that leads teams to skip the manual verification, exploratory testing, and code review that would have caught the bugs.

@feynman

High coverage with weak assertions is like a smoke detector with dead batteries — it looks like safety equipment, it passes the inspection, and it does nothing when the fire starts.
