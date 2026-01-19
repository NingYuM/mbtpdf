///|
fn winansi_encoding() -> @pdftext.Encoding raise {
  let pdf = @pdf.empty()
  let font = @pdf.PdfObject::Dictionary([
    ("/Encoding", @pdf.PdfObject::Name("/WinAnsiEncoding")),
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
