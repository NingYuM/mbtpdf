///|
async test "extract text intro pdf" {
  let pdf = @pdfread.pdf_of_file(
    None,
    None,
    "camlpdf/introduction_to_camlpdf.pdf",
  )
  let pages = extract_text_by_page(pdf)
  assert_true(pages.length() > 0)
  assert_true(pages[0].contains("AnIntroductiontoPDFwithCamlPDF"))
  let full_text = extract_text(pdf)
  assert_true(full_text.contains("NextSteps"))
}

///|
async test "extract text pdf.js identity sample" {
  let pdf = @pdfread.pdf_of_file(
    None,
    None,
    "testdata/pdfjs_identity_tounicode.pdf",
  )
  let extracted = extract_text(pdf)
  assert_true(extracted.contains("ABCdef"))
}

///|
async test "extract text SFAA Japanese" {
  let pdf = @pdfread.pdf_of_file(None, None, "testdata/SFAA_Japanese.pdf")
  let extracted = extract_text(pdf)
  assert_true(
    extracted.contains("すべてのアメリカ人のための科学"),
  )
}

///|
fn build_unicode_pdf() -> @pdf.Pdf raise {
  let codepoints : Array[Int] = [0x4f60, 0x597d, 0x4e16, 0x754c, 0x263a]
  let pdf = @pdf.empty()
  let text = utf16be_of_codepoints(codepoints)
  let font = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Font")),
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/BaseFont", @pdf.PdfObject::Name("/CustomUnicodeFont")),
    ("/Encoding", @pdf.PdfObject::Name("/WinAnsiEncoding")),
  ])
  let ops = [
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 24.0),
    @pdfops.Op::OpTj(text),
    @pdfops.Op::OpET,
  ]
  let stream = @pdfops.stream_of_ops(ops)
  let mediabox = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(595.0),
    @pdf.PdfObject::Real(842.0),
  ])
  let page : @pdfpage.Page = {
    content: [stream],
    mediabox,
    resources: @pdf.PdfObject::Dictionary([
      ("/Font", @pdf.PdfObject::Dictionary([("/F0", font)])),
    ]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf, pageroot) = @pdfpage.add_pagetree([page], pdf)
  @pdfpage.add_root(pageroot, [], pdf)
}

///|
test "extract unicode from generated pdf" {
  let pdf = build_unicode_pdf()
  let expected = utf8_of_codepoints([0x4f60, 0x597d, 0x4e16, 0x754c, 0x263a])
  assert_eq(extract_text(pdf), expected)
}
