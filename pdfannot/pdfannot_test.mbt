///|
test "annotation border dash array" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let page = @pdfpage.custompage(rect)
  let border = @pdfannot.make_border(1.0, dasharray=[2, 3])
  let annot = @pdfannot.make(@pdfannot.Subtype::Text, border~)
  let updated = @pdfannot.add_annotation(pdf, page, annot)
  match @pdf.lookup_direct(pdf, "/Annots", updated.rest) {
    Some(@pdf.PdfObject::Array([annot_obj, ..])) =>
      match @pdf.lookup_direct(pdf, "/Border", annot_obj) {
        Some(@pdf.PdfObject::Array([_, _, _, @pdf.PdfObject::Array(dash)])) => {
          assert_eq(dash.length(), 2)
          match dash[0] {
            @pdf.PdfObject::Integer(2) => ()
            _ => fail("expected dash value 2")
          }
        }
        _ => fail("expected border dash array")
      }
    _ => fail("expected /Annots array")
  }
}
