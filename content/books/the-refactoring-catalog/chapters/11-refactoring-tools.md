@chapter
id: rfc-ch11-refactoring-tools
order: 11
title: Refactoring Tools
summary: The catalog is the theory; the tooling is what lets you apply it at the speed engineering work actually demands — and modern IDEs, codemod libraries, and language servers have made dozens of refactorings press-button-safe in static languages.

@card
id: rfc-ch11-c001
order: 1
title: Tools Encode the Catalog
teaser: Fluency with ten IDE refactorings outperforms memorizing fifty catalog entries — because automated refactorings are part of the practice, not a shortcut around it.

@explanation

The Refactoring catalog names and defines transformations. Tools implement them. When IntelliJ IDEA performs Extract Method, it resolves scopes, rewires call sites, and handles local variables that need to become parameters — in a single keystroke. When you do the same manually, each of those steps is a micro-opportunity for error.

This isn't about outsourcing judgment to the IDE. You still decide *when* to extract, *what* to name the result, and *why* the structure is better. The tool removes the mechanical risk from the execution.

Three practical consequences:

- **Tool-safe refactorings should be done freely.** Rename, Extract Method, Inline Variable — when the IDE guarantees all call sites change atomically, the cost of trying and undoing is negligible.
- **Manual refactorings need tests first.** Any transformation your IDE cannot automate safely requires a safety net of characterization tests before you touch the code.
- **Your tool choice shapes your refactoring vocabulary.** IntelliJ-on-Java exposes forty-plus catalog operations. A text editor exposes none. The gap is not academic — it changes how much refactoring actually happens.

Invest in learning your IDE's refactoring surface the same way you'd learn a new language's standard library. The catalog tells you what's possible; the tool determines what's practical.

> [!tip] Start with five: Extract Method, Inline, Rename, Change Signature, and Move. Master those bindings until they're muscle memory before broadening your repertoire.

@feynman

Knowing the catalog without your IDE's refactoring menu is like knowing every guitar chord shape but always playing with one hand.

@card
id: rfc-ch11-c002
order: 2
title: IntelliJ IDEA Refactorings
teaser: IntelliJ IDEA 2024+ is the most complete implementation of the refactoring catalog for Java and Kotlin — and knowing the exact shortcuts is the difference between using it and using it fluently.

@explanation

IntelliJ IDEA's refactoring menu covers the core catalog comprehensively. The actions you should have bound to memory on macOS:

- **Extract Method** — ⌘⌥M
- **Inline** — ⌘⌥N
- **Rename** — Shift+F6
- **Change Signature** — ⌘F6
- **Move** — F6
- **Pull Members Up**, **Push Members Down**, **Replace Inheritance with Delegation** — Refactor menu (no default keybinding; surface via `Refactor This`)

The `Refactor This` popup (⌃T on macOS) is the most useful single binding — it shows every refactoring applicable to the current selection so you don't need to memorize the full menu.

What makes IntelliJ's implementation trustworthy is its use of the full program model. Extract Method resolves whether a local variable should become a parameter, whether a field access needs to be captured, and whether the extracted method can be `static`. It handles cases where naive text substitution would produce code that doesn't compile.

The trade-off: IntelliJ's analysis is deep enough that it can be slow on very large projects during indexing. On a cold-start monorepo, some refactorings will be unavailable until indexing completes. Keep the project indexed by leaving IntelliJ running rather than restarting it frequently.

> [!info] Kotlin support in IntelliJ 2024+ is first-class — most refactorings work across Java and Kotlin files in mixed-language projects, including rename and move.

@feynman

Using IntelliJ's refactoring shortcuts is like using a chef's knife for prep work — you could use a paring knife for everything, but the right tool makes the job structurally safer and faster.

@card
id: rfc-ch11-c003
order: 3
title: VS Code Refactorings via Language Server
teaser: VS Code's refactoring support is real but narrower than IntelliJ — what you get depends entirely on the language server, and the gap for object-oriented refactorings is honest enough to plan around.

@explanation

VS Code delegates all language intelligence — including refactorings — to Language Server Protocol (LSP) implementations. The actions you can count on across most mature servers:

- **Rename** (F2) — renames a symbol and all its references across the workspace. This is the most reliable cross-editor refactoring.
- **Extract Method / Extract Variable** — available via the lightbulb (⌘.) or `Source Action...` command palette entry. Availability depends on the language server.
- **Source Actions** — a catch-all menu per language server that may include organize imports, extract interface, or generate accessors.

Where VS Code falls short compared to IntelliJ:

- **No Change Signature** for most languages. Changing a method's parameter list and having all call sites updated automatically requires IntelliJ or Rider.
- **No Pull Up / Push Down.** Inheritance hierarchy refactorings are not supported by most language servers.
- **Extract Method quality varies.** The TypeScript language server's Extract Method is solid. Pylance's is acceptable. Java in VS Code via Language Support for Java by Red Hat is functional but not as thorough as IntelliJ's.

For TypeScript and Python projects where the dominant refactoring needs are rename and extract, VS Code is entirely adequate. For Java or C# with heavy OO refactoring needs, VS Code is a real downgrade.

> [!warning] VS Code's rename refactoring only covers symbols the language server has indexed. In large TypeScript monorepos, ensure `tsconfig.json` project references are configured correctly or renames will miss files outside the active project.

@feynman

VS Code's refactoring support is like a well-stocked toolkit where the language server decided which tools to include — for most jobs it has everything, but the specialty items depend on who packed the bag.

@card
id: rfc-ch11-c004
order: 4
title: ReSharper and Rider for .NET
teaser: ReSharper and Rider bring IntelliJ-quality refactoring to the C# and .NET ecosystem — and for teams that live in that stack, the investment pays back immediately.

@explanation

ReSharper is JetBrains's Visual Studio extension; Rider is the standalone IDE built on the same engine. Both surface the same refactoring capabilities, which are the most comprehensive available for C# and the .NET stack.

High-value refactorings to know:

- **Extract Method** (⌃R, ⌃M on Windows) — same depth as IntelliJ's Java implementation.
- **Rename** (F2 in Rider, ⌃R, R in ReSharper) — works across `.cs`, `.razor`, `.aspx`, `.cshtml`, and XML configuration files.
- **Change Signature** — modifies a method's signature and updates all call sites. Adds optional parameters, reorders parameters, converts to return type.
- **Introduce Parameter Object** — groups related parameters into a new class, a refactoring VS Code doesn't offer.
- **Move to Another Type / Move to File** — moves a method or class with call-site updates.
- **Encapsulate Field** — converts a public field to a property with get/set accessors.

The practical difference between ReSharper and Rider: ReSharper runs inside Visual Studio and has historically had a performance cost on large solutions. Rider is a standalone IDE with a better performance profile on large codebases. As of 2024, most .NET teams doing heavy refactoring work prefer Rider.

> [!tip] ReSharper's "Inspect This" and solution-wide analysis complement the refactoring menu — run it on a legacy codebase to surface the highest-density code smell clusters before deciding where to start.

@feynman

ReSharper in a C# codebase is like having a structural engineer on your renovation crew — the tool knows the load-bearing walls before you start moving things.

@card
id: rfc-ch11-c005
order: 5
title: Xcode Refactorings for Swift
teaser: Xcode's built-in refactoring support covers the basics for Swift, but the depth gap compared to IntelliJ or Rider is real — and most Swift teams learn to work around it rather than through it.

@explanation

Xcode's refactoring actions are accessible via Editor > Refactor or by right-clicking a symbol. The operations available in Xcode 15+:

- **Rename** — renames a Swift symbol and its usages. Works across Swift files in the same project. Does not reliably handle Objective-C interop or dynamic dispatch.
- **Extract to Function** — extracts a selected code block. Works for simple cases; complex closures or captured variables often need manual cleanup after extraction.
- **Extract to Variable** — promotes an inline expression to a named `let` or `var`.
- **Extract to Method** (in ObjC context)
- **Generate Memberwise Initializer** — creates a struct's `init` from its stored properties.
- **Add Missing Cases** — fills in exhaustive `switch` cases for an enum.

What Xcode lacks: Change Signature, Pull Up / Push Down, Introduce Parameter Object, Move to Protocol — all the OO refactorings that IntelliJ covers. Rename is also fragile with protocol conformances across module boundaries.

The practical consequence: Swift refactoring is more often done manually or via codemod tooling (like SwiftSyntax-based transforms) than through IDE actions. The community-driven SourceKit-LSP project has improved things for VS Code and Emacs users on the server side, but Xcode's own front-end hasn't fully caught up.

> [!info] For larger refactoring operations in Swift, look at swift-syntax and swift-format together — Apple's own macro system is built on swift-syntax, which means AST-level transforms are increasingly first-class in the ecosystem.

@feynman

Using Xcode for refactoring is like using a kitchen knife that has excellent balance but a shorter blade than you'd like — it handles the everyday cuts cleanly, but for the big jobs you'll be reaching for something else.

@card
id: rfc-ch11-c006
order: 6
title: Static Analysis as a Refactoring Radar
teaser: SonarQube, ESLint, Pylint, and RuboCop are not refactoring tools — they're smell detectors that tell you where refactoring is overdue before you decide what to do.

@explanation

Static analysis tools surface code smells programmatically. They don't perform refactorings, but they act as a refactoring radar — pointing you at the code that has the highest density of issues before you commit time to manual exploration.

The main tools by ecosystem:

- **SonarQube / SonarCloud** — language-agnostic platform (Java, JS/TS, Python, C#, Go, and more). Issues are mapped to categories that align closely with the refactoring catalog: cognitive complexity, duplicated blocks, long methods, dead code. SonarQube's "technical debt" estimate is a rough but useful triage signal.
- **ESLint** — JavaScript and TypeScript. Rule sets like `eslint-plugin-sonarjs` surface catalog-relevant patterns (duplicated string literals, too-complex functions, nested ternaries).
- **Pylint / Ruff** — Python. Pylint covers style and complexity; Ruff (written in Rust, dramatically faster) is displacing Pylint as the default in new Python projects as of 2024.
- **RuboCop** — Ruby. Deep coverage of Rails idioms and code complexity.

The discipline is to run these tools before starting a refactoring sprint — not as gatekeepers at PR time, but as prioritization input. A method with a cognitive complexity of 40 is a better refactoring target than one with a complexity of 8, even if both have other problems.

> [!warning] Don't let the number of linter warnings paralyze you. In legacy codebases, configure the tools to baseline existing issues and alert only on regressions — incremental improvement over time.

@feynman

A static analyzer is like a building inspector who walks through the structure and marks every code path that violates the standard — the repair decisions are still yours, but you know exactly where to look.

@card
id: rfc-ch11-c007
order: 7
title: jscodeshift — AST-Based Codemods for JS and TS
teaser: jscodeshift lets you write programmatic refactorings over JavaScript and TypeScript abstract syntax trees — the right tool when you need to apply the same structural change to hundreds of files.

@explanation

jscodeshift is Meta's codemod runner for JavaScript and TypeScript. It executes a transform function against each file in a target directory, giving your script access to the parsed AST via a jQuery-like `jscodeshift` API.

A minimal transform that renames a function call:

```js
// transform.js
module.exports = function(fileInfo, { jscodeshift: j }) {
  return j(fileInfo.source)
    .find(j.CallExpression, { callee: { name: 'oldFunctionName' } })
    .forEach(path => {
      path.node.callee.name = 'newFunctionName';
    })
    .toSource();
};
```

Run it across a codebase:

```bash
npx jscodeshift -t transform.js src/ --extensions ts,tsx
```

jscodeshift is the foundation for major ecosystem migration tooling: React's codemod collection (e.g., class components to hooks migration), Next.js upgrade codemods, and create-react-app migration scripts all use it. When a library ships a breaking API change, jscodeshift transforms are how they make it semi-automated.

The honest trade-off: jscodeshift transforms require understanding the AST shape of the code you're targeting. AST Explorer (astexplorer.net) is essential for developing them. For simple find-and-replace, `jscodeshift` is overkill — use it when the transformation is genuinely structural (replacing an import pattern, migrating a component API, converting a function signature).

> [!tip] Use AST Explorer with the `recast` parser to see the exact AST node types your code produces — this saves most of the debugging time when writing a new transform.

@feynman

jscodeshift is like having a skilled contractor who can execute the same renovation in every apartment in a building simultaneously — you write the renovation spec once, they do all the work.

@card
id: rfc-ch11-c008
order: 8
title: ast-grep and Comby — Structural Search and Replace
teaser: ast-grep and Comby let you write pattern-based structural refactorings without building a full AST transform — the right fit for cross-language changes that don't need the full power of jscodeshift.

@explanation

**ast-grep** is a fast, Rust-based structural search tool. It uses syntax-aware pattern matching — `$EXPR` is a metavariable matching any expression — and supports rewrite rules. It understands over twenty languages via tree-sitter grammars.

```bash
# Find all calls to deprecated() and replace with updated()
ast-grep --lang js --pattern 'deprecated($ARG)' --rewrite 'updated($ARG)' src/
```

**Comby** is a language-agnostic structural matcher that targets "templates" without requiring grammar definitions. It's less precise than ast-grep (it doesn't fully parse code) but handles more languages and edge cases in multi-line constructs.

```bash
comby 'console.warn(:[msg])' 'logger.warn(:[msg])' .js .ts -in-place
```

Where these tools shine:

- Cross-language migrations (the same pattern in Python, Go, and Ruby simultaneously)
- Simpler transformations where jscodeshift's AST API overhead isn't justified
- CI-enforced patterns — run in `--check` mode to flag if a deprecated pattern reappears

The honest limitation: ast-grep is younger than jscodeshift (active development since 2022) and some language grammars are still maturing. Complex rewrites that require semantic understanding — like "only replace this call if the variable is a string type" — are not in scope for either tool.

> [!info] ast-grep's rule files (YAML) support composable rules with `all`, `any`, and `not` logic, making it viable for enforcement in CI without a custom script.

@feynman

ast-grep is like a find-and-replace that actually understands your code's grammar — it won't match the pattern inside a comment or a string literal the way a regex would.

@card
id: rfc-ch11-c009
order: 9
title: OpenRewrite — Platform-Scale Codemods for the JVM
teaser: OpenRewrite is the open-source platform for safe, large-scale automated refactoring of Java, Kotlin, YAML, and XML — designed for the class of changes that affect entire repositories or multi-module Maven/Gradle builds.

@explanation

OpenRewrite models code transformations as "recipes" — composable, declarative operations that run against a lossless semantic AST (called an LST, Lossless Semantic Tree). Unlike jscodeshift or ast-grep, OpenRewrite understands imports, type resolution, and project structure.

Run a recipe from the command line using Maven or Gradle:

```bash
# Migrate from JUnit 4 to JUnit 5
mvn -U org.openrewrite.maven:rewrite-maven-plugin:run \
  -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-testing-frameworks:LATEST \
  -Drewrite.activeRecipes=org.openrewrite.java.testing.junit5.JUnit4to5Migration
```

A custom recipe in YAML form:

```yaml
---
type: specs.openrewrite.org/v1beta/recipe
name: com.example.RenameProperty
recipeList:
  - org.openrewrite.java.RenameVariable:
      oldName: oldField
      newName: newField
```

OpenRewrite's recipe library covers: Java version upgrades (Java 8 → 11 → 17 → 21), framework migrations (Spring Boot 2 → 3, Micronaut, Quarkus), testing framework upgrades, security vulnerability remediation (Log4Shell), and dependency upgrades.

The trade-off: OpenRewrite requires the project to compile cleanly before a recipe runs. It won't handle broken codebases or multi-language transforms outside the JVM ecosystem. It also adds a Maven/Gradle plugin dependency to your build.

> [!info] Moderne (the commercial arm of OpenRewrite) offers a platform that runs recipes across hundreds of repositories simultaneously — valuable for large organizations managing many services on the same library stack.

@feynman

OpenRewrite is like having a master plumber who can re-pipe every unit in a building at once by understanding the full schematic — not just swapping visible fixtures but tracing every dependency back to the source.

@card
id: rfc-ch11-c010
order: 10
title: Language Server Protocol
teaser: LSP is why rename works in VS Code, Neovim, and Emacs without each editor reimplementing language intelligence — it's the infrastructure layer that makes refactorings portable.

@explanation

Language Server Protocol (LSP), introduced by Microsoft in 2016 and now maintained as an open standard, defines a JSON-RPC communication protocol between an editor (the "client") and a language-aware process (the "server"). The editor sends requests like `textDocument/rename`; the server returns workspace edits.

The refactoring-relevant LSP capabilities:

- `textDocument/rename` — produces a set of edits to rename a symbol and all references
- `textDocument/codeAction` — returns a list of applicable actions for the cursor position (includes Extract Method, Fix All, Organize Imports)
- `textDocument/documentSymbol` — enables breadcrumb navigation by symbol
- `workspace/applyEdit` — the server tells the client to apply a set of changes across files

Why this matters for refactoring tools: every language server that implements `codeAction` correctly makes those actions available in any LSP client. TypeScript's language server adds Extract Function support; that action works in VS Code, Neovim, Helix, and any other LSP-compatible editor without those editors knowing anything about TypeScript.

The current landscape as of 2024:

- **rust-analyzer** (Rust) — among the best LSP implementations; offers struct field extraction, pull refactorings, and more.
- **clangd** (C/C++) — rename, extract, and code actions.
- **Pylance / pyright** (Python) — rename and extract; improving each release.
- **gopls** (Go) — rename and fill struct.

The limitation: LSP's refactoring surface is still narrower than what IntelliJ's native model can express. Change Signature, Pull Up/Down, and deep OO hierarchy transformations don't have standard LSP request types yet.

> [!info] The `codeAction` response includes a `kind` field (e.g., `refactor.extract`, `refactor.inline`) that editors use to categorize actions in their menus — servers that populate this correctly give a much better UX.

@feynman

LSP is like a universal adapter plug — language intelligence is implemented once in the server, and any editor that speaks the protocol gets the same capabilities without anyone duplicating the work.

@card
id: rfc-ch11-c011
order: 11
title: Linters That Fix vs Linters That Just Complain
teaser: The difference between ESLint --fix, Ruff, and Prettier on one side and a plain Pylint run on the other is the difference between a tool that reduces debt and a tool that only measures it.

@explanation

Static analysis tools divide into two categories:

**Auto-fixing linters and formatters** — apply changes directly, making them part of the refactoring workflow:

- **Prettier** — opinionated formatter for JS/TS/CSS/HTML/JSON/Markdown. No configuration options for style; it formats on save or in CI. When your team adopts Prettier, an entire class of formatting debates and nit-picks disappear from code review.
- **ESLint --fix** — applies safe auto-fixes for linting rules that have a deterministic transformation. Not all rules are auto-fixable, but common ones (unused imports, `var` → `const`, quote style) are.
- **Ruff** — Python linter and formatter. Written in Rust, dramatically faster than Pylint or Black + isort. `ruff check --fix` applies auto-fixes; `ruff format` replaces Black. As of 2024, Ruff has become the default recommendation for new Python projects.
- **gofmt / goimports** — Go's canonical formatter; non-negotiable in Go projects.

**Report-only tools:**

- **Pylint** in default mode — reports issues but does not apply fixes. Useful for surfacing complexity and smell, not for incrementally reducing technical debt automatically.
- **SonarQube** — reports and tracks over time, but does not modify code.

The practical discipline: auto-fixing tools belong in pre-commit hooks and CI — they run on every change and keep code from degrading. Report-only tools inform periodic refactoring sprints.

> [!tip] Running `ruff check --fix && ruff format` as a pre-commit step replaces what used to require Pylint + Black + isort + autoflake — four tools replaced by one, in a fraction of the time.

@feynman

An auto-fixing linter is like a spell-checker that corrects as you type; a report-only linter is like a grammar teacher who circles every error in red but hands the paper back for you to fix yourself.

@card
id: rfc-ch11-c012
order: 12
title: CI Enforcement — Hooks and Quality Gates
teaser: Automated refactoring only compounds value if regressions are blocked at commit and merge time — pre-commit hooks and CI quality gates are what make the improvement durable.

@explanation

A refactoring sprint that isn't backed by enforcement is temporary. The same patterns reappear within weeks without friction at the point of introduction.

**Pre-commit hooks** run locally before a commit is created. The major frameworks:

- **Husky** (Node ecosystem) — configures Git hooks via `package.json`. Standard setup runs ESLint, Prettier, and tests on staged files. Used by most JS/TS projects.
- **lefthook** — faster alternative to Husky, supports parallel hook execution, language-agnostic. Increasingly preferred for monorepos or mixed-language projects.
- **lint-staged** — pairs with Husky or lefthook to run tools only on staged files, not the entire codebase — making hooks fast enough that developers don't disable them.

A minimal lefthook configuration:

```yaml
pre-commit:
  parallel: true
  commands:
    lint:
      glob: "*.{js,ts}"
      run: npx eslint --fix {staged_files}
    format:
      glob: "*.{js,ts,json}"
      run: npx prettier --write {staged_files}
```

**CI quality gates** are the second line of enforcement. SonarQube Quality Gates block PR merges when new code introduces smells above a threshold. Coverage gates block merges when test coverage drops below a floor. These complement pre-commit hooks — hooks catch most issues locally, gates catch the rest before they reach main.

The anti-pattern to avoid: adding hooks and gates to enforce a standard that the existing codebase violates. This creates constant false positives and guarantees developers disable the tooling. Configure gates to enforce "no new violations" rather than "zero violations" until the legacy debt is addressed.

> [!warning] Never configure a pre-commit hook that takes more than 5–10 seconds on a typical change. Slow hooks train developers to commit with `--no-verify`, defeating the entire purpose.

@feynman

Pre-commit hooks and CI gates are like the double-door system at a building entrance — most issues are stopped at the first door, but the second door is there specifically for the cases the first one missed.
