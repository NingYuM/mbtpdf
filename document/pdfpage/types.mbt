///|
/// The type of the four rotations of pages.
pub(all) enum Rotation {
  Rotate0
  Rotate90
  Rotate180
  Rotate270
} derive(Debug)

///|
/// A type representing a page.
pub(all) struct Page {
  content : Array[@pdf.PdfObject]
  mediabox : @pdf.PdfObject
  resources : @pdf.PdfObject
  rotate : Rotation
  rest : @pdf.PdfObject
}

///|
/// Create a page with empty content and no extra dictionary entries.
pub fn Page::custom(rectangle : @pdf.PdfObject) -> Page {
  {
    content: [],
    mediabox: rectangle,
    resources: @pdf.PdfObject::Dictionary([]),
    rotate: Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
}

///|
/// Create a blank page using the given paper size.
pub fn Page::blank(paper : @pdfpaper.Paper) -> Page {
  Page::custom(paper.rectangle())
}

///|
/// Convert rotation to integers.
pub fn Rotation::to_int(self : Rotation) -> Int {
  match self {
    Rotation::Rotate0 => 0
    Rotation::Rotate90 => 90
    Rotation::Rotate180 => 180
    Rotation::Rotate270 => 270
  }
}

///|
/// Convert an integer to rotation.
pub fn Rotation::from_int(i : Int) -> Rotation raise {
  let r = i % 360
  match r {
    0 => Rotation::Rotate0
    90 | -270 => Rotation::Rotate90
    180 | -180 => Rotation::Rotate180
    270 | -90 => Rotation::Rotate270
    _ => raise @pdf.PdfError::Msg("Bad /Rotate")
  }
}
