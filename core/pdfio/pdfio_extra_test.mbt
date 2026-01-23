///|
test "fillbytes and bytes_selfmap" {
  let bytes = @pdfio.mkbytes(3)
  @pdfio.fillbytes(65, bytes)
  assert_eq(@pdfio.string_of_bytes(bytes), "AAA")
  @pdfio.bytes_selfmap(value => value + 1, bytes)
  assert_eq(@pdfio.string_of_bytes(bytes), "BBB")
  let prev_logger = @pdfe.logger.val
  @pdfe.logger.val = _ => ()
  defer {
    @pdfe.logger.val = prev_logger
  }
  @pdfio.print_bytes(bytes)
}

///|
test "bytes_of_charlist and bytes_of_arraylist" {
  let bytes = @pdfio.bytes_of_charlist(['A', 'B'])
  assert_eq(@pdfio.string_of_bytes(bytes), "AB")
  let arrays : Array[Array[Int]] = [[65, 66], [67]]
  let bytes2 = @pdfio.bytes_of_arraylist(arrays)
  assert_eq(@pdfio.string_of_bytes(bytes2), "ABC")
}

///|
test "copybytes returns an independent buffer" {
  let bytes = @pdfio.bytes_of_string("ab")
  let copied = @pdfio.copybytes(bytes)
  @pdfio.bset(copied, 0, 'z'.to_int())
  assert_eq(@pdfio.string_of_bytes(copied), "zb")
  assert_eq(@pdfio.string_of_bytes(bytes), "ab")
}

///|
test "setinit_string and getinit error cases" {
  let input = @pdfio.input_of_string("abc")
  let buf = @pdfio.mkbytes(3)
  @pdfio.setinit_string(input, buf, 0, 3)
  assert_eq(@pdfio.string_of_bytes(buf), "abc")
  @pdfio.setinit(input, buf, 0, 0)
  let (output, buffer) = @pdfio.input_output_of_bytes(1)
  @pdfio.getinit(output, buf, 0, 0)
  let out = @pdfio.extract_bytes_from_input_output(output, buffer)
  assert_eq(out.length(), 0)
  let res : Result[Unit, Error] = try? @pdfio.getinit(output, buf, 10, 1)
  assert_true(res is Err(_))
}

///|
test "bitstream error paths" {
  let empty = @pdfio.mkbytes(0)
  let input = @pdfio.input_of_bytes(empty)
  let stream = @pdfio.bitbytes_of_input(input)
  let res_bit : Result[Bool, Error] = try? @pdfio.getbit(stream)
  assert_true(res_bit is Err(_))
  let res_val32 : Result[Int, Error] = try? @pdfio.getval_32(stream, -1)
  assert_true(res_val32 is Err(_))
  let res_val31 : Result[Int, Error] = try? @pdfio.getval_31(stream, -1)
  assert_true(res_val31 is Err(_))
}

///|
test "write_bitstream_append_aligned aligns and appends" {
  let a = @pdfio.make_write_bitstream()
  @pdfio.putval(a, 4, 10)
  let b = @pdfio.make_write_bitstream()
  @pdfio.putval(b, 8, 0xcc)
  let combined = @pdfio.write_bitstream_append_aligned(a, b)
  let bytes = @pdfio.bytes_of_write_bitstream(combined)
  assert_eq(bytes.length(), 2)
  assert_eq(@pdfio.bget(bytes, 0), 0xa0)
  assert_eq(@pdfio.bget(bytes, 1), 0xcc)
  let res : Result[Unit, Error] = try? @pdfio.putval(b, 40, 1)
  assert_true(res is Err(_))
}
