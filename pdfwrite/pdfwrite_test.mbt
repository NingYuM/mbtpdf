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

///|
test "string_of_pdf escapes names" {
  let obj = @pdf.PdfObject::Name("/A B#C/D")
  let s = @pdfwrite.string_of_pdf(obj)
  assert_eq(s, "/A#20B#23C#2FD")
}

///|
test "pdf_to_output writes binary header" {
  let pdf = build_minimal_pdf()
  let (output, buffer) = @pdfio.input_output_of_bytes(128)
  @pdfwrite.pdf_to_output(_encryption=None, _build_new_id=false, pdf, output)
  let bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let expected = [
    '%'.to_int(),
    'P'.to_int(),
    'D'.to_int(),
    'F'.to_int(),
    '-'.to_int(),
    '2'.to_int(),
    '.'.to_int(),
    '0'.to_int(),
    '\n'.to_int(),
    '%'.to_int(),
    128,
    129,
    130,
    131,
    '\n'.to_int(),
  ]
  if bytes.length() < expected.length() {
    fail("expected header length \{expected.length()}")
  }
  let mut i = 0
  while i < expected.length() {
    if bytes[i].to_int() != expected[i] {
      fail("unexpected header byte at \{i}")
    }
    i = i + 1
  }
}

///|
test "string_of_pdf formats reals without exponent" {
  let s = @pdfwrite.string_of_pdf(@pdf.PdfObject::Real(1e-6))
  assert_true(!s.contains("e") && !s.contains("E"))
}

///|
test "string_of_pdf trims trailing zeros" {
  let s = @pdfwrite.string_of_pdf(@pdf.PdfObject::Real(2.0))
  assert_eq(s, "2")
}
