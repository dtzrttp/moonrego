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
      Some(policy_module) => Environment::for_module(policy_module)
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
      @syntax.RuleKind::OrderedComplete(branches) =>
        for branch in branches {
          let before = complete_values.length()
          let rows = eval_body(branch.body, environment, context)
          for (branch_environment, _) in rows {
            match branch.value {
              Some(expression) =>
                match eval_value(expression, branch_environment, context) {
                  Some(value) => complete_values.push(value)
                  None => ()
                }
              None => complete_values.push(@value.Value::boolean(true))
            }
          }
          if context.diagnostics.length() > 0 {
            return None
          }
          if complete_values.length() > before {
            break
          }
        }
      @syntax.RuleKind::Function(_, _)
      | @syntax.RuleKind::DefaultFunction(_, _) => ()
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
