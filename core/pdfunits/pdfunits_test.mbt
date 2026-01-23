///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.001)
}

///|
test "points conversions" {
  assert_close(@pdfunits.points(1.0, @pdfunits.LengthUnit::PdfPoint), 1.0)
  assert_close(@pdfunits.points(1.0, @pdfunits.LengthUnit::Inch), 72.0)
  assert_close(@pdfunits.points(2.54, @pdfunits.LengthUnit::Centimetre), 72.0)
  assert_close(@pdfunits.points(25.4, @pdfunits.LengthUnit::Millimetre), 72.0)
}

///|
test "inches conversions" {
  assert_close(@pdfunits.inches(1.0, @pdfunits.LengthUnit::Inch), 1.0)
  assert_close(@pdfunits.inches(72.0, @pdfunits.LengthUnit::PdfPoint), 1.0)
  assert_close(@pdfunits.inches(2.54, @pdfunits.LengthUnit::Centimetre), 1.0)
  assert_close(@pdfunits.inches(25.4, @pdfunits.LengthUnit::Millimetre), 1.0)
}

///|
test "centimetres conversions" {
  assert_close(
    @pdfunits.centimetres(1.0, @pdfunits.LengthUnit::Centimetre),
    1.0,
  )
  assert_close(@pdfunits.centimetres(1.0, @pdfunits.LengthUnit::Inch), 2.54)
  assert_close(
    @pdfunits.centimetres(10.0, @pdfunits.LengthUnit::Millimetre),
    1.0,
  )
  assert_close(
    @pdfunits.centimetres(28.3456, @pdfunits.LengthUnit::PdfPoint),
    1.0,
  )
}

///|
test "millimetres conversions" {
  assert_close(
    @pdfunits.millimetres(1.0, @pdfunits.LengthUnit::Millimetre),
    1.0,
  )
  assert_close(
    @pdfunits.millimetres(1.0, @pdfunits.LengthUnit::Centimetre),
    10.0,
  )
  assert_close(@pdfunits.millimetres(1.0, @pdfunits.LengthUnit::Inch), 25.4)
}
