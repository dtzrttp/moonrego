///|
fn eval_rule(
  program : @compile.Program,
  package_name : String,
  rule_name : String,
  context : EvalContext,
) -> @value.Value? {
  let definitions = program.rules_for(package_name, rule_name)
  let complete_values : Array[@value.Value] = []
  let set_values : Array[@value.Value] = []
  let mut default_value : @value.Value? = None
  let mut is_incremental_set = false
  for rule in definitions {
    let environment = match
      program.module_for_rule(package_name, rule_name, rule.span.filename) {
      Some(policy_module) => import_environment(policy_module, context)
      None => Environment::empty()
    }
    match rule.kind() {
      @syntax.RuleKind::Default(expression) =>
        default_value = eval_value(expression, environment, context)
      @syntax.RuleKind::Complete(head_value) => {
        let rows = eval_body(rule.body(), environment, context)
        for (environment, _) in rows {
          match head_value {
            Some(expression) =>
              match eval_value(expression, environment, context) {
                Some(value) => complete_values.push(value)
                None => ()
              }
            None => complete_values.push(@value.Value::boolean(true))
          }
        }
      }
      @syntax.RuleKind::IncrementalSet(head_value) => {
        is_incremental_set = true
        let rows = eval_body(rule.body(), environment, context)
        for (environment, _) in rows {
          match eval_value(head_value, environment, context) {
            Some(value) => {
              let inserted = insert_set_value(
                set_values,
                value,
                head_value.span(),
                context,
              )
              if inserted is None {
                return None
              }
            }
            None => ()
          }
        }
      }
    }
    if context.diagnostics.length() > 0 {
      return None
    }
  }
  if is_incremental_set {
    Some(@value.Value::Set(set_values))
  } else if complete_values.length() > 0 {
    let first = complete_values[0]
    if complete_values.all(fn(value) { value.equal(first) }) {
      Some(first)
    } else {
      let span = definitions[0].span
      context.diagnostics.push(
        @diagnostic.Diagnostic::error(
          @diagnostic.Stage::Eval,
          "rego_eval_conflict_error",
          "complete rule '\{package_name}.\{rule_name}' produced conflicting values",
          span,
        ),
      )
      None
    }
  } else {
    default_value
  }
}

///|
fn import_environment(
  policy_module : @syntax.PolicyModule,
  context : EvalContext,
) -> Environment {
  let mut environment = Environment::empty()
  for item in policy_module.imports() {
    let path = item.path()
    if path.length() < 2 || path[0] != "data" {
      continue
    }
    let parts : Array[@syntax.RefPart] = []
    for index in 1..<path.length() {
      parts.push(@syntax.RefPart::Field(path[index]))
    }
    match resolve_data_reference(parts, environment, context) {
      Some(value) => {
        let import_name = match item.alias_name() {
          Some(name) => name
          None => path[path.length() - 1]
        }
        match environment.bind(import_name, value) {
          Some(updated) => environment = updated
          None => ()
        }
      }
      None => ()
    }
  }
  environment
}
