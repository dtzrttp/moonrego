///|
pub(all) enum Stage {
  Parse
  Compile
  Eval
  Cli
} derive(Debug, Eq)

///|
pub extend Stage with @debug.Debug::{to_repr}

///|
pub extend Stage with Eq::{equal, not_equal}

///|
pub(all) enum Severity {
  Error
  Warning
} derive(Debug, Eq)

///|
pub extend Severity with @debug.Debug::{to_repr}

///|
pub extend Severity with Eq::{equal, not_equal}

///|
pub(all) struct RelatedLocation {
  message : String
  span : SourceSpan
} derive(Debug, Eq)

///|
pub extend RelatedLocation with @debug.Debug::{to_repr}

///|
pub extend RelatedLocation with Eq::{equal, not_equal}

///|
pub struct Diagnostic {
  stage : Stage
  severity : Severity
  code : String
  message : String
  primary : SourceSpan
  related : Array[RelatedLocation]
}

///|
pub fn Diagnostic::error(
  stage : Stage,
  code : String,
  message : String,
  primary : SourceSpan,
) -> Diagnostic {
  { stage, severity: Error, code, message, primary, related: [], }
}

///|
pub fn Diagnostic::warning(
  stage : Stage,
  code : String,
  message : String,
  primary : SourceSpan,
) -> Diagnostic {
  { stage, severity: Warning, code, message, primary, related: [], }
}

///|
pub fn Diagnostic::with_related(
  self : Diagnostic,
  message : String,
  span : SourceSpan,
) -> Diagnostic {
  let related = self.related.copy()
  related.push({ message, span, })
  { ..self, related, }
}

///|
pub fn Diagnostic::stage(self : Diagnostic) -> Stage {
  self.stage
}

///|
pub fn Diagnostic::severity(self : Diagnostic) -> Severity {
  self.severity
}

///|
pub fn Diagnostic::code(self : Diagnostic) -> String {
  self.code
}

///|
pub fn Diagnostic::message(self : Diagnostic) -> String {
  self.message
}

///|
pub fn Diagnostic::primary(self : Diagnostic) -> SourceSpan {
  self.primary
}

///|
pub fn Diagnostic::related(self : Diagnostic) -> Array[RelatedLocation] {
  self.related.copy()
}
