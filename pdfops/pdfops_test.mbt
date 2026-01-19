///|
test "string_of_ops renders basic operators" {
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::Opw(2.0),
    @pdfops.Op::Opq,
    @pdfops.Op::OpQ,
  ])
  assert_true(rendered.contains("w"))
  assert_true(rendered.contains("q"))
  assert_true(rendered.contains("Q"))
}

///|
test "stream_of_ops builds a stream" {
  let stream = @pdfops.stream_of_ops([@pdfops.Op::Opq, @pdfops.Op::OpQ])
  match stream {
    @pdf.PdfObject::Stream(r) => {
      let (dict, contents) = r.val
      match @pdf.lookup_direct(@pdf.empty(), "/Length", dict) {
        Some(@pdf.PdfObject::Integer(length)) => assert_true(length > 0)
        _ => fail("expected /Length")
      }
      match contents {
        @pdf.Stream::Got(bytes) => {
          let text = @pdfio.string_of_bytes(bytes)
          assert_true(text.contains("q"))
          assert_true(text.contains("Q"))
        }
        _ => fail("expected stream bytes")
      }
    }
    _ => fail("expected stream object")
  }
}

///|
test "components resolves color spaces" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    (
      "/ColorSpace",
      @pdf.PdfObject::Dictionary([
        ("/MyCS", @pdf.PdfObject::Name("/DeviceGray")),
      ]),
    ),
  ])
  assert_eq(
    @pdfops.components(pdf, resources, @pdf.PdfObject::Name("/DeviceRGB")),
    3,
  )
  assert_eq(
    @pdfops.components(pdf, resources, @pdf.PdfObject::Name("/MyCS")),
    1,
  )
  assert_eq(
    @pdfops.components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Pattern"),
        @pdf.PdfObject::Name("/DeviceRGB"),
      ]),
    ),
    3,
  )
  assert_eq(
    @pdfops.components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/ICCBased"),
        @pdf.PdfObject::Dictionary([("/N", @pdf.PdfObject::Integer(4))]),
      ]),
    ),
    4,
  )
  assert_eq(
    @pdfops.components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/DeviceN"),
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Name("/A"),
          @pdf.PdfObject::Name("/B"),
        ]),
      ]),
    ),
    2,
  )
  assert_eq(
    @pdfops.components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Separation"),
        @pdf.PdfObject::Name("/Spot"),
        @pdf.PdfObject::Name("/DeviceRGB"),
        @pdf.PdfObject::Dictionary([]),
      ]),
    ),
    1,
  )
  let pattern_err : Result[Int, Error] = try? @pdfops.components(
    pdf,
    resources,
    @pdf.PdfObject::Name("/Pattern"),
  )
  assert_true(pattern_err is Err(_))
}

///|
test "parse_single_stream reads basic ops" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_string("1 w q 0 0 m 10 0 l S Q")
  let ops = @pdfops.parse_single_stream(pdf, resources, data)
  match ops[0] {
    @pdfops.Op::Opw(value) => assert_eq(value, 1.0)
    _ => fail("expected Opw")
  }
  match ops[1] {
    @pdfops.Op::Opq => ()
    _ => fail("expected Opq")
  }
  assert_true(
    ops.exists(op => match op {
      @pdfops.Op::OpS => true
      _ => false
    }),
  )
}

///|
test "parse_operators roundtrips stream_of_ops" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let ops_in = [@pdfops.Op::Opq, @pdfops.Op::Opw(2.0), @pdfops.Op::OpQ]
  let stream = @pdfops.stream_of_ops(ops_in)
  let ops = @pdfops.parse_operators(pdf, resources, [stream])
  assert_true(ops.length() >= 3)
  match ops[0] {
    @pdfops.Op::Opq => ()
    _ => fail("expected Opq")
  }
  match ops[1] {
    @pdfops.Op::Opw(value) => assert_eq(value, 2.0)
    _ => fail("expected Opw")
  }
  match ops[2] {
    @pdfops.Op::OpQ => ()
    _ => fail("expected OpQ")
  }
}

///|
test "parse_stream concatenates multiple streams" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let ops = @pdfops.parse_stream(pdf, resources, [
    @pdfio.bytes_of_string("q"),
    @pdfio.bytes_of_string("Q"),
  ])
  assert_true(ops.length() >= 2)
  match ops[0] {
    @pdfops.Op::Opq => ()
    _ => fail("expected Opq")
  }
  match ops[1] {
    @pdfops.Op::OpQ => ()
    _ => fail("expected OpQ")
  }
}
