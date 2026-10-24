///|
test "span joins two source ranges" {
  let left = @diagnostic.SourceSpan::new(
    "policy.rego",
    start_offset=0,
    start_line=1,
    start_column=1,
    end_offset=4,
    end_line=1,
    end_column=5,
  )
  let right = @diagnostic.SourceSpan::new(
    "policy.rego",
    start_offset=5,
    start_line=1,
    start_column=6,
    end_offset=9,
    end_line=1,
    end_column=10,
  )
  let joined = left.join(right)
  assert_eq(joined.start_offset(), 0)
  assert_eq(joined.end_offset(), 9)
  assert_eq(joined.start_line(), 1)
  assert_eq(joined.end_column(), 10)
}

///|
test "span refuses to join different files" {
  let left = @diagnostic.SourceSpan::point("a.rego", 0, 1, 1)
  let right = @diagnostic.SourceSpan::point("b.rego", 0, 1, 1)
  debug_inspect(left.try_join(right), content="None")
}
