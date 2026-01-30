///|
test "bytes_of_charlist and bytes_of_arraylist" {
  let bytes = bytes_of_charlist(['A', 'B'])
  assert_eq(string_of_bytes(bytes), "AB")
  let arrays : Array[Array[Int]] = [[65, 66], [67]]
  let bytes2 = bytes_of_arraylist(arrays)
  assert_eq(string_of_bytes(bytes2), "ABC")
}

///|
test "copybytes returns an independent buffer" {
  let bytes = bytes_of_string("ab")
  let copied = copybytes(bytes)
  bset(copied, 0, 'z')
  assert_eq(string_of_bytes(copied), "zb")
  assert_eq(string_of_bytes(bytes), "ab")
}

///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
test "input utils handle EOF and rewind paths" {
  let empty = Input::of_string("", source="empty")
  assert_eq(getuntil(true, _ => true, empty).length(), 0)
  let input_chars = Input::of_string("ab ", source="getuntil")
  let chars = getuntil(true, c => c == ' ', input_chars)
  assert_eq(chars.map(c => c.to_string()).join(""), "ab")
  match (input_chars.input_byte)() {
    b if b == ' ' => ()
    _ => fail("expected getuntil rewind")
  }
  let input = Input::of_string("abc", source="rewind")
  let out = getuntil_string(true, c => c == 'a', input)
  assert_eq(out, "")
  match (input.input_byte)() {
    b if b == 'a' => ()
    _ => fail("expected rewind")
  }
  assert_is_err(
    try? getuntil_string(
      false,
      _ => false,
      Input::of_string("abc", source="eof-string"),
    ),
  )
  let eof_fail = Input::of_string("", source="eof")
  assert_is_err(try? ignoreuntil(false, _ => true, eof_fail))
  let line = input_line(Input::of_string("", source="line"))
  assert_eq(line, "")
  assert_is_err(try? backline(Input::of_string("", source="backline")))
  assert_is_err(try? read_chunk(5, Input::of_string("abc", source="chunk")))
}
