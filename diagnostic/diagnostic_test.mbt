///|
test "error diagnostic preserves stage code and location" {
  let span = @diagnostic.SourceSpan::point("policy.rego", 7, 2, 3)
  let diagnostic = @diagnostic.Diagnostic::error(
    @diagnostic.Stage::Parse,
    "rego_parse_error",
    "unexpected token",
    span,
  )
  assert_eq(diagnostic.code(), "rego_parse_error")
  assert_eq(diagnostic.message(), "unexpected token")
  assert_eq(diagnostic.primary().start_offset(), 7)
  assert_true(diagnostic.stage() == @diagnostic.Stage::Parse)
  assert_true(diagnostic.severity() == @diagnostic.Severity::Error)
}
