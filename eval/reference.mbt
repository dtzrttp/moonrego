///|
fn eval_reference(
  root : @syntax.Expr,
  parts : Array[@syntax.RefPart],
  environment : Environment,
  context : EvalContext,
) -> @value.Value? {
  if root
    is @syntax.Expr::Term(@syntax.Term::Root(@syntax.RootDocument::Data), _) {
    return resolve_data_reference(parts, environment, context)
  }
  guard eval_value(root, environment, context) is Some(initial) else {
    return None
  }
  apply_reference_parts(initial, parts, 0, environment, context)
}

///|
fn apply_reference_parts(
  initial : @value.Value,
  parts : Array[@syntax.RefPart],
  start : Int32,
  environment : Environment,
  context : EvalContext,
) -> @value.Value? {
  let mut current = initial
  for index in start..<parts.length() {
    match parts[index] {
      @syntax.RefPart::Field(name) => {
        guard current is @value.Value::Object(fields) else { return None }
        guard fields.get(name) is Some(value) else { return None }
        current = value
      }
      @syntax.RefPart::Index(index_expression) => {
        guard eval_value(index_expression, environment, context) is Some(key) else {
          return None
        }
        match (current, key) {
          (@value.Value::Object(fields), @value.Value::String(name)) => {
            guard fields.get(name) is Some(value) else { return None }
            current = value
          }
          (@value.Value::Array(items), @value.Value::Number(number)) => {
            guard number_index(number) is Some(position) else { return None }
            guard items.get(position) is Some(value) else { return None }
            current = value
          }
          _ => return None
        }
      }
    }
  }
  Some(current)
}

///|
fn resolve_data_reference(
  parts : Array[@syntax.RefPart],
  environment : Environment,
  context : EvalContext,
) -> @value.Value? {
  match context.program {
    Some(program) =>
      match find_rule_prefix(program, parts) {
        Some((consumed, package_name, rule_name)) => {
          guard eval_rule(program, package_name, rule_name, context)
            is Some(value) else {
            return None
          }
          apply_reference_parts(value, parts, consumed, environment, context)
        }
        None =>
          apply_reference_parts(context.data, parts, 0, environment, context)
      }
    None => apply_reference_parts(context.data, parts, 0, environment, context)
  }
}

///|
fn find_rule_prefix(
  program : @compile.Program,
  parts : Array[@syntax.RefPart],
) -> (Int32, String, String)? {
  let path : Array[String] = []
  let mut consumed = 0
  let mut found : (Int32, String, String)? = None
  for part in parts {
    match part {
      @syntax.RefPart::Field(name) => {
        path.push(name)
        consumed += 1
        if path.length() >= 2 {
          let rule_name = path[path.length() - 1]
          let package_parts : Array[String] = []
          for i in 0..<(path.length() - 1) {
            package_parts.push(path[i])
          }
          let package_name = package_parts.join(".")
          if program.rules_for(package_name, rule_name).length() > 0 {
            found = Some((consumed, package_name, rule_name))
          }
        }
      }
      @syntax.RefPart::Index(_) => break
    }
  }
  found
}
