///|
fn make_resources() -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([])
}

///|
test "parse_single_stream basic ops" {
  let pdf = @pdf.empty()
  let resources = make_resources()
  let bytes = @pdfio.bytes_of_string("1 2 3 4 re S")
  let ops = parse_single_stream(pdf, resources, bytes)
  assert_eq(string_of_ops(ops), "1 2 3 4 re S")
}

///|
test "stream_of_ops roundtrip" {
  let pdf = @pdf.empty()
  let resources = make_resources()
  let ops : Array[Op] = [Op::Opq, Op::Opw(2.0), Op::OpQ]
  let stream_obj = stream_of_ops(ops)
  let bytes = match stream_obj {
    @pdf.PdfObject::Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(data)) => data
        _ => fail("expected in-memory stream data")
      }
    _ => fail("expected stream object")
  }
  let parsed = parse_single_stream(pdf, resources, bytes)
  assert_eq(string_of_ops(parsed), string_of_ops(ops))
}

///|
test "components device spaces" {
  let pdf = @pdf.empty()
  let resources = make_resources()
  assert_eq(components(pdf, resources, @pdf.PdfObject::Name("/DeviceGray")), 1)
  assert_eq(components(pdf, resources, @pdf.PdfObject::Name("/DeviceRGB")), 3)
  assert_eq(components(pdf, resources, @pdf.PdfObject::Name("/DeviceCMYK")), 4)
}

///|
test "components complex spaces" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    (
      "/ColorSpace",
      @pdf.PdfObject::Dictionary([
        (
          "/CS1",
          @pdf.PdfObject::Array([
            @pdf.PdfObject::Name("/Indexed"),
            @pdf.PdfObject::Name("/DeviceRGB"),
          ]),
        ),
      ]),
    ),
  ])
  assert_eq(components(pdf, resources, @pdf.PdfObject::Name("/CS1")), 1)
  let icc = @pdf.PdfObject::Dictionary([("/N", @pdf.PdfObject::Integer(4))])
  assert_eq(
    components(
      pdf,
      resources,
      @pdf.PdfObject::Array([@pdf.PdfObject::Name("/ICCBased"), icc]),
    ),
    4,
  )
  assert_eq(
    components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/DeviceN"),
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Name("/C1"),
          @pdf.PdfObject::Name("/C2"),
        ]),
      ]),
    ),
    2,
  )
  assert_eq(
    components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Separation"),
        @pdf.PdfObject::Name("/Spot"),
        @pdf.PdfObject::Name("/DeviceCMYK"),
        @pdf.PdfObject::Null,
      ]),
    ),
    1,
  )
}

///|
test "parse_single_stream text ops" {
  let pdf = @pdf.empty()
  let resources = make_resources()
  let content = "BT /F1 12 Tf 10 20 Td (Hi) Tj ET"
  let ops = parse_single_stream(pdf, resources, @pdfio.bytes_of_string(content))
  match ops {
    [Op::OpBT, Op::OpTf(_, _), Op::OpTd(_, _), Op::OpTj(_), Op::OpET] => ()
    _ => fail("unexpected text ops sequence")
  }
}

///|
test "parse_single_stream TJ array" {
  let pdf = @pdf.empty()
  let resources = make_resources()
  let content = "[(A) 120 (B)] TJ"
  let ops = parse_single_stream(pdf, resources, @pdfio.bytes_of_string(content))
  match ops {
    [Op::OpTJ(@pdf.PdfObject::Array(_))] => ()
    _ => fail("expected TJ array op")
  }
}
