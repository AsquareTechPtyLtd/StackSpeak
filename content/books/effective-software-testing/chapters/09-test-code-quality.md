@chapter
id: est-ch09-test-code-quality
order: 9
title: Test Code Quality
summary: Test code is code, and the same maintenance bar applies — but a few rules flip: DAMP beats DRY, redundancy is a feature, and abstraction is a trap. Learn the smells, the fixes, and what to look for when reviewing a test suite.

@card
id: est-ch09-c001
order: 1
title: Test Code Is Code
teaser: Test code lives in the same repository, survives the same refactorings, and rots the same way production code does — treating it as a second-class citizen is how you end up with a test suite nobody trusts.

@explanation

Mauricio Aniche makes this point plainly in *Effective Software Testing*: the moment you stop maintaining test code with the same discipline you apply to production code, the tests start lying to you. They pass when they shouldn't, fail when the reason is no longer relevant, and become so tangled with implementation details that any refactoring drags a hundred failing tests along with it.

The implication is not that test code and production code are identical — they have different goals, and some rules change. But the baseline expectations do not:

- **Tests can be too long.** A 200-line test method is not a test; it is a script nobody will read twice.
- **Tests can be poorly named.** `test1()` tells you nothing about what breaks when the test fails.
- **Tests can have bugs.** A test that always passes is worse than no test at all, because it creates false confidence.
- **Tests can be duplicated carelessly.** Copy-paste test setup that you modify in six places when the constructor changes is a maintenance tax, not a safety net.

Treating test code as a first-class citizen means: reviewing it with the same attention you give a pull request on a service, refactoring it when it gets messy, and deleting tests that are no longer earning their keep.

The unique tension is that test code quality trade-offs are sometimes different from production code trade-offs — and understanding which rules change, and why, is what this chapter is about.

@feynman

Test code is code: if you would not accept it in production with that name, that length, and that structure, you should not accept it in your test suite either.

@card
id: est-ch09-c002
order: 2
title: DAMP, Not DRY
teaser: In tests, Descriptive And Meaningful Phrases beat Don't Repeat Yourself — a little duplication that keeps each test self-contained and readable is worth more than a perfectly DRY suite that requires three files of context to understand a single failure.

@explanation

Tim Ottinger popularized the DAMP principle as a deliberate counter-weight to DRY in test code. DRY says: extract duplication into a shared abstraction. DAMP says: duplication in tests is often not a problem — it is a feature.

Here is why. When a test fails, the first question is: what was the test doing? If the setup lives in a `@BeforeEach`, the fixtures in a builder class, and the assertion helpers in a utility, you are now reading three or four files to reconstruct what the test was asserting and why. The cognitive overhead compounds every time a test fails.

Compare:

```swift
// DRY — setup extracted, but now you need to find UserFixtures to understand this test
func test_blockedUserCannotLogin() {
    let user = UserFixtures.blockedUser()
    let result = authService.login(user)
    XCTAssertFalse(result.success)
}

// DAMP — slightly repetitive, but the test tells its whole story
func test_blockedUserCannotLogin() {
    let user = User(
        email: "blocked@example.com",
        status: .blocked,
        passwordHash: "hashed-secret"
    )
    let result = authService.login(credentials: .init(email: user.email, password: "secret"))
    XCTAssertFalse(result.success)
    XCTAssertEqual(result.failureReason, .accountBlocked)
}
```

The DAMP version takes more lines. It also tells you exactly what a "blocked user" means for this test, without forcing you to read a fixture file.

The honest tradeoff: DAMP does not mean "never extract." If setup code changes in twelve identical copies when a constructor changes, that is genuine DRY pain worth addressing. The judgment call is whether the extraction helps readability or hurts it.

> [!tip] Apply the "failure readability" test: when this test fails at 2 AM, will the developer on call understand what it was testing just by reading the test method — without jumping to three other files?

@feynman

DAMP says: in a test, it is better to repeat yourself clearly than to be terse in a way that forces the reader to hunt for context when the test breaks.

@card
id: est-ch09-c003
order: 3
title: The AAA Pattern
teaser: Arrange / Act / Assert gives every test a canonical three-part structure — and when a test violates that structure, it is almost always a symptom that the test is doing too much.

@explanation

The AAA pattern (sometimes called Given / When / Then in BDD style) is the most widely adopted structural convention in unit testing. Every test has exactly three sections:

- **Arrange** — set up the system under test and its dependencies in the state the test requires.
- **Act** — invoke the one behavior being tested.
- **Assert** — verify the outcome.

```swift
func test_checkout_appliesDiscountWhenCouponIsValid() {
    // Arrange
    let cart = Cart(items: [Item(price: 100)])
    let coupon = Coupon(code: "SAVE10", discountPercent: 10)

    // Act
    let total = checkout.calculateTotal(cart: cart, coupon: coupon)

    // Assert
    XCTAssertEqual(total, 90)
}
```

The structure enforces a useful discipline: a test with two `Act` sections probably needs to be split into two tests. A test with `Assert` calls interleaved with `Act` calls is hiding a stateful scenario that is better modeled explicitly.

Common violations:

- **Act/Assert/Act/Assert** — the test is actually two tests stitched together.
- **Arrange that spans half the file** — the system under test has too many dependencies, or the test is asserting on a scenario that requires too much state.
- **No explicit Act** — the test calls several methods and asserts on accumulated state; it is testing a workflow, not a behavior.

A single blank line between sections is enough to make the structure visible without comments. Some teams annotate with `// Arrange`, `// Act`, `// Assert` when the sections are long.

@feynman

AAA gives every test the same three sentences: here is the world, here is the thing I did, here is what I expected to happen.

@card
id: est-ch09-c004
order: 4
title: Descriptive Test Names
teaser: A good test name is a sentence describing behavior — when the test fails, the name alone should tell you what broke, under what condition, and what the expected outcome was.

@explanation

Aniche recommends a naming convention that encodes three things: what the method or system does, what condition triggers that behavior, and what the expected result is.

A popular form is: `should_<result>_when_<condition>`.

```swift
// Bad names
func testFilter() { ... }
func test2() { ... }
func testEdgeCase() { ... }

// Good names
func should_returnEmptyList_when_filterMatchesNothing() { ... }
func should_throwInvalidCoupon_when_couponIsExpired() { ... }
func should_preserveOrder_when_sortingWithEqualKeys() { ... }
```

The payoff shows up in two moments:

1. **During code review** — reading the list of test names should read like a specification of the system's behavior. If it does not, the test suite is incomplete or badly named.
2. **During failure** — a CI pipeline that reports `test2 FAILED` tells you nothing. `should_returnEmptyList_when_filterMatchesNothing FAILED` tells you exactly which behavior broke and where to look.

Some teams use a slightly different form: `givenX_whenY_thenZ`. The exact template matters less than the discipline of making the name a complete behavioral statement.

One constraint: do not embed implementation detail in the test name. `should_callRepositorySaveOnce_when_userIsCreated` is coupling the test name to the implementation. Prefer `should_persistNewUser_when_registrationSucceeds` — the behavior, not the mechanism.

> [!tip] If you find it hard to write a descriptive name, that is often a signal the test is asserting on the wrong thing, or testing too many things at once.

@feynman

A good test name is a one-line specification of a behavior: what the system does, under what condition, and what the outcome should be.

@card
id: est-ch09-c005
order: 5
title: Test Smells — The Catalog
teaser: Gerard Meszaros catalogued the recurring patterns of bad tests in xUnit Test Patterns — knowing the names gives you a shared vocabulary for code review and a checklist for self-review.

@explanation

In *xUnit Test Patterns* (2007), Gerard Meszaros named and described dozens of recurring patterns of poorly structured test code. The term "test smell" mirrors the production code concept of code smells — a structural property that indicates potential problems without being a bug in itself.

The most common smells in practice, and what they signal:

- **Assertion Roulette** — multiple unrelated assertions in one test body; you know something failed but not which assertion, or why.
- **Mystery Guest** — the test depends on external state (a file, a database row, a global variable) set up somewhere else; reading the test alone gives you no idea what it is doing.
- **Eager Test** — one test asserts on too many behaviors; it is a suite disguised as a test.
- **Fragile Fixture** — shared test setup that causes unrelated tests to break when any one behavior changes.
- **Test Interdependence** — tests that only pass when run in a specific order because they share mutable state.
- **Obscure Test** — a test that is syntactically correct but impossible to read because the intent is buried.
- **Lazy Test** — tests that always pass because the assertion is trivially satisfied (e.g., asserting a list is not nil rather than asserting its contents).

The catalog is not a rule set — it is a vocabulary. Meszaros's point is that when you can name what is wrong, the fix becomes much clearer.

@feynman

Test smells are named patterns of bad test structure — knowing the names means you can diagnose and discuss a problem precisely instead of just saying "this test is hard to read."

@card
id: est-ch09-c006
order: 6
title: Assertion Roulette
teaser: When a test has a dozen assertions and one fails, you know the test is broken but not which behavior caused it — and the fix is almost always splitting the test, not grouping assertions better.

@explanation

Assertion Roulette is Meszaros's name for a test with multiple independent assertions where a failure in assertion three hides assertions four through twelve — and where the failure message gives you only "expected true, was false" with no indication of which behavior broke.

```swift
// Assertion roulette: which assertion caused the failure?
func test_userProfile() {
    let profile = profileService.load(userId: "u1")
    XCTAssertEqual(profile.name, "Alice")
    XCTAssertEqual(profile.email, "alice@example.com")
    XCTAssertTrue(profile.isVerified)
    XCTAssertEqual(profile.tier, .pro)
    XCTAssertFalse(profile.isDeleted)
}

// Better: one assertion per behavioral concern
func should_returnCorrectName_when_loadingExistingUser() {
    let profile = profileService.load(userId: "u1")
    XCTAssertEqual(profile.name, "Alice")
}

func should_returnVerifiedStatus_when_userHasCompletedVerification() {
    let profile = profileService.load(userId: "u1")
    XCTAssertTrue(profile.isVerified)
}
```

The honest nuance: a single test asserting multiple properties of one return value is not always bad. If you are asserting that an `Address` struct has the correct street, city, and postal code, those three assertions belong together — they describe one thing. The smell is multiple independent behavioral assertions in a single test method, where a failure in any one hides the others.

> [!info] Swift Testing's `#expect` macro runs all assertions in a test before reporting, which reduces but does not eliminate the assertion roulette problem. The structural discipline of one behavior per test still matters.

@feynman

Assertion roulette means: if the test has ten assertions and fails, you know something is wrong, but not which behavior broke or whether the rest would have passed.

@card
id: est-ch09-c007
order: 7
title: Mystery Guest
teaser: A Mystery Guest is fixture data or external state that the test depends on but does not create — the test reads correctly but only passes because something invisible set up the world the right way first.

@explanation

Meszaros named this smell after the old game show format: a guest appears and everyone must guess who they are. In tests, the mystery guest is the entity whose presence is assumed but never introduced.

```swift
// Mystery guest: where does the user with id "u42" come from?
func test_dashboardLoadsForPremiumUser() {
    let viewModel = DashboardViewModel(userId: "u42")
    viewModel.load()
    XCTAssertTrue(viewModel.hasPremiumFeatures)
}
```

This test passes only because a user with id `u42` with premium status exists somewhere — in a database, in a JSON fixture file loaded by a setup method, in a shared test helper, somewhere. Reading the test alone, you have no idea why `hasPremiumFeatures` should be true.

The fix is to construct the necessary state explicitly inside the test, or to make the dependency on external data visible and named:

```swift
func should_showPremiumFeatures_when_userHasPremiumTier() {
    // Arrange — explicitly constructed, no mystery
    let user = User(id: "u42", tier: .premium)
    let repo = InMemoryUserRepository(users: [user])
    let viewModel = DashboardViewModel(userId: "u42", repository: repo)

    // Act
    viewModel.load()

    // Assert
    XCTAssertTrue(viewModel.hasPremiumFeatures)
}
```

The root cause of mystery guests is usually shared fixture setup that accumulates over time. Each new test borrows a little more from the shared state, until no individual test is understandable without reading the entire test class.

@feynman

A mystery guest is when your test depends on data that nobody introduced in the test — it just appears from somewhere, and reading the test alone cannot tell you why the assertion should pass.

@card
id: est-ch09-c008
order: 8
title: Eager Test
teaser: An eager test tries to verify too many behaviors in one method — it is effectively a test suite pretending to be a single test, and splitting it is almost always the right refactoring.

@explanation

Meszaros's Eager Test smell describes a test that asserts on multiple independent behaviors of the system under test. It is the structural sibling of Assertion Roulette but distinct in cause: Assertion Roulette comes from too many assertions; Eager Test comes from too many acts.

```swift
// Eager test: testing the full lifecycle in one method
func test_shoppingCart() {
    var cart = Cart()

    // behavior 1: adding items
    cart.add(Item(name: "Book", price: 20))
    XCTAssertEqual(cart.itemCount, 1)

    // behavior 2: applying discount
    cart.applyCoupon(Coupon(discount: 5))
    XCTAssertEqual(cart.total, 15)

    // behavior 3: removing items
    cart.remove(at: 0)
    XCTAssertEqual(cart.itemCount, 0)
    XCTAssertEqual(cart.total, 0)
}
```

Each of those three sections is a separate concern. When `cart.total` fails, it may be because `applyCoupon` is broken, or because `add` left the cart in a bad state, or because the discount calculation itself is wrong. The eager structure obscures the diagnosis.

The refactoring is mechanical: split along the `// behavior N` seams, move each into its own named test method, give each its own arrange phase.

```swift
func should_incrementItemCount_when_itemIsAdded() { ... }
func should_subtractDiscountFromTotal_when_validCouponApplied() { ... }
func should_resetTotal_when_lastItemRemoved() { ... }
```

The tradeoff: splitting multiplies the number of test methods and requires repeating some setup. This is where DAMP over DRY is the right call — the repetition is worth the clarity.

@feynman

An eager test tests everything about a system in one method; when it fails, you do not know which behavior broke, and the test is too big to read as a single coherent story.

@card
id: est-ch09-c009
order: 9
title: Fragile Fixture
teaser: A fragile fixture is shared test setup that causes cascading failures when any one test's requirements change — the cure is to minimize shared state and construct only what each test actually needs.

@explanation

Fragile fixtures emerge from a well-intentioned impulse: avoid repeating setup by sharing it across all tests in a class. The `@BeforeEach` method (or Swift Testing's `init`) builds a large, complex object graph that all tests operate on. The problem is that the fixture eventually serves many tests' needs simultaneously, and changing it for one test breaks others.

```swift
// Shared fixture — one struct serves twelve tests
final class OrderServiceTests: XCTestCase {
    var service: OrderService!
    var user: User!
    var product: Product!
    var warehouse: Warehouse!

    override func setUp() {
        user = User(id: "u1", tier: .pro, creditLimit: 1000)
        product = Product(id: "p1", price: 50, stock: 10)
        warehouse = Warehouse(location: "EU", products: [product])
        service = OrderService(warehouse: warehouse)
    }
}
```

When a new test needs a user with zero credit, or a warehouse with no stock, the shared fixture no longer fits. The choices are bad: modify the shared setup and break the tests that relied on the original values, or add conditional logic to the fixture that makes it unreadable.

The alternative is to construct minimum sufficient state inside each test:

```swift
func should_rejectOrder_when_userExceedsCreditLimit() {
    let user = User(id: "u1", tier: .standard, creditLimit: 0)
    let product = Product(id: "p1", price: 50, stock: 10)
    let service = OrderService(warehouse: Warehouse(products: [product]))

    let result = service.placeOrder(userId: user.id, productId: product.id)

    XCTAssertEqual(result, .rejected(.insufficientCredit))
}
```

> [!warning] Shared setup is not bad by default — a three-line setUp that initializes a stateless service object is fine. The smell appears when the shared fixture encodes behavioral assumptions (the user has credit limit 1000) that belong to specific tests, not all of them.

@feynman

A fragile fixture is shared test setup that encodes assumptions specific to some tests — when those assumptions change for a new test, unrelated tests break because they all depended on the same setup.

@card
id: est-ch09-c010
order: 10
title: Test Interdependence
teaser: Tests that must run in a specific order to pass are hiding state leakage between tests — and the bugs they miss will only appear when a CI runner happens to run them in a different sequence.

@explanation

Test interdependence occurs when one test leaves mutable state behind that another test depends on, either explicitly (test A creates a record that test B queries) or accidentally (test A calls a singleton that test B assumes has its default state).

The insidious property of this smell is that it often goes undetected for months. Most test runners use a consistent ordering, so the dependency is satisfied every run. Then someone adds a new test, or the runner reorders for parallel execution, and a seemingly unrelated test starts failing.

Patterns that produce interdependence:

- **Shared in-memory state** — a singleton, a class-level variable, or a static cache that one test modifies and another reads.
- **External state** — a test writes to a database, file system, or network endpoint without cleaning up; the next test reads that residual state.
- **Incorrect setup/teardown** — setup only initializes, teardown only deletes; a test that fails mid-way leaves the environment dirty.

The fix is to make every test own and clean up its environment completely:

```swift
func test_A() {
    // Arrange
    let repo = InMemoryUserRepository() // fresh, not shared
    let service = UserService(repository: repo)

    // Act + Assert
    ...
} // repo goes out of scope; no shared state survives
```

For external state (database, file system), use transactions rolled back after each test, in-memory fakes, or a setUp/tearDown pair that is defensive — clean up at the start of setUp rather than relying on tearDown having run cleanly.

@feynman

Test interdependence means tests only pass in one specific order because they share mutable state; a test runner that changes the order reveals bugs that have been hiding in the suite for months.

@card
id: est-ch09-c011
order: 11
title: Refactoring Tests
teaser: When test code gets messy, you refactor it — but the mechanics are different, because you cannot use the tests to verify the test refactoring, so you must move in very small steps and rely on the test suite staying green as the safety net.

@explanation

Refactoring production code is safer when tests exist to catch regressions. Refactoring test code removes that safety net: you are changing the thing that is supposed to tell you when something breaks. This asymmetry demands a different approach.

The principles Aniche describes:

**Move in the smallest possible steps.** Extract one helper method, run the tests, confirm green before extracting the next. Do not rename, restructure, and inline all at once. Each individual step should be mechanically safe — a rename, a pure extraction, a move of identical code.

**Never change the assertion while refactoring.** The assertion is the test's contract. Changing what is asserted is not a refactoring — it is changing the specification. If you want to change what is asserted, that is a separate commit, separate review, and separate decision.

**Leave the behavior of the test unchanged.** A test refactoring that accidentally removes a negative assertion (e.g., a `XCTAssertFalse` that was redundant-looking but meaningful) can silently remove coverage. Diff the before and after at the assertion level, not just the structural level.

**Use test-specific helpers, not production helpers.** If you are extracting a `makeValidUser()` factory, put it in the test target — not in production code. Test-only helpers that leak into production code corrupt the separation of concerns.

The "sprout and wrap" techniques from Michael Feathers's *Working Effectively with Legacy Code* apply here too: rather than modifying a large existing test, sprout a new test alongside it and retire the old one once the new version is verified.

@feynman

Refactoring test code is harder than refactoring production code because the tests themselves are the safety net — you are working without a net, so every step must be small enough to be obviously correct.

@card
id: est-ch09-c012
order: 12
title: Test Code Review
teaser: Reviewing test code requires a different lens than reviewing production code — you are not just checking correctness, you are checking whether the tests will actually catch future bugs and whether a failure will be diagnosable.

@explanation

When reviewing production code, reviewers ask: does this work, is it readable, is it well-structured? When reviewing test code, those questions still apply, but a different set of questions matters more:

**Does the test actually test the stated behavior?**
A test can be syntactically correct and still test nothing meaningful. Check whether the assertion would fail if the behavior were broken. It is easy to write a test that exercises the code path but asserts on something that is always true.

**Does the test name match the test body?**
Drift between the name and the assertions is common when tests are modified without updating their names. A test named `should_returnNull_when_userNotFound` that now asserts a thrown exception is misleading.

**Is every assertion load-bearing?**
Each assertion should be there because a real production bug could violate it. Assertions that test implementation details (method call counts, intermediate variable values) are brittle and add noise to failure output.

**Would you be able to diagnose a failure from the test output alone?**
If the test fails in CI, does the failure message tell you what broke, what was expected, and what actually happened — without needing to read the test code?

**Are there missing negative cases?**
Reviewers often approve test suites that test only the happy path. Look for missing error cases, boundary values, and inputs the specification explicitly rejects.

**Is the test isolated?**
Check for dependencies on external state, class-level mutable variables, ordering assumptions, or calls to real network/database endpoints in a unit test.

These are the categories of feedback that are unique to test review. They do not replace the usual code review concerns — they add to them.

> [!tip] The single most useful question in test code review: "If this test started failing tomorrow, would the failure message alone tell me what broke?" If the answer is no, the test needs work before it merges.

@feynman

Reviewing test code means asking not just "is this correct?" but "will this test catch a real bug, and when it fails, will someone be able to diagnose it without reading the production code?"
