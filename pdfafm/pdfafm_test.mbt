///|
fn find_header(headers : Array[(String, String)], key : String) -> String? {
  for pair in headers {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
test "read minimal afm" {
  let afm = "StartFontMetrics 2.0\n" +
    "FontName TestFont\n" +
    "StartCharMetrics 1\n" +
    "C 65 ; WX 600 ; N A ;\n" +
    "EndCharMetrics\n" +
    "StartKernPairs 1\n" +
    "KPX A A -50\n" +
    "EndKernPairs\n" +
    "EndFontMetrics\n"
  let input = @pdfio.input_of_string(afm, source="afm")
  let (headers, widths, kerns, widths_prime) = read(input)
  match find_header(headers, "FontName") {
    Some(value) => assert_eq(value, "TestFont")
    None => fail("expected FontName")
  }
  assert_true(widths.length() > 0)
  assert_true(widths_prime.length() > 0)
  assert_true(kerns.length() >= 0)
}
