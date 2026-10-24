# Rego v1 compatibility

MoonRego is a deliberately limited Rego v1 implementation. It does not claim
full Open Policy Agent compatibility. Unsupported constructs should produce a
diagnostic or an undefined result as described below; they are not silently
translated into different semantics.

## Implemented

| Area | Supported behavior |
| --- | --- |
| Modules | `package`, `import data...` and aliases |
| Rules | Constant, `default`, complete boolean/value rules with `if`, and `contains` set rules |
| Expressions | JSON literals, arrays, string-key objects, sets, array, set, and object comprehensions, references, assignment, comparisons, `in`, `not`, and exact `+`, `-`, `*` |
| Iteration | `some value in collection`; `some key, value in collection` for arrays and objects |
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

## Not implemented

- Rego v0 compatibility syntax;
- division, remainder, user functions, `every`, `else`, or `with`;
- two-variable `some-in` over sets and composite binding patterns;
- most OPA builtins, including generic `sort`, `product`, and non-numeric `min`/`max`;
- result-count, output-byte, and recursion-depth budgets;
- complete deterministic result normalization, tracing, coverage, bundles, or OPA services.

The current conformance package has eight first-party semantic regression cases.
OPA is not installed in the development environment, and no upstream OPA test
fixtures have been copied or run as an oracle. See `conformance/README.md` and
the root `NOTICE.md` for test and source provenance.
