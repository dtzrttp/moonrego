///|
pub async fn run(args : Array[String]) -> Int32 {
  match parse_args(args) {
    Err(message) => {
      println("error: \{message}")
      println(usage())
      2
    }
    Ok(Help) => {
      println(usage())
      0
    }
    Ok(Check(paths, format)) => run_check(paths, format)
    Ok(Eval(query, input_path, data_path, paths, strict, format)) =>
      run_eval(query, input_path, data_path, paths, strict, format)
    Ok(Test(paths, format)) => run_tests(paths, format)
  }
}

///|
async fn run_check(paths : Array[String], format : OutputFormat) -> Int32 {
  match load_policy_bundle(paths) {
    Err(LoadPoliciesError::Io(message)) => {
      println("I/O error: \{message}")
      5
    }
    Err(LoadPoliciesError::Diagnostics(diagnostics)) => {
      println(render_diagnostics(diagnostics, format))
      3
    }
    Ok(bundle) => {
      let count = bundle.modules().length()
      if format is Json {
        println(
          @builtin.Json::object({
            "ok": @builtin.Json::boolean(true),
            "modules": @builtin.Json::number(count.to_double()),
          }).stringify(indent=2),
        )
      } else {
        println("OK: checked \{count} policy module(s)")
      }
      0
    }
  }
}

///|
async fn run_eval(
  query : String,
  input_path : String?,
  data_path : String?,
  paths : Array[String],
  strict : Bool,
  format : OutputFormat,
) -> Int32 {
  let bundle = match load_policy_bundle(paths) {
    Err(LoadPoliciesError::Io(message)) => {
      println("I/O error: \{message}")
      return 5
    }
    Err(LoadPoliciesError::Diagnostics(diagnostics)) => {
      println(render_diagnostics(diagnostics, format))
      return 3
    }
    Ok(bundle) => bundle
  }
  let input = match read_json_value(input_path) {
    Ok(value) => value
    Err(InputError::Io(message)) => {
      println("I/O error: \{message}")
      return 5
    }
    Err(InputError::Json(message)) => {
      println("input error: \{message}")
      return 4
    }
  }
  let data = match read_json_value(data_path) {
    Ok(value) => value
    Err(InputError::Io(message)) => {
      println("I/O error: \{message}")
      return 5
    }
    Err(InputError::Json(message)) => {
      println("data error: \{message}")
      return 4
    }
  }
  let options = @eval.EvalOptions::new(100000).with_strict_builtin_errors(
    strict,
  )
  let result = @eval.eval_program_query(
    bundle.program(),
    query,
    input,
    data,
    options,
  )
  let diagnostics = result.diagnostics()
  if diagnostics.length() > 0 {
    println(render_diagnostics(diagnostics, format))
    return 4
  }
  let values = result.values()
  if format is Json {
    let output = @builtin.Json::object({
      "results": @builtin.Json::array(values.map(fn(value) { value.to_json() })),
      "diagnostics": @builtin.Json::array([]),
    })
    println(output.stringify(indent=2))
  } else {
    println(
      @builtin.Json::array(values.map(fn(value) { value.to_json() })).stringify(
        indent=2,
      ),
    )
  }
  0
}

///|
async fn run_tests(paths : Array[String], format : OutputFormat) -> Int32 {
  let bundle = match load_policy_bundle(paths) {
    Err(LoadPoliciesError::Io(message)) => {
      println("I/O error: \{message}")
      return 5
    }
    Err(LoadPoliciesError::Diagnostics(diagnostics)) => {
      println(render_diagnostics(diagnostics, format))
      return 3
    }
    Ok(bundle) => bundle
  }
  let cases : Array[(String, String)] = []
  for policy_module in bundle.modules() {
    for rule in policy_module.rules() {
      if rule.name().has_prefix("test_") {
        cases.push((policy_module.package_name(), rule.name()))
      }
    }
  }
  if cases.length() == 0 {
    println("no test_ rules found")
    return 1
  }
  let lines : Array[String] = []
  let diagnostics : Array[@diagnostic.Diagnostic] = []
  let mut failed = 0
  for (package_name, rule_name) in cases {
    let name = "\{package_name}.\{rule_name}"
    let result = @eval.eval_program_query(
      bundle.program(),
      "data.\{name}",
      @value.Value::null(),
      @value.Value::null(),
      @eval.EvalOptions::new(100000),
    )
    let case_diagnostics = result.diagnostics()
    if case_diagnostics.length() > 0 {
      lines.push("ERROR \{name}")
      failed += 1
      for diagnostic in case_diagnostics {
        diagnostics.push(diagnostic)
      }
    } else if result.values() is [@value.Value::Bool(true)] {
      lines.push("PASS  \{name}")
    } else {
      lines.push("FAIL  \{name}")
      failed += 1
    }
  }
  if format is Json {
    let json_lines = lines.map(fn(line) { @builtin.Json::string(line) })
    println(
      @builtin.Json::object({
        "passed": @builtin.Json::number((cases.length() - failed).to_double()),
        "failed": @builtin.Json::number(failed.to_double()),
        "cases": @builtin.Json::array(json_lines),
        "diagnostics": diagnostics_json(diagnostics),
      }).stringify(indent=2),
    )
  } else {
    for line in lines {
      println(line)
    }
    println("\{cases.length() - failed} passed; \{failed} failed")
  }
  if diagnostics.length() > 0 {
    println(render_diagnostics(diagnostics, Pretty))
    4
  } else if failed > 0 {
    1
  } else {
    0
  }
}

///|
fn render_diagnostics(
  diagnostics : Array[@diagnostic.Diagnostic],
  format : OutputFormat,
) -> String {
  if format is Json {
    @builtin.Json::object({ "diagnostics": diagnostics_json(diagnostics) }).stringify(
      indent=2,
    )
  } else {
    diagnostics
    .map(fn(diagnostic) {
      let span = diagnostic.primary()
      "\{span.filename()}:\{span.start_line()}:\{span.start_column()}: error[\{diagnostic.code()}]: \{diagnostic.message()}"
    })
    .join("\n")
  }
}

///|
fn diagnostics_json(
  diagnostics : Array[@diagnostic.Diagnostic],
) -> @builtin.Json {
  @builtin.Json::array(
    diagnostics.map(fn(diagnostic) {
      let span = diagnostic.primary()
      @builtin.Json::object({
        "stage": @builtin.Json::string(stage_name(diagnostic.stage())),
        "code": @builtin.Json::string(diagnostic.code()),
        "message": @builtin.Json::string(diagnostic.message()),
        "file": @builtin.Json::string(span.filename()),
        "line": @builtin.Json::number(span.start_line().to_double()),
        "column": @builtin.Json::number(span.start_column().to_double()),
      })
    }),
  )
}

///|
fn stage_name(stage : @diagnostic.Stage) -> String {
  match stage {
    @diagnostic.Stage::Parse => "parse"
    @diagnostic.Stage::Compile => "compile"
    @diagnostic.Stage::Eval => "eval"
    @diagnostic.Stage::Cli => "cli"
  }
}

///|
fn usage() -> String {
  "Usage:\n  moonrego check [--format pretty|json] POLICY...\n  moonrego eval QUERY [-i INPUT.json] [-d DATA.json] [--strict-builtin-errors] [--format pretty|json] POLICY...\n  moonrego test [--format pretty|json] POLICY_OR_DIR...\n  moonrego help"
}
