@chapter
id: apid-ch09-documentation-and-contracts
order: 9
title: Documentation and Contracts
summary: API docs are most useful when they're generated from the same machine-readable contract that drives validation, code generation, and tests — turning documentation from a stale afterthought into the central artifact of the API itself.

@card
id: apid-ch09-c001
order: 1
title: Spec as Source of Truth
teaser: When a single machine-readable contract generates your docs, your client SDKs, your mocks, and your validation rules, you stop maintaining four versions of the same fact and start maintaining one.

@explanation

The central insight behind modern API documentation tooling is that most API artifacts — reference docs, server stubs, client libraries, test fixtures, mock servers — are derivable from a sufficiently detailed contract. If you write the contract first and derive everything else from it, the artifacts stay in sync automatically.

What a good spec enables:

- **Documentation** generated on every commit, always reflecting the current contract rather than what someone last remembered to update.
- **Code generation** producing client libraries and server stubs in multiple languages from the same schema definitions.
- **Mock servers** spun up from examples in the spec, letting frontend developers work before the backend is built.
- **Contract tests** that verify the running service actually conforms to what the spec describes.
- **Request and response validation** enforced at runtime using the same schema that produced the docs.

The failure mode is treating the spec as an output — something you write after the implementation to satisfy a documentation requirement. When the spec is written retrospectively and inconsistently, none of the derived tooling works reliably, and the spec becomes stale the moment it's published.

The discipline required is small but non-negotiable: spec changes and implementation changes must happen together, reviewed together, and merged together.

> [!tip] If your spec and your implementation live in separate pull requests, they will diverge. Enforce co-location in code review: no spec change without a corresponding implementation change, and no implementation change without a spec update.

@feynman

A spec-as-source-of-truth is like a building's architectural blueprint — one document that contractors, electricians, and inspectors all work from, so they're never arguing about different versions of the same floor plan.

@card
id: apid-ch09-c002
order: 2
title: OpenAPI 3.1
teaser: OpenAPI 3.1 is the dominant machine-readable format for describing REST APIs — it's what most tooling reads, but what it can describe has real limits worth knowing before you commit to it.

@explanation

OpenAPI 3.1 (released 2021) is the specification format that the broadest ecosystem of tooling supports. It describes REST APIs as a YAML or JSON document covering endpoints, HTTP methods, request parameters, request and response bodies, authentication schemes, and links between operations.

A minimal endpoint definition:

```yaml
paths:
  /users/{id}:
    get:
      summary: Retrieve a user by ID
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: User found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '404':
          description: User not found
```

3.1 closed a long-standing compatibility gap with JSON Schema by aligning with the JSON Schema 2020-12 draft. This means schema keywords like `unevaluatedProperties`, `prefixItems`, and `const` now work as documented.

What OpenAPI cannot describe well:

- **Streaming responses** — server-sent events and long-polling have no first-class representation.
- **Bidirectional protocols** — WebSocket interactions require the AsyncAPI spec or informal prose.
- **Complex conditional behavior** — "if the `type` field is `admin`, then `permissions` is required" can be expressed with `if/then/else` but quickly becomes unreadable.
- **Operation ordering and side effects** — the spec describes individual operations, not workflows or state machines.

> [!info] OpenAPI 3.0.x (not 3.1) is still more widely supported by older tools. Check your toolchain's compatibility before upgrading — Swagger UI, Redoc, and code generators have varying 3.1 support.

@feynman

OpenAPI is a grammar for describing REST APIs — once you write down your API in that grammar, every tool that speaks OpenAPI can read it, the same way every compiler that speaks C can parse a `.c` file.

@card
id: apid-ch09-c003
order: 3
title: AsyncAPI 3.x
teaser: AsyncAPI is the event-driven equivalent of OpenAPI — it describes channels, messages, and bindings for Kafka, AMQP, WebSocket, and other async protocols that OpenAPI was never designed to cover.

@explanation

AsyncAPI 3.x (the 3.0 release landed in late 2023) describes APIs where communication is asynchronous and message-driven rather than request-response. A channel in AsyncAPI is roughly analogous to an endpoint in OpenAPI — it's the address where messages flow.

An AsyncAPI document for a Kafka topic might look like:

```yaml
asyncapi: 3.0.0
info:
  title: Order Events API
  version: 1.0.0
channels:
  order.placed:
    address: orders.placed
    messages:
      OrderPlaced:
        $ref: '#/components/messages/OrderPlaced'
operations:
  receiveOrderPlaced:
    action: receive
    channel:
      $ref: '#/channels/order.placed'
components:
  messages:
    OrderPlaced:
      payload:
        type: object
        properties:
          orderId:
            type: string
          total:
            type: number
```

AsyncAPI supports protocol-specific bindings — Kafka, AMQP, MQTT, WebSocket, HTTP — allowing the same schema layer to carry protocol-specific metadata like partition keys, consumer groups, or QoS levels.

The practical gap: tooling maturity lags far behind OpenAPI. Code generators, mock servers, and documentation renderers for AsyncAPI exist but cover fewer languages and have more rough edges. The spec itself is sound; the ecosystem around it is still catching up.

> [!warning] AsyncAPI 2.x and 3.x are not backward-compatible — the operations model changed significantly. If you're evaluating AsyncAPI today, start with 3.x and check that your chosen tools support it before committing.

@feynman

AsyncAPI is to event-driven APIs what OpenAPI is to REST — a shared language so that a Kafka consumer, a WebSocket client, and an MQTT device can all be described in one machine-readable document.

@card
id: apid-ch09-c004
order: 4
title: Contract Testing with Pact
teaser: Pact flips the ownership of integration testing — instead of the provider writing tests for every possible consumer, each consumer defines exactly what it needs, and the provider proves it delivers that.

@explanation

Consumer-driven contract testing with Pact works in two steps. First, a consumer (a frontend, a mobile app, another service) writes a test that defines the interactions it depends on — specific request shapes and the response fields it actually uses. Pact records these as a "pact file" (a JSON contract). Second, the provider runs that pact file against its real implementation to verify it can fulfill every interaction the consumer defined.

A pact interaction in JSON:

```json
{
  "description": "a request for user profile",
  "providerState": "user 42 exists",
  "request": {
    "method": "GET",
    "path": "/users/42"
  },
  "response": {
    "status": 200,
    "body": {
      "id": "42",
      "email": "user@example.com"
    }
  }
}
```

The **Pact Broker** is a hosted service (or self-hosted via `pact-broker` Docker image) that stores pact files, tracks which versions are verified, and exposes a `can-i-deploy` query — "can service A version X deploy to production given what all its consumers depend on?"

Where Pact scales: microservice ecosystems with stable consumer/provider ownership boundaries and teams that discipline themselves to update pacts when contracts change.

Where Pact breaks down: when consumers change frequently without updating their pacts, when provider states are complex to set up, or when a single provider has dozens of consumers with overlapping but slightly inconsistent expectations. In those cases, the broker becomes a bottleneck and the pact verification suite becomes an unreliable signal.

@feynman

Pact is like each customer writing down exactly what they ordered so the kitchen can verify it can make every dish on every ticket — instead of the kitchen guessing what every possible customer might want.

@card
id: apid-ch09-c005
order: 5
title: Spring Cloud Contract
teaser: Spring Cloud Contract is the JVM-native approach to contract testing — contracts are written in Groovy DSL or YAML and generate both a WireMock stub for consumers and a test suite for the provider.

@explanation

Spring Cloud Contract takes a different approach to consumer-driven contracts than Pact. Contracts are owned by the provider and written in the provider's repository using a Groovy DSL or YAML format. From these contracts, the framework generates two artifacts automatically:

- A **WireMock stub** JAR that consumers download and run locally to simulate the provider during their own tests.
- A **generated test class** (JUnit or Spock) that the provider runs against itself to verify it fulfills every contract it has published.

A contract in YAML:

```yaml
description: should return user by id
request:
  method: GET
  url: /users/42
response:
  status: 200
  headers:
    Content-Type: application/json
  body:
    id: "42"
    email: "user@example.com"
```

The appeal on the JVM: it integrates naturally into a Spring Boot application's build and test lifecycle. The provider publishes stubs to a Maven repository (local or remote), and consumers declare a test dependency on those stubs. No separate broker infrastructure is required for basic setups.

The tradeoff against Pact: because contracts live in the provider's repo, consumers have less visibility into what drove the contract definitions, and there is no equivalent of Pact's `can-i-deploy` query out of the box. Spring Cloud Contract fits tightly integrated teams working in the same Maven ecosystem; Pact fits polyglot environments with looser organizational coupling.

> [!info] Spring Cloud Contract works best when both provider and consumer teams are on the JVM and use a shared artifact repository like Nexus or Artifactory. For cross-language contracts, Pact's broker model handles polyglot environments more naturally.

@feynman

Spring Cloud Contract is like the provider publishing a reference manual with sample inputs and expected outputs — the consumer uses that manual to simulate the provider during testing, and the provider uses it to make sure its real behavior matches every example in the book.

@card
id: apid-ch09-c006
order: 6
title: Generated SDKs from Specs
teaser: Code-generating client SDKs from an OpenAPI or protobuf spec guarantees the client matches the contract — but generated code is rarely idiomatic, and the line between "nice to have" and "maintenance burden" depends on how often your spec changes.

@explanation

Three tools dominate this space:

**openapi-generator** (the open-source successor to swagger-codegen) produces client libraries and server stubs in over 50 languages from an OpenAPI document. It's feature-complete but produces verbose, non-idiomatic code in many targets. The generated code is committed to the repo and regenerated when the spec changes.

**openapi-typescript-codegen** (and its more actively maintained fork `hey-api/openapi-ts`) generates TypeScript clients from OpenAPI. The output is cleaner than openapi-generator for TypeScript consumers and integrates well with `fetch`-based stacks.

**Buf** handles protobuf and gRPC. It generates type-safe clients and servers from `.proto` files across multiple languages, manages a schema registry (the Buf Schema Registry), and enforces backwards-compatibility rules with `buf breaking` — flagging changes that would break existing consumers before they ship.

The tradeoff with SDK generation:

- **Benefit:** Consumer code never falls behind the contract; type errors at compile time rather than runtime surprises.
- **Cost:** Generated code is hard to read, hard to customize, and requires a disciplined regeneration workflow. Teams that generate SDKs and then edit the generated files by hand end up with code that can't be regenerated — and eventually diverges from the spec anyway.

The rule: commit to fully automated regeneration (no hand-edits to generated files) or don't generate. A half-automated process gives you the costs of both approaches and the benefits of neither.

@feynman

Generating an SDK from a spec is like having a translation tool that automatically re-translates a document whenever the original is updated — as long as you don't annotate the translation by hand, you always have an accurate copy.

@card
id: apid-ch09-c007
order: 7
title: Mock Servers from Specs
teaser: Running a mock server derived from your OpenAPI spec lets frontend developers and integration test suites work against a realistic API surface before — or instead of — a live backend.

@explanation

Three tools cover the main use cases:

**Prism** (by Stoplight) reads an OpenAPI document and spins up an HTTP server that validates requests against the spec and returns example responses defined in it. If the spec has no examples for a path, Prism generates a response by sampling from the schema. It also runs in validation-only mode, acting as a proxy that rejects requests or responses that violate the contract.

```bash
npx @stoplight/prism-cli mock ./openapi.yaml
# Listening on http://127.0.0.1:4010
```

**Mockoon** is a desktop and CLI tool for manually designing mock APIs with a GUI, exporting to a JSON config, and running it as a server. It imports from OpenAPI as a starting point but is primarily a hand-authored tool — better for exploratory prototyping than spec-driven automation.

**MSW (Mock Service Worker)** intercepts requests at the network layer in a browser or Node.js process using a service worker. It's not driven by an OpenAPI spec directly, but tools like `msw-auto-mock` generate MSW handlers from an OpenAPI document. The result is a mock that lives in the test suite rather than a separate server process — useful for component and integration tests in frontend codebases.

The shared failure mode: spec examples that are too generic to be useful. A mock server that returns `{"id": "string", "email": "string"}` for every request is technically contract-valid but useless for building UI against. Invest in realistic, domain-specific examples in the spec itself.

> [!tip] Use Prism in validation proxy mode in CI — route integration tests through it and fail the build when any request or response violates the spec. This catches spec drift without adding a separate contract test framework.

@feynman

A mock server from a spec is like a rehearsal stand-in — it knows the lines from the script (the spec) so the rest of the cast can run through scenes before the real actor shows up.

@card
id: apid-ch09-c008
order: 8
title: Doc-as-Code Workflow
teaser: Versioning your API spec in git and running CI checks against it treats the contract with the same rigor as application code — and catches breaking changes and spec errors before they reach consumers.

@explanation

A doc-as-code workflow means the spec file lives in the same repository as the implementation, is reviewed in pull requests alongside code changes, and is validated automatically on every commit.

Key CI checks to run against an OpenAPI spec:

- **Linting** with `spectral` (by Stoplight) — checks for missing descriptions, inconsistent naming conventions, missing examples, and custom rules your team defines. Spectral uses a YAML ruleset and produces line-level errors.
- **Breaking change detection** with `oasdiff` or `openapi-diff` — flags changes that would remove or incompatibly modify existing fields, endpoints, or response shapes. Runs against a diff of the current spec versus the last published version.
- **Schema validation** — confirms the spec document itself is valid OpenAPI (not just that it's valid YAML). `swagger-parser` or `openapi-schema-validator` handle this.

For protobuf APIs, `buf lint` and `buf breaking` cover the same ground — linting `.proto` files for style and detecting breaking changes in the schema.

The workflow for a spec change in a REST API team:

1. Spec file is updated in the same branch as the implementation.
2. CI runs Spectral lint, breaking change check, and schema validation.
3. Documentation preview is generated and linked in the PR.
4. Reviewer approves both the spec change and the implementation together.
5. On merge, documentation is automatically published.

The trap to avoid: writing spec validation that only checks syntax, not semantics. A spec that is valid OpenAPI but has no examples, no descriptions, and inconsistent naming conventions passes the validator and fails the developer who reads it.

@feynman

Doc-as-code is treating your API spec like source code — it lives in git, goes through code review, and gets tested in CI, so it can't drift quietly in a wiki while the real implementation moves on.

@card
id: apid-ch09-c009
order: 9
title: Interactive Documentation
teaser: Swagger UI, Redoc, and Stoplight Elements each render OpenAPI into a browsable reference — they differ in what they prioritize, and choosing the wrong one frustrates the audience you're actually writing docs for.

@explanation

**Swagger UI** is the original OpenAPI renderer, bundled with Swagger Editor. It's functional and widely recognized, but visually dense and better suited for API exploration than API learning. Every endpoint is an accordion panel; the "Try it out" button lets you send live requests against the API directly from the docs. Useful for internal developer portals where users already know the API and want to test calls quickly.

**Redoc** (by Redocly) produces a three-panel layout — navigation on the left, descriptions in the center, code samples on the right — with a cleaner reading experience than Swagger UI. It renders well on mobile, handles large specs without becoming slow, and produces documentation that reads like a product rather than a tool output. It doesn't include a built-in "try it" console by default, which is a deliberate choice: it focuses on reading, not experimentation.

**Stoplight Elements** is a component library approach — you embed it into your own documentation site and control the surrounding layout. It combines a Redoc-style reading experience with a try-it console and supports both REST and GraphQL specs. The tradeoff is a higher integration cost compared to dropping in a single HTML file.

The choice comes down to the audience:

- Internal teams who want quick request testing: Swagger UI.
- Public API docs with a polished reading experience: Redoc.
- Teams building a full developer portal with their own branding and navigation: Stoplight Elements.

> [!info] Redoc's three-panel layout works well for large, reference-heavy specs. Swagger UI becomes harder to navigate as operation count grows past a few dozen endpoints.

@feynman

Swagger UI is the workshop bench where you test and tinker; Redoc is the polished reference manual you hand to a new developer — both render the same spec, but they're optimized for different moments in the learning curve.

@card
id: apid-ch09-c010
order: 10
title: Examples in the Spec
teaser: Embedding concrete request and response examples in your OpenAPI document does more work than descriptions alone — those examples feed mock servers, documentation renderers, and test assertions simultaneously.

@explanation

OpenAPI supports examples at both the media type level (`examples` object) and the individual field level (`example` on a schema property). The distinction matters:

```yaml
components:
  schemas:
    CreateUserRequest:
      type: object
      properties:
        email:
          type: string
          format: email
          example: "ada@example.com"
        role:
          type: string
          enum: [admin, viewer]
          example: "viewer"
      example:
        email: "ada@example.com"
        role: "viewer"
```

A schema-level `example` is what Prism and other mock servers return when they need a sample response. A property-level `example` is what Redoc and Swagger UI display inline in the schema reference.

For more complex cases — showing multiple scenarios, like a successful response and an error response for the same endpoint — the `examples` (plural) object on the media type allows multiple named examples:

```yaml
responses:
  '200':
    content:
      application/json:
        examples:
          adminUser:
            value:
              id: "1"
              role: "admin"
          viewerUser:
            value:
              id: "2"
              role: "viewer"
```

The practical discipline: write examples that represent real domain objects, not placeholder values. An example with `id: "string"` tells the reader nothing. An example with `id: "usr_01HXYZ"` communicates the ID format, the naming convention, and implicitly the prefix scheme — all without a single extra description sentence.

@feynman

Examples in a spec are like worked problems in a textbook — the definition of an integral tells you what it is, but the example with actual numbers shows you how to use it.

@card
id: apid-ch09-c011
order: 11
title: Schema Validation as Runtime Gate
teaser: Using your OpenAPI schema to validate requests and responses at runtime closes the gap between "the spec says this" and "the service actually does this" — but validation has a performance cost that compounds at scale.

@explanation

Runtime schema validation validates live request payloads against the schemas defined in the spec before handing them to business logic, and optionally validates response payloads before sending them to the client. This enforces the contract as a hard invariant rather than a soft documentation promise.

Three common tools:

**ajv** (Another JSON Schema Validator) is the fastest JSON Schema validator in the Node.js ecosystem. You compile a schema once and reuse the compiled validator function. Validation for a typical request body runs in microseconds. Used directly or via middleware libraries like `express-openapi-validator`.

**pydantic** (Python) validates data against Python type annotations and supports OpenAPI-compatible JSON Schema output. In a FastAPI application, pydantic validation on request models is automatic — the framework generates the OpenAPI schema from the same type definitions that perform runtime validation, achieving the spec-as-source-of-truth ideal in a single step.

**express-openapi-validator** (Node.js) reads an OpenAPI file and mounts middleware that validates incoming requests and optionally outgoing responses against it. It requires no manual schema compilation — the spec file is the configuration.

The cost and configuration decision:

- **Request validation** in production is almost always worth it — it rejects malformed inputs early and provides useful error messages.
- **Response validation** in production is expensive and rarely warranted; run it in staging or development instead. A 404 response that accidentally includes a field not in the spec will cause the service to reject its own response.

@feynman

Schema validation as a runtime gate is like a toll booth that checks every car's registration before letting it through — malformed requests never reach your business logic, because they fail the check at the entrance.

@card
id: apid-ch09-c012
order: 12
title: Living vs Dead Docs
teaser: Documentation dies when it decouples from the implementation — the signs are subtle at first and expensive later, and most of the fixes are process interventions, not technical ones.

@explanation

Dead documentation is a spec that was accurate when it was written and drifted since. The drift is rarely dramatic — a field gets renamed, an error code changes, a new required parameter appears — and by the time a consumer discovers the inconsistency, weeks of work may have been built on the wrong contract.

Signs that documentation has decoupled from reality:

- **The spec hasn't been updated in a release cycle** despite the API being actively developed.
- **Response examples in the spec don't match what the running service returns.** Running `curl` against the API and comparing to the spec reveals this immediately.
- **Spec files have merge conflicts that were resolved without updating both sides.** The implementation won; the spec was silently wrong.
- **No CI check validates the spec.** Nothing fails when someone changes a field in the implementation without updating the contract.
- **The team refers to "the code" and "the docs" as separate sources of truth.** If someone asks "which one is right?", the answer is already "neither."

Detection mechanisms:

- **Dredd** runs an OpenAPI spec against a live API server and verifies that every example in the spec produces a matching response. It's a blunt but effective reality check.
- **Schemathesis** goes further — it generates test cases from the spec using property-based testing and finds responses that contradict it, including edge cases the spec author didn't anticipate.

The root cause of documentation death is organizational, not technical: documentation is treated as someone's side responsibility rather than a required artifact of shipping. The fix is making spec updates a merge requirement, not a nice-to-have.

> [!warning] A spec that has never been validated against the running service is a hypothesis, not a contract. Run Dredd or Schemathesis against your staging environment at least once per release cycle to find out how much reality diverges from the document.

@feynman

Living documentation is a map that gets redrawn whenever the territory changes; dead documentation is a map of where the roads used to be — accurate once, actively misleading now.
