///|
test "eval requires a query and accepts input data and policy paths" {
  match
    @cli.parse_args([
      "eval", "input.role == \"admin\"", "--input", "request.json", "--data", "data.json",
      "--strict-builtin-errors", "--format", "json", "policy.rego",
    ]) {
    Ok(Eval(query, input, data, policies, strict, format)) => {
      assert_eq(query, "input.role == \"admin\"")
      assert_eq(input, Some("request.json"))
      assert_eq(data, Some("data.json"))
      assert_eq(policies, ["policy.rego"])
      assert_true(strict)
      assert_true(format is @cli.OutputFormat::Json)
    }
    _ => fail("expected an eval command")
  }
}

///|
test "eval requires at least one policy file" {
  match @cli.parse_args(["eval", "true"]) {
    Err(message) => assert_true(message.contains("policy"))
    _ => fail("expected a usage error")
  }
}

///|
test "check requires at least one policy file" {
  match @cli.parse_args(["check"]) {
    Err(message) => assert_true(message.contains("policy"))
    _ => fail("expected a usage error")
  }
}
