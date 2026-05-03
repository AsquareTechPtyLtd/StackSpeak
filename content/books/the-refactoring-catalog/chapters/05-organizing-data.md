@chapter
id: rfc-ch05-organizing-data
order: 5
title: Organizing Data
summary: Refactorings that improve how data is shaped — replacing primitives with meaningful types, encapsulating fields, distinguishing values from references, and removing the magic numbers that haunt every codebase.

@card
id: rfc-ch05-c001
order: 1
title: Data Shape Is Design
teaser: The most common class of data problems isn't a missing field — it's a value that exists but carries no meaning, no constraints, and no behavior.

@explanation

When a function signature reads `charge(amount: number, currency: string, customerId: string, orderId: string)`, you are looking at a design problem disguised as a typing problem. Every parameter is technically correct and completely wrong: there is nothing stopping you from passing an order id where a customer id belongs, nothing stopping a negative amount, nothing saying that currency is an ISO 4217 code and not a free-form string your UI happened to emit.

This is primitive obsession — the tendency to reach for the language's built-in scalar types rather than creating domain types that carry the invariants of your model. Primitive obsession is not a style preference. It is a design decision, and it consistently produces the same failure modes:

- Validation scattered across callsites instead of enforced at construction.
- Parameters of identical primitive type passed in the wrong order with no compiler error.
- Behavior that belongs to a concept (formatting a money amount, comparing two email addresses case-insensitively) duplicated across files.
- Business rules buried in comments because there is nowhere better to put them.

Chapter 5's refactorings are all answers to primitive obsession in one form or another. The throughline is this: when a value represents a concept in your domain, it deserves a type. That type is where you put the constructor validation, the display logic, the equality semantics, and the documentation. Everything else follows.

> [!info] The refactorings in this chapter compound. Replacing a primitive type often exposes a data value that should be lifted into an object, which in turn makes a type code look suspicious — one move sets up the next.

@feynman

Primitive obsession is using a plain cardboard box to store a violin — technically it fits, but the box offers no protection, no labeling, and no hint that the contents are fragile.

@card
id: rfc-ch05-c002
order: 2
title: Replace Primitive with Object
teaser: When a value has constraints, formatting rules, or comparison semantics that keep being reimplemented at callsites, it is ready to become a type.

@explanation

The signal is repetition. You find `amount > 0` checked in three places. You find `currency.toUpperCase()` written twice. You find a comment that says "customerId must be a UUID." When validation or formatting for a value appears outside the value itself, that is the smell.

The recipe:

1. Create a new class (or value type) for the concept — `Money`, `EmailAddress`, `CustomerId`, `PhoneNumber`.
2. Move the invariant into the constructor: throw or return an error if the input violates it.
3. Add the behavior that was scattered: a `format()` method, a custom `equals()`, a `toString()`.
4. Replace every primitive usage with the new type, starting at construction sites and working outward.
5. Delete the callsite validations that the constructor now handles.

```swift
// Before
func charge(amountCents: Int, currency: String) {
    guard amountCents > 0 else { fatalError("amount must be positive") }
    guard currency.count == 3 else { fatalError("invalid currency code") }
    // ...
}

// After
struct Money {
    let amountCents: Int
    let currency: CurrencyCode   // itself a value type — see card 8

    init(amountCents: Int, currency: CurrencyCode) {
        precondition(amountCents >= 0, "amount cannot be negative")
        self.amountCents = amountCents
        self.currency = currency
    }
}

func charge(amount: Money) { ... }
```

Do not apply this when the value has no behavior beyond storage and is not reused across boundaries. A local intermediate result that lives for three lines does not need a wrapper type — the added friction outweighs the clarity.

@feynman

Replacing a primitive with an object is like upgrading a sticky note that says "temperature" to a thermometer — the thermometer enforces the unit, has a readable display, and cannot accidentally show you someone's phone number.

@card
id: rfc-ch05-c003
order: 3
title: Replace Data Value with Object
teaser: A record that starts as a passive struct earns the right to become a class when it accumulates behavior and needs an identity.

@explanation

The distinction between a data value and a rich object is behavioral. A data value holds fields. An object holds fields and knows how to do things with them. When you notice that a struct has started collecting methods — validation, formatting, derived properties, comparison logic — it is carrying behavior that belongs in a class with proper encapsulation.

The recipe:

1. Identify the struct or record that has grown beyond passive data storage.
2. Create a class with the same fields.
3. Move the methods that operate on those fields into the class.
4. Decide whether instances should be values (copied, compared by content) or references (shared, compared by identity) — see card 4 for that decision.
5. Replace all usages and verify that callsites are not mutating the value in ways that would break reference semantics.

```kotlin
// Before
data class CustomerRecord(
    val id: String,
    val email: String,
    val loyaltyPoints: Int
)

fun formatCustomerLabel(c: CustomerRecord): String =
    "${c.email} (${c.loyaltyPoints} pts)"

// After
class Customer(
    val id: CustomerId,
    private val email: EmailAddress,
    private var loyaltyPoints: Int
) {
    fun label(): String = "${email.display()} ($loyaltyPoints pts)"
    fun addPoints(points: Int) {
        require(points > 0)
        loyaltyPoints += points
    }
}
```

> [!tip] In Kotlin, prefer `data class` for pure values (immutable, compared by content) and a regular `class` when the object has identity, mutable state, or complex behavior. The choice makes the semantics explicit in the type declaration.

@feynman

Turning a data record into an object is like hiring the file cabinet to also be the archivist — instead of a passive container that anyone can rifle through, you have an entity that knows the rules for how its contents should be accessed and modified.

@card
id: rfc-ch05-c004
order: 4
title: Change Value to Reference / Change Reference to Value
teaser: Whether two objects with identical data are "the same object" or "two equal objects" is not a trivial question — and the answer has consequences for caching, mutation, and thread safety.

@explanation

A **value** is copied on assignment; equality is determined by content. Two `Money(100, USD)` instances are interchangeable and equal. A **reference** is shared; equality is determined by identity. Two `Customer` objects with the same id are pointers to the same entity, and mutating one mutates it everywhere.

**Change Value to Reference** when: the same real-world entity is represented in multiple places and mutations need to propagate. A `Customer` being updated in one part of the system should be visible everywhere that customer is referenced. Making it a value means changes to a copy are silently lost.

1. Introduce a registry or repository that hands out the canonical instance by id.
2. Replace all construction sites with lookups: `CustomerRepository.find(id)` instead of `Customer(...)`.
3. Verify that all mutations go through the canonical instance.

**Change Reference to Value** when: the object is small, immutable, and defined by its content — not by a persistent identity. `Money`, `DateRange`, `Coordinates` are natural values. Treating them as references forces you to reason about aliasing and ownership unnecessarily.

1. Make all fields immutable.
2. Implement `equals` and `hashCode` (or the language equivalent) based on content.
3. Ensure that any "modification" returns a new instance rather than mutating the existing one.

```swift
// Value: safe to copy, no shared state
struct DateRange: Equatable {
    let start: Date
    let end: Date
    func extended(by days: Int) -> DateRange { ... }  // returns new value
}
```

> [!warning] Mixing reference and value semantics for the same concept across a codebase is a reliable source of subtle bugs. Decide once per type and enforce it through immutability or access control.

@feynman

The difference between a value and a reference is the difference between a recipe card and a shared whiteboard — if you annotate the recipe card, only your copy changes; if you write on the whiteboard, everyone in the room sees the change.

@card
id: rfc-ch05-c005
order: 5
title: Encapsulate Field
teaser: Exposing a field directly gives callers the ability to change it without the owning object knowing — encapsulation routes every read and write through methods the object controls.

@explanation

A public field is a promise you can never take back. Once external code reads and writes a field directly, you cannot add validation, logging, lazy initialization, computed derivation, or change-notification without breaking every callsite. The refactoring is small but its value compounds over time.

The recipe:

1. Add a getter and setter (or a computed property) that wraps the field.
2. Make the field private.
3. Replace all direct accesses with the getter/setter — your compiler will point out every violation once the field is private.
4. Add any validation or side effects to the setter now that you have a choke point.

```swift
// Before
class Invoice {
    var status: String   // external code writes "paid", "PAID", "Paid" freely
}

// After
class Invoice {
    private var _status: InvoiceStatus = .draft

    var status: InvoiceStatus {
        get { _status }
        set {
            precondition(newValue != .draft || _status == .draft,
                         "cannot revert a processed invoice to draft")
            _status = newValue
        }
    }
}
```

Do not mechanically wrap every field with a getter and setter that do nothing but read and write the field. That is encapsulation theater. The value of encapsulation is the ability to add behavior later — apply it where behavior is plausible.

@feynman

Encapsulating a field is like replacing a self-serve cabinet with a receptionist — callers still get what they need, but now there is one place to enforce the rules, log the requests, and say no when appropriate.

@card
id: rfc-ch05-c006
order: 6
title: Encapsulate Collection
teaser: When a class exposes its internal collection directly, callers can modify it without the owner's knowledge — encapsulating a collection means returning a copy or an unmodifiable view, never the live list.

@explanation

Returning a reference to an internal `List`, `Array`, or `Set` is a subtle form of broken encapsulation. The owning object cannot enforce invariants on its own data because anyone holding the reference can mutate it at will. The bug is typically discovered much later, when the internal list has mysteriously grown an element the class never added.

The recipe:

1. Change the return type of the collection getter to an immutable or copied form.
2. Add explicit `add` and `remove` methods to the class for all mutations that callers legitimately need.
3. Remove any setter that replaces the entire collection (replace with a method that validates the incoming data).

```kotlin
// Before
class Order(val lineItems: MutableList<LineItem>)

// caller does: order.lineItems.add(item)   // bypasses any validation

// After
class Order(private val _lineItems: MutableList<LineItem> = mutableListOf()) {

    val lineItems: List<LineItem>
        get() = _lineItems.toList()   // defensive copy — caller cannot mutate

    fun addItem(item: LineItem) {
        require(item.quantity > 0) { "quantity must be positive" }
        _lineItems.add(item)
    }

    fun removeItem(itemId: LineItemId) {
        _lineItems.removeIf { it.id == itemId }
    }
}
```

> [!warning] Returning `Collections.unmodifiableList(items)` in Java (or `.asReadOnly()` in Kotlin) prevents mutation but still exposes a live view — additions to the internal list are reflected in the returned reference. A defensive copy (`toList()`, `new ArrayList<>(items)`) eliminates that aliasing completely.

@feynman

Exposing an internal collection without a copy is like handing a guest the master key to your filing cabinet — they asked to see one document, but now they can add, remove, and rearrange everything while you are not looking.

@card
id: rfc-ch05-c007
order: 7
title: Replace Magic Number with Symbolic Constant
teaser: A number that appears in code without explanation forces every reader to reverse-engineer its meaning — a named constant documents the intent at the site of the value, not in a comment three files away.

@explanation

Magic numbers are context-free. The value `86400` is recognizable to some readers as seconds-in-a-day; the value `0.0825` is meaningless without context; the value `3` could be anything. The name is the documentation.

The recipe:

1. Identify the literal value and its meaning.
2. Introduce a named constant at the appropriate scope (`const val`, `static final`, a module-level `let`).
3. Give it a name that describes the concept, not the value: `SECONDS_PER_DAY`, not `EIGHTY_SIX_THOUSAND_FOUR_HUNDRED`.
4. Replace all occurrences of the literal with the constant.
5. If the same numeric value represents two different concepts in different places, create two separate constants — coincidental equality is not the same as identity.

```typescript
// Before
const expiresAt = createdAt + 86400 * 30;
const lateFee = subtotal * 0.0825;

// After
const SECONDS_PER_DAY = 86_400;
const TRIAL_PERIOD_DAYS = 30;
const LATE_FEE_RATE = 0.0825;  // jurisdiction-specific; see billing/rates.ts

const expiresAt = createdAt + SECONDS_PER_DAY * TRIAL_PERIOD_DAYS;
const lateFee = subtotal * LATE_FEE_RATE;
```

The cost of this refactoring is close to zero. The benefit is that a search for `TRIAL_PERIOD_DAYS` now finds every place that relies on this policy, making it safe to change.

@feynman

A magic number is like a phone number written on a Post-it with no name next to it — you have to call it to find out who it is, and there is no way to know how many other Post-its have the same number.

@card
id: rfc-ch05-c008
order: 8
title: Replace Magic Number with Named Type
teaser: When a value is drawn from a fixed set of legal options, a constant is not enough — an enum or a dedicated type makes illegal values unrepresentable.

@explanation

A symbolic constant tells you the name of a value. An enum tells you the complete set of valid values. That distinction matters when a field like `status` has exactly four legal states and your current representation is a `String` constant — nothing prevents you from assigning a fifth, typo-ridden value that the type system will never catch.

The recipe:

1. Identify the set of values that are legal for the concept.
2. Define an enum (or a sealed class for cases that carry data).
3. Replace all usages of the primitive with the enum.
4. Handle exhaustiveness: if your language supports exhaustive `when`/`switch`, add cases for every member and let the compiler warn you when you add a new one later.

```swift
// Before
let status = "pending"   // could be "Pending", "PENDING", "penidng"

func describe(_ status: String) -> String {
    if status == "pending" { return "Awaiting payment" }
    if status == "paid" { return "Payment received" }
    return "Unknown"    // silently swallows invalid values
}

// After
enum InvoiceStatus {
    case draft, pending, paid, voided
}

func describe(_ status: InvoiceStatus) -> String {
    switch status {
    case .draft:   return "Draft"
    case .pending: return "Awaiting payment"
    case .paid:    return "Payment received"
    case .voided:  return "Voided"
    }   // Swift requires exhaustiveness — adding a case breaks the build
}
```

> [!tip] Swift enums, Kotlin sealed classes, and TypeScript string literal union types all support exhaustiveness checking. Lean on this: the compiler tells you everywhere a new case must be handled instead of relying on code review to catch the gaps.

@feynman

Replacing a string constant with an enum is like replacing a written dress-code policy with a turnstile that physically cannot let through anyone not wearing the right badge — compliance is enforced by the system, not by the honor system.

@card
id: rfc-ch05-c009
order: 9
title: Replace Type Code with Subclass
teaser: When an enum drives fundamentally different behavior via conditionals scattered across the codebase, each case is secretly a subclass trying to be born.

@explanation

The signal: you have a type code (`shape.kind`, `payment.method`, `employee.role`) and you find `if/switch` statements that branch on it appearing in multiple methods. Every time you add a new type code value, you must find and update every one of those switches. That is the maintenance burden of a polymorphism problem solved with conditionals.

The recipe:

1. Create a subclass for each type code value.
2. Move the behavior that varies per type into overridden methods in each subclass.
3. Replace `if/switch` blocks with virtual dispatch.
4. Remove the type code field — the subclass hierarchy is now the type code.
5. Update construction sites to instantiate the correct subclass.

```kotlin
// Before
class Payment(val method: String, val amount: Money) {
    fun processingFee(): Money = when (method) {
        "card"   -> amount * 0.029
        "bank"   -> Money(25_00, amount.currency)
        "crypto" -> amount * 0.01
        else     -> throw IllegalStateException("unknown method: $method")
    }
}

// After
abstract class Payment(val amount: Money) {
    abstract fun processingFee(): Money
}

class CardPayment(amount: Money) : Payment(amount) {
    override fun processingFee() = amount * 0.029
}

class BankTransfer(amount: Money) : Payment(amount) {
    override fun processingFee() = Money(25_00, amount.currency)
}

class CryptoPayment(amount: Money) : Payment(amount) {
    override fun processingFee() = amount * 0.01
}
```

Do not apply this when the type code changes during the object's lifetime. An `Order` that starts as `pending` and becomes `paid` cannot change its subclass at runtime — use State/Strategy instead (see card 10).

@feynman

Replacing a type code with subclasses is like stopping a single chef from switching between cooking styles mid-service and instead hiring a specialist for each cuisine — the right person handles each dish without a giant decision tree in the kitchen.

@card
id: rfc-ch05-c010
order: 10
title: Replace Type Code with State/Strategy
teaser: When an object's behavior changes because its type changes during its lifetime, State and Strategy patterns are the dynamic equivalent of the subclass approach.

@explanation

The constraint that prevented using subclasses (card 9) is that a live object cannot change its class. An `Invoice` starts as `draft`, moves to `pending`, and becomes `paid`. Subclassing the static type code works; subclassing the runtime state does not.

State and Strategy both solve this by extracting the varying behavior into a separate object that the host object delegates to, and which can be swapped at runtime.

**State:** Use when the varying behavior represents lifecycle phases of the same object. The state object is an implementation detail — callers do not choose or see it.

**Strategy:** Use when the varying behavior is an algorithm the caller selects. A `TaxCalculator` strategy is chosen at construction or injection time, not by the object's own lifecycle.

The recipe:

1. Create an interface (or abstract class) for the behavior that varies.
2. Implement one concrete class per type code value.
3. Replace the type code field with a reference to the current strategy/state.
4. Delegate all type-dependent methods through that reference.
5. Add transition methods that swap the state when a lifecycle event occurs.

```swift
// Before
class Invoice {
    var status: InvoiceStatus   // .draft, .pending, .paid, .voided
    func canAddItems() -> Bool {
        return status == .draft
    }
}

// After
protocol InvoiceState {
    func canAddItems() -> Bool
    func transitionToPending(invoice: Invoice)
}

class DraftState: InvoiceState {
    func canAddItems() -> Bool { true }
    func transitionToPending(invoice: Invoice) {
        invoice.state = PendingState()
    }
}

class PendingState: InvoiceState {
    func canAddItems() -> Bool { false }
    func transitionToPending(invoice: Invoice) { /* no-op */ }
}
```

> [!info] State is not always the right answer for lifecycle transitions. If the number of states is small and the behavior differences are minimal, a simple enum with a few guard statements is less indirection at lower cognitive cost.

@feynman

The State pattern is like a traffic light having a different internal circuit active for each color rather than a single circuit that checks "what color am I currently showing" — the current state handles its own behavior, and you just signal when it is time to change.

@card
id: rfc-ch05-c011
order: 11
title: Replace Array with Object
teaser: When an array is being used as a fixed-format record — where index 0 is always the name, index 1 is always the score — it is a struct wearing a disguise.

@explanation

Arrays have two valid uses: homogeneous sequences of items of the same kind, and sparse buffers. When you see `result[0]`, `result[1]`, `result[2]` used as named fields throughout the code, you have a record that chose the wrong container. The signal is commentary: `// index 0 is customerId, index 1 is score, index 2 is tier`.

The recipe:

1. Create a class or struct with a named field for each array index.
2. Replace all array creation sites with object construction.
3. Replace all indexed reads with field accesses.
4. Remove all comments that explained what each index meant — the field names are now the documentation.
5. Delete the array.

```typescript
// Before
type CustomerScore = [string, number, string];
//                    ^id     ^score  ^tier

function promote(scores: CustomerScore[]): void {
    for (const s of scores) {
        if (s[1] > 90 && s[2] !== "platinum") {
            upgradeTier(s[0], "platinum");
        }
    }
}

// After
interface CustomerScore {
    customerId: CustomerId;
    score: number;
    tier: LoyaltyTier;
}

function promote(scores: CustomerScore[]): void {
    for (const s of scores) {
        if (s.score > 90 && s.tier !== LoyaltyTier.Platinum) {
            upgradeTier(s.customerId, LoyaltyTier.Platinum);
        }
    }
}
```

@feynman

Using an array as a record is like labeling your moving boxes by number and keeping a separate sheet that says "box 3 is the kitchen" — the object gives every item a name tag so you never need the sheet.

@card
id: rfc-ch05-c012
order: 12
title: Replace Inheritance with Composition
teaser: When a class inherits from another class primarily to reuse its methods rather than to be a genuine subtype, inheritance is the wrong tool — and composition separates what you are from what you use.

@explanation

The smell: a subclass inherits only to get access to a handful of methods on the superclass. It does not satisfy the Liskov substitution principle — you cannot pass the subclass wherever the superclass is expected without things breaking. The inheritance is about reuse, not subtyping.

The recipe:

1. Create a field in the subclass that holds an instance of the former superclass.
2. For each method the subclass was using from the superclass, add a delegation method.
3. Remove the `extends`/`: SuperClass` relationship.
4. Adjust visibility — the composed object's interface should be as narrow as needed.
5. If the former superclass had abstract methods that the subclass implemented, you may need an interface to preserve polymorphism without the inheritance chain.

```kotlin
// Before
class InvoiceFormatter : BaseFormatter() {
    // uses formatCurrency() and formatDate() from BaseFormatter
    // but Invoice is not a BaseFormatter in any meaningful sense
    fun formatHeader(invoice: Invoice): String =
        "${formatDate(invoice.date)}  ${formatCurrency(invoice.total)}"
}

// After
class InvoiceFormatter(private val formatter: BaseFormatter) {
    fun formatHeader(invoice: Invoice): String =
        "${formatter.formatDate(invoice.date)}  ${formatter.formatCurrency(invoice.total)}"
}
```

The rule of thumb is the "is-a" test: a `CardPayment` is a `Payment`; an `InvoiceFormatter` is not a `BaseFormatter`. When the is-a relationship is strained, composition is almost always the better model.

> [!tip] In Swift, protocol extensions and conformances provide a clean alternative to inheritance for sharing behavior — prefer composing protocols over building class hierarchies when the shared behavior is not truly subtype-polymorphic.

@feynman

Choosing inheritance over composition for code reuse is like becoming a member of a gym just to use their parking lot — you have committed to a relationship that implies much more than the one thing you actually wanted.

@card
id: rfc-ch05-c013
order: 13
title: Decompose Domain Concept
teaser: When a generic type like a `String`, a `Map`, or a `Pair` is secretly carrying a named concept from your domain, extracting it into its own type clarifies the model and centralizes its rules.

@explanation

This refactoring generalizes the thinking behind the entire chapter. Anywhere a built-in or generic type is being used to represent a domain concept — an `ISO8601 String` that is really a `Timestamp`, a `Map<String, Any>` that is really a `LineItemAttributes` record, a `Pair<String, Int>` that is really a `(CustomerId, LoyaltyPoints)` tuple — there is an unnamed concept that deserves a name.

The recipe:

1. Identify the generic type and the concept it is carrying.
2. Name the concept. If naming it is difficult, the concept may not be well-defined — investigate before proceeding.
3. Create the new type with a constructor that validates the input.
4. Move all operations that were performed on the generic type (parsing, formatting, comparison, derivation) into the new type.
5. Replace all usages and remove the now-redundant validation and transformation code at callsites.

```typescript
// Before: a Map that is pretending to be a domain object
type OrderMetadata = Map<string, string>;
// keys in practice: "referral_code", "campaign_id", "affiliate_id"
// written out in prose in a comment somewhere

// After
interface OrderMetadata {
    referralCode: ReferralCode | null;
    campaignId: CampaignId | null;
    affiliateId: AffiliateId | null;
}

// Each of those ids is itself a branded type:
type ReferralCode = string & { readonly _brand: "ReferralCode" };

function makeReferralCode(raw: string): ReferralCode {
    if (!/^[A-Z0-9]{6,12}$/.test(raw)) throw new Error("invalid referral code");
    return raw as ReferralCode;
}
```

TypeScript branded types, Kotlin inline value classes (`@JvmInline value class`), and Swift single-field structs with private constructors all give you a zero-overhead wrapper that is type-incompatible with its underlying primitive — the compiler does the enforcement.

@feynman

Decomposing a domain concept is like noticing that your "miscellaneous" drawer has been the home of scissors, tape, and stamps for three years — at some point it is no longer miscellaneous, it is your stationery drawer, and it deserves a label.
