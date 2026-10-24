///|
test "missing right operand reports parse error" {
  let parsed = @parser.parse_query("input.count ==")
  assert_eq(parsed.diagnostics().length(), 1)
  assert_eq(parsed.diagnostics()[0].code(), "rego_parse_error")
}

///|
test "trailing token reports parse error" {
  let parsed = @parser.parse_query("true false")
  assert_eq(parsed.diagnostics().length(), 1)
  assert_eq(parsed.diagnostics()[0].message(), "unexpected token after query")
}
