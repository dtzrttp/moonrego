///|
test "parses semicolon-separated query body expressions" {
  let parsed = @parser.parse_query_body(
    "some role in input.roles; role == \"admin\"; role",
  )
  assert_eq(parsed.expressions().length(), 3)
  assert_eq(parsed.diagnostics().length(), 0)
}
