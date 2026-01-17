///|
/// Units for paper sizes and conversions.
pub(all) enum Unit {
  PdfPoint
  Inch
  Centimetre
  Millimetre
}

///|
/// Convert a measurement to points.
pub fn points(value : Double, unit : Unit) -> Double {
  match unit {
    Unit::PdfPoint => value
    Unit::Inch => value * 72.0
    Unit::Centimetre => value * 28.3465
    Unit::Millimetre => value * 2.83465
  }
}

///|
/// Convert a measurement to inches.
pub fn inches(value : Double, unit : Unit) -> Double {
  match unit {
    Unit::Inch => value
    Unit::PdfPoint => value / 72.0
    Unit::Centimetre => value / 2.54
    Unit::Millimetre => value / 25.4
  }
}

///|
/// Convert a measurement to centimetres.
pub fn centimetres(value : Double, unit : Unit) -> Double {
  match unit {
    Unit::Centimetre => value
    Unit::Inch => value * 2.54
    Unit::Millimetre => value / 10.0
    Unit::PdfPoint => value / 28.3456
  }
}

///|
/// Convert a measurement to millimetres.
pub fn millimetres(value : Double, unit : Unit) -> Double {
  centimetres(value, unit) * 10.0
}
