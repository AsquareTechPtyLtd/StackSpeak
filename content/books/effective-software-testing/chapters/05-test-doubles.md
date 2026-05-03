@chapter
id: est-ch05-test-doubles
order: 5
title: Test Doubles
summary: Test doubles — dummies, fakes, stubs, mocks, spies — replace real dependencies with controlled stand-ins, and the difference between the five kinds (Gerard Meszaros's xUnit Patterns vocabulary) determines whether tests stay maintainable or become hostage to the implementation.

@card
id: est-ch05-c001
order: 1
title: The Test Doubles Vocabulary
teaser: Gerard Meszaros coined the term "test double" in *xUnit Test Patterns* to cover all the ways you replace a real collaborator with a controlled stand-in — and using the precise term matters because each kind has different tradeoffs.

@explanation

Before Meszaros gave them a unified vocabulary, teams reached for the word "mock" to mean everything from an object that returns hardcoded values to one that asserts specific calls were made. That imprecision leads to arguments about testing philosophy that are actually just arguments about terminology.

In *xUnit Test Patterns* (Addison-Wesley, 2007), Meszaros defined five distinct roles:

- **Dummy** — passed in but never actually called; fills a required parameter.
- **Fake** — a simplified but working implementation (an in-memory database, a fake clock).
- **Stub** — returns canned responses to specific queries; no verification.
- **Mock** — pre-programmed with expectations; verifies calls were made correctly.
- **Spy** — records what it was called with so you can assert after the fact.

Martin Fowler's 2004 essay "Mocks Aren't Stubs" (martinfowler.com) brought this vocabulary to wide attention. It remains the clearest short treatment of why the distinctions matter. The five types form a spectrum from "I don't care about this dependency at all" (dummy) to "I want to verify exactly how this dependency was used" (mock and spy).

Using the correct term in code review cuts through a lot of noise. When someone says "that test has too many mocks," it's worth asking: do they mean mocks specifically, or test doubles in general?

> [!info] The canonical sources are Meszaros's *xUnit Test Patterns* for definitions and Fowler's "Mocks Aren't Stubs" essay for the philosophical split between classical and mockist TDD. Both are worth reading in full.

@feynman

A test double is a stunt performer standing in for the real actor — there are five different kinds of stunt work, and calling them all "the stuntman" obscures what each one is actually doing.

@card
id: est-ch05-c002
order: 2
title: Dummy
teaser: A dummy is an object passed to satisfy a required parameter that is never actually called during the test — the simplest possible stand-in, and usually a sign that a method has too many parameters.

@explanation

Dummies exist purely to make the compiler happy. They satisfy a required argument, but the code under test never actually invokes them.

```java
// Java — testing an OrderProcessor that requires a Logger,
// but this test path never logs anything
class OrderProcessorTest {
    @Test
    void appliesDiscountToEligibleOrder() {
        Logger dummyLogger = mock(Logger.class); // never called
        var processor = new OrderProcessor(dummyLogger);

        Money result = processor.applyDiscount(new Order(100_00), "SAVE10");

        assertThat(result.cents()).isEqualTo(90_00);
    }
}
```

In Python with `unittest.mock`, a dummy is often just `None` or `MagicMock()` that the code path never touches:

```python
def test_applies_discount():
    dummy_logger = MagicMock()  # never invoked on this path
    processor = OrderProcessor(logger=dummy_logger)
    assert processor.apply_discount(order=Order(10000), code="SAVE10") == 9000
```

Dummies are the least interesting test double, but they reveal something useful about design: if a constructor demands five collaborators and a test only exercises one code path, the object probably has too many responsibilities. A dummy is sometimes a smell before it is a solution.

@feynman

A dummy is the cardboard cutout you put in the passenger seat so the carpool lane sensor is satisfied — it's there, but it never does anything.

@card
id: est-ch05-c003
order: 3
title: Fake
teaser: A fake is a real, working implementation built to be fast and simple — an in-memory database instead of PostgreSQL, a fixed clock instead of the system clock — and it lets you test logic that genuinely depends on the collaborator's behavior.

@explanation

Unlike a stub (which just returns canned values) or a mock (which just records calls), a fake actually does the work — it just does a simplified version of it. The canonical examples are:

- An in-memory `UserRepository` that stores records in a `HashMap` instead of a real database.
- A `FakeClock` that returns a configurable fixed instant instead of `LocalDateTime.now()`.
- An in-memory message broker that delivers messages synchronously, without Kafka's networking and partitioning.

```java
// Java — FakeClock satisfies a Clock interface
class FakeClock implements Clock {
    private Instant now;

    FakeClock(Instant now) { this.now = now; }

    @Override public Instant instant() { return now; }
    public void advance(Duration d) { now = now.plus(d); }
}

@Test
void expiresSessions_afterThirtyMinutes() {
    var clock = new FakeClock(Instant.parse("2024-06-01T10:00:00Z"));
    var manager = new SessionManager(clock);
    var session = manager.create("user-42");

    clock.advance(Duration.ofMinutes(31));

    assertThat(manager.isExpired(session)).isTrue();
}
```

Fakes carry a maintenance cost that dummies and stubs don't: they contain logic, and that logic can be wrong. A fake repository that doesn't enforce unique constraints will allow tests to pass that fail in production. Steve Freeman and Nat Pryce (in *Growing Object-Oriented Software, Guided by Tests*) recommend testing the fake itself against the contract of the real implementation using a shared set of contract tests.

> [!warning] A fake with incorrect behavior is worse than no fake — it gives your tests confidence they haven't earned. Write contract tests to verify the fake satisfies the same behavioral contract as the real dependency.

@feynman

A fake is a movie prop that actually works — the gun fires real blanks, the car really drives — it's just built for the set, not for the road.

@card
id: est-ch05-c004
order: 4
title: Stub
teaser: A stub returns pre-configured answers to specific queries — it's the right tool when your test needs to control what a dependency returns without caring whether that dependency was called at all.

@explanation

A stub says: "when asked this question, return this answer." It doesn't care whether the question was asked once, twice, or never. Verification is not its job.

```java
// Java with Mockito — stubbing a payment gateway
@Test
void marksOrderAsPaid_whenGatewaySucceeds() {
    PaymentGateway gateway = mock(PaymentGateway.class);
    when(gateway.charge("tok_visa", 5000)).thenReturn(new ChargeResult(true, "ch_123"));

    var service = new CheckoutService(gateway);
    Order result = service.checkout(new Order(5000), "tok_visa");

    assertThat(result.status()).isEqualTo(OrderStatus.PAID);
}
```

In Python:

```python
def test_marks_order_paid_when_gateway_succeeds():
    gateway = MagicMock()
    gateway.charge.return_value = ChargeResult(success=True, id="ch_123")

    service = CheckoutService(gateway=gateway)
    result = service.checkout(order=Order(5000), token="tok_visa")

    assert result.status == OrderStatus.PAID
```

The important constraint: stub only the queries your system under test actually makes. Stubbing everything preemptively couples your test to the implementation — if you stub `gateway.charge` even when testing a code path that never charges, you've created maintenance debt. Stub the minimum needed.

Stubs are often confused with mocks because the same library (Mockito, `unittest.mock`) sets them up. The distinction is intent: a stub controls inputs; a mock verifies outputs. A test that stubs and never asserts anything on the stub is using a stub correctly.

@feynman

A stub is the receptionist who gives you a scripted answer when you ask a specific question — she doesn't keep track of who called or whether anyone ever called, she just reads from the card.

@card
id: est-ch05-c005
order: 5
title: Mock
teaser: A mock is pre-programmed with expectations about which calls should be made — it fails the test if those calls aren't made correctly, making it the right tool for "behavior verification" rather than "state verification."

@explanation

Where a stub says "return this when called," a mock says "you must call me with these arguments, and if you don't, the test fails." Mocks shift the verification from checking state after the fact to checking the communication pattern between objects.

```java
// Java with Mockito — verifying an email service is called
@Test
void sendsWelcomeEmail_afterRegistration() {
    EmailService email = mock(EmailService.class);
    var service = new RegistrationService(email);

    service.register("user@example.com");

    verify(email).send(eq("user@example.com"), contains("Welcome"));
}
```

In .NET with Moq:

```csharp
[Fact]
public void SendsWelcomeEmail_AfterRegistration()
{
    var email = new Mock<IEmailService>();
    var service = new RegistrationService(email.Object);

    service.Register("user@example.com");

    email.Verify(e => e.Send("user@example.com", It.Is<string>(s => s.Contains("Welcome"))));
}
```

The risk with mocks: they couple the test to the exact communication pattern of the implementation, not just its observable outcome. If you refactor the internals — batching two email sends into one, or changing the argument order — the mock fails even though the feature still works correctly. This is the core tension Martin Fowler describes in "Mocks Aren't Stubs": mocks can drive out interfaces (good) or lock you into implementations (bad).

Use mocks where the interaction itself is the behavior you want to guarantee — sending an email, publishing an event, auditing a call. Avoid mocks where a state assertion on a return value would serve equally well.

> [!warning] Mocks that assert on the number of times a method was called with exact arguments tend to break during legitimate refactors. Prefer asserting on meaningful outcomes when you can; reach for call-count verification only when the call itself is the contract.

@feynman

A mock is a strict exam proctor who writes down exactly which questions the test must answer and in what order — if the test answers correctly but skips a required question, the proctor fails it anyway.

@card
id: est-ch05-c006
order: 6
title: Spy
teaser: A spy is a stub that records everything it was called with, letting you make assertions after the fact — it's less prescriptive than a mock because you decide what to verify after the system has run.

@explanation

A spy wraps a real (or fake) collaborator and records all calls to it. Unlike a mock, it doesn't fail immediately if expectations aren't met — the test runs to completion, and then you inspect the spy's record.

```java
// Java with Mockito — spy on a real list
@Test
void addsThreeItems_duringProcessing() {
    List<String> list = new ArrayList<>();
    List<String> spy = spy(list);

    processor.process(spy);

    verify(spy, times(3)).add(anyString());
    assertThat(spy).hasSize(3);
}
```

In JavaScript with Vitest:

```typescript
import { vi, expect, test } from 'vitest';
import { sendNotification } from './notifications';

test('notifies user after order confirmation', () => {
    const notifySpy = vi.spyOn(notificationService, 'notify');

    confirmOrder(orderId);

    expect(notifySpy).toHaveBeenCalledWith(userId, expect.stringContaining('confirmed'));
});
```

In Python with `unittest.mock`:

```python
def test_logs_each_retry():
    logger = MagicMock()
    client = RetryingHttpClient(logger=logger)

    client.get("https://example.com/flaky")

    assert logger.warning.call_count == 3
    logger.warning.assert_called_with("Retrying request, attempt 3")
```

Spies give you the best of both worlds — the test can still make state assertions on the result, and separately inspect the collaboration that took place. The tradeoff is that forgetting to assert on the spy makes it a no-op; unlike a mock, a spy with unchecked calls does not fail automatically.

@feynman

A spy is a recording device you place in the room before the meeting — it captures everything that was said, and afterward you review the tape to confirm the conversation went the way it should have.

@card
id: est-ch05-c007
order: 7
title: Classical vs Mockist TDD
teaser: The "Detroit school" tests state and uses real objects where possible; the "London school" tests communication between objects and uses mocks heavily — Martin Fowler named both schools and neither is universally right.

@explanation

Martin Fowler's "Mocks Aren't Stubs" essay (2004, revised 2007) named two distinct styles of TDD that had evolved independently:

**Classical TDD (the Detroit or Chicago school)**, associated with Kent Beck and the original XP community, works outside-in: you test the observable state of the system under test, using real collaborators when feasible and test doubles only at true boundaries (I/O, time, external services). The emphasis is on confidence that the whole thing works together.

**Mockist TDD (the London school)**, pioneered by Steve Freeman and Nat Pryce in *Growing Object-Oriented Software, Guided by Tests* (Addison-Wesley, 2009), uses mocks extensively even between internal collaborators. The rationale: mocking dependencies forces you to think about object responsibilities and communication protocols as you write code, not after. The test failures you get when an interface changes are considered valuable design signals.

The practical differences:

- Classical tests tend to be more robust during refactoring because they assert on outcomes, not on collaboration structure.
- Mockist tests tend to catch missing collaborations early and drive object design more explicitly, but are more brittle when implementation changes.
- Classical tests require real objects to be available and fast; mockist tests work even when real objects are expensive or slow.

Most working developers land somewhere in between: use real objects for fast, side-effect-free collaborators, and reach for mocks at external boundaries and when testing that a side-effecting call is made at all.

> [!info] Neither school is "correct." Mauricio Aniche's *Effective Software Testing* (Manning, 2022) recommends a pragmatic blend: prefer integration tests for persistence, use mocks at I/O and external-service boundaries, and reserve mockist-style behavior verification for genuine interaction contracts.

@feynman

Classical TDD checks that the cake tastes right; mockist TDD checks that the baker followed the recipe exactly — both are valid ways to verify quality, and a professional baker does some of each.

@card
id: est-ch05-c008
order: 8
title: When to Mock and When to Use a Real Dependency
teaser: The decision to mock comes down to one question: does crossing this boundary make the test slow, nondeterministic, or hard to set up — and if the answer is no, a real dependency is almost always better.

@explanation

The instinct to mock every collaborator leads to a test suite that passes reliably while the integrated system fails in ways no individual test predicted. The instinct to never mock leads to slow, fragile tests that require a running database and active network connections to check a simple business rule.

A working decision framework:

**Mock (or stub) when the dependency:**
- Makes an outbound network call (payment processor, SMS gateway, external REST API)
- Has nondeterministic behavior (current time, random number generators, UUIDs)
- Is slow to set up or tear down (spinning up a real email server, provisioning infrastructure)
- Has side effects that are hard to clean up (sending actual emails in a test)

**Use the real dependency when:**
- It is a pure function or value object with no side effects
- It is in-process, fast, and deterministic (a sorting algorithm, a discount calculator, a validation rule)
- The interaction with it is what you're actually testing (database query correctness, SQL serialization)
- The fake or stub would require duplicating complex logic that could itself be wrong

```python
# Don't mock a simple in-process collaborator
def test_discount_applies_correctly():
    # PriceCalculator is pure — no I/O, no state, no side effects
    # Using the real object is strictly better than a stub
    calc = PriceCalculator()
    service = CheckoutService(calc)
    assert service.total(items=[Item(price=100)], code="10OFF") == 90
```

The integration cost question — how expensive is it to test with the real thing? — should drive the decision more than any philosophical stance on mocking.

@feynman

Deciding whether to mock a dependency is like deciding whether to use a practice partner or a real opponent — a practice partner is fine for rehearsing footwork, but you need a real opponent to know if your game-time strategy actually works.

@card
id: est-ch05-c009
order: 9
title: Don't Mock What You Don't Own
teaser: Mocking a third-party library directly ties your tests to the library's specific API shape, so when the library changes its interface your tests break even though your code is fine — wrap external dependencies first, then mock the wrapper.

@explanation

"Don't mock what you don't own" is a heuristic from Steve Freeman and Nat Pryce (*Growing Object-Oriented Software, Guided by Tests*). The rule: don't stub or mock types defined by a library you don't control.

The problem when you ignore it:

```java
// Fragile — mocking an AWS SDK type directly
@Test
void uploadsFileToBucket() {
    AmazonS3 s3 = mock(AmazonS3.class);  // we don't own AmazonS3
    when(s3.putObject(any(), any(), any(), any())).thenReturn(new PutObjectResult());

    new FileUploadService(s3).upload("key", content);

    verify(s3).putObject("my-bucket", "key", any(), any());
}
```

If AWS changes the SDK method signature from four arguments to a `PutObjectRequest` object, these tests fail — and they tell you nothing about whether your code actually handles S3 correctly.

The pattern that fixes it: define your own interface, implement it with the third-party library, and mock only your interface:

```java
interface ObjectStore {
    void put(String key, byte[] data);
}

class S3ObjectStore implements ObjectStore {
    private final AmazonS3 s3;
    // real S3 calls live here
    @Override public void put(String key, byte[] data) { ... }
}

@Test
void uploadsFile_throughObjectStore() {
    ObjectStore store = mock(ObjectStore.class); // we own this interface
    new FileUploadService(store).upload("key", content);
    verify(store).put("key", content);
}
```

Now the mock tests the boundary you defined. Your integration tests (which use a real `S3ObjectStore`) catch SDK API drift. Neither kind of test is doing the other's job.

> [!tip] Every third-party service your code talks to should have an adapter interface you own. The adapter is the seam — you mock the seam in unit tests and test the adapter itself in focused integration tests.

@feynman

Mocking a library you don't own is like rehearsing a script you didn't write — when the playwright changes the lines, every actor who memorized the old version is suddenly wrong.

@card
id: est-ch05-c010
order: 10
title: Mock Libraries by Ecosystem
teaser: Every major ecosystem has a dominant mock library — Mockito (Java), Moq (.NET), Vitest/Jest (JS/TS), unittest.mock (Python), RSpec doubles (Ruby) — and while their APIs differ, they all implement the same five archetypes.

@explanation

**Java — Mockito**

The most widely used mock library in the JVM ecosystem. Supports stubbing (`when(...).thenReturn(...)`), verification (`verify(...)`), argument matchers, `@Spy`, and `@Captor`. Works with JUnit 5 and TestNG.

```java
UserRepository repo = mock(UserRepository.class);
when(repo.findById(42L)).thenReturn(Optional.of(new User(42L, "alice")));
```

**C# / .NET — Moq**

Fluent lambda-based API. Strict vs loose mock modes. `It.IsAny<T>()` for argument matchers. `Mock<T>.Object` gets the proxied instance.

```csharp
var repo = new Mock<IUserRepository>();
repo.Setup(r => r.FindById(42)).Returns(new User(42, "alice"));
```

**JavaScript / TypeScript — Vitest and Jest**

`vi.fn()` / `jest.fn()` for standalone functions. `vi.spyOn()` for wrapping existing methods. `vi.mock()` for module-level replacement. Both libraries share largely identical APIs.

```typescript
const findById = vi.fn().mockResolvedValue({ id: 42, name: 'alice' });
```

**Python — unittest.mock**

Built into the standard library since Python 3.3. `MagicMock`, `patch` (decorator and context manager), `call` for asserting arguments.

```python
with patch('app.services.repo.find_by_id', return_value=User(42, 'alice')):
    result = service.get_profile(42)
```

**Ruby — RSpec Mocks**

Doubles (`double`, `instance_double`), `allow(...).to receive(...)` for stubs, `expect(...).to receive(...)` for mocks. `instance_double` verifies that the stubbed method actually exists on the class.

```ruby
repo = instance_double(UserRepository)
allow(repo).to receive(:find_by_id).with(42).and_return(User.new(42, 'alice'))
```

**JavaScript — Sinon.js**

The standalone alternative to Jest/Vitest for environments where you don't control the test runner. Separate `sinon.stub()`, `sinon.spy()`, and `sinon.mock()` types that map explicitly to Meszaros's vocabulary.

@feynman

Mock libraries are all different accents of the same language — each ecosystem says "when called, return this" in a slightly different way, but they're all translating the same five ideas.

@card
id: est-ch05-c011
order: 11
title: Test Double Smells
teaser: Over-mocked tests that verify call signatures instead of behavior, brittle mock chains that break on every refactor, and mocks that drive design in the wrong direction are the three most common signs that test doubles are hurting more than helping.

@explanation

Test doubles are tools, and like all tools they can be misused. The smells to watch for:

**Over-mocking.** When every collaborator is mocked, the test is effectively testing nothing but wiring. A test that stubs ten methods and verifies five calls is not testing behavior — it's transcribing the implementation.

```java
// Smell: this test breaks if you rename any internal method,
// even if the public behavior is unchanged
verify(validator).validate(order);
verify(taxCalculator).calculate(order, "US");
verify(inventoryService).reserve(order.items());
verify(auditLog).record(order, "PLACED");
verify(notifier).notify(order.customerId(), "ORDER_PLACED");
```

**Brittle mock chains.** When a mock returns a mock that returns another mock, the test is describing a particular call chain deep inside the implementation. These tests break whenever that chain changes — not when the feature breaks.

```java
// Smell: three levels of mock traversal
when(session.getTransaction().isActive()).thenReturn(true);
```

**Mocks driving design in the wrong direction.** Mockist TDD is supposed to let mocks discover interfaces. When you find yourself bending your production code to make it easier to mock — adding unnecessary interfaces, exposing internals, splitting objects arbitrarily — the tool is driving the design instead of supporting it.

**Tests that survive only because they mock.** If removing a mock would cause the test to talk to a real service that returns an error (because the feature is actually broken), the mock is hiding a real bug.

The test of whether your test doubles are healthy: if you refactor the internals of the system under test without changing its public behavior, how many tests break? The answer should be zero or very close to it.

> [!warning] Mock libraries make it frictionless to verify that `foo()` called `bar()` with exactly these arguments. That frictionlessness is a trap. Verification at that level of granularity is usually testing the implementation, not the contract.

@feynman

An over-mocked test is like a rehearsal where the director has scripted every actor's every gesture — it passes dress rehearsal perfectly and falls apart the moment someone improvises a single line.

@card
id: est-ch05-c012
order: 12
title: Test the Contract, Not the Implementation
teaser: The goal of a test double is to verify that the system under test honors its behavioral contract with collaborators — not to verify that it calls specific methods in a specific order, which is just a shadow of the current implementation.

@explanation

The most durable tests describe what the code is supposed to do — the contract — not how it currently does it. When a test is coupled to the implementation's call sequence, every refactor that preserves behavior but changes structure breaks the test. This is the central lesson of the behavior-verification school taken too far.

**Implementation-coupled test:**

```java
// Brittle — tests HOW, not WHAT
@Test
void processesPayment() {
    verify(validator).validate(order);
    verify(gateway).authorize(order.total(), card);
    verify(gateway).capture(authToken);
    verify(repository).save(order.withStatus(PAID));
    verify(eventBus).publish(new OrderPaidEvent(order.id()));
}
```

This test breaks if you combine `authorize` and `capture` into a single `charge` call, even if the feature works correctly.

**Contract-focused test:**

```java
// Durable — tests WHAT, uses doubles only where needed
@Test
void marksOrderPaidAndPublishesEvent_whenPaymentSucceeds() {
    when(gateway.charge(order.total(), card)).thenReturn(new PaymentResult(SUCCESS));
    var events = new FakeEventBus();

    service.placeOrder(order, card);

    assertThat(order.status()).isEqualTo(PAID);                   // state
    assertThat(events.published()).contains(new OrderPaidEvent(order.id())); // observable side effect
}
```

The second test uses a stub (the gateway) to control the input scenario and a fake (the event bus) to capture the observable side effect. It does not care about the internal sequence of calls. It will survive most refactors.

The principle generalizes: mock at the edges of your system, not in the middle of it. Verify the results that cross system boundaries — the email that was sent, the event that was published, the record that was persisted — not the intermediate method calls that produced those results.

Steve Freeman and Nat Pryce phrase it as: "only mock types you own, and only mock them at the places where responsibilities genuinely meet."

@feynman

Testing the contract means asking "did the order get marked paid and did the event go out?" — not "did the code call these seven methods in this order?", which is like grading a math student on their scratch work instead of their answer.
