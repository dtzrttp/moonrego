# Architecture

MoonRego is a pure MoonBit implementation of a documented Rego v1 subset. Its
library packages are usable on native, wasm-gc, wasm, and JavaScript targets.
The file-based CLI is a separate native-only adapter.

## Evaluation pipeline

```text
Rego source
    -> lexer and source spans
    -> syntax tree
    -> compiler checks and rule index
    -> bounded query evaluator
    -> MoonRego values and structured diagnostics
```

| Package | Responsibility |
| --- | --- |
| `diagnostic` | Source positions, spans, stages, severity, and diagnostics |
| `internal/lexer` | Rego tokens and lexical errors |
| `parser`, `syntax` | Rego v1 expressions, modules, rules, and AST |
| `value` | Runtime values, exact finite decimals, and JSON conversion |
| `compile` | Rule grouping, import aliases, safety, builtin arity, conflicts, and recursion checks |
| `eval` | Binding environments, references, expressions, rules, builtins, and step accounting |
| `cmd/cli` | Argument parsing, policy discovery, JSON files, output, and test-rule execution |
| `cmd/moonrego` | Native process entry point and exit status |

## Undefined and rule evaluation

`Value` represents JSON/Rego values and does not contain an undefined case. An
expression with no successful result produces no value; this keeps a missing
reference distinct from an explicit JSON `null`. Query bodies carry an array of
binding environments from one expression to the next, so iteration and
backtracking can yield several results.

Array and set comprehensions evaluate their body in a copied binding
environment, then evaluate the result expression once for each successful row.
Array results preserve successful-row order and duplicates; set results remove
duplicates. Variables remain scoped to the comprehension. Body iteration and
value comparisons used for set deduplication charge the shared evaluation step
budget.

Complete rules collect successful values and report a conflict when definitions
produce unequal values. A default is used only when the complete rule has no
value. `contains` rules collect distinct values as a Rego set. Compilation
rejects unsafe variables, invalid builtin names or arities, rule shape conflicts,
duplicate defaults, and recursive rule dependencies.

## Builtins and limits

Builtins are implemented in the evaluator and registered by exact name and
arity in the compiler. Invalid builtin inputs are undefined by default; strict
mode turns them into `rego_eval_builtin_error` diagnostics. The current step
budget limits evaluator work. Result count, output size, and recursion depth
limits are not implemented yet.

The current evaluator does not normalize all output ordering across backends.
Callers should not depend on the iteration order of object keys or sets. Exact
decimal arithmetic is used for the supported number operations; division is
not implemented.

## Effects and targets

Core parser, compiler, values, and evaluator packages do not read files, access
the network, or read process environment. The CLI owns filesystem access and is
configured for the native backend. CI checks, builds, and tests the shared
library on `native`, `wasm-gc`, `wasm`, and `js`.
