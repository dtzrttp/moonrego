///|
/// A checked collection of policy modules.
pub struct Program {
  modules : Array[@syntax.PolicyModule]
}

///|
/// Return all definitions of one rule in a dotted package.
pub fn Program::rules_for(
  self : Program,
  package_name : String,
  rule_name : String,
) -> Array[@syntax.Rule] {
  let matches : Array[@syntax.Rule] = []
  for policy_module in self.modules {
    if policy_module.package_name() == package_name {
      for rule in policy_module.rules() {
        if rule.name() == rule_name {
          matches.push(rule)
        }
      }
    }
  }
  matches
}

///|
/// Find the source module that owns a rule definition.
pub fn Program::module_for_rule(
  self : Program,
  package_name : String,
  rule_name : String,
  filename : String,
) -> @syntax.PolicyModule? {
  for policy_module in self.modules {
    if policy_module.package_name() == package_name &&
      policy_module.filename() == filename {
      for rule in policy_module.rules() {
        if rule.name() == rule_name {
          return Some(policy_module)
        }
      }
    }
  }
  None
}

///|
/// The optional checked program and diagnostics produced by compilation.
pub struct CompileResult {
  program : Program?
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
/// Return the checked program when compilation succeeds.
pub fn CompileResult::program(self : CompileResult) -> Program? {
  self.program
}

///|
/// Return all parse and compile diagnostics.
pub fn CompileResult::diagnostics(
  self : CompileResult,
) -> Array[@diagnostic.Diagnostic] {
  self.diagnostics.copy()
}

///|
/// Parse and check one Rego module, returning parser and compiler diagnostics.
pub fn compile_source(
  source : String,
  filename : String,
) -> Array[@diagnostic.Diagnostic] {
  let parsed = @parser.parse_module(source, filename)
  let diagnostics = parsed.diagnostics()
  match parsed.policy() {
    Some(policy) => {
      let checked = compile_modules([policy])
      for diagnostic in checked.diagnostics() {
        diagnostics.push(diagnostic)
      }
    }
    None => ()
  }
  diagnostics
}

///|
fn default_function_literal(expression : @syntax.Expr) -> Bool {
  match expression {
    @syntax.Expr::Term(@syntax.Term::Null, _)
    | @syntax.Expr::Term(@syntax.Term::Bool(_), _)
    | @syntax.Expr::Term(@syntax.Term::Number(_), _)
    | @syntax.Expr::Term(@syntax.Term::String(_), _) => true
    @syntax.Expr::Term(@syntax.Term::Array(items), _)
    | @syntax.Expr::Term(@syntax.Term::Set(items), _) =>
      items.all(default_function_literal)
    @syntax.Expr::Term(@syntax.Term::Object(items), _) =>
      items.all(fn(item) { default_function_literal(item.1) })
    @syntax.Expr::Unary(@syntax.UnaryOp::Negate, inner, _) =>
      match inner {
        @syntax.Expr::Term(@syntax.Term::Number(_), _) => true
        _ => false
      }
    _ => false
  }
}

///|
/// Check parsed modules and build a rule index for later evaluation.
pub fn compile_modules(modules : Array[@syntax.PolicyModule]) -> CompileResult {
  let diagnostics : Array[@diagnostic.Diagnostic] = []
  let rule_shapes : Array[(String, String, Bool, Bool, @diagnostic.SourceSpan)] = []
  let signatures : Array[(String, String, Int32)] = []
  let function_keys : Array[String] = []
  for policy_module in modules {
    for rule in policy_module.rules() {
      let parameter_count = match rule.kind() {
        @syntax.RuleKind::Function(parameters, _)
        | @syntax.RuleKind::DefaultFunction(parameters, _) =>
          Some(parameters.length())
        _ => None
      }
      if parameter_count is Some(arity) {
        let package_name = policy_module.package_name()
        signatures.push((package_name, rule.name(), arity))
        let key = package_name + "." + rule.name()
        if !function_keys.contains(key) {
          function_keys.push(key)
        }
      }
    }
  }
  for policy_module in modules {
    let functions : Array[(String, Int32)] = []
    for (package_name, name, arity) in signatures {
      if package_name == policy_module.package_name() {
        functions.push((name, arity))
      }
    }
    for rule in policy_module.rules() {
      let key = "\{policy_module.package_name()}.\{rule.name()}"
      let shape = rule.shape()
      let is_default = rule.kind() is @syntax.RuleKind::Default(_) ||
        rule.kind() is @syntax.RuleKind::DefaultFunction(_, _)
      let is_function = rule.kind() is @syntax.RuleKind::Function(_, _) ||
        rule.kind() is @syntax.RuleKind::DefaultFunction(_, _)
      for
        (
          previous_key,
          previous_shape,
          previous_default,
          previous_function,
          previous_span,
        ) in rule_shapes {
        let duplicate_default = is_default && previous_default
        let conflicting_shape = if is_function && previous_function {
          shape != previous_shape
        } else {
          !is_default && !previous_default && shape != previous_shape
        }
        let function_default_conflict = (
            is_default && previous_function && !is_function
          ) ||
          (is_function && previous_default && !previous_function) ||
          (is_default && is_function && !previous_function) ||
          (previous_default && previous_function && !is_function)
        if key == previous_key &&
          (conflicting_shape || duplicate_default || function_default_conflict) {
          let message = if duplicate_default {
            "rule '\{key}' has multiple default definitions"
          } else {
            "rule '\{key}' has conflicting definitions"
          }
          diagnostics.push(
            @diagnostic.Diagnostic::error(
              @diagnostic.Stage::Compile,
              "rego_type_error",
              message,
              rule.span,
            ).with_related("conflicting definition", previous_span),
          )
        }
      }
      rule_shapes.push((key, shape, is_default, is_function, rule.span))
      if is_function {
        if builtin_arity(rule.name()) is Some(_) {
          diagnostics.push(
            @diagnostic.Diagnostic::error(
              @diagnostic.Stage::Compile,
              "rego_unsupported_feature",
              "user functions cannot shadow built-ins in this implementation",
              rule.span,
            ),
          )
        }
      }
      if rule.kind() is @syntax.RuleKind::DefaultFunction(_, value) {
        if !default_function_literal(value) {
          diagnostics.push(
            @diagnostic.Diagnostic::error(
              @diagnostic.Stage::Compile,
              "rego_unsupported_feature",
              "default function values currently require a literal",
              value.span(),
            ),
          )
        }
      }
      check_rule(policy_module, rule, functions, diagnostics)
    }
  }
  let known_keys : Array[String] = []
  for (key, _, _, _, _) in rule_shapes {
    if !known_keys.contains(key) {
      known_keys.push(key)
    }
  }
  let dependencies : Array[(String, String, @diagnostic.SourceSpan)] = []
  for policy_module in modules {
    let package_name = policy_module.package_name()
    let import_aliases = import_alias_paths(policy_module)
    for rule in policy_module.rules() {
      let owner = "\{policy_module.package_name()}.\{rule.name()}"
      let rule_import_aliases = match rule.kind() {
        @syntax.RuleKind::Function(parameters, _) =>
          import_aliases.filter(fn(entry) { !parameters.contains(entry.0) })
        _ => import_aliases
      }
      for expression in rule.body() {
        collect_dependencies(
          expression, owner, package_name, known_keys, function_keys, dependencies,
        )
        collect_import_dependencies(
          expression, owner, rule_import_aliases, known_keys, dependencies,
        )
      }
      match rule.kind() {
        @syntax.RuleKind::Default(value)
        | @syntax.RuleKind::DefaultFunction(_, value)
        | @syntax.RuleKind::Complete(Some(value))
        | @syntax.RuleKind::IncrementalSet(value)
        | @syntax.RuleKind::Function(_, Some(value)) => {
          collect_dependencies(
            value, owner, package_name, known_keys, function_keys, dependencies,
          )
          collect_import_dependencies(
            value, owner, rule_import_aliases, known_keys, dependencies,
          )
        }
        @syntax.RuleKind::Complete(None)
        | @syntax.RuleKind::Function(_, None) => ()
        @syntax.RuleKind::OrderedComplete(branches) =>
          for branch in branches {
            for expression in branch.body {
              collect_dependencies(
                expression, owner, package_name, known_keys, function_keys, dependencies,
              )
              collect_import_dependencies(
                expression, owner, import_aliases, known_keys, dependencies,
              )
            }
            if branch.value is Some(value) {
              collect_dependencies(
                value, owner, package_name, known_keys, function_keys, dependencies,
              )
              collect_import_dependencies(
                value, owner, import_aliases, known_keys, dependencies,
              )
            }
          }
      }
    }
  }
  for key in known_keys {
    match cycle_span(key, dependencies) {
      Some(span) =>
        diagnostics.push(
          @diagnostic.Diagnostic::error(
            @diagnostic.Stage::Compile,
            "rego_recursion_error",
            "rule '\{key}' is recursive",
            span,
          ),
        )
      None => ()
    }
  }
  let has_errors = diagnostics.any(fn(diagnostic) {
    diagnostic.severity() is @diagnostic.Severity::Error
  })
  let program = if has_errors {
    None
  } else {
    Some({ modules: modules.copy(), })
  }
  { program, diagnostics, }
}

///|
fn import_alias_paths(
  policy_module : @syntax.PolicyModule,
) -> Array[(String, Array[String])] {
  let aliases : Array[(String, Array[String])] = []
  for item in policy_module.imports() {
    let path = item.path()
    if path.length() >= 2 && path[0] == "data" {
      let imported_path : Array[String] = []
      for index in 1..<path.length() {
        imported_path.push(path[index])
      }
      let name = match item.alias_name() {
        Some(import_name) => import_name
        None => path[path.length() - 1]
      }
      aliases.push((name, imported_path))
    }
  }
  aliases
}

///|
fn collect_import_dependencies(
  expression : @syntax.Expr,
  owner : String,
  aliases : Array[(String, Array[String])],
  known_keys : Array[String],
  dependencies : Array[(String, String, @diagnostic.SourceSpan)],
) -> Unit {
  match expression {
    @syntax.Expr::Term(@syntax.Term::Variable(name), span) =>
      for (import_name, path) in aliases {
        if name == import_name {
          match imported_rule_target(path, [], known_keys) {
            Some(target) => dependencies.push((owner, target, span))
            None => ()
          }
        }
      }
    @syntax.Expr::Term(@syntax.Term::Array(items), _)
    | @syntax.Expr::Term(@syntax.Term::Set(items), _) =>
      for item in items {
        collect_import_dependencies(
          item, owner, aliases, known_keys, dependencies,
        )
      }
    @syntax.Expr::ArrayComprehension(element, body, _) => {
      collect_import_dependencies(
        element, owner, aliases, known_keys, dependencies,
      )
      for expression in body {
        collect_import_dependencies(
          expression, owner, aliases, known_keys, dependencies,
        )
      }
    }
    @syntax.Expr::SetComprehension(element, body, _) => {
      collect_import_dependencies(
        element, owner, aliases, known_keys, dependencies,
      )
      for expression in body {
        collect_import_dependencies(
          expression, owner, aliases, known_keys, dependencies,
        )
      }
    }
    @syntax.Expr::ObjectComprehension(key, value, body, _) => {
      collect_import_dependencies(key, owner, aliases, known_keys, dependencies)
      collect_import_dependencies(
        value, owner, aliases, known_keys, dependencies,
      )
      for expression in body {
        collect_import_dependencies(
          expression, owner, aliases, known_keys, dependencies,
        )
      }
    }
    @syntax.Expr::Term(@syntax.Term::Object(items), _) =>
      for (_, value) in items {
        collect_import_dependencies(
          value, owner, aliases, known_keys, dependencies,
        )
      }
    @syntax.Expr::Term(_, _) => ()
    @syntax.Expr::Ref(root, parts, span) => {
      match root {
        @syntax.Expr::Term(@syntax.Term::Variable(name), _) =>
          for (import_name, path) in aliases {
            if name == import_name {
              let suffix : Array[String] = []
              for part in parts {
                match part {
                  @syntax.RefPart::Field(field) => suffix.push(field)
                  @syntax.RefPart::Index(_) => break
                }
              }
              match imported_rule_target(path, suffix, known_keys) {
                Some(target) => dependencies.push((owner, target, span))
                None => ()
              }
            }
          }
        _ =>
          collect_import_dependencies(
            root, owner, aliases, known_keys, dependencies,
          )
      }
      for part in parts {
        match part {
          @syntax.RefPart::Field(_) => ()
          @syntax.RefPart::Index(index) =>
            collect_import_dependencies(
              index, owner, aliases, known_keys, dependencies,
            )
        }
      }
    }
    @syntax.Expr::Unary(_, inner, _) =>
      collect_import_dependencies(
        inner, owner, aliases, known_keys, dependencies,
      )
    @syntax.Expr::Binary(_, left, right, _) => {
      collect_import_dependencies(
        left, owner, aliases, known_keys, dependencies,
      )
      collect_import_dependencies(
        right, owner, aliases, known_keys, dependencies,
      )
    }
    @syntax.Expr::Call(_, arguments, _) =>
      for argument in arguments {
        collect_import_dependencies(
          argument, owner, aliases, known_keys, dependencies,
        )
      }
    @syntax.Expr::SomeIn(_, collection, _) =>
      collect_import_dependencies(
        collection, owner, aliases, known_keys, dependencies,
      )
    @syntax.Expr::SomeInPair(_, _, collection, _) =>
      collect_import_dependencies(
        collection, owner, aliases, known_keys, dependencies,
      )
    @syntax.Expr::Every(_, _, domain, body, _) => {
      collect_import_dependencies(
        domain, owner, aliases, known_keys, dependencies,
      )
      for expression in body {
        collect_import_dependencies(
          expression, owner, aliases, known_keys, dependencies,
        )
      }
    }
  }
}

///|
fn imported_rule_target(
  imported_path : Array[String],
  suffix : Array[String],
  known_keys : Array[String],
) -> String? {
  let path = imported_path.copy()
  let mut target : String? = None
  let initial = path.join(".")
  if known_keys.contains(initial) {
    target = Some(initial)
  }
  for segment in suffix {
    path.push(segment)
    let candidate = path.join(".")
    if known_keys.contains(candidate) {
      target = Some(candidate)
    }
  }
  target
}

///|
fn collect_dependencies(
  expression : @syntax.Expr,
  owner : String,
  package_name : String,
  known_keys : Array[String],
  function_keys : Array[String],
  dependencies : Array[(String, String, @diagnostic.SourceSpan)],
) -> Unit {
  match expression {
    @syntax.Expr::Term(@syntax.Term::Array(items), _) =>
      for item in items {
        collect_dependencies(
          item, owner, package_name, known_keys, function_keys, dependencies,
        )
      }
    @syntax.Expr::Term(@syntax.Term::Object(items), _) =>
      for (_, value) in items {
        collect_dependencies(
          value, owner, package_name, known_keys, function_keys, dependencies,
        )
      }
    @syntax.Expr::Term(@syntax.Term::Set(items), _) =>
      for item in items {
        collect_dependencies(
          item, owner, package_name, known_keys, function_keys, dependencies,
        )
      }
    @syntax.Expr::Term(_, _) => ()
    @syntax.Expr::Ref(root, parts, span) => {
      match data_reference_target(root, parts, known_keys) {
        Some(target) => dependencies.push((owner, target, span))
        None => ()
      }
      collect_dependencies(
        root, owner, package_name, known_keys, function_keys, dependencies,
      )
      for part in parts {
        match part {
          @syntax.RefPart::Field(_) => ()
          @syntax.RefPart::Index(index) =>
            collect_dependencies(
              index, owner, package_name, known_keys, function_keys, dependencies,
            )
        }
      }
    }
    @syntax.Expr::Unary(_, inner, _) =>
      collect_dependencies(
        inner, owner, package_name, known_keys, function_keys, dependencies,
      )
    @syntax.Expr::Binary(_, left, right, _) => {
      collect_dependencies(
        left, owner, package_name, known_keys, function_keys, dependencies,
      )
      collect_dependencies(
        right, owner, package_name, known_keys, function_keys, dependencies,
      )
    }
    @syntax.Expr::Call(name, arguments, span) => {
      let target = package_name + "." + name
      if function_keys.contains(target) {
        dependencies.push((owner, target, span))
      }
      for argument in arguments {
        collect_dependencies(
          argument, owner, package_name, known_keys, function_keys, dependencies,
        )
      }
    }
    @syntax.Expr::SomeIn(_, collection, _) =>
      collect_dependencies(
        collection, owner, package_name, known_keys, function_keys, dependencies,
      )
    @syntax.Expr::SomeInPair(_, _, collection, _) =>
      collect_dependencies(
        collection, owner, package_name, known_keys, function_keys, dependencies,
      )
    @syntax.Expr::Every(_, _, domain, body, _) => {
      collect_dependencies(
        domain, owner, package_name, known_keys, function_keys, dependencies,
      )
      for expression in body {
        collect_dependencies(
          expression, owner, package_name, known_keys, function_keys, dependencies,
        )
      }
    }
    @syntax.Expr::ArrayComprehension(element, body, _) => {
      collect_dependencies(
        element, owner, package_name, known_keys, function_keys, dependencies,
      )
      for expression in body {
        collect_dependencies(
          expression, owner, package_name, known_keys, function_keys, dependencies,
        )
      }
    }
    @syntax.Expr::SetComprehension(element, body, _) => {
      collect_dependencies(
        element, owner, package_name, known_keys, function_keys, dependencies,
      )
      for expression in body {
        collect_dependencies(
          expression, owner, package_name, known_keys, function_keys, dependencies,
        )
      }
    }
    @syntax.Expr::ObjectComprehension(key, value, body, _) => {
      collect_dependencies(
        key, owner, package_name, known_keys, function_keys, dependencies,
      )
      collect_dependencies(
        value, owner, package_name, known_keys, function_keys, dependencies,
      )
      for expression in body {
        collect_dependencies(
          expression, owner, package_name, known_keys, function_keys, dependencies,
        )
      }
    }
  }
}

///|
fn data_reference_target(
  root : @syntax.Expr,
  parts : Array[@syntax.RefPart],
  known_keys : Array[String],
) -> String? {
  if !(root
    is @syntax.Expr::Term(@syntax.Term::Root(@syntax.RootDocument::Data), _)) {
    return None
  }
  let path : Array[String] = []
  let mut target : String? = None
  for part in parts {
    match part {
      @syntax.RefPart::Field(name) => {
        path.push(name)
        let candidate = path.join(".")
        if known_keys.contains(candidate) {
          target = Some(candidate)
        }
      }
      @syntax.RefPart::Index(_) => break
    }
  }
  target
}

///|
fn cycle_span(
  start : String,
  dependencies : Array[(String, String, @diagnostic.SourceSpan)],
) -> @diagnostic.SourceSpan? {
  for (owner, target, span) in dependencies {
    if owner == start && path_exists(target, start, dependencies) {
      return Some(span)
    }
  }
  None
}

///|
fn path_exists(
  start : String,
  goal : String,
  dependencies : Array[(String, String, @diagnostic.SourceSpan)],
) -> Bool {
  let pending : Array[String] = [start]
  let visited : Array[String] = []
  let mut index = 0
  while index < pending.length() {
    let current = pending[index]
    index += 1
    if current == goal {
      return true
    }
    if !visited.contains(current) {
      visited.push(current)
      for (owner, target, _) in dependencies {
        if owner == current && !visited.contains(target) {
          pending.push(target)
        }
      }
    }
  }
  false
}

///|
fn check_rule(
  policy_module : @syntax.PolicyModule,
  rule : @syntax.Rule,
  functions : Array[(String, Int32)],
  diagnostics : Array[@diagnostic.Diagnostic],
) -> Unit {
  let bound = import_aliases(policy_module)
  if rule.kind() is @syntax.RuleKind::Function(parameters, _) {
    for parameter in parameters {
      if !bound.contains(parameter) {
        bound.push(parameter)
      }
    }
  }
  for expression in rule.body() {
    check_expression(expression, bound, diagnostics, functions) |> ignore
  }
  match rule.kind() {
    @syntax.RuleKind::Default(value) =>
      check_expression(value, bound, diagnostics, functions) |> ignore
    @syntax.RuleKind::DefaultFunction(_, value) =>
      check_expression(value, [], diagnostics, functions) |> ignore
    @syntax.RuleKind::Complete(Some(value))
    | @syntax.RuleKind::IncrementalSet(value)
    | @syntax.RuleKind::Function(_, Some(value)) =>
      check_expression(value, bound, diagnostics, functions) |> ignore
    @syntax.RuleKind::Complete(None) | @syntax.RuleKind::Function(_, None) => ()
    @syntax.RuleKind::OrderedComplete(branches) =>
      for branch in branches {
        let branch_bound = import_aliases(policy_module)
        for expression in branch.body {
          check_expression(expression, branch_bound, diagnostics, functions)
          |> ignore
        }
        if branch.value is Some(value) {
          check_expression(value, branch_bound, diagnostics, functions)
          |> ignore
        }
      }
  }
}

///|
fn import_aliases(policy_module : @syntax.PolicyModule) -> Array[String] {
  let aliases : Array[String] = []
  for item in policy_module.imports() {
    match item.alias_name() {
      Some(import_name) => aliases.push(import_name)
      None => {
        let path = item.path()
        if path.length() > 0 {
          aliases.push(path[path.length() - 1])
        }
      }
    }
  }
  aliases
}

///|
fn check_expression(
  expression : @syntax.Expr,
  bound : Array[String],
  diagnostics : Array[@diagnostic.Diagnostic],
  functions : Array[(String, Int32)],
) -> Bool {
  match expression {
    @syntax.Expr::Term(@syntax.Term::Variable(name), span) =>
      if bound.contains(name) {
        true
      } else {
        diagnostics.push(
          @diagnostic.Diagnostic::error(
            @diagnostic.Stage::Compile,
            "rego_unsafe_var_error",
            "reference to undeclared variable \"\{name}\"",
            span,
          ),
        )
        false
      }
    @syntax.Expr::Term(@syntax.Term::Array(items), _)
    | @syntax.Expr::Term(@syntax.Term::Set(items), _) => {
      let mut safe = true
      for item in items {
        safe = check_expression(item, bound, diagnostics, functions) && safe
      }
      safe
    }
    @syntax.Expr::Term(@syntax.Term::Object(items), _) => {
      let mut safe = true
      for (_, value) in items {
        safe = check_expression(value, bound, diagnostics, functions) && safe
      }
      safe
    }
    @syntax.Expr::Term(_, _) => true
    @syntax.Expr::Ref(root, parts, _) => {
      let mut safe = check_expression(root, bound, diagnostics, functions)
      for part in parts {
        match part {
          @syntax.RefPart::Field(_) => ()
          @syntax.RefPart::Index(index) =>
            safe = check_expression(index, bound, diagnostics, functions) &&
              safe
        }
      }
      safe
    }
    @syntax.Expr::Unary(_, inner, _) =>
      check_expression(inner, bound, diagnostics, functions)
    @syntax.Expr::Binary(@syntax.BinaryOp::Assign, left, right, _) => {
      let right_safe = check_expression(right, bound, diagnostics, functions)
      match left {
        @syntax.Expr::Term(@syntax.Term::Variable(name), _) => {
          if right_safe && !bound.contains(name) {
            bound.push(name)
          } else if right_safe && bound.contains(name) {
            check_expression(left, bound, diagnostics, functions) |> ignore
          }
          right_safe
        }
        _ => check_expression(left, bound, diagnostics, functions) && right_safe
      }
    }
    @syntax.Expr::Binary(_, left, right, _) => {
      let left_safe = check_expression(left, bound, diagnostics, functions)
      let right_safe = check_expression(right, bound, diagnostics, functions)
      left_safe && right_safe
    }
    @syntax.Expr::Call(name, arguments, span) => {
      let mut arity = builtin_arity(name)
      for (function_name, expected) in functions {
        if function_name == name {
          arity = Some(expected)
        }
      }
      match arity {
        Some(expected) if expected != arguments.length() =>
          diagnostics.push(
            @diagnostic.Diagnostic::error(
              @diagnostic.Stage::Compile,
              "rego_type_error",
              "function '\{name}' expects \{expected} arguments, got \{arguments.length()}",
              span,
            ),
          )
        None =>
          diagnostics.push(
            @diagnostic.Diagnostic::error(
              @diagnostic.Stage::Compile,
              "rego_type_error",
              "undefined function '\{name}'",
              span,
            ),
          )
        _ => ()
      }
      let mut safe = true
      for argument in arguments {
        safe = check_expression(argument, bound, diagnostics, functions) && safe
      }
      safe
    }
    @syntax.Expr::SomeIn(name, collection, _) => {
      let safe = check_expression(collection, bound, diagnostics, functions)
      if safe && !bound.contains(name) {
        bound.push(name)
      }
      safe
    }
    @syntax.Expr::SomeInPair(key_name, value_name, collection, _) => {
      let safe = check_expression(collection, bound, diagnostics, functions)
      if safe {
        if !bound.contains(key_name) {
          bound.push(key_name)
        }
        if !bound.contains(value_name) {
          bound.push(value_name)
        }
      }
      safe
    }
    @syntax.Expr::Every(key_name, value_name, domain, body, span) => {
      if key_name == Some(value_name) && value_name != "_" {
        diagnostics.push(
          @diagnostic.Diagnostic::error(
            @diagnostic.Stage::Compile,
            "rego_compile_error",
            "var \{value_name} declared above",
            span,
          ),
        )
      }
      let domain_safe = check_expression(domain, bound, diagnostics, functions)
      let local_bound = bound.copy()
      match key_name {
        Some(name) if !local_bound.contains(name) => local_bound.push(name)
        _ => ()
      }
      if !local_bound.contains(value_name) {
        local_bound.push(value_name)
      }
      let mut safe = domain_safe
      for expression in body {
        safe = check_expression(expression, local_bound, diagnostics, functions) &&
          safe
      }
      safe
    }
    @syntax.Expr::ArrayComprehension(element, body, _) => {
      let local_bound = bound.copy()
      let mut safe = true
      for expression in body {
        safe = check_expression(expression, local_bound, diagnostics, functions) &&
          safe
      }
      check_expression(element, local_bound, diagnostics, functions) && safe
    }
    @syntax.Expr::SetComprehension(element, body, _) => {
      let local_bound = bound.copy()
      let mut safe = true
      for expression in body {
        safe = check_expression(expression, local_bound, diagnostics, functions) &&
          safe
      }
      check_expression(element, local_bound, diagnostics, functions) && safe
    }
    @syntax.Expr::ObjectComprehension(key, value, body, _) => {
      let local_bound = bound.copy()
      let mut safe = true
      for expression in body {
        safe = check_expression(expression, local_bound, diagnostics, functions) &&
          safe
      }
      let key_safe = check_expression(key, local_bound, diagnostics, functions)
      let value_safe = check_expression(
        value, local_bound, diagnostics, functions,
      )
      key_safe && value_safe && safe
    }
  }
}

///|
fn builtin_arity(name : String) -> Int32? {
  match name {
    "count"
    | "is_number"
    | "is_string"
    | "is_boolean"
    | "is_array"
    | "is_object"
    | "is_set"
    | "is_null"
    | "max"
    | "min"
    | "sum"
    | "to_number"
    | "upper"
    | "lower"
    | "object.keys" => Some(1)
    "contains" | "endswith" | "startswith" | "array.concat" => Some(2)
    "object.get" => Some(3)
    _ => None
  }
}
