@chapter
id: ttp-ch02-design-principles
order: 2
title: Design Principles
summary: The foundational principles — DRY, SOLID, Demeter, coupling/cohesion, and abstraction timing — that determine whether software resists change or crumbles under it.

@card
id: ttp-ch02-c001
order: 1
title: DRY Is About Knowledge, Not Code
teaser: Don't Repeat Yourself isn't about removing duplicate lines — it's about ensuring every piece of knowledge in a system has exactly one authoritative home.

@explanation

DRY is one of the most misapplied principles in software. The original formulation from _The Pragmatic Programmer_ is precise: "Every piece of knowledge must have a single, unambiguous, authoritative representation within a system." That is not the same as "find identical code and extract it."

The important distinction:

- **Code duplication** — two functions that happen to look similar. May be fine if they represent different concepts that will diverge.
- **Knowledge duplication** — the same rule, formula, or constraint expressed in two places. If the rule changes and you update one but not the other, you have a bug.

A tax rate that appears as `0.08` in three files is knowledge duplication. Two `for` loops with similar structure but different purposes are not.

The failure mode of misapplied DRY is premature unification: you merge two things because they look alike today, they diverge as requirements change, and you end up with a function whose parameter list grows to cover every caller's special case. The cure — the abstraction — becomes harder to change than the duplication was.

```python
# Knowledge duplication — wrong
MAX_RETRIES = 3   # in http_client.py
MAX_RETRIES = 3   # in job_runner.py — same constant, no shared source

# Code duplication — often fine
def format_user_name(user): ...
def format_account_name(account): ...  # similar structure, different domain
```

> [!warning] Deduplicating code that represents different concepts couples things that should be independent. Before extracting, ask: "If these two requirements changed independently, would this abstraction hold?"

@feynman

DRY is the same as normalizing a database — the goal is one source of truth for each fact, not zero lines that look the same.

@card
id: ttp-ch02-c002
order: 2
title: YAGNI: Build What's Needed Now
teaser: Speculative generalization costs real time today in exchange for imaginary savings that usually never arrive — and leaves behind complexity you now have to maintain.

@explanation

YAGNI (You Aren't Gonna Need It) is a direct response to a specific failure mode: engineers building for requirements that don't exist yet. It shows up as plugin architectures for apps with one client, configurable flags for behavior that never varies, and abstraction layers that wrap a single implementation.

The sunk-cost trap is where this gets expensive. An engineer spends a day building a generic event pipeline "because we'll probably need it." It ships. It works. Now every future engineer has to understand the abstraction even though there's still only one event type. The flexibility is real; the future requirements that would use it are not.

How to distinguish genuine from hypothetical need:

- **Genuine near-term need:** a feature planned in the current quarter, a variation with a known second use case, infrastructure required to unblock another team.
- **Hypothetical future need:** "we might," "clients could want," "it would be nice if," requirements with no concrete owner or timeline.

The cost of building something you don't need is not just the initial time. It's maintenance, documentation, test coverage, onboarding complexity, and the cognitive load it adds to every future change in that area. Ron Jeffries, who coined YAGNI in the context of Extreme Programming, estimated that speculative features cost roughly three times what they appear to cost.

> [!tip] If a future requirement arrives and the code isn't ready, you can add it then — with full knowledge of the actual requirement. Premature generality is almost always a worse fit for the real requirement than code written to the real requirement.

@feynman

Optimizing for theoretical future load before you have real load is premature optimization with extra steps — you paid a real cost to solve a problem you don't have.

@card
id: ttp-ch02-c003
order: 3
title: Single Responsibility: One Reason to Change
teaser: A class with two responsibilities will be modified for two different reasons — and every modification risks breaking the part of the class that had nothing to do with the change.

@explanation

The Single Responsibility Principle (SRP) says a class or module should have exactly one reason to change. Not "does one thing" — does one thing at the right level of abstraction, for one actor.

SRP violations surface in recognizable patterns:

- **God objects** — a `UserManager` that handles authentication, profile updates, email sending, billing, and session management. Every feature touches it; every change risks breaking something unrelated.
- **Tangled tests** — a test file that imports half the codebase to set up one unit, because the unit has tendrils in too many places.
- **Change cascades** — you change a data format and have to update business logic, rendering code, and persistence in the same class because they're not separated.

The cohesion test: would you describe what this class does using "and"? If yes — "it handles login and sends welcome emails and manages sessions" — it probably has too many responsibilities.

```swift
// Violates SRP — one class, two reasons to change
class ReportGenerator {
    func fetchData() -> [Record] { ... }   // changes when data source changes
    func formatAsPDF() -> Data { ... }     // changes when output format changes
}

// Better — each class has one reason to change
class ReportDataFetcher { func fetch() -> [Record] { ... } }
class PDFFormatter { func format(_ records: [Record]) -> Data { ... } }
```

SRP doesn't mean every class is tiny. It means every class is coherent — its parts belong together because they serve the same purpose.

> [!info] SRP is violated at the design level, not the line count level. A 300-line class with one clear responsibility is fine. A 50-line class with two distinct concerns is not.

@feynman

A Swiss Army knife is a terrible hammer — not because it's big, but because mixing concerns means every tool compromises every other tool.

@card
id: ttp-ch02-c004
order: 4
title: Open/Closed: Extend Without Modifying
teaser: Code that can only be extended by changing its internals is fragile — every extension is a potential regression in existing behavior.

@explanation

The Open/Closed Principle (OCP) states that a software entity should be open for extension but closed for modification. In practice: you add new behavior by adding new code, not by editing existing code.

The motivation is risk reduction. Every time you modify a tested, deployed piece of logic, you introduce the possibility of breaking existing behavior. If the design allows extension via new implementations — new classes, new strategy objects, new plugins — the existing logic never needs to touch.

The mechanism is stable abstractions. A `PaymentProcessor` interface closed for modification lets you add `StripeProcessor` and `PaypalProcessor` without touching the interface or its callers. The abstraction is the extension point.

```typescript
// Violates OCP — every new shape requires modifying this function
function area(shape: { type: string; ... }): number {
    if (shape.type === "circle") return Math.PI * shape.radius ** 2;
    if (shape.type === "square") return shape.side ** 2;
    // add new shape? modify here
}

// Follows OCP — extend by adding a new class, not editing existing code
interface Shape { area(): number; }
class Circle implements Shape { area() { return Math.PI * this.radius ** 2; } }
class Square implements Shape { area() { return this.side ** 2; } }
```

The tradeoff: designing for extension requires predicting the right extension points. Over-engineering extension points you'll never use is a YAGNI violation. The right answer is usually: make the code easy to change now, design explicit extension points only when you have a concrete second use case.

> [!tip] OCP and YAGNI are in tension. Lean toward OCP at system boundaries and integration points — places where new behavior is a near-certainty. Lean toward simplicity everywhere else.

@feynman

A well-designed plugin architecture lets you add new capabilities by dropping in a new file — the host application never needs a surgery appointment.

@card
id: ttp-ch02-c005
order: 5
title: Liskov Substitution: Honor the Contract
teaser: A subtype that violates the behavioral contract of its parent type doesn't extend the abstraction — it breaks it, silently, for any caller that trusted the contract.

@explanation

The Liskov Substitution Principle (LSP) says: if `S` is a subtype of `T`, then objects of type `T` in a program may be replaced with objects of type `S` without altering any of the desirable properties of that program. It's not about type signatures — it's about behavioral contracts.

The classic violation is `Square extends Rectangle`. Mathematically, a square is a rectangle. But in code, `Rectangle` has a contract: you can set width and height independently. `Square` violates it — setting width also sets height. Callers who trust the `Rectangle` contract and write:

```python
def stretch(rect: Rectangle):
    rect.width = 10
    rect.height = 5
    assert rect.area() == 50  # fails for Square
```

…get incorrect behavior. The type system didn't catch it. The violation is in the contract, not the signature.

LSP violations reveal design problems:

- Subclass that throws `NotImplementedError` on an inherited method — it doesn't actually support the full interface.
- Subclass that narrows preconditions (accepts fewer inputs than the base) or weakens postconditions (guarantees less than the base).
- Inheritance used for code reuse rather than type substitution — the subclass shares code, not behavior.

When you find an LSP violation, the fix is usually composition over inheritance. The `Square` and `Rectangle` should not be in a hierarchy — they're different shapes.

> [!warning] If a subclass needs to override a method to throw an exception or do nothing, the subclass doesn't satisfy the behavioral contract. The inheritance relationship is wrong.

@feynman

It's like a function that says it accepts any `Iterable` but explodes on generators — the type is right, the contract is broken.

@card
id: ttp-ch02-c006
order: 6
title: Interface Segregation: Keep Interfaces Focused
teaser: A fat interface forces every implementer to depend on methods they don't use — and forces every caller to know about behavior that's irrelevant to their purpose.

@explanation

The Interface Segregation Principle (ISP) says clients should not be forced to depend on interfaces they don't use. The failure mode is the fat interface: a single `IWorker` interface with 12 methods for every possible worker type, where most concrete workers implement half of them and leave the other half as empty stubs or thrown exceptions.

Why this is a problem:

- Implementers are burdened with methods they can't meaningfully implement.
- Callers import a large interface to use two methods, increasing coupling to everything in the interface.
- Changes to any method in the interface force recompilation or review of all implementers, even those not affected.

In Swift's protocol-oriented design, ISP is enforced naturally via protocol composition — you define small, focused protocols and compose them:

```swift
protocol Readable { func read() -> Data }
protocol Writable { func write(_ data: Data) }
protocol ReadWritable: Readable, Writable {}

// A read-only cache only needs Readable
class ReadOnlyCache: Readable { ... }

// A full store implements both
class FileStore: ReadWritable { ... }
```

Compare this to a single `Storage` protocol with 8 methods that every type must satisfy in full.

ISP and SRP are complementary: SRP keeps classes focused on one reason to change, ISP keeps interfaces focused on one client's needs. Together, they prevent the entanglement that makes large codebases hard to change.

> [!info] The right size for an interface is the smallest set of methods a specific caller needs. If two callers need different subsets, they need different interfaces.

@feynman

A universal remote with 80 buttons that controls every device ever made is technically powerful — but you spend all your time ignoring 75 of them to press the five you actually need.

@card
id: ttp-ch02-c007
order: 7
title: Dependency Inversion: Depend on Abstractions
teaser: When high-level business logic depends directly on low-level implementation details, it becomes impossible to test, swap, or evolve either one independently.

@explanation

The Dependency Inversion Principle (DIP) has two parts: high-level modules should not depend on low-level modules — both should depend on abstractions. And abstractions should not depend on details — details should depend on abstractions.

The concrete problem it solves: if your `OrderService` directly instantiates a `PostgresDatabase`, you can't unit test `OrderService` without a running Postgres instance, you can't swap to a different database without modifying `OrderService`, and you can't run the service offline.

The fix is to introduce an abstraction at the boundary:

```swift
// Without DIP — hard dependency
class OrderService {
    let db = PostgresDatabase()  // directly depends on details
    func placeOrder(...) { db.insert(...) }
}

// With DIP — depends on abstraction
protocol OrderRepository { func save(_ order: Order) async throws }
class OrderService {
    let repo: OrderRepository  // injected, not instantiated
    init(repo: OrderRepository) { self.repo = repo }
}

// Tests use a mock; production uses PostgresOrderRepository
```

DIP is the architectural foundation for testability and pluggability. Without it, unit tests are integration tests in disguise. With it, you can test each layer in isolation and swap implementations (database, email provider, payment processor) without touching the business logic.

The principle doesn't require a dependency injection framework — constructor injection is sufficient. The framework is optional scaffolding; the principle is the point.

> [!tip] If your test setup requires spinning up infrastructure (a real database, a real API), you have a DIP violation somewhere in the call chain. Trace the dependency back to find the abstraction that's missing.

@feynman

It's the same as coding to an interface rather than a concrete class — the power is in the indirection that lets you swap the implementation without touching the caller.

@card
id: ttp-ch02-c008
order: 8
title: Law of Demeter: Talk to Friends, Not Strangers
teaser: Method chains that reach three objects deep don't just look messy — each link in the chain is a dependency on something you don't directly own.

@explanation

The Law of Demeter (LoD) says a method should only call methods on: itself, its parameters, objects it creates, or its direct component objects. In short: talk to friends, not strangers.

The violation is easy to spot — long method chains:

```python
# Violates LoD — three objects deep
discount = order.getCustomer().getLoyaltyAccount().getDiscount()

# Follows LoD — ask the direct collaborator
discount = order.getDiscount()  # Order knows how to get its own discount
```

Why this matters: `order.getCustomer().getLoyaltyAccount().getDiscount()` means the calling code now depends on `Order`, `Customer`, `LoyaltyAccount`, and the internal relationship between them. If `LoyaltyAccount` is renamed, restructured, or removed, this call breaks. You've coupled your code to the internal structure of objects you don't own.

The distinction between LoD violations and fluent APIs is intent:

- **Accidental deep coupling** — `order.getCustomer().getAddress().getCity()` — the chain traverses ownership boundaries to dig out a value.
- **Fluent API** — `QueryBuilder().select("*").from("users").where("active = 1").build()` — each call returns the same builder; there's no traversal of foreign object graphs.

Fixing LoD violations usually means pushing behavior closer to the data. Instead of callers reaching through objects to do something, the owning object exposes a method that does it. This is the "tell, don't ask" corollary: tell objects to do things rather than asking for their state and doing it yourself.

> [!info] Long chains are a symptom of Feature Envy — a method more interested in the data of other objects than its own. Move the method closer to the data it uses.

@feynman

Asking your friend to ask their friend to ask their neighbor for the time is slower and more fragile than just checking your own watch — every intermediary is a dependency you didn't sign up for.

@card
id: ttp-ch02-c009
order: 9
title: Coupling vs. Cohesion: The Two Design Forces
teaser: Every design decision shifts the balance between coupling — how much modules depend on each other — and cohesion — how closely related the things inside a module are.

@explanation

Coupling and cohesion are the two lenses that evaluate almost every structural decision in software design. They pull in opposite directions, and good design holds them in tension.

**Cohesion** measures how related the responsibilities inside a module are. High cohesion means everything in the module belongs together — they serve the same purpose, work on the same data, change for the same reason. Low cohesion means the module is a grab-bag: utilities, helpers, `common/`, `misc/`.

**Coupling** measures how much a module depends on other modules. Low coupling means a module can be understood, tested, and changed without having to understand its neighbors. High coupling means a change in one place ripples through the system.

The goal: high cohesion inside modules, low coupling between them.

Common traps:

- **Splitting cohesive things to reduce size** — breaking a naturally cohesive module into multiple files increases coupling without improving cohesion. Smaller is not always better.
- **Merging unrelated things for convenience** — putting "all the utilities" in one module achieves low coupling (only one import) but destroys cohesion.
- **Coupling through shared state** — a global cache or singleton that 12 modules depend on looks like low coupling (one import) but creates invisible tight coupling through shared mutable state.

Use cohesion as the primary criterion for what goes together, and coupling as the criterion for how modules communicate. When you're deciding whether two things belong in the same module, ask: do they change for the same reason? If yes, co-locate. If no, separate.

> [!tip] A useful heuristic: if a change to business requirement X requires touching 6 different modules, you probably have low cohesion around X. If deleting one class requires changing 10 others, you probably have high coupling.

@feynman

It's the same tradeoff as microservices versus monolith — you gain deployment independence (low coupling) at the cost of distributed systems complexity, and lose it when your "microservices" share a database (high coupling through shared state).

@card
id: ttp-ch02-c010
order: 10
title: Abstraction Timing: Too Early Is as Bad as Too Late
teaser: The wrong abstraction is worse than no abstraction — it locks in a model that doesn't fit the problem while adding all the overhead of indirection.

@explanation

The hardest design skill is not writing abstractions — it's knowing when to write them. Two failure modes flank the correct timing:

**Premature abstraction** — you generalize before you understand the problem. You build a flexible `ContentRenderer` that handles "all possible content types" when you have one. The abstraction encodes your current best guess at the shape of future requirements. When those requirements arrive differently than expected, the abstraction is in the way — you're now fighting its model while trying to implement the real one.

**Missed abstraction** — three places in the codebase share the same logic with slight variations, each copy has independently drifted, and the rule they're all supposed to implement is no longer coherent. The abstraction was needed and never made.

The rule of three is a practical heuristic: see the same pattern once, note it. Twice, be skeptical. Three times, abstract it. Three instances gives you enough information to see the real shape of the pattern rather than guessing from one example.

Why the wrong abstraction is worse than none:

- It adds indirection that has to be understood before you can change anything.
- It encodes a model that future developers treat as intentional even when it's accidental.
- Removing it requires untangling everything that has been built on top of it — more work than if it had never existed.

```typescript
// Don't rush to abstract this after seeing it twice
function formatUserEmail(user: User): string { ... }
function formatAdminEmail(admin: Admin): string { ... }

// After a third caller with the same pattern, the abstraction earns its place
function formatEmail(entity: HasEmailAddress): string { ... }
```

The right abstraction, at the right time, makes code clearer and easier to change. The wrong one — or the right one too early — makes every future change harder.

> [!warning] "We'll refactor when we have more data" is correct. "Let me build the abstraction now so we don't have to refactor later" is usually premature — you're paying the cost of generalization before you know what you're generalizing over.

@feynman

It's the same as schema design — model what you know now, because a schema that fits your data is cheaper to evolve than a schema built for data you don't have yet.
