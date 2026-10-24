///|
test "some-in backtracks over matching input values" {
  let input : @value.Value = @value.Value::Object({
    "roles": @value.Value::array([
      @value.Value::string("viewer"),
      @value.Value::string("admin"),
      @value.Value::string("admin"),
    ]),
  })
  let result = @eval.eval_query(
    "some role in input.roles; role == \"admin\"; role",
    input,
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 2)
  assert_true(
    result
    .values()
    .all(fn(value) { value.equal(@value.Value::string("admin")) }),
  )
  assert_eq(result.diagnostics().length(), 0)
}

///|
test "some-in pair binds an array index and value" {
  let input : @value.Value = @value.Value::Object({
    "roles": @value.Value::array([
      @value.Value::string("viewer"),
      @value.Value::string("admin"),
    ]),
  })
  let result = @eval.eval_query(
    "some index, role in input.roles; role == \"admin\"; index",
    input,
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 1)
  assert_true(
    result.values()[0].equal(
      @value.Value::number(@value.Number::parse("1").unwrap()),
    ),
  )
  assert_eq(result.diagnostics().length(), 0)
}

///|
test "some-in pair binds an object key and value" {
  let input : @value.Value = @value.Value::Object({
    "roles": @value.Value::Object({
      "primary": @value.Value::string("admin"),
      "secondary": @value.Value::string("viewer"),
    }),
  })
  let result = @eval.eval_query(
    "some name, role in input.roles; role == \"admin\"; name",
    input,
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::string("primary")))
  assert_eq(result.diagnostics().length(), 0)
}

///|
test "some-in pair reports unsupported set key-value iteration" {
  let result = @eval.eval_query(
    "some key, value in input.roles",
    @value.Value::Object({
      "roles": @value.Value::set([@value.Value::string("admin")]),
    }),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_unsupported_feature")
}

///|
test "every over an array succeeds when every body has a result" {
  let result = @eval.eval_query(
    "every role in input.roles { role != \"blocked\" }",
    @value.Value::Object({
      "roles": @value.Value::array([
        @value.Value::string("viewer"),
        @value.Value::string("admin"),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::boolean(true)))
}

///|
test "every over an array fails when any body has no result" {
  let result = @eval.eval_query(
    "every role in input.roles { role != \"blocked\" }",
    @value.Value::Object({
      "roles": @value.Value::array([
        @value.Value::string("viewer"),
        @value.Value::string("blocked"),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 0)
}

///|
test "every over empty arrays objects and sets succeeds" {
  let parsed = @parser.parse_query_body("every item in [] { item > 0 }")
  assert_eq(parsed.diagnostics().length(), 0)
  assert_eq(parsed.expressions().length(), 1)
  match parsed.expressions()[0] {
    @syntax.Expr::Every(_, _, _, _, _) => ()
    _ => assert_true(false)
  }
  let empty_array = @eval.eval_query(
    "every item in [] { item > 0 }",
    @value.Value::null(),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(empty_array.diagnostics().length(), 0)
  assert_eq(empty_array.values().length(), 1)
  assert_true(empty_array.values()[0].equal(@value.Value::boolean(true)))

  let empty_object = @eval.eval_query(
    "every item in input.roles { item > 0 }",
    @value.Value::Object({ "roles": @value.Value::Object({}) }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(empty_object.diagnostics().length(), 0)
  assert_eq(empty_object.values().length(), 1)
  assert_true(empty_object.values()[0].equal(@value.Value::boolean(true)))

  let empty_set = @eval.eval_query(
    "every item in set() { item > 0 }",
    @value.Value::null(),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(empty_set.diagnostics().length(), 0)
  assert_eq(empty_set.values().length(), 1)
  assert_true(empty_set.values()[0].equal(@value.Value::boolean(true)))
}

///|
test "every over an undefined domain is undefined without diagnostics" {
  let result = @eval.eval_query(
    "every role in input.roles { role != \"blocked\" }",
    @value.Value::Object({}),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 0)
}

///|
test "every binder shadows locally and preserves the outer binding" {
  let result = @eval.eval_query(
    "some role in input.roles; every role in input.allowed { role == \"admin\" }; role",
    @value.Value::Object({
      "roles": @value.Value::array([@value.Value::string("viewer")]),
      "allowed": @value.Value::array([@value.Value::string("admin")]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::string("viewer")))
}

///|
test "every body assignments do not escape their local scope" {
  let result = @eval.eval_query(
    "every role in input.roles { seen := role }; seen",
    @value.Value::Object({
      "roles": @value.Value::array([@value.Value::string("admin")]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 0)
}

///|
test "every pair iterates array indices and values" {
  let result = @eval.eval_query(
    "every index, role in input.roles { index >= 0; role != \"blocked\" }",
    @value.Value::Object({
      "roles": @value.Value::array([
        @value.Value::string("viewer"),
        @value.Value::string("admin"),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::boolean(true)))
}

///|
test "every pair iterates object keys and values" {
  let result = @eval.eval_query(
    "every name, user in input.users { startswith(name, \"team-\"); \"staff\" in user.roles }",
    @value.Value::Object({
      "users": @value.Value::Object({
        "team-a": @value.Value::Object({
          "roles": @value.Value::array([@value.Value::string("staff")]),
        }),
        "team-b": @value.Value::Object({
          "roles": @value.Value::array([
            @value.Value::string("staff"),
            @value.Value::string("reviewer"),
          ]),
        }),
      }),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::boolean(true)))
}

///|
test "every one-variable object iteration binds keys and set iteration binds members" {
  let object_result = @eval.eval_query(
    "every name in input.users { startswith(name, \"team-\") }",
    @value.Value::Object({
      "users": @value.Value::Object({
        "team-a": @value.Value::boolean(true),
        "team-b": @value.Value::boolean(false),
      }),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(object_result.diagnostics().length(), 0)
  assert_eq(object_result.values().length(), 1)
  assert_true(object_result.values()[0].equal(@value.Value::boolean(true)))

  let set_result = @eval.eval_query(
    "every tag in input.tags { tag != \"blocked\" }",
    @value.Value::Object({
      "tags": @value.Value::set([
        @value.Value::string("public"),
        @value.Value::string("internal"),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(set_result.diagnostics().length(), 0)
  assert_eq(set_result.values().length(), 1)
  assert_true(set_result.values()[0].equal(@value.Value::boolean(true)))
}

///|
test "every over a set fails when a member fails the body" {
  let result = @eval.eval_query(
    "every tag in input.tags { tag != \"blocked\" }",
    @value.Value::Object({
      "tags": @value.Value::set([
        @value.Value::string("public"),
        @value.Value::string("blocked"),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 0)
}

///|
test "every rejects two-variable set iteration" {
  let result = @eval.eval_query(
    "every key, value in input.tags { true }",
    @value.Value::Object({
      "tags": @value.Value::set([@value.Value::string("public")]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_unsupported_feature")
}

///|
test "every reports an error for a non-collection domain" {
  let result = @eval.eval_query(
    "every value in 42 { true }",
    @value.Value::null(),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_type_error")
  assert_eq(
    result.diagnostics()[0].message(),
    "every domain must be an array, object, or set",
  )
}

///|
test "nested every checks each nested collection" {
  let all_pass = @eval.eval_query(
    "every team in input.teams { every role in team.roles { role != \"blocked\" } }",
    @value.Value::Object({
      "teams": @value.Value::array([
        @value.Value::Object({
          "roles": @value.Value::array([@value.Value::string("admin")]),
        }),
        @value.Value::Object({
          "roles": @value.Value::array([@value.Value::string("viewer")]),
        }),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(all_pass.diagnostics().length(), 0)
  assert_eq(all_pass.values().length(), 1)
  assert_true(all_pass.values()[0].equal(@value.Value::boolean(true)))

  let one_fails = @eval.eval_query(
    "every team in input.teams { every role in team.roles { role != \"blocked\" } }",
    @value.Value::Object({
      "teams": @value.Value::array([
        @value.Value::Object({
          "roles": @value.Value::array([@value.Value::string("admin")]),
        }),
        @value.Value::Object({
          "roles": @value.Value::array([@value.Value::string("blocked")]),
        }),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(one_fails.diagnostics().length(), 0)
  assert_eq(one_fails.values().length(), 0)
}

///|
test "array comprehension filters values and preserves duplicates" {
  let input : @value.Value = @value.Value::Object({
    "roles": @value.Value::array([
      @value.Value::string("guest"),
      @value.Value::string("admin"),
      @value.Value::string("admin"),
    ]),
  })
  let result = @eval.eval_query(
    "[role | some role in input.roles; role != \"guest\"]",
    input,
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  match result.values()[0] {
    @value.Value::Array(items) => {
      assert_eq(items.length(), 2)
      assert_true(items[0].equal(@value.Value::string("admin")))
      assert_true(items[1].equal(@value.Value::string("admin")))
    }
    _ => assert_true(false)
  }
}

///|
test "array comprehension returns an empty array when its body has no results" {
  let result = @eval.eval_query(
    "[role | some role in input.roles; role == \"admin\"]",
    @value.Value::Object({
      "roles": @value.Value::array([@value.Value::string("guest")]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::array([])))
}

///|
test "array comprehension step exhaustion returns no partial result" {
  let result = @eval.eval_query(
    "[item | some item in input.items]",
    @value.Value::Object({
      "items": @value.Value::array([
        @value.Value::number(@value.Number::parse("1").unwrap()),
      ]),
    }),
    @eval.EvalOptions::new(2),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_step_limit")
}

///|
test "array comprehension charges the budget while generating body rows" {
  let query = "[item | some item in input.items]"
  let result = @eval.eval_query(
    query,
    @value.Value::Object({
      "items": @value.Value::array([
        @value.Value::number(@value.Number::parse("1").unwrap()),
        @value.Value::number(@value.Number::parse("2").unwrap()),
        @value.Value::number(@value.Number::parse("3").unwrap()),
        @value.Value::number(@value.Number::parse("4").unwrap()),
      ]),
    }),
    @eval.EvalOptions::new(5),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_step_limit")
  assert_eq(result.diagnostics()[0].primary().start_offset(), 8)
}

///|
test "array comprehension charges key-value iteration before binding rows" {
  let query = "[value | some index, value in input.items]"
  let options = @eval.EvalOptions::new(5)
  let array_result = @eval.eval_query(
    query,
    @value.Value::Object({
      "items": @value.Value::array([
        @value.Value::number(@value.Number::parse("1").unwrap()),
        @value.Value::number(@value.Number::parse("2").unwrap()),
      ]),
    }),
    options,
  )
  let object_result = @eval.eval_query(
    query,
    @value.Value::Object({
      "items": @value.Value::Object({
        "first": @value.Value::number(@value.Number::parse("1").unwrap()),
        "second": @value.Value::number(@value.Number::parse("2").unwrap()),
      }),
    }),
    options,
  )
  for result in [array_result, object_result] {
    assert_eq(result.values().length(), 0)
    assert_eq(result.diagnostics().length(), 1)
    assert_eq(result.diagnostics()[0].code(), "rego_eval_step_limit")
    assert_eq(result.diagnostics()[0].primary().start_offset(), 9)
  }
}

///|
test "set comprehension filters and deduplicates values" {
  let input : @value.Value = @value.Value::Object({
    "roles": @value.Value::array([
      @value.Value::string("guest"),
      @value.Value::string("admin"),
      @value.Value::string("admin"),
    ]),
  })
  let result = @eval.eval_query(
    "{role | some role in input.roles; role != \"guest\"}",
    input,
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  assert_true(
    result.values()[0].equal(@value.Value::set([@value.Value::string("admin")])),
  )
}

///|
test "set comprehension step exhaustion returns no partial result" {
  let result = @eval.eval_query(
    "{item | some item in input.items}",
    @value.Value::Object({
      "items": @value.Value::array([
        @value.Value::number(@value.Number::parse("1").unwrap()),
        @value.Value::number(@value.Number::parse("2").unwrap()),
        @value.Value::number(@value.Number::parse("3").unwrap()),
        @value.Value::number(@value.Number::parse("4").unwrap()),
      ]),
    }),
    @eval.EvalOptions::new(5),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_step_limit")
  assert_eq(result.diagnostics()[0].primary().start_offset(), 8)
}

///|
test "set comprehension charges value deduplication to the step budget" {
  let result = @eval.eval_query(
    "{item | some item in input.items}",
    @value.Value::Object({
      "items": @value.Value::array([
        @value.Value::number(@value.Number::parse("1").unwrap()),
        @value.Value::number(@value.Number::parse("2").unwrap()),
        @value.Value::number(@value.Number::parse("3").unwrap()),
        @value.Value::number(@value.Number::parse("4").unwrap()),
      ]),
    }),
    @eval.EvalOptions::new(13),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_step_limit")
  assert_eq(result.diagnostics()[0].primary().start_offset(), 1)
}

///|
test "set literals charge value deduplication to the step budget" {
  let result = @eval.eval_query(
    "{1, 2, 3, 4}",
    @value.Value::null(),
    @eval.EvalOptions::new(6),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_step_limit")
}

///|
test "object comprehension evaluates computed role mappings" {
  let result = @eval.eval_query(
    "{role: upper(role) | some role in input.roles}",
    @value.Value::Object({
      "roles": @value.Value::array([
        @value.Value::string("admin"),
        @value.Value::string("editor"),
        @value.Value::string("viewer"),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_eq(result.values().length(), 1)
  assert_true(
    result.values()[0].equal(
      @value.Value::Object({
        "admin": @value.Value::string("ADMIN"),
        "editor": @value.Value::string("EDITOR"),
        "viewer": @value.Value::string("VIEWER"),
      }),
    ),
  )
}

///|
test "object comprehension reports conflicting values for one key" {
  let result = @eval.eval_query(
    "{item.name: item.role | some item in input.items}",
    @value.Value::Object({
      "items": @value.Value::array([
        @value.Value::Object({
          "name": @value.Value::string("alpha"),
          "role": @value.Value::string("reader"),
        }),
        @value.Value::Object({
          "name": @value.Value::string("alpha"),
          "role": @value.Value::string("writer"),
        }),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_conflict_error")
}

///|
test "object comprehension rejects duplicate keys with equal values" {
  let result = @eval.eval_query(
    "{role: upper(role) | some role in input.roles}",
    @value.Value::Object({
      "roles": @value.Value::array([
        @value.Value::string("admin"),
        @value.Value::string("admin"),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_conflict_error")
}

///|
test "object comprehension rejects non-string keys" {
  let result = @eval.eval_query(
    "{item: true | some item in input.items}",
    @value.Value::Object({
      "items": @value.Value::array([
        @value.Value::number(@value.Number::parse("1").unwrap()),
      ]),
    }),
    @eval.EvalOptions::new(1000),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_type_error")
}

///|
test "false predicates produce no query results" {
  let result = @eval.eval_query(
    "input.enabled == true",
    @value.Value::Object({ "enabled": @value.Value::boolean(false) }),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.values().length(), 0)
}

///|
test "builtin type errors are undefined unless strict mode is enabled" {
  let ordinary = @eval.eval_query(
    "upper(42)",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  assert_eq(ordinary.values().length(), 0)
  assert_eq(ordinary.diagnostics().length(), 0)
  let strict = @eval.eval_query(
    "upper(42)",
    @value.Value::null(),
    @eval.EvalOptions::new(100).with_strict_builtin_errors(true),
  )
  assert_eq(strict.values().length(), 0)
  assert_eq(strict.diagnostics().length(), 1)
  assert_eq(strict.diagnostics()[0].code(), "rego_eval_builtin_error")
}

///|
test "array.concat preserves the input array order" {
  let result = @eval.eval_query(
    "array.concat([1, 2], [3])",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_true(
    result
    .values()
    .any(fn(value) {
      value.equal(
        @value.Value::array([
          @value.Value::number(@value.Number::parse("1").unwrap()),
          @value.Value::number(@value.Number::parse("2").unwrap()),
          @value.Value::number(@value.Number::parse("3").unwrap()),
        ]),
      )
    }),
  )
}

///|
test "object.get returns present values and defaults for missing paths" {
  let input : @value.Value = @value.Value::Object({
    "name": @value.Value::string("Ada"),
    "profile": @value.Value::Object({ "nickname": @value.Value::null() }),
    "servers": @value.Value::array([
      @value.Value::Object({ "name": @value.Value::string("api") }),
    ]),
    "settings": @value.Value::Object({ "theme": @value.Value::string("dark") }),
  })
  let present = @eval.eval_query(
    "object.get(input, \"name\", \"anon\")",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(present.diagnostics().length(), 0)
  assert_true(
    present.values().any(fn(value) { value.equal(@value.Value::string("Ada")) }),
  )
  let nested = @eval.eval_query(
    "object.get(input, [\"settings\", \"theme\"], \"light\")",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(nested.diagnostics().length(), 0)
  assert_true(
    nested.values().any(fn(value) { value.equal(@value.Value::string("dark")) }),
  )
  let missing = @eval.eval_query(
    "object.get(input, [\"settings\", \"missing\"], \"light\")",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(missing.diagnostics().length(), 0)
  assert_true(
    missing
    .values()
    .any(fn(value) { value.equal(@value.Value::string("light")) }),
  )
  let array_path = @eval.eval_query(
    "object.get(input, [\"servers\", 0, \"name\"], \"missing\")",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(array_path.diagnostics().length(), 0)
  assert_true(
    array_path
    .values()
    .any(fn(value) { value.equal(@value.Value::string("api")) }),
  )
  let explicit_null = @eval.eval_query(
    "object.get(input, [\"profile\", \"nickname\"], \"fallback\")",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(explicit_null.diagnostics().length(), 0)
  assert_true(
    explicit_null.values().any(fn(value) { value.equal(@value.Value::null()) }),
  )
}

///|
test "object.keys returns a set of object keys" {
  let result = @eval.eval_query(
    "object.keys(input)",
    @value.Value::Object({
      "alpha": @value.Value::number(@value.Number::parse("1").unwrap()),
      "beta": @value.Value::boolean(true),
    }),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.diagnostics().length(), 0)
  assert_true(
    result
    .values()
    .any(fn(value) {
      value.equal(
        @value.Value::set([
          @value.Value::string("alpha"),
          @value.Value::string("beta"),
        ]),
      )
    }),
  )
}

///|
test "sum uses exact decimal arithmetic for arrays and sets" {
  let array_sum = @eval.eval_query(
    "sum([0.1, 0.2, 0.3])",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  let expected = @value.Value::number(@value.Number::parse("0.6").unwrap())
  assert_eq(array_sum.diagnostics().length(), 0)
  assert_true(array_sum.values().any(fn(value) { value.equal(expected) }))
  let set_sum = @eval.eval_query(
    "sum({1, 2, 3})",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  assert_eq(set_sum.diagnostics().length(), 0)
  assert_true(
    set_sum
    .values()
    .any(fn(value) {
      value.equal(@value.Value::number(@value.Number::parse("6").unwrap()))
    }),
  )
}

///|
test "min and max find exact numeric bounds" {
  let minimum = @eval.eval_query(
    "min([3, 0.1, 2])",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  let maximum = @eval.eval_query(
    "max([3, 0.1, 2])",
    @value.Value::null(),
    @eval.EvalOptions::new(100),
  )
  assert_eq(minimum.diagnostics().length(), 0)
  assert_eq(maximum.diagnostics().length(), 0)
  assert_true(
    minimum
    .values()
    .any(fn(value) {
      value.equal(@value.Value::number(@value.Number::parse("0.1").unwrap()))
    }),
  )
  assert_true(
    maximum
    .values()
    .any(fn(value) {
      value.equal(@value.Value::number(@value.Number::parse("3").unwrap()))
    }),
  )
}

///|
test "resolves array references and uses exact decimal arithmetic" {
  let input : @value.Value = @value.Value::Object({
    "prices": @value.Value::array([
      @value.Value::number(@value.Number::parse("0.2").unwrap()),
    ]),
  })
  let result = @eval.eval_query(
    "input.prices[0] + 0.1 == 0.3",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::boolean(true)))
}

///|
test "not succeeds when its expression is false" {
  let result = @eval.eval_query(
    "not input.enabled",
    @value.Value::Object({ "enabled": @value.Value::boolean(false) }),
    @eval.EvalOptions::new(100),
  )
  assert_true(result.values()[0].equal(@value.Value::boolean(true)))
}

///|
test "step budget exhaustion returns a structured error" {
  let result = @eval.eval_query(
    "input.enabled",
    @value.Value::Object({ "enabled": @value.Value::boolean(true) }),
    @eval.EvalOptions::new(0),
  )
  assert_eq(result.values().length(), 0)
  assert_eq(result.diagnostics().length(), 1)
  assert_eq(result.diagnostics()[0].code(), "rego_eval_step_limit")
}

///|
test "undefined references remain distinct from JSON null" {
  let input : @value.Value = @value.Value::Object({
    "present": @value.Value::null(),
  })
  let present = @eval.eval_query(
    "input.present",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(present.values().length(), 1)
  assert_eq(present.values()[0].kind_name(), "null")
  let missing = @eval.eval_query(
    "input.missing",
    input,
    @eval.EvalOptions::new(100),
  )
  assert_eq(missing.values().length(), 0)
}

///|
test "final query expression can return the boolean false value" {
  let result = @eval.eval_query(
    "input.enabled",
    @value.Value::Object({ "enabled": @value.Value::boolean(false) }),
    @eval.EvalOptions::new(100),
  )
  assert_eq(result.values().length(), 1)
  assert_true(result.values()[0].equal(@value.Value::boolean(false)))
}
