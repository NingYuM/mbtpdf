///|
test "bitstream write/read roundtrip" {
  let writer = @pdfio.make_write_bitstream()
  @pdfio.putval(writer, 4, 10)
  @pdfio.putval(writer, 4, 12)
  let bytes = @pdfio.bytes_of_write_bitstream(writer)
  assert_eq(bytes.length(), 1)
  assert_eq(@pdfio.bget(bytes, 0), 172)
  let input = @pdfio.input_of_bytes(bytes)
  let stream = @pdfio.bitbytes_of_input(input)
  assert_eq(@pdfio.getval_32(stream, 4), 10)
  assert_eq(@pdfio.getval_32(stream, 4), 12)
}

///|
test "bitstream seek restores position" {
  let bytes = @pdfio.bytes_of_list([0xaa, 0x55])
  let input = @pdfio.input_of_bytes(bytes)
  let stream = @pdfio.bitbytes_of_input(input)
  assert_eq(@pdfio.getval_32(stream, 3), 5)
  let pos = @pdfio.bitstream_pos(stream)
  let next = @pdfio.getval_32(stream, 5)
  assert_eq(next, 10)
  @pdfio.bitstream_seek(stream, pos)
  let next_again = @pdfio.getval_32(stream, 5)
  assert_eq(next_again, 10)
}

///|
test "align skips to next byte boundary" {
  let bytes = @pdfio.bytes_of_list([0xf0, 0x0f])
  let input = @pdfio.input_of_bytes(bytes)
  let stream = @pdfio.bitbytes_of_input(input)
  assert_eq(@pdfio.getval_32(stream, 4), 15)
  @pdfio.align(stream)
  assert_eq(@pdfio.getval_32(stream, 8), 15)
}
