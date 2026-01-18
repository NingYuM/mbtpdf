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
