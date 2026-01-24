///|
async test "extract text intro pdf" {
  let pdf = @pdfread.pdf_of_file(
    None,
    None,
    "camlpdf/introduction_to_camlpdf.pdf",
  )
  let ctx = @pdftext.PdfText::new(pdf)
  let pages = ctx.extract_text_by_page()
  assert_true(pages.length() > 0)
  assert_true(pages[0].contains("AnIntroductiontoPDFwithCamlPDF"))
  let full_text = ctx.extract_text()
  assert_true(full_text.contains("NextSteps"))
}

///|
async test "extract text pdf.js identity sample" {
  let pdf = @pdfread.pdf_of_file(
    None,
    None,
    "testdata/pdfjs_identity_tounicode.pdf",
  )
  let extracted = @pdftext.PdfText::new(pdf).extract_text()
  assert_true(extracted.contains("ABCdef"))
}

///|
async test "extract text SFAA Japanese" {
  let pdf = @pdfread.pdf_of_file(None, None, "testdata/SFAA_Japanese.pdf")
  let extracted = @pdftext.PdfText::new(pdf).extract_text()
  assert_true(
    extracted.contains("すべてのアメリカ人のための科学"),
  )
}

///|
fn build_unicode_pdf() -> @pdf.Pdf raise {
  let codepoints : Array[Int] = [0x4f60, 0x597d, 0x4e16, 0x754c, 0x263a]
  let pdf = @pdf.empty()
  let text = utf16be_of_codepoints(codepoints)
  let font : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/Font")),
    ("/Subtype", Name("/Type1")),
    ("/BaseFont", Name("/CustomUnicodeFont")),
    ("/Encoding", Name("/WinAnsiEncoding")),
  ])
  let ops : Array[@pdfops.Op] = [OpBT, OpTf("/F0", 24.0), OpTj(text), OpET]
  let stream = @pdfops.stream_of_ops(ops)
  let mediabox : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(595.0),
    Real(842.0),
  ])
  let page : @pdfpage.Page = {
    content: [stream],
    mediabox,
    resources: Dictionary([("/Font", Dictionary([("/F0", font)]))]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf, pageroot) = @pdfpage.add_pagetree([page], pdf)
  @pdfpage.add_root(pageroot, [], pdf)
}

///|
test "extract unicode from generated pdf" {
  let pdf = build_unicode_pdf()
  let expected = utf8_of_codepoints([0x4f60, 0x597d, 0x4e16, 0x754c, 0x263a])
  assert_eq(@pdftext.PdfText::new(pdf).extract_text(), expected)
}

///|
fn extract_test_mediabox() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)])
}

///|
fn extract_test_page(
  ops : Array[@pdfops.Op],
  resources : @pdf.PdfObject,
) -> @pdfpage.Page raise {
  let stream = @pdfops.stream_of_ops(ops)
  {
    content: [stream],
    mediabox: extract_test_mediabox(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
}

///|
fn add_pages_to_pdf(
  pages : Array[@pdfpage.Page],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let (pdf, pageroot) = @pdfpage.add_pagetree(pages, pdf)
  @pdfpage.add_root(pageroot, [], pdf)
}

///|
fn form_xobject_stream(text : String) -> @pdf.PdfObject raise {
  let ops : Array[@pdfops.Op] = [OpBT, OpTj(text), OpET]
  let stream = @pdfops.stream_of_ops(ops)
  let stream = @pdf.add_dict_entry(stream, "/Type", Name("/XObject"))
  @pdf.add_dict_entry(stream, "/Subtype", Name("/Form"))
}

///|
test "extract text handles text ops and arrays" {
  let ops : Array[@pdfops.Op] = [
    OpBT,
    OpTj("A"),
    OpTj(""),
    OpSingleQuote("B"),
    OpDoubleQuote(0.0, 0.0, "C"),
    OpTStar,
    OpTj("D"),
    OpTd(0.0, 10.0),
    OpTj("E"),
    OpTD(0.0, 10.0),
    OpTJ(Array([String("F"), Integer(120), String("")])),
    OpET,
  ]
  let page = extract_test_page(ops, Dictionary([]))
  let pdf = add_pages_to_pdf([page], @pdf.empty())
  let pages = @pdftext.PdfText::new(pdf).extract_text_by_page()
  assert_eq(pages.length(), 1)
  assert_eq(pages[0], "A\nB\nC\nD\nE\nF")
}

///|
test "extract text handles invalid unicode and missing xobjects" {
  let invalid_unicode = @pdfio.string_of_bytes(
    @pdfio.bytes_of_int_array([0xfe, 0xff, 0x00]),
  )
  let ops : Array[@pdfops.Op] = [
    OpBT,
    OpTj(invalid_unicode),
    OpET,
    OpDo("/NoXObject"),
  ]
  let page = extract_test_page(ops, Dictionary([]))
  let pdf = add_pages_to_pdf([page], @pdf.empty())
  let pages = @pdftext.PdfText::new(pdf).extract_text_by_page()
  assert_eq(pages.length(), 1)
  let bytes = @pdfio.int_array_of_bytes(@pdfio.bytes_of_string(pages[0]))
  inspect(bytes, content="[254, 255, 0]")
}

///|
test "extract text visits xobjects once" {
  let pdf = @pdf.empty()
  let form_indirect = form_xobject_stream("X1")
  let form_indirect_id = @pdf.addobj(pdf, form_indirect)
  let form_direct = form_xobject_stream("X2")
  let xobjects : @pdf.PdfObject = Dictionary([
    ("/X1", Indirect(form_indirect_id)),
    ("/X2", form_direct),
    ("/X3", Dictionary([("/Subtype", Name("/Image"))])),
  ])
  let resources : @pdf.PdfObject = Dictionary([("/XObject", xobjects)])
  let ops : Array[@pdfops.Op] = [
    OpDo("/X1"),
    OpDo("/X1"),
    OpDo("/X2"),
    OpDo("/X3"),
    OpDo("/Missing"),
  ]
  let page = extract_test_page(ops, resources)
  let pdf = add_pages_to_pdf([page], pdf)
  let pages = @pdftext.PdfText::new(pdf).extract_text_by_page()
  assert_eq(pages.length(), 1)
  assert_eq(pages[0], "X1X2")
}

///|
test "extract text ignores missing or invalid fonts" {
  let bad_font : @pdf.PdfObject = Dictionary([])
  let resources_bad : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/Bad", bad_font)])),
  ])
  let ops_missing_font : Array[@pdfops.Op] = [
    OpBT,
    OpTf("/F0", 12.0),
    OpTj("A"),
    OpET,
  ]
  let ops_bad_font : Array[@pdfops.Op] = [
    OpBT,
    OpTf("/Bad", 12.0),
    OpTj("B"),
    OpET,
  ]
  let ops_unknown_font : Array[@pdfops.Op] = [
    OpBT,
    OpTf("/Missing", 12.0),
    OpTj("C"),
    OpET,
  ]
  let page1 = extract_test_page(ops_missing_font, Dictionary([]))
  let page2 = extract_test_page(ops_bad_font, resources_bad)
  let page3 = extract_test_page(ops_unknown_font, resources_bad)
  let pdf = add_pages_to_pdf([page1, page2, page3], @pdf.empty())
  let pages = @pdftext.PdfText::new(pdf).extract_text_by_page()
  assert_eq(pages.length(), 3)
  assert_eq(pages[0], "A")
  assert_eq(pages[1], "B")
  assert_eq(pages[2], "C")
}

///|
test "extract text falls back for odd identity-h text bytes" {
  let font = cid_font_dict("/Identity-H")
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F1", font)])),
  ])
  let ops : Array[@pdfops.Op] = [OpBT, OpTf("/F1", 12.0), OpTj("A"), OpET]
  let page = extract_test_page(ops, resources)
  let pdf = add_pages_to_pdf([page], @pdf.empty())
  let pages = @pdftext.PdfText::new(pdf).extract_text_by_page()
  assert_eq(pages.length(), 1)
  assert_eq(pages[0], "A")
}
