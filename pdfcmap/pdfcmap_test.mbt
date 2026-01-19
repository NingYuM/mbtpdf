///|
fn find_value(pairs : Array[(String, String)], key : String) -> String? {
  for pair in pairs {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
test "parse_cmap parses bfchar and bfrange" {
  let data = @pdfio.bytes_of_string(
    "/WMode 1 beginbfchar<01><0041>endbfchar" +
    " beginbfrange<02><03><0042>endbfrange",
  )
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(data))),
  ])
  let cmap = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let parsed = @pdfcmap.parse_cmap(@pdf.empty(), cmap)
  assert_eq(parsed.wmode, Some(1))
  let key01 = @pdfio.string_of_int_array([0x01])
  let key02 = @pdfio.string_of_int_array([0x02])
  let key03 = @pdfio.string_of_int_array([0x03])
  let u0041 = @pdfio.string_of_int_array([0x00, 0x41])
  let u0042 = @pdfio.string_of_int_array([0x00, 0x42])
  let u0043 = @pdfio.string_of_int_array([0x00, 0x43])
  assert_eq(find_value(parsed.map, key01), Some(u0041))
  assert_eq(find_value(parsed.map, key02), Some(u0042))
  assert_eq(find_value(parsed.map, key03), Some(u0043))
}
