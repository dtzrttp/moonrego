# Notices and sources

MoonRego is an original MoonBit implementation.

Language behavior and terminology are based on the Open Policy Agent Rego
documentation:

- https://www.openpolicyagent.org/docs/policy-language (including `every`)
- https://www.openpolicyagent.org/docs/policy-reference
- https://www.openpolicyagent.org/docs/policy-reference/builtins/aggregates
- https://www.openpolicyagent.org/docs/policy-reference/builtins/array
- https://www.openpolicyagent.org/docs/policy-reference/builtins/object
- https://www.openpolicyagent.org/docs/policy-reference/keywords/some
- https://www.openpolicyagent.org/docs/errors
- https://www.openpolicyagent.org/docs/policy-testing

Open Policy Agent is licensed under Apache-2.0. MoonRego does not embed or call
the OPA binary. The policies and input data in `conformance/opa/` are first-party
semantic oracle cases intended for OPA v1.21.4; they have not been executed
locally. No OPA source files, upstream test fixtures, or third-party policy
samples have been copied into this repository. The links above document the
language behavior used to design the independent implementation.

The MoonBit core BigInt implementation is consumed as a standard toolchain
package and is licensed under Apache-2.0.

The native CLI depends on `moonbitlang/async@0.22.4`, an Apache-2.0 MoonBit
package from <https://github.com/moonbitlang/async>. Its source is resolved as
a package-manager dependency and is not copied into this repository.
