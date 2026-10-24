///|
test "lexer recognizes v1 rule punctuation and keywords" {
  let result = lex("allow if { input.role == \"admin\" }", "policy.rego")
  inspect(
    result.kind_labels().join(","),
    content="identifier,if,{,input,.,identifier,==,string,},eof",
  )
  assert_eq(result.diagnostics().length(), 0)
}

///|
test "lexer skips comments and tracks lines" {
  let result = lex("package authz # comment\nallow if true", "policy.rego")
  inspect(
    result.kind_labels().join(","),
    content="package,identifier,identifier,if,true,eof",
  )
  let allow = result.tokens()[2]
  assert_eq(allow.span().start_line(), 2)
  assert_eq(allow.span().start_column(), 1)
}

///|
test "lexer keeps raw string contents" {
  let result = lex("`a\\nb` \"a\\nb\"", "policy.rego")
  let tokens = result.tokens()
  assert_eq(tokens[0].text(), "a\\nb")
  assert_eq(tokens[1].text(), "a\\nb")
  assert_true(tokens[0].kind() is @syntax.TokenKind::RawStringLiteral(_))
  assert_true(tokens[1].kind() is @syntax.TokenKind::StringLiteral(_))
}
