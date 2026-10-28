# Full Rego v1 semantics: target and evidence

MoonRego targets the complete Rego v1 language semantics, benchmarked against a
fixed OPA v1.21.4 reference. The current implementation is incomplete. This
document is a development and acceptance plan, not a compatibility claim.

## Scope of the endpoint

- Parse and check the complete Rego v1 grammar and its lexical rules, including
  rule reference heads, functions and argument patterns, imports, ordered else
  chains, with modifiers, comprehensions, quantifiers and all operators.
- Match variable scope, unification and evaluation ordering, virtual and base
  data, undefined values, conflicts, safety, recursion, diagnostics, and values
  including arbitrary keys and the reference implementation's number semantics.
- Support every built-in listed by the pinned reference's capabilities, with
  equivalent types, errors and results. Host effects, time and nondeterminism
  require explicit host interfaces and corresponding target-specific tests;
  they are not silently removed from the full-compatibility target.
- Support the declared native, wasm, wasm-gc and JavaScript core targets.
  A target is not called fully compatible if required host capabilities or
  tests are missing. An OPA server, management APIs, and command-line option
  parity are separate product goals, rather than language semantics.

## Delivery sequence

1. Obtain the exact OPA release and its capabilities manifest through an
   authorized source; record version, provenance and license. Run first-party
   differential fixtures against both engines; normalize only semantically
   unordered values, and compare undefined, conflicts and error stages.
2. Complete grammar, scopes and rules: ordered else, functions and patterns,
   nested and dynamic rule heads, with replacements, imports and v1 syntax.
3. Complete unification and evaluation: variable binding and reordering,
   references and backtracking, arbitrary values and keys, numeric operations,
   document assembly and conflict behavior.
4. Implement all pinned built-in capabilities, including host-dependent ones,
   with per-target capability tests and explicit deterministic test hosts.
5. Run the pinned official language/conformance tests where licensing and test
   harness permit, plus differential regression tests on all supported targets.
   Document every remaining failure and its reason; no known semantic gap may
   be relabeled as an intentional subset in the final compatibility claim.

## Acceptance evidence

Full Rego v1 support may be claimed only after the pinned capabilities inventory
has been compared item by item, the complete applicable conformance corpus and
the independent differential suite pass, and native/wasm/wasm-gc/js results and
host-dependent behavior are reproducible. The reference version, corpus
revision, exact commands, results, test counts, exclusions and their reasons
must be published. Skipping a feature, builtin category or target is a recorded
gap, not evidence of full compatibility.

## Current status

The existing implementation supports only the subset in compatibility.md.
Ordered complete-rule else chains with conditional and value-only branches
have been added, and
single-variable object iteration now binds values. Same-package functions with
named parameters have an initial implementation; patterns, default functions,
qualified calls and function-associated else are still missing. Functions, with, rule
reference heads, many operations and built-ins are not
complete. Existing first-party tests do not establish OPA parity. OPA v1.21.4
was not available locally during the previous oracle attempt, so the capability
inventory, independent oracle outputs, and upstream conformance runs are
pending. Do not state that the full endpoint has been achieved.

References: [Rego grammar and policy reference](https://www.openpolicyagent.org/docs/policy-reference),
[policy language semantics](https://www.openpolicyagent.org/docs/policy-language), and
[built-in capability reference](https://www.openpolicyagent.org/docs/policy-reference/builtins).
