@chapter
id: rfc-ch02-code-smells
order: 2
title: Code Smells That Trigger Refactoring
summary: Code smells are the heuristics that tell you a refactoring is needed — surface symptoms of deeper design problems, each with a canonical name and a usual remedy.

@card
id: rfc-ch02-c001
order: 1
title: What a Code Smell Actually Is
teaser: A code smell is a surface signal that something in your design might be wrong — not a bug, not a rule, but a hint worth following.

@explanation

Kent Beck coined the term during the first edition of *Refactoring* to capture a class of observations that don't compile to a single error message but still leave an experienced developer uneasy. The term "smell" is deliberate: it's a sensory metaphor for something that might be fine or might indicate a deeper problem, depending on context.

Three things a smell is not:

- **Not a bug.** The code runs. It does what it claims to do. A smell is a structural concern, not a correctness concern.
- **Not a rule.** There is no "long method violation." Smells are heuristics — they raise a question, not a verdict.
- **Not always wrong.** A long method might be long because the domain is inherently complex. Primitive obsession might be fine in a script you throw away Friday. Context matters.

The value of naming smells is the vocabulary it creates. When you and your teammate both know what "shotgun surgery" means, you can have a ten-second conversation that would otherwise take ten minutes of pointing at code. The catalog in this chapter covers the thirteen most useful smells. For each one: what it looks like, when it matters, what tools surface it, and — briefly — what typically fixes it. The fixes themselves are separate refactoring operations catalogued in later chapters.

Tools that automate smell detection: SonarQube (covers most of this list with configurable thresholds), IntelliJ IDEA's built-in inspections, ESLint with the `complexity` and `max-lines-per-function` rules, and `pylint` for Python codebases.

> [!info] Naming smells gives your team a shared language. "This has shotgun surgery" is more actionable than "this feels messy to me."

@feynman

A code smell is like a musty odor in a basement — it doesn't tell you exactly what's wrong, but it tells you something is worth investigating before you close the door and forget about it.

@card
id: rfc-ch02-c002
order: 2
title: Long Method
teaser: The longer a method grows, the harder it becomes to name, test, and change — and the more it starts doing things that belong somewhere else.

@explanation

Long method is the most common smell in most codebases. The canonical threshold is loose — Fowler suggests that any method requiring a comment to explain a section of it is already too long. A stricter heuristic: if a method doesn't fit on one screen, treat that as a prompt to look at it.

The symptoms cluster around cognitive load:

- You need to scroll to understand what the method does.
- The method has multiple levels of indented logic that each solve a sub-problem.
- You're adding a comment above a block of lines to explain what the block does.
- The method name ends up being something like `processAndValidateAndSave`.

```ts
// The smell — one method doing data fetching, validation, transformation, and persistence
async function handleOrderSubmission(payload: OrderPayload) {
  const user = await db.users.findById(payload.userId);
  if (!user || !user.isActive) throw new Error("Invalid user");

  const items = payload.items.map(i => ({
    ...i,
    price: i.quantity * products[i.productId].unitPrice,
  }));
  const total = items.reduce((sum, i) => sum + i.price, 0);
  if (total < 0) throw new Error("Negative total");

  const order = await db.orders.create({ userId: user.id, items, total });
  await mailer.sendConfirmation(user.email, order.id);
  return order;
}
```

The usual remedy is Extract Method — pull each coherent chunk into a named function. SonarQube's `cognitive_complexity` metric and IntelliJ's "Method is too long" inspection are the automated surface points. ESLint's `max-lines-per-function` rule does the same for TypeScript and JavaScript.

The tradeoff: sometimes a long method is long because it is a single sequential procedure and splitting it would obscure the flow. Batch processing pipelines and migration scripts often fall here. A long method with a clear narrative and zero branching is less worrying than a short method with six levels of nested conditionals.

@feynman

A long method is like a run-on paragraph that keeps starting new topics without ever hitting a period — by the time you reach the end, you've forgotten what sentence you started on.

@card
id: rfc-ch02-c003
order: 3
title: Large Class
teaser: A class that has accumulated too many responsibilities tells you that several smaller, more focused abstractions are waiting to be separated out.

@explanation

A large class — sometimes called a God object — is the class-level version of long method. It has too many fields, too many methods, and a name so broad (`Manager`, `Handler`, `Service`, `Processor`) that it can justify absorbing anything. The smell is about breadth of responsibility, not just line count.

Indicators:

- The class has field groups that are only used by a subset of its methods.
- You find yourself scrolling through it to find unrelated behaviors that both happen to live there.
- The class name can't be made specific without becoming a sentence.
- Tests for this class are enormous and unrelated to each other.

```java
// The smell — one class managing users, emails, and billing
public class UserManager {
    private Database db;
    private EmailClient emailClient;
    private BillingSystem billing;
    private AuditLog auditLog;

    public User createUser(String email, String plan) { ... }
    public void sendWelcomeEmail(User user) { ... }
    public void chargeForPlan(User user) { ... }
    public List<User> getActiveUsers() { ... }
    public void logAction(User user, String action) { ... }
    public void updateSubscription(User user, String newPlan) { ... }
}
```

The usual remedy is Extract Class — identify which fields and methods form a coherent cluster and pull them into their own type. `UserManager` above contains at least three classes: `UserRepository`, `UserMailer`, and `SubscriptionService`.

SonarQube tracks this under the "God Class" rule (`squid:S2176` and related). IntelliJ's "Class too long" inspection is a blunt approximation. The more targeted signal is Lack of Cohesion of Methods (LCOM) metrics available in SonarQube and code analysis tools like CodeScene.

The tradeoff: application entry points (App, Main, Router) are legitimately larger because they wire things together. Coordination classes aren't the same as God classes. The smell applies when a class both coordinates and implements.

> [!warning] A class named `Manager`, `Service`, or `Helper` is not evidence of the smell by itself — but it's worth scrutinizing every time you see one.

@feynman

A large class is like a junk drawer in your kitchen — technically everything fits, but finding the scissors requires moving the takeout menus, the phone charger, and three mystery batteries.

@card
id: rfc-ch02-c004
order: 4
title: Primitive Obsession
teaser: Using raw strings and integers where a small domain type would carry meaning, validation, and constraints is a subtle smell that compounds as the codebase grows.

@explanation

Primitive obsession happens when domain concepts that have rules, formats, or structure are represented as plain language primitives (`string`, `int`, `boolean`) instead of dedicated types. The code works, but the constraints live in comments, validation functions scattered across the codebase, or in the heads of the people who've been around longest.

Common examples:

- An email address as `string` instead of an `Email` value type that validates on construction.
- A money amount as `float` or `int` instead of a `Money` type that carries its currency.
- A status as `string` instead of an enum with exhaustive cases.
- Coordinates as two separate `Double` fields instead of a `Coordinate` struct.

```swift
// The smell — raw primitives for structured domain values
func createOrder(userId: String, amount: Double, currency: String, status: String) {
    // What's a valid userId? What precision does amount have?
    // What are valid currency values? Valid status strings?
    // None of these constraints are enforced here.
}
```

The usual remedies are Replace Primitive with Object or Introduce Value Object. The resulting types become natural homes for validation and behavior that currently float loose.

The tradeoff: not every string needs to be a type. A `firstName: String` on a `User` model doesn't warrant a `FirstName` wrapper. The signal is whether the primitive carries domain rules (format, range, valid values) that appear in multiple places — if so, a type earns its keep. If it's a simple label with no constraints, a primitive is fine.

> [!tip] The test: if you've written the same validation logic for this field in more than one place, you have a candidate for a value type.

@feynman

Primitive obsession is like labeling every folder "stuff" — the contents are all there, but you've thrown away the information that would make them useful.

@card
id: rfc-ch02-c005
order: 5
title: Long Parameter List
teaser: When a function takes more arguments than working memory can hold at once, callers lose track of what each position means and the signature becomes resistant to change.

@explanation

The cognitive science rule of thumb is around seven items — beyond that, humans start dropping things. A function with six or more parameters is already in this zone, and the failures are predictable: callers pass arguments in the wrong order, optional parameters get confused with required ones, and adding a new parameter means touching every call site.

```py
# The smell — a function whose call site requires reading the definition
def send_notification(
    user_id: str,
    message: str,
    channel: str,
    priority: int,
    retry_count: int,
    delay_seconds: int,
    fallback_email: str,
):
    ...

# At the call site, the meaning of each argument is invisible
send_notification(user.id, body, "push", 2, 3, 0, user.email)
```

Usual remedies: Introduce Parameter Object (group related parameters into a single value type), or Preserve Whole Object (pass the owning object instead of extracting multiple fields from it). In Python and TypeScript, mandatory keyword arguments partially mitigate the ordering risk, but don't address the root problem.

IntelliJ flags this as "Method has too many parameters." SonarQube tracks it under the "Too many parameters" rule, configurable per language.

The tradeoff: framework-level constructors and dependency injection entry points often have legitimately long signatures that are called in exactly one place. The smell matters most when the function is called in many places and the call sites are hard to read or easy to get wrong.

@feynman

A long parameter list is like a form that asks for eighteen fields on one page — by the time you've filled in the last field, you've already forgotten what you wrote in the first.

@card
id: rfc-ch02-c006
order: 6
title: Data Clumps
teaser: Fields that always appear together are telling you they belong to the same concept — and that concept deserves a name.

@explanation

Data clumps are groups of data items that keep showing up as a set: in method parameters, in object fields, in database query results. The tell is that removing any one item from the group would leave the others without context. They're already a concept — they just don't have a name yet.

Classic examples:

- `startDate` and `endDate` appearing together in five method signatures.
- `street`, `city`, `postCode`, and `country` as four separate fields on every form and model.
- `host`, `port`, and `credentials` passed as a triple to every database function.

```go
// The smell — three fields that always travel as a unit, unnamed
func connectToDatabase(host string, port int, credentials string) *DB { ... }
func validateConnection(host string, port int, credentials string) bool { ... }
func logConnectionAttempt(host string, port int, credentials string) { ... }
```

The usual remedy is Extract Class or Introduce Value Object — give the cluster a name (`DatabaseConfig`, `DateRange`, `Address`) and operate on it as a unit. This typically results in fewer parameters per call site and a natural home for any behavior that belongs to the concept.

The tradeoff: if the cluster only appears in one place and never needs validation or behavior, a named struct might be premature. Data clumps earn extraction when they recur across multiple call sites or when behavior (validation, formatting, comparison) starts accumulating on individual fields.

> [!tip] The three-occurrence rule: if you see the same group of fields together in three places, name it.

@feynman

Data clumps are like a group of coworkers who always eat lunch together, take the same train, and cc each other on every email — at some point, they're effectively a team and deserve to be recognized as one.

@card
id: rfc-ch02-c007
order: 7
title: Feature Envy
teaser: A method that spends most of its time reaching into another class's data is probably in the wrong class.

@explanation

Feature envy is the smell where a method is defined in class A but spends most of its effort touching the fields or methods of class B. The method "envies" class B — it clearly wants to be there. The behavioral tell is a chain of getters or a heavy use of another object's internals to compute something.

```kotlin
// The smell — Invoice.calculateDiscount spends all its time in Customer
class Invoice(val customer: Customer, val amount: Double) {
    fun calculateDiscount(): Double {
        val years = customer.yearsAsMember()
        val tier = customer.loyaltyTier()
        val purchaseHistory = customer.totalPurchases()
        return when {
            years > 5 && tier == "gold" && purchaseHistory > 10000 -> amount * 0.20
            years > 2 && tier == "silver" -> amount * 0.10
            else -> 0.0
        }
    }
}
```

The logic `calculateDiscount` is implementing belongs to `Customer` — it's entirely driven by customer state and has nothing to do with the invoice except for the final multiplication. Moving the method to `Customer` eliminates the envy and makes `Customer` the right place for discount policies.

The usual remedy is Move Method. In more complex cases, part of a method envies one class and part envies another — Extract Method first, then move each piece to where it belongs.

IntelliJ IDEA has a "Feature Envy" inspection under Code Inspections that flags exactly this pattern. CodeScene tracks it as a complexity-hotspot metric.

The tradeoff: Strategy and Visitor patterns deliberately have methods that operate on another class's data. These are intentional design patterns, not accidental envy — context distinguishes them.

@feynman

Feature envy is like a team member who keeps walking over to another team's board to make updates — at some point, that person probably belongs on the other team.

@card
id: rfc-ch02-c008
order: 8
title: Shotgun Surgery
teaser: If making one logical change requires touching many unrelated files, your design has scattered what should be cohesive into pieces that are expensive to keep in sync.

@explanation

Shotgun surgery is the inverse of divergent change. Where divergent change is one class changing for many reasons, shotgun surgery is one reason causing changes in many classes. You make a conceptually simple change — adding a new payment method, adding a new notification channel, adding a user role — and your diff touches a dozen files in unrelated directories.

```ts
// The smell — adding "sms" notification requires editing six separate files:
// notification-router.ts
// user-preferences.ts
// admin-dashboard.ts
// onboarding-flow.ts
// notification-constants.ts
// notification-analytics.ts

// Each file has a different switch/if-chain that handles notification channels
switch (channel) {
  case "email": ...
  case "push": ...
  // "sms" needs to be added here, and in five other places
}
```

The usual remedy is Move Method combined with Inline Class — consolidate the scattered logic into a single, cohesive place. In the example above, a `NotificationChannel` type or a plugin/registry pattern would let you add "sms" in one file.

SonarQube's "Divergent Change" rule and CodeScene's "Temporal Coupling" analysis identify files that change together repeatedly, which surfaces shotgun surgery patterns in historical commit data. `git log --stat` or `git log --all --follow` over a cluster of files can reveal the pattern manually.

The tradeoff: framework-driven conventions sometimes require registering things in multiple places (e.g., Django's URL router + views + admin + serializers). This is framework structure, not design failure. The smell applies when the scatter is accidental rather than prescribed.

> [!warning] If your PR diffs routinely touch ten files for a change that sounds like one sentence, that's a strong signal of shotgun surgery somewhere in the affected code path.

@feynman

Shotgun surgery is like updating your address and having to call your bank, your gym, your dentist, your employer, and three delivery services separately because nothing shares a common record.

@card
id: rfc-ch02-c009
order: 9
title: Divergent Change
teaser: When a class needs to change for several different reasons across its lifetime, it's doing too many jobs and should be split along its change axes.

@explanation

Divergent change says: if you look at a class and can identify multiple unrelated reasons why you might open it and edit it, the class should probably be split. The heuristic connects directly to the Single Responsibility Principle — a class should have one reason to change.

A common place to find this: a controller or service class that handles both the HTTP wire format and the domain logic. You change it when a new API field comes in, and you change it again when a business rule changes, and you change it a third time when a new integration is added.

```py
# The smell — OrderService changes for three different reasons:
# 1. When order processing rules change
# 2. When the payment gateway API changes
# 3. When reporting requirements change
class OrderService:
    def process_order(self, order): ...        # domain logic
    def charge_payment(self, order): ...       # payment integration
    def generate_order_report(self, order): ... # reporting concern
```

The usual remedy is Extract Class — split the class along its change axes. `OrderProcessor`, `PaymentGateway`, and `OrderReporter` each change for a single reason and can be modified, tested, and deployed independently.

Divergent change and shotgun surgery are mirrors: divergent change is one class, many reasons; shotgun surgery is one reason, many classes. A codebase with both has a design structure misaligned with its change patterns.

The tradeoff: small codebases and early-stage projects sometimes accept some divergent change deliberately — extracting classes before the change axes are proven is premature. The smell earns intervention once the class has changed for multiple reasons at least twice.

@feynman

Divergent change is like a Swiss Army knife being used by a chef — it can technically do the work, but when the blade needs sharpening and the corkscrew needs replacing at the same time, you start to wish you had separate tools.

@card
id: rfc-ch02-c010
order: 10
title: Comments as Deodorant
teaser: A comment that describes what a block of code does is a signal that the code could be named well enough to make the comment unnecessary.

@explanation

Fowler's phrase "comments as deodorant" is deliberately provocative: comments that explain what code does are masking the smell of code that can't explain itself. This is different from comments that explain *why* a decision was made — those are valuable. The smell is specifically the what-comment.

```java
// The smell — comments compensating for unexpressive code
public double calc(Order o) {
    // calculate base price
    double b = o.qty * o.price;

    // apply seasonal discount
    double d = b * 0.15;

    // add tax
    double t = (b - d) * 0.08;

    return b - d + t;
}
```

Each of those comments is a free method name waiting to be claimed. `calculateBasePrice`, `applySeasonalDiscount`, `calculateTax` would eliminate the need for the comments and name the operations explicitly.

The usual remedy is Extract Method — pull the commented block into a named function. The function name replaces the comment. In editors like IntelliJ IDEA, the "Replace comment with self-explanatory code" inspection nudges toward this. ESLint doesn't flag this pattern, but SonarQube has smell detectors for methods with high comment density relative to code lines.

The tradeoff: some comments are good. A well-placed comment explaining a counterintuitive algorithm, a regulatory constraint, or a hard-won workaround for a library bug is not deodorant — it's documentation of reasoning that code alone can't express. The smell is specifically comments that document what the next line already says, not comments that explain why it says it.

> [!tip] A useful test: delete the comment. If the code becomes harder to understand, the comment was earning its place. If the code reads fine, the comment was deodorant.

@feynman

A comment explaining what a line of code does is like a caption on a photo that just says what's already in the photo — if the subject were labeled better, the caption would be redundant.

@card
id: rfc-ch02-c011
order: 11
title: Speculative Generality
teaser: Abstractions written for future needs that never arrive add complexity without benefit — YAGNI in its smell form.

@explanation

Speculative generality is the smell of code built for imagined futures. The implementation supports use cases that don't exist yet, has hooks for extensibility that nobody has asked for, or wraps a simple operation in a framework-sized abstraction because "we might need it later."

Signs it's present:

- Interfaces with only one implementation.
- Abstract base classes with a single concrete subclass.
- Parameters that are passed through multiple layers and never actually vary.
- Callback hooks, plugin registries, or strategy patterns that have exactly one registered implementation.
- Configuration objects with thirty fields, twenty-eight of which are always set to defaults.

```ts
// The smell — an abstract pipeline framework for one use case
abstract class DataProcessor<T, R> {
  abstract transform(input: T): R;
  abstract validate(input: T): boolean;
  abstract handleError(error: Error): void;
  process(input: T): R | null { ... }
}

class CsvParser extends DataProcessor<string, Row[]> {
  // The only concrete implementation. Ever.
  transform(input: string): Row[] { ... }
  validate(input: string): boolean { ... }
  handleError(error: Error): void { console.error(error); }
}
```

The usual remedy is Collapse Hierarchy or Remove Middle Man — remove the abstraction layer and work with the concrete implementation directly until a second use case arrives that earns it.

The tradeoff: platform code, public libraries, and SDK-level abstractions are legitimately designed for extensibility, since external consumers will add implementations you don't control. The smell applies to internal application code where you control all consumers and the anticipated extension never materializes.

@feynman

Speculative generality is like installing a revolving door on a broom closet because "we might turn it into a lobby someday" — the flexibility costs something real, and the future need might never come.

@card
id: rfc-ch02-c012
order: 12
title: Duplicate Code
teaser: When the same logic exists in more than one place, the next change that touches that logic requires you to find and update every copy — and one will be missed.

@explanation

Duplicate code is the original sin of software design. It comes in three forms with increasing complexity:

1. **Exact duplication** — the same block of code appears verbatim in two places. The easiest case. Extract Method and call it from both.
2. **Near-duplication** — two methods do almost the same thing with minor variations. Extract Method with parameters, or Form Template Method if the structure is shared between subclasses.
3. **Conceptual duplication** — two pieces of code implement the same concept differently. Hardest to detect; requires understanding intent, not just comparing text.

The rule of three provides a concrete evidence standard: the first time you write something, write it. The second time you encounter the same pattern, note it. The third time, extract it.

```rust
// The smell — the same validation logic in two functions
fn create_user(email: &str) -> Result<User, Error> {
    if email.is_empty() || !email.contains('@') {
        return Err(Error::InvalidEmail);
    }
    // ...
}

fn update_email(user_id: u64, email: &str) -> Result<(), Error> {
    if email.is_empty() || !email.contains('@') {
        return Err(Error::InvalidEmail);
    }
    // ...
}
```

SonarQube's "Duplicated Blocks" rule is the standard automated detector. IntelliJ IDEA's Duplicate Code Detection (Analyze → Locate Duplicates) finds structural duplication even when variable names differ. `jscpd` is a standalone duplicate-code detector for JavaScript, TypeScript, and several other languages.

The tradeoff: sometimes duplication is the right tradeoff — especially across module or service boundaries where coupling is more dangerous than the duplication. Duplication across microservices or between a frontend and backend model is often acceptable. The smell applies most directly within a single module or class hierarchy.

> [!info] The rule of three: tolerate duplication once. Extract on the third occurrence. Extracting on the second is often premature — you may not yet know the right abstraction.

@feynman

Duplicate code is like keeping the same contact in your phone three times under slightly different names — when the number changes, you'll update one and wonder why you're still reaching voicemail on the others.

@card
id: rfc-ch02-c013
order: 13
title: Mysterious Name
teaser: A name that doesn't communicate its purpose makes every subsequent reader do extra work — and renaming is usually the highest-value, lowest-risk refactoring in the catalog.

@explanation

The mysterious name smell is the smallest and most universal entry in the catalog. It applies to variables, functions, classes, modules, parameters, and constants. The symptom is that you have to read the body of a thing to understand what it does — the name doesn't do the work of explanation.

Common forms:

- Single-letter variable names outside of a known convention (e.g., `i` in a for loop is fine; `x` in a domain function is not).
- Abbreviations that require context to decode (`usr`, `cfg`, `proc`, `mgr`).
- Generic names that describe type but not purpose (`data`, `info`, `result`, `temp`, `value`).
- Names that are technically accurate but miss the domain intent (`calculateValue` instead of `calculateInvoiceTotal`).

```go
// The smell — every name is technically valid but tells you nothing
func proc(d []map[string]interface{}) []map[string]interface{} {
    var res []map[string]interface{}
    for _, item := range d {
        if item["s"] == "active" {
            res = append(res, item)
        }
    }
    return res
}
```

What does `proc` do? What is `d`? What is `s`? The function filters a collection by a status field — but nothing in the code communicates that.

The usual remedy is Rename (Variable, Function, or Class). Modern IDEs make this mechanical and safe — IntelliJ's Rename refactoring, VS Code's rename symbol, and `gorename` for Go all propagate changes across the entire codebase in one operation with full reference tracking.

The tradeoff: very small scopes (a two-line closure, a loop index) tolerate abbreviated names when convention makes the intent clear. The smell applies when a name outlives the context where its meaning is obvious.

> [!tip] A good name test: if you have to open the function body to understand what a call site does, the function name is not earning its place.

@feynman

A mysterious name is like a filing cabinet drawer labeled "stuff" — you know it has contents, but you have to open it every single time because the label refuses to tell you anything useful.
