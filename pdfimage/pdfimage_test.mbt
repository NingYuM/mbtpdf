///|
test "colspace uses image mask" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let image = @pdf.PdfObject::Dictionary([
    ("/ImageMask", @pdf.PdfObject::Boolean(true)),
  ])
  let space = @pdfimage.colspace(pdf, image, resources)
  match space {
    @pdfspace.ColourSpace::DeviceGray => ()
    _ => fail("expected DeviceGray")
  }
}

///|
test "colspace resolves named resource" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    (
      "/ColorSpace",
      @pdf.PdfObject::Dictionary([("/CS1", @pdf.PdfObject::Name("/DeviceRGB"))]),
    ),
  ])
  let image = @pdf.PdfObject::Dictionary([("/CS", @pdf.PdfObject::Name("/CS1"))])
  let space = @pdfimage.colspace(pdf, image, resources)
  match space {
    @pdfspace.ColourSpace::DeviceRGB => ()
    _ => fail("expected DeviceRGB")
  }
}

///|
test "bpc returns component bits" {
  let pdf = @pdf.empty()
  let image = @pdf.PdfObject::Dictionary([("/BPC", @pdf.PdfObject::Integer(8))])
  match @pdfimage.bpc(pdf, image) {
    Some(@pdf.PdfObject::Integer(8)) => ()
    _ => fail("expected /BPC 8")
  }
}

///|
test "bpc defaults to image mask" {
  let pdf = @pdf.empty()
  let image = @pdf.PdfObject::Dictionary([
    ("/ImageMask", @pdf.PdfObject::Boolean(true)),
  ])
  match @pdfimage.bpc(pdf, image) {
    Some(@pdf.PdfObject::Integer(1)) => ()
    _ => fail("expected /BPC 1 for image mask")
  }
}

///|
test "bpc none when absent" {
  let pdf = @pdf.empty()
  let image = @pdf.PdfObject::Dictionary([])
  match @pdfimage.bpc(pdf, image) {
    None => ()
    _ => fail("expected None")
  }
}
