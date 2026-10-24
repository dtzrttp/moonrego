///|
pub(all) enum TokenKind {
  Identifier(String)
  NumberLiteral(String)
  StringLiteral(String)
  RawStringLiteral(String)
  Package
  Import
  As
  Default
  Else
  If
  Contains
  In
  Some
  Not
  Every
  With
  True
  False
  Null
  Input
  Data
  LeftBrace
  RightBrace
  LeftBracket
  RightBracket
  LeftParen
  RightParen
  Comma
  Dot
  Colon
  Semicolon
  Pipe
  Plus
  Minus
  Star
  Slash
  Percent
  Assign
  Equal
  EqualEqual
  NotEqual
  Less
  LessEqual
  Greater
  GreaterEqual
  Eof
} derive(Debug, Eq)

///|
pub extend TokenKind with @debug.Debug::{to_repr}

///|
pub extend TokenKind with Eq::{equal, not_equal}

///|
pub fn TokenKind::label(self : TokenKind) -> String {
  match self {
    Identifier(_) => "identifier"
    NumberLiteral(_) => "number"
    StringLiteral(_) => "string"
    RawStringLiteral(_) => "raw-string"
    Package => "package"
    Import => "import"
    As => "as"
    Default => "default"
    Else => "else"
    If => "if"
    Contains => "contains"
    In => "in"
    Some => "some"
    Not => "not"
    Every => "every"
    With => "with"
    True => "true"
    False => "false"
    Null => "null"
    Input => "input"
    Data => "data"
    LeftBrace => "{"
    RightBrace => "}"
    LeftBracket => "["
    RightBracket => "]"
    LeftParen => "("
    RightParen => ")"
    Comma => ","
    Dot => "."
    Colon => ":"
    Semicolon => ";"
    Pipe => "|"
    Plus => "+"
    Minus => "-"
    Star => "*"
    Slash => "/"
    Percent => "%"
    Assign => ":="
    Equal => "="
    EqualEqual => "=="
    NotEqual => "!="
    Less => "<"
    LessEqual => "<="
    Greater => ">"
    GreaterEqual => ">="
    Eof => "eof"
  }
}

///|
pub fn TokenKind::text(self : TokenKind) -> String {
  match self {
    Identifier(text)
    | NumberLiteral(text)
    | StringLiteral(text)
    | RawStringLiteral(text) => text
    other => other.label()
  }
}

///|
pub(all) struct Token {
  kind : TokenKind
  span : @diagnostic.SourceSpan
}

///|
pub fn Token::new(kind : TokenKind, span : @diagnostic.SourceSpan) -> Token {
  { kind, span, }
}

///|
pub fn Token::kind(self : Token) -> TokenKind {
  self.kind
}

///|
pub fn Token::span(self : Token) -> @diagnostic.SourceSpan {
  self.span
}

///|
pub fn Token::text(self : Token) -> String {
  self.kind.text()
}
