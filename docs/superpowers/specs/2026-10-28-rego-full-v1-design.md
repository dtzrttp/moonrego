# Full Rego v1 design and first implementation slice

The product endpoint is complete Rego v1 semantics against pinned OPA v1.21.4,
including its built-in capabilities and target-specific host effects. Current
behavior and any unverified or unsupported forms remain explicit. The full
scope, staged work and acceptance evidence are in docs/rego-v1-roadmap.md.

The first slice implements ordered complete rules. The syntax tree represents
an else chain as one complete rule with ordered branches. Each branch contains
its own optional result expression, body, and source span. Parsing accepts the
documented conditional and unconditional value forms, and rejects else on
default and set rules. The
compiler checks every branch with an independent scope and includes all branch
expressions in recursion dependency analysis. Evaluation examines branches in
order with fresh local bindings, stops on the first defined result, preserves
false as a defined result, propagates errors, and still detects conflicts with
separate definitions of the same complete rule. A default applies only if no
definition has a result. All evaluation uses the existing shared step budget.

The first slice does not claim full else or Rego support: function-associated
else, unspecified edge cases and the OPA oracle remain separately tracked.
Parser, compiler, evaluator and end-to-end tests exercise branch order, fallback,
false results, local scopes, conflicts, recursion and malformed forms. The
published OPA language reference establishes the ordinary ordered behavior;
exact compatibility requires the pinned executable and conformance corpus.
