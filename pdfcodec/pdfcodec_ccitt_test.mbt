///|
fn assert_bytes_eq(
  expected : @pdfio.MutableBytes,
  actual : @pdfio.MutableBytes,
) -> Unit raise {
  assert_eq(@pdfio.bytes_size(actual), @pdfio.bytes_size(expected))
  for i = 0; i < expected.length(); i = i + 1 {
    assert_eq(actual[i].to_int(), expected[i].to_int())
  }
}

///|
fn bytes_from_runs(runs : Array[Int]) -> @pdfio.MutableBytes {
  let writer = @pdfio.make_write_bitstream()
  let mut white = true
  for run in runs {
    let bit = if white { 1 } else { 0 }
    for _ in 0..<run {
      @pdfio.putbit(writer, bit)
    }
    white = !white
  }
  @pdfio.bytes_of_write_bitstream(writer)
}

///|
test "decode_from_input CCITT Group3 roundtrip" {
  let columns = 8
  let rows = 2
  let raw = @pdfio.bytes_of_list([0xF0, 0x0F])
  let encoded = encode_ccitt(columns, rows, raw)
  let dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/CCITTFaxDecode")),
    (
      "/DecodeParms",
      @pdf.PdfObject::Dictionary([
        ("/K", @pdf.PdfObject::Integer(0)),
        ("/Columns", @pdf.PdfObject::Integer(columns)),
        ("/Rows", @pdf.PdfObject::Integer(rows)),
      ]),
    ),
  ])
  let input = @pdfio.input_of_bytes(encoded, source="ccitt-g3")
  match decode_from_input(input, dict) {
    Some(decoded) => assert_bytes_eq(raw, decoded)
    None => fail("expected CCITT Group3 decode")
  }
}

///|
test "decode_from_input CCITT Group4 roundtrip" {
  let columns = 8
  let rows = 2
  let raw = @pdfio.bytes_of_list([0xAA, 0xAA])
  let encoded = encode_ccittg4(columns, rows, raw)
  let dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/CCITTFaxDecode")),
    (
      "/DecodeParms",
      @pdf.PdfObject::Dictionary([
        ("/K", @pdf.PdfObject::Integer(-1)),
        ("/Columns", @pdf.PdfObject::Integer(columns)),
        ("/Rows", @pdf.PdfObject::Integer(rows)),
      ]),
    ),
  ])
  let input = @pdfio.input_of_bytes(encoded, source="ccitt-g4")
  match decode_from_input(input, dict) {
    Some(decoded) => assert_bytes_eq(raw, decoded)
    None => fail("expected CCITT Group4 decode")
  }
}

///|
test "decode_from_input CCITT Group3 varied runs" {
  let runs = Array::new()
  let mut columns = 0
  for i = 1; i <= 32; i = i + 1 {
    runs.push(i)
    columns = columns + i
  }
  runs.push(64)
  columns = columns + 64
  runs.push(128)
  columns = columns + 128
  let raw = bytes_from_runs(runs)
  let encoded = encode_ccitt(columns, 1, raw)
  let dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/CCITTFaxDecode")),
    (
      "/DecodeParms",
      @pdf.PdfObject::Dictionary([
        ("/K", @pdf.PdfObject::Integer(0)),
        ("/Columns", @pdf.PdfObject::Integer(columns)),
        ("/Rows", @pdf.PdfObject::Integer(1)),
      ]),
    ),
  ])
  let input = @pdfio.input_of_bytes(encoded, source="ccitt-g3-runs")
  match decode_from_input(input, dict) {
    Some(decoded) => assert_bytes_eq(raw, decoded)
    None => fail("expected CCITT varied run decode")
  }
}

///|
test "encode_ccittg4 rejects imagemagick path" {
  let raw = @pdfio.bytes_of_list([0xFF])
  let res : Result[@pdfio.MutableBytes, Error] = try? encode_ccittg4(
    8,
    1,
    raw,
    im="magick",
  )
  assert_true(res is Err(_))
}

///|
test "decode_from_input returns None on unknown filter" {
  let dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/JBIG2Decode")),
  ])
  let input = @pdfio.input_of_bytes(@pdfio.bytes_of_string("data"))
  let res = decode_from_input(input, dict)
  assert_true(res is None)
}
