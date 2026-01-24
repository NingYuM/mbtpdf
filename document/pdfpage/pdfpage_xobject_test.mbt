///|
test "process_xobjects updates form xobject stream" {
  let pdf = @pdf.Pdf::empty()
  let stream_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Form")),
    ("/Filter", Name("/FlateDecode")),
  ])
  let data = @pdfio.bytes_of_list([0x01, 0x02])
  let stream : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(data))),
  )
  let xobj_num = @pdf.addobj(pdf, stream)
  let resources : @pdf.PdfObject = Dictionary([
    ("/XObject", Dictionary([("/X1", Indirect(xobj_num))])),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let bbox : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(20.0),
  ])
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    let dict_updated : @pdf.PdfObject = Dictionary([
      ("/BBox", bbox),
      ("/Filter", Name("/ASCIIHexDecode")),
    ])
    let updated_data = @pdfio.bytes_of_list([0x41, 0x42])
    [Stream(Ref::new((dict_updated, @pdf.Stream::Got(updated_data))))]
  }
  page.process_xobjects(pdf, update)
  let updated = @pdf.lookup_obj(pdf, xobj_num)
  match (@pdf.lookup_direct(pdf, "/Subtype", updated) : @pdf.PdfObject?) {
    Some(Name("/Form")) => ()
    _ => fail("expected /Form subtype")
  }
  match (@pdf.lookup_direct(pdf, "/BBox", updated) : @pdf.PdfObject?) {
    Some(Array(_)) => ()
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
  let pdf = @pdf.Pdf::empty()
  let a : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F1", Null)])),
    ("/Foo", Integer(1)),
  ])
  let b : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F2", Null)])),
    ("/Bar", Name("/Baz")),
  ])
  let combined = @pdfpage.PdfPageDoc::new(pdf).combine_pdf_resources(a, b)
  match (@pdf.lookup_direct(pdf, "/Font", combined) : @pdf.PdfObject?) {
    Some(Dictionary(entries)) => assert_eq(entries.length(), 2)
    _ => fail("expected merged fonts")
  }
  match (@pdf.lookup_direct(pdf, "/Foo", combined) : @pdf.PdfObject?) {
    Some(Integer(1)) => ()
    _ => fail("expected /Foo")
  }
  match (@pdf.lookup_direct(pdf, "/Bar", combined) : @pdf.PdfObject?) {
    Some(Name("/Baz")) => ()
    _ => fail("expected /Bar")
  }
}
