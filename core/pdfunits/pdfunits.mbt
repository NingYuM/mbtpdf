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
pub fn points(value : Double, unit : LengthUnit) -> Double {
  match unit {
    LengthUnit::PdfPoint => value
    LengthUnit::Inch => value * 72.0
    LengthUnit::Centimetre => value * 28.3465
    LengthUnit::Millimetre => value * 2.83465
  }
}

///|
/// Convert a measurement to inches.
pub fn inches(value : Double, unit : LengthUnit) -> Double {
  match unit {
    LengthUnit::Inch => value
    LengthUnit::PdfPoint => value / 72.0
    LengthUnit::Centimetre => value / 2.54
    LengthUnit::Millimetre => value / 25.4
  }
}

///|
/// Convert a measurement to centimetres.
pub fn centimetres(value : Double, unit : LengthUnit) -> Double {
  match unit {
    LengthUnit::Centimetre => value
    LengthUnit::Inch => value * 2.54
    LengthUnit::Millimetre => value / 10.0
    LengthUnit::PdfPoint => value / 28.3456
  }
}

///|
/// Convert a measurement to millimetres.
pub fn millimetres(value : Double, unit : LengthUnit) -> Double {
  centimetres(value, unit) * 10.0
}
