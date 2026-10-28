///|
test "parses package default complete and contains rules" {
  let source =
    #|package authz
    #|default allow := false
    #|allow if input.role == "admin"
    #|deny contains "missing owner" if { not input.owner }
  let parsed = @parser.parse_module(source, "authz.rego")
  assert_eq(parsed.diagnostics().length(), 0)
  let policy_module = parsed.policy().unwrap()
  assert_eq(policy_module.package_name(), "authz")
  assert_eq(policy_module.rules().length(), 3)
  inspect(policy_module.rules()[0].shape(), content="default:allow")
  inspect(policy_module.rules()[1].shape(), content="complete:allow")
  inspect(policy_module.rules()[2].shape(), content="contains:deny")
}

///|
test "parses data import alias" {
  let source =
    #|package app
    #|import data.authz.roles as roles
    #|allow if roles[input.user]
  let parsed = @parser.parse_module(source, "app.rego")
  assert_eq(parsed.diagnostics().length(), 0)
  let policy_module = parsed.policy().unwrap()
  assert_eq(policy_module.imports().length(), 1)
  assert_eq(policy_module.imports()[0].path_string(), "data.authz.roles")
  assert_eq(policy_module.imports()[0].alias_name(), Some("roles"))
}

///|
test "ordered rule spans the full else chain" {
  let source =
    #|package p
    #|decision := "first" if { false }
    #|else := "second" if { true }
  let parsed = @parser.parse_module(source, "else.rego")
  assert_eq(parsed.diagnostics().length(), 0)
  let rule = parsed.policy().unwrap().rules()[0]
  assert_eq(rule.span.end_offset(), source.length())
  assert_eq(rule.shape(), "complete:decision")
  match rule.kind() {
    @syntax.RuleKind::OrderedComplete(branches) =>
      assert_eq(branches.length(), 2)
    _ => fail("expected an ordered complete rule")
  }
}

///|
test "rejects else on default and incremental set rules" {
  let default_rule = @parser.parse_module(
    "package p\ndefault allow := false else if { true }", "default-else.rego",
  )
  assert_true(default_rule.diagnostics().length() > 0)
  let set_rule = @parser.parse_module(
    "package p\nroles contains \"admin\" if { true } else if { true }", "set-else.rego",
  )
  assert_true(set_rule.diagnostics().length() > 0)
}

///|
test "rejects empty else body" {
  let parsed = @parser.parse_module(
    "package p\nallow if { true } else if {}", "empty-else.rego",
  )
  assert_true(parsed.diagnostics().length() > 0)
}
