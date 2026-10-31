# OPA `every` semantic oracle

These policies and inputs were written for MoonReGo as first-party fixtures. No
OPA implementation code or upstream policy tests were copied. The oracle is
intended to be run with OPA v1.21.4, released 2026-10-23:
[OPA v1.21.4 release](https://github.com/open-policy-agent/opa/releases/tag/v1.21.4).

## Execution status

On 2026-10-31 the official Windows v1.21.4 executable was downloaded outside
the repository and verified against the release SHA-256. `opa version` reported
1.21.4, commit `05c845177c80747a2aabb607f9318f981993cc76-dirty`.
The executable hash was
`efad1c0ee4e3150d213f7babdaff3440b18b93c7368b465fca42cda392947f7c`.
The extracted `capabilities --current` reports 206 built-ins; a complete
item-by-item implementation and differential audit is still pending.

The earlier attempt on 2026-10-24 failed because `opa` was not installed:

```text
The term 'opa' is not recognized as a name of a cmdlet, function, script file,
or executable program.
```

Selected commands below were executed against that executable on 2026-10-31.
The list is retained as a reproducible starting point; it is not a complete
conformance suite.

MoonReGo's own evaluator checks are separate from this OPA run. On 2026-10-24,
`moon test eval --deny-warn --target native` passed 50/50 tests, including the
step-budget boundaries for `every x in [1] { x == 1 }` (8 steps pass, 7 fail)
and `every x in [1, 1] { x == 1 }` (14 steps pass, 13 fail), repeated binder
name behavior, and strict built-in error propagation. These results validate
MoonReGo behavior only; they do not establish conformance with OPA.

## Queries to run

From the repository root:

```powershell
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.array_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.object_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.set_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.object_value_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.empty_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.empty_object_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.empty_set_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.outer_binding'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json --fail 'data.every_oracle.blocked_set_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json --fail 'data.every_oracle.undefined_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-blocked-input.json --fail 'data.every_oracle.array_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-blocked-input.json --fail 'data.every_oracle.object_every'
opa check conformance/opa/not-every.rego
opa check conformance/opa/every-set-pair.rego
opa eval --format pretty --input conformance/opa/every-noncollection-input.json 'every item in input.value { true }'
opa eval --format raw --data conformance/opa/every-duplicate-binder.rego --input conformance/opa/every-duplicate-binder-input.json 'data.every_duplicate_binder.equal_pair'
opa eval --format raw --data conformance/opa/every-duplicate-binder.rego --input conformance/opa/every-duplicate-binder-input.json --fail 'data.every_duplicate_binder.unequal_pair'
opa eval --format raw --data conformance/opa/else.rego --input conformance/opa/else-admin.json 'data.else_oracle.decision'
opa eval --format raw --data conformance/opa/else.rego --input conformance/opa/else-viewer.json 'data.else_oracle.decision'
opa eval --format raw --data conformance/opa/else.rego --input conformance/opa/else-none.json 'data.else_oracle.decision'
opa eval --format raw --data conformance/opa/else.rego --input conformance/opa/else-admin.json 'data.else_oracle.false_stops'
```

## Unverified expectations

### Observed reference results on 2026-10-31

The first eight named positive `every` rules returned `true` (exit 0).
`blocked_set_every` and `undefined_every` produced no raw value (exit 0);
blocked array and object cases with `--fail` exited 1. The `else` decisions
were `primary`, `secondary`, `fallback`, and `false_stops` was `false`.
OPA rejected `not every` at parse time and the duplicate-binder module at
compile time (`var item declared above`). After changing the set-pair fixture
to use both variables, it evaluated to `true` (exit 0). The query
`every x in input.value { x == x }` against the non-collection fixture was
`undefined` (exit 0). A previous query using an unused variable instead failed
compile-time unused-variable checking, so it is not evidence of domain behavior.
MoonReGo fixes for duplicate binders, set-pair bindings and dynamic
non-collection domains are covered by its local regression tests; this list
alone is not a full cross-engine differential suite.

- `array_every`, `object_every`, `set_every`, `object_value_every`, all three
  `empty_*_every` rules, and `outer_binding` should produce `true`.
- The blocked array/object inputs, `blocked_set_every`, and `undefined_every`
  should be undefined; commands using `--fail` should return nonzero.
- Record whether `not every` is rejected by `opa check`, whether two-variable
  iteration over a set is accepted, and the actual non-collection error stage
  and code. Do not infer these details from rolling documentation.
- OPA rejects the same named key/value binder; MoonReGo now reports a compile
  diagnostic for that case.
- The ordered else fixture is expected to return `primary`, `secondary`,
  and `fallback` for the three inputs, and `false` for `false_stops`.
  These values have now been observed in OPA as recorded above.

The [published Rego grammar](https://www.openpolicyagent.org/docs/policy-reference)
defines an `every` body as a `query`, whose first production is a required
`literal`. MoonReGo's parser therefore rejects an empty `every` body. The
separate empty-body OPA v1.21.4 fixture run remains pending.
