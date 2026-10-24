# MoonRego conformance cases

This suite covers the documented v0.1 subset: Rego v1 syntax rejection,
undefined versus null, complete/default rules, array key/value iteration,
incremental sets, conflicts, and strict built-in errors. The cases are
first-party examples based on the language behavior documented by OPA; no OPA
source or test fixture has been copied.

The OPA executable is not installed in the local environment, so no oracle
version is claimed and the cases have not yet been differentially checked
against OPA. The policy references used to choose behavior are listed in the
root `NOTICE.md`.

Run with:

```sh
moon test conformance --deny-warn
```
