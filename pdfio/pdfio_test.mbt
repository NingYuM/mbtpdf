///|
test "raw bytes roundtrip" {
  let bytes = bytes_of_string("abc")
  let raw = raw_of_bytes(bytes)
  let back = bytes_of_raw(raw)
  assert_eq(string_of_bytes(back), "abc")
}
