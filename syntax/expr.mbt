///|
pub(all) enum RootDocument {
  Input
  Data
}

///|
pub(all) enum UnaryOp {
  Not
  Negate
}

///|
pub(all) enum BinaryOp {
  Assign
  Equal
  NotEqual
  Less
  LessEqual
  Greater
  GreaterEqual
  In
  Add
  Subtract
  Multiply
  Divide
  Remainder
}

///|
pub(all) enum Term {
  Null
  Bool(Bool)
  Number(String)
  String(String)
  Variable(String)
  Root(RootDocument)
  Array(Array[Expr])
  Object(Array[(String, Expr)])
  Set(Array[Expr])
}

///|
pub(all) enum RefPart {
  Field(String)
  Index(Expr)
}

///|
pub(all) enum Expr {
  Term(Term, @diagnostic.SourceSpan)
  Ref(Expr, Array[RefPart], @diagnostic.SourceSpan)
  Unary(UnaryOp, Expr, @diagnostic.SourceSpan)
  Binary(BinaryOp, Expr, Expr, @diagnostic.SourceSpan)
  Call(String, Array[Expr], @diagnostic.SourceSpan)
  SomeIn(String, Expr, @diagnostic.SourceSpan)
  SomeInPair(String, String, Expr, @diagnostic.SourceSpan)
  ArrayComprehension(Expr, Array[Expr], @diagnostic.SourceSpan)
  SetComprehension(Expr, Array[Expr], @diagnostic.SourceSpan)
}

///|
pub fn Expr::span(self : Expr) -> @diagnostic.SourceSpan {
  match self {
    Term(_, span)
    | Ref(_, _, span)
    | Unary(_, _, span)
    | Binary(_, _, _, span)
    | Call(_, _, span)
    | SomeIn(_, _, span)
    | SomeInPair(_, _, _, span)
    | ArrayComprehension(_, _, span)
    | SetComprehension(_, _, span) => span
  }
}

///|
fn UnaryOp::syntax(self : UnaryOp) -> String {
  match self {
    Not => "Not"
    Negate => "Negate"
  }
}

///|
fn BinaryOp::syntax(self : BinaryOp) -> String {
  match self {
    Assign => "Assign"
    Equal => "Equal"
    NotEqual => "NotEqual"
    Less => "Less"
    LessEqual => "LessEqual"
    Greater => "Greater"
    GreaterEqual => "GreaterEqual"
    In => "In"
    Add => "Add"
    Subtract => "Subtract"
    Multiply => "Multiply"
    Divide => "Divide"
    Remainder => "Remainder"
  }
}

///|
fn Term::syntax(self : Term) -> String {
  match self {
    Null => "Null"
    Bool(value) => if value { "Bool(true)" } else { "Bool(false)" }
    Number(value) => "Number(\{value})"
    String(value) => "String(\{value})"
    Variable(name) => name
    Root(Input) => "input"
    Root(Data) => "data"
    Array(items) =>
      "Array([\{items.map(fn(item) { item.syntax() }).join(",")}])"
    Object(items) => {
      let fields = items.map(fn(item) {
        let (key, value) = item
        "\{key}:\{value.syntax()}"
      })
      "Object({\{fields.join(",")}})"
    }
    Set(items) => "Set({\{items.map(fn(item) { item.syntax() }).join(",")}})"
  }
}

///|
fn RefPart::syntax(self : RefPart) -> String {
  match self {
    Field(name) => "Field(\{name})"
    Index(expr) => "Index(\{expr.syntax()})"
  }
}

///|
pub fn Expr::syntax(self : Expr) -> String {
  match self {
    Term(term, _) => term.syntax()
    Ref(root, parts, _) =>
      "Ref(\{root.syntax()},[\{parts.map(fn(part) { part.syntax() }).join(",")}])"
    Unary(op, expr, _) => "Unary(\{op.syntax()},\{expr.syntax()})"
    Binary(op, left, right, _) =>
      "Binary(\{op.syntax()},\{left.syntax()},\{right.syntax()})"
    Call(name, arguments, _) =>
      "Call(\{name},[\{arguments.map(fn(arg) { arg.syntax() }).join(",")}])"
    SomeIn(name, collection, _) => "SomeIn(\{name},\{collection.syntax()})"
    SomeInPair(key, value, collection, _) =>
      "SomeInPair(\{key},\{value},\{collection.syntax()})"
    ArrayComprehension(value, body, _) =>
      "ArrayComprehension(\{value.syntax()},[\{body.map(fn(item) { item.syntax() }).join(",")}])"
    SetComprehension(value, body, _) =>
      "SetComprehension(\{value.syntax()},[\{body.map(fn(item) { item.syntax() }).join(",")}])"
  }
}
