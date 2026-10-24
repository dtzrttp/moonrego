///|
test "unterminated string reports a parse diagnostic and reaches eof" {
  let result = lex("allow if \"unterminated", "broken.rego")
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_parse_error")
  assert_eq(result.kind_labels().last(), Some("eof"))
}

///|
test "unexpected character reports its exact column and continues" {
  let result = lex("allow if @ true", "broken.rego")
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].primary().start_column(), 10)
  inspect(result.kind_labels().join(","), content="identifier,if,true,eof")
}
