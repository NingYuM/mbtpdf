///|
fn all_standard_fonts() -> Array[@pdftext.StandardFont] {
  [
    @pdftext.StandardFont::TimesRoman,
    @pdftext.StandardFont::TimesBold,
    @pdftext.StandardFont::TimesItalic,
    @pdftext.StandardFont::TimesBoldItalic,
    @pdftext.StandardFont::Helvetica,
    @pdftext.StandardFont::HelveticaBold,
    @pdftext.StandardFont::HelveticaOblique,
    @pdftext.StandardFont::HelveticaBoldOblique,
    @pdftext.StandardFont::Courier,
    @pdftext.StandardFont::CourierBold,
    @pdftext.StandardFont::CourierOblique,
    @pdftext.StandardFont::CourierBoldOblique,
    @pdftext.StandardFont::Symbol,
    @pdftext.StandardFont::ZapfDingbats,
  ]
}

///|
test "afm_data loads standard fonts" {
  for font in all_standard_fonts() {
    let (headers, widths, _, widths_by_name) = @pdfstandard14.afm_data(font)
    assert_true(headers.length() > 0)
    assert_true(widths.length() > 0)
    assert_true(widths_by_name.length() > 0)
  }
}

///|
test "baseline_adjustment covers all fonts" {
  let values = all_standard_fonts().map(font => @pdfstandard14.baseline_adjustment(
    font,
  ))
  assert_eq(values.length(), all_standard_fonts().length())
  assert_eq(
    @pdfstandard14.baseline_adjustment(@pdftext.StandardFont::TimesBold),
    338,
  )
  assert_eq(
    @pdfstandard14.baseline_adjustment(@pdftext.StandardFont::HelveticaBold),
    359,
  )
}

///|
test "stemv_of_standard_font covers all fonts" {
  let values = all_standard_fonts().map(font => @pdfstandard14.stemv_of_standard_font(
    font,
  ))
  assert_eq(values.length(), all_standard_fonts().length())
  assert_eq(
    @pdfstandard14.stemv_of_standard_font(@pdftext.StandardFont::TimesBold),
    122,
  )
  assert_eq(
    @pdfstandard14.stemv_of_standard_font(@pdftext.StandardFont::ZapfDingbats),
    125,
  )
}

///|
test "textwidth handles missing widths and kerning" {
  let font = @pdftext.StandardFont::TimesRoman
  let missing = String::from_array([
    Int::unsafe_to_char(999),
    Int::unsafe_to_char(998),
  ])
  let (_, widths, kerns, widths_by_name) = @pdfstandard14.afm_data(font)
  assert_true(widths.get(999) is None)
  assert_true(kerns.get((999, 998)) is None)
  let pdf = @pdf.empty()
  let implicit_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
  ])
  let implicit_encoding = @pdftext.read_encoding(pdf, implicit_font)
  let implicit_width = @pdfstandard14.textwidth(
    true, implicit_encoding, font, missing,
  )
  assert_eq(implicit_width, 0)
  assert_true(widths_by_name.get("NoSlash") is None)
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
            @pdf.PdfObject::Name("NoSlash"),
          ]),
        ),
      ]),
    ),
  ])
  let encoding = @pdftext.read_encoding(pdf, custom_font)
  let custom_width = @pdfstandard14.textwidth(false, encoding, font, "A")
  assert_eq(custom_width, 0)
}

///|
test "textwidth handles empty string and unicode fallback" {
  let font = @pdftext.StandardFont::Helvetica
  let pdf = @pdf.empty()
  let winansi_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/Encoding", @pdf.PdfObject::Name("/WinAnsiEncoding")),
  ])
  let encoding = @pdftext.read_encoding(pdf, winansi_font)
  let width_empty = @pdfstandard14.textwidth(false, encoding, font, "")
  assert_eq(width_empty, 0)
  let unicode = String::from_array([Int::unsafe_to_char(256)])
  let width_space = @pdfstandard14.textwidth(false, encoding, font, unicode)
  assert_true(width_space > 0)
}

///|
test "textwidth applies kerning for standard fonts" {
  let font = @pdftext.StandardFont::TimesRoman
  let pdf = @pdf.empty()
  let implicit_font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
  ])
  let encoding = @pdftext.read_encoding(pdf, implicit_font)
  let kerned = @pdfstandard14.textwidth(true, encoding, font, "AV")
  let plain = @pdfstandard14.textwidth(false, encoding, font, "AV")
  assert_true(kerned <= plain)
  let single = @pdfstandard14.textwidth(false, encoding, font, "A")
  assert_true(single > 0)
}

///|
test "flags_of_standard_font covers branches" {
  assert_eq(
    @pdfstandard14.flags_of_standard_font(@pdftext.StandardFont::Symbol),
    65541,
  )
  assert_eq(
    @pdfstandard14.flags_of_standard_font(
      @pdftext.StandardFont::CourierBoldOblique,
    ),
    33,
  )
  assert_eq(
    @pdfstandard14.flags_of_standard_font(@pdftext.StandardFont::Helvetica),
    32,
  )
}
