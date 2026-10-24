///|
test "JSON conversion preserves exact number text" {
  let json = @json.parse(
    "{\"id\":9007199254740993,\"ratio\":1.2500e2}",
    preserve_number_repr=true,
  )
  let value = @value.Value::from_json(json).unwrap()
  match value {
    Object(fields) => {
      match fields.get("id") {
        Some(Number(number)) =>
          assert_eq(number.to_canonical_string(), "9007199254740993")
        _ => abort("id should be an exact number")
      }
      match fields.get("ratio") {
        Some(Number(number)) => assert_eq(number.to_canonical_string(), "125")
        _ => abort("ratio should be an exact number")
      }
    }
    _ => abort("JSON object expected")
  }
  let round_trip = value.to_json().stringify()
  assert_eq(round_trip, "{\"id\":9007199254740993,\"ratio\":125}")
}

///|
test "JSON arrays preserve nested values and booleans" {
  let json = @json.parse(
    "[null,true,\"MoonBit\",[2]]",
    preserve_number_repr=true,
  )
  let value = @value.Value::from_json(json).unwrap()
  assert_eq(value.kind_name(), "array")
  assert_eq(value.elements().length(), 4)
  assert_eq(value.to_json().stringify(), "[null,true,\"MoonBit\",[2]]")
}
