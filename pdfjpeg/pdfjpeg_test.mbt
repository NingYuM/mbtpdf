///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
test "get_jpeg_data reads until marker" {
  let bytes : Array[Byte] = [
    b'\xff', b'\xd8', b'\x00', b'\xff', b'\xd9', b'\x11',
  ]
  let input = @pdfio.input_of_bytes(bytes, source="jpeg")
  let data = get_jpeg_data(input)
  assert_eq(data.length(), 5)
  assert_eq(data[0].to_int(), 0xff)
  assert_eq(data[4].to_int(), 0xd9)
  assert_eq((input.pos_in)(), 5)
}

///|
test "get_jpeg_data errors on missing end" {
  let bytes : Array[Byte] = [b'\xff', b'\xd8', b'\x00']
  let input = @pdfio.input_of_bytes(bytes, source="jpeg")
  assert_is_err(try? get_jpeg_data(input))
}
