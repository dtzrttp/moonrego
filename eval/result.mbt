///|
/// Limits work performed during one query evaluation.
pub struct EvalOptions {
  max_steps : Int32
  strict_builtin_errors : Bool
}

///|
/// Construct evaluation options with a maximum number of expression steps.
pub fn EvalOptions::new(max_steps : Int32) -> EvalOptions {
  { max_steps, strict_builtin_errors: false, }
}

///|
/// Enable or disable evaluation errors for invalid built-in calls.
pub fn EvalOptions::with_strict_builtin_errors(
  self : EvalOptions,
  strict : Bool,
) -> EvalOptions {
  { ..self, strict_builtin_errors: strict, }
}

///|
/// Query values and structured evaluation diagnostics.
pub struct EvalResult {
  values : Array[@value.Value]
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
/// Return the values from successful query environments.
pub fn EvalResult::values(self : EvalResult) -> Array[@value.Value] {
  self.values.copy()
}

///|
/// Return evaluation diagnostics.
pub fn EvalResult::diagnostics(
  self : EvalResult,
) -> Array[@diagnostic.Diagnostic] {
  self.diagnostics.copy()
}

///|
priv struct EvalContext {
  input : @value.Value
  data : @value.Value
  program : @compile.Program?
  mut remaining : Int32
  strict_builtin_errors : Bool
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
fn EvalContext::charge(
  self : EvalContext,
  span : @diagnostic.SourceSpan,
) -> Bool {
  if self.remaining <= 0 {
    if self.diagnostics.length() == 0 ||
      self.diagnostics[self.diagnostics.length() - 1].code() !=
      "rego_eval_step_limit" {
      self.diagnostics.push(
        @diagnostic.Diagnostic::error(
          @diagnostic.Stage::Eval,
          "rego_eval_step_limit",
          "evaluation exceeded the configured step limit",
          span,
        ),
      )
    }
    false
  } else {
    self.remaining -= 1
    true
  }
}

///|
fn EvalContext::builtin_error(
  self : EvalContext,
  name : String,
  span : @diagnostic.SourceSpan,
) -> Unit {
  let code = "rego_eval_builtin_error"
  if !self.diagnostics.any(fn(diagnostic) {
      diagnostic.code() == code && diagnostic.primary() == span
    }) {
    self.diagnostics.push(
      @diagnostic.Diagnostic::error(
        @diagnostic.Stage::Eval,
        code,
        "built-in function '\{name}' received unsupported or invalid arguments",
        span,
      ),
    )
  }
}
