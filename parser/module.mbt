///|
pub struct ParsedModule {
  policy : @syntax.PolicyModule?
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
pub fn ParsedModule::policy(self : ParsedModule) -> @syntax.PolicyModule? {
  self.policy
}

///|
pub fn ParsedModule::diagnostics(
  self : ParsedModule,
) -> Array[@diagnostic.Diagnostic] {
  self.diagnostics.copy()
}

///|
fn Parser::error_code(self : Parser, code : String, message : String) -> Unit {
  self.diagnostics.push(
    @diagnostic.Diagnostic::error(
      @diagnostic.Stage::Parse,
      code,
      message,
      self.current().span(),
    ),
  )
}

///|
fn Parser::take_identifier(self : Parser, message : String) -> String? {
  match self.current().kind() {
    @syntax.TokenKind::Identifier(name) => {
      self.advance() |> ignore
      Some(name)
    }
    _ => {
      self.error(message)
      None
    }
  }
}

///|
fn Parser::parse_path(self : Parser, allow_data_root : Bool) -> Array[String]? {
  let path : Array[String] = []
  match self.current().kind() {
    @syntax.TokenKind::Identifier(name) => {
      path.push(name)
      self.advance() |> ignore
    }
    @syntax.TokenKind::Data if allow_data_root => {
      path.push("data")
      self.advance() |> ignore
    }
    _ => {
      self.error("expected identifier path")
      return None
    }
  }
  while self.current().kind() is @syntax.TokenKind::Dot {
    self.advance() |> ignore
    match self.take_identifier("expected identifier after '.'") {
      Some(name) => path.push(name)
      None => return None
    }
  }
  Some(path)
}

///|
fn Parser::parse_import(self : Parser) -> @syntax.Import? {
  let start = self.advance().span()
  guard self.parse_path(true) is Some(path) else { return None }
  let alias_name = if self.current().kind() is @syntax.TokenKind::As {
    self.advance() |> ignore
    self.take_identifier("expected import alias after 'as'")
  } else {
    None
  }
  let end = if self.index > 0 {
    self.tokens[self.index - 1].span()
  } else {
    start
  }
  Some(@syntax.Import::new(path, alias_name, start.join(end)))
}

///|
fn Parser::parse_body(self : Parser) -> Array[@syntax.Expr]? {
  let body : Array[@syntax.Expr] = []
  if self.current().kind() is @syntax.TokenKind::LeftBrace {
    self.advance() |> ignore
    while !(self.current().kind() is @syntax.TokenKind::RightBrace) &&
          !self.at_end() {
      if self.current().kind() is @syntax.TokenKind::Semicolon {
        self.advance() |> ignore
        continue
      }
      let before = self.index
      match self.parse_precedence(0) {
        Some(expression) => body.push(expression)
        None => return None
      }
      if self.index == before {
        self.error("parser made no progress in rule body")
        return None
      }
    }
    if self.current().kind() is @syntax.TokenKind::RightBrace {
      self.advance() |> ignore
      Some(body)
    } else {
      self.error("expected '}' after rule body")
      None
    }
  } else {
    match self.parse_precedence(0) {
      Some(expression) => {
        body.push(expression)
        Some(body)
      }
      None => None
    }
  }
}

///|
fn Parser::parse_rule(self : Parser) -> @syntax.Rule? {
  let is_default = self.current().kind() is @syntax.TokenKind::Default
  let start = if is_default {
    self.advance().span()
  } else {
    self.current().span()
  }
  guard self.take_identifier("expected rule name") is Some(name) else {
    return None
  }
  let (kind, body) : (@syntax.RuleKind, Array[@syntax.Expr]) = if is_default {
    if !(self.current().kind() is @syntax.TokenKind::Assign) {
      self.error("expected ':=' after default rule name")
      return None
    }
    self.advance() |> ignore
    guard self.parse_precedence(0) is Some(value) else { return None }
    (Default(value), [])
  } else {
    match self.current().kind() {
      @syntax.TokenKind::LeftBrace => {
        self.error_code(
          "rego_v1_rule_if_required", "Rego v1 requires 'if' before a rule body",
        )
        self.parse_body() |> ignore
        return None
      }
      @syntax.TokenKind::If => {
        self.advance() |> ignore
        guard self.parse_body() is Some(parsed_body) else { return None }
        (Complete(None), parsed_body)
      }
      @syntax.TokenKind::Assign => {
        self.advance() |> ignore
        guard self.parse_precedence(0) is Some(value) else { return None }
        let parsed_body = if self.current().kind() is @syntax.TokenKind::If {
          self.advance() |> ignore
          guard self.parse_body() is Some(rule_body) else { return None }
          rule_body
        } else {
          []
        }
        (Complete(Some(value)), parsed_body)
      }
      @syntax.TokenKind::Contains => {
        self.advance() |> ignore
        guard self.parse_precedence(0) is Some(value) else { return None }
        if !(self.current().kind() is @syntax.TokenKind::If) {
          self.error("expected 'if' after contains rule value")
          return None
        }
        self.advance() |> ignore
        guard self.parse_body() is Some(parsed_body) else { return None }
        (IncrementalSet(value), parsed_body)
      }
      _ => {
        self.error("expected ':=', 'if', or 'contains' after rule name")
        return None
      }
    }
  }
  let end = if self.index > 0 {
    self.tokens[self.index - 1].span()
  } else {
    start
  }
  Some(@syntax.Rule::new(name, kind, body, start.join(end)))
}

///|
pub fn parse_module(source : String, filename : String) -> ParsedModule {
  let lexed = @lexer.lex(source, filename)
  let diagnostics = lexed.diagnostics()
  let parser : Parser = { tokens: lexed.tokens(), index: 0, diagnostics, }
  if !(parser.current().kind() is @syntax.TokenKind::Package) {
    parser.error("module must start with a package declaration")
    return { policy: None, diagnostics: parser.diagnostics, }
  }
  parser.advance() |> ignore
  guard parser.parse_path(false) is Some(package_path) else {
    return { policy: None, diagnostics: parser.diagnostics, }
  }
  let imports : Array[@syntax.Import] = []
  while parser.current().kind() is @syntax.TokenKind::Import {
    match parser.parse_import() {
      Some(item) => imports.push(item)
      None => break
    }
  }
  let rules : Array[@syntax.Rule] = []
  while !parser.at_end() {
    let before = parser.index
    match parser.parse_rule() {
      Some(rule) => rules.push(rule)
      None => ()
    }
    if parser.index == before {
      parser.advance() |> ignore
    }
  }
  let policy = @syntax.PolicyModule::new(filename, package_path, imports, rules)
  { policy: Some(policy), diagnostics: parser.diagnostics, }
}
