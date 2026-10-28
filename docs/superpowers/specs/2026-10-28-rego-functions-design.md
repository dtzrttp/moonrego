# Rego user functions: initial implementation slice

The full endpoint remains the complete pinned Rego v1 language and built-in
capabilities described in docs/rego-v1-roadmap.md. This slice adds ordinary
same-package user functions with named variable parameters; pattern arguments,
default functions, function-associated else and imported/qualified function
calls remain open work and must not be claimed as supported.

The parser represents a function as a rule kind containing its parameter names
and optional result expression, with the existing rule body. Compilation first
collects function signatures across modules in each package, checks parameter
scope and arity, rejects conflicting rule shapes and function arities, and
includes same-package call edges in cycle detection. Unknown functions continue
to produce a diagnostic. Parameter bindings do not leak into the caller.

Evaluation first evaluates all call arguments in the caller environment. It
then creates a fresh package and import environment per matching definition,
binds parameters, evaluates its body, and evaluates its result or implicit true.
All definitions with the same name and arity participate; equal results are
allowed and conflicting results produce the existing conflict diagnostic. No
result is undefined, and strict built-in errors, the step budget and other
diagnostics propagate rather than being converted to a function result.

Tests exercise source parsing, arithmetic results, false/undefined bodies,
multiple definitions and conflicts, arity, scoping, recursion and budget
propagation. OPA differential execution remains a separate acceptance gate.
