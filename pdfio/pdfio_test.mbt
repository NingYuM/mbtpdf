///|
test "raw bytes roundtrip" {
  let bytes = bytes_of_string("abc")
  let raw = raw_of_bytes(bytes)
  let back = bytes_of_raw(raw)
  assert_eq(string_of_bytes(back), "abc")
}

///|
test "bytes and int array conversions" {
  let bytes = bytes_of_list([65, 66, 67])
  assert_eq(bytes_size(bytes), 3)
  assert_eq(string_of_bytes(bytes), "ABC")
  let ints = int_array_of_bytes(bytes)
  assert_eq(ints.length(), 3)
  assert_eq(ints[0], 65)
  assert_eq(ints[2], 67)
  let roundtrip = bytes_of_int_array(ints)
  assert_eq(string_of_bytes(roundtrip), "ABC")
}

///|
test "string_of_int_arrays flattens" {
  let s = string_of_int_arrays([[65], [66, 67]])
  assert_eq(s, "ABC")
}

///|
test "input_of_string supports read_line" {
  let input = input_of_string("first\nsecond")
  assert_eq(read_line(input), "first")
  assert_eq(read_line(input), "second")
  let res : Result[String, Error] = try? read_line(input)
  assert_true(res is Err(_))
}

///|
test "peek_char and read_char_back" {
  let input = input_of_string("ab")
  assert_eq(peek_char(input), Some('a'))
  let _ = (input.input_char)()
  let back = read_char_back(input)
  assert_eq(back, Some('a'))
}
