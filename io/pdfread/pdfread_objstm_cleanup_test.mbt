///|
test "pdf_of_input removes xref and objstm objects after eager parse" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let (output, buffer) = @pdfio.Output::of_bytes(2048)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    None,
    false,
    pdf,
    output,
  )
  let bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(bytes, source="objstm-cleanup")
  let parsed = @pdfread.PdfRead::new().pdf_of_input(None, None, input)
  for objnum in parsed.objnumbers() {
    let obj = parsed.lookup_obj(objnum)
    match (obj : @pdf.PdfObject) {
      Stream(r) => {
        let (dict, _) = r.val
        match (parsed.lookup_direct("/Type", dict) : @pdf.PdfObject?) {
          Some(Name(n)) if n.equal_string_bytes("/XRef") =>
            fail("expected xref streams removed")
          Some(Name(n)) if n.equal_string_bytes("/ObjStm") =>
            fail("expected objstm streams removed")
          _ => ()
        }
      }
      _ => ()
    }
  }
}
