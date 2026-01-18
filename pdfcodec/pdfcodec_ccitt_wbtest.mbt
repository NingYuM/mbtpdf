///|
fn bitmap_bytes(
  rows_bits : Array[Array[Int]],
  columns : Int,
) -> @pdfio.MutableBytes raise {
  let output = @pdfio.make_write_bitstream()
  for row in rows_bits {
    assert_eq(row.length(), columns)
    for bit in row {
      @pdfio.putbit(output, bit)
    }
    @pdfio.align_write(output)
  }
  @pdfio.bytes_of_write_bitstream(output)
}

///|
fn assert_bytes_eq(
  left : @pdfio.MutableBytes,
  right : @pdfio.MutableBytes,
) -> Unit raise {
  assert_eq(left.length(), right.length())
  for i = 0; i < left.length(); i = i + 1 {
    assert_eq(left[i], right[i])
  }
}

///|
test "ccitt g3 roundtrip" {
  let columns = 8
  let rows = 2
  let rows_bits = [[1, 1, 1, 1, 0, 0, 1, 0], [1, 0, 1, 0, 1, 0, 1, 0]]
  let raw = bitmap_bytes(rows_bits, columns)
  let encoded = encode_ccitt(columns, rows, raw)
  let decoded = decode_ccittfax(
    0,
    false,
    false,
    columns,
    rows,
    true,
    false,
    0,
    @pdfio.input_of_bytes(encoded, source="ccitt-g3"),
  )
  assert_bytes_eq(decoded, raw)
}

///|
test "ccitt g4 roundtrip" {
  let columns = 8
  let rows = 2
  let rows_bits = [[1, 0, 1, 0, 1, 0, 1, 0], [1, 1, 0, 0, 1, 1, 0, 0]]
  let raw = bitmap_bytes(rows_bits, columns)
  let encoded = encode_ccittg4(columns, rows, raw)
  let decoded = decode_ccittfax(
    -1,
    false,
    false,
    columns,
    rows,
    true,
    false,
    0,
    @pdfio.input_of_bytes(encoded, source="ccitt-g4"),
  )
  assert_bytes_eq(decoded, raw)
}
