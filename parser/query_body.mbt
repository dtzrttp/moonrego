///|
/// A parsed query body with source diagnostics.
pub struct ParsedBody {
  expressions : Array[@syntax.Expr]
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
/// Return the expressions in a semicolon-separated query body.
pub fn ParsedBody::expressions(self : ParsedBody) -> Array[@syntax.Expr] {
  self.expressions.copy()
}

///|
/// Return query parsing diagnostics.
pub fn ParsedBody::diagnostics(
  self : ParsedBody,
) -> Array[@diagnostic.Diagnostic] {
  self.diagnostics.copy()
}

///|
/// Parse zero or more expressions separated by semicolons.
pub fn parse_query_body(source : String) -> ParsedBody {
  let lexed = @lexer.lex(source, "<query>")
  let parser : Parser = {
    tokens: lexed.tokens(),
    index: 0,
    diagnostics: lexed.diagnostics(),
  }
  let expressions : Array[@syntax.Expr] = []
  while !parser.at_end() {
    if parser.current().kind() is @syntax.TokenKind::Semicolon {
      parser.advance() |> ignore
      continue
    }
    let before = parser.index
    match parser.parse_precedence(0) {
      Some(expression) => expressions.push(expression)
      None => {
        parser.error("expected query expression")
        break
      }
    }
    if parser.current().kind() is @syntax.TokenKind::Semicolon {
      parser.advance() |> ignore
    } else if !parser.at_end() {
      parser.error("expected ';' between query expressions")
      break
    }
    if parser.index == before {
      parser.error("parser made no progress in query body")
      break
    }
  }
  { expressions, diagnostics: parser.diagnostics, }
}
