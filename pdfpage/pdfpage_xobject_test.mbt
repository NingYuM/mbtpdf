///|
test "process_xobjects updates form xobject stream" {
  let pdf = @pdf.empty()
  let stream_dict = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Form")),
    ("/Filter", @pdf.PdfObject::Name("/FlateDecode")),
  ])
  let data = @pdfio.bytes_of_list([0x01, 0x02])
  let stream = @pdf.PdfObject::Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(data))),
  )
  let xobj_num = @pdf.addobj(pdf, stream)
  let resources = @pdf.PdfObject::Dictionary([
    (
      "/XObject",
      @pdf.PdfObject::Dictionary([("/X1", @pdf.PdfObject::Indirect(xobj_num))]),
    ),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: @pdf.PdfObject::Array([
      @pdf.PdfObject::Real(0.0),
      @pdf.PdfObject::Real(0.0),
      @pdf.PdfObject::Real(10.0),
      @pdf.PdfObject::Real(20.0),
    ]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let bbox = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(20.0),
  ])
  let update = fn(_ : @pdf.Pdf, _ : @pdf.PdfObject, _ : Array[@pdf.PdfObject]) {
    let dict_updated = @pdf.PdfObject::Dictionary([
      ("/BBox", bbox),
      ("/Filter", @pdf.PdfObject::Name("/ASCIIHexDecode")),
    ])
    let updated_data = @pdfio.bytes_of_list([0x41, 0x42])
    [
      @pdf.PdfObject::Stream(
        Ref::new((dict_updated, @pdf.Stream::Got(updated_data))),
      ),
    ]
  }
  @pdfpage.process_xobjects(pdf, page, update)
  let updated = @pdf.lookup_obj(pdf, xobj_num)
  match @pdf.lookup_direct(pdf, "/Subtype", updated) {
    Some(@pdf.PdfObject::Name("/Form")) => ()
    _ => fail("expected /Form subtype")
  }
  match @pdf.lookup_direct(pdf, "/BBox", updated) {
    Some(@pdf.PdfObject::Array(_)) => ()
    _ => fail("expected bbox")
  }
  match @pdf.lookup_direct(pdf, "/Filter", updated) {
    None => ()
    _ => fail("expected filter removal")
  }
  let updated_bytes = @pdf.bigarray_of_stream(updated)
  assert_eq(@pdfio.int_array_of_bytes(updated_bytes), [0x41, 0x42])
}

///|
test "combine_pdf_resources merges known and keeps unknown" {
  let pdf = @pdf.empty()
  let a = @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("/F1", @pdf.PdfObject::Null)])),
    ("/Foo", @pdf.PdfObject::Integer(1)),
  ])
  let b = @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("/F2", @pdf.PdfObject::Null)])),
    ("/Bar", @pdf.PdfObject::Name("/Baz")),
  ])
  let combined = @pdfpage.combine_pdf_resources(pdf, a, b)
  match @pdf.lookup_direct(pdf, "/Font", combined) {
    Some(@pdf.PdfObject::Dictionary(entries)) => assert_eq(entries.length(), 2)
    _ => fail("expected merged fonts")
  }
  match @pdf.lookup_direct(pdf, "/Foo", combined) {
    Some(@pdf.PdfObject::Integer(1)) => ()
    _ => fail("expected /Foo")
  }
  match @pdf.lookup_direct(pdf, "/Bar", combined) {
    Some(@pdf.PdfObject::Name("/Baz")) => ()
    _ => fail("expected /Bar")
  }
}
