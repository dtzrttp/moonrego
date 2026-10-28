///|
test "rejects a rule that refers to itself through data" {
  let diagnostics = @compile.compile_source(
    "package p\nallow if data.p.allow", "recursive.rego",
  )
  assert_true(
    diagnostics.any(fn(diagnostic) {
      diagnostic.code() == "rego_recursion_error"
    }),
  )
}

///|
test "rejects mutually recursive rules across their dependencies" {
  let first = @parser.parse_module("package p\na if data.p.b", "a.rego").policy()
  let second = @parser.parse_module("package p\nb if data.p.a", "b.rego").policy()
  let modules = match (first, second) {
    (Some(left), Some(right)) => [left, right]
    _ => abort("test modules should parse")
  }
  let result = @compile.compile_modules(modules)
  assert_true(
    result
    .diagnostics()
    .any(fn(diagnostic) { diagnostic.code() == "rego_recursion_error" }),
  )
}

///|
test "detects recursion through an imported rule alias" {
  let diagnostics = @compile.compile_source(
    "package p\nimport data.p.allow as self_ref\nallow if self_ref", "import-recursion.rego",
  )
  assert_true(
    diagnostics.any(fn(diagnostic) {
      diagnostic.code() == "rego_recursion_error"
    }),
  )
}

///|
test "detects recursion in a later else branch" {
  let diagnostics = @compile.compile_source(
    (
      #|package p
      #|allow := true if { false }
      #|else := data.p.allow if { true }
    ),
    "else-recursion.rego",
  )
  assert_true(
    diagnostics.any(fn(diagnostic) {
      diagnostic.code() == "rego_recursion_error"
    }),
  )
}

///|
test "detects recursion in an unconditional else head" {
  let diagnostics = @compile.compile_source(
    "package p\nallow := true if { false } else := data.p.allow", "else-head-recursion.rego",
  )
  assert_true(
    diagnostics.any(fn(diagnostic) {
      diagnostic.code() == "rego_recursion_error"
    }),
  )
}
