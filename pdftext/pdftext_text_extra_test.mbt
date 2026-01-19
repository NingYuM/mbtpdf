///|
fn font_with_encoding_name(
  encoding_name : String,
  subtype? : String = "/Type1",
) -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name(subtype)),
    ("/BaseFont", @pdf.PdfObject::Name("/CustomFont")),
    ("/Encoding", @pdf.PdfObject::Name(encoding_name)),
  ])
}

///|
fn truetype_font_with_encoding_dict() -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/TrueType")),
    ("/BaseFont", @pdf.PdfObject::Name("/CustomFont")),
    (
      "/Encoding",
      @pdf.PdfObject::Dictionary([
        ("/BaseEncoding", @pdf.PdfObject::Name("/MacRomanEncoding")),
      ]),
    ),
  ])
}

///|
fn embedded_font_with_custom_encoding() -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/BaseFont", @pdf.PdfObject::Name("/CustomFont")),
    (
      "/FontDescriptor",
      @pdf.PdfObject::Dictionary([("/FontFile2", @pdf.PdfObject::Indirect(10))]),
    ),
    (
      "/Encoding",
      @pdf.PdfObject::Dictionary([
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
}

///|
test "encoding tables include mac variants and filled standards" {
  let pdf = @pdf.empty()
  let macroman_encoding = @pdftext.read_encoding(
    pdf,
    font_with_encoding_name("/MacRomanEncoding"),
  )
  let macroman = @pdftext.table_of_encoding(macroman_encoding)
  assert_eq(macroman.get(65), Some("/A"))
  let macexpert_encoding = @pdftext.read_encoding(
    pdf,
    font_with_encoding_name("/MacExpertEncoding"),
  )
  let macexpert = @pdftext.table_of_encoding(macexpert_encoding)
  assert_eq(macexpert.get(97), Some("/Asmall"))
  let filled_encoding = @pdftext.read_encoding(
    pdf,
    truetype_font_with_encoding_dict(),
  )
  let filled = @pdftext.table_of_encoding(filled_encoding)
  assert_eq(filled.get(65), Some("/A"))
}

///|
test "reverse tables handle implicit and mac encodings" {
  let pdf = @pdf.empty()
  let implicit_encoding = @pdftext.read_encoding(
    pdf,
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/Type1")),
      ("/BaseFont", @pdf.PdfObject::Name("/CustomFont")),
    ]),
  )
  let implicit = @pdftext.reverse_table_of_encoding(implicit_encoding)
  assert_eq(implicit.get("/A"), None)
  let macroman_encoding = @pdftext.read_encoding(
    pdf,
    font_with_encoding_name("/MacRomanEncoding"),
  )
  let macroman = @pdftext.reverse_table_of_encoding(macroman_encoding)
  assert_eq(macroman.get("/A"), Some(65))
  let macexpert_encoding = @pdftext.read_encoding(
    pdf,
    font_with_encoding_name("/MacExpertEncoding"),
  )
  let macexpert = @pdftext.reverse_table_of_encoding(macexpert_encoding)
  assert_eq(macexpert.get("/Asmall"), Some(97))
  let filled_encoding = @pdftext.read_encoding(
    pdf,
    truetype_font_with_encoding_dict(),
  )
  let filled = @pdftext.reverse_table_of_encoding(filled_encoding)
  assert_eq(filled.get("/A"), Some(65))
}

///|
test "charcode extractor uses tounicode bytes map" {
  let pdf = @pdf.empty()
  let tounicode : Map[Int, String] = Map::new()
  tounicode.set(33, @pdfio.string_of_int_array([0x00, 0x42]))
  let tounicode_ref = @pdftext.write_tounicode(pdf, tounicode)
  let charcode = @pdftext.charcode_extractor_of_font(
    pdf,
    simple_font_with_tounicode(tounicode_ref),
  )
  assert_eq(charcode(66), Some(33))
}

///|
test "codepoints_of_utf16be rejects invalid surrogate pairs" {
  let missing_low = @pdfio.string_of_int_array([0xd8, 0x00])
  let missing_result : Result[Array[Int], Error] = try? @pdftext.codepoints_of_utf16be(
    missing_low,
  )
  assert_true(missing_result is Err(_))
  let bad_low = @pdfio.string_of_int_array([0xd8, 0x00, 0x00, 0x41])
  let bad_low_result : Result[Array[Int], Error] = try? @pdftext.codepoints_of_utf16be(
    bad_low,
  )
  assert_true(bad_low_result is Err(_))
  let low_only = @pdfio.string_of_int_array([0xdc, 0x00, 0x00, 0x41])
  let low_only_result : Result[Array[Int], Error] = try? @pdftext.codepoints_of_utf16be(
    low_only,
  )
  assert_true(low_only_result is Err(_))
}

///|
test "simplify_utf16be keeps non-unicode text" {
  assert_eq(@pdftext.simplify_utf16be("plain"), "plain")
}
