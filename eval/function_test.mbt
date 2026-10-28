///|
test "multiple user function definitions must agree" {
  let parsed = @parser.parse_module(
    (
      #|package p
      #|f(x) := x if { x > 0 }
      #|f(x) := x + 1 if { x > 0 }
      #|result := f(1)
    ),
    "function-conflict.rego",
  )
  assert_eq(parsed.diagnostics().length(), 0)
  let checked = @compile.compile_modules([parsed.policy().unwrap()])
  assert_eq(checked.diagnostics().length(), 0)
  let result = @eval.eval_program_query(
    checked.program().unwrap(),
    "data.p.result",
    @value.Value::null(),
    @value.Value::null(),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 0)
  assert_true(
    result.diagnostics().any(fn(d) { d.code() == "rego_eval_conflict_error" }),
  )
}

///|
test "strict built-in errors inside user functions propagate" {
  let parsed = @parser.parse_module(
    "package p\nf(x) := upper(x)\nresult := f(42)", "function-error.rego",
  )
  assert_eq(parsed.diagnostics().length(), 0)
  let program = @compile.compile_modules([parsed.policy().unwrap()])
    .program()
    .unwrap()
  let result = @eval.eval_program_query(
    program,
    "data.p.result",
    @value.Value::null(),
    @value.Value::null(),
    @eval.EvalOptions::new(1000).with_strict_builtin_errors(true),
  )
  assert_eq(result.values().length(), 0)
  assert_true(
    result.diagnostics().any(fn(d) { d.code() == "rego_eval_builtin_error" }),
  )
}

///|
test "equal user function results from separate definitions do not conflict" {
  let parsed = @parser.parse_module(
    "package p\nf(x) := x\nf(x) := x\nresult := f(7)", "function-equal.rego",
  )
  assert_eq(parsed.diagnostics().length(), 0)
  let program = @compile.compile_modules([parsed.policy().unwrap()])
    .program()
    .unwrap()
  let result = @eval.eval_program_query(
    program,
    "data.p.result",
    @value.Value::null(),
    @value.Value::null(),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  assert_true(
    result.values()[0].equal(
      @value.Value::number(@value.Number::parse("7").unwrap()),
    ),
  )
}

///|
test "user functions share the query step budget" {
  let parsed = @parser.parse_module(
    "package p\nf(x) := x + 1\nresult := f(7)", "function-budget.rego",
  )
  let program = @compile.compile_modules([parsed.policy().unwrap()])
    .program()
    .unwrap()
  let result = @eval.eval_program_query(
    program,
    "data.p.result",
    @value.Value::null(),
    @value.Value::null(),
    @eval.EvalOptions::new(2),
  )
  assert_eq(result.values().length(), 0)
  assert_true(
    result.diagnostics().any(fn(d) { d.code() == "rego_eval_step_limit" }),
  )
}

///|
test "unused imports do not recursively evaluate while calling a function" {
  let function_module = @parser.parse_module(
    "package p\nimport data.p.result as unused\nf(x) := x", "function.rego",
  )
  let caller_module = @parser.parse_module(
    "package p\nresult := f(1)", "caller.rego",
  )
  assert_eq(function_module.diagnostics().length(), 0)
  assert_eq(caller_module.diagnostics().length(), 0)
  let checked = @compile.compile_modules([
    function_module.policy().unwrap(),
    caller_module.policy().unwrap(),
  ])
  assert_eq(checked.diagnostics().length(), 0)
  let result = @eval.eval_program_query(
    checked.program().unwrap(),
    "data.p.result",
    @value.Value::null(),
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  assert_true(
    result.values()[0].equal(
      @value.Value::number(@value.Number::parse("1").unwrap()),
    ),
  )
}

///|
test "function parameter bindings are local to the call" {
  let parsed = @parser.parse_module(
    (
      #|package p
      #|import data.config as x
      #|identity(x) := x
      #|result := identity(2)
    ),
    "function-local-parameter.rego",
  )
  assert_eq(parsed.diagnostics().length(), 0)
  let program = @compile.compile_modules([parsed.policy().unwrap()])
    .program()
    .unwrap()
  let result = @eval.eval_program_query(
    program,
    "data.p.result",
    @value.Value::null(),
    @value.Value::Object({
      "config": @value.Value::number(@value.Number::parse("1").unwrap()),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  assert_true(
    result.values()[0].equal(
      @value.Value::number(@value.Number::parse("2").unwrap()),
    ),
  )
}
