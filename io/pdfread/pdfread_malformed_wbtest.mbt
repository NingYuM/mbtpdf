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
  let pdf = pdf_of_input(None, None, @pdfio.input_of_string(data))
  assert_eq(pdf.root, 1)
  assert_eq(@pdf.objcard(pdf), 2)
  match (@pdf.lookup_obj(pdf, 1) : @pdf.PdfObject) {
    Dictionary(_) => ()
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
  let pdf = pdf_of_input(None, None, @pdfio.input_of_string(data))
  assert_eq(pdf.root, 1)
  match (@pdf.lookup_immediate("/Root", pdf.trailerdict) : @pdf.PdfObject?) {
    Some(Indirect(1)) => ()
    _ => fail("expected /Root in trailer")
  }
}

///|
test "malformed pdf honors error_on_malformed" {
  let prev = error_on_malformed.val
  error_on_malformed.val = true
  defer {
    error_on_malformed.val = prev
  }
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|%%EOF
  let res : Result[@pdf.Pdf, Error] = try? pdf_of_input(
    None,
    None,
    @pdfio.input_of_string(data),
  )
  assert_true(res is Err(_))
}

///|
test "malformed pdf skips bad objects and trailers" {
  let data =
    #|trailer %PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|3 0 obj
    #|>
    #|endobj
    #|trailer
    #|<< /Root 1 0 R
  let pdf = pdf_of_input(None, None, @pdfio.input_of_string(data))
  assert_eq(pdf.root, 1)
  assert_eq(@pdf.objcard(pdf), 2)
}

///|
async test "revision -1 returns revisions error" {
  let res : Result[@pdf.Pdf, Error] = try? pdf_of_file(
    revision=-1,
    None,
    None,
    "testdata/pdfjs_identity_tounicode.pdf",
  )
  assert_true(res is Err(_))
}
