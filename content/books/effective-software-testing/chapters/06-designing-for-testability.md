@chapter
id: est-ch06-designing-for-testability
order: 6
title: Designing for Testability
summary: Testability is a design property — high cohesion, low coupling, dependency injection, and the explicit absence of hidden dependencies are the structural decisions that determine whether tests are easy or impossible to write.

@card
id: est-ch06-c001
order: 1
title: Testability Is Design
teaser: Code that is hard to test is not just an inconvenience — it is a signal that the design has a structural problem.

@explanation

The central insight from Misko Hevery's testability essays is that testability is not a feature you bolt on after the fact. It is a property that emerges from — and reveals — the structure of your code. When a class is difficult to instantiate in a test, when you need an elaborate setup to exercise one function, or when tests break every time an unrelated module changes, these are not testing problems. They are design problems made visible by the act of testing.

This framing matters because it changes how you respond to hard-to-test code:

- Hard to instantiate → the class has too many responsibilities or too many hidden dependencies.
- Hard to isolate → the module is tightly coupled to things it should not know about.
- Tests require real databases or real clocks → the code fails to treat I/O and time as explicit dependencies.
- Tests keep breaking for unrelated reasons → there is too much shared mutable state.

The good news is that the design improvements that make code testable — high cohesion, low coupling, explicit dependencies, small composable functions — are improvements that make code better in every other way too. Testability and good design point in the same direction.

> [!tip] If you find yourself reaching for reflection, inheritance tricks, or test-framework magic to get a class under test, stop and ask what the design is hiding. The test friction is a symptom; fix the design.

@feynman

Testable code and well-designed code are the same thing seen from different angles — if your code is hard to test, that is the code telling you something is wrong with how it is structured.

@card
id: est-ch06-c002
order: 2
title: High Cohesion
teaser: A cohesive class does one thing well — and that single focus is exactly what makes its tests focused, fast, and stable.

@explanation

Cohesion measures how related the responsibilities of a module are to each other. A highly cohesive class has one clear job; a low-cohesion class is a bag of loosely related behavior that happened to land in the same file.

From a testability perspective, cohesion matters because test scope follows responsibility scope. A class with one responsibility has tests that exercise one behavior in one context. A class with five responsibilities has tests that must account for the interactions between all five — exponentially more setup, more combinations, and more ways for an unrelated change to break a test.

The "single reason to change" heuristic from the Single Responsibility Principle (SRP) is a practical proxy for cohesion:

- A `UserService` that handles authentication, sends welcome emails, and writes audit logs has at least three reasons to change. Its tests must either cover all three or use heavy mocking to isolate them.
- Split into `AuthService`, `WelcomeEmailSender`, and `AuditLogger`, each class changes for one reason. Its tests are small, direct, and independent.

Low cohesion also produces a hidden cost: when a class does too much, the tests for one responsibility inadvertently depend on the implementation of another. A change to how audit logs are formatted should not break a test for authentication logic — but it will if both live in the same class.

```python
# Low cohesion — one class, three responsibilities
class UserService:
    def register(self, email, password):
        user = self._create_user(email, password)
        self._send_welcome_email(user)       # email logic here
        self._write_audit_log("registered")  # audit logic here
        return user

# High cohesion — each class does one thing
class UserRegistrar:
    def __init__(self, email_sender, audit_log):
        self.email_sender = email_sender
        self.audit_log = audit_log

    def register(self, email, password):
        user = self._create_user(email, password)
        self.email_sender.send_welcome(user)
        self.audit_log.record("registered", user)
        return user
```

@feynman

A cohesive class is like a specialist doctor — you know exactly what they treat, their tests stay focused on that specialty, and a change in cardiology does not affect the orthopedics ward.

@card
id: est-ch06-c003
order: 3
title: Low Coupling
teaser: Testable code has narrow, explicit dependencies — a class that knows too much about too many other classes cannot be tested without dragging all of them into the room.

@explanation

Coupling measures how much one module depends on the internals of another. High coupling means a change in module A forces changes in module B. From a testing perspective, high coupling means you cannot test A without also bringing B — and everything B depends on — into the test.

The practical symptoms of high coupling in tests:

- You need five imports and three database connections to test a function that does a simple calculation.
- Changing an unrelated class breaks dozens of tests in a module that never directly uses it.
- Setting up a test requires constructing a large object graph just to get to the one piece of behavior you care about.

Low coupling does not mean zero dependencies. It means that dependencies are:

- **Narrow** — the class depends on a small interface, not an entire concrete class with many methods.
- **Explicit** — dependencies are declared, not discovered at runtime through global state.
- **Replaceable** — in a test, you can substitute a lightweight fake without touching production wiring.

```typescript
// High coupling — depends on concrete EmailClient with 12 methods
class OrderService {
  private emailClient = new EmailClient(); // constructed internally

  completeOrder(order: Order): void {
    // ... process order
    this.emailClient.sendTransactionalEmail(
      order.user.email, "Your order is complete", /* ... */
    );
  }
}

// Low coupling — depends on a narrow interface
interface OrderNotifier {
  notifyOrderComplete(order: Order): void;
}

class OrderService {
  constructor(private notifier: OrderNotifier) {}

  completeOrder(order: Order): void {
    // ... process order
    this.notifier.notifyOrderComplete(order);
  }
}
```

In the second form, a test passes a stub `OrderNotifier` and never touches `EmailClient` at all.

@feynman

Low coupling is like using a standard electrical outlet — you can plug in any device that fits the socket without knowing or caring how the device is built internally.

@card
id: est-ch06-c004
order: 4
title: Dependency Injection
teaser: Dependency injection is the single most effective testability lever — pass dependencies in, never construct them inside.

@explanation

Dependency injection (DI) is the practice of providing a class with the objects it needs rather than letting the class construct them itself. This is the structural mechanism that makes low coupling and test isolation possible.

The before-and-after is stark:

```java
// Without DI — untestable in isolation
public class ReportGenerator {
    private final Database db = new Database("jdbc:mysql://prod-host:3306/reports");
    private final Clock clock = new SystemClock();

    public Report generate(String reportId) {
        Instant now = clock.now();
        List<Row> rows = db.query("SELECT * FROM data WHERE id = ?", reportId);
        return new Report(rows, now);
    }
}

// With DI — fully testable
public class ReportGenerator {
    private final Database db;
    private final Clock clock;

    public ReportGenerator(Database db, Clock clock) {
        this.db = db;
        this.clock = clock;
    }

    public Report generate(String reportId) {
        Instant now = clock.now();
        List<Row> rows = db.query("SELECT * FROM data WHERE id = ?", reportId);
        return new Report(rows, now);
    }
}
```

In the first version, you cannot test `generate()` without hitting a production database and using the real system clock. In the second, you pass in a fake `Database` returning fixed rows and a `FakeClock` returning a known instant. The test is fast, deterministic, and self-contained.

DI does not require a framework. Manual constructor injection — passing real dependencies in `main()` and fake dependencies in tests — is sufficient for most codebases and the most transparent form.

> [!tip] The rule is simple: if a class constructs a dependency with `new` (or an equivalent), that dependency cannot be replaced in a test. Use `new` only for value objects (data containers). Inject everything with behavior.

@feynman

Dependency injection is like a restaurant that lets you bring your own ingredients — the chef follows the same recipe, but you get to decide what goes in, which means you can test the recipe with predictable, controlled inputs.

@card
id: est-ch06-c005
order: 5
title: Constructor vs Setter vs Framework DI
teaser: Constructor injection is the default; setter injection is occasionally useful; framework DI is powerful but obscures wiring — know which to reach for and when.

@explanation

There are three common forms of dependency injection, each with different tradeoffs.

**Constructor injection** — dependencies are passed as constructor parameters and stored as fields.

- Dependencies are visible in the type signature.
- Objects are always fully initialized after construction — no partially-configured state.
- Immutable fields (`final` in Java, `let` in Swift) are natural.
- The preferred form for the vast majority of cases.

**Setter injection** — dependencies are provided through setter methods after construction.

- Allows optional dependencies (a class can function with or without a particular collaborator).
- Permits circular dependencies (A needs B, B needs A) — though circular dependencies are themselves a design smell.
- Objects can be in a partially initialized state if a setter is never called, which makes it easy to accidentally use an object before it is fully configured.
- Use sparingly, only when optional dependencies or framework constraints require it.

**Framework DI (Spring, Guice, Angular, NestJS, etc.)** — a DI container constructs objects and wires their dependencies automatically, often using annotations or configuration files.

- Eliminates boilerplate wiring in production code.
- Can make the dependency graph invisible — you must read container configuration or scan annotations to understand what gets injected where.
- Tests may need to spin up a partial or full container context, which reintroduces slow startup.
- Best practice: use the framework for production wiring; bypass it in unit tests by constructing objects manually with fakes.

```typescript
// Framework DI (NestJS) for production
@Injectable()
class OrderService {
  constructor(private readonly notifier: OrderNotifier) {}
}

// Manual constructor injection in the test — no framework needed
const fakeNotifier = new FakeOrderNotifier();
const service = new OrderService(fakeNotifier);
```

@feynman

Constructor injection hands you all the tools you need before the job starts; setter injection lets you swap tools mid-job; a DI framework is a tool belt that assembles itself — convenient, but you need to know what is in it.

@card
id: est-ch06-c006
order: 6
title: Hidden Dependencies
teaser: Static state, singletons, and global mutable state are the testability killers — they make tests order-dependent, non-repeatable, and impossible to isolate.

@explanation

A hidden dependency is one that does not appear in a class's constructor or method signature but is consumed by the class at runtime. The three most damaging forms are static state, singletons, and global mutable state.

**Why they harm testability:**

- Tests cannot replace them with fakes, because there is no seam — no parameter where an alternative could be passed.
- State from one test leaks into the next, making tests order-dependent and non-repeatable.
- Parallel test execution is broken, because multiple tests mutate the same global object concurrently.

```java
// Hidden dependency via static singleton — untestable
public class PaymentProcessor {
    public boolean process(Payment payment) {
        DatabaseConnection conn = DatabaseConnection.getInstance(); // global singleton
        Logger.log("Processing payment"); // static global logger
        return conn.execute(payment.toSQL());
    }
}

// Explicit dependencies — testable
public class PaymentProcessor {
    private final Database db;
    private final Logger logger;

    public PaymentProcessor(Database db, Logger logger) {
        this.db = db;
        this.logger = logger;
    }

    public boolean process(Payment payment) {
        logger.log("Processing payment");
        return db.execute(payment.toSQL());
    }
}
```

Misko Hevery's "Singletons are Pathological Liars" essay names this precisely: a class that uses a singleton appears to have no dependencies when reading its constructor, but it hides a web of dependencies that the test runner must set up correctly or risk poisoning the test suite.

> [!warning] Global mutable state shared across tests is the most common root cause of flaky test suites. The fix is not better test ordering — it is making the dependency explicit and injectable.

@feynman

A hidden dependency is like a coworker who secretly relies on a shared whiteboard that nobody else knows about — everything works fine until someone erases it, and then you have a mysterious failure with no obvious cause.

@card
id: est-ch06-c007
order: 7
title: Time and Randomness as Dependencies
teaser: A function that calls `new Date()` or `Math.random()` internally is non-deterministic by definition — inject a Clock and a random source, and it becomes testable.

@explanation

Time and randomness are two of the most common sources of non-deterministic tests. When a function reaches out to the system clock or a global RNG, the result differs on every call. You cannot write an assertion about "the expiry date is 30 days from now" without either freezing real time or accepting that the test is fragile.

The fix is the same as for any hidden dependency: make it explicit and injectable.

```typescript
// Non-deterministic — cannot be tested reliably
class SessionManager {
  createSession(userId: string): Session {
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    const token = Math.random().toString(36).slice(2);
    return { userId, token, expiresAt };
  }
}

// Deterministic — fully testable
interface Clock {
  now(): Date;
}

interface TokenGenerator {
  generate(): string;
}

class SessionManager {
  constructor(
    private clock: Clock,
    private tokenGen: TokenGenerator,
  ) {}

  createSession(userId: string): Session {
    const expiresAt = new Date(this.clock.now().getTime() + 30 * 24 * 60 * 60 * 1000);
    const token = this.tokenGen.generate();
    return { userId, token, expiresAt };
  }
}

// In test:
const fixedClock = { now: () => new Date("2025-01-01T00:00:00Z") };
const fixedToken = { generate: () => "test-token-abc" };
const manager = new SessionManager(fixedClock, fixedToken);
const session = manager.createSession("user-1");
// session.expiresAt is exactly 2025-01-31T00:00:00Z — assertable
```

Java's `java.time.Clock`, Python's `freezegun`, and similar abstractions exist precisely because this pattern is universal. The production wiring passes `SystemClock.instance()`; tests pass a fixed clock.

@feynman

A function that checks the real clock is like a quiz whose correct answer changes depending on what time you take it — inject a fixed clock and the answer is always the same, regardless of when the test runs.

@card
id: est-ch06-c008
order: 8
title: I/O as a Dependency
teaser: File system access, network calls, and environment variable reads are I/O — they belong behind an interface so tests never touch the real thing.

@explanation

I/O is the broadest category of hidden dependency. Any operation that touches something outside the process — a file, a socket, a database, an environment variable — is I/O. When business logic is entangled with I/O, you cannot test the logic without also executing the I/O.

The structural solution is to push I/O to the edges of your system and represent it behind an interface in the interior.

```python
# I/O entangled with logic — untestable without real file system
def load_config_and_start(config_path: str) -> App:
    with open(config_path) as f:            # real file system
        raw = json.load(f)
    port = int(os.environ["PORT"])          # real env var
    config = AppConfig(host=raw["host"], port=port)
    return App(config)

# I/O separated — logic is testable with any config source
class ConfigLoader:
    def load(self) -> AppConfig: ...        # interface

class FileConfigLoader(ConfigLoader):
    def __init__(self, path: str, env: dict):
        self.path = path
        self.env = env

    def load(self) -> AppConfig:
        with open(self.path) as f:
            raw = json.load(f)
        return AppConfig(host=raw["host"], port=int(self.env["PORT"]))

def start(loader: ConfigLoader) -> App:
    config = loader.load()
    return App(config)

# In test:
class FakeConfigLoader(ConfigLoader):
    def load(self) -> AppConfig:
        return AppConfig(host="localhost", port=8080)

app = start(FakeConfigLoader())
```

The test exercises `start()` — the function with the startup logic — without touching a real file or a real environment variable. The `FileConfigLoader` gets its own, simpler test that checks it reads files correctly. Each piece is testable independently.

Environment variables deserve special mention. Reading `os.environ["PORT"]` inside a function creates a hidden dependency on the process environment. Passing `env: dict` as a parameter — defaulting to `os.environ` in production — makes the dependency explicit and replaceable.

@feynman

Treating I/O as a dependency is like building a machine with a standardized input slot — the machine does not care whether you feed it real material from the factory or a sample from the lab, as long as it fits the slot.

@card
id: est-ch06-c009
order: 9
title: Pure Functions as the Gold Standard
teaser: A pure function — no I/O, no side effects, same output for same input — is the most testable unit of code that exists.

@explanation

A pure function takes inputs, computes a result, and returns it. It reads nothing from outside its parameters, writes nothing to the world, and produces the same output every time it is called with the same arguments. This makes it trivially testable: call it with known inputs, assert on the output, done.

```python
# Pure — no I/O, no side effects, deterministic
def calculate_discount(price: float, user_tier: str) -> float:
    rates = {"standard": 0.0, "premium": 0.10, "enterprise": 0.20}
    rate = rates.get(user_tier, 0.0)
    return round(price * (1 - rate), 2)

# Test — no setup, no mocks, no teardown
assert calculate_discount(100.0, "premium") == 90.0
assert calculate_discount(100.0, "standard") == 100.0
assert calculate_discount(100.0, "unknown") == 100.0
```

Pure functions can be tested in parallel, in any order, without fixtures, without database cleanup, and without anything beyond the language runtime.

The design implication is to push as much logic as possible into pure functions and confine side effects (writing to a database, sending an email, mutating state) to a thin outer shell. This is the architecture of hexagonal architecture and functional core / imperative shell:

- **Functional core:** pure functions doing all the calculation, validation, and decision-making.
- **Imperative shell:** thin layer performing I/O, calling the core, and persisting results.

The core is fully testable with unit tests. The shell is thin enough that integration tests cover it adequately without needing a large suite of slow tests.

> [!info] The more of your business logic you can move into pure functions, the smaller and cheaper your test suite becomes. I/O-heavy code is expensive to test; pure code is free.

@feynman

A pure function is like a math formula — give it the same numbers, get the same answer every time, with no side effects to clean up afterward.

@card
id: est-ch06-c010
order: 10
title: The Test-First Effect on Design
teaser: You do not need strict TDD to benefit from asking "how will I test this?" before writing — that question alone reshapes the design toward testability.

@explanation

Test-Driven Development (TDD) enforces a test-first discipline: write a failing test, write the minimum code to pass it, refactor. One of the well-documented side effects of TDD is that it produces more testable designs — not because TDD has magic properties, but because writing the test first forces you to think about the class's interface, its dependencies, and how an external caller interacts with it before you think about the implementation.

You can capture much of this benefit without strict TDD by adopting the habit of asking, before writing a class, "How will I test this?" That single question tends to surface:

- Dependencies that would otherwise be hidden (you realize you need to inject them to test).
- Methods that are too large to test directly (you break them into smaller pieces).
- Responsibilities that are tangled together (you separate them to test each in isolation).

The question also discourages design patterns that are testability anti-patterns — long setup chains, constructor overloading to create "test modes," and protected methods exposed only for testing.

An alternative framing from behavior-driven design: before writing a class, write the sentence "Given [initial state], when [action], then [expected outcome]." If you cannot write that sentence cleanly, the design of the class is unclear. Clarity in the test premise usually corresponds to clarity in the design.

```java
// Before writing the class, ask: what do I need to test?
// "Given a cart with two items, when I apply a 10% discount code,
//  then the total is reduced by 10%."
// This tells you: Cart should not fetch discount rates from the DB itself.
// The rate should be passed in, or looked up via an injected interface.

class Cart {
    Cart(List<Item> items, DiscountPolicy discountPolicy) { ... }
    Money total(String discountCode) { ... }
}
```

@feynman

Asking "how will I test this?" before writing code is like asking "how will I change a tire?" before buying a car — it surfaces requirements that are invisible until you are stranded on the side of a road.

@card
id: est-ch06-c011
order: 11
title: Testability Anti-Patterns
teaser: Long methods, deep hierarchies, many constructor parameters, and protected methods exposed only for tests are structural signals that the design needs rework — not the tests.

@explanation

Several recurring code shapes make testing hard. Recognizing them by name helps you identify them quickly and respond with the right refactoring rather than a testing workaround.

**Long methods** — a method with 80 lines of logic has many implicit branches, many combinations to cover, and no clean seam to test a sub-behavior in isolation. Break it into smaller, well-named private methods (which become candidates for extraction into their own classes if they grow further).

**Deep inheritance hierarchies** — when a class inherits from a class that inherits from a class, a test for the leaf class must understand and satisfy constraints from all ancestors. Prefer composition over inheritance for behavior reuse.

**Many constructor parameters (constructor bloat)** — a constructor with eight parameters is a sign that the class has too many responsibilities. It also makes tests verbose and fragile: adding a ninth parameter breaks every test that constructs the class. Extract cohesive parameter groups into value objects; split responsibilities into separate classes.

**Protected methods exposed for testing** — the pattern of making a private method protected so a test subclass can call it is a design smell disguised as a test technique. If the behavior is worth testing, extract it into a separate class where it can be tested directly and publicly.

**Static utility classes with mutable state** — a static class that caches results or holds configuration is a hidden dependency factory. The fix is to make it a proper injectable service.

```python
# Anti-pattern: protected method exposed only for testing
class DataProcessor:
    def process(self, data: list) -> list:
        cleaned = self._clean(data)       # private
        return self._transform(cleaned)   # private

    def _clean(self, data: list) -> list: ...   # made 'protected' for tests — wrong

# Better: extract into a testable collaborator
class DataCleaner:
    def clean(self, data: list) -> list: ...    # public, directly testable

class DataTransformer:
    def transform(self, data: list) -> list: ...

class DataProcessor:
    def __init__(self, cleaner: DataCleaner, transformer: DataTransformer): ...
    def process(self, data: list) -> list: ...
```

@feynman

Testability anti-patterns are warning signs built into the code itself — the way a long method makes your eyes glaze over is the same property that makes tests for it unmanageable.

@card
id: est-ch06-c012
order: 12
title: Trading Off Testability
teaser: Testability is not free and not always the highest priority — performance constraints, framework idioms, and genuine simplicity sometimes push in the other direction, and that tradeoff deserves to be made explicitly, not accidentally.

@explanation

The case for testability is strong, but treating it as an absolute rule produces its own problems. There are legitimate situations where full testability costs more than it is worth, and being honest about those tradeoffs is part of professional judgment.

**Performance constraints.** Dependency injection adds an indirection layer. In tight inner loops, virtual dispatch or interface calls can introduce measurable overhead. Inlining a concrete implementation for performance — and accepting that this particular path is tested through integration tests rather than unit tests — can be the right call. Document the decision.

**Framework idioms.** Some frameworks are not designed with DI-first testability in mind. Fighting a framework's conventions to achieve perfect unit testability often produces code that is harder to read, harder to maintain, and unfamiliar to new team members. It is sometimes better to align with framework idioms and cover those paths with integration or end-to-end tests.

**Genuine simplicity.** A 10-line script that reads a config file and prints a summary does not need an injected `ConfigLoader` interface. The overhead of full DI in simple scripts is not testability — it is ceremony. Keep it simple; cover it with a single integration test if you cover it at all.

**The accidental tradeoff** is where things go wrong. When testability is sacrificed not because of a conscious performance or simplicity decision but because the developer did not think about testing at all, the result is a codebase that is hard to test, hard to change, and hard to understand — with none of the benefits of the tradeoff.

The discipline is:
- Make the tradeoff explicitly.
- Document why.
- Know which parts of the system are covered by what kind of tests as a result.

> [!warning] The danger is not choosing performance over testability — it is making that choice accidentally, without knowing the cost, and without a compensating test strategy for the affected code.

@feynman

Choosing not to make something testable is a valid engineering decision, as long as you know you are making it and have a plan for how you will catch bugs in that code without unit tests.
