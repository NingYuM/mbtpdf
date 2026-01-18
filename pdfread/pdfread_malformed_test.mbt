///|
test "malformed pdf without xref uses fallback" {
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|trailer
    #|<< /Root 1 0 R /Size 3 >>
    #|%%EOF
  let pdf = @pdfread.pdf_of_input(None, None, @pdfio.input_of_string(data))
  assert_eq(pdf.root, 1)
  assert_eq(@pdf.objcard(pdf), 2)
  match @pdf.lookup_obj(pdf, 1) {
    @pdf.PdfObject::Dictionary(_) => ()
    _ => fail("expected catalog dictionary")
  }
}

///|
test "malformed pdf without trailer infers root" {
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|%%EOF
  let pdf = @pdfread.pdf_of_input(None, None, @pdfio.input_of_string(data))
  assert_eq(pdf.root, 1)
  match @pdf.lookup_immediate("/Root", pdf.trailerdict) {
    Some(@pdf.PdfObject::Indirect(1)) => ()
    _ => fail("expected /Root in trailer")
  }
}
