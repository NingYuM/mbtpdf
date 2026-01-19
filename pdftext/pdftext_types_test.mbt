///|
fn encoding_string(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> String raise {
  @pdftext.string_of_encoding(@pdftext.read_encoding(pdf, font))
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
      Some(font) => assert_eq(@pdftext.string_of_standard_font(font), expected)
      None => fail("expected standard font")
    }
  }
}

///|
test "string_of_fonttype covers variants" {
  let pdf = @pdf.empty()
  let dummy = @pdf.PdfObject::Dictionary([])
  match @pdftext.simple_fonttype_of_string(pdf, dummy, "/Type1") {
    Some(ft) => assert_eq(@pdftext.string_of_fonttype(ft), "Type 1")
    None => fail("expected Type1")
  }
  match @pdftext.simple_fonttype_of_string(pdf, dummy, "/MMType1") {
    Some(ft) => assert_eq(@pdftext.string_of_fonttype(ft), "MM Type 1")
    None => fail("expected MMType1")
  }
  match @pdftext.simple_fonttype_of_string(pdf, dummy, "/TrueType") {
    Some(ft) => assert_eq(@pdftext.string_of_fonttype(ft), "Truetype")
    None => fail("expected Truetype")
  }
  let type3_font = @pdf.PdfObject::Dictionary([
    (
      "/FontBBox",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(10.0),
        @pdf.PdfObject::Real(10.0),
      ]),
    ),
    (
      "/FontMatrix",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(0.0),
      ]),
    ),
    ("/CharProcs", @pdf.PdfObject::Dictionary([("/A", @pdf.PdfObject::Null)])),
  ])
  match @pdftext.simple_fonttype_of_string(pdf, type3_font, "/Type3") {
    Some(ft) =>
      assert_eq(@pdftext.string_of_fonttype(ft), "Type 3: charprocs for/A")
    None => fail("expected Type3")
  }
}

///|
test "string_of_encoding covers variants" {
  let pdf = @pdf.empty()
  let implicit_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
  ])
  assert_eq(encoding_string(pdf, implicit_font), "ImplicitInFontFile")
  let mac_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/Encoding", @pdf.PdfObject::Name("/MacRomanEncoding")),
  ])
  assert_eq(encoding_string(pdf, mac_font), "MacRomanEncoding")
  let expert_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/Encoding", @pdf.PdfObject::Name("/MacExpertEncoding")),
  ])
  assert_eq(encoding_string(pdf, expert_font), "MacExpertEncoding")
  let ansi_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/Encoding", @pdf.PdfObject::Name("/WinAnsiEncoding")),
  ])
  assert_eq(encoding_string(pdf, ansi_font), "WinAnsiEncoding")
  let standard_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/Encoding", @pdf.PdfObject::Dictionary([])),
  ])
  assert_eq(encoding_string(pdf, standard_font), "StandardEncoding")
  let custom_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    (
      "/Encoding",
      @pdf.PdfObject::Dictionary([
        ("/BaseEncoding", @pdf.PdfObject::Name("/WinAnsiEncoding")),
        (
          "/Differences",
          @pdf.PdfObject::Array([
            @pdf.PdfObject::Integer(65),
            @pdf.PdfObject::Name("/A"),
          ]),
        ),
      ]),
    ),
  ])
  assert_eq(
    encoding_string(pdf, custom_font),
    "CustomEncoding with base WinAnsiEncoding and differences 65 -> /A, ",
  )
  let fill_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/TrueType")),
    (
      "/Encoding",
      @pdf.PdfObject::Dictionary([
        ("/BaseEncoding", @pdf.PdfObject::Name("/WinAnsiEncoding")),
      ]),
    ),
  ])
  assert_eq(
    encoding_string(pdf, fill_font),
    "FillUndefinedWithStandard WinAnsiEncoding",
  )
}

///|
test "string_of_simple_font formats details" {
  let pdf = @pdf.empty()
  let font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/BaseFont", @pdf.PdfObject::Name("/Helvetica")),
    ("/FirstChar", @pdf.PdfObject::Integer(65)),
    ("/LastChar", @pdf.PdfObject::Integer(65)),
    ("/Widths", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(500)])),
    (
      "/Encoding",
      @pdf.PdfObject::Dictionary([
        ("/BaseEncoding", @pdf.PdfObject::Name("/WinAnsiEncoding")),
        (
          "/Differences",
          @pdf.PdfObject::Array([
            @pdf.PdfObject::Integer(65),
            @pdf.PdfObject::Name("/A"),
          ]),
        ),
      ]),
    ),
  ])
  let simple = match @pdftext.read_simple_font(pdf, font) {
    @pdftext.Font::SimpleFont(value) => value
    _ => fail("expected simple font")
  }
  let rendered = @pdftext.string_of_simple_font(simple)
  assert_true(rendered.contains("fonttype = Type 1"))
  assert_true(rendered.contains("basefont /Helvetica"))
  assert_true(rendered.contains("CustomEncoding"))
}

///|
test "string_of_font covers variants" {
  let pdf = @pdf.empty()
  let standard_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/BaseFont", @pdf.PdfObject::Name("/Helvetica")),
  ])
  let standard = @pdftext.read_standard14font(pdf, standard_font)
  assert_eq(@pdftext.string_of_font(standard), "StandardFont Helvetica")
  let simple_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/BaseFont", @pdf.PdfObject::Name("/Helvetica")),
    ("/FirstChar", @pdf.PdfObject::Integer(65)),
    ("/LastChar", @pdf.PdfObject::Integer(65)),
    ("/Widths", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(500)])),
  ])
  let simple = @pdftext.read_simple_font(pdf, simple_font)
  assert_true(@pdftext.string_of_font(simple).contains("SimpleFont fonttype"))
  let descendant = @pdf.PdfObject::Dictionary([
    (
      "/CIDSystemInfo",
      @pdf.PdfObject::Dictionary([
        ("/Registry", @pdf.PdfObject::String("Adobe")),
        ("/Ordering", @pdf.PdfObject::String("Identity")),
        ("/Supplement", @pdf.PdfObject::Integer(0)),
      ]),
    ),
    ("/BaseFont", @pdf.PdfObject::Name("/CIDFont")),
    ("/FontDescriptor", @pdf.PdfObject::Dictionary([])),
  ])
  let cid_font = @pdf.PdfObject::Dictionary([
    ("/BaseFont", @pdf.PdfObject::Name("/CIDFontType0")),
    ("/DescendantFonts", @pdf.PdfObject::Array([descendant])),
    ("/Encoding", @pdf.PdfObject::Name("/Identity-H")),
  ])
  let cid = @pdftext.read_cidkeyed_font(pdf, cid_font)
  assert_eq(@pdftext.string_of_font(cid), "CIDKeyedFont /CIDFontType0")
}
