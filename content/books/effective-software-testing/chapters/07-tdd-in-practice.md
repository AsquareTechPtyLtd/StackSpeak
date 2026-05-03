@chapter
id: est-ch07-tdd-in-practice
order: 7
title: Test-Driven Development in Practice
summary: Test-Driven Development is taught as a three-step rhythm — red, green, refactor — but the practiced version is more nuanced: when to use it, when not to, classicist vs London-school differences, and how to keep the practice when deadlines hit.

@card
id: est-ch07-c001
order: 1
title: The Red-Green-Refactor Rhythm
teaser: TDD is a three-beat cycle — write a failing test, make it pass with the simplest code possible, then clean up — and the order is not optional.

@explanation

The red-green-refactor loop is the heartbeat of TDD. Each beat has a specific constraint, and violating the order defeats the purpose.

**Red — write a failing test.** Before any production code exists, write a test that describes the desired behavior. The test must fail, proving the feature is not yet implemented. A test that passes immediately either tests nothing new or was written after the code — neither is TDD.

**Green — make it pass, simply.** Write the minimum production code that makes the failing test pass. "Minimum" is deliberate: fake it if necessary, return a hardcoded value, do whatever it takes. The goal is a green bar as fast as possible. Design quality is not the concern here.

**Refactor — clean up under green.** Once the test passes, improve the internal structure of both the production code and the test itself. Extract duplication, improve naming, simplify logic. The test suite is the safety net — it tells you immediately if a refactoring breaks behavior.

A concrete example — implementing a `max` function:

```swift
// Red: test first
func testMaxReturnsLargerOfTwoIntegers() {
    XCTAssertEqual(max(3, 7), 7)
}

// Green: simplest code that passes
func max(_ a: Int, _ b: Int) -> Int {
    return 7  // hardcoded — but the test passes
}

// Next red: add a second test to force a real implementation
func testMaxReturnsFiveWhenFiveIsLarger() {
    XCTAssertEqual(max(5, 2), 5)
}

// Green: now the hardcode fails, so we generalize
func max(_ a: Int, _ b: Int) -> Int {
    return a > b ? a : b
}

// Refactor: nothing to clean up here — the logic is already minimal
```

The hardcoded return is not a shortcut; it is the technique. It forces you to add more tests that triangulate toward a real implementation, each step backed by a failing test.

> [!tip] If you feel embarrassed writing a hardcoded return, you are probably skipping steps. The discipline of tiny steps is what makes TDD safe, not a sign you are doing it wrong.

@feynman

Red-green-refactor is the same rhythm as a sculptor working in clay — poke the problem into shape first (red), make it hold together (green), then smooth the surface (refactor) — never polish before the shape is right.

@card
id: est-ch07-c002
order: 2
title: Kent Beck's Original Framing
teaser: Kent Beck introduced TDD in *Test-Driven Development: By Example* (2002) not as a testing technique but as a way to manage fear and build design confidence one small step at a time.

@explanation

Kent Beck's *Test-Driven Development: By Example* (Addison-Wesley, 2002) is the canonical TDD text. Beck describes TDD as a response to a specific problem: the fear of making a change in code you don't fully understand.

Beck's framing is psychological as much as technical. When you have a test suite that is always green, you know exactly what you broke and when. That safety lets you take bolder design moves. Without it, programmers work cautiously, avoid refactoring, and let systems accumulate complexity because changing anything feels risky.

Two of Beck's key patterns from the book:

**Fake It ('Til You Make It):** Return a hardcoded value to get green, then generalize once you have more tests. This is not laziness — it is the correct technique for preventing over-engineering.

**Triangulate:** Add multiple tests from different angles to force a general implementation to emerge. If you can get green with a hardcoded return, write another test that breaks the hardcode.

Beck also introduced the concept of a **test list** — before coding anything, jot down every behavior the system needs to exhibit. Work through the list test by test. This keeps the scope visible and prevents both gold-plating and forgetting edge cases.

One of Beck's most quoted observations: "TDD is not about testing. It is about taking small enough steps that you can always know where you are."

The book uses two worked examples: a multi-currency money problem and a minimal xUnit framework built using TDD. Reading these worked examples is more instructive than any abstract description.

@feynman

Beck's TDD insight is like navigating a dark room by taking small steps and tapping the floor — each tap is a test that tells you where it's safe to put your weight before you commit to the step.

@card
id: est-ch07-c003
order: 3
title: Classicist (Detroit-School) TDD
teaser: The classicist approach tests real objects against real collaborators and treats the unit test as a black-box contract — mocks are a last resort, not the default.

@explanation

The classicist school of TDD — also called the Detroit school, or state-based TDD — emerged from Beck's original work and the Extreme Programming community. Its defining characteristic is testing behavior through real objects, not through mocks.

In classicist TDD:

- **Units are tested in isolation but using real collaborators.** A "unit" is a cluster of related classes working together. If `OrderService` depends on `PriceCalculator`, the test instantiates both and tests the behavior through their interaction, not by mocking `PriceCalculator`.
- **Tests verify state, not interaction.** You assert on the output or the resulting state of objects, not on which methods were called on which collaborators.
- **Mocks and stubs are used only for external dependencies** — database calls, HTTP requests, the system clock — where the real collaborator is impractical in a test environment.
- **The design emerges from refactoring, not from upfront interface design.** You let the real behavior tell you what abstractions are needed.

A classicist test for a discount engine:

```swift
func testAppliesLoyaltyDiscountForMember() {
    let cart = Cart(items: [Item(price: 100)])
    let customer = Customer(memberSince: Date.distantPast)
    let engine = DiscountEngine()

    let total = engine.calculateTotal(cart: cart, customer: customer)

    XCTAssertEqual(total, 90)  // 10% loyalty discount applied
}
```

No mocks. Real `Cart`, real `Customer`, real `DiscountEngine`. The test asserts on the output value.

The advantage is that classicist tests survive internal refactoring better — the test does not care how `DiscountEngine` is implemented internally, only what it produces. The risk is that integration failures (two real collaborators misunderstanding each other) are harder to pinpoint than in mock-heavy tests.

Mauricio Aniche's *Effective Software Testing* (Manning, 2022) takes a classicist position, emphasizing specification-based testing of real behavior rather than interaction-based verification.

@feynman

Classicist TDD is like testing a recipe by tasting the finished dish — you don't care how each ingredient behaved during cooking, only whether the result tastes right.

@card
id: est-ch07-c004
order: 4
title: London-School TDD
teaser: The London school tests objects in strict isolation using mocks for all collaborators, discovering interfaces top-down from a failing acceptance test — design is the primary output.

@explanation

The London school of TDD — also called mockist TDD or interaction-based TDD — was formalized by Steve Freeman and Nat Pryce in *Growing Object-Oriented Software, Guided by Tests* (Addison-Wesley, 2009), commonly cited as GOOS. Freeman and Pryce worked in London, hence the name.

The defining characteristics:

- **Outside-in development.** Start with a failing acceptance test that describes end-to-end behavior. Then drive the implementation downward through the layers, one class at a time, mocking out everything not yet implemented.
- **Mock all collaborators.** Each class is tested in total isolation. `OrderService` is tested with a mocked `PriceCalculator`, a mocked `InventoryRepository`, and a mocked `NotificationService`. The test verifies that `OrderService` calls its collaborators in the right way with the right arguments.
- **Tests verify interactions, not just state.** Expectations like "the `NotificationService.sendOrderConfirmation` method was called exactly once with this `orderId`" are first-class assertions.
- **Interfaces emerge from the outside in.** When you mock a collaborator that does not yet exist, you are designing its interface at the point of use — which tends to produce interfaces shaped by what callers actually need.

```swift
func testOrderServiceSendsConfirmationOnSuccess() {
    let mockNotifier = MockNotificationService()
    let mockInventory = MockInventoryRepository(available: true)
    let service = OrderService(notifier: mockNotifier, inventory: mockInventory)

    service.placeOrder(orderId: "abc-123")

    XCTAssertTrue(mockNotifier.sendConfirmationCalled)
    XCTAssertEqual(mockNotifier.lastOrderId, "abc-123")
}
```

The downside: mockist tests are tightly coupled to implementation details. Refactoring — say, merging two collaborators into one — breaks the tests even if behavior is unchanged. This is the central critique of the London school from classicist practitioners.

> [!warning] London-school tests that mock every collaborator can become implementation transcripts rather than behavior specifications. If your tests break every time you refactor internals, the mocks may be too granular.

@feynman

London-school TDD is like testing a relay race by verifying that each runner received the baton correctly and passed it in the right direction — you trust the outcome only after confirming every handoff was correct.

@card
id: est-ch07-c005
order: 5
title: Uncle Bob's Three Rules of TDD
teaser: Robert C. Martin distilled TDD into three rules that, if followed literally, make it impossible to write production code that isn't covered by a test — and impossible to write a test before it can fail.

@explanation

Robert C. Martin (Uncle Bob) formulated three rules of TDD that are more restrictive than the simple red-green-refactor description. They define the micro-cycle at the level of individual lines of code:

**Rule 1:** You are not allowed to write any production code unless it is to make a failing unit test pass.

**Rule 2:** You are not allowed to write more of a unit test than is sufficient to fail — and compilation failures count as failures.

**Rule 3:** You are not allowed to write more production code than is sufficient to pass the currently failing unit test.

These rules enforce a loop with a cycle time measured in seconds, not minutes. Write one line of the test — if it doesn't even compile, stop and make it compile before adding more test code. Write exactly enough production code to make that line pass. Return to the test.

The consequence of following all three rules simultaneously is that you are almost never more than a few seconds away from a green bar. The rules also make it structurally impossible to have untested production code: code can only be added to make a failing test pass.

Martin argues in *Clean Code* and in numerous talks that the three rules also act as documentation — because the tests are written just before the production code, they describe exactly what the programmer was thinking at the point of writing.

The critique is that this level of micro-management can feel mechanical and is difficult to sustain on complex algorithmic problems where the shape of the solution is not yet clear.

> [!info] The three rules work best when you already have some sense of the shape of the solution. If you are genuinely exploring an unfamiliar problem space, the rules can feel like constraints on thinking rather than supports for it.

@feynman

Uncle Bob's three rules are like a traffic light with a one-second cycle — you can only move one foot forward on green, and you must stop and check again before the next step.

@card
id: est-ch07-c006
order: 6
title: TDD as a Design Tool
teaser: The most underrated benefit of TDD is not test coverage — it is the design pressure that hard-to-test code creates, forcing better interfaces, smaller classes, and lower coupling before the code ships.

@explanation

Practitioners who adopt TDD primarily for test coverage often abandon it when deadlines hit, because coverage alone does not justify the overhead. The ones who stick with it have usually discovered the design feedback loop.

**Hard-to-test code signals design problems.** If writing a test for a class requires instantiating twelve other objects, the class has too many dependencies. If a test requires setting up elaborate global state, the code relies on hidden inputs. If the test is impossible to write without reaching into private internals, the abstraction boundary is wrong.

TDD surfaces these problems before the code reaches production, when they are cheap to fix. Writing the test first forces you to answer: "What is the simplest interface I can give this class so that the test is easy to write?" That question is exactly the design question you need to be asking.

Specific design benefits that TDD tends to produce:

- **Smaller classes.** A class that is easy to test in isolation does not have twenty responsibilities.
- **Explicit dependencies.** When a test must provide all collaborators, hidden global state becomes obvious and painful. Constructor injection naturally follows.
- **Stable interfaces.** Thinking about the interface before the implementation tends to produce interfaces shaped by the caller's needs rather than the implementor's convenience.
- **Lower coupling.** A class that is easy to test without a database, an HTTP server, or a file system has necessarily been decoupled from those infrastructure concerns.

This is why Freeman and Pryce subtitle *Growing Object-Oriented Software, Guided by Tests* the way they do — the tests are guiding the design, not just verifying it.

@feynman

TDD is like planning a piece of furniture by sitting in it before you build it — the act of imagining the use reveals what shape the design needs to be.

@card
id: est-ch07-c007
order: 7
title: The Green-Bar Discipline
teaser: The green-bar discipline is a commitment to keeping your test suite passing at all times — small steps, frequent commits, and a willingness to revert rather than fight a red bar for too long.

@explanation

The green-bar discipline is the operational habit that makes TDD sustainable under pressure. It rests on three commitments:

**Take small steps.** The red phase should last seconds to minutes, not hours. If you have been failing for thirty minutes, the step was too large. Revert to the last green state and break the problem into smaller pieces.

**Never leave the bar red at the end of a session.** If you must stop working with a failing test, revert the change rather than commit a broken state. A test suite that is sometimes red trains you to ignore red, which destroys the feedback signal.

**Revert rather than debug long red states.** This is the most counterintuitive rule. If a change that should have been simple has made the bar red and you cannot find why in a few minutes, revert to green and take a smaller step. The tests are not broken — your model of the change was wrong. A green state with a clearer direction is always more valuable than a continued attempt to salvage a confused red state.

Kent Beck describes this in *TDD: By Example* as the distinction between "running the tests" and "watching the bar." The bar is a communication device — if it is not communicating clearly, something is wrong with the rhythm, not just the code.

The green-bar discipline also means running the full test suite frequently. If a suite takes 20 minutes to run, the discipline breaks down: programmers stop running it after every change. Fast tests are a prerequisite for this way of working, not a nice-to-have.

> [!tip] If you find yourself red for more than ten minutes, revert. Every extra minute of fighting a red bar is a minute of paying interest on a step that was too large.

@feynman

The green-bar discipline is like a pilot's commitment to staying in visual contact with the ground — when you lose sight of where you are, you do not push on and hope; you climb back up to where you can see.

@card
id: est-ch07-c008
order: 8
title: Refactoring Under Green — The Step That Gets Skipped
teaser: The refactor step is not optional — it is where TDD pays for itself — but it is the first thing dropped under deadline pressure, and that is exactly when accumulated design debt accelerates.

@explanation

The red-green-refactor cycle only delivers its long-term value if the third step actually happens. Getting to green with messy code and shipping it is not TDD — it is test-first coding with the same design debt accumulation as any other approach.

What the refactor step actually covers:

- **Removing duplication.** Duplication introduced during the "simplest possible code" phase is the most common residue. Extract it.
- **Improving names.** The name you chose under pressure to pass a test is rarely the name you want in the codebase long-term.
- **Simplifying conditionals.** The `if/else` that emerged from triangulating across three tests may collapse into a single expression.
- **Reconsidering abstractions.** After several cycles, a pattern may emerge that suggests a new class or interface that makes the next test easier to write.

Refactoring under green is safe specifically because the tests exist and are passing. You can rename, extract, and reorganize with confidence that any behavior regression will be caught immediately.

The deadline failure mode: under time pressure, the refactor step is skipped with the intention of coming back later. "Later" rarely arrives. The green state persists, but the code accumulates duplication and poor names until the tests are still green but the code is increasingly difficult to work in.

Aniche's *Effective Software Testing* notes that this is the stealth failure mode of TDD in teams — the process looks followed from the outside (tests exist, they pass) but the refactor discipline has eroded and the code quality degrades despite test coverage.

> [!warning] Tests that pass on messy code give you safety but not speed. Skipping refactor trades tomorrow's productivity for today's velocity, and the exchange rate gets worse over time.

@feynman

Skipping the refactor step is like washing your dishes but leaving them stacked wet — the kitchen looks clean enough to use, but the clutter compounds and eventually the mess is bigger than if you'd just put them away properly each time.

@card
id: est-ch07-c009
order: 9
title: When TDD Shines
teaser: TDD delivers the most value on algorithmic code, parsers, business rule engines, and well-specified numeric computation — where the expected output is precisely knowable before implementation begins.

@explanation

TDD works best when two conditions are met: you can specify the expected output precisely before writing the code, and the feedback loop from test to implementation is fast.

**Algorithmic code.** Sorting, searching, compression, encryption, and graph traversal have known correct outputs for given inputs. You can write the assertions before writing a single line of implementation. The tests form a specification that is verifiable and exhaustive.

**Parsers and lexers.** Input-output behavior is completely specifiable: given this string, produce this token sequence or AST. Each parser rule becomes a test. TDD naturally drives a parser through its grammar incrementally.

**Business rule engines.** Pricing logic, discount rules, tax calculations, eligibility rules — these are systems where the product team can usually describe every case. "A loyalty member with an order over £100 gets 15% off." That sentence is a test.

**Well-specified numeric computation.** Financial calculations, unit conversions, actuarial formulas — anywhere the domain has a clear, testable specification.

**Pure functions.** Any function that takes inputs and returns an output with no side effects is trivially testable and benefits from TDD's immediate feedback.

```swift
// Business rule: ideal TDD territory
func testAppliesVolumeDiscountAboveTenUnits() {
    let pricer = VolumePricer(unitPrice: 10.0)
    XCTAssertEqual(pricer.total(units: 11), 99.0)  // 10% discount
}

func testNoDiscountAtOrBelowTenUnits() {
    let pricer = VolumePricer(unitPrice: 10.0)
    XCTAssertEqual(pricer.total(units: 10), 100.0)
}
```

The common thread is predictability: you can be right about what the test should assert before the implementation teaches you. When that condition holds, TDD's cycle of test-then-implement is not overhead — it is the natural order of work.

@feynman

TDD shines when you already know what the answer should look like before you start computing it — like verifying a math proof by checking each line against known rules before moving to the next.

@card
id: est-ch07-c010
order: 10
title: When TDD Struggles
teaser: TDD is a poor fit for UI code, exploratory prototyping, integration with unfamiliar third-party APIs, and throw-away spike code — forcing it in these contexts produces tests of low value at high cost.

@explanation

Honest practitioners acknowledge that TDD is not universally the right approach. Applying it in the wrong contexts produces brittle tests, slows exploration, and creates a backlog of tests that do not survive the next iteration.

**UI code.** The expected appearance of a view is hard to express as a precise assertion. Tests that verify layout properties (this label is 16pt and red) break constantly as the design evolves, and they do not verify the thing users actually care about — does it look right and work correctly? Manual review and screenshot testing capture UI correctness more effectively than unit tests.

**Exploratory and prototype work.** When the goal is to learn whether an approach is feasible at all, writing tests first imposes discipline on a phase that benefits from freedom. Write the spike freely, discover the right abstractions, then throw the spike away and use TDD to build the real version informed by what you learned.

**Integrating unfamiliar third-party APIs.** Before you understand what an API does, you cannot write a meaningful test against it. Reading documentation, writing exploratory code, and running real requests teaches you what to expect. After you understand the API, you can write an adapter with clear tests.

**Code you know you will discard.** Test code is a maintenance liability. Writing careful tests for a two-day throwaway protects nothing and costs real time.

The failure mode is cargo-culting: applying TDD everywhere because "we do TDD" rather than because it is the right tool. The result is a test suite full of tests for UI layout, mock-heavy tests that mirror implementation rather than behavior, and tests for spike code that was never meant to survive.

Aniche is direct about this in *Effective Software Testing*: knowing when not to test is as important as knowing how to test.

> [!info] Use TDD where the specification is stable enough to write before the code. Use exploratory coding where the goal is to discover what the specification should be.

@feynman

Trying to TDD your way through genuinely unknown territory is like writing a checklist for a journey whose destination you haven't decided yet — the discipline is real, but it's applied to the wrong problem.

@card
id: est-ch07-c011
order: 11
title: The "TDD is Dead" Debate
teaser: DHH's 2014 post "TDD is Dead. Long Live Testing." provoked a recorded debate with Kent Beck and Martin Fowler — and the disagreement revealed that most TDD arguments are really arguments about mocking and design, not about tests.

@explanation

In April 2014, David Heinemeier Hansson (DHH), creator of Ruby on Rails, published a post titled "TDD is Dead. Long Live Testing." He followed it with a second post, "Test-induced design damage." The core argument: TDD, specifically in its London-school mockist form, pressures developers into over-engineering their designs — adding layers of indirection (hexagonal architecture, ports and adapters, dependency injection everywhere) in service of testability rather than clarity.

DHH's specific complaint was that the need to mock the database during unit tests leads to an artificial separation of domain logic from persistence, producing architectures that are harder to read and change than the simple Rails model he preferred.

Kent Beck and Martin Fowler convened a series of recorded conversations with DHH to discuss the arguments directly. Three videos from May–June 2014 are available under the title "Is TDD Dead?" and are worth watching for how carefully the three separate the actual disagreements.

What the debate clarified:

- **DHH's critique was primarily of London-school TDD and mockist testing**, not of test-first coding itself. He continued writing tests — just after the code.
- **Beck acknowledged that TDD is not universally applicable** and that confidence and context matter more than rigid adherence.
- **The design damage critique has merit in specific contexts.** Adding a repository abstraction solely to mock a database in tests, when the application only ever uses one database, may produce complexity without benefit.
- **The debate did not resolve the classicist vs. London-school question** — it surfaced it for a broader audience.

What was wrong in DHH's framing: integration tests do not replace unit tests for testing algorithmic behavior, and "write tests after" consistently produces lower coverage of edge cases because the implementation has already narrowed your imagination of what can go wrong.

@feynman

The TDD is Dead debate was a disagreement about which room in the house to lock the door on — both sides agreed you need doors; they disagreed about where the burglar would come from.

@card
id: est-ch07-c012
order: 12
title: Mob TDD and Pair TDD
teaser: TDD practiced with two or more people — the driver writes the test, the navigator makes it pass, roles rotate — amplifies the design-feedback loop and surfaces disagreements about behavior before a line of production code exists.

@explanation

TDD is usually described as a solo discipline, but its design feedback is amplified in collaborative settings. Pair TDD and mob TDD (also called ensemble programming) introduce a social dimension that changes the dynamics significantly.

**Pair TDD — Ping Pong:** One programmer writes a failing test. The other writes the minimum production code to make it pass. The first programmer then refactors, writes the next test, and the pattern continues. Roles alternate on each cycle.

The effect: the person writing the test must articulate what they expect before the implementation exists, forcing clarity. The person writing the production code cannot gold-plate because the test defines exactly what "done" means. Disagreements about design surface at the test level — "your test assumes X but I think the behavior should be Y" — before any implementation has hardened.

**Mob TDD:** The entire team (three to eight people) works on a single computer. One person is the Driver (typing). Others are Navigators (giving direction). Roles rotate frequently — every seven to fifteen minutes in most formats. Everyone sees every test and every design decision in real time.

The social dynamics are specific to TDD:

- Writing a test in front of the team makes the intended behavior explicit and discussable. Misunderstandings surface immediately.
- Disagreements about mocking vs. real collaborators force the classicist vs. London-school tension into the open where the team must actually resolve it.
- The refactor step is harder to skip when five people are watching and someone can say "we still have duplication here."

Mob TDD is particularly effective for onboarding new team members to both the codebase and the TDD discipline simultaneously — the new person can drive while experienced navigators guide, making the tacit rules explicit.

> [!tip] Mob TDD sessions of two to three hours on a well-defined feature are a faster way to build shared design understanding than code reviews after the fact.

@feynman

Pair TDD is like two people assembling furniture together where one reads the instructions aloud and the other does the assembly — the reading forces clarity about what comes next before any bolt is turned.
