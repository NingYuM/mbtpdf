///|
test "pdf_of_input triggers endpage hook without objstms" {
  let previous = endpage.val
  let called : Ref[Bool] = Ref::new(false)
  endpage.val = _ => {
    called.val = true
    0
  }
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let (output, buffer) = @pdfio.Output::of_bytes(2048)
  @pdfwrite.PdfWrite::new().pdf_to_output(None, false, pdf, output)
  let bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(bytes, source="endpage-hook")
  let _ = PdfRead::new().pdf_of_input(None, None, input)
  endpage.val = previous
  assert_eq(called.val, true)
}
