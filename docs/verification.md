# `every` local verification record

Date: 2026-10-24
Branch: `codex/rego-every`
Scope: local checkout only. No GitHub repository, account, or remote CI was
queried for this feature branch.

## Toolchain

Command: moon version --all

    moon 0.1.20261023 (3778465 2026-10-23)
    moonc v0.10.17+d971670cd (2026-10-23)
    moonrun 0.1.20261023 (3778465 2026-10-23)

On 2026-10-24, moon upgrade --force completed through the default stable
channel and reported “Moonbit installed successfully.” A normal-privilege
attempt failed because Windows denied replacing the current moon.exe. The
interactive retry with the required install permission completed; its
PowerShell Set-ExecutionPolicy call emitted a module-load warning, but the
installer continued. Post-install moon version --all returned the versions
above, so the installed toolchain matches the latest stable release selected
by the official updater at that time. The [official MoonBit update index](https://www.moonbitlang.com/updates) lists
language releases through 0.10.14, which is not directly comparable to this
dated CLI build. No development channel was selected.

A separate moon upgrade --dry-run attempt returned “dry-run is not supported
for upgrade”; the current CLI does not expose a no-write check for this
command.

## Release gate

Commands were run from the repository root in this order:

| Command | Result |
| --- | --- |
| `moon fmt --check` | Passed. |
| `moon check --deny-warn --target all` | Passed. |
| `moon test --deny-warn --target all` | Passed after the edge-case fixes: wasm 130/130, wasm-gc 130/130, JavaScript 130/130, native 133/133. |
| `moon build --deny-warn --target all` | Passed, exit code 0. The first run emitted dependency warning C4005 (EINVAL macro redefinition) from cached moonbitlang/async; the post-upgrade rerun emitted no warning. |
| `moon info` | Passed with no further generated interface diff. The intended public `Expr::Every(String?, String, Expr, Array[Expr], SourceSpan)` line had already been generated and committed as `a0a36c5`. |
| `git diff --check` | Passed. Git printed line-ending conversion notices for edited text files. |
| `moon test conformance --deny-warn --target native` | Passed: 11/11. |
| `moon run cmd/moonrego --target native -- --help` | Passed; usage lists `check`, `eval`, and `test`. |

After adding regressions for empty `every` bodies, the full `Every` source span,
and repeated key/value binder names, `moon test parser --deny-warn --target
native` passed 32/32 and `moon test eval --deny-warn --target native` passed
50/50. `moon test conformance --deny-warn --target native` passed 11/11.

The new parser test first failed because an empty body was accepted; the new
evaluator test first failed because the value binder overwrote the same-named
key binder. Both failures reproduced the reviewed issues. The parser now
rejects empty `every` bodies, and duplicate pair names require equal key/value
bindings before the body runs. The general Rego same-variable rule supports
this interpretation, but the OPA-specific result remains pending.

## Runnable example

After the stable updater completed, both commands were rerun locally with --format json:

```powershell
moon run cmd/moonrego --target native -- eval 'data.access.allow' -i examples/every/input.json --format json examples/every/policy.rego
moon run cmd/moonrego --target native -- eval 'data.access.allow' -i examples/every/input-blocked.json --format json examples/every/policy.rego
```

The allowed fixture returned `"results": [true]`; the blocked fixture returned
`"results": [false]` through `default allow := false`. Both responses had an
empty diagnostics array. The same commands are included in
`.github/workflows/test.yml`, but a remote CI run for this branch is pending.

The existing authz and config CLI smoke commands also passed locally: the
authz policy check passed, its policy tests passed 2/2, the authz labels query
returned the expected object, and `data.config.valid` returned `true` using
`examples/config_check/input-valid.json`. An initial ad hoc invocation used a
nonexistent `examples/config` path and failed; the repository's documented
`examples/config_check` command was then run successfully.

## Independent OPA oracle

OPA v1.21.4 is the intended one-time semantic oracle, based on the official
[v1.21.4 release](https://github.com/open-policy-agent/opa/releases/tag/v1.21.4).
The `opa` executable is not installed locally (`opa version` was not
recognized). An attempt to download the official Windows binary from the
OPA v1.21.4 release into the OS temporary directory failed with proxy
authentication error; no executable was created or run. The oracle fixture
commands in `conformance/opa/README.md` have not been executed. Their listed
outcomes are expected cases, not observations. Binder shadowing, repeated
key/value binder names, two-variable set iteration, and the OPA error code for
non-collection domains remain unverified against OPA.

MoonReGo's own evaluator checks passed 50/50, including exact step budgets of
8/14 passing steps and one-step-short failures, strict built-in error
propagation, undefined domains, collection iteration, nesting, and local scope.
These results establish local behavior only, not OPA compatibility.

## Remote status

No operations on the user's GitHub account or project repository were
performed for `codex/rego-every`. The branch's
remote default branch, uploaded files, commit authors as reported by GitHub,
and remote CI status remain unverified. Earlier remote observations in
`docs/local-self-review.md` describe a prior project state and do not validate
this feature branch.

## Review

A second read-only review of commit d945f80 confirmed the empty-body parser
rejection, full source span, repeated-binder behavior, and README correction.
It found one documentation count left stale at 49/49 after the evaluator
regression was added; conformance/opa/README.md now reports 50/50. No other
concrete behavior or consistency findings remained. The reviewer also confirmed
the OPA v1.21.4 outcome is still pending and is not presented as observed.
