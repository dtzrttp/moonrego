///|
test "reports an unbound variable and dependent assignments" {
  let diagnostics = @compile.compile_source(
    "package p\nallow if { title := users[0].title; upper(title) == \"CEO\" }", "unsafe.rego",
  )
  assert_true(
    diagnostics.any(fn(diagnostic) {
      diagnostic.code() == "rego_unsafe_var_error"
    }),
  )
}

///|
test "accepts variables bound by assignment and some-in" {
  let diagnostics = @compile.compile_source(
    "package p\nallow if { some role in input.roles; title := role; title == \"admin\" }",
    "safe.rego",
  )
  assert_false(
    diagnostics.any(fn(diagnostic) {
      diagnostic.code() == "rego_unsafe_var_error"
    }),
  )
}

///|
test "accepts both variables bound by key-value some-in" {
  let diagnostics = @compile.compile_source(
    "package p\nallow if { some index, role in input.roles; index >= 0; role == \"admin\" }",
    "some-in-pair.rego",
  )
  assert_false(
    diagnostics.any(fn(diagnostic) {
      diagnostic.code() == "rego_unsafe_var_error"
    }),
  )
}

///|
test "array comprehension variables stay local to the comprehension" {
  let safe = @compile.compile_source(
    "package p\nallow if { roles := [role | some role in input.roles; role == \"admin\"]; count(roles) > 0 }",
    "comprehension-safe.rego",
  )
  assert_false(
    safe.any(fn(diagnostic) { diagnostic.code() == "rego_unsafe_var_error" }),
  )
  let escaping = @compile.compile_source(
    "package p\nallow if { roles := [role | some role in input.roles]; role == \"admin\" }",
    "comprehension-scope.rego",
  )
  assert_true(
    escaping.any(fn(diagnostic) { diagnostic.code() == "rego_unsafe_var_error" }),
  )
}

///|
test "set comprehension bindings are local and checked for safety" {
  let safe = @compile.compile_source(
    "package p\nroles := {role | some role in input.roles; role != \"guest\"}", "set-comprehension-safe.rego",
  )
  assert_eq(safe.map(fn(diagnostic) { diagnostic.message() }).join("|"), "")
  let escaping = @compile.compile_source(
    "package p\nroles := {role | some role in input.roles}\nallow if role == \"admin\"",
    "set-comprehension-scope.rego",
  )
  assert_true(
    escaping.any(fn(diagnostic) { diagnostic.code() == "rego_unsafe_var_error" }),
  )
}

///|
test "object comprehension key and value use local bindings" {
  let safe = @compile.compile_source(
    "package p\nroles := {role: upper(role) | some role in input.roles}", "object-comprehension-safe.rego",
  )
  assert_eq(safe.length(), 0)
  let escaping = @compile.compile_source(
    "package p\nroles := {role: role | some role in input.roles}\nallow if role == \"admin\"",
    "object-comprehension-scope.rego",
  )
  assert_true(
    escaping.any(fn(diagnostic) { diagnostic.code() == "rego_unsafe_var_error" }),
  )
}

///|
test "rejects multiple default definitions for one rule" {
  let diagnostics = @compile.compile_source(
    "package p\ndefault allow := false\ndefault allow := true", "defaults.rego",
  )
  assert_true(
    diagnostics.any(fn(diagnostic) { diagnostic.code() == "rego_type_error" }),
  )
}

///|
test "indexes complete rule definitions across modules" {
  let first = @parser.parse_module(
    "package p\nallow if input.role == \"admin\"", "one.rego",
  ).policy()
  let second = @parser.parse_module(
    "package p\nallow if input.owner == \"team\"", "two.rego",
  ).policy()
  let modules = match (first, second) {
    (Some(left), Some(right)) => [left, right]
    _ => abort("test modules should parse")
  }
  let compiled = @compile.compile_modules(modules)
  assert_true(compiled.program() is Some(_))
  match compiled.program() {
    Some(program) => assert_eq(program.rules_for("p", "allow").length(), 2)
    None => abort("program should be available")
  }
}

///|
test "rejects unknown builtin calls" {
  let diagnostics = @compile.compile_source(
    "package p\nallow if mystery(input.user)", "unknown-call.rego",
  )
  assert_true(
    diagnostics.any(fn(diagnostic) { diagnostic.code() == "rego_type_error" }),
  )
}

///|
test "rejects builtins outside the implemented subset" {
  let diagnostics = @compile.compile_source(
    "package p\nallow if sort([1, 2])", "unsupported-builtin.rego",
  )
  assert_true(
    diagnostics.any(fn(diagnostic) { diagnostic.code() == "rego_type_error" }),
  )
}

///|
test "accepts namespaced object builtins with their documented arity" {
  let diagnostics = @compile.compile_source(
    "package p\nallow if object.get(input, \"active\", false) == true", "object-get.rego",
  )
  assert_eq(diagnostics.length(), 0)
}

///|
test "accepts numeric aggregates with their documented arity" {
  let sum = @compile.compile_source(
    "package p\nallow if sum([1, 2]) == 3", "sum.rego",
  )
  let minimum = @compile.compile_source(
    "package p\nallow if min([1, 2]) == 1", "min.rego",
  )
  let maximum = @compile.compile_source(
    "package p\nallow if max([1, 2]) == 2", "max.rego",
  )
  assert_eq(sum.length(), 0)
  assert_eq(minimum.length(), 0)
  assert_eq(maximum.length(), 0)
}

///|
test "rejects builtin calls with the wrong arity" {
  let diagnostics = @compile.compile_source(
    "package p\nallow if upper(input.user, input.role)", "wrong-arity.rego",
  )
  assert_true(
    diagnostics.any(fn(diagnostic) { diagnostic.code() == "rego_type_error" }),
  )
}

///|
test "import aliases are valid rule references" {
  let diagnostics = @compile.compile_source(
    "package p\nimport data.users as users\nallow if users[0].role == \"admin\"",
    "import.rego",
  )
  assert_false(
    diagnostics.any(fn(diagnostic) {
      diagnostic.code() == "rego_unsafe_var_error"
    }),
  )
}
