///|
test "some-in backtracks over matching input values" {
  let input : @value.Value = @value.Value::Object({
    "roles": @value.Value::array([
      @value.Value::string("viewer"),
      @value.Value::string("admin"),
      @value.Value::string("admin"),
    ]),
  })
  let result = @eval.eval_query(
    "some role in input.roles; role == \"admin\"; role",
    input,
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 2)
  assert_true(
    result
    .values()
    .all(fn(value) { value.equal(@value.Value::string("admin")) }),
  )
  assert_eq(result.diagnostics().length(), 0)
}

///|
test "some-in pair binds an array index and value" {
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
  assert_eq(result.values().length(), 1)
  assert_true(
    result.values()[0].equal(
      @value.Value::number(@value.Number::parse("1").unwrap()),
    ),
  )
  assert_eq(result.diagnostics().length(), 0)
}

///|
test "some-in pair binds an object key and value" {
  let input : @value.Value = @value.Value::Object({
    "roles": @value.Value::Object({
      "primary": @value.Value::string("admin"),
      "secondary": @value.Value::string("viewer"),
    }),
  })
  let result = @eval.eval_query(
    "some name, role in input.roles; role == \"admin\"; name",
    input,
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::string("primary")))
  assert_eq(result.diagnostics().length(), 0)
}

///|
test "some-in pair reports unsupported set key-value iteration" {
  let result = @eval.eval_query(
    "some key, value in input.roles",
    @value.Value::Object({
      "roles": @value.Value::set([@value.Value::string("admin")]),
    }),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_unsupported_feature")
}

///|
test "false predicates produce no query results" {
  let result = @eval.eval_query(
    "input.enabled == true",
    @value.Value::Object({ "enabled": @value.Value::boolean(false) }),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.values().length(), 0)
}

///|
test "builtin type errors are undefined unless strict mode is enabled" {
  let ordinary = @eval.eval_query(
    "upper(42)",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  assert_eq(ordinary.values().length(), 0)
  assert_eq(ordinary.diagnostics().length(), 0)
  let strict = @eval.eval_query(
    "upper(42)",
    @value.Value::null(),
    @eval.EvalOptions::new(100).with_strict_builtin_errors(true),
  )
  assert_eq(strict.values().length(), 0)
  assert_eq(strict.diagnostics().length(), 1)
  assert_eq(strict.diagnostics()[0].code(), "rego_eval_builtin_error")
}

///|
test "array.concat preserves the input array order" {
  let result = @eval.eval_query(
    "array.concat([1, 2], [3])",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_true(
    result
    .values()
    .any(fn(value) {
      value.equal(
        @value.Value::array([
          @value.Value::number(@value.Number::parse("1").unwrap()),
          @value.Value::number(@value.Number::parse("2").unwrap()),
          @value.Value::number(@value.Number::parse("3").unwrap()),
        ]),
      )
    }),
  )
}

///|
test "object.get returns present values and defaults for missing paths" {
  let input : @value.Value = @value.Value::Object({
    "name": @value.Value::string("Ada"),
    "profile": @value.Value::Object({ "nickname": @value.Value::null() }),
    "servers": @value.Value::array([
      @value.Value::Object({ "name": @value.Value::string("api") }),
    ]),
    "settings": @value.Value::Object({ "theme": @value.Value::string("dark") }),
  })
  let present = @eval.eval_query(
    "object.get(input, \"name\", \"anon\")",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(present.diagnostics().length(), 0)
  assert_true(
    present.values().any(fn(value) { value.equal(@value.Value::string("Ada")) }),
  )
  let nested = @eval.eval_query(
    "object.get(input, [\"settings\", \"theme\"], \"light\")",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(nested.diagnostics().length(), 0)
  assert_true(
    nested.values().any(fn(value) { value.equal(@value.Value::string("dark")) }),
  )
  let missing = @eval.eval_query(
    "object.get(input, [\"settings\", \"missing\"], \"light\")",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(missing.diagnostics().length(), 0)
  assert_true(
    missing
    .values()
    .any(fn(value) { value.equal(@value.Value::string("light")) }),
  )
  let array_path = @eval.eval_query(
    "object.get(input, [\"servers\", 0, \"name\"], \"missing\")",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(array_path.diagnostics().length(), 0)
  assert_true(
    array_path
    .values()
    .any(fn(value) { value.equal(@value.Value::string("api")) }),
  )
  let explicit_null = @eval.eval_query(
    "object.get(input, [\"profile\", \"nickname\"], \"fallback\")",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(explicit_null.diagnostics().length(), 0)
  assert_true(
    explicit_null.values().any(fn(value) { value.equal(@value.Value::null()) }),
  )
}

///|
test "object.keys returns a set of object keys" {
  let result = @eval.eval_query(
    "object.keys(input)",
    @value.Value::Object({
      "alpha": @value.Value::number(@value.Number::parse("1").unwrap()),
      "beta": @value.Value::boolean(true),
    }),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_true(
    result
    .values()
    .any(fn(value) {
      value.equal(
        @value.Value::set([
          @value.Value::string("alpha"),
          @value.Value::string("beta"),
        ]),
      )
    }),
  )
}

///|
test "sum uses exact decimal arithmetic for arrays and sets" {
  let array_sum = @eval.eval_query(
    "sum([0.1, 0.2, 0.3])",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  let expected = @value.Value::number(@value.Number::parse("0.6").unwrap())
  assert_eq(array_sum.diagnostics().length(), 0)
  assert_true(array_sum.values().any(fn(value) { value.equal(expected) }))
  let set_sum = @eval.eval_query(
    "sum({1, 2, 3})",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  assert_eq(set_sum.diagnostics().length(), 0)
  assert_true(
    set_sum
    .values()
    .any(fn(value) {
      value.equal(@value.Value::number(@value.Number::parse("6").unwrap()))
    }),
  )
}

///|
test "min and max find exact numeric bounds" {
  let minimum = @eval.eval_query(
    "min([3, 0.1, 2])",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  let maximum = @eval.eval_query(
    "max([3, 0.1, 2])",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  assert_eq(minimum.diagnostics().length(), 0)
  assert_eq(maximum.diagnostics().length(), 0)
  assert_true(
    minimum
    .values()
    .any(fn(value) {
      value.equal(@value.Value::number(@value.Number::parse("0.1").unwrap()))
    }),
  )
  assert_true(
    maximum
    .values()
    .any(fn(value) {
      value.equal(@value.Value::number(@value.Number::parse("3").unwrap()))
    }),
  )
}

///|
test "resolves array references and uses exact decimal arithmetic" {
  let input : @value.Value = @value.Value::Object({
    "prices": @value.Value::array([
      @value.Value::number(@value.Number::parse("0.2").unwrap()),
    ]),
  })
  let result = @eval.eval_query(
    "input.prices[0] + 0.1 == 0.3",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::boolean(true)))
}

///|
test "not succeeds when its expression is false" {
  let result = @eval.eval_query(
    "not input.enabled",
    @value.Value::Object({ "enabled": @value.Value::boolean(false) }),
    @eval.EvalOptions::new(100),
  )
  assert_true(result.values()[0].equal(@value.Value::boolean(true)))
}

///|
test "step budget exhaustion returns a structured error" {
  let result = @eval.eval_query(
    "input.enabled",
    @value.Value::Object({ "enabled": @value.Value::boolean(true) }),
    @eval.EvalOptions::new(0),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_step_limit")
}

///|
test "undefined references remain distinct from JSON null" {
  let input : @value.Value = @value.Value::Object({
    "present": @value.Value::null(),
  })
  let present = @eval.eval_query(
    "input.present",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(present.values().length(), 1)
  assert_eq(present.values()[0].kind_name(), "null")
  let missing = @eval.eval_query(
    "input.missing",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(missing.values().length(), 0)
}

///|
test "final query expression can return the boolean false value" {
  let result = @eval.eval_query(
    "input.enabled",
    @value.Value::Object({ "enabled": @value.Value::boolean(false) }),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::boolean(false)))
}
