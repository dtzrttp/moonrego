# Rego v1 compatibility

MoonRego targets complete Rego v1 language semantics, but its current
implementation is incomplete and does not claim full Open Policy Agent
compatibility. The [roadmap](rego-v1-roadmap.md) defines the endpoint and
required evidence. Unsupported constructs should produce a
diagnostic or an undefined result as described below; they are not silently
translated into different semantics.

## Implemented

| Area | Supported behavior |
| --- | --- |
| Modules | `package`, `import data...` and aliases |
| Rules | Constant, `default`, complete boolean/value rules with `if`, ordered complete-rule `else` chains with conditional or unconditional value branches, and `contains` set rules |
| Functions | Same-package calls to functions with named parameters, including multiple definitions, local bindings, conflict detection and shared step budget; default functions with literal values |
| Expressions | JSON literals, arrays, string-key objects, sets, array, set, and object comprehensions, references, assignment, comparisons, `in`, `not`, `every`, and exact `+`, `-`, `*` |
| Iteration | `some value in collection`; `some key, value in collection` for arrays and objects; `every value in collection`; `every key, value in collection` for arrays, objects and sets |
| Compiler | Unsafe-variable checks, builtin name/arity checks, rule-shape/default conflicts, and recursion checks |
| Evaluation | `input`/`data`, backtracking, complete/default/set rules, conflict diagnostics, and a maximum step count |
| Builtins | `count`; `is_null`, `is_boolean`, `is_number`, `is_string`, `is_array`, `is_object`, `is_set`; `to_number`; `upper`, `lower`, `contains`, `startswith`, `endswith`; numeric `sum`, `min`, `max`; `array.concat`; `object.get`; `object.keys` |
| CLI | Native `check`, `eval`, and `test` commands; JSON or pretty diagnostics/results |

`sum`, `min`, and `max` currently accept arrays or sets of numbers. `array.concat`
accepts two arrays. `object.get` supports a string key or a path array through
objects and arrays, and returns its default if the path is missing. `object.keys`
returns a set of string keys.

Array comprehensions use `[value | body]`; set comprehensions use
`{value | body}`; object comprehensions use `{key: value | body}`. Their bodies
accept semicolon-separated expressions, and variables bound there are local to
the comprehension. Array results preserve iteration order and duplicate values;
set results contain distinct values. Object-comprehension keys must evaluate to
strings; any repeated key produces a diagnostic, even when the associated
values are equal. Body iteration and value comparisons used to remove duplicate
set results use the shared evaluation step budget.

`every` requires a nonempty braced body and supports arrays, objects, and sets.
Both single-variable `some-in` and `every` bind object values.
The one-variable `every` form binds array elements, object values, and set members; its
two-variable form binds array indices and elements, object keys and values, or
the same set member to both variables.
Its header and body variables are local to the expression, and an empty
collection passes vacuously. A missing or dynamically resolved non-collection
domain is undefined. Static non-collection type checking is incomplete. `not every`
is rejected during parsing. Duplicate named `every` binders are rejected;
OPA v1.21.4 confirms this and allows two-variable set iteration.

## Not implemented

- Rego v0 compatibility syntax;
- division, remainder, `with`, function-associated `else`, default function comprehension values,
  qualified/imported function calls, and function argument patterns;
- two-variable `some-in` over sets and composite binding patterns;
- most OPA builtins, including generic `sort`, `product`, and non-numeric `min`/`max`;
- result-count, output-byte, and recursion-depth budgets;
- complete deterministic result normalization, tracing, coverage, bundles, or OPA services.

The current conformance package has first-party semantic regression cases.
OPA v1.21.4 was acquired on 2026-10-31 and selected oracle checks were run;
complete differential and upstream conformance suites remain pending. No upstream
OPA test fixtures have been copied. See `conformance/README.md`,
`conformance/opa/README.md`, and the root `NOTICE.md` for provenance and status.
