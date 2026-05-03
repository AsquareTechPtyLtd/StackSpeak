@chapter
id: rfc-ch06-simplifying-conditionals
order: 6
title: Simplifying Conditionals
summary: Conditional logic accumulates faster than any other part of a codebase, and the refactorings in this chapter — guard clauses, polymorphism, null objects, decomposition — are how you keep branches readable and behavior reasonable to test.

@card
id: rfc-ch06-c001
order: 1
title: Conditional Logic Is Design Debt
teaser: Nested conditionals don't just make code harder to read — they make behavior impossible to reason about in isolation, and that compounds every time a new case is added.

@explanation

When a billing function gains a branch for premium accounts, then another for trial accounts, then one for legacy grandfathered plans, you don't have a complex function — you have a function that is doing five things at once, all of them hidden inside an `if`/`else` ladder. Each new branch multiplies the number of paths through the code. A function with five independent booleans has thirty-two possible execution paths. You can't test them all. You can't describe them all. And the next developer to open that file will read it three times before touching it.

The compounding problem is that conditionals attract conditionals. A branch added for one reason gets extended for another, and within a year the original intent is buried under pragmatic fixes. The cost is not just readability — it is testability, because unit tests must cover branches, and modifiability, because a new case requires understanding every existing branch before you know where to add yours.

This chapter's refactorings all push in the same direction: get the branching logic out of the function body and into a structure — a named method, a class hierarchy, a map, a guard clause — that can be read, tested, and extended independently. Guard clauses eliminate the nesting of "happy path" logic. Polymorphism replaces type-based dispatch with a structure that makes adding new types non-disruptive. Null Objects and Special Cases remove the most common category of defensive conditionals entirely.

The theme is not "avoid conditionals." The theme is that a conditional is a decision, and decisions belong somewhere that makes them legible.

> [!info] A function that is hard to name is often a function with too many branches. If you cannot write a one-line description without the word "or," the function needs to be split.

@feynman

Nested conditionals are like a legal contract where every clause has a sub-clause and every sub-clause has an exception — technically precise, but nobody can tell you what it actually says without reading the whole thing.

@card
id: rfc-ch06-c002
order: 2
title: Decompose Conditional
teaser: When you can't name what a condition is checking, the condition is doing too much — extract it, and the intent becomes visible from the call site.

@explanation

The signal: a condition like `order.total > 1000 && order.customer.tier === "gold" && !order.hasDiscount` sits inline in an `if` statement. Reading it requires parsing the logic, not reading the intent. The then-branch and the else-branch may be equally dense.

The recipe:
1. Select the condition expression.
2. Extract it to a named method: `isEligibleForBulkDiscount(order)`.
3. Select the then-branch body.
4. Extract it to a named method: `applyBulkDiscount(order)`.
5. Repeat for the else-branch: `applyStandardPricing(order)`.

```ts
// Before
function calculateTotal(order: Order): number {
  if (order.total > 1000 && order.customer.tier === "gold" && !order.hasDiscount) {
    total = order.total * 0.85;
  } else {
    total = order.total;
  }
  return total;
}

// After
function calculateTotal(order: Order): number {
  return isEligibleForBulkDiscount(order)
    ? applyBulkDiscount(order)
    : order.total;
}
```

Both IntelliJ IDEA and WebStorm support "Extract Method" as a keyboard shortcut (`Cmd+Alt+M` on macOS). VS Code has "Extract to function" in the refactor menu (`Cmd+.` → Refactor). The condition expression and each branch can be extracted in three separate steps.

When not to apply: if the condition is already one clear expression and the branch bodies are one line each, this is overhead without payoff. Only extract when the extraction produces a name that means more than the code it replaces.

@feynman

Decomposing a conditional is like replacing a long street address with a landmark name — "the corner of 5th and Market, third door past the blue awning" becomes "City Hall," and everyone immediately knows where you mean.

@card
id: rfc-ch06-c003
order: 3
title: Consolidate Conditional Expression
teaser: When several conditions all lead to the same outcome, merging them into one named check removes the false impression that they are separate decisions.

@explanation

The signal: a sequence of `if` statements all returning or assigning the same value — `false`, `null`, `0` — before the real logic begins. Each check looks like a distinct decision, but they are all one decision: this input is ineligible. Keeping them separate suggests they have different meanings when they don't.

The recipe:
1. Confirm all branches produce the same result (same return, same assignment).
2. Combine conditions with `||` (or `&&`) into a single expression.
3. Extract the combined condition into a named method.
4. Remove the redundant individual checks.

```ts
// Before
function calculateCommission(rep: SalesRep): number {
  if (rep.isOnLeave) return 0;
  if (rep.territory === null) return 0;
  if (rep.quotaAchieved < 0.5) return 0;
  return rep.baseSalary * 0.1;
}

// After
function calculateCommission(rep: SalesRep): number {
  if (isIneligibleForCommission(rep)) return 0;
  return rep.baseSalary * 0.1;
}

function isIneligibleForCommission(rep: SalesRep): boolean {
  return rep.isOnLeave || rep.territory === null || rep.quotaAchieved < 0.5;
}
```

IntelliJ's "Merge sequential if-return" inspection can suggest this automatically. In VS Code, the consolidation is manual but the subsequent "Extract to function" step benefits from refactor actions.

When not to apply: if each condition is actually a separate business rule that future maintainers might need to distinguish — for example, one triggers a different error message than the others — collapsing them erases that distinction. Consolidate only when the conditions are genuinely one logical check.

@feynman

Consolidating conditional fragments is like merging three "out of office" autoresponders into one — each had the same message, and receiving three copies created the false impression that something different was happening each time.

@card
id: rfc-ch06-c004
order: 4
title: Consolidate Duplicate Conditional Fragments
teaser: Code that appears in every branch of a conditional belongs outside the conditional — duplication inside branches is an invitation for the branches to diverge.

@explanation

The signal: every branch of an `if`/`else` or `switch` starts with the same setup, or ends with the same teardown. The duplication is subtle because the lines aren't adjacent — they're scattered across branches. When one branch gets updated and another doesn't, the divergence introduces a bug that is genuinely hard to spot in a diff.

The recipe:
1. Identify the statement(s) duplicated in all branches.
2. If duplicated at the start: move them before the conditional.
3. If duplicated at the end: move them after the conditional.
4. If duplicated in the middle of long branches: this may indicate the conditional needs to be split into two smaller conditionals.

```ts
// Before
function processPayment(order: Order): void {
  if (order.paymentMethod === "card") {
    chargeCard(order);
    order.status = "paid";
    sendReceipt(order);
  } else {
    chargeBankTransfer(order);
    order.status = "paid";
    sendReceipt(order);
  }
}

// After
function processPayment(order: Order): void {
  if (order.paymentMethod === "card") {
    chargeCard(order);
  } else {
    chargeBankTransfer(order);
  }
  order.status = "paid";
  sendReceipt(order);
}
```

IDEs don't have a dedicated context action for this refactoring; it's a manual move. However, a code formatter or linter running after the change will confirm nothing else moved inadvertently.

When not to apply: if the duplicated line behaves differently in each branch because of side-effects — for example, `sendReceipt` uses a value that differs between branches — moving it outside is incorrect. Verify with a test before moving.

@feynman

Duplicate conditional fragments are like every chapter of a book ending with the same acknowledgment paragraph — it belongs in the front matter once, not repeated at the end of every chapter where it dilutes the actual content.

@card
id: rfc-ch06-c005
order: 5
title: Replace Nested Conditional with Guard Clauses
teaser: When the core logic of a function is buried inside a nesting of safety checks, guard clauses invert the branches and let the happy path read linearly from top to bottom.

@explanation

The signal: a function's main behavior is indented three or four levels deep because it is wrapped in `if (condition) { if (condition) { if (condition) { ... } } }`. Each level is a defensive check — null check, role check, state check — and the code that matters is the deepest layer.

The recipe:
1. Identify each guarding condition — conditions that exit early if not met.
2. For each one, invert the condition and return early (or throw).
3. Remove the `else` that was the "valid" branch — it becomes the body of the function after the guard.
4. Repeat for each nested level, working outside-in.

```ts
// Before
function approveExpense(claim: ExpenseClaim): void {
  if (claim !== null) {
    if (claim.status === "pending") {
      if (claim.submittedBy.isActive) {
        processApproval(claim);
      }
    }
  }
}

// After
function approveExpense(claim: ExpenseClaim): void {
  if (claim === null) return;
  if (claim.status !== "pending") return;
  if (!claim.submittedBy.isActive) return;
  processApproval(claim);
}
```

IntelliJ and Rider offer "Replace if with early return" in the refactor menu and as a quick fix inspection. VS Code requires the inversion manually; the `Cmd+.` refactor menu sometimes suggests "Flip if statement."

When not to apply: if the function has cleanup logic (resource release, logging) that must run regardless of the early return path, guard clauses require careful placement or a `try/finally` wrapper. Also avoid if early returns are forbidden by your team's style guide — some codebases enforce single-exit discipline.

> [!tip] Guard clauses also improve diff readability. Adding a new precondition adds one line at the top; it doesn't change the indentation of the entire function body.

@feynman

Guard clauses are like checking your bag at the door before a meeting — you eliminate all the reasons the meeting can't happen upfront, so the meeting itself can proceed without interruption.

@card
id: rfc-ch06-c006
order: 6
title: Replace Conditional with Polymorphism
teaser: When a switch or if/else dispatches on an object's type or category to produce different behavior, that dispatch belongs in the type hierarchy — not in the caller.

@explanation

The signal: a function contains a `switch (order.type)` or `if (permission.role === "admin")` block where each branch does a qualitatively different thing. The switch recurs — the same `order.type` dispatch appears in pricing, in validation, in the receipt format. Every new order type requires touching all of them.

The recipe:
1. Create a class (or interface) for the shared concept — `PricingStrategy`, `PermissionPolicy`.
2. Move each branch's logic into a concrete subclass or implementation.
3. Replace the conditional in the caller with a polymorphic call.
4. Remove the original switch from each site that used it.

```ts
// Before
function getDiscount(order: Order): number {
  switch (order.customerType) {
    case "retail": return 0;
    case "wholesale": return 0.15;
    case "partner": return 0.25;
  }
}

// After
interface DiscountPolicy { calculate(order: Order): number; }

class RetailDiscount implements DiscountPolicy {
  calculate(_: Order) { return 0; }
}
class WholesaleDiscount implements DiscountPolicy {
  calculate(_: Order) { return 0.15; }
}
class PartnerDiscount implements DiscountPolicy {
  calculate(_: Order) { return 0.25; }
}

// Caller:
order.discountPolicy.calculate(order);
```

IntelliJ has a dedicated "Replace Conditional with Polymorphism" context action that scaffolds the class hierarchy and migrates branches automatically — it is one of the most powerful automated refactorings in the tool. VS Code requires manual extraction.

When not to apply: if there are only two stable cases and they are genuinely unlikely to grow, a simple ternary is less ceremony. Polymorphism adds a class per variant; if the variants are trivially different (a boolean flag), a map lookup or strategy function is lighter weight.

> [!warning] Polymorphism is the right answer when behavior varies per type. It is the wrong answer when data varies per type — for that, a plain data structure or a type union is simpler.

@feynman

Replacing a conditional with polymorphism is like replacing a customer service script with specialists — instead of one agent who reads from a flowchart for every account type, you route each customer to someone who handles only their kind of account.

@card
id: rfc-ch06-c007
order: 7
title: Introduce Null Object
teaser: When every call site checks for null before using an object, the null check is scattered business logic — a Null Object absorbs it by giving null a no-op identity.

@explanation

The signal: `if (customer !== null) customer.notify(...)` appears in five places. Or every function that accepts a `User` begins with `if (!user) return`. The null check is not defensive programming — it is a repeated policy decision (do nothing when there's no customer) that belongs in one place.

The recipe:
1. Create a `NullCustomer` class (or subclass) that implements the same interface as `Customer`.
2. Implement each method as a safe no-op or a sensible default — `notify()` does nothing; `getName()` returns "Guest"; `isActive()` returns false.
3. Replace `null` at creation time with `new NullCustomer()`.
4. Remove the null checks at each call site.

```ts
// Before
function sendPromotion(customer: Customer | null): void {
  if (customer !== null && customer.isOptedIn) {
    emailService.send(customer.email, promoTemplate);
  }
}

// After
class NullCustomer implements Customer {
  readonly isOptedIn = false;
  readonly email = "";
}

function sendPromotion(customer: Customer): void {
  if (customer.isOptedIn) {
    emailService.send(customer.email, promoTemplate);
  }
}
```

Neither IntelliJ nor VS Code has a dedicated "Introduce Null Object" action. The creation is manual; the call-site cleanup is a series of inline deletions once the null object is wired in. TypeScript's strict null checks (`strictNullChecks: true`) will point to every location that previously accepted `| null`, guiding the cleanup.

When not to apply: if callers legitimately need to distinguish "no customer" from "a customer who hasn't opted in," a null object hides that distinction. Only introduce one when "no value" and "default value" truly mean the same thing in your domain.

@feynman

A Null Object is like a polite hold music track — when there's nobody on the line, callers don't get an error or silence, they get a sensible placeholder that handles the situation gracefully.

@card
id: rfc-ch06-c008
order: 8
title: Introduce Special Case
teaser: Null Object is the most common special case — but any "weird value" that triggers repeated conditional handling deserves its own type, not its own if-block at every call site.

@explanation

The signal: code keeps checking for a specific edge-case value — a suspended account, a deleted order, an unverified user — and each check is followed by the same fallback behavior. The edge case is not null; it is a real domain concept that has been represented as a conditional rather than a type.

The recipe:
1. Identify the value or state that triggers the repeated check.
2. Create a class that extends or implements the relevant type — `SuspendedAccount`, `DeletedOrder`.
3. Implement the methods with the edge-case behavior — `getBalance()` returns zero, `canCheckout()` returns false, `statusLabel()` returns "Suspended".
4. Produce instances of the special-case class at the boundary where they enter the system.
5. Remove the conditional checks at each call site.

```ts
// Before
function getBillingLabel(account: Account): string {
  if (account.status === "suspended") return "Account Suspended";
  return `Balance: ${formatCurrency(account.balance)}`;
}

// After
class SuspendedAccount extends Account {
  getBillingLabel(): string { return "Account Suspended"; }
  get balance(): number { return 0; }
}

// Caller:
function getBillingLabel(account: Account): string {
  return account.getBillingLabel();
}
```

No dedicated IDE action exists for this refactoring. The creation of the special-case class is a design decision; the call-site cleanup follows naturally once the class is in place.

When not to apply: if the edge case only occurs in one place and is stable, the special-case class is more ceremony than it saves. The refactoring pays off when the same value triggers conditional handling in three or more locations.

> [!info] Special Case is a generalization of Null Object. Every null object is a special case, but not every special case is null — a trial account, a deleted record, or a system user are all candidates.

@feynman

Introduce Special Case is like creating a "Press 1 for billing" option on a phone system — instead of every department asking "is this a billing call?" and handling it themselves, billing gets its own path from the start.

@card
id: rfc-ch06-c009
order: 9
title: Introduce Assertion
teaser: When your code assumes something is true but never checks it, you're relying on a social contract — an assertion makes the assumption explicit and crashes loudly when reality doesn't match.

@explanation

The signal: a comment like `// assume order is already validated here` or `// customerId should never be null at this point`. The assumption is real, it was agreed on by the team, but there is no mechanism that enforces it. When the assumption breaks — a refactoring changes the call order, a new caller bypasses the validation path — the failure manifests somewhere downstream, not at the source.

The recipe:
1. Identify the implicit assumption (a value's range, a state, a precondition).
2. Add an assertion at the point where the assumption must hold.
3. Write the assertion in the positive: `assert(order.isValid, "Order must be validated before checkout")`.
4. In environments without a first-class assertion mechanism, a guard clause that throws a descriptive error serves the same purpose.

```ts
// Before
function finalizeOrder(order: Order): void {
  // assume payment has already been authorized
  fulfillment.ship(order);
  inventory.reserve(order);
}

// After
function finalizeOrder(order: Order): void {
  console.assert(
    order.paymentStatus === "authorized",
    `finalizeOrder called with unauthorized order ${order.id}`
  );
  fulfillment.ship(order);
  inventory.reserve(order);
}
```

IntelliJ's "Add assertion" quick fix appears when the tool detects a potential null dereference or type mismatch. In TypeScript, assertions are also encoded as precondition functions or `never`-typed exhaustiveness checks that the compiler enforces.

When not to apply: assertions are for invariants, not for user input validation. An assertion that fires on bad user input is a design error — user input should be validated with explicit error handling, not with a crash. The distinction is: assertions catch programmer mistakes; validation catches user mistakes.

@feynman

An assertion is like the safety net under a trapeze — you're not expecting the performer to fall, but if they do, the net stops the show before anyone gets hurt.

@card
id: rfc-ch06-c010
order: 10
title: Replace Control Flag with Break
teaser: A boolean variable used to control loop exit is an indirect stop signal — a break or return says the same thing directly, in one line, at the exact point it needs to be said.

@explanation

The signal: a loop with a `found` or `done` variable that gets set to `true` inside the loop body, with the loop condition checking `!found`. The flag introduces one extra level of indirection: to understand when the loop exits, you must read where the flag is set, not just read the loop condition.

The recipe:
1. Locate the statement that sets the flag to its exit value.
2. Replace it with `break` (if you only need to exit the loop) or `return` (if you can exit the function entirely).
3. Remove the flag variable from the loop condition.
4. Remove any remaining uses of the flag variable; if none remain, remove the declaration.

```ts
// Before
function findAdmin(users: User[]): User | undefined {
  let found = false;
  let admin: User | undefined;
  for (const user of users) {
    if (!found && user.role === "admin") {
      admin = user;
      found = true;
    }
  }
  return admin;
}

// After
function findAdmin(users: User[]): User | undefined {
  for (const user of users) {
    if (user.role === "admin") return user;
  }
  return undefined;
}
```

IntelliJ detects "boolean flag used to exit loop" patterns and offers to replace them automatically. VS Code does not have a dedicated inspection, but the manual replacement is a one-step inline and deletion.

When not to apply: if the control flag carries additional state beyond "exit" — for example, the loop behaves differently on subsequent iterations depending on whether the flag was set — a simple `break` does not capture the same semantics. In that case, consider splitting the loop or extracting a named method instead.

@feynman

A control flag mid-loop is like turning the lights off to signal everyone should leave a party — a direct announcement at the door is cleaner and leaves no ambiguity.

@card
id: rfc-ch06-c011
order: 11
title: Replace Conditional with Lookup Table
teaser: When a switch or long if/else chain maps discrete input values to fixed output values, a dictionary carries the same information in a form that needs no branching and is trivial to extend.

@explanation

The signal: a `switch` statement where every case assigns a constant — a label, a coefficient, a status string — with no logic in the branches. The switch is a table pretending to be code. Every new entry requires a new `case`; the compiler gains no type safety from the structure because the valid values are implied, not declared.

The recipe:
1. Collect the input-to-output pairs from the switch cases.
2. Define a typed map (dictionary, record) with those pairs as literal data.
3. Replace the switch with a map lookup, with an explicit fallback for missing keys.
4. Remove the switch.

```ts
// Before
function getPermissionLabel(permission: Permission): string {
  switch (permission) {
    case "read":    return "View Only";
    case "write":   return "Can Edit";
    case "admin":   return "Full Access";
    case "billing": return "Billing Manager";
    default:        return "Unknown";
  }
}

// After
const PERMISSION_LABELS: Record<Permission, string> = {
  read:    "View Only",
  write:   "Can Edit",
  admin:   "Full Access",
  billing: "Billing Manager",
};

function getPermissionLabel(permission: Permission): string {
  return PERMISSION_LABELS[permission] ?? "Unknown";
}
```

Neither IntelliJ nor VS Code automates this refactoring. In TypeScript, using `Record<KeyType, ValueType>` gives you compile-time exhaustiveness checking if `KeyType` is a union type — add a new member to the union and the compiler flags the missing map entry.

When not to apply: if the branches contain logic rather than constants, a lookup table only stores the data, not the computation — you'd need a map of functions, which is valid (and is a lightweight form of the Strategy pattern) but is different from a simple lookup. Also avoid when the set of valid keys is unbounded or dynamic.

> [!tip] A typed `Record<Permission, string>` in TypeScript will produce a compile error if you add a new permission to the union without adding its label to the map. That is strictly better than a switch with a default case.

@feynman

Replacing a switch with a lookup table is like swapping a long list of if-the-dish-is-X-charge-Y rules in a kitchen memo with a printed price list on the wall — same information, far easier to scan and update.

@card
id: rfc-ch06-c012
order: 12
title: Decompose Conditional in Tests
teaser: Tests with nested conditionals or looping assertions are harder to diagnose than failing tests need to be — the same decompose-and-name discipline that improves production code applies equally to your test suite.

@explanation

The signal: a test body that contains `if`/`else` branches selecting which assertion to run, or a loop that accumulates failures without identifying which case failed. When this test fails, the failure message says "expected X but got Y" with no indication of which branch or which iteration triggered it. Debugging requires re-running the test with print statements or a debugger.

The recipe:
1. If a test has an `if`/`else` choosing between assertions: split it into two separate test cases, one per branch.
2. If a test loops over cases: use a parameterized test (table-driven test) where each row is a named case with its own assertion message.
3. Extract complex precondition setup into a named helper that signals its intent: `createSuspendedAccount()` rather than five lines of `account.status = "suspended"` inline.
4. Name each test case after the scenario, not the method: `"suspended account returns zero balance"` not `"getBalance test 3"`.

```ts
// Before: conditional in test body
test("getDiscount handles customer types", () => {
  for (const [type, expected] of [["retail", 0], ["wholesale", 0.15]]) {
    expect(getDiscount(createOrder(type))).toBe(expected);
  }
});

// After: parameterized, named cases
test.each([
  ["retail customer gets no discount",    "retail",    0],
  ["wholesale customer gets 15% off",     "wholesale", 0.15],
  ["partner customer gets 25% off",       "partner",   0.25],
])("%s", (_, customerType, expectedDiscount) => {
  expect(getDiscount(createOrder(customerType))).toBe(expectedDiscount);
});
```

Jest and Vitest support `test.each`. JUnit 5 has `@ParameterizedTest`. Pytest uses `@pytest.mark.parametrize`. In all three, a failing case identifies itself by its label, not by its index in an array.

When not to apply: if the conditional in the test is asserting that a method behaves consistently across a large range of inputs, and the intent is to express an invariant rather than enumerate cases, a property-based test (fast-check, Hypothesis) is the right tool — splitting into individual test cases would produce hundreds of meaningless test names.

@feynman

A test with a conditional in its body is like a restaurant review that says "if you ordered the pasta it was good, otherwise it was fine" — it tells you something happened, but not enough to help you decide what to order.
