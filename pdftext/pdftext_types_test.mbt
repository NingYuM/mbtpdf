///|
fn encoding_string(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> String raise {
  @pdffont.string_of_encoding(@pdftext.read_encoding(pdf, font))
}

///|
test "string_of_standard_font covers all names" {
  let cases : Array[(String, String)] = [
    ("/Times-Roman", "Times-Roman"),
    ("/Times-Bold", "Times-Bold"),
    ("/Times-Italic", "Times-Italic"),
    ("/Times-BoldItalic", "Times-BoldItalic"),
    ("/Helvetica", "Helvetica"),
    ("/Helvetica-Bold", "Helvetica-Bold"),
    ("/Helvetica-Oblique", "Helvetica-Oblique"),
    ("/Helvetica-BoldOblique", "Helvetica-BoldOblique"),
    ("/Courier", "Courier"),
    ("/Courier-Bold", "Courier-Bold"),
    ("/Courier-Oblique", "Courier-Oblique"),
    ("/Courier-BoldOblique", "Courier-BoldOblique"),
    ("/Symbol", "Symbol"),
    ("/ZapfDingbats", "ZapfDingbats"),
  ]
  for pair in cases {
    let name = pair.0
    let expected = pair.1
    match @pdftext.standard_font_of_name(name) {
      Some(font) => assert_eq(@pdffont.string_of_standard_font(font), expected)
      None => fail("expected standard font")
    }
  }
}

///|
test "string_of_fonttype covers variants" {
  let pdf = @pdf.empty()
  let dummy : @pdf.PdfObject = Dictionary([])
  match @pdftext.simple_fonttype_of_string(pdf, dummy, "/Type1") {
    Some(ft) => assert_eq(@pdffont.string_of_fonttype(ft), "Type 1")
    None => fail("expected Type1")
  }
  match @pdftext.simple_fonttype_of_string(pdf, dummy, "/MMType1") {
    Some(ft) => assert_eq(@pdffont.string_of_fonttype(ft), "MM Type 1")
    None => fail("expected MMType1")
  }
  match @pdftext.simple_fonttype_of_string(pdf, dummy, "/TrueType") {
    Some(ft) => assert_eq(@pdffont.string_of_fonttype(ft), "Truetype")
    None => fail("expected Truetype")
  }
  let type3_font : @pdf.PdfObject = Dictionary([
    ("/FontBBox", Array([Real(0.0), Real(0.0), Real(10.0), Real(10.0)])),
    (
      "/FontMatrix",
      Array([Real(1.0), Real(0.0), Real(0.0), Real(1.0), Real(0.0), Real(0.0)]),
    ),
    ("/CharProcs", Dictionary([("/A", Null)])),
  ])
  match @pdftext.simple_fonttype_of_string(pdf, type3_font, "/Type3") {
    Some(ft) =>
      assert_eq(@pdffont.string_of_fonttype(ft), "Type 3: charprocs for/A")
    None => fail("expected Type3")
  }
}

///|
test "string_of_encoding covers variants" {
  let pdf = @pdf.empty()
  let implicit_font : @pdf.PdfObject = Dictionary([("/Subtype", Name("/Type1"))])
  assert_eq(encoding_string(pdf, implicit_font), "ImplicitInFontFile")
  let mac_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Type1")),
    ("/Encoding", Name("/MacRomanEncoding")),
  ])
  assert_eq(encoding_string(pdf, mac_font), "MacRomanEncoding")
  let expert_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Type1")),
    ("/Encoding", Name("/MacExpertEncoding")),
  ])
  assert_eq(encoding_string(pdf, expert_font), "MacExpertEncoding")
  let ansi_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Type1")),
    ("/Encoding", Name("/WinAnsiEncoding")),
  ])
  assert_eq(encoding_string(pdf, ansi_font), "WinAnsiEncoding")
  let standard_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Type1")),
    ("/Encoding", Dictionary([])),
  ])
  assert_eq(encoding_string(pdf, standard_font), "StandardEncoding")
  let custom_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Type1")),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name("/WinAnsiEncoding")),
        ("/Differences", Array([Integer(65), Name("/A")])),
      ]),
    ),
  ])
  assert_eq(
    encoding_string(pdf, custom_font),
    "CustomEncoding with base WinAnsiEncoding and differences 65 -> /A, ",
  )
  let fill_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/TrueType")),
    ("/Encoding", Dictionary([("/BaseEncoding", Name("/WinAnsiEncoding"))])),
  ])
  assert_eq(
    encoding_string(pdf, fill_font),
    "FillUndefinedWithStandard WinAnsiEncoding",
  )
}

///|
test "string_of_simple_font formats details" {
  let pdf = @pdf.empty()
  let font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Type1")),
    ("/BaseFont", Name("/Helvetica")),
    ("/FirstChar", Integer(65)),
    ("/LastChar", Integer(65)),
    ("/Widths", Array([Integer(500)])),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name("/WinAnsiEncoding")),
        ("/Differences", Array([Integer(65), Name("/A")])),
      ]),
    ),
  ])
  let simple = match (@pdftext.read_simple_font(pdf, font) : @pdffont.Font) {
    SimpleFont(value) => value
    _ => fail("expected simple font")
  }
  let rendered = @pdffont.string_of_simple_font(simple)
  assert_true(rendered.contains("fonttype = Type 1"))
  assert_true(rendered.contains("basefont /Helvetica"))
  assert_true(rendered.contains("CustomEncoding"))
}

///|
test "string_of_font covers variants" {
  let pdf = @pdf.empty()
  let standard_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Type1")),
    ("/BaseFont", Name("/Helvetica")),
  ])
  let standard = @pdftext.read_standard14font(pdf, standard_font)
  assert_eq(@pdffont.string_of_font(standard), "StandardFont Helvetica")
  let simple_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Type1")),
    ("/BaseFont", Name("/Helvetica")),
    ("/FirstChar", Integer(65)),
    ("/LastChar", Integer(65)),
    ("/Widths", Array([Integer(500)])),
  ])
  let simple = @pdftext.read_simple_font(pdf, simple_font)
  assert_true(@pdffont.string_of_font(simple).contains("SimpleFont fonttype"))
  let descendant : @pdf.PdfObject = Dictionary([
    (
      "/CIDSystemInfo",
      Dictionary([
        ("/Registry", String("Adobe")),
        ("/Ordering", String("Identity")),
        ("/Supplement", Integer(0)),
      ]),
    ),
    ("/BaseFont", Name("/CIDFont")),
    ("/FontDescriptor", Dictionary([])),
  ])
  let cid_font : @pdf.PdfObject = Dictionary([
    ("/BaseFont", Name("/CIDFontType0")),
    ("/DescendantFonts", Array([descendant])),
    ("/Encoding", Name("/Identity-H")),
  ])
  let cid = @pdftext.read_cidkeyed_font(pdf, cid_font)
  assert_eq(@pdffont.string_of_font(cid), "CIDKeyedFont /CIDFontType0")
}
