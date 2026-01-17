///|
test "string_of_pdf basic" {
  let obj = @pdf.PdfObject::String("a(b)\\c")
  let s = @pdfwrite.string_of_pdf(obj)
  assert_eq(s, "(a\\(b\\)\\\\c)")
}

///|
test "string_of_pdf dictionary" {
  let obj = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Example")),
    ("/Count", @pdf.PdfObject::Integer(2)),
  ])
  let s = @pdfwrite.string_of_pdf(obj)
  assert_eq(s, "<</Type /Example /Count 2>>")
}
