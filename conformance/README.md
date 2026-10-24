# MoonRego conformance cases

This suite covers the documented v0.1 subset: Rego v1 syntax rejection,
undefined versus null, complete/default rules, `every` over role arrays,
array key/value iteration, incremental sets, conflicts, and strict built-in
errors. The cases are first-party examples based on the language behavior
documented by OPA; no OPA source or test fixture has been copied.

The OPA v1.21.4 release is recorded as the intended semantic oracle, but its
executable is not installed locally and its fixtures have not yet been run.
The tests in this package validate MoonReGo only. The policy references used to
choose behavior and the oracle status are recorded in the root `NOTICE.md` and
`conformance/opa/README.md`.

Run with:

```sh
moon test conformance --deny-warn
```
