///|
test "e2e parse camlpdf intro pdf" {
  let filename = "camlpdf/introduction_to_camlpdf.pdf"
  let pdf = @pdfread.pdf_of_file(None, None, filename)
  let page_count = @pdfpage.pages_of_pagetree_quick(pdf)
  assert_true(@pdf.objcard(pdf) > 0)
  assert_true(page_count > 0)
  assert_eq(@pdfpage.pages_of_pagetree(pdf).length(), page_count)
}
