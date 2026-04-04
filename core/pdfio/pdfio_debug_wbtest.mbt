///|
async test "input_output_of_bytes supports seek and flush" {
  let (output, buffer) = Output::of_bytes(1)
  (output.output_string)("abc")
  (output.seek_out)(0)
  (output.output_byte)('z')
  (output.seek_out)(3)
  assert_eq((output.out_channel_length)(), 3)
  (output.flush)()
  let out = output.extract_bytes(buffer)
  assert_eq(string_of_bytes(out), "zbc")
}

///|
test "output_of_bytes grows across repeated resizes" {
  let payload = "a".repeat(20000)
  let (output, buffer) = Output::of_bytes(1)
  (output.output_string)(payload)
  (output.seek_out)(0)
  (output.output_byte)('b')
  (output.seek_out)(payload.length())
  let out = output.extract_bytes(buffer)
  assert_eq(out.length(), payload.length())
  assert_eq(out[0].to_int(), 'b')
  assert_eq(out[out.length() - 1].to_int(), 'a')
}

///|
test "debug_next_n_chars rewinds input" {
  let input = Input::of_string("abc")
  @pdfe.with_logger(_ => (), fn() { debug_next_n_chars(2, input) })
  match (input.input_char)() {
    Some('a') => ()
    _ => fail("expected rewind to start")
  }
}
