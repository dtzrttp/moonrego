///|
test "multiplication binds more tightly than addition" {
  let parsed = @parser.parse_query("1 + 2 * 3")
  inspect(
    parsed.syntax(),
    content="Binary(Add,Number(1),Binary(Multiply,Number(2),Number(3)))",
  )
  assert_eq(parsed.diagnostics().length(), 0)
}

///|
test "reference preserves static and dynamic path parts" {
  let parsed = @parser.parse_query("input.user.roles[0]")
  inspect(
    parsed.syntax(),
    content="Ref(input,[Field(user),Field(roles),Index(Number(0))])",
  )
}

///|
test "some-in binds a value from a collection" {
  let parsed = @parser.parse_query("some role in input.roles")
  inspect(parsed.syntax(), content="SomeIn(role,Ref(input,[Field(roles)]))")
}

///|
test "some-in parses both key and value binders" {
  let parsed = @parser.parse_query("some index, role in input.roles")
  assert_eq(parsed.diagnostics().length(), 0)
  inspect(
    parsed.syntax(),
    content="SomeInPair(index,role,Ref(input,[Field(roles)]))",
  )
}

///|
test "not is a prefix expression" {
  let parsed = @parser.parse_query("not input.enabled")
  inspect(parsed.syntax(), content="Unary(Not,Ref(input,[Field(enabled)]))")
}

///|
test "parses array literals" {
  let parsed = @parser.parse_query("[1, 2, input.user]")
  inspect(
    parsed.syntax(),
    content="Array([Number(1),Number(2),Ref(input,[Field(user)])])",
  )
  assert_eq(parsed.diagnostics().length(), 0)
}

///|
test "parses array comprehensions with a semicolon-separated body" {
  let parsed = @parser.parse_query(
    "[role | some role in input.roles; role != \"guest\"]",
  )
  inspect(
    parsed.syntax(),
    content="ArrayComprehension(role,[SomeIn(role,Ref(input,[Field(roles)])),Binary(NotEqual,role,String(guest))])",
  )
  assert_eq(parsed.diagnostics().length(), 0)
}

///|
test "parses object literals with string keys" {
  let parsed = @parser.parse_query("{\"role\": input.role, \"active\": true}")
  inspect(
    parsed.syntax(),
    content="Object({role:Ref(input,[Field(role)]),active:Bool(true)})",
  )
  assert_eq(parsed.diagnostics().length(), 0)
}

///|
test "parses set literals" {
  let parsed = @parser.parse_query("{\"admin\", \"editor\"}")
  inspect(parsed.syntax(), content="Set({String(admin),String(editor)})")
  assert_eq(parsed.diagnostics().length(), 0)
}

///|
test "parses the empty set constructor as a set value" {
  let parsed = @parser.parse_query("set()")
  inspect(parsed.syntax(), content="Set({})")
  assert_eq(parsed.diagnostics().length(), 0)
}

///|
test "parses namespaced builtin calls" {
  let array_call = @parser.parse_query("array.concat([1], [2])")
  assert_eq(array_call.diagnostics().length(), 0)
  inspect(
    array_call.syntax(),
    content="Call(array.concat,[Array([Number(1)]),Array([Number(2)])])",
  )
  let object_call = @parser.parse_query("object.get(input, \"name\", \"anon\")")
  assert_eq(object_call.diagnostics().length(), 0)
  inspect(
    object_call.syntax(),
    content="Call(object.get,[input,String(name),String(anon)])",
  )
}

///|
test "parses unqualified builtin calls" {
  let parsed = @parser.parse_query("upper(\"hello\")")
  assert_eq(parsed.diagnostics().length(), 0)
  inspect(parsed.syntax(), content="Call(upper,[String(hello)])")
}

///|
test "decodes JSON string escapes and unicode escapes" {
  let escaped = @parser.parse_query("\"line\\n\\t\\\\end\"")
  assert_true(
    escaped.expression()
    is Some(@syntax.Expr::Term(@syntax.Term::String("line\n\t\\end"), _)),
  )
  let unicode = @parser.parse_query("\"\\u4F60\\u597D\"")
  assert_true(
    unicode.expression()
    is Some(@syntax.Expr::Term(@syntax.Term::String("你好"), _)),
  )
  let astral = @parser.parse_query("\"\\uD83D\\uDE00\"")
  assert_true(
    astral.expression()
    is Some(@syntax.Expr::Term(@syntax.Term::String("😀"), _)),
  )
}

///|
test "rejects invalid JSON string escapes" {
  let parsed = @parser.parse_query("\"bad\\q\"")
  assert_eq(parsed.diagnostics().length(), 1)
  assert_eq(parsed.diagnostics()[0].code(), "rego_parse_error")
}
