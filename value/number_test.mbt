///|
test "decimal equality does not lose precision" {
  let a = @value.Number::parse("9007199254740993").unwrap()
  let b = @value.Number::parse("9007199254740992").unwrap()
  assert_false(a.equal(b))
  assert_true(a.compare(b) > 0)
}

///|
test "equivalent decimal spellings normalize equally" {
  let a = @value.Number::parse("1.2300").unwrap()
  let b = @value.Number::parse("123e-2").unwrap()
  assert_true(a.equal(b))
  assert_eq(a.to_canonical_string(), "1.23")
  assert_eq(b.to_canonical_string(), "1.23")
}

///|
test "exact decimal addition aligns scales" {
  let a = @value.Number::parse("0.1").unwrap()
  let b = @value.Number::parse("0.02").unwrap()
  assert_eq(a.add(b).to_canonical_string(), "0.12")
}

///|
test "invalid JSON number is rejected" {
  assert_true(@value.Number::parse("01") is None)
  assert_true(@value.Number::parse("1e") is None)
  assert_true(@value.Number::parse("NaN") is None)
}

///|
test "negates exact decimals without changing their scale" {
  let number = @value.Number::parse("12.50").unwrap()
  assert_eq(number.negate().to_canonical_string(), "-12.5")
}
