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
/// Make a PDF rectangle from a paper size.
pub fn rectangle_of_paper(paper : @pdfpaper.Paper) -> @pdf.PdfObject {
  let unit = paper.unit()
  let width = unit.to_points(paper.width())
  let height = unit.to_points(paper.height())
  @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(width),
    @pdf.PdfObject::Real(height),
  ])
}

///|
/// Create a page with empty content and no extra dictionary entries.
pub fn custompage(rectangle : @pdf.PdfObject) -> Page {
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
pub fn blankpage(paper : @pdfpaper.Paper) -> Page {
  custompage(rectangle_of_paper(paper))
}

///|
/// Convert rotation to integers.
pub fn int_of_rotation(rotation : Rotation) -> Int {
  match rotation {
    Rotation::Rotate0 => 0
    Rotation::Rotate90 => 90
    Rotation::Rotate180 => 180
    Rotation::Rotate270 => 270
  }
}

///|
/// Convert an integer to rotation.
pub fn rotation_of_int(i : Int) -> Rotation raise {
  let r = i % 360
  match r {
    0 => Rotation::Rotate0
    90 | -270 => Rotation::Rotate90
    180 | -180 => Rotation::Rotate180
    270 | -90 => Rotation::Rotate270
    _ => raise @pdf.PdfError::Msg("Bad /Rotate")
  }
}
