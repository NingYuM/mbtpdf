///|
/// Units for paper sizes and conversions.
pub(all) enum LengthUnit {
  PdfPoint
  Inch
  Centimetre
  Millimetre
} derive(Debug)

///|
/// Convert a measurement to points.
pub fn LengthUnit::to_points(self : LengthUnit, value : Double) -> Double {
  match self {
    LengthUnit::PdfPoint => value
    LengthUnit::Inch => value * 72.0
    LengthUnit::Centimetre => value * 28.3465
    LengthUnit::Millimetre => value * 2.83465
  }
}

///|
/// Convert a measurement to inches.
pub fn LengthUnit::to_inches(self : LengthUnit, value : Double) -> Double {
  match self {
    LengthUnit::Inch => value
    LengthUnit::PdfPoint => value / 72.0
    LengthUnit::Centimetre => value / 2.54
    LengthUnit::Millimetre => value / 25.4
  }
}

///|
/// Convert a measurement to centimetres.
pub fn LengthUnit::to_centimetres(self : LengthUnit, value : Double) -> Double {
  match self {
    LengthUnit::Centimetre => value
    LengthUnit::Inch => value * 2.54
    LengthUnit::Millimetre => value / 10.0
    LengthUnit::PdfPoint => value / 28.3456
  }
}

///|
/// Convert a measurement to millimetres.
pub fn LengthUnit::to_millimetres(self : LengthUnit, value : Double) -> Double {
  self.to_centimetres(value) * 10.0
}
