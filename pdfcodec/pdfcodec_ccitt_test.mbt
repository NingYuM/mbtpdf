///|
fn assert_bytes_eq(
  expected : @pdfio.MutableBytes,
  actual : @pdfio.MutableBytes,
) -> Unit raise {
  assert_eq(@pdfio.bytes_size(actual), @pdfio.bytes_size(expected))
  for i in 0..<expected.length() {
    assert_eq(actual[i].to_int(), expected[i].to_int())
  }
}

///|
fn bytes_from_runs(
  start_white : Bool,
  runs : Array[Int],
) -> @pdfio.MutableBytes {
  let writer = @pdfio.make_write_bitstream()
  let mut white = start_white
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
fn build_runs() -> Array[Int] {
  let runs = Array::new()
  for i = 1; i <= 63; i = i + 1 {
    runs.push(i)
  }
  for v = 64; v <= 2560; v = v + 64 {
    runs.push(v)
  }
  runs
}

///|
fn bytes_from_rows(rows : Array[Array[Int]]) -> @pdfio.MutableBytes {
  let writer = @pdfio.make_write_bitstream()
  for row in rows {
    let mut white = true
    for run in row {
      let bit = if white { 1 } else { 0 }
      for _ in 0..<run {
        @pdfio.putbit(writer, bit)
      }
      white = !white
    }
    @pdfio.align_write(writer)
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
test "decode_from_input CCITT Group4 triggers pass mode" {
  let columns = 16
  let rows = 2
  let raw = bytes_from_rows([[4, 2, 10], [8, 2, 6]])
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
  let input = @pdfio.input_of_bytes(encoded, source="ccitt-g4-pass")
  match decode_from_input(input, dict) {
    Some(decoded) => assert_bytes_eq(raw, decoded)
    None => fail("expected CCITT pass decode")
  }
}

///|
test "decode_from_input CCITT Group4 triggers vertical modes" {
  let columns = 16
  let rows = 4
  let raw = bytes_from_rows([[5, 5, 6], [7, 3, 6], [10, 1, 5], [7, 3, 6]])
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
  let input = @pdfio.input_of_bytes(encoded, source="ccitt-g4-vertical")
  match decode_from_input(input, dict) {
    Some(decoded) => assert_bytes_eq(raw, decoded)
    None => fail("expected CCITT vertical decode")
  }
}

///|
test "decode_from_input CCITT Group3 varied runs" {
  let runs = build_runs()
  let mut columns = 0
  for run in runs {
    columns = columns + run
  }
  let raw = bytes_from_runs(true, runs)
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
test "decode_from_input CCITT Group3 shifted runs" {
  let runs = build_runs()
  let mut columns = 0
  for run in runs {
    columns = columns + run
  }
  let raw = bytes_from_runs(false, runs)
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
  let input = @pdfio.input_of_bytes(encoded, source="ccitt-g3-shifted")
  match decode_from_input(input, dict) {
    Some(decoded) => assert_bytes_eq(raw, decoded)
    None => fail("expected CCITT shifted run decode")
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

///|
test "decode_from_input CCITT rejects k > 0" {
  let dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/CCITTFaxDecode")),
    (
      "/DecodeParms",
      @pdf.PdfObject::Dictionary([
        ("/K", @pdf.PdfObject::Integer(1)),
        ("/Columns", @pdf.PdfObject::Integer(8)),
        ("/Rows", @pdf.PdfObject::Integer(1)),
      ]),
    ),
  ])
  let input = @pdfio.input_of_bytes(@pdfio.bytes_of_list([0xff]))
  let res = decode_from_input(input, dict)
  assert_true(res is None)
}

///|
test "decode_from_input CCITT rejects malformed data" {
  let dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/CCITTFaxDecode")),
    (
      "/DecodeParms",
      @pdf.PdfObject::Dictionary([
        ("/K", @pdf.PdfObject::Integer(0)),
        ("/Columns", @pdf.PdfObject::Integer(8)),
        ("/Rows", @pdf.PdfObject::Integer(1)),
      ]),
    ),
  ])
  let input = @pdfio.input_of_bytes(@pdfio.bytes_of_list([0x00, 0x00]))
  let res = decode_from_input(input, dict)
  assert_true(res is None)
}
