///|
async test "input_output_of_bytes supports seek and flush" {
  let (output, buffer) = @pdfio.input_output_of_bytes(1)
  (output.output_string)("abc")
  (output.seek_out)(0)
  (output.output_byte)('z'.to_int())
  (output.seek_out)(3)
  assert_eq((output.out_channel_length)(), 3)
  (output.flush)()
  let out = @pdfio.extract_bytes_from_input_output(output, buffer)
  assert_eq(@pdfio.string_of_bytes(out), "zbc")
}

///|
test "write_bitstream_append_aligned handles empty source" {
  let a = @pdfio.make_write_bitstream()
  @pdfio.putval(a, 8, 0xaa)
  let b = @pdfio.make_write_bitstream()
  let combined = @pdfio.write_bitstream_append_aligned(a, b)
  let bytes = @pdfio.bytes_of_write_bitstream(combined)
  assert_eq(bytes.length(), 1)
  assert_eq(@pdfio.bget(bytes, 0), 0xaa)
}

///|
test "getval_31 reads bits" {
  let bytes = @pdfio.bytes_of_list([0x80])
  let input = @pdfio.input_of_bytes(bytes)
  let stream = @pdfio.bitbytes_of_input(input)
  assert_eq(@pdfio.getval_31(stream, 1), 1)
}

///|
test "debug_next_n_chars rewinds input" {
  let input = @pdfio.input_of_string("abc")
  @pdfio.debug_next_n_chars(2, input)
  match (input.input_char)() {
    Some('a') => ()
    _ => fail("expected rewind to start")
  }
}
