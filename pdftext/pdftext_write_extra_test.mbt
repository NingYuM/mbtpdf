///|
test "write_encoding covers mac and custom encodings" {
  let pdf = @pdf.empty()
  let macroman_encoding = @pdftext.read_encoding(
    pdf,
    font_with_encoding_name("/MacRomanEncoding"),
  )
  let macroman = @pdftext.write_encoding(pdf, macroman_encoding)
  match @pdf.lookup_obj(pdf, macroman) {
    @pdf.PdfObject::Name("/MacRomanEncoding") => ()
    _ => fail("expected /MacRomanEncoding")
  }
  let macexpert_encoding = @pdftext.read_encoding(
    pdf,
    font_with_encoding_name("/MacExpertEncoding"),
  )
  let macexpert = @pdftext.write_encoding(pdf, macexpert_encoding)
  match @pdf.lookup_obj(pdf, macexpert) {
    @pdf.PdfObject::Name("/MacExpertEncoding") => ()
    _ => fail("expected /MacExpertEncoding")
  }
  let filled_encoding = @pdftext.read_encoding(
    pdf,
    truetype_font_with_encoding_dict(),
  )
  let filled = @pdftext.write_encoding(pdf, filled_encoding)
  match @pdf.lookup_obj(pdf, filled) {
    @pdf.PdfObject::Name("/MacRomanEncoding") => ()
    _ => fail("expected filled encoding to reuse inner")
  }
  let custom_encoding = @pdftext.read_encoding(
    pdf,
    embedded_font_with_custom_encoding(),
  )
  let custom = @pdftext.write_encoding(pdf, custom_encoding)
  match @pdf.lookup_obj(pdf, custom) {
    @pdf.PdfObject::Dictionary(_) as dict => {
      assert_true(@pdf.lookup_direct(pdf, "/BaseEncoding", dict) is None)
      match @pdf.lookup_direct(pdf, "/Differences", dict) {
        Some(@pdf.PdfObject::Array(values)) => assert_true(values.length() > 0)
        _ => fail("expected differences array")
      }
    }
    _ => fail("expected custom encoding dictionary")
  }
  let implicit_encoding = @pdftext.read_encoding(
    pdf,
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/Type1")),
      ("/BaseFont", @pdf.PdfObject::Name("/CustomFont")),
    ]),
  )
  let implicit_result : Result[Int, Error] = try? @pdftext.write_encoding(
    pdf, implicit_encoding,
  )
  assert_true(implicit_result is Err(_))
}

///|
test "write_font errors on unsupported fonts" {
  let pdf = @pdf.empty()
  let simple_font = @pdftext.read_font(
    pdf,
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/Type1")),
      ("/BaseFont", @pdf.PdfObject::Name("/CustomFont")),
    ]),
  )
  let simple_result : Result[Int, Error] = try? @pdftext.write_font(
    pdf, simple_font,
  )
  assert_true(simple_result is Err(_))
  let cid_font = @pdftext.read_font(pdf, cid_font_dict("/Identity-H"))
  let cid_result : Result[Int, Error] = try? @pdftext.write_font(pdf, cid_font)
  assert_true(cid_result is Err(_))
}
