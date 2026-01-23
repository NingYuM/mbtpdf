///|
fn all_standard_fonts() -> Array[@pdffont.StandardFont] {
  [
    @pdffont.StandardFont::TimesRoman,
    @pdffont.StandardFont::TimesBold,
    @pdffont.StandardFont::TimesItalic,
    @pdffont.StandardFont::TimesBoldItalic,
    @pdffont.StandardFont::Helvetica,
    @pdffont.StandardFont::HelveticaBold,
    @pdffont.StandardFont::HelveticaOblique,
    @pdffont.StandardFont::HelveticaBoldOblique,
    @pdffont.StandardFont::Courier,
    @pdffont.StandardFont::CourierBold,
    @pdffont.StandardFont::CourierOblique,
    @pdffont.StandardFont::CourierBoldOblique,
    @pdffont.StandardFont::Symbol,
    @pdffont.StandardFont::ZapfDingbats,
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
    @pdfstandard14.baseline_adjustment(@pdffont.StandardFont::TimesBold),
    338,
  )
  assert_eq(
    @pdfstandard14.baseline_adjustment(@pdffont.StandardFont::HelveticaBold),
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
    @pdfstandard14.stemv_of_standard_font(@pdffont.StandardFont::TimesBold),
    122,
  )
  assert_eq(
    @pdfstandard14.stemv_of_standard_font(@pdffont.StandardFont::ZapfDingbats),
    125,
  )
}

///|
test "textwidth handles missing widths and kerning" {
  let font = @pdffont.StandardFont::TimesRoman
  let missing = String::from_array([
    Int::unsafe_to_char(999),
    Int::unsafe_to_char(998),
  ])
  let (_, widths, kerns, widths_by_name) = @pdfstandard14.afm_data(font)
  assert_true(widths.get(999) is None)
  assert_true(kerns.get((999, 998)) is None)
  let pdf = @pdf.empty()
  let implicit_font : @pdf.PdfObject = Dictionary([("/Subtype", Name("/Type1"))])
  let implicit_encoding = @pdftext.read_encoding(pdf, implicit_font)
  let implicit_width = @pdfstandard14.textwidth(
    true, implicit_encoding, font, missing,
  )
  assert_eq(implicit_width, 0)
  assert_true(widths_by_name.get("NoSlash") is None)
  let custom_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Type1")),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name("/WinAnsiEncoding")),
        ("/Differences", Array([Integer(65), Name("NoSlash")])),
      ]),
    ),
  ])
  let encoding = @pdftext.read_encoding(pdf, custom_font)
  let custom_width = @pdfstandard14.textwidth(false, encoding, font, "A")
  assert_eq(custom_width, 0)
}

///|
test "textwidth handles empty string and unicode fallback" {
  let font = @pdffont.StandardFont::Helvetica
  let pdf = @pdf.empty()
  let winansi_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Type1")),
    ("/Encoding", Name("/WinAnsiEncoding")),
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
  let font = @pdffont.StandardFont::TimesRoman
  let pdf = @pdf.empty()
  let implicit_font : @pdf.PdfObject = Dictionary([("/Subtype", Name("/Type1"))])
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
    @pdfstandard14.flags_of_standard_font(@pdffont.StandardFont::Symbol),
    65541,
  )
  assert_eq(
    @pdfstandard14.flags_of_standard_font(
      @pdffont.StandardFont::CourierBoldOblique,
    ),
    33,
  )
  assert_eq(
    @pdfstandard14.flags_of_standard_font(@pdffont.StandardFont::Helvetica),
    32,
  )
}
