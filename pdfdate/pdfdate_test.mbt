///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
test "date_of_string parses full utc" {
  let date = date_of_string("D:20240203040506Z")
  assert_eq(date.year, 2024)
  assert_eq(date.month, 2)
  assert_eq(date.day, 3)
  assert_eq(date.hour, 4)
  assert_eq(date.minute, 5)
  assert_eq(date.second, 6)
  assert_eq(date.hour_offset, 0)
  assert_eq(date.minute_offset, 0)
  assert_eq(string_of_date(date), "D:20240203040506Z")
}

///|
test "date_of_string parses offsets and defaults" {
  let offset = date_of_string("D:20240102030405+02'30'")
  assert_eq(offset.hour_offset, 2)
  assert_eq(offset.minute_offset, 30)
  assert_eq(string_of_date(offset), "D:20240102030405+02'30'")
  let minimal = date_of_string("D:20240102")
  assert_eq(minimal.year, 2024)
  assert_eq(minimal.month, 1)
  assert_eq(minimal.day, 2)
  assert_eq(minimal.hour, 0)
  assert_eq(minimal.minute, 0)
  assert_eq(minimal.second, 0)
  assert_eq(string_of_date(minimal), "D:20240102000000Z")
}

///|
test "date_of_string special 19100" {
  let special = date_of_string("D:19100")
  assert_eq(special.year, 2000)
  assert_eq(special.month, 1)
  assert_eq(special.day, 1)
  assert_eq(string_of_date(special), "D:20000101000000Z")
}

///|
test "date_of_string rejects invalid" {
  assert_is_err(try? date_of_string("D:20A4"))
}
