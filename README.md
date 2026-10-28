# MoonRego

MoonRego aims to implement complete Rego v1 language semantics in MoonBit,
using a pinned Open Policy Agent (OPA) version as its compatibility reference.
The implementation is currently incomplete: it parses, checks, and evaluates
a documented subset without embedding or calling an OPA service. The
[compatibility guide](docs/compatibility.md) lists current support, and the
[full-language roadmap](docs/rego-v1-roadmap.md) defines remaining work and
evidence required before claiming full compatibility.

## Features

- Source-located lexer, parser, compiler, and evaluation diagnostics.
- Exact finite decimal values and JSON conversion.
- Array, set, and object comprehensions with scoped iteration and filtering.
- Universal `every` iteration over arrays, objects, and sets, with scoped binders.
- Complete, default, and incremental set rules with bounded evaluation.
- Ordered complete-rule `else` chains with conditional and unconditional value branches.
- Policy checks, `test_` rules, and JSON or human-readable CLI output.
- A shared core that checks on native, WebAssembly, WebAssembly GC, and
  JavaScript targets; the file-based CLI currently targets native.

## Run an example

```sh
moon run cmd/moonrego --target native -- check examples/authz
moon run cmd/moonrego --target native -- test examples/authz
moon run cmd/moonrego --target native -- eval 'data.authz.allow' \
  -i examples/authz/input-allowed.json --format json examples/authz
moon run cmd/moonrego --target native -- eval 'data.access.allow' \
  -i examples/every/input.json --format json examples/every/policy.rego
moon run cmd/moonrego --target native -- eval 'data.access.allow' \
  -i examples/every/input-blocked.json --format json examples/every/policy.rego
```

The first two commands validate the authorization policy and run its `test_`
rules; the third evaluates the allowed authorization input. The final two
commands evaluate the allowed and blocked `every` inputs. The policy also exposes
`data.authz.matched_roles` as a set and `data.authz.role_labels` as an object,
both built by comprehensions over the input roles. More examples and the
complete local verification commands are in [README.mbt.md](README.mbt.md).

The `every` example checks each role and each principal's key and roles. The
allowed input returns `{"results":[true]}`; the blocked input returns
`{"results":[false]}` through the policy's default rule. Empty arrays,
objects, and sets satisfy their `every` expression vacuously.

## Development

```sh
moon fmt --check
moon check --deny-warn --target all
moon build --deny-warn --target all
moon test --deny-warn --target all
moon info
```

See the [architecture](docs/architecture.md),
[compatibility matrix](docs/compatibility.md),
[source notices](docs/sources.md).

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).

The module namespace is `dtzrttp/moonrego`; Mooncakes publication is pending.
