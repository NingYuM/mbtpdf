///|
test "malformed pdf honors /Version in catalog when forced" {
  let prev = @pdfread.debug_always_treat_malformed.val
  @pdfread.debug_always_treat_malformed.val = true
  defer {
    @pdfread.debug_always_treat_malformed.val = prev
  }
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R /Version /1.7 >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|trailer
    #|<< /Root 1 0 R >>
    #|%%EOF
  let pdf = @pdfread.pdf_of_input(None, None, @pdfio.input_of_string(data))
  assert_eq(pdf.major, 1)
  assert_eq(pdf.minor, 7)
}

///|
test "malformed pdf falls back to catalog when /Root is direct" {
  let prev = @pdfread.debug_always_treat_malformed.val
  @pdfread.debug_always_treat_malformed.val = true
  defer {
    @pdfread.debug_always_treat_malformed.val = prev
  }
  let data =
    #|%PDF-1.4
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|trailer
    #|<< /Root 99 >>
    #|%%EOF
  let pdf = @pdfread.pdf_of_input(None, None, @pdfio.input_of_string(data))
  assert_eq(pdf.root, 1)
}

///|
test "malformed pdf without /Root and catalog errors" {
  let prev = @pdfread.debug_always_treat_malformed.val
  @pdfread.debug_always_treat_malformed.val = true
  defer {
    @pdfread.debug_always_treat_malformed.val = prev
  }
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|trailer
    #|<< /Size 2 >>
    #|trailer
  let res : Result[@pdf.Pdf, Error] = try? @pdfread.pdf_of_input(
    None,
    None,
    @pdfio.input_of_string(data),
  )
  assert_true(res is Err(_))
}

///|
test "malformed pdf ignores invalid /Version name" {
  let prev = @pdfread.debug_always_treat_malformed.val
  @pdfread.debug_always_treat_malformed.val = true
  defer {
    @pdfread.debug_always_treat_malformed.val = prev
  }
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R /Version /1.a >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|trailer
    #|<< /Root 1 0 R >>
    #|%%EOF
  let pdf = @pdfread.pdf_of_input(None, None, @pdfio.input_of_string(data))
  assert_eq(pdf.major, 1)
  assert_eq(pdf.minor, 4)
}
