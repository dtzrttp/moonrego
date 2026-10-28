# Rego `every` Implementation Plan

> Historical plan: its single-variable object-key assumption was corrected on
> 2026-10-28. Its old source-file split also counted two white-box test files
> as production files. See docs/compatibility.md and the 2026-10-28
> verification record for current behavior and a corrected classification.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the reviewed Rego v1 `every` universal quantifier to MoonReGo with correct parsing, compiler scoping, evaluation, diagnostics, tests, and examples.

**Architecture:** Preserve `every` as an explicit `syntax.Expr` node because it owns a local scope and has universal, short-circuiting evaluation semantics. Reuse the parser's rule-body parser, the compiler's copied-bound-variable pattern, the evaluator's `Environment`, `eval_body`, and shared `EvalContext` budget. Do not lower `every` into a comprehension.

**Tech Stack:** MoonBit latest stable toolchain; current MoonReGo parser, syntax AST, compiler safety checker, evaluator, CLI, `moon test`; OPA CLI v1.21.4 for a one-time local semantic oracle, not a runtime or CI dependency.

## Global Constraints

- Follow `docs/superpowers/specs/2026-10-24-rego-every-design.md` and the existing `docs/superpowers/plans/2026-10-23-moonrego-v0.1.md` project conventions.
- Implement only the documented Rego v1 subset; do not claim full OPA compatibility.
- Empty array, object, or set domains succeed without evaluating the body.
- Every non-empty domain item must have at least one successful body evaluation; one failing item makes the whole `every` expression undefined.
- The domain is evaluated once in the outer environment. `every` header variables and body assignments are local and do not add bindings to the outer evaluation.
- Single-variable iteration supports arrays, objects (binding property names), and sets. Two-variable iteration supports arrays (index/value) and objects (key/value); sets in the two-variable form return `rego_unsupported_feature`.
- An undefined domain is undefined; a non-collection domain produces the design's eval-stage `rego_type_error`, with any difference from OPA v1.21.4 recorded in `docs/compatibility.md`.
- Reject `not every`, including `not (every ...)`, as a parse or compile diagnostic.
- Charge the `every` expression, every visited domain item, and its body against the existing shared evaluation step budget; propagate existing diagnostics and stop on budget exhaustion.
- Do not copy OPA implementation code or upstream test fixtures. Record only first-party oracle policies, inputs, outputs, OPA version, and commands.
- Use test-driven development. Do not weaken warnings or edit generated `.mbti` files manually.
- First run and record `moon version --all`, then compare it with the current stable channel using the [official MoonBit updates](https://www.moonbitlang.com/updates) and [stable `moon` command reference](https://docs.moonbitlang.com/en/stable/toolchain/moon/commands.html). The update index may name a language release while the installer reports a newer dated toolchain build; rely on the output after the default stable upgrade rather than infer freshness from one version string. If behind, run `moon upgrade` without `--dev` and repeat the version check; the reference documents `--dev` as the development channel. Use `moon fmt --check`, `moon check --deny-warn --target all`, `moon test --deny-warn --target all`, and `moon build --deny-warn --target all`. Run `moon info` without `--deny-warn` and inspect its generated interface changes.
- Preserve traceable history: this checkout has 11 substantive commits before the `every` work. Commit only actual milestones after their tests pass; do not make empty commits, rewrite dates, or invent contributors. GitHub operations are out of scope here.
- Keep this work local; do not create, modify, push, or inspect a GitHub repository during this plan.

## Execution status (2026-10-24)

Implementation, follow-up review fixes, and the post-upgrade local release gate
are complete on branch codex/rego-every. The default stable moon upgrade
completed successfully; moon version --all reports moon 0.1.20261023,
moonc v0.10.17+d971670cd, and moonrun 0.1.20261023 after the refresh. All
targets pass: wasm, wasm-gc, and JS 130/130 each; native 133/133. Formatting,
all-target check/build, moon info, and both every CLI examples pass. The latest
post-upgrade build emitted no warning; an earlier Windows build emitted cached
dependency warning C4005, recorded in docs/verification.md.

OPA v1.21.4 is not installed. Downloading its official Windows binary failed
with proxy authentication, so Task 1's oracle execution and comparison remain
pending; the fixture expectations are not observations. No GitHub repository
operation has been performed for this branch. See docs/verification.md for
command details.
---

## File Map

- `conformance/opa/every.rego`, `conformance/opa/every-input.json`, `conformance/opa/every-blocked-input.json`, `conformance/opa/every-noncollection-input.json`, `conformance/opa/every-duplicate-binder.rego`, `conformance/opa/every-duplicate-binder-input.json`, `conformance/opa/not-every.rego`, `conformance/opa/every-set-pair.rego`, `conformance/opa/README.md`: first-party cases and reproducible OPA v1.21.4 oracle commands; not executed by CI.
- `syntax/expr.mbt`: public `Expr::Every` variant, source span, and syntax representation.
- `parser/expression.mbt`: parse one- and two-variable headers and braced bodies. The `Every` token and lexer keyword already exist in `syntax/token.mbt` and `internal/lexer/lexer.mbt`.
- `parser/expression_test.mbt`, `parser/expression_error_test.mbt`: successful forms, nested bodies, spans, and rejection tests.
- `compile/compile.mbt`: check the domain against outer bindings and the body in a local safety environment.
- `compile/safety_test.mbt`: domain, body, and post-`every` scope tests.
- `eval/expression.mbt`: universal evaluation, key/value iteration, non-collection diagnostics, and non-value-context handling.
- `eval/environment.mbt`: local shadowing binder operation that copies bindings and overwrites only within the copied environment.
- `eval/expression_test.mbt`: array/object/set, empty, undefined, failure, nesting, scope, diagnostics, and step budget behavior.
- `conformance/runner_test.mbt`: policy-level regressions using the existing `eval_policy_case` helper.
- `docs/compatibility.md`, `README.md`, `README.mbt.md`, `conformance/README.md`: feature matrix, runnable CLI example, API and test provenance.
- `.github/workflows/test.yml`: add the verified `every` allowed/blocked CLI smoke cases to the existing cross-platform workflow.
- `examples/every/`: standalone policy and input fixtures for the CLI demonstration.

## Task 1: Pin the OPA semantic oracle

**Files:**
- Create: `conformance/opa/every.rego`
- Create: `conformance/opa/every-input.json`
- Create: `conformance/opa/every-blocked-input.json`
- Create: `conformance/opa/every-noncollection-input.json`
- Create: `conformance/opa/not-every.rego`
- Create: `conformance/opa/every-set-pair.rego`
- Create: `conformance/opa/every-duplicate-binder.rego`
- Create: `conformance/opa/every-duplicate-binder-input.json`
- Create: `conformance/opa/README.md`

**Interfaces:**
- Produces: named expected cases for arrays, object key/value binding, set values, empty domains, undefined domains, non-collection domains, binder/body scope, `not every`, and two-variable set iteration.
- Consumes: OPA v1.21.4 released 2026-10-23, [official release](https://github.com/open-policy-agent/opa/releases/tag/v1.21.4).

- [x] **Step 1: Write first-party oracle policy and input**

Create `conformance/opa/every.rego`:

```rego
package every_oracle

array_every if {
  every index, role in input.roles {
    index >= 0
    role != "blocked"
  }
}

object_every if {
  every name, user in input.users {
    startswith(name, "team-")
    "staff" in user.roles
  }
}

set_every if {
  every tag in {"web", "api"} {
    tag != "blocked"
  }
}

blocked_set_every if {
  every tag in {"web", "blocked"} {
    tag != "blocked"
  }
}

object_key_every if {
  every name in input.users {
    startswith(name, "team-")
  }
}

empty_every if {
  every item in [] {
    item > 0
  }
}

empty_object_every if {
  every item in {} {
    item > 0
  }
}

empty_set_every if {
  every item in set() {
    item > 0
  }
}

undefined_every if {
  every item in input.missing {
    item > 0
  }
}

outer_binding if {
  role := "outside"
  every role in ["inside"] {
    role == "inside"
  }
  role == "outside"
}
```

Create `conformance/opa/every-input.json`:

```json
{
  "roles": ["viewer", "admin"],
  "users": {
    "team-a": {"roles": ["staff"]},
    "team-b": {"roles": ["staff", "reviewer"]}
  },
  "tags": ["web", "api"]
}
```


Create `conformance/opa/every-blocked-input.json` with roles `["admin", "blocked"]`, users.team-b.roles `["contractor"]`, and no set domain input.
Create `conformance/opa/every-noncollection-input.json` with `{"value": 7}`.
Create `conformance/opa/not-every.rego` containing `package every_negative` and `allow if { not every role in input.roles { true } }`.
Create `conformance/opa/every-set-pair.rego` containing `package every_set_pair` and `allow if { every key, value in {"item"} { true } }`.
Create `conformance/opa/every-duplicate-binder.rego` and its input fixture to check equal and unequal object key/value pairs with the same binder name.

- [ ] **Step 2: Run and record the pinned oracle**

Before implementation, run `moon version --all` and record it. Compare with the official stable channel; if behind, run `moon upgrade` without `--dev` and record the repeated `moon version --all`. Run `opa version`; expected version line: `Version: 1.21.4`. If OPA v1.21.4 is not installed, obtain the official v1.21.4 executable in the OS temporary directory, outside the repository, and verify it with `opa version`. For each defined policy query run:

```powershell
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.array_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.object_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.set_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.object_key_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json --fail 'data.every_oracle.blocked_set_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json --fail 'data.every_oracle.undefined_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-blocked-input.json --fail 'data.every_oracle.array_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-blocked-input.json --fail 'data.every_oracle.object_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.empty_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.empty_object_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.empty_set_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.outer_binding'
```

Expected output for `array_every`, `object_every`, `set_every`, `object_key_every`, all three `empty_*_every` rules, and `outer_binding` is `true`. Run `array_every` and `object_every` with `every-blocked-input.json`; each must be undefined. Run `blocked_set_every` and `undefined_every` with `--fail`; both must return a nonzero exit status for undefined results. Run `opa check conformance/opa/not-every.rego` and `opa check conformance/opa/every-set-pair.rego`, then run `opa eval --format pretty --input conformance/opa/every-noncollection-input.json 'every item in input.value { true }'` to record OPA's actual non-collection error stage and code. Record every command, output, and version in `conformance/opa/README.md`; do not infer error codes from documentation.

- [ ] **Step 3: Compare oracle results with the approved spec**

Expected: core universal quantification, empty-domain, and no-leak behavior matches the spec. If any core result differs, stop before MoonBit implementation, update the design document with the OPA evidence, and request review. For diagnostic-code differences already allowed by the spec, retain the MoonReGo code and record the compatibility difference.

Pending because the official OPA binary could not be downloaded through the configured proxy. The follow-up oracle cases include repeated binder names; their OPA outcome is still unknown.

- [x] **Step 4: Commit the reproducible oracle record**

```powershell
git add conformance/opa
git -c user.name=dtzrttp -c user.email=313799694+dtzrttp@users.noreply.github.com commit -m "Record OPA every semantic oracle"
```

## Task 2: Add the AST and parser with compiler scope checks

**Files:**
- Modify: `syntax/expr.mbt`
- Modify: `parser/expression.mbt`
- Modify: `parser/expression_test.mbt`
- Modify: `parser/expression_error_test.mbt`
- Modify: `compile/compile.mbt`
- Modify: `compile/safety_test.mbt`
- Modify: `eval/expression.mbt` (temporary exhaustive fail-closed cases until Task 3)

**Interfaces:**
- Produces: `Expr::Every(String?, String, Expr, Array[Expr], SourceSpan)`; `None` key means one binder, `Some(key)` means key/value form.
- Produces: parser syntax strings `Every(None,role,domain,[body...])` and `Every(Some(index),role,domain,[body...])`.
- Produces: compiler rule that checks domain against outer scope and checks all body expressions against a copy containing the `every` binders, then discards that copy.

- [x] **Step 1: Add parser tests and run them red**

Add to `parser/expression_test.mbt`:

```moonbit
///|
test "parses every with a value binder and a braced body" {
  let parsed = @parser.parse_query(
    "every role in input.roles { role != \"blocked\" }",
  )
  assert_eq(parsed.diagnostics().length(), 0)
  inspect(
    parsed.syntax(),
    content="Every(None,role,Ref(input,[Field(roles)]),[Binary(NotEqual,role,String(blocked))])",
  )
}

///|
test "parses every with key and value binders" {
  let parsed = @parser.parse_query(
    "every index, role in input.roles { index >= 0; role == \"admin\" }",
  )
  assert_eq(parsed.diagnostics().length(), 0)
  inspect(
    parsed.syntax(),
    content="Every(Some(index),role,Ref(input,[Field(roles)]),[Binary(GreaterEqual,index,Number(0)),Binary(Equal,role,String(admin))])",
  )
}
```

Add failures for missing binder, missing `in`, missing `{`, and missing `}`. Assert each reports `rego_parse_error` with non-empty source span. Add `not every role in input.roles { true }` and `not (every role in input.roles { true })`; each must report `rego_parse_error`. Run `moon test --deny-warn --target native`; expected: the new parser cases fail because `Every` is not parsed yet.

- [x] **Step 2: Add the explicit syntax node and parser implementation**

Add `Every(String?, String, Expr, Array[Expr], @diagnostic.SourceSpan)` to `syntax.Expr`; include it in `Expr::span` and `Expr::syntax`. In `Parser::parse_unary`, dispatch `TokenKind::Every` to a `parse_every` helper. Parse one identifier, optional comma plus second identifier, required `in`, the domain expression, then require a left brace and reuse `Parser::parse_body`. Build a span from the `every` token through the closing brace. When unary `not` receives a direct `Every` operand (including a parenthesized expression represented as the same AST), report `rego_parse_error` rather than constructing `Unary(Not, Every(...))`.

Keep the existing `Every` lexer token and keyword mapping unchanged. Add a temporary fail-closed `Every` arm to `check_expression` that emits a compile-stage `rego_unsupported_feature` diagnostic and returns false, so the AST change remains exhaustive and cannot silently compile. Add fail-closed evaluator arms: `eval_step` returns no rows and `eval_value` returns `None`. Task 2 Step 3 replaces the temporary compiler diagnostic with scoped safety logic.

- [x] **Step 3: Add compiler scope tests, run red, and implement local safety**

Add to `compile/safety_test.mbt` cases asserting (a) `input.roles` is safe as a domain, (b) an undeclared `roles` domain is unsafe, (c) a body may read a safely assigned outer `account`, (d) a body binder is safe inside its body, and (e) `role` is unsafe in an expression after the `every` expression. Use the OPA v1.21.4 result for a binder matching an outer variable when available; if it remains unavailable, record that comparison as pending and implement the approved design.

Run `moon test --deny-warn --target native`; expected: parser tests pass and the new scope tests fail until `check_expression` handles `Every`.

In `compile/compile.mbt`, for `Every(key_name, value_name, domain, body, _)`, run `check_expression(domain, bound, diagnostics)`. If safe, create `local_bound = bound.copy()`, add the header name(s) to `local_bound` according to the approved design, check body expressions in order against `local_bound`, and return combined safety without modifying `bound`. For the approved shadowing behavior, local binder lookup must precede outer lookup at evaluation time; do not make the compiler accidentally treat the binder as an outer unification.

- [x] **Step 4: Run parser and compiler tests green; commit**

Run `moon fmt --check` then `moon test --deny-warn --target native`. Expected: parser and compiler tests pass; eval tests remain green because the fail-closed evaluator arms do not claim support yet.

```powershell
git add syntax/expr.mbt parser/expression.mbt parser/expression_test.mbt parser/expression_error_test.mbt compile/compile.mbt compile/safety_test.mbt eval/expression.mbt
git -c user.name=dtzrttp -c user.email=313799694+dtzrttp@users.noreply.github.com commit -m "Parse and scope Rego every expressions"
```

## Task 3: Implement universal evaluation and collection iteration

**Files:**
- Modify: `eval/environment.mbt`
- Modify: `eval/expression.mbt`
- Modify: `eval/expression_test.mbt`

**Interfaces:**
- Consumes: `Every(key_name, value_name, domain, body, span)`, `Environment::bind_local`, `eval_body`, `EvalContext::charge`.
- Produces: one `(original_environment, true)` row if every domain item passes; otherwise zero rows. Evaluation never returns header or body bindings to the outer environment.

- [x] **Step 1: Write array, failure, empty, and undefined-domain tests**

Add tests to `eval/expression_test.mbt` for these exact queries and expectations:

```moonbit
let all_pass = @eval.eval_query(
  "every role in input.roles { role != \"blocked\" }",
  @value.Value::Object({
    "roles": @value.Value::array([
      @value.Value::string("viewer"),
      @value.Value::string("admin"),
    ]),
  }),
  @eval.EvalOptions::new(1000),
)
assert_eq(all_pass.diagnostics().length(), 0)
assert_eq(all_pass.values().length(), 1)
assert_true(all_pass.values()[0].equal(@value.Value::boolean(true)))
```

Add a second array with one `blocked` item and assert zero values and zero diagnostics. Add `every item in [] { item > 0 }` and assert `[true]`. Add empty object and empty set domains and assert `[true]` for each. Add an absent `input.roles` domain and assert zero values and no diagnostic. Run `moon test --deny-warn --target native`; expected: these tests fail because the evaluator's `Every` case is still fail-closed.

- [x] **Step 2: Implement the evaluator's all-items loop**

Replace the fail-closed `eval_step` arm. Evaluate the domain once in the current environment. For each supported one-variable value, create a local environment with `Environment::bind_local`, charge the shared context for the item, call `eval_body`, and discard the resulting row environments. `bind_local` copies the bindings map and replaces only the local copy's named value; keep existing `Environment::bind` unification behavior unchanged for `some` and assignment. This implements the approved binder-shadow behavior while preserving the original outer environment; the OPA comparison remains pending. Treat any non-empty body result as success for that item. On the first item with no rows, return no rows. If diagnostics appear, stop and return no rows. If all items pass (including zero items), return exactly `(environment, @value.Value::boolean(true))`. Keep `Every` non-value-producing in `eval_value` by returning `None` there.

- [x] **Step 3: Run evaluator tests green and commit**

Run `moon fmt --check` and `moon test --deny-warn --target native`. Expected: array pass/fail, empty domain, undefined domain, and existing evaluator tests pass.

```powershell
git add eval/environment.mbt eval/expression.mbt eval/expression_test.mbt
git -c user.name=dtzrttp -c user.email=313799694+dtzrttp@users.noreply.github.com commit -m "Evaluate Rego every over array values"
```

## Task 4: Add key/value forms, type errors, and nested scope behavior

**Files:**
- Modify: `eval/expression.mbt`
- Modify: `eval/expression_test.mbt`
- Modify: `compile/safety_test.mbt`
- Modify: `conformance/runner_test.mbt`

**Interfaces:**
- Produces: array index/value iteration; object key/value iteration; single-variable object key iteration; single-variable set value iteration.
- Produces: `rego_unsupported_feature` for two-variable set iteration and eval-stage `rego_type_error` for a non-collection domain, as specified.

- [x] **Step 1: Add collection-form tests**

Add cases with expected results:

```moonbit
"every index, role in input.roles { index >= 0; role != \"blocked\" }"
"every name, user in input.users { startswith(name, \"team-\"); \"staff\" in user.roles }"
"every role in input.roles { role == \"primary\" }"
"every tag in input.tags { tag != \"blocked\" }"
```

The first uses an array of two allowed roles and returns true; the second uses an object containing two staff users and returns true; the third uses a one-key object and checks the key, not its value; the fourth uses a set with two allowed members. Also assert a set with one blocked member returns no rows. Test empty array, object, and set domains as true. Assert `every key, value in input.tags { true }` returns no rows and one `rego_unsupported_feature` diagnostic.

Run `moon test --deny-warn --target native`; expected: two-variable, object, and set tests fail until the remaining domain arms are implemented.

- [x] **Step 2: Implement key/value iteration and explicit domain diagnostics**

Extend the item expansion in `eval/expression.mbt`: arrays produce integer index and element; objects produce string key and property value; sets produce member only. For a set with a key binder, push one eval `rego_unsupported_feature` diagnostic at the `every` span and stop. For values outside array/object/set, push an eval diagnostic with code `rego_type_error`, message `every domain must be an array, object, or set`, and the domain span. A missing/undefined domain remains undefined without a type diagnostic. Check `context.diagnostics` after each body and item so strict built-in and budget errors are never mistaken for a successful universal result.

- [x] **Step 3: Add nested and non-leaking evaluation tests**

Add nested `every` over `input.teams` and `team.roles`, where all teams pass, then change one nested role to `blocked` and assert undefined. Add an outer binding before `every`, use a same-named header binder, and verify both the Task 1 OPA oracle result and that the original outer binding is still visible after `every`. Add compile safety assertions that neither a binder nor an assignment created only in the body becomes available to the following expression.

- [x] **Step 4: Add a policy-level conformance regression and commit**

In `conformance/runner_test.mbt`, use existing `eval_policy_case(source, query, input)` with:

```rego
package p

allow if {
  every role in input.roles {
    role != "blocked"
  }
}
```

Assert `data.p.allow` returns true for `roles: ["admin", "viewer"]`, and undefined for `roles: ["admin", "blocked"]`. Run `moon fmt --check` and `moon test --deny-warn --target native`.

```powershell
git add eval/environment.mbt eval/expression.mbt eval/expression_test.mbt compile/safety_test.mbt conformance/runner_test.mbt
git -c user.name=dtzrttp -c user.email=313799694+dtzrttp@users.noreply.github.com commit -m "Support Rego every collection domains"
```

## Task 5: Verify the shared step budget and error boundaries

**Files:**
- Modify: `eval/expression_test.mbt`
- Modify: `conformance/opa/README.md`

**Interfaces:**
- Produces: exact passing and one-step-short cases for a fixed one-item query; diagnostics stop evaluation and are retained.

- [x] **Step 1: Add exact-budget tests**

Use the fixed query `every x in [1] { x == 1 }`. The expected successful budget is 8 steps: one `eval_step` charge for `every`, one `eval_value` charge for the array literal, one for its number literal, one explicit domain-item charge, then four charges for the body comparison (`eval_step`, `eval_value` on the comparison, and each operand). For two items, the exact total is 14: the shared first four charges plus five per item. Confirm this against the actual `EvalContext::charge` calls when implementing; if the evaluator path charges differently, preserve the boundary-testing intent and record the measured count in the test and oracle notes. Assert `EvalOptions::new(8)` returns `[true]` with no diagnostics and `EvalOptions::new(7)` returns no value and exactly one `rego_eval_step_limit` diagnostic. For `every x in [1, 1] { x == 1 }`, assert 14 steps pass and 13 steps produce one step-limit diagnostic.

Run `moon test --deny-warn --target native`; expected: the seven-step case fails if item charging or body charging is missing, and the eight-step case passes.

- [x] **Step 2: Verify strict built-in errors propagate through `every`**

Use `every value in ["not-a-number"] { to_number(value) > 0 }` with strict built-in errors enabled via `EvalOptions::new(100).with_strict_builtin_errors(true)`. Assert zero values and one `rego_eval_builtin_error` diagnostic. In default mode, assert the item simply fails with no diagnostic. This proves a diagnostic from the body cannot be swallowed by the universal loop.

- [x] **Step 3: Run evaluator and conformance tests and commit**

Run `moon fmt --check` and `moon test --deny-warn --target native`. Expected: exact budget boundary, strict/default error behavior, and all existing tests pass. If the charge count differs because the implementation's measured code path differs, derive and document the count from actual `EvalContext::charge` calls, then set the test to that exact boundary before committing.

```powershell
git add eval/expression_test.mbt conformance/opa/README.md
git -c user.name=dtzrttp -c user.email=313799694+dtzrttp@users.noreply.github.com commit -m "Verify Rego every budget and errors"
```

## Task 6: Add runnable example and compatibility documentation

**Files:**
- Create: `examples/every/policy.rego`
- Create: `examples/every/input.json`
- Create: `examples/every/input-blocked.json`
- Modify: `docs/compatibility.md`
- Modify: `README.md`
- Modify: `README.mbt.md`
- Modify: `conformance/README.md`
- Modify: `.github/workflows/test.yml`

**Interfaces:**
- Produces: a local `moonrego eval` example that checks role arrays and an object of principals, with documented allowed, denied, and empty-domain behavior.

- [x] **Step 1: Add runnable policy and fixture inputs**

Create `examples/every/policy.rego`:

```rego
package access

default allow := false

allow if {
  every role in input.roles {
    role != "blocked"
  }
  every name, principal in input.principals {
    startswith(name, "team-")
    "staff" in principal.roles
  }
}
```

Create `examples/every/input.json`:

```json
{
  "roles": ["admin", "viewer"],
  "principals": {
    "team-a": {"roles": ["staff"]},
    "team-b": {"roles": ["staff", "reviewer"]}
  }
}
```

Create `examples/every/input-blocked.json`:

```json
{
  "roles": ["admin", "blocked"],
  "principals": {
    "team-a": {"roles": ["contractor"]}
  }
}
```

Empty arrays, objects, and sets are covered in unit tests and documented as vacuously passing the respective `every` expression.

- [x] **Step 2: Run the actual CLI commands and record output**

Run the existing command shape from the repository root:

```powershell
moon run cmd/moonrego --target native -- eval 'data.access.allow' -i examples/every/input.json --format json examples/every/policy.rego
moon run cmd/moonrego --target native -- eval 'data.access.allow' -i examples/every/input-blocked.json --format json examples/every/policy.rego
```

Expected: the first JSON response has `"results": [true]`; the second has `"results": [false]` through `default allow := false`. Confirm native CLI usage with `moon run cmd/moonrego --target native -- --help` and record the verified invocation in the README.

- [x] **Step 3: Update compatibility and README**

Add `every` to the implemented expression/iteration rows of `docs/compatibility.md`, specifying arrays, objects, sets, key/value support, scope, empty-domain behavior, `not every` rejection, and the explicit unsupported/error cases. Replace `every` with its supported subset in the not-implemented list. Add the example commands and expected JSON result fields to `README.md` and `README.mbt.md`; update the implemented-feature list and conformance status in `README.mbt.md`. Record that OPA v1.21.4 is an oracle-only development tool and no OPA source or fixtures were copied in `conformance/README.md`.

- [x] **Step 4: Run CLI and docs checks and commit**

Run both example commands above, `moon fmt --check`, and `moon test --deny-warn --target native`. Expected: example outputs match README and tests pass. Add those same allowed and blocked CLI smoke commands to `.github/workflows/test.yml`; preserve its existing stable-channel installation, `moon version --all` reporting, three-OS matrix, and all-target checks. Validate the workflow file locally by reviewing the final YAML and running the commands exactly as CI will. Remote CI status is pending until GitHub operations are authorized.

```powershell
git add examples/every docs/compatibility.md README.md README.mbt.md conformance/README.md .github/workflows/test.yml
git -c user.name=dtzrttp -c user.email=313799694+dtzrttp@users.noreply.github.com commit -m "Document and demonstrate Rego every"
```

## Task 7: Run the full local release gate and inspect generated interfaces

**Files:**
- Modify only intentional generated interface files reported by `moon info`.
- Update: `docs/compatibility.md` if any oracle difference was found.

**Interfaces:**
- Produces: tested parser/compiler/evaluator behavior on every supported target and reviewed public interface changes.

- [x] **Step 1: Confirm the latest local MoonBit toolchain**

Ran moon upgrade --force on the default stable channel. The official updater
completed the install and the post-install moon version --all output is
recorded in docs/verification.md. It returned the same moon 0.1.20261023,
moonc v0.10.17+d971670cd, and moonrun 0.1.20261023 versions, confirming the
latest stable toolchain selected by the updater. No development channel was
used.

- [x] **Step 2: Run formatting, check, tests, build, and interface generation**

Run these commands in order:

```powershell
moon fmt --check
moon check --deny-warn --target all
moon test --deny-warn --target all
moon build --deny-warn --target all
moon info
```

Expected: formatting and all-target checks/build pass; all native, wasm, wasm-gc, and JavaScript tests pass. `moon info` completes; generated `.mbti` files include only the intentional public `Expr::Every` API change. Do not pass `--deny-warn` to `moon fmt` or `moon info`.

- [x] **Step 3: Review local source and repository state**

Run the listed local checks and review the source and repository state. **Verified locally:** at d945f80 the feature branch had 20 meaningful commits, 41 .mbt files / 4,694 production lines / 2,007 test lines, and no generated interface diff after moon info. The final documentation commits record the later stable refresh.

- [x] **Step 4: Commit final verified interface and documentation corrections**

The second review identified a stale test count in conformance/opa/README.md. The corrected count and this final verification record are committed as the closing documentation milestone. moon info produced no new interface changes.

```powershell
git add conformance/opa/README.md docs/superpowers/plans/2026-10-24-rego-every.md docs/verification.md
git -c user.name=dtzrttp -c user.email=313799694+dtzrttp@users.noreply.github.com commit -m "Record final every verification"
```

Run `git status --short` and `git show --stat --oneline HEAD`; expected: clean worktree and only files for this feature.


- [x] **Step 5: Record stable toolchain refresh and post-upgrade verification**

Committed the updater result, refreshed release-gate outcomes, and updated the
local application and self-review records after the post-upgrade checks.

## Self-review

- Parser grammar, AST span/syntax, compiler safety, evaluator semantics, collection forms, local scope, errors, shared budget, documentation, example, oracle provenance, and all-target verification each map to a task above.
- The parser keyword/token already exists; the plan does not duplicate lexer work.
- A new public AST variant requires exhaustive branches in the compiler and evaluator; Task 2 includes fail-closed evaluator branches before Task 3 replaces them with runtime behavior.
- Binder shadowing and dynamic-domain error behavior are covered by first-party tests, but the OPA v1.21.4 comparison remains pending because the executable is unavailable locally.
- Tests use existing parser, compiler, evaluator, conformance, and CLI entry points. The CLI command order is verified against current `--help` output before documentation is committed.
- The existing CI already installs the stable toolchain, prints its version, and tests the current target matrix; Task 6 adds the `every` CLI smoke cases. The remote run remains pending and is not claimed as verified.
- GitHub is out of scope for this plan; all changes and commits remain local.
