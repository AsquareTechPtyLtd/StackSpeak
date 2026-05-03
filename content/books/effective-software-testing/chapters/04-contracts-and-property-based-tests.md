@chapter
id: est-ch04-contracts-and-property-based-tests
order: 4
title: Designing Contracts and Property-Based Tests
summary: Contracts and property-based tests turn assertions about specific examples into assertions about the entire input space — preconditions, postconditions, invariants, and properties that the test framework hammers with thousands of generated cases.

@card
id: est-ch04-c001
order: 1
title: Why Specific Examples Are Not Enough
teaser: An example-based test says "given this input, expect this output" — a property-based test says "for all valid inputs, this relationship must hold," which covers an infinite space no example suite can.

@explanation

Example-based tests are the foundation of most test suites. You pick a handful of representative inputs, run the function, and assert the output matches what you wrote down. The problem is "representative" is a judgment call, and the judgment is made by the same developer who wrote the code — meaning the inputs chosen tend to avoid the exact corners that contain the bugs.

Property-based testing reframes the question. Instead of asking "does this function return 4 when I pass 2?" you ask "does this function always return a value greater than or equal to its input?" The test framework then generates thousands of inputs — integers, strings, lists, edge cases — and checks the property against each one.

The progression of testing power:
- **Concrete examples** — fast to write, fragile to the inputs you chose, miss most of the input space
- **Equivalence partitions** — better, but partitions still require human judgment about boundaries
- **Property-based tests** — the framework explores the input space; you focus on what must be universally true

The shift in mindset is the hardest part. Writing a property forces you to articulate the actual contract of the function — not "it returns 42 here," but "it always returns a sorted list," or "the output length never exceeds the input length." That articulation is valuable even before the test runs.

> [!tip] If you cannot state a property, you may not fully understand what the function is supposed to do. Struggling to write properties is a design signal, not a testing failure.

@feynman

An example-based test is checking that one specific lock works with one specific key; a property-based test checks that every key in the universe either fits the lock or correctly fails to.

@card
id: est-ch04-c002
order: 2
title: Design by Contract
teaser: Design by Contract, introduced by Bertrand Meyer in Eiffel, says every function carries a formal agreement — what the caller must provide, what the function promises in return, and what never changes.

@explanation

Bertrand Meyer developed Design by Contract (DbC) in the 1980s as a correctness technique for the Eiffel language. The core idea: a function is a contract between the caller and the implementer. Both sides have obligations and both sides have guarantees.

The three elements of a contract:

- **Preconditions** — what must be true when the function is called. The caller is obligated to satisfy them. If the caller violates a precondition, the behavior of the function is undefined — the implementer is not responsible for the result.
- **Postconditions** — what the function guarantees upon returning. If the preconditions were met and the function returns normally, the postconditions must hold. The implementer is obligated to satisfy them.
- **Invariants** — what must remain true about an object or system at all times (between public method calls). The implementer must preserve them; the caller can rely on them.

Eiffel embedded these directly in the language syntax. In most other languages — Python, Java, TypeScript — you enforce them through assertions, runtime checks, or documentation:

```python
def divide(a: float, b: float) -> float:
    assert b != 0, "Precondition violated: divisor must be non-zero"
    result = a / b
    # Postcondition: if b > 0 and a >= 0, result must be non-negative
    assert b <= 0 or a < 0 or result >= 0
    return result
```

DbC is not just about assertions at runtime — it is a design discipline. When you write a contract before writing an implementation, you are forced to think about the boundary between valid and invalid use before a single line of the body exists.

@feynman

Design by Contract is like a legal agreement between a function and its caller: the caller promises to show up with the right inputs, and the function promises to deliver the right output — and both sides can be held accountable if they break the deal.

@card
id: est-ch04-c003
order: 3
title: Preconditions
teaser: A precondition is a constraint the caller must satisfy before invoking a function — if the caller fails to meet it, the function has no obligation to behave correctly.

@explanation

Preconditions define the valid input space for a function. They represent the assumptions the implementer is allowed to make. If those assumptions are violated, all bets are off.

A well-written precondition is specific and checkable:

```java
/**
 * Returns the element at the given index.
 *
 * Preconditions:
 *   - index >= 0
 *   - index < this.size()
 */
public T get(int index) {
    if (index < 0 || index >= size()) {
        throw new IllegalArgumentException(
            "Index " + index + " out of range [0, " + size() + ")");
    }
    return elements[index];
}
```

The practical question is whether to enforce preconditions with exceptions, assertions, or implicit documentation. Three schools of thought:

- **Fail loudly at the boundary** — throw an exception or assertion error immediately when a precondition is violated. This is the safest approach for production code. The failure happens at the call site, not deep inside the implementation where the stack trace is harder to read.
- **Assert in debug builds only** — use language-level assertions (Java's `assert`, Python's `assert`) that can be disabled in production. The argument is performance; the cost is that violated preconditions in production produce mysterious behavior instead of a clear error.
- **Document but do not enforce** — rely on callers to read the docs. Acceptable only for performance-critical inner loops where the check itself is measurably expensive, and the caller can be audited statically.

For most code, the first approach — fail loudly at the boundary — is correct. The performance argument for disabling assertions rarely survives measurement.

> [!warning] Never use precondition failures to handle expected invalid user input. Preconditions are for programming errors, not for validating data from external sources. Use proper validation and error handling for external input.

@feynman

A precondition is the bouncer at the door: the function is allowed to assume everyone inside behaved correctly, because the bouncer already checked IDs at the entrance.

@card
id: est-ch04-c004
order: 4
title: Postconditions
teaser: A postcondition is a guarantee about what will be true after a function returns — the function's side of the contract, which the caller is entitled to depend on.

@explanation

While preconditions constrain the caller, postconditions constrain the implementer. A postcondition says: "if you called me correctly, then when I return, you can count on this."

Postconditions are harder to express than preconditions because they often describe the relationship between the input and the output, or the state before and after:

```python
def sort(items: list[int]) -> list[int]:
    result = sorted(items)
    
    # Postconditions:
    # 1. Result has the same length as input
    assert len(result) == len(items), "Length must be preserved"
    # 2. Result is sorted
    assert all(result[i] <= result[i+1] for i in range(len(result)-1)), \
        "Result must be non-decreasing"
    # 3. Result is a permutation of input (same elements)
    assert sorted(result) == sorted(items), "Elements must be preserved"
    
    return result
```

Postconditions serve two purposes. First, they document what the function promises — the caller can write code that relies on the guarantee without looking at the implementation. Second, they serve as runtime sanity checks that catch implementation bugs: if the postcondition fails, the function itself is broken, not the caller.

The `old` value pattern is common in DbC tooling: capturing the value of mutable state before execution so the postcondition can reference how things changed:

```java
// Postcondition: size increased by exactly 1
assert this.size() == old_size + 1 : "add() must increase size by 1";
```

@feynman

A postcondition is a receipt the function hands back to the caller: proof that the work was done correctly, which the caller can keep and rely on without re-inspecting the work.

@card
id: est-ch04-c005
order: 5
title: Invariants
teaser: An invariant is a property that must remain true at all observable points — class invariants describe consistent object state, loop invariants prove that loops do what they claim to do.

@explanation

An invariant is a condition that is preserved across all operations. Unlike preconditions and postconditions, which are local to a single call, invariants describe ongoing constraints that must hold throughout a computation or across the entire lifetime of an object.

**Class invariants** express constraints on an object's internal state that must hold after every public method call. They are not required to hold during the execution of a method — only at its exit:

```java
public class BoundedStack<T> {
    private final int capacity;
    private int size;

    // Class invariant: 0 <= size <= capacity
    private void checkInvariant() {
        assert size >= 0 : "size must be non-negative";
        assert size <= capacity : "size must not exceed capacity";
    }

    public void push(T item) {
        if (size >= capacity) throw new IllegalStateException("Stack is full");
        elements[size++] = item;
        checkInvariant();  // invariant must hold at exit
    }
}
```

**Loop invariants** are conditions that are true before the loop starts, remain true after each iteration, and whose conjunction with the loop exit condition implies the loop's correctness. They are the primary tool for reasoning about loop-based algorithms:

```
// Loop invariant for binary search:
// At every iteration, if target is present, it lies within arr[low..high]
```

Invariants are the theoretical backbone of formal verification and are heavily used in tools like TLA+ and Dafny. In practice, even informal invariant reasoning — writing them down as comments, adding runtime checks during testing — dramatically reduces the class of bugs that survive code review.

> [!info] Invariants do not need to hold inside a method during mutation — they are only required at the entry and exit of every public operation. Enforcing them mid-operation would prevent many legitimate algorithms.

@feynman

An invariant is like a building's load-bearing wall: individual rooms can be rearranged during renovation, but when the work is done, the wall must still be standing — it is the constraint that keeps the whole structure sound.

@card
id: est-ch04-c006
order: 6
title: Property-Based Testing
teaser: In property-based testing, you define a property that must hold for all valid inputs, and the framework generates thousands of random cases to try to falsify it — you write the law, the framework tries to break it.

@explanation

The mechanics are simple: you write a test that takes generated inputs as parameters, runs the code under test, and asserts a property about the result. The framework handles generating the inputs, typically running hundreds to thousands of cases per test:

```typescript
import * as fc from "fast-check";

// Property: reversing a list twice yields the original list
test("reverse is an involution", () => {
  fc.assert(
    fc.property(fc.array(fc.integer()), (arr) => {
      const twice = [...arr].reverse().reverse();
      expect(twice).toEqual(arr);
    })
  );
});
```

```python
from hypothesis import given, strategies as st

# Property: sorting is idempotent
@given(st.lists(st.integers()))
def test_sort_idempotent(lst):
    sorted_once = sorted(lst)
    sorted_twice = sorted(sorted_once)
    assert sorted_once == sorted_twice
```

The framework does not generate purely random inputs. It uses typed generators (integers, strings, lists, custom types) so the inputs are always structurally valid. Many frameworks also include edge-case tables — empty collections, `None`, `0`, `INT_MAX`, empty strings — that are tried on every run regardless of the random seed.

The test fails as soon as a single generated input violates the property. The framework then reports which input caused the failure, along with the shrunk (minimal) version of that input.

@feynman

Property-based testing is like hiring a QA team that never gets tired: you tell them what rule the code must follow, and they spend all day inventing new inputs to try to break it.

@card
id: est-ch04-c007
order: 7
title: The Frameworks
teaser: QuickCheck (Haskell, 1999) is the original; Hypothesis (Python), fast-check (TypeScript/JavaScript), and jqwik (JVM) are its descendants — each shares the same core model but adapts to its language's idioms.

@explanation

**QuickCheck** — Haskell, introduced by Koen Claessen and John Hughes in 2000. The original framework that defined the model: generators, properties, shrinking, and the `Arbitrary` typeclass for generating values of any type. Nearly every property-based testing framework in other languages is a direct descendant.

**Hypothesis** — Python. The most sophisticated property-based framework available. Uses a database of previously failing examples to avoid regressions, employs a stateful shrinking algorithm called "Conjecture" that produces extremely minimal failures, and integrates naturally with pytest:

```python
from hypothesis import given, strategies as st, settings

@given(st.text(min_size=1))
@settings(max_examples=1000)
def test_encode_decode_roundtrip(s: str):
    assert decode(encode(s)) == s
```

**fast-check** — TypeScript/JavaScript. The idiomatic choice for JS/TS projects. Provides typed generators, composable arbitraries, and first-class async support:

```typescript
import * as fc from "fast-check";

fc.assert(
  fc.asyncProperty(fc.string(), async (s) => {
    const encoded = await encode(s);
    const decoded = await decode(encoded);
    return decoded === s;
  })
);
```

**jqwik** — JVM (Java/Kotlin). A JUnit 5 test engine that adds property-based testing to the standard JVM test lifecycle. Uses annotations rather than higher-order functions to match Java's style:

```java
@Property
boolean sortingPreservesLength(@ForAll List<Integer> list) {
    return sort(list).size() == list.size();
}
```

All four frameworks implement the same fundamental loop: generate, test, shrink on failure, report.

> [!info] Hypothesis's shrinking is considered the best in class. If you are working in Python, start there — its error messages after shrinking often point directly to the offending logic.

@feynman

QuickCheck is the original blueprint; Hypothesis, fast-check, and jqwik are the same building constructed in different cities — same structural design, adapted to the local materials and building codes.

@card
id: est-ch04-c008
order: 8
title: Common Properties
teaser: Round-trip, idempotence, commutativity, associativity, and monotonicity are the five property patterns that apply to the widest range of functions — recognizing them by name makes writing property tests faster.

@explanation

**Round-trip (encode then decode):** If you serialize then deserialize, you get back the original. Applies to any codec, serializer, parser, or compression algorithm:

```python
@given(st.builds(User, name=st.text(), age=st.integers(min_value=0, max_value=150)))
def test_user_json_roundtrip(user):
    assert User.from_json(user.to_json()) == user
```

**Idempotence:** Applying the operation twice gives the same result as applying it once. Sorting, deduplication, normalization, and many data-cleaning operations should be idempotent:

```typescript
fc.assert(fc.property(fc.array(fc.integer()), (arr) => {
  expect(normalize(normalize(arr))).toEqual(normalize(arr));
}));
```

**Commutativity:** The order of operands does not affect the result. Addition, set union, and merging commutative data structures are candidates:
```
add(a, b) === add(b, a)
```

**Associativity:** Grouping of operations does not affect the result. String concatenation, list append, and most fold/reduce operations are associative:
```
concat(concat(a, b), c) === concat(a, concat(b, c))
```

**Monotonicity:** The output changes in a predictable direction as the input grows. A search function that returns more results with a less restrictive query; a compression function whose output size is bounded by its input size:
```
if len(input_a) <= len(input_b): compress(input_a).size <= compress(input_b).size
```

Recognizing which pattern applies to a given function tells you which property to write — often within seconds of looking at the function signature.

@feynman

Round-trip, idempotence, commutativity, associativity, and monotonicity are the five recurring shapes that most properties take — learning to spot them is like learning five chord shapes on a guitar: suddenly most songs are within reach.

@card
id: est-ch04-c009
order: 9
title: Shrinking
teaser: When a property fails, the framework does not stop at the first failing input — it systematically simplifies the input toward the smallest case that still causes the failure, because minimal failures are far easier to debug.

@explanation

The first input that falsifies a property is rarely useful by itself. A generated list of 47 integers with values in the range `[-10000, 10000]` is hard to reason about. Shrinking is the process of automatically finding a smaller, simpler version of that input that still triggers the same failure.

Shrinking algorithms vary by framework, but the basic idea is: given a failing input, generate "smaller" variants (shorter lists, smaller integers, simpler strings), test whether each variant still fails, keep the simplest one that does, and repeat until no simpler variant fails.

The difference this makes in practice is significant:

```
# Before shrinking:
Failed with: [47, -3901, 22, 0, -1, 18, 301, -2, 99, 0, 3, -47, 8, 1024, -500]

# After shrinking:
Failed with: [1, -1]
```

The shrunk example `[1, -1]` immediately suggests the bug involves a list with a positive and a negative element — something the original 15-element list obscures entirely.

Frameworks handle shrinking differently:

- **QuickCheck and jqwik** use type-directed shrinking: each generator knows how to shrink its own values (an integer shrinks toward 0, a list shrinks by removing elements).
- **Hypothesis** uses integrated shrinking: it operates on the internal byte sequence used to generate the value, which produces more consistent and aggressive simplification without requiring each generator to implement its own shrinker.

The practical consequence: do not be satisfied with the first failing example the framework reports. Wait for shrinking to complete. The shrunk case is the one worth putting in your bug report.

> [!tip] Hypothesis stores the shrunk failing example in its database and replays it on every subsequent run. If you fix the bug, the stored example is retried first — a free regression check.

@feynman

Shrinking is a property test's way of doing the detective work for you: instead of handing you a 47-piece jigsaw of a bug, it keeps removing pieces until you have only the two or three that matter.

@card
id: est-ch04-c010
order: 10
title: When Property-Based Testing Wins
teaser: Property-based testing delivers the highest return on pure functions, parsers, serializers, data transformations, and algorithmic code — anywhere the input space is large and the correct behavior can be stated as a universal law.

@explanation

Property-based testing is most powerful when three conditions hold simultaneously: the input space is large (or infinite), the correct behavior can be stated as a property that does not depend on the specific input value, and the function under test is deterministic.

**Strongest use cases:**

- **Pure functions and transformations** — functions with no side effects and no I/O are trivially easy to test with properties. `encode`, `decode`, `sort`, `format`, `parse`, `normalize`, `compress`.
- **Parsers and serializers** — the round-trip property (`parse(serialize(x)) == x`) is one of the most useful properties in the catalog, and parsers have enormous input spaces.
- **Mathematical and algorithmic code** — arithmetic operations, sorting algorithms, search algorithms, graph algorithms. The mathematical properties (commutativity, associativity, idempotence) map directly to the code.
- **Data validation logic** — a validator's properties include "valid inputs are always accepted" and "inputs violating constraint X are always rejected." These are directly testable.
- **Codecs and data conversions** — currency conversion, unit conversion, encoding schemes. Round-trip and inverse-function properties apply cleanly.

**What makes a function a strong candidate:**

- The function is deterministic for a given input
- The domain is easy to describe with generators
- You can state at least one universal property — a law that holds for all inputs in the domain
- The function is self-contained (no database calls, no HTTP requests, no timestamps)

The presence of all three signals is a reliable indicator that writing even one property test will find bugs that a hand-crafted example suite missed.

@feynman

Property-based testing is at its strongest when you can describe a function's behavior as a law of nature rather than a list of examples — the more universal the rule, the more damage a generator army can do finding exceptions to it.

@card
id: est-ch04-c011
order: 11
title: When Property-Based Testing Struggles
teaser: UI, I/O-heavy code, and time-sensitive operations resist property-based testing — not because the technique is wrong, but because the preconditions for it to work (determinism, cheap generation, articulable laws) are not met.

@explanation

Property-based testing is not a universal replacement for example-based tests. Several categories of code resist it structurally:

**UI and rendering code** — a property test needs a checkable assertion. "The button is the right color" is not mechanically verifiable without a pixel-comparison oracle, and pixel comparisons are fragile. Visual regression testing is a different tool for this problem.

**I/O-heavy and side-effectful code** — code that reads from a database, makes HTTP calls, or writes to the filesystem is expensive to run thousands of times. Setup cost per test case is prohibitive. The correct approach is to push I/O to the edges of the system and property-test the pure core.

**Time-sensitive and non-deterministic code** — code that reads `Date.now()` or `random()` internally is hard to generate inputs for, because part of the "input" is invisible to the framework. Dependency injection of clocks and random sources can solve this.

**Complex setup with deep interdependencies** — if generating a valid input requires constructing a large object graph with many constraints between fields, the cost of writing and maintaining the generator can exceed the benefit. Sometimes a well-chosen set of examples is more maintainable.

**When you cannot state a property** — if the only correct description of the function is "it returns the right answer," and the "right answer" is itself computed by a reference implementation that is as complex as the code under test, properties offer little leverage.

The practical approach: use property-based testing for the pure, algorithmic core of your system, and use example-based tests for the I/O boundaries, the UI, and anywhere the setup cost is high.

> [!warning] Running 1,000 property cases against a real database is not property-based testing — it is a load test with a broken exit condition. Always separate I/O from the logic you want to explore with properties.

@feynman

Property-based testing is a precision tool, not a universal solvent: it works brilliantly on the pure, mathematical heart of your code and gets stuck when the thing you are testing requires a real database, a real clock, or a real screen.

@card
id: est-ch04-c012
order: 12
title: Stateful Property Testing
teaser: Stateful property testing goes beyond pure functions — you model valid sequences of operations, the framework generates thousands of operation sequences, and you verify that the real system always matches your model's predictions.

@explanation

Most real systems are stateful. A property-based test that only generates a single input and checks a single output cannot directly test a shopping cart, a file system, or a database connection pool. Stateful property testing extends the technique to cover stateful systems by treating operation sequences as the generated input.

The pattern has three parts:

1. **Define a model** — a simple, trusted reference implementation of the system's behavior. The model does not need to be efficient; it only needs to be obviously correct. A list-backed stack, a dictionary-backed cache, a plain-object user account.
2. **Define the operations** — the commands that can be applied to both the real system and the model. Each command has a generator for its arguments, a precondition (is this command currently valid to run?), and an assertion (after running the real command and the model command, do they agree?).
3. **Generate sequences** — the framework generates random sequences of valid operations and runs them against both the real system and the model in parallel, failing if they diverge.

```python
from hypothesis.stateful import RuleBasedStateMachine, rule, initialize
import hypothesis.strategies as st

class QueueMachine(RuleBasedStateMachine):
    def __init__(self):
        super().__init__()
        self.model = []           # reference implementation
        self.real = MyQueue()     # system under test

    @rule(value=st.integers())
    def enqueue(self, value):
        self.model.append(value)
        self.real.enqueue(value)

    @rule()
    def dequeue(self):
        if not self.model:
            return  # precondition: queue must not be empty
        expected = self.model.pop(0)
        actual = self.real.dequeue()
        assert actual == expected, f"Expected {expected}, got {actual}"

TestQueue = QueueMachine.TestCase
```

This is also the primary technique for testing concurrent or distributed systems: generate interleaved operation sequences from multiple clients, verify that the observable outcomes are consistent with some valid sequential execution (linearizability testing).

> [!info] Stateful property testing found a bug in the Riak distributed database and in the Dropbox sync client that no unit or integration test had caught. For stateful concurrent systems, it is arguably the most powerful testing technique available.

@feynman

Stateful property testing is like hiring a monkey to randomly press buttons on your application all day — except the monkey has a reference manual describing what each button should do, and it files a precise bug report the moment the app and the manual disagree.
