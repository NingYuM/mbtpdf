///|
test "parse inline image flate data" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    ("/CS", @pdf.PdfObject::Name("/DeviceGray")),
  ])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x7f]))),
  ])
  let stream = @pdfio.bytes_of_string(rendered)
  let ops = @pdfops.parse_single_stream(pdf, resources, stream)
  let mut saw = false
  for op in ops {
    match op {
      @pdfops.Op::InlineImage((dict, _, data)) => {
        match @pdf.lookup_direct(pdf, "/W", dict) {
          Some(@pdf.PdfObject::Integer(1)) => ()
          _ => fail("expected width entry")
        }
        assert_eq(@pdfio.bytes_size(data), 1)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image uses resources for colorspace" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    (
      "/ColorSpace",
      @pdf.PdfObject::Dictionary([("/Cs1", @pdf.PdfObject::Name("/DeviceRGB"))]),
    ),
  ])
  let old = @pdfops.debug.val
  @pdfops.debug.val = true
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    ("/CS", @pdf.PdfObject::Name("/Cs1")),
  ])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_string("RGB"))),
  ])
  let stream = @pdfio.bytes_of_string(rendered)
  let ops = @pdfops.parse_single_stream(pdf, resources, stream)
  @pdfops.debug.val = old
  let mut saw = false
  for op in ops {
    match op {
      @pdfops.Op::InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 3)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image handles DCT data" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    ("/CS", @pdf.PdfObject::Name("/DeviceRGB")),
    ("/Filter", @pdf.PdfObject::Name("/DCT")),
  ])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0xFF, 0xD9]))),
  ])
  let stream = @pdfio.bytes_of_string(rendered)
  let ops = @pdfops.parse_single_stream(pdf, resources, stream)
  let mut saw = false
  for op in ops {
    match op {
      @pdfops.Op::InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 2)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "string_of_ops ignores non-name inline filters" {
  let dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Integer(1)),
  ])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x61]))),
  ])
  assert_true(rendered.contains("BI"))
  assert_true(rendered.contains("EI"))
}

///|
test "parse inline image handles colorspace array" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    (
      "/CS",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Indexed"),
        @pdf.PdfObject::Name("/DeviceRGB"),
        @pdf.PdfObject::Integer(1),
        @pdf.PdfObject::String(""),
      ]),
    ),
  ])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x12]))),
  ])
  let ops = @pdfops.parse_single_stream(
    pdf,
    resources,
    @pdfio.bytes_of_string(rendered),
  )
  let mut saw = false
  for op in ops {
    match op {
      @pdfops.Op::InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 1)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image uses ImageMask when colorspace missing" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(2)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(1)),
    ("/IM", @pdf.PdfObject::Boolean(true)),
  ])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x80]))),
  ])
  let ops = @pdfops.parse_single_stream(
    pdf,
    resources,
    @pdfio.bytes_of_string(rendered),
  )
  let mut saw = false
  for op in ops {
    match op {
      @pdfops.Op::InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 1)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image decodes flate filter" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let raw = @pdfio.bytes_of_list([0x7f])
  let encoded = @pdfcodec.encode_flate(raw)
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    ("/CS", @pdf.PdfObject::Name("/DeviceGray")),
    ("/Filter", @pdf.PdfObject::Name("/FlateDecode")),
  ])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::InlineImage((dict, None, encoded)),
  ])
  let ops = @pdfops.parse_single_stream(
    pdf,
    resources,
    @pdfio.bytes_of_string(rendered),
  )
  let mut saw = false
  for op in ops {
    match op {
      @pdfops.Op::InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 1)
        assert_eq(@pdfio.bget_unsafe(data, 0), 0x7f)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image errors on invalid filter array" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    ("/CS", @pdf.PdfObject::Name("/DeviceGray")),
    ("/Filter", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(1)])),
  ])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x00]))),
  ])
  let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.parse_single_stream(
    pdf,
    resources,
    @pdfio.bytes_of_string(rendered),
  )
  assert_true(res is Err(_))
}

///|
test "components handles indexed shorthand and errors" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let indexed = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/I"),
    @pdf.PdfObject::Name("/DeviceRGB"),
  ])
  assert_eq(@pdfops.components(pdf, resources, indexed), 1)
  let bad_first : Result[Int, Error] = try? @pdfops.components(
    pdf,
    resources,
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Integer(1),
      @pdf.PdfObject::Name("/DeviceRGB"),
    ]),
  )
  assert_true(bad_first is Err(_))
}

///|
test "parse_single_stream errors on ID keyword" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let old = @pdfread.read_debug.val
  @pdfread.read_debug.val = true
  let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.parse_single_stream(
    pdf,
    resources,
    @pdfio.bytes_of_string("ID"),
  )
  @pdfread.read_debug.val = old
  assert_true(res is Err(_))
}
