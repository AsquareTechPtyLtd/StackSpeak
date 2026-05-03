@chapter
id: rfc-ch08-generalization
order: 8
title: Dealing with Generalization
summary: Inheritance is a useful tool and a sharp one — these refactorings reshape class hierarchies, lift shared behavior up, push specialized behavior down, and trade inheritance for delegation when that fits better.

@card
id: rfc-ch08-c001
order: 1
title: Inheritance and Its Discontents
teaser: Inheritance earns its keep when subtypes are genuinely specializations — and causes harm when they're merely convenient holders for shared code.

@explanation

Inheritance is one of the first abstractions programmers reach for and one of the last they fully understand. The appeal is obvious: define common behavior once, let subclasses inherit it, override what differs. The problem is that "shares some code with" is not the same as "is a kind of." When that conflation happens — and it happens often — the hierarchy drifts from its original purpose. Subclasses accumulate overrides that mute parent behavior. New requirements don't fit the hierarchy cleanly. You start passing flags to constructors to suppress inherited methods that shouldn't apply.

The refactorings in this chapter address the full lifecycle of that drift. Some push the hierarchy into better shape: Pull Up lifts shared behavior to where it belongs; Push Down confines specialized behavior to where it's used; Extract Superclass and Extract Subclass reshape the boundaries. Some dissolve the hierarchy entirely: Replace Inheritance with Delegation replaces an "is-a" that was never true with an honest "has-a."

Inheritance is still right when:

- Every subclass truly is a specialization of the parent type.
- Substitutability holds — you can use a subclass wherever the parent is expected without surprises.
- The hierarchy is shallow (1–2 levels is normal; 4+ is a warning sign).

When those conditions aren't met, one of the refactorings in this chapter is probably the right next move.

> [!info] The Liskov Substitution Principle is the practical test: if using a subclass in place of the parent changes behavior the caller didn't expect, the hierarchy is wrong.

@feynman

Inheritance is like the "same recipe, different garnish" rule in a kitchen — it works as long as the dishes really are variations of the same thing, and falls apart the moment you try to make a soup and a steak from the same base.

@card
id: rfc-ch08-c002
order: 2
title: Pull Up Method
teaser: When two subclasses contain identical or near-identical methods, the duplication belongs in the parent — not in both subclasses independently.

@explanation

You have two subclasses — say `CheckingAccount` and `SavingsAccount` — and both implement a `statementHeader()` method with the same body. Every change to that logic must be made twice, in sync. Eventually they diverge and you can no longer tell which version is correct.

Pull Up Method removes that duplication by moving the method to the shared superclass. The key constraint: the implementations must be genuinely identical, not just superficially similar. If the bodies look alike but rely on different fields or produce subtly different output, lifting them produces a misleading parent. Reconcile the differences first, or use Form Template Method instead.

**Recipe:**
1. Verify the two implementations are identical (including any methods they call).
2. If they reference subclass-specific fields, pull those fields up first (Pull Up Field).
3. Copy the method to the superclass.
4. Delete the method from both subclasses.
5. Compile and run tests; confirm both subclasses inherit correctly.

```kotlin
// Before
class CheckingAccount : Account() {
    fun statementHeader(): String = "Checking — Acct #$accountNumber"
}
class SavingsAccount : Account() {
    fun statementHeader(): String = "Savings — Acct #$accountNumber"
}

// After — implementations were identical after extracting the prefix;
// here the prefix differs, so Pull Up Field for accountNumber was enough
abstract class Account {
    protected abstract val accountNumber: String
    fun statementHeader(): String = "${accountType()} — Acct #$accountNumber"
    protected abstract fun accountType(): String
}
```

IntelliJ IDEA: right-click the method → Refactor → Pull Members Up.

> [!warning] Pull Up Method is wrong when the two implementations only look alike. Lifting them creates a parent that behaves differently than callers expect depending on which subtype they hold.

@feynman

Pulling up a shared method is like hoisting the house rules to the front of a rulebook instead of reprinting them in every chapter — the rule exists once, and every chapter that needs it just refers up.

@card
id: rfc-ch08-c003
order: 3
title: Pull Up Field
teaser: A field that appears in multiple sibling subclasses with the same name and purpose belongs in the superclass, not duplicated across each subclass independently.

@explanation

`CheckingAccount` has a `protected val accountNumber: String` and so does `SavingsAccount`. They serve identical purposes. Every place that pattern holds, Pull Up Field is the move: define the field once in the parent and remove it from the subclasses.

The field analogue is simpler than the method analogue because fields don't have behavior to reconcile — only name and type. When those match, the refactoring is mechanical.

**Recipe:**
1. Identify all subclasses that declare the same field with the same name and compatible type.
2. Declare the field in the superclass (usually `protected`).
3. Remove the field from each subclass.
4. Compile; fix any access modifier issues.
5. Run tests.

```kotlin
// Before
class CheckingAccount : Account() {
    protected val accountNumber: String = ""
    protected val ownerId: String = ""
}
class SavingsAccount : Account() {
    protected val accountNumber: String = ""
    protected val ownerId: String = ""
}

// After
abstract class Account {
    protected val accountNumber: String = ""
    protected val ownerId: String = ""
}
class CheckingAccount : Account()
class SavingsAccount : Account()
```

IntelliJ IDEA: right-click the field → Refactor → Pull Members Up. The IDE handles the access modifier adjustment automatically.

> [!tip] If the field names differ across subclasses but represent the same concept, rename them to match first, then pull up. Mismatched names are a sign the concept itself was never consciously shared.

@feynman

Pulling up a shared field is like moving the "emergency contact" box to the top of a form shared by multiple departments — every department needed it, so it belongs in the header, not re-drawn on each department's section.

@card
id: rfc-ch08-c004
order: 4
title: Pull Up Constructor Body
teaser: Constructor logic that is identical across subclasses should be expressed once in the superclass constructor — not replicated in every subclass that calls `super()` and then repeats the same assignments.

@explanation

Constructors in subclasses frequently start with a `super()` call and then repeat the same field initializations that every sibling subclass also performs. The duplication is harder to see than in methods because constructors are often short and treated as boilerplate, but the change-in-two-places problem is identical.

**Recipe:**
1. Identify the statements in each subclass constructor that are identical across all subclasses.
2. Move those statements into the superclass constructor.
3. Replace the duplicated statements in each subclass constructor with a `super(...)` call that passes the necessary arguments.
4. If any subclass has constructor logic that is *not* shared, leave it in the subclass after the `super(...)` call.
5. Compile and test.

```kotlin
// Before
class CheckingAccount(number: String, owner: String) : Account() {
    init {
        this.accountNumber = number
        this.ownerId = owner
        this.openedAt = LocalDate.now()
    }
}
class SavingsAccount(number: String, owner: String) : Account() {
    init {
        this.accountNumber = number
        this.ownerId = owner
        this.openedAt = LocalDate.now()
    }
}

// After
abstract class Account(number: String, owner: String) {
    protected val accountNumber: String = number
    protected val ownerId: String = owner
    protected val openedAt: LocalDate = LocalDate.now()
}
class CheckingAccount(number: String, owner: String) : Account(number, owner)
class SavingsAccount(number: String, owner: String) : Account(number, owner)
```

IntelliJ IDEA does not offer a dedicated "Pull Up Constructor Body" action — perform this manually.

> [!info] In Kotlin and Scala, primary constructor parameters with `val`/`var` often make this refactoring implicit: defining shared properties in the superclass primary constructor eliminates the duplication structurally.

@feynman

Pulling up constructor body is like moving the "plug in and power on" step from every device's setup guide into the general introduction — every device needs it, so it belongs in the shared preamble, not reprinted for each model.

@card
id: rfc-ch08-c005
order: 5
title: Push Down Method
teaser: A method on the superclass that is only relevant to one subclass is creating false promises for every other subclass — push it down to where it actually belongs.

@explanation

`Account` has a `calculateOverdraftFee()` method. `SavingsAccount` never has an overdraft. Callers holding a reference to `Account` see a method that has no meaning for half the implementations. The hierarchy is lying about what all accounts can do.

Push Down Method is the inverse of Pull Up: move the method from the parent into the subclass (or subclasses) that actually use it. The parent becomes more honest about the general contract, and the specialized behavior lives where it's meaningful.

**Recipe:**
1. Identify which subclasses actually use the method.
2. Copy the method into each of those subclasses.
3. Remove the method from the superclass.
4. If the superclass declared the method abstract, remove the declaration; update any subclasses that were forced to override it with an empty body.
5. Compile; check that no call sites reference the method through the superclass type (if they do, the design needs more thought before pushing down).

```kotlin
// Before
abstract class Account {
    fun calculateOverdraftFee(): Money { ... }   // meaningless for SavingsAccount
}

// After
abstract class Account  // no overdraft method

class CheckingAccount : Account() {
    fun calculateOverdraftFee(): Money { ... }
}
// SavingsAccount has no such method — and that's correct
```

IntelliJ IDEA: right-click the method → Refactor → Push Members Down.

> [!warning] If call sites reference the method through the superclass type (`Account.calculateOverdraftFee()`), pushing down will break the callers. Fix the call sites — typically by narrowing their type — before performing the push.

@feynman

Pushing down a method is like removing "knows how to operate a forklift" from the generic job description for all warehouse staff and putting it only in the forklift operator's role — most staff don't drive forklifts, and claiming they do misleads everyone.

@card
id: rfc-ch08-c006
order: 6
title: Push Down Field
teaser: A field on the superclass that only some subclasses use adds noise to the general type — push it down to the subclasses that actually need it.

@explanation

`Account` has an `overdraftLimit: Money` field. `SavingsAccount` never uses it. Every `SavingsAccount` instance carries a field that is conceptually null or irrelevant, and every developer reading `Account` is misled about what the concept of an account includes.

This is the field analogue of Push Down Method, and the recipe is the same mechanical sequence.

**Recipe:**
1. Identify which subclasses actually use the field.
2. Add the field to each of those subclasses.
3. Remove the field from the superclass.
4. Update all references to the field so they compile against the subclass type.
5. Compile and run tests.

```kotlin
// Before
abstract class Account {
    protected var overdraftLimit: Money = Money.ZERO  // unused in SavingsAccount
}

// After
abstract class Account  // no overdraftLimit

class CheckingAccount : Account() {
    private var overdraftLimit: Money = Money.ZERO
}
// SavingsAccount has no overdraftLimit — correct
```

IntelliJ IDEA: right-click the field → Refactor → Push Members Down.

> [!tip] If you find yourself setting a pushed-down field to a sentinel value (like zero or null) in subclasses that don't use it, that is a strong signal the field was in the wrong place to begin with — do the push.

@feynman

Pushing down a field is like removing "assigned locker number" from the general employee record and putting it only on the records for employees who work on-site — remote employees don't have lockers, and pretending they do just clutters the record.

@card
id: rfc-ch08-c007
order: 7
title: Extract Subclass
teaser: When one subset of a class's instances has behavior that the others never use, that subset is an implicit subclass waiting to be named.

@explanation

`Account` has an `isBusinessAccount: Boolean` field and a handful of methods (`calculateMonthlyFee()`, `assignRelationshipManager()`) that are only called when that flag is true. The flag is a type code in disguise — it divides instances into two behavioral populations, and the code is compensating with conditional checks rather than letting the type system express the distinction.

Extract Subclass formalizes that distinction: create a `BusinessAccount` subclass, move the flag-dependent behavior into it, and remove the flag from the base class.

**Recipe:**
1. Create the new subclass extending the existing class.
2. Add a constructor in the subclass that calls `super(...)` with the appropriate arguments.
3. Move the methods and fields that apply only to the subset into the subclass (using Push Down Method and Push Down Field).
4. For each place in the code that checks the flag before calling those methods, replace the check with a type check (`is BusinessAccount`) or, better, polymorphism.
5. Remove the flag field from the superclass.
6. Compile and test.

```kotlin
// Before
class Account(val accountNumber: String, val isBusiness: Boolean) {
    fun assignRelationshipManager(rm: Employee) {
        if (!isBusiness) throw IllegalStateException("Not a business account")
        ...
    }
}

// After
open class Account(val accountNumber: String)

class BusinessAccount(accountNumber: String) : Account(accountNumber) {
    fun assignRelationshipManager(rm: Employee) { ... }
}
```

IntelliJ IDEA does not offer a dedicated Extract Subclass action for Kotlin; perform this manually.

> [!warning] Extract Subclass is wrong when the "subset" behavior applies to different instances at different times — an account that starts personal and becomes a business account cannot switch its type at runtime. In that case, replace the type code with state or strategy instead.

@feynman

Extracting a subclass is like splitting a "general employee" badge into a "contractor" badge and a "full-time" badge — the distinction was always real, you were just paper-clipping a note to the general badge to mark the difference.

@card
id: rfc-ch08-c008
order: 8
title: Extract Superclass
teaser: When two sibling classes share enough fields and methods that you keep copying changes between them, they are implicitly describing a parent that you have not yet written.

@explanation

You have `CheckingAccount` and `LoanAccount`. They share `accountNumber`, `ownerId`, `openedAt`, `statementHeader()`, and `applyTransaction()`. Neither extends the other because there is no parent to extend — it was never extracted. Extract Superclass creates it.

This is different from Pull Up Method and Pull Up Field, which assume the hierarchy already exists. Extract Superclass creates the hierarchy from scratch when two classes are discovered to be siblings.

**Recipe:**
1. Create a new abstract class (the superclass) with no fields or methods yet.
2. Have both existing classes extend the new superclass.
3. Use Pull Up Field and Pull Up Method to move shared members to the superclass, one member at a time.
4. For behavior that differs between the two classes, either leave it in each subclass or extract it into an abstract method on the superclass that each subclass implements.
5. Compile and test after each member move.

```kotlin
// Before — two unrelated classes with shared fields and methods
class CheckingAccount {
    val accountNumber: String = ""
    val ownerId: String = ""
    fun statementHeader(): String = "Checking — #$accountNumber"
}
class LoanAccount {
    val accountNumber: String = ""
    val ownerId: String = ""
    fun statementHeader(): String = "Loan — #$accountNumber"
}

// After
abstract class Account {
    abstract val accountNumber: String
    abstract val ownerId: String
    abstract fun accountType(): String
    fun statementHeader(): String = "${accountType()} — #$accountNumber"
}
class CheckingAccount : Account() { override fun accountType() = "Checking" ... }
class LoanAccount : Account() { override fun accountType() = "Loan" ... }
```

IntelliJ IDEA: Refactor → Extract Superclass — available for Java; for Kotlin, use the Java extraction path or perform manually.

> [!info] If the two classes have different interfaces beyond the shared core, consider Extract Interface instead — a shared superclass is only appropriate when you also want to share implementation, not just the contract.

@feynman

Extracting a superclass is like discovering that two recipes you wrote independently both start with the same base sauce — you name the base sauce, write it once, and make both recipes reference it.

@card
id: rfc-ch08-c009
order: 9
title: Collapse Hierarchy
teaser: When a subclass adds nothing — no new fields, no overridden behavior, no meaningful distinction — the hierarchy has one level too many and the subclass should be merged into its parent.

@explanation

`PremiumSavingsAccount` extends `SavingsAccount`. You look at the subclass body: it's empty, or it overrides one method to call `super` with a slightly different default argument. The distinction that originally justified the subclass has been eroded by later changes. The hierarchy now has a level whose sole cost is reader confusion.

Collapse Hierarchy removes that level by merging the subclass into the superclass (or vice versa, depending on which name is more meaningful).

**Recipe:**
1. Decide which class absorbs the other — usually the superclass absorbs the subclass, but if the subclass name is better, consider renaming the superclass first.
2. Use Pull Up Field and Pull Up Method to move any remaining members from the subclass to the superclass.
3. Update all references to the subclass type to point to the superclass.
4. Delete the subclass.
5. Compile and run tests.

```kotlin
// Before — PremiumSavingsAccount adds nothing
open class SavingsAccount(val accountNumber: String)

class PremiumSavingsAccount(accountNumber: String) : SavingsAccount(accountNumber)
// Body is empty; "premium" is handled by a flag set elsewhere

// After
class SavingsAccount(val accountNumber: String)
// All former PremiumSavingsAccount references now use SavingsAccount
```

IntelliJ IDEA does not offer a dedicated "Collapse Hierarchy" action; perform manually by pulling up all members and deleting the subclass.

> [!tip] Before collapsing, search for any code that does `is PremiumSavingsAccount` or pattern-matches on the type. Those call sites need to be updated or the behavior they implement needs to move into `SavingsAccount` first.

@feynman

Collapsing a hierarchy is like merging an appendix back into the chapter it supplements when the appendix has grown so short that flipping to it adds more friction than the separation saves.

@card
id: rfc-ch08-c010
order: 10
title: Form Template Method
teaser: When two subclasses implement the same algorithm but fill in different details at specific steps, extract the algorithm's skeleton into the superclass and let each subclass override only the steps that differ.

@explanation

`CheckingAccount` and `SavingsAccount` both implement `generateStatement()`. The overall flow is the same — fetch transactions, format the header, format each line, append totals — but the formatting details differ per account type. The duplication is not in a single method you can pull up; it's tangled through parallel structure.

Form Template Method extracts the shared algorithm spine into the superclass as a non-overridable method, declares each varying step as an abstract (or overridable) method, and has each subclass override only the steps that differ.

**Recipe:**
1. Identify the common algorithm structure across both implementations.
2. Extract each varying step into its own method in each subclass, giving matching names to equivalent steps.
3. Pull up the invariant steps to the superclass (Pull Up Method).
4. Declare the varying steps as `abstract` (or with a default implementation) in the superclass.
5. Replace the full implementations in each subclass with overrides of only the varying steps.
6. Compile and test.

```kotlin
// Before
class CheckingAccount : Account() {
    fun generateStatement(): String {
        val header = "CHECKING — #$accountNumber"
        val lines = transactions.joinToString("\n") { "  CHK ${it.amount}" }
        return "$header\n$lines\nTotal: $balance"
    }
}
class SavingsAccount : Account() {
    fun generateStatement(): String {
        val header = "SAVINGS — #$accountNumber"
        val lines = transactions.joinToString("\n") { "  SAV ${it.amount}" }
        return "$header\n$lines\nTotal: $balance"
    }
}

// After — template method in superclass
abstract class Account {
    fun generateStatement(): String {         // template — do not override
        return "${statementHeader()}\n${formatLines()}\nTotal: $balance"
    }
    protected abstract fun statementHeader(): String
    protected abstract fun formatLines(): String
}
class CheckingAccount : Account() {
    override fun statementHeader() = "CHECKING — #$accountNumber"
    override fun formatLines() = transactions.joinToString("\n") { "  CHK ${it.amount}" }
}
class SavingsAccount : Account() {
    override fun statementHeader() = "SAVINGS — #$accountNumber"
    override fun formatLines() = transactions.joinToString("\n") { "  SAV ${it.amount}" }
}
```

IntelliJ IDEA does not offer a dedicated Form Template Method action; extract methods manually and then use Pull Members Up.

> [!warning] If the number of variation points grows beyond 3–4 abstract methods, the template method is doing too much. Consider Strategy instead — pass in an interchangeable formatter rather than extending to configure behavior.

@feynman

A template method is like a printed itinerary with blanks — the schedule of activities is fixed, but each participant fills in their own travel and accommodation details for the steps that vary.

@card
id: rfc-ch08-c011
order: 11
title: Replace Inheritance with Delegation
teaser: When a class inherits from a parent to reuse a handful of methods but the "is-a" relationship was never true, swap the inheritance for a field — the honest "has-a" design.

@explanation

`CheckingAccount` extends `ArrayList` because someone wanted `add()` and `size()` for free. But a checking account is not a list. Callers can now call `remove()`, `subList()`, or `sort()` on an account — operations that make no sense. The account has accidentally exposed the full list interface.

Replace Inheritance with Delegation wraps the formerly-inherited class as a private field instead, and provides only the subset of that interface that actually makes sense to delegate.

**Recipe:**
1. Create a field in the subclass that holds an instance of the superclass (or, better, an instance of a purpose-fit type).
2. Change each method that currently inherits behavior to delegate explicitly to that field.
3. Remove the `extends` clause.
4. Compile; fix any call sites that were relying on the superclass type being assignable from this class.
5. Run tests.

```kotlin
// Before — CheckingAccount "is" an ArrayList, which is wrong
class CheckingAccount : ArrayList<Transaction>() {
    val accountNumber: String = ""
    // inherits add(), remove(), sort(), subList() — none appropriate
}

// After — CheckingAccount "has" a list of transactions
class CheckingAccount(val accountNumber: String) {
    private val transactions: MutableList<Transaction> = mutableListOf()

    fun recordTransaction(t: Transaction) { transactions.add(t) }
    fun transactionCount(): Int = transactions.size
    // only the meaningful subset is exposed
}
```

IntelliJ IDEA: Refactor → Replace Inheritance with Delegation — available for Java and Kotlin; the IDE generates the delegate field and forwarding methods automatically.

> [!info] This is the most frequently needed refactoring in this chapter. "Extends for convenience" is extremely common in codebases that grew quickly, and it tends to compound: once a class inherits a broad interface, callers start depending on that interface, and the coupling deepens.

@feynman

Replacing inheritance with delegation is like switching from living in your employer's house to renting your own — you still have access to the resources you need, but the relationship is now honest and you control what you share.

@card
id: rfc-ch08-c012
order: 12
title: Replace Delegation with Inheritance
teaser: When a class delegates every method to a wrapped object and adds nothing of its own, the delegation is noise — a genuine "is-a" relationship expressed with unnecessary indirection.

@explanation

`SpecializedAccount` wraps an `Account` and forwards every single method call to it: `fun balance() = delegate.balance()`, `fun statementHeader() = delegate.statementHeader()`, and so on for a dozen methods. There is no transformation, no filtering, no additional state — just forwarding. The wrapping adds code volume without adding clarity. If `SpecializedAccount` truly is a kind of `Account`, make that structural.

Replace Delegation with Inheritance is the inverse of the previous refactoring — apply it only when the "is-a" relationship is genuinely true and substitutability holds.

**Recipe:**
1. Verify that the delegating class truly is a subtype of the delegate class — it can be used wherever the delegate is used without surprising callers.
2. Make the delegating class extend the delegate class.
3. For each delegating method that simply forwards to the wrapped instance unchanged, remove the forwarding method (the subclass now inherits it directly).
4. Remove the delegate field.
5. Compile and run tests; confirm no behavior changed.

```kotlin
// Before — forwarding every method adds no value
class SpecializedAccount(private val delegate: Account) {
    fun balance(): Money = delegate.balance()
    fun statementHeader(): String = delegate.statementHeader()
    fun recordTransaction(t: Transaction) = delegate.recordTransaction(t)
    // ...10 more forwarding methods
}

// After — the relationship is honest; inherit directly
class SpecializedAccount : Account() {
    // Inherits balance(), statementHeader(), recordTransaction() directly
    // Override only what genuinely differs
}
```

IntelliJ IDEA does not offer a dedicated "Replace Delegation with Inheritance" action for this direction; perform manually by adding the `extends` clause and removing forwarding methods one by one.

> [!warning] Do not apply this refactoring if the delegating class suppresses or modifies any of the forwarded methods. Suppression means the "is-a" claim is false — keep the delegation and revisit the design instead.

@feynman

Replacing delegation with inheritance is like discovering you have been hand-delivering every memo to a department that is already on the distribution list — once you realize the relationship is direct, you stop the manual relay and let the mail flow naturally.
