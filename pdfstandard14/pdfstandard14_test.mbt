///|
fn winansi_encoding() -> @pdftext.Encoding raise {
  let pdf = @pdf.empty()
  let font = @pdf.PdfObject::Dictionary([
    ("/Encoding", @pdf.PdfObject::Name("/WinAnsiEncoding")),
  ])
  @pdftext.read_encoding(pdf, font)
}

///|
fn implicit_encoding() -> @pdftext.Encoding raise {
  @pdftext.read_encoding(@pdf.empty(), @pdf.PdfObject::Dictionary([]))
}

///|
fn custom_encoding_missing() -> @pdftext.Encoding raise {
  let pdf = @pdf.empty()
  let encoding = @pdf.PdfObject::Dictionary([
    (
      "/Differences",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Integer(65),
        @pdf.PdfObject::Name("/NotAChar"),
      ]),
    ),
  ])
  let font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/Encoding", encoding),
    (
      "/FontDescriptor",
      @pdf.PdfObject::Dictionary([("/FontFile", @pdf.PdfObject::Null)]),
    ),
  ])
  @pdftext.read_encoding(pdf, font)
}

///|
test "baseline adjustments and textwidth" {
  assert_eq(baseline_adjustment(@pdftext.StandardFont::TimesRoman), 331)
  assert_eq(baseline_adjustment(@pdftext.StandardFont::Helvetica), 359)
  let encoding = winansi_encoding()
  let short = textwidth(false, encoding, @pdftext.StandardFont::Helvetica, "Hi")
  let long = textwidth(
    false,
    encoding,
    @pdftext.StandardFont::Helvetica,
    "Hello",
  )
  assert_true(short > 0)
  assert_true(long > short)
}

///|
test "afm_data returns tables" {
  let (headers, widths, kerns, widths_prime) = afm_data(
    @pdftext.StandardFont::Courier,
  )
  assert_true(headers.to_array().length() > 0)
  assert_true(widths.to_array().length() > 0)
  assert_true(kerns.to_array().length() >= 0)
  assert_true(widths_prime.to_array().length() > 0)
}

///|
test "flags and stemv by font" {
  assert_eq(flags_of_standard_font(@pdftext.StandardFont::Symbol), 65541)
  assert_eq(flags_of_standard_font(@pdftext.StandardFont::ZapfDingbats), 4)
  assert_eq(flags_of_standard_font(@pdftext.StandardFont::Courier), 33)
  assert_eq(flags_of_standard_font(@pdftext.StandardFont::Helvetica), 32)
  assert_eq(stemv_of_standard_font(@pdftext.StandardFont::TimesRoman), 116)
  assert_eq(stemv_of_standard_font(@pdftext.StandardFont::Symbol), 0)
}

///|
test "textwidth handles empty and repeated strings" {
  let encoding = winansi_encoding()
  let empty = textwidth(false, encoding, @pdftext.StandardFont::Helvetica, "")
  assert_eq(empty, 0)
  let width_a = textwidth(
    false,
    encoding,
    @pdftext.StandardFont::Helvetica,
    "A",
  )
  let width_aa = textwidth(
    false,
    encoding,
    @pdftext.StandardFont::Helvetica,
    "AA",
  )
  assert_eq(width_aa, width_a * 2)
  let implicit = textwidth(
    false,
    @pdftext.read_encoding(
      @pdf.empty(),
      @pdf.PdfObject::Dictionary([
        ("/Subtype", @pdf.PdfObject::Name("/Type1")),
        ("/BaseFont", @pdf.PdfObject::Name("/Helvetica")),
      ]),
    ),
    @pdftext.StandardFont::Helvetica,
    "A",
  )
  assert_true(implicit >= 0)
}

///|
test "textwidth handles implicit and custom fallbacks" {
  let implicit = implicit_encoding()
  let base = textwidth(false, implicit, @pdftext.StandardFont::Helvetica, "AV")
  let kerned = textwidth(true, implicit, @pdftext.StandardFont::Helvetica, "AV")
  assert_true(base > 0)
  assert_true(kerned >= 0)
  let custom = custom_encoding_missing()
  let missing_code = textwidth(
    false,
    custom,
    @pdftext.StandardFont::Helvetica,
    "B",
  )
  let space = textwidth(false, custom, @pdftext.StandardFont::Helvetica, " ")
  assert_eq(missing_code, space)
  let unknown_name = textwidth(
    false,
    custom,
    @pdftext.StandardFont::Helvetica,
    "A",
  )
  assert_eq(unknown_name, 0)
}
