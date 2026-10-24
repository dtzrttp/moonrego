///|
test "rejects a v0 rule body without if" {
  let parsed = @parser.parse_module(
    "package legacy\nallow { input.admin }", "legacy.rego",
  )
  assert_eq(parsed.diagnostics().length(), 1)
  assert_eq(parsed.diagnostics()[0].code(), "rego_v1_rule_if_required")
}
