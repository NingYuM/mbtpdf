///|
test "string_of_date formats offsets" {
  let base = @pdfdate.date_of_string("D:20240102030405Z")
  assert_eq(@pdfdate.string_of_date(base), "D:20240102030405Z")
  let positive = @pdfdate.date_of_string("D:20240102030405+05'30'")
  assert_eq(@pdfdate.string_of_date(positive), "D:20240102030405+05'30'")
  let negative = @pdfdate.date_of_string("D:20240102030405-07'15'")
  assert_eq(@pdfdate.string_of_date(negative), "D:20240102030405-07'15'")
}

///|
test "date_of_string parses full dates" {
  let parsed = @pdfdate.date_of_string("D:20240203040506-07'15'")
  assert_eq(parsed.year, 2024)
  assert_eq(parsed.month, 2)
  assert_eq(parsed.day, 3)
  assert_eq(parsed.hour, 4)
  assert_eq(parsed.minute, 5)
  assert_eq(parsed.second, 6)
  assert_eq(parsed.hour_offset, -7)
  assert_eq(parsed.minute_offset, -15)
}

///|
test "date_of_string parses short forms" {
  let parsed = @pdfdate.date_of_string("2024")
  assert_eq(parsed.year, 2024)
  assert_eq(parsed.month, 1)
  assert_eq(parsed.day, 1)
  assert_eq(parsed.hour, 0)
  assert_eq(parsed.minute, 0)
  assert_eq(parsed.second, 0)
  assert_eq(parsed.hour_offset, 0)
  assert_eq(parsed.minute_offset, 0)
}

///|
test "date_of_string handles special 19100 year" {
  let parsed = @pdfdate.date_of_string("D:19100")
  assert_eq(parsed.year, 2000)
  assert_eq(parsed.month, 1)
  assert_eq(parsed.day, 1)
}

///|
test "date parsing rejects invalid values" {
  let bad_month : Result[@pdfdate.Date, Error] = try? @pdfdate.date_of_string(
    "D:20241301",
  )
  assert_true(bad_month is Err(_))
  let bad_format : Result[@pdfdate.Date, Error] = try? @pdfdate.date_of_string(
    "D:20A4",
  )
  assert_true(bad_format is Err(_))
}
