///|
test "complete policy rules evaluate with OR and default fallback" {
  let policy = @parser.parse_module(
      "package authz\ndefault allow := false\nallow if input.role == \"admin\"",
      "authz.rego",
    )
    .policy()
    .unwrap()
  let compiled = @compile.compile_modules([policy])
  let program = compiled.program().unwrap()
  let allowed = @eval.eval_program_query(
    program,
    "data.authz.allow",
    @value.Value::Object({ "role": @value.Value::string("admin") }),
    @value.Value::null(),
    @eval.EvalOptions::new(1000),
  )
  assert_true(allowed.values()[0].equal(@value.Value::boolean(true)))
  let denied = @eval.eval_program_query(
    program,
    "data.authz.allow",
    @value.Value::Object({ "role": @value.Value::string("viewer") }),
    @value.Value::null(),
    @eval.EvalOptions::new(1000),
  )
  assert_true(denied.values()[0].equal(@value.Value::boolean(false)))
}

///|
test "incremental rules collect unique values into a set" {
  let policy = @parser.parse_module(
      "package p\nroles contains \"admin\" if true\nroles contains \"admin\" if true\nroles contains \"editor\" if true",
      "roles.rego",
    )
    .policy()
    .unwrap()
  let program = @compile.compile_modules([policy]).program().unwrap()
  let result = @eval.eval_program_query(
    program,
    "data.p.roles",
    @value.Value::null(),
    @value.Value::null(),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 1)
  assert_eq(result.values()[0].kind_name(), "set")
  assert_eq(result.values()[0].elements().length(), 2)
}

///|
test "incremental set rule deduplication uses the shared step budget" {
  let policy = @parser.parse_module(
      "package p\nroles contains 1 if true\nroles contains 2 if true\nroles contains 3 if true\nroles contains 4 if true",
      "roles-budget.rego",
    )
    .policy()
    .unwrap()
  let program = @compile.compile_modules([policy]).program().unwrap()
  let result = @eval.eval_program_query(
    program,
    "data.p.roles",
    @value.Value::null(),
    @value.Value::null(),
    @eval.EvalOptions::new(14),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_step_limit")
}

///|
test "conflicting complete rule values produce an evaluation error" {
  let policy = @parser.parse_module(
      "package p\nrole := \"admin\"\nrole := \"editor\"", "conflict.rego",
    )
    .policy()
    .unwrap()
  let program = @compile.compile_modules([policy]).program().unwrap()
  let result = @eval.eval_program_query(
    program,
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
test "rule bodies resolve imported data aliases" {
  let policy = @parser.parse_module(
      "package authz\nimport data.users as directory\nallow if directory[0].role == \"admin\"",
      "imported.rego",
    )
    .policy()
    .unwrap()
  let program = @compile.compile_modules([policy]).program().unwrap()
  let result = @eval.eval_program_query(
    program,
    "data.authz.allow",
    @value.Value::null(),
    @value.Value::Object({
      "users": @value.Value::array([
        @value.Value::Object({ "role": @value.Value::string("admin") }),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::boolean(true)))
}
