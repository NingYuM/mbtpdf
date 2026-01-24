///|
test "pdf_of_input removes xref and objstm objects after eager parse" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let (output, buffer) = @pdfio.input_output_of_bytes(2048)
  @pdfwrite.pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    None,
    false,
    pdf,
    output,
  )
  let bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let input = @pdfio.input_of_bytes(bytes, source="objstm-cleanup")
  let parsed = @pdfread.pdf_of_input(None, None, input)
  for objnum in parsed.objnumbers() {
    let obj = @pdf.lookup_obj(parsed, objnum)
    match (obj : @pdf.PdfObject) {
      Stream(r) => {
        let (dict, _) = r.val
        match (@pdf.lookup_direct(parsed, "/Type", dict) : @pdf.PdfObject?) {
          Some(Name("/XRef")) => fail("expected xref streams removed")
          Some(Name("/ObjStm")) => fail("expected objstm streams removed")
          _ => ()
        }
      }
      _ => ()
    }
  }
}
