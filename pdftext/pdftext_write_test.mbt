///|
fn type3_font_dict() -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type3")),
    ("/BaseFont", @pdf.PdfObject::Name("/TestFont")),
    (
      "/FontBBox",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(1.0),
      ]),
    ),
    (
      "/FontMatrix",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(0.001),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(0.001),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(0.0),
      ]),
    ),
    ("/CharProcs", @pdf.PdfObject::Dictionary([("/A", @pdf.PdfObject::Null)])),
    ("/FirstChar", @pdf.PdfObject::Integer(0)),
    ("/LastChar", @pdf.PdfObject::Integer(0)),
    ("/Widths", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(0)])),
    ("/FontDescriptor", @pdf.PdfObject::Dictionary([])),
  ])
}

///|
test "write_encoding handles builtins and custom diffs" {
  let pdf = @pdf.empty()
  let standard_encoding = @pdftext.read_encoding(pdf, standard_font_dict())
  let standard = @pdftext.write_encoding(pdf, standard_encoding)
  match @pdf.lookup_obj(pdf, standard) {
    @pdf.PdfObject::Name("/StandardEncoding") => ()
    _ => fail("expected StandardEncoding name")
  }
  let custom_encoding = @pdftext.read_encoding(pdf, custom_encoding_font_dict())
  let custom = @pdftext.write_encoding(pdf, custom_encoding)
  match @pdf.lookup_obj(pdf, custom) {
    @pdf.PdfObject::Dictionary(_) as dict =>
      match @pdf.lookup_direct(pdf, "/Differences", dict) {
        Some(@pdf.PdfObject::Array(values)) => assert_true(values.length() >= 2)
        _ => fail("expected /Differences")
      }
    _ => fail("expected encoding dictionary")
  }
  let implicit = @pdftext.read_encoding(
    pdf,
    @pdf.PdfObject::Dictionary([("/Subtype", @pdf.PdfObject::Name("/Type0"))]),
  )
  let implicit_result : Result[Int, Error] = try? @pdftext.write_encoding(
    pdf, implicit,
  )
  assert_true(implicit_result is Err(_))
}

///|
test "hex and tounicode_map encode bytes" {
  assert_eq(@pdftext.hex("A"), "41")
  let bytes = @pdftext.tounicode_map(33, ["A", "B"])
  let text = @pdfio.string_of_bytes(bytes)
  assert_true(text.contains("begincmap"))
  assert_true(text.contains("<21><21><41>"))
  assert_true(text.contains("<22><22><42>"))
}

///|
test "write_font handles standard and type3 fonts" {
  let pdf = @pdf.empty()
  let standard_font = @pdftext.read_font(pdf, win_ansi_font_dict())
  let standard = @pdftext.write_font(pdf, standard_font)
  match @pdf.lookup_obj(pdf, standard) {
    @pdf.PdfObject::Dictionary(_) as dict =>
      match @pdf.lookup_direct(pdf, "/BaseFont", dict) {
        Some(@pdf.PdfObject::Name("/Helvetica")) => ()
        _ => fail("expected /BaseFont /Helvetica")
      }
    _ => fail("expected font dictionary")
  }
  let type3_font = @pdftext.read_font(pdf, type3_font_dict())
  let type3_num = @pdftext.write_font(pdf, type3_font)
  match @pdf.lookup_obj(pdf, type3_num) {
    @pdf.PdfObject::Dictionary(_) as dict =>
      match @pdf.lookup_direct(pdf, "/Subtype", dict) {
        Some(@pdf.PdfObject::Name("/Type3")) => ()
        _ => fail("expected /Subtype /Type3")
      }
    _ => fail("expected Type3 font dictionary")
  }
}
