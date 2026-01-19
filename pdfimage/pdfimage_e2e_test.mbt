///|
test "colspace and bpc handle image masks" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/ImageMask", @pdf.PdfObject::Boolean(true)),
  ])
  let space = @pdfimage.colspace(pdf, dict, @pdf.PdfObject::Dictionary([]))
  match space {
    @pdfspace.ColourSpace::DeviceGray => ()
    _ => fail("expected DeviceGray")
  }
  match @pdfimage.bpc(pdf, dict) {
    Some(@pdf.PdfObject::Integer(1)) => ()
    _ => fail("expected bpc of 1")
  }
}

///|
test "get_image_24bpp decodes raw rgb image" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Image")),
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceRGB")),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/Length", @pdf.PdfObject::Integer(3)),
  ])
  let data = @pdfio.bytes_of_list([0x10, 0x20, 0x30])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let image = @pdfimage.get_image_24bpp(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    stream,
  )
  match image {
    Image::Raw(w, h, _, bytes) => {
      assert_eq(w, 1)
      assert_eq(h, 1)
      assert_true(@pdfio.bytes_size(bytes) > 0)
    }
    _ => fail("expected raw image")
  }
}

///|
test "get_image_24bpp applies decode for 1bpp" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Image")),
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceGray")),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(1)),
    (
      "/Decode",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(0.0),
      ]),
    ),
    ("/Length", @pdf.PdfObject::Integer(1)),
  ])
  let data = @pdfio.bytes_of_list([0x00])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let image = @pdfimage.get_image_24bpp(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    stream,
  )
  match image {
    Image::Raw(w, h, _, bytes) => {
      assert_eq(w, 1)
      assert_eq(h, 1)
      assert_true(@pdfio.bytes_size(bytes) > 0)
    }
    _ => fail("expected raw image")
  }
}
