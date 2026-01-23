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

///|
test "read_lines reads all lines" {
  let input = input_of_string("first\nsecond\n")
  let lines = read_lines(input)
  assert_eq(lines, ["first", "second"])
}

///|
test "setinit and bytes_of_input read slices" {
  let input = input_of_string("abcd")
  let buf = mkbytes(4)
  setinit(input, buf, 0, 4)
  assert_eq(string_of_bytes(buf), "abcd")
  let input2 = input_of_string("abcd")
  let slice = bytes_of_input(input2, 1, 2)
  assert_eq(string_of_bytes(slice), "bc")
  let res : Result[Unit, Error] = try? setinit(input2, buf, 10, 1)
  assert_true(res is Err(_))
}

///|
test "string_of_input and getinit write output" {
  let input = input_of_string("xyz")
  assert_eq(string_of_input(input), "xyz")
  let data = bytes_of_string("hi")
  let (output, buffer) = input_output_of_bytes(2)
  getinit(output, data, 0, data.length())
  let out = extract_bytes_from_input_output(output, buffer)
  assert_eq(string_of_bytes(out), "hi")
}
