///|
fn build_minimal_pdf() -> @pdf.Pdf {
  let pdf : @pdf.Pdf = {
    major: 2,
    minor: 0,
    root: 4,
    objects: {
      max_obj_num: 0,
      parse: None,
      objects: @pdf.pdfobjmap_empty(),
      object_stream_ids: Map::new(),
    },
    trailerdict: @pdf.PdfObject::Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
  }
  let content = "BT /F0 12 Tf (Hello) Tj ET\n"
  let stream_bytes = @pdfio.bytes_of_string(content)
  let stream_dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(stream_bytes))),
  ])
  let stream_obj = @pdf.PdfObject::Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(stream_bytes))),
  )
  let font_dict = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Font")),
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/BaseFont", @pdf.PdfObject::Name("/Times-Roman")),
  ])
  let resources = @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("/F0", font_dict)])),
  ])
  let page = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Page")),
    ("/Parent", @pdf.PdfObject::Indirect(1)),
    ("/Resources", resources),
    (
      "/MediaBox",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Integer(0),
        @pdf.PdfObject::Integer(0),
        @pdf.PdfObject::Integer(300),
        @pdf.PdfObject::Integer(300),
      ]),
    ),
    ("/Contents", @pdf.PdfObject::Indirect(2)),
  ])
  let pages = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Pages")),
    ("/Kids", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(3)])),
    ("/Count", @pdf.PdfObject::Integer(1)),
  ])
  let catalog = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Catalog")),
    ("/Pages", @pdf.PdfObject::Indirect(1)),
  ])
  @pdf.addobj_given_num(pdf, (1, pages))
  @pdf.addobj_given_num(pdf, (2, stream_obj))
  @pdf.addobj_given_num(pdf, (3, page))
  @pdf.addobj_given_num(pdf, (4, catalog))
  pdf
}

///|
fn roundtrip(pdf : @pdf.Pdf) -> @pdf.Pdf raise {
  let (output, buffer) = @pdfio.input_output_of_bytes(512)
  @pdfwrite.pdf_to_output(_encryption=None, _build_new_id=false, pdf, output)
  let pdf_bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let input = @pdfio.input_of_bytes(pdf_bytes, source="roundtrip")
  @pdfread.pdf_of_input(
    revision=None,
    user_password=None,
    owner_password=None,
    input,
  )
}

///|
test "pdf roundtrip read/write/read" {
  let pdf1 = build_minimal_pdf()
  let pdf2 = roundtrip(pdf1)
  let pdf3 = roundtrip(pdf2)
  assert_eq(@pdf.objcard(pdf2), 4)
  assert_eq(@pdf.objcard(pdf3), 4)
  assert_eq(pdf2.root, 4)
  assert_eq(pdf3.root, 4)
}
