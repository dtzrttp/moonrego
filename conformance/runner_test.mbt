///|
fn expect_values(
  result : @eval.EvalResult,
  expected : Array[@value.Value],
) -> Unit raise {
  assert_eq(result.diagnostics().length(), 0)
  let actual = result.values()
  assert_eq(actual.length(), expected.length())
  for index in 0..<expected.length() {
    assert_true(actual[index].equal(expected[index]))
  }
}

///|
fn eval_policy_case(
  source : String,
  query : String,
  input : @value.Value,
) -> @eval.EvalResult raise {
  let parsed = @parser.parse_module(source, "conformance.rego")
  assert_eq(parsed.diagnostics().length(), 0)
  let policy = parsed.policy().unwrap()
  let checked = @compile.compile_modules([policy])
  assert_eq(checked.diagnostics().length(), 0)
  @eval.eval_program_query(
    checked.program().unwrap(),
    query,
    input,
    @value.Value::null(),
    @eval.EvalOptions::new(1000),
  )
}

///|
test "v1 parser rejects a v0 rule body" {
  let parsed = @parser.parse_module(
    "package legacy\nallow { input.admin }", "legacy.rego",
  )
  assert_eq(parsed.diagnostics().length(), 1)
  assert_eq(parsed.diagnostics()[0].code(), "rego_v1_rule_if_required")
}

///|
test "undefined and explicit null remain distinguishable" {
  let input : @value.Value = @value.Value::Object({
    "present": @value.Value::null(),
  })
  let present = @eval.eval_query(
    "input.present",
    input,
    @eval.EvalOptions::new(100),
  )
  expect_values(present, [@value.Value::null()])
  let absent = @eval.eval_query(
    "input.missing",
    input,
    @eval.EvalOptions::new(100),
  )
  expect_values(absent, [])
}

///|
test "default and complete rules preserve Rego fallback behavior" {
  let source =
    #|package authz
    #|default allow := false
    #|allow if input.role == "admin"
  let allowed = eval_policy_case(
    source,
    "data.authz.allow",
    @value.Value::Object({ "role": @value.Value::string("admin") }),
  )
  expect_values(allowed, [@value.Value::boolean(true)])
  let denied = eval_policy_case(
    source,
    "data.authz.allow",
    @value.Value::Object({ "role": @value.Value::string("viewer") }),
  )
  expect_values(denied, [@value.Value::boolean(false)])
}

///|
test "every policy checks all array members in rule definitions" {
  let source =
    #|package p
    #|allow if {
    #|  every role in input.roles {
    #|    role != "blocked"
    #|  }
    #|}
  let allowed = eval_policy_case(
    source,
    "data.p.allow",
    @value.Value::Object({
      "roles": @value.Value::array([
        @value.Value::string("admin"),
        @value.Value::string("viewer"),
      ]),
    }),
  )
  expect_values(allowed, [@value.Value::boolean(true)])
  let denied = eval_policy_case(
    source,
    "data.p.allow",
    @value.Value::Object({
      "roles": @value.Value::array([
        @value.Value::string("admin"),
        @value.Value::string("blocked"),
      ]),
    }),
  )
  expect_values(denied, [])
}

///|
test "array key-value iteration binds the index and value" {
  let input : @value.Value = @value.Value::Object({
    "roles": @value.Value::array([
      @value.Value::string("viewer"),
      @value.Value::string("admin"),
    ]),
  })
  let result = @eval.eval_query(
    "some index, role in input.roles; role == \"admin\"; index",
    input,
    @eval.EvalOptions::new(1000),
  )
  expect_values(result, [
    @value.Value::number(@value.Number::parse("1").unwrap()),
  ])
}

///|
test "array comprehensions filter values in rule definitions" {
  let source =
    #|package p
    #|filtered := [role | some role in input.roles; role != "guest"]
  let result = eval_policy_case(
    source,
    "data.p.filtered",
    @value.Value::Object({
      "roles": @value.Value::array([
        @value.Value::string("guest"),
        @value.Value::string("admin"),
      ]),
    }),
  )
  expect_values(result, [@value.Value::array([@value.Value::string("admin")])])
}

///|
test "set comprehensions return distinct values in rule definitions" {
  let source =
    #|package p
    #|roles := {role | some role in input.roles; role != "guest"}
  let result = eval_policy_case(
    source,
    "data.p.roles",
    @value.Value::Object({
      "roles": @value.Value::array([
        @value.Value::string("guest"),
        @value.Value::string("admin"),
        @value.Value::string("admin"),
      ]),
    }),
  )
  expect_values(result, [@value.Value::set([@value.Value::string("admin")])])
}

///|
test "object comprehensions build role lookup objects in rules" {
  let source =
    #|package p
    #|role_labels := {role: upper(role) | some role in input.roles}
  let result = eval_policy_case(
    source,
    "data.p.role_labels",
    @value.Value::Object({
      "roles": @value.Value::array([
        @value.Value::string("admin"),
        @value.Value::string("editor"),
      ]),
    }),
  )
  expect_values(result, [
    @value.Value::Object({
      "admin": @value.Value::string("ADMIN"),
      "editor": @value.Value::string("EDITOR"),
    }),
  ])
}

///|
test "contains rules collect unique values" {
  let source =
    #|package p
    #|roles contains "admin" if true
    #|roles contains "admin" if true
    #|roles contains "editor" if true
  let result = eval_policy_case(source, "data.p.roles", @value.Value::null())
  assert_eq(result.values().length(), 1)
  match result.values()[0] {
    @value.Value::Set(items) => {
      assert_eq(items.length(), 2)
      assert_true(
        items.any(fn(item) { item.equal(@value.Value::string("admin")) }),
      )
      assert_true(
        items.any(fn(item) { item.equal(@value.Value::string("editor")) }),
      )
    }
    _ => fail("expected a set result")
  }
}

///|
test "complete rule conflicts are reported" {
  let parsed = @parser.parse_module(
    "package p\nrole := \"admin\"\nrole := \"editor\"", "conflict.rego",
  )
  let checked = @compile.compile_modules([parsed.policy().unwrap()])
  let result = @eval.eval_program_query(
    checked.program().unwrap(),
    "data.p.role",
    @value.Value::null(),
    @value.Value::null(),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_conflict_error")
}

///|
test "strict builtin mode converts invalid arguments to diagnostics" {
  let result = @eval.eval_query(
    "upper(42)",
    @value.Value::null(),
    @eval.EvalOptions::new(100).with_strict_builtin_errors(true),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_builtin_error")
}
