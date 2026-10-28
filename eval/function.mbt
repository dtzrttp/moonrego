///|
fn eval_user_function(
  program : @compile.Program,
  package_name : String,
  name : String,
  arguments : Array[@value.Value],
  span : @diagnostic.SourceSpan,
  context : EvalContext,
) -> @value.Value? {
  let results : Array[@value.Value] = []
  let mut fallback : (@syntax.Expr, Environment)? = None
  for rule in program.rules_for(package_name, name) {
    match rule.kind() {
      @syntax.RuleKind::DefaultFunction(parameters, value) =>
        if parameters.length() == arguments.length() {
          let environment = match
            program.module_for_rule(package_name, name, rule.span.filename) {
            Some(policy_module) => Environment::for_module(policy_module)
            None => Environment::for_package(package_name)
          }
          fallback = Some((value, environment))
        }
      @syntax.RuleKind::Function(parameters, head) =>
        if parameters.length() == arguments.length() {
          let mut environment = match
            program.module_for_rule(package_name, name, rule.span.filename) {
            Some(policy_module) => Environment::for_module(policy_module)
            None => Environment::for_package(package_name)
          }
          let mut matched = true
          for index in 0..<parameters.length() {
            if matched {
              match environment.bind(parameters[index], arguments[index]) {
                Some(updated) => environment = updated
                None => matched = false
              }
            }
          }
          if matched {
            let rows = eval_body(rule.body(), environment, context)
            for (row_environment, _) in rows {
              match head {
                Some(expression) =>
                  match eval_value(expression, row_environment, context) {
                    Some(value) => results.push(value)
                    None => ()
                  }
                None => results.push(@value.Value::boolean(true))
              }
            }
          }
        }
      _ => ()
    }
    if context.diagnostics.length() > 0 {
      return None
    }
  }
  if results.length() == 0 {
    match fallback {
      Some((expression, environment)) =>
        eval_value(expression, environment, context)
      None => None
    }
  } else {
    let first = results[0]
    if results.all(fn(value) { value.equal(first) }) {
      Some(first)
    } else {
      context.diagnostics.push(
        @diagnostic.Diagnostic::error(
          @diagnostic.Stage::Eval,
          "rego_eval_conflict_error",
          "function '\{name}' produced conflicting values",
          span,
        ),
      )
      None
    }
  }
}
