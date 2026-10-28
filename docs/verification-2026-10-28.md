# Local verification: full-language target, ordered rules and functions

Date: 2026-10-28. Branch: codex/rego-every. The full Rego v1 endpoint in
rego-v1-roadmap.md is a goal and is not complete.

## Local toolchain

moon version --all reported moon 0.1.20261023, moonc
v0.10.17+d971670cd and moonrun 0.1.20261023. The default stable updater was
successfully run on 2026-10-24; freshness was not rechecked on 2026-10-28.

## Commands and results

| Command | Observed result |
| --- | --- |
| moon fmt --check | Passed after formatting changed MoonBit files. |
| moon check --deny-warn --target all | Passed. |
| moon test --deny-warn --target all | Passed: wasm 163/163, wasm-gc 163/163, JS 163/163, native 166/166. |
| moon build --deny-warn --target all | Exit 0. An earlier Windows build emitted dependency warning C4005, EINVAL macro redefinition, from cached moonbitlang/async; the final incremental build did not reproduce it. |
| moon info | Passed; the intended syntax interface adds RuleBranch, OrderedComplete and Function. No unrelated generated interface difference was observed. |
| moon test conformance --deny-warn --target native | 16/16 after adding unconditional else. |
| git diff --cached --check | Passed before each local milestone commit. |

The first ordered-rule regression failed before implementation with parser
diagnostics. The two new object-iteration regressions failed before the fix:
some returned the key instead of the value, and every returned no result.
After fixing the evaluator, both passed. An independent review identified that
an unconditional else value was rejected; its new regression failed before the
parser fix and passed afterward. The review found no other confirmed defect in
the inspected changes.

The initial named-parameter function regression failed during parsing before
implementation. Further regression tests exposed eager evaluation of unused
imports, missed safety checks inside composite literals, and a false recursion
report when function parameters shadow imports. Each was fixed after a failing
test and then passed. The import and parameter-shadowing behavior still requires
independent comparison with OPA.

The MoonRego CLI evaluated conformance/opa/else.rego against the admin, viewer
and none inputs and returned primary, secondary and fallback respectively;
false_stops returned false. These are MoonRego observations, not OPA results.

## Source accounting

On this checkout, git ls-files found 43 tracked MoonBit files: 24 non-test
files with 5,283 physical lines and 19 test files with 2,804 physical lines.
Counts include blank lines and comments. Both _test.mbt and _wbtest.mbt are
classified as tests. Earlier records incorrectly included two white-box test
files among production files; those records are historical, not current counts.

## Remaining verification

OPA is not installed. The first-party OPA oracle policies and their expected
outputs have not been executed against OPA v1.21.4. In particular, else
behavior when a matching body produces an undefined head remains unverified.
The pinned capabilities manifest and applicable official conformance corpus
remain to be acquired and run. User functions remain partial; with, full unification, rule
heads and many built-ins remain incomplete; passing local tests does not prove
full Rego v1 compatibility. No GitHub repository operation or remote CI
verification was performed during this work.
