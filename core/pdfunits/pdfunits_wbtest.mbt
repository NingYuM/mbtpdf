///|
fn unit_pdf_point() -> LengthUnit {
  LengthUnit::PdfPoint
}

///|
fn unit_inch() -> LengthUnit {
  LengthUnit::Inch
}

///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "points and inches conversions" {
  let pdf_point = unit_pdf_point()
  let inch = unit_inch()
  assert_close(points(1.0, pdf_point), 1.0)
  assert_close(points(1.0, inch), 72.0)
  assert_close(inches(72.0, pdf_point), 1.0)
}
