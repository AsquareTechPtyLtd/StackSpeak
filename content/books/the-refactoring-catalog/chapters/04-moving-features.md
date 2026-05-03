@chapter
id: rfc-ch04-moving-features
order: 4
title: Moving Features Between Objects
summary: Once methods are clean, the next refactorings move features between objects — putting behavior next to the data it uses, splitting overgrown classes, and managing the delegation paths that emerge.

@card
id: rfc-ch04-c001
order: 1
title: Behavior Follows Data
teaser: The guiding principle of this chapter is that a method should live in the class whose data it mostly uses — everything else in this chapter is an application of that rule.

@explanation

When you look at a method and notice it spends most of its time reaching into another object's fields, that method is in the wrong place. It belongs next to the data it needs.

This is the "behavior follows data" principle, and it shapes every refactoring in this chapter:

- **Move Method** applies it directly — you physically relocate a method to the class whose state it manipulates.
- **Move Field** applies it to data — when a field is more tightly coupled to a different class, move the field and update the accessors.
- **Extract Class** applies it to an overloaded class — when a class has grown two distinct data clusters, you split it so each cluster has its own class with its own behavior.
- **Hide Delegate** applies it defensively — when clients reach through one object to manipulate another, you let the owning class handle the delegation itself.

The opposing failure mode is the anemic domain model: classes that carry data but no behavior, with all the logic pushed into service objects or controllers that do nothing but manipulate foreign state. That arrangement is feature envy made structural — the service class exists solely to reach into the data class and do what the data class should be doing itself.

You don't have to resolve every case perfectly. The goal is directional: each move should reduce how often a method has to reach outside its own class to get work done.

> [!info] Feature envy is the symptom; a misplaced method is the diagnosis; Move Method is the prescription. The other refactorings in this chapter handle the structural cases where a single move is not enough.

@feynman

Behavior follows data the same way a kitchen belongs next to a pantry — it makes no sense to cook in one room when all the ingredients are stored in another.

@card
id: rfc-ch04-c002
order: 2
title: Move Method
teaser: When a method uses more data from a different class than from its own, move the method to the class it most depends on.

@explanation

The signal for Move Method is feature envy: you open a method and see it making three or four calls into another object's fields or methods while barely touching `this`. The method has already voted with its feet — it belongs in the other class.

**Mechanical recipe:**

1. Identify the target class — usually the one the method references most. If it's ambiguous, ask which class would make the method's name make the most sense.
2. Define the equivalent method on the target class. Copy the body over; replace references to the source object with parameters or direct field access as appropriate.
3. Decide how the source class will call the new method: delegate to it, accept a reference, or remove the call entirely if it was only needed in certain paths.
4. Replace the original method body with a delegation call to the target, then verify all tests pass.
5. Once callers are updated, delete the original method.

Be honest about when to stop: if the source class still uses the method's logic heavily — even if the method also reaches into the target — the move just relocates the envy without fixing it. That's a sign to Extract Class instead.

```ts
// Before — ShippingCalculator reaches deep into Order
class ShippingCalculator {
  computeCost(order: Order): number {
    const weight = order.items.reduce((sum, item) => sum + item.weight, 0);
    const zone = order.destination.shippingZone;
    return weight * ZONE_RATES[zone];
  }
}

// After — the method lives with the data it uses
class Order {
  computeShippingCost(): number {
    const weight = this.items.reduce((sum, item) => sum + item.weight, 0);
    const zone = this.destination.shippingZone;
    return weight * ZONE_RATES[zone];
  }
}
```

> [!warning] Move Method is wrong when the original class still uses the method's data as heavily as the target does. Moving it just relocates the feature envy — recognize that as a signal to Extract Class instead.

@feynman

Moving a method to the class whose data it uses is like reassigning a project manager to the team they spend all day talking to — the work stays the same, but the communication overhead drops to zero.

@card
id: rfc-ch04-c003
order: 3
title: Move Field
teaser: When a field is queried or set more often by a different class than by its own, move the field to where it actually lives.

@explanation

A field that is constantly accessed from another class is a structural smell. It means the owning class is acting as a data bucket for state that really belongs to a neighbor. Move Field fixes the address.

**Mechanical recipe:**

1. Find all read and write sites for the field across the codebase.
2. Create the field on the target class, with a matching accessor.
3. Update the source class to delegate reads and writes through the target's accessor rather than holding the value itself.
4. Verify all tests pass with the delegating version.
5. Remove the source field and any now-redundant delegating accessors once all callers have been updated.

The tricky case is shared state: if two classes both have legitimate ownership of the field (reading and writing it roughly equally), that's a sign to Extract Class to create an explicit shared concept rather than picking an arbitrary winner.

```ts
// Before — Order holds discountRate but Pricing always reads it
class Order {
  discountRate: number;
  // ...
}
class Pricing {
  apply(order: Order): number {
    return order.totalBeforeDiscount * (1 - order.discountRate);
  }
}

// After — discountRate moves to Pricing where it is used
class Pricing {
  discountRate: number;
  apply(order: Order): number {
    return order.totalBeforeDiscount * (1 - this.discountRate);
  }
}
```

> [!tip] If moving the field makes you realize the source class no longer has much state left, consider whether the source class itself should be inlined into the target — that's the Inline Class refactoring.

@feynman

Moving a field to the class that uses it is like moving the spare key to the house of the person who always needs to borrow it — the key belongs where it gets used, not where it was originally stored.

@card
id: rfc-ch04-c004
order: 4
title: Extract Class
teaser: When a single class is doing two distinct jobs — managing its own identity and managing a separate cluster of behavior — split it into two classes, each with a clear purpose.

@explanation

The signal is a class with too many fields and methods where you can draw a mental line between two separate responsibilities. The two groups of fields and methods have little reason to talk to each other; they just happen to live in the same file.

**Mechanical recipe:**

1. Name the new class — the right name often makes it obvious you should have split earlier.
2. Create the new class and move the fields that belong to it. Update the original class to hold a reference to the new class.
3. Move the methods that operate on those fields, one at a time. After each move, run tests.
4. Review the interface between the two classes. Decide whether the original class should expose the new class directly or only delegate to it.
5. Tighten access modifiers — if the new class is an implementation detail, keep it package-private or unexposed.

```ts
// Before — Order mixes order identity with physical shipping data
class Order {
  id: string;
  customerEmail: string;
  shippingStreet: string;
  shippingCity: string;
  shippingPostalCode: string;
  shippingCountry: string;
  formattedAddress(): string { ... }
  validateAddress(): boolean { ... }
}

// After — address concerns are extracted
class ShippingAddress {
  street: string;
  city: string;
  postalCode: string;
  country: string;
  formatted(): string { ... }
  isValid(): boolean { ... }
}

class Order {
  id: string;
  customerEmail: string;
  shippingAddress: ShippingAddress;
}
```

> [!info] Naming the new class before you start is the most important step. If you cannot name it clearly, you may not have found the right split yet — the right cut usually becomes obvious once you identify the two responsibilities.

@feynman

Extracting a class from an overloaded one is like splitting a general store into a grocery and a hardware shop — the same inventory existed before, but now each shop knows exactly what it sells.

@card
id: rfc-ch04-c005
order: 5
title: Inline Class
teaser: When a class no longer carries enough responsibility to justify its existence, fold it back into the class that uses it.

@explanation

Inline Class is Extract Class in reverse. A class that started as a useful abstraction can become a hollow wrapper after features migrate away — it holds one or two fields and delegates everything. At that point it adds navigational overhead without adding clarity.

**Mechanical recipe:**

1. Identify all callers of the class to be inlined. If there are many diverse callers, inlining may increase coupling — consider whether the class is actually serving a boundary that should be kept.
2. Move all the fields and methods of the thin class into the absorbing class, one at a time.
3. Update callers to use the absorbing class directly rather than going through the indirection.
4. Run tests after each move.
5. Delete the now-empty class.

```ts
// Before — PhoneFormatter exists just to hold one method
class PhoneFormatter {
  format(number: string): string {
    return number.replace(/(\d{3})(\d{3})(\d{4})/, '($1) $2-$3');
  }
}

class Customer {
  private formatter = new PhoneFormatter();
  displayPhone(): string {
    return this.formatter.format(this.rawPhone);
  }
}

// After — format logic lives directly in Customer
class Customer {
  displayPhone(): string {
    return this.rawPhone.replace(/(\d{3})(\d{3})(\d{4})/, '($1) $2-$3');
  }
}
```

> [!warning] Do not inline a class just because it is small. Size is not the criterion — ask whether the class represents a concept worth naming. A small class with a strong name and a clear contract is fine; a small class that is just a renamed method is not.

@feynman

Inlining a class that no longer carries its weight is like removing an intermediary from a supply chain once they stop adding value — the product still moves, but there is one fewer hand in between.

@card
id: rfc-ch04-c006
order: 6
title: Hide Delegate
teaser: When clients navigate a chain of objects to reach what they need, give the first object in the chain a method that does the navigation internally.

@explanation

Law of Demeter violations look like this: `order.getCustomer().getAddress().getCity()`. Every `.` after the first couples the caller to the internal structure of a chain of objects. When `Customer` restructures how it stores addresses, every caller that navigated the chain has to change.

**Mechanical recipe:**

1. Identify the delegation chain that clients are navigating.
2. For each method the client calls on the end of the chain, add a delegating method to the first object that calls through internally.
3. Update clients to call the new method on the first object rather than navigating the chain.
4. Run tests.
5. Consider whether the intermediate class in the chain is still needed by external callers. If not, hide or remove its accessor.

```ts
// Before — callers reach through Order into Customer into Address
class OrderSummary {
  cityLabel(order: Order): string {
    return order.customer.address.city;
  }
}

// After — Order exposes what callers need directly
class Order {
  shippingCity(): string {
    return this.customer.address.city;
  }
}

class OrderSummary {
  cityLabel(order: Order): string {
    return order.shippingCity();
  }
}
```

> [!tip] Hide Delegate is most valuable at module or layer boundaries, where you want to decouple callers from internal structure. Within a single tightly coupled subsystem, the extra forwarding methods can be more noise than signal — apply judgment.

@feynman

Hide Delegate is like asking a hotel concierge to arrange your restaurant reservation instead of calling the restaurant yourself — you don't need to know which restaurant the concierge calls or what their booking system looks like.

@card
id: rfc-ch04-c007
order: 7
title: Remove Middle Man
teaser: When a class spends most of its time forwarding calls to a delegate, remove the indirection and let clients call the delegate directly.

@explanation

Hide Delegate and Remove Middle Man are inverses. Every time you add a delegating method to hide an internal object, you take on the maintenance cost of keeping that method in sync with the delegate. Once a class is mostly made of forwarding methods, the "encapsulation" it provides is just noise — callers are better served by accessing the delegate directly.

**Mechanical recipe:**

1. Create an accessor method on the middle class that exposes the delegate directly.
2. For each client that currently calls a forwarding method, update the call to navigate through the accessor and call the delegate directly.
3. After updating all clients for a given forwarding method, delete that forwarding method.
4. Repeat for each forwarding method until none remain.
5. Evaluate whether the accessor itself (or the middle class) still serves a purpose.

```ts
// Before — Order has accumulated forwarding methods for Customer
class Order {
  customerName(): string { return this.customer.name; }
  customerEmail(): string { return this.customer.email; }
  customerTier(): string { return this.customer.loyaltyTier; }
}

// After — expose the Customer and let callers use it directly
class Order {
  get customer(): Customer { return this._customer; }
}

// Callers now: order.customer.name, order.customer.email, etc.
```

> [!info] The right balance between Hide Delegate and Remove Middle Man shifts over time. A class that wraps one concept in a stable API is worth keeping; a class that just passes calls through to an unstable internal object should be removed.

@feynman

Removing the middle man is like canceling a subscription to a news aggregator once you realize you only read articles from one source — cut out the step and go directly.

@card
id: rfc-ch04-c008
order: 8
title: Introduce Foreign Method
teaser: When you need behavior on a class you cannot modify, add a standalone function or static helper that takes an instance of that class as its first argument.

@explanation

Sometimes the class that should own a method is a third-party type, a framework class, or a generated type you have no control over. You cannot add the method directly. Introduce Foreign Method is the minimal workaround: write the method as a free function (or a static helper on the consuming class) that takes an instance of the foreign class as its first argument.

**Mechanical recipe:**

1. Write the method in the consuming class as a private static method (or a module-level function in Python/TypeScript). Pass an instance of the foreign class as the first parameter.
2. Add a comment noting that this is a foreign method and belongs on the target class if it were ever made modifiable.
3. Call it wherever the operation is needed, passing the foreign instance explicitly.
4. If you need this operation in more than two or three places, consider Introduce Local Extension instead.

```ts
// Date is a built-in; you cannot add methods to it.
// Before — date arithmetic scattered in callers
function processDueDate(invoice: Invoice): void {
  const due = new Date(invoice.issuedAt);
  due.setDate(due.getDate() + invoice.netDays);
  invoice.dueAt = due;
}

// After — extracted as a foreign method with an explanatory name
// Foreign method: belongs on Date if Date were extensible
function addDays(date: Date, days: number): Date {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
}

function processDueDate(invoice: Invoice): void {
  invoice.dueAt = addDays(invoice.issuedAt, invoice.netDays);
}
```

> [!warning] Introduce Foreign Method is a stopgap. If you find yourself writing many foreign methods for the same class, switch to Introduce Local Extension — a subclass or wrapper that adds those methods in one coherent place.

@feynman

A foreign method is like writing a sticky note of instructions for a tool you cannot modify — it works, but it belongs on the tool itself and you're only keeping it nearby until a better solution appears.

@card
id: rfc-ch04-c009
order: 9
title: Introduce Local Extension
teaser: When you need multiple methods on a class you cannot modify, create a subclass or wrapper that adds those methods and use it consistently throughout your codebase.

@explanation

Where Introduce Foreign Method adds a single operation as a standalone helper, Introduce Local Extension is appropriate when you need several operations on a type you do not own. Rather than accumulating scattered foreign methods, you create a coherent extension point: either a subclass (if the type is non-final) or a wrapper class (if subclassing is blocked or unsuitable).

**Mechanical recipe:**

1. Choose between subclass and wrapper. Use a subclass if it is straightforward to construct from an existing instance and the type is not final/sealed. Use a wrapper otherwise.
2. Create the extension class. For a subclass, add a constructor that delegates to the parent. For a wrapper, hold a reference to the wrapped instance and delegate all original methods.
3. Add the new methods to the extension class.
4. Update construction sites in the consuming code to produce the extension class instead of the original type.
5. Update type annotations and parameters where the extension features are needed — you may not need to update every site, only those that use the new methods.

```ts
// MoneyAmount is a third-party value type with no business logic
class RichMoneyAmount extends MoneyAmount {
  constructor(base: MoneyAmount) {
    super(base.amount, base.currency);
  }

  applyDiscount(rate: number): RichMoneyAmount {
    return new RichMoneyAmount(
      new MoneyAmount(this.amount * (1 - rate), this.currency)
    );
  }

  addTax(rate: number): RichMoneyAmount {
    return new RichMoneyAmount(
      new MoneyAmount(this.amount * (1 + rate), this.currency)
    );
  }
}

const lineTotal = new RichMoneyAmount(invoice.subtotal)
  .applyDiscount(0.1)
  .addTax(0.08);
```

> [!tip] Prefer the wrapper form when the original type might change its constructor signature, or when you want to present a narrower interface to callers — the wrapper lets you expose only what they need.

@feynman

A local extension is like attaching a custom adapter to a standard power strip — you keep using the strip as-is, but your new adapter gives you the extra socket you needed without rewiring the original.

@card
id: rfc-ch04-c010
order: 10
title: Encapsulate Field
teaser: When a class exposes a mutable field directly, hide it behind accessors so the class controls how its data is read and modified.

@explanation

A public field is a hole in encapsulation. Any caller can write any value at any time with no validation, no notification, no side effects. The class cannot defend its own invariants. Encapsulate Field is the refactoring that closes the hole.

**Mechanical recipe:**

1. Make the field private (or the narrowest access level that compiles).
2. Add a getter method. Name it after the concept, not after the mechanical accessor convention if you can avoid it.
3. Add a setter method. Apply any validation logic the field needs.
4. Update all read and write sites throughout the codebase to use the accessor rather than the field directly. Compile after each change.
5. Review the setter: in many cases, once you have control of writes, you realize the setter should be removed entirely and the field set only through a meaningful business method like `applyDiscount()` or `confirmShipment()`.

```ts
// Before — status can be set to anything by anyone
class Order {
  status: string;
}
order.status = "SHIPPED"; // no validation, no side effects

// After — Order controls transitions through its own interface
class Order {
  private _status: OrderStatus = OrderStatus.Pending;

  get status(): OrderStatus { return this._status; }

  confirmShipment(trackingId: string): void {
    if (this._status !== OrderStatus.Processing) {
      throw new Error("Can only ship a processing order");
    }
    this._status = OrderStatus.Shipped;
    this.trackingId = trackingId;
  }
}
```

> [!info] The real value of Encapsulate Field is not the getter and setter themselves — it is the opportunity to replace free-form assignment with meaningful business methods that enforce valid state transitions.

@feynman

Encapsulating a field is like replacing an unlocked filing cabinet with a front-desk clerk — the information is still accessible, but now there is a person who checks what you are doing before handing anything over.

@card
id: rfc-ch04-c011
order: 11
title: Self-Encapsulate Field
teaser: Even inside a class, access your own fields through accessor methods so that subclasses and later changes have a single place to intercept reads and writes.

@explanation

Self-Encapsulate Field goes one step further than Encapsulate Field: you use the accessor methods even from within the class itself, not just from outside callers. Direct field access inside a class bypasses the accessor logic and makes it harder to override behavior in subclasses.

**Mechanical recipe:**

1. Add private getter and setter methods for the field (as in Encapsulate Field).
2. Search for all direct accesses to the field within the class body, including constructors, methods, and property initializers.
3. Replace each direct access with the corresponding getter or setter call.
4. The constructor is a special case: decide whether the constructor should bypass the setter (to avoid running incomplete initialization logic) or use it (if the setter validation is safe to run during construction).
5. Run tests. The behavior should be identical — you have changed the access path, not the logic.

```ts
// Before — Order reads its own discount field directly
class Order {
  private discount: number = 0;

  totalAfterDiscount(): number {
    return this.subtotal * (1 - this.discount); // direct field access
  }
}

// After — reads go through the accessor; subclass can override
class Order {
  private _discount: number = 0;

  protected get discount(): number { return this._discount; }
  protected set discount(value: number) {
    if (value < 0 || value > 1) throw new Error("Invalid discount");
    this._discount = value;
  }

  totalAfterDiscount(): number {
    return this.subtotal * (1 - this.discount); // accessor call
  }
}
```

> [!tip] Self-encapsulation is most valuable in class hierarchies where you expect subclasses to override the lazy initialization or caching strategy of a field. In a sealed class with no planned subclasses, the indirection may not be worth the noise.

@feynman

Using your own accessors inside a class is like a chef following the restaurant's own recipes even when cooking for themselves — consistency means any change to the recipe propagates everywhere, including the chef's own plate.

@card
id: rfc-ch04-c012
order: 12
title: Replace Data Class with Data Behavior
teaser: When a class holds data but all its behavior lives in the classes that manipulate it, move that behavior back in — anemic domain models are feature envy made architectural.

@explanation

The anemic domain model is the structural form of feature envy. You have an `Invoice` class with a dozen fields and no methods, and a separate `InvoiceService` class with a dozen methods that do nothing but read and write `Invoice` fields. The service class is feature envy at scale — it exists solely because the `Invoice` class was kept deliberately thin.

This is the refactoring that closes the chapter's loop: you started with the principle that behavior should live next to the data it uses, and a data class is the failure state where that principle was abandoned entirely.

**Mechanical recipe:**

1. Identify all the service/utility methods that operate primarily on the data class's own fields. These are the displaced behaviors.
2. Pick the most cohesive cluster — the methods that touch the fewest other objects and rely most heavily on the data class's own state.
3. Move those methods onto the data class using Move Method. Remove the now-redundant parameters that were previously passed in as the data object.
4. Evaluate which fields can be made private now that behavior lives alongside them — apply Encapsulate Field where appropriate.
5. Repeat for each cluster of behavior until the service class either disappears or is left with only genuinely cross-cutting operations that involve multiple domain objects.

```ts
// Before — Invoice is a pure data carrier; all logic is elsewhere
class Invoice {
  lineItems: LineItem[];
  discountRate: number;
  taxRate: number;
  paidAt: Date | null;
}

class InvoiceService {
  subtotal(invoice: Invoice): number {
    return invoice.lineItems.reduce((s, item) => s + item.total, 0);
  }
  amountDue(invoice: Invoice): number {
    const sub = this.subtotal(invoice);
    return sub * (1 - invoice.discountRate) * (1 + invoice.taxRate);
  }
  isPaid(invoice: Invoice): boolean {
    return invoice.paidAt !== null;
  }
}

// After — Invoice knows how to compute its own state
class Invoice {
  private lineItems: LineItem[];
  private discountRate: number;
  private taxRate: number;
  private paidAt: Date | null;

  subtotal(): number {
    return this.lineItems.reduce((s, item) => s + item.total, 0);
  }
  amountDue(): number {
    return this.subtotal() * (1 - this.discountRate) * (1 + this.taxRate);
  }
  isPaid(): boolean {
    return this.paidAt !== null;
  }
}
```

> [!warning] Not every data class should absorb all the behavior that touches it. Methods involving multiple domain objects or infrastructure concerns (persistence, serialization, HTTP) belong in service layers. The criterion is: does this behavior depend only on this object's own state? If yes, it belongs here.

@feynman

A data class that gains its own behavior is like a recipe card that learns to cook — instead of waiting for someone else to read its instructions and act, it can prepare the dish itself.
