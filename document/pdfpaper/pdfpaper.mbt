///|
/// Paper sizes for PDF page boxes.
pub struct Paper {
  unit : @pdfunits.LengthUnit
  width : Double
  height : Double
} derive(Debug)

///|
/// Make a paper size from unit, width, and height.
pub fn Paper::new(
  unit : @pdfunits.LengthUnit,
  width : Double,
  height : Double,
) -> Paper {
  { unit, width, height }
}

///|
/// Project the unit from a paper size.
pub fn Paper::unit(self : Paper) -> @pdfunits.LengthUnit {
  self.unit
}

///|
/// Project the width from a paper size.
pub fn Paper::width(self : Paper) -> Double {
  self.width
}

///|
/// Project the height from a paper size.
pub fn Paper::height(self : Paper) -> Double {
  self.height
}

///|
/// Convert a paper size to a PDF rectangle.
pub fn Paper::rectangle(self : Paper) -> @pdf.PdfObject {
  let unit = self.unit()
  let width = unit.to_points(self.width())
  let height = unit.to_points(self.height())
  @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(width),
    @pdf.PdfObject::Real(height),
  ])
}

///|
/// Flip a paper size between landscape and portrait.
pub fn Paper::landscape(self : Paper) -> Paper {
  { unit: self.unit, width: self.height, height: self.width }
}

///|
/// ISO A series paper sizes (portrait).
pub let a0 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 841.0,
  height: 1189.0,
}

///|
pub let a1 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 594.0,
  height: 841.0,
}

///|
pub let a2 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 420.0,
  height: 594.0,
}

///|
pub let a3 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 297.0,
  height: 420.0,
}

///|
pub let a4 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 210.0,
  height: 297.0,
}

///|
pub let a5 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 148.0,
  height: 210.0,
}

///|
pub let a6 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 105.0,
  height: 148.0,
}

///|
pub let a7 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 74.0,
  height: 105.0,
}

///|
pub let a8 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 52.0,
  height: 74.0,
}

///|
pub let a9 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 37.0,
  height: 52.0,
}

///|
pub let a10 : Paper = {
  unit: @pdfunits.LengthUnit::Millimetre,
  width: 26.0,
  height: 37.0,
}

///|
/// United States paper sizes (portrait).
pub let usletter : Paper = {
  unit: @pdfunits.LengthUnit::Inch,
  width: 8.5,
  height: 11.0,
}

///|
pub let uslegal : Paper = {
  unit: @pdfunits.LengthUnit::Inch,
  width: 8.5,
  height: 14.0,
}
