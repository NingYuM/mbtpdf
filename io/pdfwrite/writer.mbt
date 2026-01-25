///|
pub struct PdfWrite {
  unit : Unit
}

///|
pub fn PdfWrite::new() -> PdfWrite {
  { unit: () }
}

///|
type PdfObject = @pdf.PdfObject
