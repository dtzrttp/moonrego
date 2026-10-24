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
