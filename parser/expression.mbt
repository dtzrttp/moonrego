///|
priv struct Parser {
  tokens : Array[@syntax.Token]
  mut index : Int32
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
pub struct ParsedQuery {
  expression : @syntax.Expr?
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
pub fn ParsedQuery::expression(self : ParsedQuery) -> @syntax.Expr? {
  self.expression
}

///|
pub fn ParsedQuery::diagnostics(
  self : ParsedQuery,
) -> Array[@diagnostic.Diagnostic] {
  self.diagnostics.copy()
}

///|
pub fn ParsedQuery::syntax(self : ParsedQuery) -> String {
  match self.expression {
    Some(expression) => expression.syntax()
    None => ""
  }
}

///|
fn Parser::current(self : Parser) -> @syntax.Token {
  self.tokens[self.index]
}

///|
fn Parser::at_end(self : Parser) -> Bool {
  self.current().kind() is @syntax.TokenKind::Eof
}

///|
fn Parser::advance(self : Parser) -> @syntax.Token {
  let token = self.current()
  if !self.at_end() {
    self.index += 1
  }
  token
}

///|
fn Parser::error(self : Parser, message : String) -> Unit {
  self.diagnostics.push(
    @diagnostic.Diagnostic::error(
      @diagnostic.Stage::Parse,
      "rego_parse_error",
      message,
      self.current().span(),
    ),
  )
}

///|
fn Parser::parse_array_literal(
  self : Parser,
  start : @diagnostic.SourceSpan,
) -> @syntax.Expr? {
  let items : Array[@syntax.Expr] = []
  if self.current().kind() is @syntax.TokenKind::RightBracket {
    let end = self.advance().span()
    return Some(@syntax.Expr::Term(@syntax.Term::Array(items), start.join(end)))
  }
  for ;; {
    guard self.parse_precedence(0) is Some(item) else { return None }
    items.push(item)
    if self.current().kind() is @syntax.TokenKind::Pipe {
      self.advance() |> ignore
      let body = self.parse_comprehension_body()
      if body.length() == 0 {
        self.error("array comprehension body must not be empty")
        return None
      }
      if self.current().kind() is @syntax.TokenKind::RightBracket {
        let end = self.advance().span()
        return Some(
          @syntax.Expr::ArrayComprehension(item, body, start.join(end)),
        )
      }
      self.error("expected ']' after array comprehension")
      return None
    }
    if self.current().kind() is @syntax.TokenKind::Comma {
      self.advance() |> ignore
      if self.current().kind() is @syntax.TokenKind::RightBracket {
        break
      }
      continue
    }
    break
  }
  if self.current().kind() is @syntax.TokenKind::RightBracket {
    let end = self.advance().span()
    Some(@syntax.Expr::Term(@syntax.Term::Array(items), start.join(end)))
  } else {
    self.error("expected ',' or ']' in array literal")
    None
  }
}

///|
fn Parser::parse_comprehension_body(self : Parser) -> Array[@syntax.Expr] {
  let body : Array[@syntax.Expr] = []
  if self.current().kind() is @syntax.TokenKind::RightBracket {
    return body
  }
  for ;; {
    guard self.parse_precedence(0) is Some(expression) else { return body }
    body.push(expression)
    if self.current().kind() is @syntax.TokenKind::Semicolon {
      self.advance() |> ignore
      if self.current().kind() is @syntax.TokenKind::RightBracket {
        break
      }
      continue
    }
    break
  }
  body
}

///|
fn Parser::parse_object_or_set(
  self : Parser,
  start : @diagnostic.SourceSpan,
) -> @syntax.Expr? {
  let first = if self.current().kind() is @syntax.TokenKind::RightBrace {
    let end = self.advance().span()
    return Some(@syntax.Expr::Term(@syntax.Term::Object([]), start.join(end)))
  } else {
    match self.parse_precedence(0) {
      Some(expression) => expression
      None => return None
    }
  }
  if self.current().kind() is @syntax.TokenKind::Colon {
    let first_key = match first {
      @syntax.Expr::Term(@syntax.Term::String(key), _) => key
      _ => {
        self.error("object literal keys must be string literals")
        return None
      }
    }
    self.advance() |> ignore
    guard self.parse_precedence(0) is Some(first_value) else { return None }
    let fields : Array[(String, @syntax.Expr)] = [(first_key, first_value)]
    for ;; {
      if self.current().kind() is @syntax.TokenKind::Comma {
        self.advance() |> ignore
        if self.current().kind() is @syntax.TokenKind::RightBrace {
          break
        }
        let key_expr = match self.parse_precedence(0) {
          Some(expression) => expression
          None => return None
        }
        let key = match key_expr {
          @syntax.Expr::Term(@syntax.Term::String(text), _) => text
          _ => {
            self.error("object literal keys must be string literals")
            return None
          }
        }
        if !(self.current().kind() is @syntax.TokenKind::Colon) {
          self.error("expected ':' after object key")
          return None
        }
        self.advance() |> ignore
        guard self.parse_precedence(0) is Some(value) else { return None }
        fields.push((key, value))
        continue
      }
      break
    }
    if self.current().kind() is @syntax.TokenKind::RightBrace {
      let end = self.advance().span()
      Some(@syntax.Expr::Term(@syntax.Term::Object(fields), start.join(end)))
    } else {
      self.error("expected ',' or '}' in object literal")
      None
    }
  } else {
    let items : Array[@syntax.Expr] = [first]
    for ;; {
      if self.current().kind() is @syntax.TokenKind::Comma {
        self.advance() |> ignore
        if self.current().kind() is @syntax.TokenKind::RightBrace {
          break
        }
        guard self.parse_precedence(0) is Some(item) else { return None }
        items.push(item)
        continue
      }
      break
    }
    if self.current().kind() is @syntax.TokenKind::RightBrace {
      let end = self.advance().span()
      Some(@syntax.Expr::Term(@syntax.Term::Set(items), start.join(end)))
    } else {
      self.error("expected ',' or '}' in set literal")
      None
    }
  }
}

///|
fn Parser::parse_primary(self : Parser) -> @syntax.Expr? {
  let token = self.advance()
  let span = token.span()
  match token.kind() {
    @syntax.TokenKind::NumberLiteral(text) => Some(Term(Number(text), span))
    @syntax.TokenKind::StringLiteral(text) =>
      match decode_json_string(text) {
        Some(value) => Some(Term(String(value), span))
        None => {
          self.diagnostics.push(
            @diagnostic.Diagnostic::error(
              @diagnostic.Stage::Parse,
              "rego_parse_error",
              "invalid escape sequence in string literal",
              span,
            ),
          )
          None
        }
      }
    @syntax.TokenKind::RawStringLiteral(text) => Some(Term(String(text), span))
    @syntax.TokenKind::Identifier(name) => {
      let (call_name, call_index) = match self.qualified_call(name) {
        Some((qualified_name, index)) => (Some(qualified_name), index)
        None => (None, self.index)
      }
      match call_name {
        Some(qualified_name) => {
          self.index = call_index
          self.parse_call(qualified_name, span)
        }
        None => Some(Term(Variable(name), span))
      }
    }
    @syntax.TokenKind::Input => Some(Term(Root(Input), span))
    @syntax.TokenKind::Data => Some(Term(Root(Data), span))
    @syntax.TokenKind::True => Some(Term(Bool(true), span))
    @syntax.TokenKind::False => Some(Term(Bool(false), span))
    @syntax.TokenKind::Null => Some(Term(Null, span))
    @syntax.TokenKind::LeftParen => {
      let expression = self.parse_precedence(0)
      if self.current().kind() is @syntax.TokenKind::RightParen {
        self.advance() |> ignore
        expression
      } else {
        self.error("expected ')' after expression")
        None
      }
    }
    @syntax.TokenKind::LeftBracket => self.parse_array_literal(span)
    @syntax.TokenKind::LeftBrace => self.parse_object_or_set(span)
    _ => {
      self.error("expected expression")
      None
    }
  }
}

///|
fn Parser::qualified_call(
  self : Parser,
  first_name : String,
) -> (String, Int32)? {
  if self.current().kind() is @syntax.TokenKind::LeftParen {
    return Some((first_name, self.index))
  }
  let mut name = first_name
  let mut index = self.index
  let mut segments = 0
  for ;; {
    if index + 2 >= self.tokens.length() {
      break
    }
    match (self.tokens[index].kind(), self.tokens[index + 1].kind()) {
      (@syntax.TokenKind::Dot, @syntax.TokenKind::Identifier(segment)) => {
        name += "." + segment
        index += 2
        segments += 1
      }
      _ => break
    }
  }
  if segments > 0 && self.tokens[index].kind() is @syntax.TokenKind::LeftParen {
    Some((name, index))
  } else {
    None
  }
}

///|
fn Parser::parse_call(
  self : Parser,
  name : String,
  start : @diagnostic.SourceSpan,
) -> @syntax.Expr? {
  self.advance() |> ignore
  let arguments : Array[@syntax.Expr] = []
  if !(self.current().kind() is @syntax.TokenKind::RightParen) {
    for ;; {
      match self.parse_precedence(0) {
        Some(argument) => arguments.push(argument)
        None => return None
      }
      if self.current().kind() is @syntax.TokenKind::Comma {
        self.advance() |> ignore
        continue
      }
      break
    }
  }
  if self.current().kind() is @syntax.TokenKind::RightParen {
    let end = self.advance().span()
    if name == "set" && arguments.length() == 0 {
      Some(Term(Set([]), start.join(end)))
    } else {
      Some(Call(name, arguments, start.join(end)))
    }
  } else {
    self.error("expected ')' after call arguments")
    None
  }
}

///|
fn Parser::parse_postfix(self : Parser) -> @syntax.Expr? {
  guard self.parse_primary() is Some(root) else { return None }
  let parts : Array[@syntax.RefPart] = []
  let mut end = root.span()
  for ;; {
    match self.current().kind() {
      @syntax.TokenKind::Dot => {
        self.advance() |> ignore
        match self.current().kind() {
          @syntax.TokenKind::Identifier(name) => {
            let field = self.advance()
            parts.push(Field(name))
            end = field.span()
          }
          _ => {
            self.error("expected field name after '.'")
            return None
          }
        }
      }
      @syntax.TokenKind::LeftBracket => {
        self.advance() |> ignore
        guard self.parse_precedence(0) is Some(index) else { return None }
        if self.current().kind() is @syntax.TokenKind::RightBracket {
          let closing = self.advance()
          parts.push(Index(index))
          end = closing.span()
        } else {
          self.error("expected ']' after reference index")
          return None
        }
      }
      _ => break
    }
  }
  if parts.length() == 0 {
    Some(root)
  } else {
    Some(Ref(root, parts, root.span().join(end)))
  }
}

///|
fn Parser::parse_unary(self : Parser) -> @syntax.Expr? {
  match self.current().kind() {
    @syntax.TokenKind::Not => {
      let start = self.advance().span()
      match self.parse_unary() {
        Some(expression) =>
          Some(Unary(Not, expression, start.join(expression.span())))
        None => None
      }
    }
    @syntax.TokenKind::Minus => {
      let start = self.advance().span()
      match self.parse_unary() {
        Some(expression) =>
          Some(Unary(Negate, expression, start.join(expression.span())))
        None => None
      }
    }
    @syntax.TokenKind::Some => self.parse_some_in()
    _ => self.parse_postfix()
  }
}

///|
fn Parser::parse_some_in(self : Parser) -> @syntax.Expr? {
  let start = self.advance().span()
  let first_name = match self.current().kind() {
    @syntax.TokenKind::Identifier(name) => {
      self.advance() |> ignore
      name
    }
    _ => {
      self.error("expected variable after 'some'")
      return None
    }
  }
  let second_name : String? = if self.current().kind()
    is @syntax.TokenKind::Comma {
    self.advance() |> ignore
    match self.current().kind() {
      @syntax.TokenKind::Identifier(name) => {
        self.advance() |> ignore
        Some(name)
      }
      _ => {
        self.error("expected second variable after ','")
        return None
      }
    }
  } else {
    None
  }
  if !(self.current().kind() is @syntax.TokenKind::In) {
    self.error("expected 'in' after variable binder")
    return None
  }
  self.advance() |> ignore
  match self.parse_precedence(0) {
    Some(collection) => {
      let span = start.join(collection.span())
      match second_name {
        Some(value_name) =>
          Some(SomeInPair(first_name, value_name, collection, span))
        None => Some(SomeIn(first_name, collection, span))
      }
    }
    None => None
  }
}

///|
fn binary_operator(kind : @syntax.TokenKind) -> (@syntax.BinaryOp, Int32)? {
  match kind {
    @syntax.TokenKind::Assign => Some((Assign, 1))
    @syntax.TokenKind::Equal | @syntax.TokenKind::EqualEqual => Some((Equal, 2))
    @syntax.TokenKind::NotEqual => Some((NotEqual, 2))
    @syntax.TokenKind::Less => Some((Less, 3))
    @syntax.TokenKind::LessEqual => Some((LessEqual, 3))
    @syntax.TokenKind::Greater => Some((Greater, 3))
    @syntax.TokenKind::GreaterEqual => Some((GreaterEqual, 3))
    @syntax.TokenKind::In => Some((In, 3))
    @syntax.TokenKind::Plus => Some((Add, 4))
    @syntax.TokenKind::Minus => Some((Subtract, 4))
    @syntax.TokenKind::Star => Some((Multiply, 5))
    @syntax.TokenKind::Slash => Some((Divide, 5))
    @syntax.TokenKind::Percent => Some((Remainder, 5))
    _ => None
  }
}

///|
fn Parser::parse_precedence(self : Parser, minimum : Int32) -> @syntax.Expr? {
  guard self.parse_unary() is Some(initial) else { return None }
  let mut left = initial
  for ;; {
    guard binary_operator(self.current().kind()) is Some((operator, precedence)) else {
      break
    }
    if precedence < minimum {
      break
    }
    self.advance() |> ignore
    guard self.parse_precedence(precedence + 1) is Some(right) else {
      return Some(left)
    }
    left = Binary(operator, left, right, left.span().join(right.span()))
  }
  Some(left)
}

///|
pub fn parse_query(source : String) -> ParsedQuery {
  let lexed = @lexer.lex(source, "<query>")
  let diagnostics = lexed.diagnostics()
  let parser : Parser = { tokens: lexed.tokens(), index: 0, diagnostics, }
  let expression = parser.parse_precedence(0)
  if !parser.at_end() && parser.diagnostics.length() == diagnostics.length() {
    parser.error("unexpected token after query")
  }
  { expression, diagnostics: parser.diagnostics, }
}
