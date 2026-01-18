///|
fn roundtrip_pdf(pdf : @pdf.Pdf) -> @pdf.Pdf raise {
  let (output, buffer) = @pdfio.input_output_of_bytes(512)
  @pdfwrite.pdf_to_output(None, false, pdf, output)
  let bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let input = @pdfio.input_of_bytes(bytes, source="e2e-roundtrip")
  @pdfread.pdf_of_input(None, None, input)
}

///|
fn has_stream(pdf : @pdf.Pdf) -> Bool {
  for objnum in @pdf.objnumbers(pdf) {
    let obj = @pdf.lookup_obj(pdf, objnum)
    match obj {
      @pdf.PdfObject::Stream(_) => return true
      _ => ()
    }
  }
  false
}

///|
test "e2e parse camlpdf intro pdf" {
  let filename = "camlpdf/introduction_to_camlpdf.pdf"
  let pdf = @pdfread.pdf_of_file(None, None, filename)
  let page_count = @pdfpage.pages_of_pagetree_quick(pdf)
  assert_true(@pdf.objcard(pdf) > 0)
  assert_true(page_count > 0)
  assert_eq(@pdfpage.pages_of_pagetree(pdf).length(), page_count)
}

///|
test "e2e roundtrip camlpdf intro pdf" {
  let filename = "camlpdf/introduction_to_camlpdf.pdf"
  let pdf = @pdfread.pdf_of_file(None, None, filename)
  let roundtripped = roundtrip_pdf(pdf)
  assert_eq(
    @pdfpage.pages_of_pagetree_quick(roundtripped),
    @pdfpage.pages_of_pagetree_quick(pdf),
  )
}

///|
test "e2e parse camlpdf logo pdf has stream" {
  let filename = "camlpdf/logo.pdf"
  let pdf = @pdfread.pdf_of_file(None, None, filename)
  assert_true(has_stream(pdf))
}
