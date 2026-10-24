# Sources and third-party material

MoonRego is an original MoonBit implementation. The following Open Policy Agent
documents were used to understand language behavior and choose examples:

- [Policy Language](https://www.openpolicyagent.org/docs/policy-language)
- [Policy Reference](https://www.openpolicyagent.org/docs/policy-reference)
- [`every` keyword and universal quantification](https://www.openpolicyagent.org/docs/policy-language)
- [Aggregate builtins](https://www.openpolicyagent.org/docs/policy-reference/builtins/aggregates)
- [Array builtins](https://www.openpolicyagent.org/docs/policy-reference/builtins/array)
- [Object builtins](https://www.openpolicyagent.org/docs/policy-reference/builtins/object)
- [The `some` keyword](https://www.openpolicyagent.org/docs/policy-reference/keywords/some)
- [Errors](https://www.openpolicyagent.org/docs/errors)
- [`eval_conflict_error`: object keys must be unique](https://www.openpolicyagent.org/docs/errors/eval-conflict-error/object-keys-must-be-unique)
- [Policy testing](https://www.openpolicyagent.org/docs/policy-testing)

No OPA source code, upstream test cases, or third-party policy samples are
included. The eleven conformance cases and the policies and input data under
`conformance/opa/` are first-party examples based on documented semantics. The
OPA v1.21.4 release is the intended one-time semantic oracle; its executable is
not installed locally and the oracle cases have not been run. The
authorization/configuration policies and JSON inputs under `examples/` are
original project content.

## Runtime dependencies

- `moonbitlang/core` supplies the standard library and arbitrary-precision
  `BigInt`; it is distributed under Apache-2.0 with MoonBit.
- `moonbitlang/async@0.22.4` supplies filesystem operations used only by the
  native CLI. It is Apache-2.0 and is resolved as a package dependency rather
  than copied into this repository.

The project license is Apache-2.0. Full notices are in the root `NOTICE.md` and
`LICENSE` files. Apache-2.0 is listed in the
[OSI Approved Licenses](https://opensource.org/license?ls=Apache-2.0) catalog.
