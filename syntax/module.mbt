///|
pub(all) struct Import {
  path : Array[String]
  alias_name : String?
  span : @diagnostic.SourceSpan
}

///|
pub fn Import::new(
  path : Array[String],
  alias_name : String?,
  span : @diagnostic.SourceSpan,
) -> Import {
  { path, alias_name, span, }
}

///|
pub fn Import::path(self : Import) -> Array[String] {
  self.path.copy()
}

///|
pub fn Import::path_string(self : Import) -> String {
  self.path.join(".")
}

///|
pub fn Import::alias_name(self : Import) -> String? {
  self.alias_name
}

///|
pub(all) struct RuleBranch {
  value : Expr?
  body : Array[Expr]
  span : @diagnostic.SourceSpan
}

///|
pub fn RuleBranch::new(
  value : Expr?,
  body : Array[Expr],
  span : @diagnostic.SourceSpan,
) -> RuleBranch {
  { value, body, span, }
}

///|
pub(all) enum RuleKind {
  Default(Expr)
  Complete(Expr?)
  IncrementalSet(Expr)
  OrderedComplete(Array[RuleBranch])
  Function(Array[String], Expr?)
  DefaultFunction(Array[String], Expr)
}

///|
pub(all) struct Rule {
  name : String
  kind : RuleKind
  body : Array[Expr]
  span : @diagnostic.SourceSpan
}

///|
pub fn Rule::new(
  name : String,
  kind : RuleKind,
  body : Array[Expr],
  span : @diagnostic.SourceSpan,
) -> Rule {
  { name, kind, body, span, }
}

///|
pub fn Rule::name(self : Rule) -> String {
  self.name
}

///|
pub fn Rule::kind(self : Rule) -> RuleKind {
  self.kind
}

///|
pub fn Rule::body(self : Rule) -> Array[Expr] {
  self.body.copy()
}

///|
pub fn Rule::shape(self : Rule) -> String {
  match self.kind {
    Default(_) => "default:\{self.name}"
    Complete(_) | OrderedComplete(_) => "complete:\{self.name}"
    IncrementalSet(_) => "contains:\{self.name}"
    Function(parameters, _) => "function:\{self.name}/\{parameters.length()}"
    DefaultFunction(parameters, _) =>
      "function:\{self.name}/\{parameters.length()}"
  }
}

///|
pub(all) struct PolicyModule {
  filename : String
  package_path : Array[String]
  imports : Array[Import]
  rules : Array[Rule]
}

///|
pub fn PolicyModule::new(
  filename : String,
  package_path : Array[String],
  imports : Array[Import],
  rules : Array[Rule],
) -> PolicyModule {
  { filename, package_path, imports, rules, }
}

///|
pub fn PolicyModule::filename(self : PolicyModule) -> String {
  self.filename
}

///|
pub fn PolicyModule::package_path(self : PolicyModule) -> Array[String] {
  self.package_path.copy()
}

///|
pub fn PolicyModule::package_name(self : PolicyModule) -> String {
  self.package_path.join(".")
}

///|
pub fn PolicyModule::imports(self : PolicyModule) -> Array[Import] {
  self.imports.copy()
}

///|
pub fn PolicyModule::rules(self : PolicyModule) -> Array[Rule] {
  self.rules.copy()
}
