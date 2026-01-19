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
