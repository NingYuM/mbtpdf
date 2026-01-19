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

///|
test "get_image_24bpp raw rgb" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_list([255, 0, 0, 0, 255, 0])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(2)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceRGB")),
  ])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(w, h, layout, bytes) => {
      assert_eq(w, 2)
      assert_eq(h, 1)
      match layout {
        @pdfimage.PixelLayout::BPP24 => ()
        _ => fail("expected BPP24 layout")
      }
      assert_eq(bytes.length(), 6)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[3].to_int(), 0)
    }
    _ => fail("expected Raw image")
  }
}

///|
test "get_image_24bpp applies decode for 1bpp" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_list([128])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(1)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceGray")),
    (
      "/Decode",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(0.0),
      ]),
    ),
  ])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 0)
    }
    _ => fail("expected Raw image")
  }
}

///|
test "get_image_24bpp returns jpeg for DCT filter" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_list([1, 2, 3, 4])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceRGB")),
    ("/Filter", @pdf.PdfObject::Name("/DCTDecode")),
  ])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::JPEG(bytes, decode) => {
      assert_eq(bytes.length(), 4)
      match decode {
        Some(arr) => assert_eq(arr.length(), 6)
        _ => fail("expected decode array")
      }
    }
    _ => fail("expected JPEG image")
  }
}
