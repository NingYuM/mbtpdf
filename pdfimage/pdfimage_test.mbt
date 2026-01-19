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
test "get_image_24bpp applies decode for 8bpp" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_list([0, 255, 0])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceRGB")),
    (
      "/Decode",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(0.0),
      ]),
    ),
  ])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(_, _, _, bytes) => {
      assert_eq(bytes[0].to_int(), 1)
      assert_eq(bytes[1].to_int(), 0)
      assert_eq(bytes[2].to_int(), 1)
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

///|
test "get_image_24bpp returns jpeg2000 for JPX filter" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceRGB")),
    ("/Filter", @pdf.PdfObject::Name("/JPXDecode")),
  ])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::JPEG2000(bytes, _) => assert_eq(bytes.length(), 3)
    _ => fail("expected JPEG2000 image")
  }
}

///|
test "get_image_24bpp returns JBIG2 with globals" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let globals = @pdf.addobj(pdf, @pdf.PdfObject::Dictionary([]))
  let data = @pdfio.bytes_of_list([9, 8, 7])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(1)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceGray")),
    ("/Filter", @pdf.PdfObject::Name("/JBIG2Decode")),
    (
      "/DecodeParms",
      @pdf.PdfObject::Dictionary([
        ("/JBIG2Globals", @pdf.PdfObject::Indirect(globals)),
      ]),
    ),
  ])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::JBIG2(bytes, _, globals_ref) => {
      assert_eq(bytes.length(), 3)
      assert_eq(globals_ref, None)
    }
    _ => fail("expected JBIG2 image")
  }
}

///|
fn sample_tint_function() -> @pdffun.PdfFunction {
  {
    func: @pdffun.PdfFunctionKind::Interpolation({
      c0: [0.0],
      c1: [1.0],
      n: 1.0,
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
}

///|
fn sample_cmyk_function() -> @pdffun.PdfFunction {
  {
    func: @pdffun.PdfFunctionKind::Interpolation({
      c0: [0.0, 0.0, 0.0, 0.0],
      c1: [0.0, 0.0, 0.0, 1.0],
      n: 1.0,
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0]),
  }
}

///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
test "get_image_24bpp default decode for Lab" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let lab = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/Lab"),
    @pdf.PdfObject::Dictionary([
      (
        "/WhitePoint",
        @pdf.PdfObject::Array([1.0, 1.0, 1.0].map(v => @pdf.PdfObject::Real(v))),
      ),
      (
        "/BlackPoint",
        @pdf.PdfObject::Array([0.0, 0.0, 0.0].map(v => @pdf.PdfObject::Real(v))),
      ),
      (
        "/Range",
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Real(-128.0),
          @pdf.PdfObject::Real(127.0),
          @pdf.PdfObject::Real(-128.0),
          @pdf.PdfObject::Real(127.0),
        ]),
      ),
    ]),
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", lab),
    ("/Filter", @pdf.PdfObject::Name("/DCTDecode")),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::JPEG(_, Some(decode)) => {
      assert_eq(decode.length(), 6)
      assert_eq(decode[0], 0.0)
      assert_eq(decode[1], 1.0)
    }
    _ => fail("expected JPEG image with decode")
  }
}

///|
test "get_image_24bpp default decode for ICCBased" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let icc_dict = @pdf.PdfObject::Dictionary([
    ("/N", @pdf.PdfObject::Integer(3)),
    (
      "/Range",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(1.0),
      ]),
    ),
  ])
  let icc_stream = @pdf.PdfObject::Stream(
    Ref::new((icc_dict, @pdf.Stream::Got(@pdfio.bytes_of_list([0])))),
  )
  let colorspace = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/ICCBased"),
    icc_stream,
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", colorspace),
    ("/Filter", @pdf.PdfObject::Name("/DCTDecode")),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::JPEG(_, Some(decode)) => assert_eq(decode.length(), 6)
    _ => fail("expected JPEG image with decode")
  }
}

///|
test "get_image_24bpp default decode for DeviceN" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let tint = @pdffun.pdfobject_of_function(pdf, sample_tint_function())
  let colorspace = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/DeviceN"),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/C1"),
      @pdf.PdfObject::Name("/C2"),
    ]),
    @pdf.PdfObject::Name("/DeviceRGB"),
    tint,
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", colorspace),
    ("/Filter", @pdf.PdfObject::Name("/DCTDecode")),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::JPEG(_, Some(decode)) => assert_eq(decode.length(), 4)
    _ => fail("expected JPEG image with decode")
  }
}

///|
test "get_image_24bpp decode ignored for indexed DCT" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list([0, 0, 0]))
  let colorspace = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/Indexed"),
    @pdf.PdfObject::Name("/DeviceRGB"),
    @pdf.PdfObject::Integer(0),
    @pdf.PdfObject::String(table),
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", colorspace),
    ("/Filter", @pdf.PdfObject::Name("/DCTDecode")),
    (
      "/Decode",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(1.0),
      ]),
    ),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::JPEG(_, decode) => assert_true(decode is None)
    _ => fail("expected JPEG image")
  }
}

///|
test "get_image_24bpp default decode none for Pattern" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", @pdf.PdfObject::Name("/Pattern")),
    ("/Filter", @pdf.PdfObject::Name("/DCTDecode")),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::JPEG(_, decode) => assert_true(decode is None)
    _ => fail("expected JPEG image")
  }
}

///|
test "get_image_24bpp converts gray to rgb" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_list([128])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceGray")),
  ])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 128)
      assert_eq(bytes[1].to_int(), 128)
      assert_eq(bytes[2].to_int(), 128)
    }
    _ => fail("expected Raw gray image")
  }
}

///|
test "get_image_24bpp converts cmyk to rgb" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_list([0, 0, 0, 0])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceCMYK")),
  ])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[1].to_int(), 255)
      assert_eq(bytes[2].to_int(), 255)
    }
    _ => fail("expected Raw cmyk image")
  }
}

///|
test "get_image_24bpp handles indexed RGB" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list([0, 0, 0, 255, 0, 0]))
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    (
      "/ColorSpace",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Indexed"),
        @pdf.PdfObject::Name("/DeviceRGB"),
        @pdf.PdfObject::Integer(1),
        @pdf.PdfObject::String(table),
      ]),
    ),
  ])
  let data = @pdfio.bytes_of_list([1])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[1].to_int(), 0)
      assert_eq(bytes[2].to_int(), 0)
    }
    _ => fail("expected indexed RGB image")
  }
}

///|
test "get_image_24bpp handles indexed CMYK" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let table = @pdfio.string_of_bytes(
    @pdfio.bytes_of_list([0, 0, 0, 255, 0, 0, 0, 0]),
  )
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    (
      "/ColorSpace",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Indexed"),
        @pdf.PdfObject::Name("/DeviceCMYK"),
        @pdf.PdfObject::Integer(1),
        @pdf.PdfObject::String(table),
      ]),
    ),
  ])
  let data = @pdfio.bytes_of_list([1])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[1].to_int(), 255)
      assert_eq(bytes[2].to_int(), 255)
    }
    _ => fail("expected indexed CMYK image")
  }
}

///|
test "get_image_24bpp handles indexed Lab" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let lab = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/Lab"),
    @pdf.PdfObject::Dictionary([
      (
        "/WhitePoint",
        @pdf.PdfObject::Array([1.0, 1.0, 1.0].map(v => @pdf.PdfObject::Real(v))),
      ),
      (
        "/BlackPoint",
        @pdf.PdfObject::Array([0.0, 0.0, 0.0].map(v => @pdf.PdfObject::Real(v))),
      ),
    ]),
  ])
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list([127, 127, 127]))
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    (
      "/ColorSpace",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Indexed"),
        lab,
        @pdf.PdfObject::Integer(0),
        @pdf.PdfObject::String(table),
      ]),
    ),
  ])
  let data = @pdfio.bytes_of_list([0])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected indexed Lab image")
  }
}

///|
test "get_image_24bpp indexed rgb missing table entry" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list([0, 0, 0]))
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    (
      "/ColorSpace",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Indexed"),
        @pdf.PdfObject::Name("/DeviceRGB"),
        @pdf.PdfObject::Integer(0),
        @pdf.PdfObject::String(table),
      ]),
    ),
  ])
  let data = @pdfio.bytes_of_list([1])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let result : Result[@pdfimage.Image, Error] = try? @pdfimage.get_image_24bpp(
    pdf, resources, stream,
  )
  assert_true(result is Err(_))
}

///|
test "get_image_24bpp handles 4bpp gray" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(2)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(4)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceGray")),
  ])
  let data = @pdfio.bytes_of_list([0xf0])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 6)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[3].to_int(), 0)
    }
    _ => fail("expected 4bpp gray image")
  }
}

///|
test "get_image_24bpp rejects bad decode" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceRGB")),
    (
      "/Decode",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(0.0),
      ]),
    ),
  ])
  let data = @pdfio.bytes_of_list([0, 0, 0])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let result : Result[@pdfimage.Image, Error] = try? @pdfimage.get_image_24bpp(
    pdf, resources, stream,
  )
  assert_true(result is Err(_))
}

///|
test "get_image_24bpp handles ICCBased raw" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let icc_dict = @pdf.PdfObject::Dictionary([("/N", @pdf.PdfObject::Integer(3))])
  let icc_stream = @pdf.PdfObject::Stream(
    Ref::new((icc_dict, @pdf.Stream::Got(@pdfio.bytes_of_list([0])))),
  )
  let colorspace = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/ICCBased"),
    icc_stream,
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0, 0, 0])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(w, h, layout, bytes) => {
      assert_eq(w, 1)
      assert_eq(h, 1)
      match layout {
        @pdfimage.PixelLayout::BPP24 => ()
        _ => fail("expected BPP24")
      }
      assert_eq(bytes.length(), 3)
    }
    _ => fail("expected raw ICCBased image")
  }
}

///|
test "get_image_24bpp handles separation cmyk" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let tint = @pdffun.pdfobject_of_function(pdf, sample_cmyk_function())
  let colorspace = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/Separation"),
    @pdf.PdfObject::Name("/Spot"),
    @pdf.PdfObject::Name("/DeviceCMYK"),
    tint,
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected separation image")
  }
}

///|
test "get_image_24bpp rejects bad separation function" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let tint = @pdffun.pdfobject_of_function(pdf, sample_tint_function())
  let colorspace = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/Separation"),
    @pdf.PdfObject::Name("/Spot"),
    @pdf.PdfObject::Name("/DeviceCMYK"),
    tint,
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  assert_is_err(try? @pdfimage.get_image_24bpp(pdf, resources, stream))
}

///|
test "get_image_24bpp default decode for separation DCT" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let tint = @pdffun.pdfobject_of_function(pdf, sample_tint_function())
  let colorspace = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/Separation"),
    @pdf.PdfObject::Name("/Spot"),
    @pdf.PdfObject::Name("/DeviceGray"),
    tint,
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", colorspace),
    ("/Filter", @pdf.PdfObject::Name("/DCTDecode")),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::JPEG(_, Some(decode)) => {
      assert_eq(decode.length(), 2)
      assert_eq(decode[0], 0.0)
      assert_eq(decode[1], 1.0)
    }
    _ => fail("expected JPEG decode")
  }
}

///|
test "get_image_24bpp loads ToGet stream" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Width", @pdf.PdfObject::Integer(1)),
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceRGB")),
    ("/Length", @pdf.PdfObject::Integer(3)),
  ])
  let data = @pdfio.bytes_of_list([0, 255, 0])
  let input = @pdfio.input_of_bytes(data)
  let toget = @pdf.toget(input, 0, 3)
  let stream = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::ToGet(toget))),
  )
  match @pdfimage.get_image_24bpp(pdf, resources, stream) {
    @pdfimage.Image::Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected raw image")
  }
}

///|
test "get_image_24bpp rejects missing width" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Height", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/ColorSpace", @pdf.PdfObject::Name("/DeviceRGB")),
  ])
  let data = @pdfio.bytes_of_list([0, 0, 0])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  assert_is_err(try? @pdfimage.get_image_24bpp(pdf, resources, stream))
}
