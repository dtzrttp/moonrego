///|
test "undefined is not part of the Rego value model" {
  let null_value = @value.Value::null()
  assert_true(null_value is @value.Value::Null)
  assert_eq(null_value.kind_name(), "null")
}

///|
test "sets normalize duplicate values" {
  let one = @value.Value::number(@value.Number::parse("1").unwrap())
  let set = @value.Value::set([one, one])
  assert_eq(set.elements().length(), 1)
}
