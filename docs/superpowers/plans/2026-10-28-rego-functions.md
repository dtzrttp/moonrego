# Rego user functions: implementation plan

**Goal:** Add a tested same-package named-parameter function slice while
retaining the documented complete-Rego endpoint and honest current limits.

**Architecture:** Add a function rule kind, predeclare signatures by package,
and carry package identity in the evaluation environment. Function calls use
fresh local bindings, all matching definitions and the shared evaluation budget.

- [x] Add an end-to-end function policy test and observe the parser reject it.
- [x] Parse named-parameter function heads and store arguments, head and body.
- [x] Check signatures, parameter safety, conflicts and same-package recursive
  call dependencies, preserving diagnostics for unknown functions.
- [x] Evaluate arguments in caller scope and function bodies in fresh local
  package scope; compare multiple outputs and propagate errors and budgets.
- [x] Add regression tests for boolean functions, undefined arguments and
  bodies, conflicts, arity, scope, recursion and strict built-in errors.
- [x] Run formatting, all-target checks, tests and builds; generate and inspect
  public interfaces; update compatibility documentation and local evidence.
