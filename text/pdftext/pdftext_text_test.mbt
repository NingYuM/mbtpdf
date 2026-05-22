///|
fn standard_font_dict() -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(PdfName(b"/Helvetica"))),
    ("/Encoding", Dictionary([])),
  ])
}

///|
fn win_ansi_font_dict() -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(PdfName(b"/Helvetica"))),
    ("/Encoding", Name(PdfName(b"/WinAnsiEncoding"))),
  ])
}

///|
fn custom_encoding_font_dict() -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(PdfName(b"/Helvetica"))),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name(PdfName(b"/WinAnsiEncoding"))),
        ("/Differences", PdfArray([Integer(65), Name(PdfName(b"/A"))])),
      ]),
    ),
  ])
}

///|
fn simple_font_with_tounicode(tounicode_ref : Int) -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(PdfName(b"/Helvetica"))),
    ("/FirstChar", Integer(33)),
    ("/LastChar", Integer(33)),
    ("/Widths", PdfArray([Integer(500)])),
    ("/ToUnicode", Indirect(tounicode_ref)),
  ])
}

///|
fn cid_font_dict(encoding_name : String) -> @pdf.PdfObject {
  let descendant : @pdf.PdfObject = Dictionary([
    (
      "/CIDSystemInfo",
      Dictionary([
        ("/Registry", PdfString("Adobe")),
        ("/Ordering", PdfString("Identity")),
        ("/Supplement", Integer(0)),
      ]),
    ),
    ("/BaseFont", Name(PdfName(b"/CIDFont"))),
    ("/FontDescriptor", Dictionary([])),
  ])
  Dictionary([
    ("/Subtype", Name(PdfName(b"/Type0"))),
    ("/BaseFont", Name(PdfName(b"/CIDFontType0"))),
    ("/DescendantFonts", PdfArray([descendant])),
    ("/Encoding", Name(@pdf.PdfName::of_string(encoding_name))),
  ])
}

///|
test "utf16be conversions" {
  if @pdftext.PdfTextUtil::new().utf16be_of_codepoint(0x41) != [0, 65] {
    fail("unexpected utf16 for 0x41")
  }
  if @pdftext.PdfTextUtil::new().utf16be_of_codepoint(0x1f600) != [216, 61, 222, 0] {
    fail("unexpected utf16 for 0x1f600")
  }
  let utf16 = @pdftext.PdfTextUtil::new().utf16be_of_codepoints([0x41, 0x1f600])
  let utf16_bytes = @pdfio.int_array_of_string(utf16)
  if utf16_bytes != [254, 255, 0, 65, 216, 61, 222, 0] {
    fail("unexpected utf16 bytes")
  }
  let decoded = @pdftext.PdfTextUtil::new().codepoints_of_utf16be(
    @pdfio.string_of_int_array([0x00, 0x41, 0xd8, 0x3d, 0xde, 0x00]),
  )
  if decoded != [65, 128888] {
    fail("unexpected decoded utf16be")
  }
  let invalid_len : Result[Array[Int], Error] = try? @pdftext.PdfTextUtil::new().codepoints_of_utf16be(
    @pdfio.string_of_int_array([0x00]),
  )
  match invalid_len {
    Err(_) => ()
    _ => fail("expected invalid length error")
  }
  let invalid_cp : Result[Array[Int], Error] = try? @pdftext.PdfTextUtil::new().utf16be_of_codepoint(
    0x110000,
  )
  match invalid_cp {
    Err(_) => ()
    _ => fail("expected invalid codepoint error")
  }
}

///|
test "pdfdocstring conversions" {
  assert_true(!@pdftext.PdfTextUtil::new().is_unicode("A"))
  let unicode = @pdftext.PdfTextUtil::new().utf16be_of_codepoints([0x41])
  assert_true(@pdftext.PdfTextUtil::new().is_unicode(unicode))
  if @pdftext.PdfTextUtil::new().codepoints_of_pdfdocstring("A") != [65] {
    fail("unexpected pdfdocstring A")
  }
  if @pdftext.PdfTextUtil::new().codepoints_of_pdfdocstring(unicode) != [65] {
    fail("unexpected unicode pdfdocstring")
  }
  assert_true(@pdftext.PdfTextUtil::new().utf8_of_pdfdocstring("AB") == "AB")
  let simplified = @pdftext.PdfTextUtil::new().simplify_utf16be(unicode)
  assert_true(simplified == "A")
  let pdfdoc_ascii = @pdftext.PdfTextUtil::new().pdfdocstring_of_codepoints([
    0x41, 0x42,
  ])
  assert_true(pdfdoc_ascii == "AB")
  let pdfdoc_cjk = @pdftext.PdfTextUtil::new().pdfdocstring_of_codepoints([
    0x4e2d,
  ])
  assert_true(@pdftext.PdfTextUtil::new().is_unicode(pdfdoc_cjk))
  assert_true(
    @pdftext.PdfTextUtil::new().codepoints_of_pdfdocstring(pdfdoc_cjk) == [20013],
  )
  let bad : Result[Int, Error] = try? @pdftext.PdfTextUtil::new().codepoint_of_pdfdocencoding_character(
    300,
  )
  assert_true(bad is Err(_))
}

///|
test "shift_jis decoder covers ascii and error branches" {
  let util = @pdftext.PdfTextUtil::new()
  if util.codepoints_of_shift_jis([0x41, 0x7f]) != [65, 127] {
    fail("unexpected shift-jis ascii")
  }
  if util.codepoints_of_shift_jis([0xa1]) != [65377] {
    fail("unexpected shift-jis single byte")
  }
  if util.codepoints_of_shift_jis([0x82]) != [65533] {
    fail("unexpected shift-jis dangling lead")
  }
  if util.codepoints_of_shift_jis([0x82, 0x00]) != [65533] {
    fail("unexpected shift-jis bad trail")
  }
  assert_true(util.codepoints_of_shift_jis([0x80]) == [65533])
}

///|
test "charcode extractor debug handles bad tounicode values" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let tounicode : Map[Int, String] = Map([])
  tounicode.set(33, @pdfio.string_of_int_array([0xd8, 0x00]))
  let tounicode_ref = ctx.write_tounicode(tounicode)
  let font = simple_font_with_tounicode(tounicode_ref)
  @pdfutil.with_quiet(true, fn() {
    @pdfe.with_logger(_ => (), fn() {
      let charcode = ctx.charcode_extractor_of_font(font, debug=true)
      let _ = charcode(65)
      ()
    })
  })
}

///|
test "utf8 conversion helpers" {
  let cps = [0x41, 0x20ac, 0x1f600]
  let utf8 = @pdftext.PdfTextUtil::new().utf8_of_codepoints(cps)
  if @pdftext.PdfTextUtil::new().codepoints_of_utf8(utf8) != [65, 8364, 128512] {
    fail("unexpected utf8 decode")
  }
  let bytes = @pdfio.int_array_of_bytes(
    @pdfio.bytes_of_caml_bytes(@utf8.encode(utf8)),
  )
  let expected = @pdftext.PdfTextUtil::new()
    .get_utf8_chars(0x41)
    .add(@pdftext.PdfTextUtil::new().get_utf8_chars(0x20ac))
    .add(@pdftext.PdfTextUtil::new().get_utf8_chars(0x1f600))
  assert_true(bytes.length() == expected.length())
  for i in 0..<expected.length() {
    assert_true(bytes[i] == expected[i])
  }
  let invalid_utf8 : Result[Array[Int], Error] = try? @pdftext.PdfTextUtil::new().get_utf8_chars(
    0x110000,
  )
  assert_true(invalid_utf8 is Err(_))
}

///|
test "encoding tables and extractors" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let encoding = ctx.read_encoding(win_ansi_font_dict())
  let table = @pdftext.PdfTextUtil::new().table_of_encoding(encoding)
  let sample = @pdfglyphlist.name_to_win[0]
  assert_true(table.get(sample.1) == Some(sample.0))
  let reversed = @pdftext.PdfTextUtil::new().reverse_table_of_encoding(encoding)
  assert_true(reversed.get(sample.0) == Some(sample.1))
  let custom = ctx.read_encoding(custom_encoding_font_dict())
  let custom_table = @pdftext.PdfTextUtil::new().table_of_encoding(custom)
  assert_true(custom_table.get(65) == Some("/A"))
  let extractor = ctx.text_extractor_of_font(standard_font_dict())
  let pairs = extractor.glyphnames_and_codepoints_of_text("A")
  assert_true(pairs.length() == 1)
  assert_true(pairs[0].0 == "/A")
  assert_true(pairs[0].1 == [65])
  assert_true(extractor.codepoints_of_text("AB") == [65, 66])
  let charcode = ctx.charcode_extractor_of_font(standard_font_dict())
  assert_true(charcode(0x41) == Some(65))
}

///|
test "tounicode and cmap extraction" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let tounicode : Map[Int, String] = Map([])
  tounicode.set(33, @pdfio.string_of_int_array([0x00, 0x42]))
  let tounicode_ref = ctx.write_tounicode(tounicode)
  let extractor = ctx.text_extractor_of_font(
    simple_font_with_tounicode(tounicode_ref),
  )
  let pairs = extractor.glyphnames_and_codepoints_of_text("!")
  assert_true(pairs.length() == 1)
  assert_true(pairs[0].1 == [66])
  let miss = extractor.glyphnames_and_codepoints_of_text("A")
  assert_true(miss.length() == 1)
  assert_true(miss[0].1 == [65])
  let identity_extractor = ctx.text_extractor_of_font(
    cid_font_dict("/Identity-H"),
  )
  let identity_text = @pdfio.string_of_int_array([0x00, 0x41, 0x00, 0x42])
  let identity_pairs = identity_extractor.glyphnames_and_codepoints_of_text(
    identity_text,
  )
  assert_true(identity_pairs.length() == 2)
  assert_true(identity_pairs[0].1 == [65])
  assert_true(identity_pairs[1].1 == [66])
  let odd_res : Result[Array[(String, Array[Int])], Error] = try? identity_extractor.glyphnames_and_codepoints_of_text(
    @pdfio.string_of_int_array([0x00]),
  )
  assert_true(odd_res is Err(_))
  let shift_extractor = ctx.text_extractor_of_font(
    cid_font_dict("/90ms-RKSJ-H"),
  )
  let shift_text = @pdfio.string_of_int_array([0x81, 0x40])
  let shift_pairs = shift_extractor.glyphnames_and_codepoints_of_text(
    shift_text,
  )
  assert_true(shift_pairs.length() == 1)
  assert_true(shift_pairs[0].1 == [12288])
}
