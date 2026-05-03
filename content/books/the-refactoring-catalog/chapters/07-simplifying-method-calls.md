@chapter
id: rfc-ch07-simplifying-method-calls
order: 7
title: Simplifying Method Calls
summary: Method signatures are the public face of every class — these refactorings tighten them, clarify intent, and keep call sites readable as the codebase evolves.

@card
id: rfc-ch07-c001
order: 1
title: Signatures as Contracts
teaser: Every public method is a contract between the author and every caller — and changing that contract later is expensive in proportion to how many callers exist.

@explanation

A method's name, parameter list, and return type together form a promise. The name says what the method does. The parameters say what it needs to do it. The return type says what it produces. When any part of that promise is wrong — an unclear name, a parameter that no longer matters, a return type that forces callers to guess — the cost is paid not once but at every call site, every code review, and every debugging session.

The refactorings in this chapter are all about maintaining the integrity of that promise as code evolves. They fall into a few categories:

- **Clarifying intent** — Rename Method, Replace Parameter with Explicit Methods
- **Reducing surface area** — Remove Parameter, Hide Method, Remove Setting Method
- **Improving call-site ergonomics** — Introduce Parameter Object, Preserve Whole Object, Replace Parameter with Method Call
- **Managing state and behavior** — Separate Query from Modifier, Replace Constructor with Factory Method
- **Error handling** — Replace Error Code with Exception

Signature churn is expensive at scale. An internal method with one caller can be changed in a minute. A public API method with hundreds of callers in a distributed codebase is a migration project. The habits in this chapter keep signatures clean early, which makes the hard cases rarer.

> [!tip] Apply signature refactorings incrementally. IntelliJ's Change Signature (`⌘F6`) and VS Code's Rename Symbol (`F2`) handle the mechanical propagation — your job is deciding what the right signature should be.

@feynman

Cleaning up a method signature is like correcting a mislabeled file cabinet drawer — the sooner you fix the label, the fewer people open the wrong drawer looking for the wrong thing.

@card
id: rfc-ch07-c002
order: 2
title: Rename Method
teaser: The most common signature change — a better name costs nothing to apply and pays back every time someone reads the call site.

@explanation

**Signal:** The method's name does not communicate what it does. You have to look at the implementation to understand the call site. Common patterns: names that describe implementation (`parseAndCheckUser`) rather than intent (`validateUser`), abbreviations that made sense when written but not in context, or names that have drifted from behavior as the method evolved.

**When not to apply:** Rename Method is risky when the symbol is reflected or serialized — the IDE rename misses string references. Method names used in configuration files, REST endpoint route strings, or dynamic dispatch via reflection will not be caught by an automated rename.

**Mechanical recipe:**

1. Choose a name that precisely describes what the method does for its caller.
2. Use IntelliJ's Rename (`Shift+F6`) or VS Code's Rename Symbol (`F2`) to propagate the change across all call sites.
3. Search the codebase for the old name as a string literal — reflection, route annotations, and serialization are not covered by IDE rename.
4. Run your tests.

```typescript
// Before
class UserService {
  chkAndGetUsr(id: string): User { ... }
}
const user = service.chkAndGetUsr(userId);

// After
class UserService {
  findUser(id: string): User { ... }
}
const user = service.findUser(userId);
```

@feynman

Renaming a method is like correcting the name on a business card — the person hasn't changed, but now people actually know who they're calling.

@card
id: rfc-ch07-c003
order: 3
title: Separate Query from Modifier
teaser: Command-Query Separation says a method either returns a value or changes state — a method that does both is deceptive and hard to use safely.

@explanation

**Signal:** A method has a return value but also triggers a side effect — it returns the account balance and charges a fee, or it returns the next item and removes it from a queue. The caller cannot call it speculatively to inspect a value without also changing state.

**Why it matters:** Code that reads like a query (`getBalance()`) should be safe to call multiple times, in tests, in logging, in audits. If it secretly mutates state, those call sites become landmines. The principle, attributed to Bertrand Meyer, is: asking a question should not change the answer.

**Mechanical recipe:**

1. Identify the return value and the side effect.
2. Create a new method that returns the value without the side effect. Name it as a query.
3. Modify the original method to return `void` and keep only the state change. Rename it as a command.
4. Update each call site: call the query when it needs the value, call the command when it needs the effect.
5. Run your tests.

```typescript
// Before — getNextItem() both returns and removes
class WorkQueue {
  getNextItem(): WorkItem { ... } // also removes from queue
}

// After — separated
class WorkQueue {
  peekNextItem(): WorkItem { ... }   // query: no mutation
  removeNextItem(): void { ... }     // command: no return value
}
```

> [!warning] Some data structures like stack.pop() intentionally combine peek and remove. Separating them there creates a race condition in concurrent code. Know your context before separating.

@feynman

Asking a librarian for a book recommendation should not check the book out of the library on your behalf — queries and commands are two separate conversations.

@card
id: rfc-ch07-c004
order: 4
title: Parameterize Method
teaser: When two or three methods do the same thing with different hard-coded values, collapse them into one method that takes the value as a parameter.

@explanation

**Signal:** You have a family of nearly identical methods: `applyTenPercentDiscount()`, `applyTwentyPercentDiscount()`, `applyFifteenPercentDiscount()`. The only difference between them is a literal value baked into each body. Each new discount rate requires a new method.

**When not to apply:** If the variations involve substantially different logic — not just different values — parameterization obscures the differences. A parameter that controls branching behavior is a different smell (see Replace Parameter with Explicit Methods).

**Mechanical recipe:**

1. Pick the most general version of the methods (or write a new one) and add a parameter for the varying value.
2. Update the body to use the parameter instead of the hard-coded literal.
3. Update all call sites that previously called the specialized versions.
4. Delete the now-redundant specialized methods.
5. Run your tests.

```typescript
// Before
class PricingService {
  applyTenPercentDiscount(order: Order): number { return order.total * 0.90; }
  applyTwentyPercentDiscount(order: Order): number { return order.total * 0.80; }
}

// After
class PricingService {
  applyDiscount(order: Order, rate: number): number { return order.total * (1 - rate); }
}
service.applyDiscount(order, 0.10);
service.applyDiscount(order, 0.20);
```

@feynman

Parameterizing a family of methods is like replacing three identical cake recipes that differ only in baking time with one recipe that takes baking time as an input.

@card
id: rfc-ch07-c005
order: 5
title: Replace Parameter with Explicit Methods
teaser: When a boolean or enum parameter is doing the work of a dispatch — controlling which of two entirely different behaviors runs — give each behavior its own method instead.

@explanation

**Signal:** A method has a flag parameter (`isAdmin`, `mode`, `type`) and the first thing the body does is branch on it. Every call site passes a literal `true` or `false` that has no meaning without opening the method definition. IntelliJ's "Introduce parameter object" inspection sometimes surfaces this; VS Code doesn't flag it, but you can spot it in any call like `createAccount(userId, true, false)`.

**When not to apply:** If the parameter comes from runtime data — a user-selected mode, a value from a database — you cannot replace it with explicit methods at the call site without adding a wrapper. In that case, keep the dispatch internal.

**Mechanical recipe:**

1. Create a new method for each significant value of the parameter (e.g., `activateAccount()` and `suspendAccount()`).
2. Copy the body of the original method's relevant branch into each new method.
3. Compile and test each new method independently.
4. Replace each call site that passes a literal flag with a call to the appropriate explicit method.
5. Once all call sites are migrated, delete the original method.

```typescript
// Before
class AccountService {
  setAccountStatus(account: Account, active: boolean): void {
    if (active) { account.status = 'active'; sendWelcomeEmail(account); }
    else { account.status = 'suspended'; sendSuspensionNotice(account); }
  }
}

// After
class AccountService {
  activateAccount(account: Account): void {
    account.status = 'active';
    sendWelcomeEmail(account);
  }
  suspendAccount(account: Account): void {
    account.status = 'suspended';
    sendSuspensionNotice(account);
  }
}
```

> [!info] A boolean parameter is almost always a sign that a method has two personalities. Name each personality and give it its own method.

@feynman

Replacing a flag parameter with explicit methods is like separating a restaurant's lunch and dinner menus — instead of one menu with a "time of day" field you have to fill in, you just pick the right menu.

@card
id: rfc-ch07-c006
order: 6
title: Preserve Whole Object
teaser: When you pull three fields out of an object just to pass them to a method, pass the object instead — it's less fragile, and the method gains access to any additional fields it might need later.

@explanation

**Signal:** A call site extracts multiple values from an object to pass them as separate arguments: `validateBilling(account.id, account.email, account.plan)`. If the method always uses these fields together, or if you find yourself adding another parameter from the same object whenever requirements change, the object itself is the right parameter.

**When not to apply:** If the method lives in a module that should not depend on the `Account` type — a shared utility, a lower-level service with no knowledge of domain objects — passing the whole object creates an undesirable dependency. Pass primitives in that case to preserve the module boundary.

**Mechanical recipe:**

1. Create a new version of the method that accepts the whole object.
2. Change the body to read the values from the object rather than from separate parameters.
3. Update each call site to pass the object.
4. Remove the now-unused individual parameters from the signature.
5. Run your tests. Use IntelliJ's Change Signature (`⌘F6`) to handle step 4 across all call sites.

```typescript
// Before
const isValid = billingService.validateBilling(
  account.id, account.email, account.billingPlan
);

// After
const isValid = billingService.validateBilling(account);
```

@feynman

Passing the whole object is like giving someone your business card instead of reading them your phone number, email, and title one at a time — the card carries everything, and they can look up what they need.

@card
id: rfc-ch07-c007
order: 7
title: Replace Parameter with Method Call
teaser: When the caller computes an argument by calling a method on the same receiver, let the callee make that call itself instead.

@explanation

**Signal:** A call site looks like this: `invoice.applyDiscount(account.getMembershipTier())`. The argument being passed is computed from the receiver (or from an object the receiver already has access to). The caller is doing work the method could do for itself, and every new call site has to repeat that computation.

**When not to apply:** If the computation has meaningful side effects, or if the caller legitimately passes different values in different contexts (not always the result of the same method), leave the parameter in place. The refactoring is only safe when the callee can deterministically reproduce the value.

**Mechanical recipe:**

1. Confirm the callee can access whatever is needed to compute the value itself — through a field, a collaborator, or a parameter it already has.
2. Move the computation into the method body.
3. Remove the parameter from the method signature. Use IntelliJ's Change Signature (`⌘F6`) or VS Code's Rename Symbol (`F2`) to update all call sites.
4. Run your tests.

```typescript
// Before
const tier = account.getMembershipTier();
invoice.applyDiscount(tier);

// After — Invoice holds a reference to Account
invoice.applyDiscount();
// Inside Invoice:
applyDiscount(): void {
  const tier = this.account.getMembershipTier();
  this.total *= discountForTier(tier);
}
```

@feynman

Letting the method compute its own inputs is like giving a chef a recipe and the pantry key instead of pre-measuring every ingredient before you hand them a bowl.

@card
id: rfc-ch07-c008
order: 8
title: Introduce Parameter Object
teaser: When three or more parameters always travel together, give the cluster a name — a dedicated class or record that carries the values and can grow behavior of its own.

@explanation

**Signal:** Multiple methods share the same long parameter list: `(startDate: Date, endDate: Date, region: string)`. This is the "data clump" smell — values that are always seen together should probably be an object. The tell is that when you need to add a fourth related value, you add it to every method signature simultaneously.

**When not to apply:** If the parameters are truly independent and used in different subsets by different methods, a parameter object would force callers to construct an object with irrelevant fields. Prefer this refactoring when the cluster is coherent and reusable.

**Mechanical recipe:**

1. Create a new class (or interface/type) to hold the group of parameters. Give it an intention-revealing name (`BillingPeriod`, `DateRange`, `SearchCriteria`).
2. Add the new parameter object to the method signature alongside the individual parameters.
3. Update the method body to read values from the object.
4. Update each call site to construct and pass the object.
5. Once all call sites are migrated, remove the individual parameters from the signature.

```typescript
// Before
function generateReport(
  startDate: Date, endDate: Date, accountId: string, region: string
): Report { ... }

// After
interface ReportCriteria {
  period: { start: Date; end: Date };
  accountId: string;
  region: string;
}
function generateReport(criteria: ReportCriteria): Report { ... }
```

> [!tip] Once a parameter object exists, look for behavior that naturally belongs on it — validation, date arithmetic, formatting. Parameter objects often grow into proper domain types.

@feynman

Introducing a parameter object is like replacing a handful of loose coins with a wallet — the coins don't change, but now they have a home and you can hand them all over at once.

@card
id: rfc-ch07-c009
order: 9
title: Remove Setting Method
teaser: If a field should only be set at construction, remove the setter — make the object immutable after it is built, and the compiler enforces that invariant for you.

@explanation

**Signal:** A class has a setter (`setAccountId`, `setPlan`) for a field that should never change after an object is created. The setter exists because the original author "left the door open," or because the object was built incrementally rather than all at once. Every caller that holds a reference to the object can now mutate state that was meant to be fixed.

**When not to apply:** If external frameworks (ORMs, serialization libraries, dependency injection containers) require a no-arg constructor and public setters for their reflective mechanics, removing setters breaks those integrations. In that case, consider making the setter package-private or protected rather than fully removing it.

**Mechanical recipe:**

1. Find all call sites of the setter. Confirm every call sets the field exactly once, always before the object is used.
2. Move the value into the constructor as a required parameter.
3. Initialize the field in the constructor and mark it `readonly` (TypeScript) or `final` (Java).
4. Delete the setter.
5. Update call sites to pass the value at construction time.

```typescript
// Before
class Account {
  id: string;
  setId(id: string): void { this.id = id; }
}
const acct = new Account();
acct.setId('acct-123');

// After
class Account {
  readonly id: string;
  constructor(id: string) { this.id = id; }
}
const acct = new Account('acct-123');
```

@feynman

Removing a setter after construction is like sealing a time capsule — once the lid is welded shut, nobody can sneak anything in or out, and that guarantee is what makes it trustworthy.

@card
id: rfc-ch07-c010
order: 10
title: Hide Method
teaser: When a public method is only ever called from within its own class, make it private — every method on the public surface is a commitment you may have to maintain forever.

@explanation

**Signal:** A method is declared `public` but grep or "Find Usages" (`⌥F7` in IntelliJ) reveals it is only called from within the same class. It became public defensively ("someone might need it someday") or was promoted during a refactoring and never demoted. Every public method is surface area — callers outside the class can depend on it, and removing it later becomes a breaking change.

**When not to apply:** If the method is part of a testing seam — called from tests that can't otherwise observe internal behavior — discuss whether the test should test through the public API instead before making the method private.

**Mechanical recipe:**

1. Run "Find Usages" (`⌥F7` in IntelliJ) or "Find All References" (`Shift+F12` in VS Code) to confirm no external callers exist.
2. Change the method's visibility modifier from `public` to `private`.
3. Compile. Any missed external reference becomes a compiler error.
4. Run your tests.

```typescript
// Before — computeProration is public but only used internally
class BillingService {
  public computeProration(days: number, planRate: number): number { ... }
  public generateInvoice(account: Account): Invoice {
    const proration = this.computeProration(account.daysRemaining, account.plan.rate);
    ...
  }
}

// After
class BillingService {
  private computeProration(days: number, planRate: number): number { ... }
  public generateInvoice(account: Account): Invoice { ... }
}
```

@feynman

Making a method private is like changing a door from a public entrance to an internal one — it still works the same, but now you're not obligated to keep it accessible to strangers.

@card
id: rfc-ch07-c011
order: 11
title: Replace Constructor with Factory Method
teaser: When construction needs a meaningful name, a conditional path, or a return type that isn't the concrete class, a factory method gives you all three.

@explanation

**Signal:** A constructor is doing too much: it branches on a parameter to decide which subclass to build, its purpose isn't clear from `new Account(...)` alone, or you want to return a cached instance or a subtype without exposing that to callers. Constructors cannot be named, cannot return a subtype, and are hard to mock or extend cleanly.

**When not to apply:** For simple value objects with no conditional construction, a straightforward constructor is clearer than a factory method. Factories add indirection — only add them when the name or the flexibility they provide pays for that cost.

**Mechanical recipe:**

1. Create a `static` factory method (e.g., `Account.createFreeUser()`, `Account.createEnterpriseUser()`) that calls the constructor internally.
2. Give each factory method a name that expresses the construction intent clearly.
3. Move any conditional construction logic from the constructor into the factory methods.
4. Make the constructor `private` (or `protected`) so callers cannot bypass the factory.
5. Update all call sites from `new Account(...)` to `Account.createFreeUser(...)` (or the appropriate factory).

```typescript
// Before
const acct = new Account(userId, 'free', null);
const enterprise = new Account(userId, 'enterprise', orgId);

// After
class Account {
  private constructor(userId: string, plan: Plan, orgId: string | null) { ... }
  static createFreeUser(userId: string): Account {
    return new Account(userId, Plan.Free, null);
  }
  static createEnterpriseUser(userId: string, orgId: string): Account {
    return new Account(userId, Plan.Enterprise, orgId);
  }
}
```

@feynman

A factory method is like a specialist at a hardware store counter — instead of handing you raw materials and a manual, they ask what you're building and hand you exactly the right thing already assembled.

@card
id: rfc-ch07-c012
order: 12
title: Replace Error Code with Exception
teaser: When a method signals failure by returning a magic value (-1, null, false), replace it with an exception — error handling that is invisible at the call site is error handling that gets skipped.

@explanation

**Signal:** A method returns a sentinel value to indicate failure: `-1` for "not found," `null` for "invalid input," `0` for "operation failed." Callers are expected to check the return value before using it, but nothing in the language enforces that check. In practice, some callers forget, and silent failures propagate until they surface somewhere far from the cause.

**When not to apply:** In performance-critical loops where exception construction is expensive, a sentinel return value is sometimes the right tradeoff. Also, if the "failure" is a normal expected condition — a lookup that legitimately returns nothing — consider a typed optional (`Option<Account>`, `Account | null`) rather than an exception, which is semantically reserved for unexpected failures.

**Mechanical recipe:**

1. Identify the method and the sentinel value it returns to indicate failure.
2. Create or choose an appropriate exception type that describes the failure (`AccountNotFoundException`, `InvalidPlanError`).
3. Replace the sentinel `return` with a `throw` inside the method.
4. Update each call site: remove the sentinel check, and either let the exception propagate or catch it where recovery is meaningful.
5. Run your tests — tests that were checking for the sentinel return value must be updated to expect the exception.

```typescript
// Before
function findAccount(id: string): Account | null {
  const acct = db.lookup(id);
  return acct ?? null;
}
const acct = findAccount(id);
if (acct === null) { /* easily forgotten */ }

// After
function findAccount(id: string): Account {
  const acct = db.lookup(id);
  if (!acct) throw new AccountNotFoundException(id);
  return acct;
}
// Callers get a real Account or the stack unwinds — no silent path.
```

> [!warning] Don't use exceptions for control flow in normal code paths — throwing and catching an exception to check whether a user exists is semantically wrong and performs poorly. Reserve exceptions for conditions the method's contract does not expect to handle.

@feynman

Replacing a null return with an exception is like replacing a light that silently fails to turn on with a circuit breaker that trips loudly — the problem becomes impossible to ignore.
