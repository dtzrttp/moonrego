# MoonRego

MoonRego is a pure MoonBit implementation of a documented Rego v1 subset.
It is currently under local development for the October 2026 MoonBit
Hackathon.

Implemented so far:

- source spans and structured diagnostics;
- a recovering Rego v1 lexer;
- expression and reference parsing, including arrays, objects, sets, JSON string escapes, and key/value `some-in` binders;
- array, set, and object comprehensions with semicolon-separated bodies and local variable scope;
- package, import, default, complete, and `contains` rule parsing;
- exact finite decimal values backed by arbitrary-precision integers;
- JSON conversion that preserves exact decimal representations;
- compiler checks for unsafe variables, rule shape conflicts, builtin names/arity, and recursion;
- bounded query evaluation with backtracking, array index/value and object key/value iteration, references, exact addition/subtraction/multiplication, and core string/type builtins;
- complete/default/incremental-set rule evaluation with conflict diagnostics;
- a native CLI for policy checking, query evaluation, and `test_` rules, including directory discovery and JSON/pretty output.

This is an explicitly limited Rego v1 subset under active development. Implemented
built-ins include `count`, numeric `sum`/`min`/`max` over arrays and sets,
`array.concat`, `object.get`, `object.keys`, the `is_*` type predicates,
`to_number`, `upper`, `lower`, `contains`, `startswith`, and `endswith`.
Two-variable `some-in` over sets and composite binding patterns are reported as
unsupported. `min` and `max` currently accept numeric collections only. Division,
additional built-ins and deterministic result normalization remain open work. The
`conformance/` package currently contains ten first-party semantic regression
cases. It has not been checked against an installed OPA executable or OPA's
upstream test corpus. The implementation plan under `docs/superpowers/plans/`
tracks the exact status.

## Run the example

The core library checks on native, wasm-gc, wasm, and js. The file based CLI
uses MoonBit's async filesystem package and currently targets native.

```sh
moon run cmd/moonrego --target native -- check examples/authz
moon run cmd/moonrego --target native -- test examples/authz
moon run cmd/moonrego --target native -- eval 'data.authz.allow' \
  -i examples/authz/input-allowed.json --format json examples/authz
moon run cmd/moonrego --target native -- eval 'data.authz.admin_roles' \
  -i examples/authz/input-allowed.json --format json examples/authz
moon run cmd/moonrego --target native -- eval 'data.config.valid' \
  -i examples/config_check/input-valid.json examples/config_check
```

The example policy returns `true` for the allowed input and `false` for
`input-denied.json`; `admin_roles`, `matched_roles`, and `role_labels` demonstrate
array, set, and object comprehensions over configured roles. Object comprehensions
report a conflict for any repeated key, including keys associated with equal
values. The configuration example checks replica count, image, and public
exposure. Invalid built-in arguments are undefined by default;
`--strict-builtin-errors` reports them as evaluation diagnostics.

## Local verification

```text
moon fmt --check
moon check --deny-warn --target all
moon build --deny-warn --target all
moon test --deny-warn --target all
moon test cmd/cli --target native --deny-warn
moon info
```

The CLI also has a native release build. `moon info --target native` inspects
the CLI packages' backend-specific interfaces; the library packages use the
module's canonical `wasm-gc` backend.

The module namespace is `dtzrttp/moonrego`, matching the public repository
owner. Mooncakes publication is pending.

See [the architecture](docs/architecture.md), [the compatibility matrix](docs/compatibility.md),
and [source notices](docs/sources.md).

## License

Apache-2.0. See `LICENSE` and `NOTICE.md`.
