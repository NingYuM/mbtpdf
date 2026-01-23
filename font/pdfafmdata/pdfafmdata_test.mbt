///|
fn assert_deflated(data : Array[Byte]) -> Unit raise {
  assert_true(data.length() > 0)
  assert_eq(data[0].to_int(), 0x78)
}

///|
test "afm data blocks are present" {
  assert_deflated(courier_afm())
  assert_deflated(courier_bold_afm())
  assert_deflated(courier_bold_oblique_afm())
  assert_deflated(courier_oblique_afm())
  assert_deflated(helvetica_afm())
  assert_deflated(helvetica_bold_afm())
  assert_deflated(helvetica_bold_oblique_afm())
  assert_deflated(helvetica_oblique_afm())
  assert_deflated(symbol_afm())
  assert_deflated(times_bold_afm())
  assert_deflated(times_bold_italic_afm())
  assert_deflated(times_italic_afm())
  assert_deflated(times_roman_afm())
  assert_deflated(zapf_dingbats_afm())
}
