///|
test "parse_single_object numbers" {
  let obj = @pdfread.parse_single_object("123")
  match obj {
    @pdf.PdfObject::Integer(123) => ()
    _ => fail("expected integer")
  }
  let obj2 = @pdfread.parse_single_object("-3.5")
  match obj2 {
    @pdf.PdfObject::Real(r) => if r != -3.5 { fail("expected -3.5") }
    _ => fail("expected real")
  }
}

///|
test "parse_single_object collections" {
  let obj = @pdfread.parse_single_object("[1 2 3]")
  match obj {
    @pdf.PdfObject::Array(values) =>
      if values.length() != 3 {
        fail("expected array length 3")
      }
    _ => fail("expected array")
  }
  let obj2 = @pdfread.parse_single_object("<< /Type /Example /Count 2 >>")
  match obj2 {
    @pdf.PdfObject::Dictionary(entries) =>
      if entries.length() != 2 {
        fail("expected dictionary length 2")
      }
    _ => fail("expected dictionary")
  }
}
