///|
test "crypt decode from input" {
  let bytes = @pdfio.bytes_of_string("abc")
  let input = @pdfio.input_of_bytes(bytes, source="crypt")
  let dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/Crypt")),
  ])
  let decoded = match decode_from_input(input, dict) {
    Some(result) => result
    None => fail("expected decoded bytes")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "abc")
}
