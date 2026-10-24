# OPA `every` semantic oracle

These policies and inputs were written for MoonReGo as first-party fixtures. No
OPA implementation code or upstream policy tests were copied. The oracle is
intended to be run with OPA v1.21.4, released 2026-10-23:
[OPA v1.21.4 release](https://github.com/open-policy-agent/opa/releases/tag/v1.21.4).

## Execution status

**Not yet executed.** The local `opa` command was not installed on 2026-10-24.
The command `opa version` exited with code 1 and PowerShell reported:

```text
The term 'opa' is not recognized as a name of a cmdlet, function, script file,
or executable program.
```

Install the official v1.21.4 Windows executable into a temporary directory,
verify `opa version` prints `Version: 1.21.4`, then run and record every command
and its stdout, stderr, and exit status below. None of the semantic outcomes
listed here is an OPA observation yet.

MoonReGo's own evaluator checks are separate from this OPA run. On 2026-10-24,
`moon test eval --deny-warn --target native` passed 49/49 tests, including the
step-budget boundaries for `every x in [1] { x == 1 }` (8 steps pass, 7 fail)
and `every x in [1, 1] { x == 1 }` (14 steps pass, 13 fail), plus strict
built-in error propagation. These results validate MoonReGo behavior only;
they do not establish conformance with OPA.

## Queries to run

From the repository root:

```powershell
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.array_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.object_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.set_every'
opa eval --format raw --data conformance/opa/every.rego --input conformance/opa/every-input.json 'data.every_oracle.object_key_every'
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
```

## Unverified expectations

- `array_every`, `object_every`, `set_every`, `object_key_every`, all three
  `empty_*_every` rules, and `outer_binding` should produce `true`.
- The blocked array/object inputs, `blocked_set_every`, and `undefined_every`
  should be undefined; commands using `--fail` should return nonzero.
- Record whether `not every` is rejected by `opa check`, whether two-variable
  iteration over a set is accepted, and the actual non-collection error stage
  and code. Do not infer these details from rolling documentation.
- The same-name key/value binder fixture records whether OPA accepts the
  policy and whether unequal key/value pairs make the universal expression
  undefined. MoonReGo currently treats the repeated name as one variable and
  requires the pair values to be equal; that interpretation is not yet
  confirmed against OPA v1.21.4.

The [published Rego grammar](https://www.openpolicyagent.org/docs/policy-reference)
defines an `every` body as a `query`, whose first production is a required
`literal`. MoonReGo's parser therefore rejects an empty `every` body. The
explicit OPA v1.21.4 fixture run remains pending.
