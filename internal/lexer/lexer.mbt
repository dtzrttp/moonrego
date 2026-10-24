///|
priv struct Lexer {
  source : String
  filename : String
  mut offset : Int32
  mut line : Int32
  mut column : Int32
  tokens : Array[@syntax.Token]
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
pub struct LexResult {
  tokens : Array[@syntax.Token]
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
pub fn LexResult::tokens(self : LexResult) -> Array[@syntax.Token] {
  self.tokens.copy()
}

///|
pub fn LexResult::diagnostics(
  self : LexResult,
) -> Array[@diagnostic.Diagnostic] {
  self.diagnostics.copy()
}

///|
pub fn LexResult::kind_labels(self : LexResult) -> Array[String] {
  self.tokens.map(fn(token) { token.kind().label() })
}

///|
fn Lexer::at_end(self : Lexer) -> Bool {
  self.offset >= self.source.length()
}

///|
fn Lexer::current(self : Lexer) -> UInt16 {
  self.source[self.offset]
}

///|
fn Lexer::peek_next(self : Lexer) -> UInt16? {
  let next = self.offset + 1
  if next < self.source.length() {
    Some(self.source[next])
  } else {
    None
  }
}

///|
fn Lexer::advance(self : Lexer) -> Unit {
  let c = self.source[self.offset]
  self.offset += 1
  if c == '\n' {
    self.line += 1
    self.column = 1
  } else if c >= 0xD800 &&
    c <= 0xDBFF &&
    !self.at_end() &&
    self.source[self.offset] >= 0xDC00 &&
    self.source[self.offset] <= 0xDFFF {
    self.offset += 1
    self.column += 1
  } else {
    self.column += 1
  }
}

///|
fn Lexer::span_from(
  self : Lexer,
  start_offset : Int32,
  start_line : Int32,
  start_column : Int32,
) -> @diagnostic.SourceSpan {
  @diagnostic.SourceSpan::new(
    self.filename,
    start_offset~,
    start_line~,
    start_column~,
    end_offset=self.offset,
    end_line=self.line,
    end_column=self.column,
  )
}

///|
fn Lexer::emit(
  self : Lexer,
  kind : @syntax.TokenKind,
  start_offset : Int32,
  start_line : Int32,
  start_column : Int32,
) -> Unit {
  self.tokens.push(
    @syntax.Token::new(
      kind,
      self.span_from(start_offset, start_line, start_column),
    ),
  )
}

///|
fn is_ident_start(c : UInt16) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn is_ident_continue(c : UInt16) -> Bool {
  is_ident_start(c) || (c >= '0' && c <= '9')
}

///|
fn keyword_or_identifier(text : String) -> @syntax.TokenKind {
  match text {
    "package" => Package
    "import" => Import
    "as" => As
    "default" => Default
    "else" => Else
    "if" => If
    "contains" => Contains
    "in" => In
    "some" => Some
    "not" => Not
    "every" => Every
    "with" => With
    "true" => True
    "false" => False
    "null" => Null
    "input" => Input
    "data" => Data
    _ => Identifier(text)
  }
}

///|
fn Lexer::scan_identifier(
  self : Lexer,
  start_offset : Int32,
  start_line : Int32,
  start_column : Int32,
) -> Unit {
  while !self.at_end() && is_ident_continue(self.current()) {
    self.advance()
  }
  let text = self.source[start_offset:self.offset].to_owned()
  self.emit(keyword_or_identifier(text), start_offset, start_line, start_column)
}

///|
fn Lexer::scan_number(
  self : Lexer,
  start_offset : Int32,
  start_line : Int32,
  start_column : Int32,
) -> Unit {
  while !self.at_end() && self.current() >= '0' && self.current() <= '9' {
    self.advance()
  }
  if !self.at_end() &&
    self.current() == '.' &&
    self.peek_next() is Some('0'..<='9') {
    self.advance()
    while !self.at_end() && self.current() >= '0' && self.current() <= '9' {
      self.advance()
    }
  }
  if !self.at_end() && (self.current() == 'e' || self.current() == 'E') {
    let exponent_start = self.offset
    self.advance()
    if !self.at_end() && (self.current() == '+' || self.current() == '-') {
      self.advance()
    }
    if self.at_end() || self.current() < '0' || self.current() > '9' {
      self.offset = exponent_start
    } else {
      while !self.at_end() && self.current() >= '0' && self.current() <= '9' {
        self.advance()
      }
    }
  }
  let text = self.source[start_offset:self.offset].to_owned()
  self.emit(NumberLiteral(text), start_offset, start_line, start_column)
}

///|
fn Lexer::scan_string(
  self : Lexer,
  delimiter : UInt16,
  raw : Bool,
  start_offset : Int32,
  start_line : Int32,
  start_column : Int32,
) -> Unit {
  self.advance()
  let content_start = self.offset
  for ;; {
    if self.at_end() {
      self.diagnostics.push(
        @diagnostic.Diagnostic::error(
          Parse,
          "rego_parse_error",
          "unterminated string literal",
          self.span_from(start_offset, start_line, start_column),
        ),
      )
      return
    }
    let c = self.current()
    if c == delimiter {
      let text = self.source[content_start:self.offset].to_owned()
      self.advance()
      let kind : @syntax.TokenKind = if raw {
        @syntax.TokenKind::RawStringLiteral(text)
      } else {
        @syntax.TokenKind::StringLiteral(text)
      }
      self.emit(kind, start_offset, start_line, start_column)
      return
    }
    if !raw && c == '\n' {
      self.diagnostics.push(
        @diagnostic.Diagnostic::error(
          Parse,
          "rego_parse_error",
          "newline in string literal",
          self.span_from(start_offset, start_line, start_column),
        ),
      )
      return
    }
    if !raw && c == '\\' {
      self.advance()
      if !self.at_end() {
        self.advance()
      }
    } else {
      self.advance()
    }
  }
}

///|
fn Lexer::unexpected(
  self : Lexer,
  start_offset : Int32,
  start_line : Int32,
  start_column : Int32,
) -> Unit {
  self.advance()
  self.diagnostics.push(
    @diagnostic.Diagnostic::error(
      Parse,
      "rego_parse_error",
      "unexpected character",
      self.span_from(start_offset, start_line, start_column),
    ),
  )
}

///|
fn Lexer::scan_token(self : Lexer) -> Unit {
  let start_offset = self.offset
  let start_line = self.line
  let start_column = self.column
  let c = self.current()
  if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
    self.advance()
  } else if c == '#' {
    while !self.at_end() && self.current() != '\n' {
      self.advance()
    }
  } else if is_ident_start(c) {
    self.scan_identifier(start_offset, start_line, start_column)
  } else if c >= '0' && c <= '9' {
    self.scan_number(start_offset, start_line, start_column)
  } else if c == '"' {
    self.scan_string(c, false, start_offset, start_line, start_column)
  } else if c == '`' {
    self.scan_string(c, true, start_offset, start_line, start_column)
  } else {
    let simple : @syntax.TokenKind? = match c {
      '{' => Some(LeftBrace)
      '}' => Some(RightBrace)
      '[' => Some(LeftBracket)
      ']' => Some(RightBracket)
      '(' => Some(LeftParen)
      ')' => Some(RightParen)
      ',' => Some(Comma)
      '.' => Some(Dot)
      ';' => Some(Semicolon)
      '|' => Some(Pipe)
      '+' => Some(Plus)
      '-' => Some(Minus)
      '*' => Some(Star)
      '/' => Some(Slash)
      '%' => Some(Percent)
      _ => None
    }
    match simple {
      Some(kind) => {
        self.advance()
        self.emit(kind, start_offset, start_line, start_column)
      }
      None => {
        let compound : @syntax.TokenKind? = match c {
          ':' if self.peek_next() == Some('=') => Some(Assign)
          ':' => Some(Colon)
          '=' if self.peek_next() == Some('=') => Some(EqualEqual)
          '=' => Some(Equal)
          '!' if self.peek_next() == Some('=') => Some(NotEqual)
          '<' if self.peek_next() == Some('=') => Some(LessEqual)
          '<' => Some(Less)
          '>' if self.peek_next() == Some('=') => Some(GreaterEqual)
          '>' => Some(Greater)
          _ => None
        }
        match compound {
          Some(kind) => {
            self.advance()
            if kind
              is (Assign | EqualEqual | NotEqual | LessEqual | GreaterEqual) {
              self.advance()
            }
            self.emit(kind, start_offset, start_line, start_column)
          }
          None => self.unexpected(start_offset, start_line, start_column)
        }
      }
    }
  }
}

///|
pub fn lex(source : String, filename : String) -> LexResult {
  let lexer : Lexer = {
    source,
    filename,
    offset: 0,
    line: 1,
    column: 1,
    tokens: [],
    diagnostics: [],
  }
  while !lexer.at_end() {
    lexer.scan_token()
  }
  let eof_span = @diagnostic.SourceSpan::point(
    filename,
    lexer.offset,
    lexer.line,
    lexer.column,
  )
  lexer.tokens.push(@syntax.Token::new(Eof, eof_span))
  { tokens: lexer.tokens, diagnostics: lexer.diagnostics, }
}
