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
