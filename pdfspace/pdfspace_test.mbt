///|
test "string_of_colourspace basic" {
  let s = string_of_colourspace(ColourSpace::DeviceRGB)
  assert_eq(s, "/DeviceRGB")
}

///|
test "read_colourspace device rgb" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let space = read_colourspace(
    pdf,
    resources,
    @pdf.PdfObject::Name("/DeviceRGB"),
  )
  match space {
    ColourSpace::DeviceRGB => ()
    _ => fail("expected DeviceRGB")
  }
}

///|
test "read_colourspace indexed" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let lookup = @pdf.PdfObject::String("\x01\x02\x03")
  let space = read_colourspace(
    pdf,
    resources,
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Name("/DeviceRGB"),
      @pdf.PdfObject::Integer(0),
      lookup,
    ]),
  )
  match space {
    ColourSpace::Indexed(ColourSpace::DeviceRGB, table) =>
      match table.get(0) {
        Some(values) => {
          assert_eq(values.length(), 3)
          assert_eq(values[0], 1)
          assert_eq(values[1], 2)
          assert_eq(values[2], 3)
        }
        None => fail("missing indexed table entry")
      }
    _ => fail("expected Indexed DeviceRGB")
  }
}
