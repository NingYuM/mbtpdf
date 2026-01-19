///|
test "landscape swaps width and height" {
  let paper = @pdfpaper.make(@pdfunits.LengthUnit::Inch, 8.5, 11.0)
  let swapped = @pdfpaper.landscape(paper)
  assert_eq(@pdfpaper.width(swapped), 11.0)
  assert_eq(@pdfpaper.height(swapped), 8.5)
}

///|
test "paper accessors return values" {
  let paper = @pdfpaper.make(@pdfunits.LengthUnit::Centimetre, 10.0, 20.0)
  match @pdfpaper.unit(paper) {
    @pdfunits.LengthUnit::Centimetre => ()
    _ => fail("expected centimetre unit")
  }
  assert_eq(@pdfpaper.width(paper), 10.0)
  assert_eq(@pdfpaper.height(paper), 20.0)
}

///|
test "paper constants match expected sizes" {
  match @pdfpaper.unit(@pdfpaper.a4) {
    @pdfunits.LengthUnit::Millimetre => ()
    _ => fail("expected millimetre unit")
  }
  assert_eq(@pdfpaper.width(@pdfpaper.a4), 210.0)
  assert_eq(@pdfpaper.height(@pdfpaper.a4), 297.0)
  match @pdfpaper.unit(@pdfpaper.usletter) {
    @pdfunits.LengthUnit::Inch => ()
    _ => fail("expected inch unit")
  }
  assert_eq(@pdfpaper.width(@pdfpaper.usletter), 8.5)
  assert_eq(@pdfpaper.height(@pdfpaper.usletter), 11.0)
  match @pdfpaper.unit(@pdfpaper.uslegal) {
    @pdfunits.LengthUnit::Inch => ()
    _ => fail("expected inch unit")
  }
  assert_eq(@pdfpaper.width(@pdfpaper.uslegal), 8.5)
  assert_eq(@pdfpaper.height(@pdfpaper.uslegal), 14.0)
}
