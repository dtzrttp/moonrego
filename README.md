# MoonRego

MoonRego is an original MoonBit implementation of a documented, deliberately
limited Rego v1 subset. It parses, checks, and evaluates JSON policies without
embedding or calling an Open Policy Agent (OPA) service. It does not claim full
OPA compatibility; supported and unsupported language features are listed in
the [compatibility guide](docs/compatibility.md).

## Features

- Source-located lexer, parser, compiler, and evaluation diagnostics.
- Exact finite decimal values and JSON conversion.
- Array comprehensions with scoped iteration and filtering.
- Complete, default, and incremental set rules with bounded evaluation.
- Policy checks, `test_` rules, and JSON or human-readable CLI output.
- A shared core that checks on native, WebAssembly, WebAssembly GC, and
  JavaScript targets; the file-based CLI currently targets native.

## Run an example

```sh
moon run cmd/moonrego --target native -- check examples/authz
moon run cmd/moonrego --target native -- test examples/authz
moon run cmd/moonrego --target native -- eval 'data.authz.allow' \
  -i examples/authz/input-allowed.json --format json examples/authz
```

The first command validates the policy, the second runs its `test_` rules, and
the last evaluates the allowed authorization input. More examples and the
complete local verification commands are in [README.mbt.md](README.mbt.md).

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
