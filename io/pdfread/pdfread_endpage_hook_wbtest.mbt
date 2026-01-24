///|
test "pdf_of_input triggers endpage hook without objstms" {
  let previous = endpage.val
  let called : Ref[Bool] = Ref::new(false)
  endpage.val = _ => {
    called.val = true
    0
  }
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let (output, buffer) = @pdfio.input_output_of_bytes(2048)
  @pdfwrite.PdfWrite::new().pdf_to_output(None, false, pdf, output)
  let bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let input = @pdfio.input_of_bytes(bytes, source="endpage-hook")
  let _ = PdfRead::new().pdf_of_input(None, None, input)
  endpage.val = previous
  assert_eq(called.val, true)
}
