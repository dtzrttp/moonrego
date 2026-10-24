///|
/// Evaluate a query against input with null as the data document.
pub fn eval_query(
  query : String,
  input : @value.Value,
  options : EvalOptions,
) -> EvalResult {
  eval_query_with_data(query, input, @value.Value::null(), options)
}

///|
/// Evaluate a query against explicit input and data documents.
pub fn eval_query_with_data(
  query : String,
  input : @value.Value,
  data : @value.Value,
  options : EvalOptions,
) -> EvalResult {
  run_query(None, query, input, data, options)
}

///|
/// Evaluate a query against a checked policy program and data document.
pub fn eval_program_query(
  program : @compile.Program,
  query : String,
  input : @value.Value,
  data : @value.Value,
  options : EvalOptions,
) -> EvalResult {
  run_query(Some(program), query, input, data, options)
}

///|
fn run_query(
  program : @compile.Program?,
  query : String,
  input : @value.Value,
  data : @value.Value,
  options : EvalOptions,
) -> EvalResult {
  let parsed = @parser.parse_query_body(query)
  let diagnostics = parsed.diagnostics()
  if diagnostics.length() > 0 {
    return { values: [], diagnostics, }
  }
  let context : EvalContext = {
    input,
    data,
    program,
    remaining: options.max_steps,
    strict_builtin_errors: options.strict_builtin_errors,
    diagnostics,
  }
  let active_rows = eval_query_expressions(
    parsed.expressions(),
    Environment::empty(),
    context,
  )
  let values = active_rows.map(fn(row) {
    let (_, value) = row
    value
  })
  { values, diagnostics: context.diagnostics, }
}

///|
fn eval_query_expressions(
  expressions : Array[@syntax.Expr],
  initial : Environment,
  context : EvalContext,
) -> Array[(Environment, @value.Value)] {
  if expressions.length() == 0 {
    return []
  }
  let mut rows : Array[(Environment, @value.Value)] = [
    (initial, @value.Value::boolean(true)),
  ]
  for index in 0..<expressions.length() {
    let final_expression = index == expressions.length() - 1
    let next : Array[(Environment, @value.Value)] = []
    for (environment, _) in rows {
      for
        result in eval_step(
          expressions[index],
          environment,
          context,
          final_expression,
        ) {
        next.push(result)
      }
    }
    rows = next
    if context.diagnostics.length() > 0 {
      break
    }
  }
  rows
}

///|
fn eval_body(
  expressions : Array[@syntax.Expr],
  initial : Environment,
  context : EvalContext,
) -> Array[(Environment, @value.Value)] {
  let mut rows : Array[(Environment, @value.Value)] = [
    (initial, @value.Value::boolean(true)),
  ]
  for expression in expressions {
    let next : Array[(Environment, @value.Value)] = []
    for (environment, _) in rows {
      for result in eval_step(expression, environment, context, false) {
        next.push(result)
      }
    }
    rows = next
    if context.diagnostics.length() > 0 {
      break
    }
  }
  rows
}

///|
fn eval_step(
  expression : @syntax.Expr,
  environment : Environment,
  context : EvalContext,
  final_query_expression : Bool,
) -> Array[(Environment, @value.Value)] {
  if !context.charge(expression.span()) {
    return []
  }
  match expression {
    @syntax.Expr::Binary(@syntax.BinaryOp::Assign, left, right, _) => {
      guard eval_value(right, environment, context) is Some(value) else {
        return []
      }
      match left {
        @syntax.Expr::Term(@syntax.Term::Variable(name), _) =>
          match environment.bind(name, value) {
            Some(updated) => [(updated, value)]
            None => []
          }
        _ =>
          match eval_value(left, environment, context) {
            Some(previous) if previous.equal(value) => [(environment, value)]
            _ => []
          }
      }
    }
    @syntax.Expr::SomeIn(name, collection, span) => {
      guard eval_value(collection, environment, context) is Some(value) else {
        return []
      }
      let results : Array[(Environment, @value.Value)] = []
      match value {
        @value.Value::Array(items) | @value.Value::Set(items) =>
          for item in items {
            if !context.charge(span) {
              return []
            }
            match environment.bind(name, item) {
              Some(updated) => results.push((updated, item))
              None => ()
            }
          }
        @value.Value::Object(fields) =>
          for (key, _) in fields {
            if !context.charge(span) {
              return []
            }
            let item = @value.Value::string(key)
            match environment.bind(name, item) {
              Some(updated) => results.push((updated, item))
              None => ()
            }
          }
        _ => ()
      }
      results
    }
    @syntax.Expr::SomeInPair(key_name, value_name, collection, span) => {
      guard eval_value(collection, environment, context) is Some(value) else {
        return []
      }
      let results : Array[(Environment, @value.Value)] = []
      match value {
        @value.Value::Array(items) =>
          for index in 0..<items.length() {
            if !context.charge(span) {
              return []
            }
            match int_value(index) {
              Some(key) =>
                match environment.bind(key_name, key) {
                  Some(key_environment) =>
                    match key_environment.bind(value_name, items[index]) {
                      Some(updated) => results.push((updated, items[index]))
                      None => ()
                    }
                  None => ()
                }
              None => ()
            }
          }
        @value.Value::Object(fields) =>
          for (key, item) in fields {
            if !context.charge(span) {
              return []
            }
            let key_value = @value.Value::string(key)
            match environment.bind(key_name, key_value) {
              Some(key_environment) =>
                match key_environment.bind(value_name, item) {
                  Some(updated) => results.push((updated, item))
                  None => ()
                }
              None => ()
            }
          }
        @value.Value::Set(_) =>
          context.diagnostics.push(
            @diagnostic.Diagnostic::error(
              @diagnostic.Stage::Eval,
              "rego_unsupported_feature",
              "two-variable some-in over sets is outside the supported subset",
              span,
            ),
          )
        _ => ()
      }
      results
    }
    @syntax.Expr::Every(key_name, value_name, domain, body, span) =>
      eval_every(key_name, value_name, domain, body, span, environment, context)
    @syntax.Expr::Unary(@syntax.UnaryOp::Not, inner, _) => {
      let results = eval_step(inner, environment, context, false)
      if context.diagnostics.length() > 0 || results.length() > 0 {
        []
      } else {
        [(environment, @value.Value::boolean(true))]
      }
    }
    _ =>
      match eval_value(expression, environment, context) {
        Some(@value.Value::Bool(false)) =>
          if !final_query_expression || is_boolean_predicate(expression) {
            []
          } else {
            [(environment, @value.Value::boolean(false))]
          }
        Some(value) => [(environment, value)]
        None => []
      }
  }
}

///|
fn eval_every(
  key_name : String?,
  value_name : String,
  domain : @syntax.Expr,
  body : Array[@syntax.Expr],
  span : @diagnostic.SourceSpan,
  environment : Environment,
  context : EvalContext,
) -> Array[(Environment, @value.Value)] {
  guard eval_value(domain, environment, context) is Some(domain_value) else {
    return []
  }
  let mut passes = true
  match domain_value {
    @value.Value::Array(items) =>
      for index in 0..<items.length() {
        if passes {
          match int_value(index) {
            Some(key) =>
              passes = eval_every_item(
                key_name,
                value_name,
                Some(key),
                items[index],
                body,
                span,
                environment,
                context,
              )
            None => passes = false
          }
          if context.diagnostics.length() > 0 {
            return []
          }
        }
      }
    @value.Value::Object(fields) =>
      for (key, item) in fields {
        if passes {
          let value = match key_name {
            Some(_) => item
            None => @value.Value::string(key)
          }
          passes = eval_every_item(
            key_name,
            value_name,
            Some(@value.Value::string(key)),
            value,
            body,
            span,
            environment,
            context,
          )
          if context.diagnostics.length() > 0 {
            return []
          }
        }
      }
    @value.Value::Set(items) =>
      match key_name {
        Some(_) => {
          context.diagnostics.push(
            @diagnostic.Diagnostic::error(
              @diagnostic.Stage::Eval,
              "rego_unsupported_feature",
              "two-variable every over sets is outside the supported subset",
              span,
            ),
          )
          return []
        }
        None =>
          for item in items {
            if passes {
              passes = eval_every_item(
                None,
                value_name,
                None,
                item,
                body,
                span,
                environment,
                context,
              )
              if context.diagnostics.length() > 0 {
                return []
              }
            }
          }
      }
    _ => {
      context.diagnostics.push(
        @diagnostic.Diagnostic::error(
          @diagnostic.Stage::Eval,
          "rego_type_error",
          "every domain must be an array, object, or set",
          domain.span(),
        ),
      )
      return []
    }
  }
  if passes {
    [(environment, @value.Value::boolean(true))]
  } else {
    []
  }
}

///|
fn eval_every_item(
  key_name : String?,
  value_name : String,
  key_value : @value.Value?,
  item : @value.Value,
  body : Array[@syntax.Expr],
  span : @diagnostic.SourceSpan,
  environment : Environment,
  context : EvalContext,
) -> Bool {
  if !context.charge(span) {
    return false
  }
  let local_environment = match (key_name, key_value) {
    (Some(name), Some(key)) => environment.bind_local(name, key)
    _ => environment
  }
  let local_environment = local_environment.bind_local(value_name, item)
  let rows = eval_body(body, local_environment, context)
  rows.length() > 0
}

///|
fn is_boolean_predicate(expression : @syntax.Expr) -> Bool {
  match expression {
    @syntax.Expr::Binary(operator, _, _, _) =>
      operator
      is (@syntax.BinaryOp::Equal
      | @syntax.BinaryOp::NotEqual
      | @syntax.BinaryOp::Less
      | @syntax.BinaryOp::LessEqual
      | @syntax.BinaryOp::Greater
      | @syntax.BinaryOp::GreaterEqual
      | @syntax.BinaryOp::In)
    @syntax.Expr::Call(name, _, _) =>
      name
      is ("contains"
      | "startswith"
      | "endswith"
      | "is_number"
      | "is_string"
      | "is_boolean"
      | "is_array"
      | "is_object"
      | "is_set"
      | "is_null")
    _ => false
  }
}

///|
fn eval_value(
  expression : @syntax.Expr,
  environment : Environment,
  context : EvalContext,
) -> @value.Value? {
  if !context.charge(expression.span()) {
    return None
  }
  match expression {
    @syntax.Expr::Term(term, span) =>
      eval_term(term, span, environment, context)
    @syntax.Expr::Ref(root, parts, _) =>
      eval_reference(root, parts, environment, context)
    @syntax.Expr::Unary(@syntax.UnaryOp::Negate, inner, _) => {
      guard eval_value(inner, environment, context) is Some(value) else {
        return None
      }
      match value {
        @value.Value::Number(number) =>
          Some(@value.Value::Number(number.negate()))
        _ => None
      }
    }
    @syntax.Expr::Unary(@syntax.UnaryOp::Not, _, _) => None
    @syntax.Expr::Binary(@syntax.BinaryOp::Assign, _, _, _) => None
    @syntax.Expr::Binary(operator, left, right, _) => {
      guard eval_value(left, environment, context) is Some(left_value) else {
        return None
      }
      guard eval_value(right, environment, context) is Some(right_value) else {
        return None
      }
      eval_binary(operator, left_value, right_value)
    }
    @syntax.Expr::Call(name, arguments, span) => {
      let values : Array[@value.Value] = []
      for argument in arguments {
        guard eval_value(argument, environment, context) is Some(value) else {
          return None
        }
        values.push(value)
      }
      let result = eval_builtin(name, values)
      if result is None && context.strict_builtin_errors {
        context.builtin_error(name, span)
      }
      result
    }
    @syntax.Expr::ArrayComprehension(element, body, _) => {
      let rows = eval_body(body, environment, context)
      if context.diagnostics.length() > 0 {
        return None
      }
      let values : Array[@value.Value] = []
      for (row_environment, _) in rows {
        guard eval_value(element, row_environment, context) is Some(value) else {
          return None
        }
        values.push(value)
      }
      Some(@value.Value::array(values))
    }
    @syntax.Expr::SetComprehension(element, body, _) => {
      let rows = eval_body(body, environment, context)
      if context.diagnostics.length() > 0 {
        return None
      }
      let unique : Array[@value.Value] = []
      for (row_environment, _) in rows {
        guard eval_value(element, row_environment, context) is Some(value) else {
          return None
        }
        guard insert_set_value(unique, value, element.span(), context)
          is Some(_) else {
          return None
        }
      }
      Some(@value.Value::Set(unique))
    }
    @syntax.Expr::ObjectComprehension(
      key_expression,
      value_expression,
      body,
      span
    ) => {
      let rows = eval_body(body, environment, context)
      if context.diagnostics.length() > 0 {
        return None
      }
      let fields : Map[String, @value.Value] = Map([])
      for (row_environment, _) in rows {
        let key = match eval_value(key_expression, row_environment, context) {
          Some(@value.Value::String(key)) => key
          Some(_) => {
            context.diagnostics.push(
              @diagnostic.Diagnostic::error(
                @diagnostic.Stage::Eval,
                "rego_eval_type_error",
                "object comprehension keys must be strings",
                key_expression.span(),
              ),
            )
            return None
          }
          None => return None
        }
        guard eval_value(value_expression, row_environment, context)
          is Some(value) else {
          return None
        }
        match fields.get(key) {
          Some(_) => {
            context.diagnostics.push(
              @diagnostic.Diagnostic::error(
                @diagnostic.Stage::Eval,
                "rego_eval_conflict_error",
                "object comprehension produced duplicate key \"\{key}\"",
                span,
              ),
            )
            return None
          }
          None => fields[key] = value
        }
      }
      Some(@value.Value::Object(fields))
    }
    @syntax.Expr::SomeIn(_, _, _) => None
    @syntax.Expr::SomeInPair(_, _, _, _) => None
    @syntax.Expr::Every(_, _, _, _, _) => None
  }
}

///|
fn eval_term(
  term : @syntax.Term,
  span : @diagnostic.SourceSpan,
  environment : Environment,
  context : EvalContext,
) -> @value.Value? {
  match term {
    @syntax.Term::Null => Some(@value.Value::null())
    @syntax.Term::Bool(value) => Some(@value.Value::boolean(value))
    @syntax.Term::Number(text) =>
      @value.Number::parse(text).map(@value.Value::number)
    @syntax.Term::String(text) => Some(@value.Value::string(text))
    @syntax.Term::Variable(name) => environment.get(name)
    @syntax.Term::Root(@syntax.RootDocument::Input) => Some(context.input)
    @syntax.Term::Root(@syntax.RootDocument::Data) => Some(context.data)
    @syntax.Term::Array(items) => {
      let values : Array[@value.Value] = []
      for item in items {
        guard eval_value(item, environment, context) is Some(value) else {
          return None
        }
        values.push(value)
      }
      Some(@value.Value::array(values))
    }
    @syntax.Term::Object(items) => {
      let fields : Map[String, @value.Value] = Map([])
      for (key, item) in items {
        guard eval_value(item, environment, context) is Some(value) else {
          return None
        }
        fields[key] = value
      }
      Some(@value.Value::Object(fields))
    }
    @syntax.Term::Set(items) => {
      let unique : Array[@value.Value] = []
      for item in items {
        guard eval_value(item, environment, context) is Some(value) else {
          return None
        }
        guard insert_set_value(unique, value, span, context) is Some(_) else {
          return None
        }
      }
      Some(@value.Value::Set(unique))
    }
  }
}

///|
fn insert_set_value(
  unique : Array[@value.Value],
  value : @value.Value,
  span : @diagnostic.SourceSpan,
  context : EvalContext,
) -> Bool? {
  for existing in unique {
    if !context.charge(span) {
      return None
    }
    if existing.equal(value) {
      return Some(false)
    }
  }
  unique.push(value)
  Some(true)
}

///|
fn number_index(number : @value.Number) -> Int32? {
  let text = number.to_canonical_string()
  if text.length() == 0 {
    return None
  }
  let mut value = 0
  for unit in text.code_units() {
    if unit < '0' || unit > '9' {
      return None
    }
    let digit = unit.to_int() - '0'.to_int()
    if value > 214748364 {
      return None
    }
    value = value * 10 + digit
  }
  Some(value)
}

///|
fn eval_binary(
  operator : @syntax.BinaryOp,
  left : @value.Value,
  right : @value.Value,
) -> @value.Value? {
  match operator {
    @syntax.BinaryOp::Equal => Some(@value.Value::boolean(left.equal(right)))
    @syntax.BinaryOp::NotEqual =>
      Some(@value.Value::boolean(!left.equal(right)))
    @syntax.BinaryOp::In => Some(@value.Value::boolean(is_member(left, right)))
    @syntax.BinaryOp::Add =>
      match (left, right) {
        (@value.Value::Number(a), @value.Value::Number(b)) =>
          Some(@value.Value::number(a.add(b)))
        _ => None
      }
    @syntax.BinaryOp::Subtract =>
      match (left, right) {
        (@value.Value::Number(a), @value.Value::Number(b)) =>
          Some(@value.Value::number(a.subtract(b)))
        _ => None
      }
    @syntax.BinaryOp::Multiply =>
      match (left, right) {
        (@value.Value::Number(a), @value.Value::Number(b)) =>
          Some(@value.Value::number(a.multiply(b)))
        _ => None
      }
    @syntax.BinaryOp::Less
    | @syntax.BinaryOp::LessEqual
    | @syntax.BinaryOp::Greater
    | @syntax.BinaryOp::GreaterEqual => compare_result(operator, left, right)
    @syntax.BinaryOp::Divide | @syntax.BinaryOp::Remainder => None
    @syntax.BinaryOp::Assign => None
  }
}

///|
fn is_member(member_value : @value.Value, collection : @value.Value) -> Bool {
  match collection {
    @value.Value::Array(items) | @value.Value::Set(items) =>
      items.any(fn(item) { item.equal(member_value) })
    @value.Value::Object(fields) =>
      match member_value {
        @value.Value::String(key) => fields.contains(key)
        _ => false
      }
    _ => false
  }
}

///|
fn compare_result(
  operator : @syntax.BinaryOp,
  left : @value.Value,
  right : @value.Value,
) -> @value.Value? {
  let comparison = match (left, right) {
    (@value.Value::Number(a), @value.Value::Number(b)) => Some(a.compare(b))
    (@value.Value::String(a), @value.Value::String(b)) => Some(a.compare(b))
    (@value.Value::Bool(a), @value.Value::Bool(b)) =>
      Some(if a == b { 0 } else if a { 1 } else { -1 })
    _ => None
  }
  match comparison {
    Some(order) =>
      Some(
        @value.Value::boolean(
          match operator {
            @syntax.BinaryOp::Less => order < 0
            @syntax.BinaryOp::LessEqual => order <= 0
            @syntax.BinaryOp::Greater => order > 0
            @syntax.BinaryOp::GreaterEqual => order >= 0
            _ => false
          },
        ),
      )
    None => None
  }
}

///|
fn eval_builtin(
  name : String,
  arguments : Array[@value.Value],
) -> @value.Value? {
  match (name, arguments) {
    ("count", [@value.Value::Array(items)]) => int_value(items.length())
    ("count", [@value.Value::Set(items)]) => int_value(items.length())
    ("count", [@value.Value::Object(items)]) => int_value(items.length())
    ("count", [@value.Value::String(text)]) => int_value(text.length())
    ("sum", [@value.Value::Array(items)]) => sum_numbers(items)
    ("sum", [@value.Value::Set(items)]) => sum_numbers(items)
    ("min", [@value.Value::Array(items)]) => numeric_extreme(items, true)
    ("min", [@value.Value::Set(items)]) => numeric_extreme(items, true)
    ("max", [@value.Value::Array(items)]) => numeric_extreme(items, false)
    ("max", [@value.Value::Set(items)]) => numeric_extreme(items, false)
    ("array.concat", [@value.Value::Array(left), @value.Value::Array(right)]) => {
      let result = left.copy()
      for item in right {
        result.push(item)
      }
      Some(@value.Value::array(result))
    }
    ("object.get", [@value.Value::Object(fields), path, default_value]) =>
      match lookup_object_path(@value.Value::Object(fields), path) {
        Some(value) => Some(value)
        None => Some(default_value)
      }
    ("object.keys", [@value.Value::Object(fields)]) => {
      let keys : Array[@value.Value] = []
      for (key, _) in fields {
        keys.push(@value.Value::string(key))
      }
      Some(@value.Value::Set(keys))
    }
    ("upper", [@value.Value::String(text)]) =>
      Some(@value.Value::string(text.to_upper()))
    ("lower", [@value.Value::String(text)]) =>
      Some(@value.Value::string(text.to_lower()))
    ("contains", [@value.Value::String(text), @value.Value::String(part)]) =>
      Some(@value.Value::boolean(text.contains(part)))
    ("startswith", [@value.Value::String(text), @value.Value::String(prefix)]) =>
      Some(@value.Value::boolean(text.has_prefix(prefix)))
    ("endswith", [@value.Value::String(text), @value.Value::String(suffix)]) =>
      Some(@value.Value::boolean(text.has_suffix(suffix)))
    ("to_number", [@value.Value::String(text)]) =>
      @value.Number::parse(text).map(@value.Value::number)
    ("is_number", [@value.Value::Number(_)]) =>
      Some(@value.Value::boolean(true))
    ("is_string", [@value.Value::String(_)]) =>
      Some(@value.Value::boolean(true))
    ("is_boolean", [@value.Value::Bool(_)]) => Some(@value.Value::boolean(true))
    ("is_array", [@value.Value::Array(_)]) => Some(@value.Value::boolean(true))
    ("is_object", [@value.Value::Object(_)]) =>
      Some(@value.Value::boolean(true))
    ("is_set", [@value.Value::Set(_)]) => Some(@value.Value::boolean(true))
    ("is_null", [@value.Value::Null]) => Some(@value.Value::boolean(true))
    ("is_number", [_])
    | ("is_string", [_])
    | ("is_boolean", [_])
    | ("is_array", [_])
    | ("is_object", [_])
    | ("is_set", [_])
    | ("is_null", [_]) => Some(@value.Value::boolean(false))
    _ => None
  }
}

///|
fn lookup_object_path(
  root : @value.Value,
  path : @value.Value,
) -> @value.Value? {
  let segments = match path {
    @value.Value::Array(items) => items
    _ => [path]
  }
  let mut current = root
  for segment in segments {
    current = match (current, segment) {
      (@value.Value::Object(fields), @value.Value::String(key)) =>
        match fields.get(key) {
          Some(value) => value
          None => return None
        }
      (@value.Value::Array(items), @value.Value::Number(index)) => {
        let position = match number_index(index) {
          Some(index) => index
          None => return None
        }
        match items.get(position) {
          Some(value) => value
          None => return None
        }
      }
      _ => return None
    }
  }
  Some(current)
}

///|
fn sum_numbers(items : Array[@value.Value]) -> @value.Value? {
  let mut sum = @value.Number::parse("0").unwrap()
  for item in items {
    match item {
      @value.Value::Number(number) => sum = sum.add(number)
      _ => return None
    }
  }
  Some(@value.Value::number(sum))
}

///|
fn numeric_extreme(
  items : Array[@value.Value],
  find_minimum : Bool,
) -> @value.Value? {
  if items.length() == 0 {
    return None
  }
  let mut best = match items[0] {
    @value.Value::Number(number) => number
    _ => return None
  }
  for item in items[1:] {
    let number = match item {
      @value.Value::Number(number) => number
      _ => return None
    }
    let order = number.compare(best)
    if (find_minimum && order < 0) || (!find_minimum && order > 0) {
      best = number
    }
  }
  Some(@value.Value::number(best))
}

///|
fn int_value(value : Int32) -> @value.Value? {
  @value.Number::parse(value.to_string()).map(@value.Value::number)
}
