# Local OPA comparison and verification, 2026-10-31

The official OPA v1.21.4 Windows release executable was downloaded outside the
repository; its SHA-256 matched the release checksum. `opa version` reported
v1.21.4 and `opa capabilities --current` reported 206 built-in entries. This
does not mean MoonReGo implements those entries.

Selected OPA cases are recorded in `../conformance/opa/README.md`. OPA exposed
three differences in `every`: duplicate named binders are rejected, two-variable
set iteration binds both names to the member, and a dynamically resolved
non-collection domain is undefined. MoonReGo tests for these failed before the
fix and pass afterward. OPA and MoonReGo were both run on the set-pair fixture
and both returned true; both rejected the duplicate-binder fixture at compile
time. Static non-collection type checking remains incomplete.

- `moon fmt --check`: passed.
- `moon check --deny-warn --target all`: passed.
- `moon test --deny-warn --target all`: wasm 167/167, wasm-gc 167/167,
  JavaScript 167/167, native 170/170.
- `moon build --deny-warn --target all`: exit 0; native dependency
  `moonbitlang/async` emitted C4005 (`EINVAL` macro redefinition).
- `moon info`: passed; no intended public interface changes in this step.

This is not a complete differential or upstream conformance run; language
features and built-ins remain incomplete as described in `rego-v1-roadmap.md`.
