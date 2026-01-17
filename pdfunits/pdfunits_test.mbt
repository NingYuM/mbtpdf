///|
test "points and inches conversions" {
  assert_eq(@pdfunits.points(1.0, @pdfunits.Unit::PdfPoint), 1.0)
  assert_eq(@pdfunits.points(1.0, @pdfunits.Unit::Inch), 72.0)
  assert_eq(@pdfunits.inches(72.0, @pdfunits.Unit::PdfPoint), 1.0)
  assert_eq(@pdfunits.inches(2.0, @pdfunits.Unit::Inch), 2.0)
}
