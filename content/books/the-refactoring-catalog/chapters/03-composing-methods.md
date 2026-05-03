@chapter
id: rfc-ch03-composing-methods
order: 3
title: Composing Methods
summary: The most common refactorings reshape methods themselves — extracting, inlining, simplifying — so each function does one thing well and reads as a story rather than a riddle.

@card
id: rfc-ch03-c001
order: 1
title: Methods as Stories
teaser: A well-composed method reads top to bottom like a short story — each line advances the plot, and no reader has to stop and ask "what does this mean?"

@explanation

The longest method in any codebase is usually the one no one wants to touch. It grew incrementally: a conditional here, a temp variable there, a loop that was "only temporary." Six months later, it's 200 lines and nobody understands it in full without running it in their head.

The composing-methods catalog is the answer to that growth. The premise is simple: a method should do one thing, and every line of its body should operate at the same level of abstraction. When you call `calculateShippingCost()`, you shouldn't also have to read raw SQL, a loop over postal codes, and a fallback for null currency values all in the same frame.

The refactorings in this chapter all serve one goal: **make the method tell a story**. Extract the noisy details into well-named sub-methods. Inline the ones that have no story to tell. Replace temp variables with computed queries. Move code that belongs together so it can be extracted together.

None of these refactorings changes observable behavior. That's the contract: safer code, same output.

The order to reach for them:

1. Extract Method — the most frequently applied refactoring in the catalog.
2. Slide Statements — move related lines together before you can extract them.
3. Extract/Inline Variable — clarify (or remove) intermediate names.
4. Replace Temp with Query — make the method's dependencies visible.
5. Split Temporary Variable, Remove Assignments to Parameters — clean up mutation.
6. Replace Method with Method Object — for the long methods that still resist extraction.
7. Substitute Algorithm — when the right solution is wholesale replacement.

> [!tip] Before you extract anything, read the method once as prose. The places where you have to pause and re-read are exactly where extractions belong.

@feynman

Composing methods is like editing a paragraph of writing — you break long, tangled sentences into short ones, give each idea its own sentence, and cut the parts that say nothing new.

@card
id: rfc-ch03-c002
order: 2
title: Extract Method
teaser: Extract Method is the single most-used refactoring in the catalog — turn a fragment of code into a named method, and let the name do the explaining.

@explanation

**Signal:** You have a block of code you need to read carefully to understand what it does. It might be a loop body, a branch of a conditional, or a group of lines that clearly belong together. If you have to add a comment explaining a block, that's a strong signal the block should be its own method.

**When not to apply:** If the extracted method would have only one call site and no name is obviously clearer than the code itself, leave it. Extraction adds indirection — only extract when the name pays for that cost.

**Mechanical recipe:**

1. Identify the fragment to extract and decide on a name that describes what it does, not how.
2. Copy the fragment into a new method. Give the method the parameters it needs (the variables the fragment reads that are declared outside it).
3. If the fragment modifies a local variable, return that value from the new method.
4. Replace the original fragment with a call to the new method.
5. Run your tests.

In IntelliJ (any JVM or JS language), select the fragment and press `⌘⌥M` (macOS) or `Ctrl+Alt+M` (Windows/Linux). In VS Code, select the fragment, open the lightbulb (`⌘.`), and choose "Extract to function." Both tools handle parameter detection automatically.

```typescript
// Before
function printOrder(order: Order) {
  console.log(`Order: ${order.id}`);
  let total = 0;
  for (const item of order.items) {
    total += item.price * item.quantity;
  }
  if (order.memberSince < twoYearsAgo()) {
    total *= 0.9;
  }
  console.log(`Total: ${total}`);
}

// After
function printOrder(order: Order) {
  console.log(`Order: ${order.id}`);
  console.log(`Total: ${calculateTotal(order)}`);
}

function calculateTotal(order: Order): number {
  let total = order.items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  return isLoyalCustomer(order) ? total * 0.9 : total;
}
```

@feynman

Extracting a method is like pulling a recipe step out of a rambling paragraph and giving it a heading — "Prepare the roux" — so the reader can skim the recipe structure without reading every instruction line.

@card
id: rfc-ch03-c003
order: 3
title: Slide Statements
teaser: Before you can extract a block of related code, the lines often need to be neighbors — slide statements together so they can be extracted as a coherent unit.

@explanation

**Signal:** You want to extract a method, but the code you need is scattered across the function body, interleaved with unrelated lines. Sliding statements is the preparatory move that makes extraction possible.

**When not to apply:** Do not slide a statement past another if the slide changes behavior — that is, if the statement you are moving reads or writes a variable that the intervening lines also read or write. A safe slide requires checking data dependencies.

**Mechanical recipe:**

1. Identify the statements that logically belong to the same extraction target.
2. For each statement that needs to move, check: does anything between its current position and its destination position read or write a variable this statement also touches? If yes, the slide is unsafe — stop.
3. Move each statement to be adjacent to the others.
4. Re-run your tests to confirm nothing changed.
5. Now extract the adjacent block as a method (Extract Method).

There is no dedicated IDE shortcut for sliding in most editors, but IntelliJ's "Move Statement Up/Down" (`⌘⇧↑/↓`) moves lines while respecting syntax boundaries.

```python
# Before — tax and discount logic is scattered
def process_order(order):
    print(f"Processing {order.id}")
    tax = order.subtotal * 0.08        # <-- tax calc
    print(f"Customer: {order.customer}")
    discount = get_discount(order)      # <-- discount calc
    notify_warehouse(order)
    total = order.subtotal + tax - discount  # <-- total calc
    return total

# After — related lines slid together, ready for extraction
def process_order(order):
    print(f"Processing {order.id}")
    print(f"Customer: {order.customer}")
    notify_warehouse(order)
    tax = order.subtotal * 0.08
    discount = get_discount(order)
    total = order.subtotal + tax - discount
    return total
```

> [!warning] Sliding past a line that reads or writes a shared variable silently changes behavior. Check data dependencies before every slide.

@feynman

Sliding statements is like gathering scattered ingredients onto the same corner of the counter before you start cooking — nothing is prepared yet, but now everything you need is within arm's reach.

@card
id: rfc-ch03-c004
order: 4
title: Extract Variable
teaser: When a complex expression is hard to read, extract it into a named variable — the name becomes inline documentation that future readers thank you for.

@explanation

**Signal:** You're looking at a conditional or arithmetic expression and have to re-read it twice to understand what it evaluates. The expression has no name — it's just a blob of logic.

**Also known as:** "Introduce Explaining Variable" in older catalogs.

**When not to apply:** If the variable is only used once and the expression is already readable, a name adds no value. Also skip if the expression spans a scope where a method (Replace Temp with Query) would serve better.

**Mechanical recipe:**

1. Make sure the expression is free of side effects.
2. Declare a new `const` (or `val` in Kotlin/Scala) with a name that captures the business intent of the expression.
3. Assign the expression to that variable.
4. Replace all occurrences of the expression with the variable.
5. Run your tests.

In IntelliJ, select the expression and press `⌘⌥V` (macOS) / `Ctrl+Alt+V` (Windows/Linux) to extract to a variable. VS Code: select the expression, lightbulb (`⌘.`), "Extract to constant."

```typescript
// Before
if (order.items.length > 0 && !order.cancelled && user.membershipTier === "gold") {
  applyGoldDiscount(order);
}

// After
const hasItems = order.items.length > 0;
const isActive = !order.cancelled;
const isGoldMember = user.membershipTier === "gold";

if (hasItems && isActive && isGoldMember) {
  applyGoldDiscount(order);
}
```

@feynman

Naming an intermediate expression is like labeling a wire in an electrical diagram — the wire was always there, but the label lets the next person read the schematic without tracing every connection by hand.

@card
id: rfc-ch03-c005
order: 5
title: Inline Variable
teaser: When a variable's name says nothing the expression doesn't already say, remove the variable and use the expression directly.

@explanation

**Signal:** You see `const result = someCall(); return result;` or `const isReady = true; if (isReady) {...}`. The variable name restates what the expression already communicates — it's noise, not signal.

**When not to apply:** Do not inline a variable that is used more than once, or one whose name genuinely explains something the expression does not. Also skip if inlining would make the expression appear inside a complex conditional where it would reduce readability.

**Mechanical recipe:**

1. Confirm the variable is assigned exactly once and is read in exactly one expression.
2. Check that the right-hand-side expression has no side effects.
3. Replace each use of the variable with its right-hand-side expression.
4. Delete the variable declaration.
5. Run your tests.

In IntelliJ, place the caret on the variable name and use "Inline Variable" (`⌘⌥N` / `Ctrl+Alt+N`). VS Code does not have a dedicated inline-variable action, but the rename and manual delete is quick.

```python
# Before
def is_eligible(user):
    is_adult = user.age >= 18
    return is_adult

# After
def is_eligible(user):
    return user.age >= 18
```

> [!info] Inline Variable and Extract Variable are inverses. If you over-extract and the name adds no clarity, inline it back. Neither direction is permanently correct.

@feynman

Inlining a variable is like removing a sticky note that just repeats the label already printed on the box — once you notice it says the same thing twice, you peel it off.

@card
id: rfc-ch03-c006
order: 6
title: Replace Temp with Query
teaser: A local variable that holds a computed value can become a method — making the computation visible, reusable, and independently testable.

@explanation

**Signal:** You have a temp variable that is assigned once from an expression and then read in several places in the method. The assignment is buried inside the method body, invisible to callers and untestable in isolation.

**When not to apply:** If the computation is expensive and called in a tight loop, repeated calls may hurt performance (benchmark before committing). Also skip if the expression has side effects — query methods should be pure.

**Mechanical recipe:**

1. Extract the right-hand side of the assignment into its own method (use Extract Method, `⌘⌥M` in IntelliJ).
2. Give the method a name matching the business concept the variable represented.
3. Replace the temp variable's assignment with a direct call to the new method.
4. Replace all reads of the temp variable with calls to the method.
5. Delete the variable declaration, then run your tests.

```typescript
// Before
function getOrderSummary(order: Order): string {
  const basePrice = order.items.reduce((sum, i) => sum + i.price * i.quantity, 0);
  const tax = basePrice * 0.08;
  return `Subtotal: ${basePrice}, Tax: ${tax}, Total: ${basePrice + tax}`;
}

// After
function getOrderSummary(order: Order): string {
  return `Subtotal: ${basePrice(order)}, Tax: ${tax(order)}, Total: ${basePrice(order) + tax(order)}`;
}

function basePrice(order: Order): number {
  return order.items.reduce((sum, i) => sum + i.price * i.quantity, 0);
}

function tax(order: Order): number {
  return basePrice(order) * 0.08;
}
```

@feynman

Replacing a temp variable with a query is like converting a handwritten note on your desk into a function in a shared calculator — instead of hiding the formula in your scratch work, you make it available to anyone who needs it.

@card
id: rfc-ch03-c007
order: 7
title: Inline Method
teaser: When a method's body is as readable as its name — or when the method is called from exactly one place — inline it and remove the indirection.

@explanation

**Signal:** You look at a method call, jump to the implementation, and find the body is one or two lines that are completely self-explanatory. The method name added no clarity; the extra navigation was pure overhead. Another trigger: a delegation chain where several small methods just pass work along without adding meaning.

**When not to apply:** Do not inline a method that is called from multiple places and whose name genuinely aids readability at each call site. Also skip if the method is part of an interface, overriding a superclass, or used through dynamic dispatch — inlining is only safe when you control all call sites.

**Mechanical recipe:**

1. Identify all call sites of the method.
2. Replace each call site with the method's body, adjusting parameter names to match the calling scope.
3. Delete the method declaration.
4. Run your tests.

In IntelliJ, place the caret on the method name (definition or call) and press `⌘⌥N` / `Ctrl+Alt+N` ("Inline Method"). VS Code requires a manual replace — there is no automated inline-method refactoring for TypeScript at the time of writing.

```python
# Before
def is_over_minimum(order):
    return order.total >= 50

def can_apply_coupon(order):
    return is_over_minimum(order)

# After
def can_apply_coupon(order):
    return order.total >= 50
```

> [!warning] Inlining a recursive method or a method with multiple return paths requires care — the transform is not always mechanical. Test after every change.

@feynman

Inlining a method is like removing a road sign that just says "turn here" with an arrow pointing at a road you can already see — once the destination is obvious, the signpost is just clutter.

@card
id: rfc-ch03-c008
order: 8
title: Split Temporary Variable
teaser: A variable reused for two unrelated purposes is two variables pretending to be one — split it, and each assignment gains a name that actually describes its role.

@explanation

**Signal:** A temp variable is assigned more than once, but not because it accumulates a running total — it is simply reused for a different, unrelated value partway through the method. Reading the method, you cannot tell what the variable means at any given line without tracing all its assignments.

**When not to apply:** Variables that accumulate (a loop counter, a running sum, a string being built) are intentionally reused — do not split those. Split only when the reuse is for two logically distinct values.

**Mechanical recipe:**

1. Find the second (and any subsequent) assignment to the variable.
2. Rename the variable at the second assignment and all its subsequent reads to a new, descriptive name.
3. Declare the new variable with the most restrictive scope possible (`const`/`let`).
4. Remove the original variable from the scope of the second value if it no longer serves a purpose there.
5. Run your tests.

IntelliJ's "Rename" (`⇧F6`) scoped to a selection helps here. VS Code's "Rename Symbol" operates file-wide — use it carefully or rename manually within the function body.

```typescript
// Before
function computeGeometry(height: number, width: number) {
  let temp = 2 * (height + width);   // perimeter
  console.log(`Perimeter: ${temp}`);
  temp = height * width;             // area — same variable, different concept
  console.log(`Area: ${temp}`);
}

// After
function computeGeometry(height: number, width: number) {
  const perimeter = 2 * (height + width);
  console.log(`Perimeter: ${perimeter}`);
  const area = height * width;
  console.log(`Area: ${area}`);
}
```

@feynman

Splitting a reused variable is like realizing you've been using the same notebook for your grocery list and your meeting notes — once you give each a separate notebook, neither list confuses you anymore.

@card
id: rfc-ch03-c009
order: 9
title: Remove Assignments to Parameters
teaser: When you reassign a parameter inside a method, you make the function's inputs into moving parts — stop that, and callers can reason about your method without reading its body.

@explanation

**Signal:** Inside a method body, you see a line like `price = price * 0.9;` or `items = filterActive(items);` where `price` or `items` is a parameter. The parameter's value has been changed; anyone reading the call site cannot know what the function does to its inputs without reading the implementation.

**When not to apply:** In languages that pass objects by reference, mutating the object's *properties* through the parameter is a separate concern (and is sometimes intentional). This refactoring targets reassigning the *parameter binding* itself, not mutation of the referred object.

**Mechanical recipe:**

1. Find all assignments to the parameter within the method body.
2. Introduce a new local variable initialized to the parameter's value.
3. Replace all uses of the parameter after the first reassignment with the new variable.
4. Replace all assignments that targeted the parameter with assignments to the new variable.
5. Run your tests.

No dedicated IDE shortcut exists for this transform — it is typically done manually, then optionally followed by IntelliJ's "Extract Variable" (`⌘⌥V`) for the initial copy if you prefer.

```python
# Before
def apply_discount(price, is_member):
    if is_member:
        price = price * 0.9   # parameter reassigned
    return price

# After
def apply_discount(price, is_member):
    discounted_price = price
    if is_member:
        discounted_price = price * 0.9
    return discounted_price
```

> [!tip] Declaring parameters as `const` (TypeScript) or using immutable function signatures wherever the language supports it turns this from a discipline into a compiler-enforced rule.

@feynman

Treating a parameter as an input-only value is like a chef reading a recipe ingredient list — the recipe tells you what you started with, and any transformation produces a new dish rather than erasing what the original ingredient was.

@card
id: rfc-ch03-c010
order: 10
title: Replace Method with Method Object
teaser: When a long method has so many local variables that Extract Method keeps failing, convert the method into a class — the locals become fields, and extraction becomes straightforward.

@explanation

**Signal:** You have a method that is long, complex, and has many local variables that are entangled with each other. Every time you try to apply Extract Method, you find that the fragment needs five local variables as parameters, or that one extracted method needs to share state with another. The method resists decomposition as a function.

**When not to apply:** This is a heavyweight refactoring — it introduces a new class. Don't reach for it until you've confirmed that Extract Method genuinely fails due to intertwined local variables, not because the method could simply be reorganized.

**Mechanical recipe:**

1. Create a new class named after the method (e.g., `OrderPricingCalculator`).
2. Give the new class a `const` field for each local variable and parameter of the original method.
3. Add a constructor that accepts all parameters and assigns them to the fields.
4. Copy the method's body into a method on the new class (usually named `compute()` or `execute()`), replacing all local variable references with field references.
5. Replace the original method's body with: create an instance of the new class, call the compute method, return the result.
6. Now apply Extract Method freely on the new class's compute method — the fields are shared state, so parameter passing is no longer an obstacle.

In IntelliJ, "Replace Method with Method Object" is available under Refactor → Replace Method with Method Object (no default shortcut, but searchable via `⇧⌘A`).

```java
// Before (Java — OO context fits Method Object well)
double price(int quantity, int itemPrice) {
    double basePrice = quantity * itemPrice;
    double quantityDiscount = Math.max(0, quantity - 500) * itemPrice * 0.05;
    double shipping = Math.min(basePrice * 0.1, 100.0);
    return basePrice - quantityDiscount + shipping;
}

// After — each sub-calculation can now be extracted as a method on the class
class PriceCalculator {
    private final int quantity;
    private final int itemPrice;

    PriceCalculator(int quantity, int itemPrice) {
        this.quantity = quantity;
        this.itemPrice = itemPrice;
    }

    double compute() {
        return basePrice() - quantityDiscount() + shipping();
    }

    private double basePrice() { return quantity * itemPrice; }
    private double quantityDiscount() { return Math.max(0, quantity - 500) * itemPrice * 0.05; }
    private double shipping() { return Math.min(basePrice() * 0.1, 100.0); }
}
```

@feynman

Replacing a method with a method object is like converting a complicated recipe scrawled on one page into a full recipe card with named sections — once the ingredients live in labeled bowls on the counter, each step can be described on its own line.

@card
id: rfc-ch03-c011
order: 11
title: Substitute Algorithm
teaser: When you know a cleaner algorithm exists, don't patch the old one — replace the entire method body at once and let the tests confirm the behavior is preserved.

@explanation

**Signal:** You understand a better, clearer way to implement a method, and the existing implementation is not worth incrementally reshaping — perhaps because it's an opaque loop where a library method or a declarative expression would be far more readable.

**When not to apply:** If the algorithm is complex and the difference is marginal, incremental extraction is safer. Substitute Algorithm requires a passing test suite to validate the swap — do not attempt it without tests. Also be cautious if the existing algorithm has subtle edge-case handling buried in it; make sure your replacement covers all the same cases.

**Mechanical recipe:**

1. Prepare the replacement algorithm — ideally in a separate branch or scratch environment.
2. Run your full test suite against the original to establish the baseline.
3. Replace the method body with the new algorithm, keeping the same signature.
4. Run the tests. If they fail, compare the outputs for each failing case against the original.
5. Iterate on the replacement until all tests pass, then delete the old implementation.

No IDE shortcut exists — this is a deliberate, whole-body replacement done by hand.

```python
# Before — manual loop checking membership
def contains_any(collection, targets):
    for item in collection:
        for target in targets:
            if item == target:
                return True
    return False

# After — cleaner algorithm using set intersection
def contains_any(collection, targets):
    return bool(set(collection) & set(targets))
```

> [!warning] Substitute Algorithm is one of the few refactorings where you can inadvertently change behavior — especially around ordering, duplicates, or null handling. Your tests are the only safety net.

@feynman

Substituting an algorithm is like tearing out a hand-drawn map and replacing it with a printed one — you are not adjusting the old map; you are discarding it entirely and trusting the new one is more accurate.

@card
id: rfc-ch03-c012
order: 12
title: Decompose Conditional
teaser: A complex `if/else` is a method waiting to be extracted — name the condition and name each branch, and the logic reads like a policy rather than an implementation.

@explanation

**Signal:** You have an `if` statement whose condition spans several sub-expressions, or whose branches contain more than a few lines of non-trivial logic. Reading it requires holding multiple facts in mind simultaneously.

**Note:** This card gives you the mechanics for the method-composition use of Decompose Conditional. The full treatment — including nested conditionals, switch exhaustiveness, and polymorphism-based replacement — belongs to the conditionals chapter.

**When not to apply:** If the condition is a single, readable boolean expression and the branches are one-liners, the extraction adds noise. Extract only when the decomposition produces names that carry genuine meaning.

**Mechanical recipe:**

1. Extract the condition into a method whose name describes what it tests (e.g., `isSummerPeakPeriod()`). Use Extract Method (`⌘⌥M` in IntelliJ, "Extract to function" in VS Code).
2. Extract the then-branch into a method named for what it does (e.g., `applySummerRate()`).
3. Extract the else-branch into a method named for its action (e.g., `applyStandardRate()`).
4. The original `if` body now reads as a three-word policy statement.
5. Run your tests.

```typescript
// Before
function charge(order: Order): number {
  if (order.date.month >= 6 && order.date.month <= 8 && order.totalKwh > 1000) {
    return order.totalKwh * 0.15 + (order.totalKwh - 1000) * 0.10;
  } else {
    return order.totalKwh * 0.10;
  }
}

// After
function charge(order: Order): number {
  return isSummerPeak(order) ? summerCharge(order) : standardCharge(order);
}

function isSummerPeak(order: Order): boolean {
  return order.date.month >= 6 && order.date.month <= 8 && order.totalKwh > 1000;
}

function summerCharge(order: Order): number {
  return order.totalKwh * 0.15 + (order.totalKwh - 1000) * 0.10;
}

function standardCharge(order: Order): number {
  return order.totalKwh * 0.10;
}
```

@feynman

Decomposing a conditional is like replacing a tangled legal clause with a plain-English policy heading — "Weekend surcharge applies if..." — where the heading tells you the rule and the supporting details only appear if you need them.
