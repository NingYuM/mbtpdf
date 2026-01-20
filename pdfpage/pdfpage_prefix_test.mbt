///|
fn prefix_sample_rect() -> @pdf.PdfObject {
  @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
}

///|
fn prefix_resources() -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("/F1", @pdf.PdfObject::Null)])),
    ("/ExtGState", @pdf.PdfObject::Dictionary([("/GS1", @pdf.PdfObject::Null)])),
    (
      "/ColorSpace",
      @pdf.PdfObject::Dictionary([("/Cs1", @pdf.PdfObject::Name("/DeviceRGB"))]),
    ),
    ("/Pattern", @pdf.PdfObject::Dictionary([("/P1", @pdf.PdfObject::Null)])),
    ("/Shading", @pdf.PdfObject::Dictionary([("/S1", @pdf.PdfObject::Null)])),
    ("/XObject", @pdf.PdfObject::Dictionary([("/X1", @pdf.PdfObject::Null)])),
    (
      "/Properties",
      @pdf.PdfObject::Dictionary([("/Prop1", @pdf.PdfObject::Null)]),
    ),
  ])
}

///|
test "shortest_unused_prefix handles dense prefixes" {
  let pdf0 = @pdf.empty()
  let font_entries = Array::new()
  for code in 'a'.to_int()..<='z'.to_int() {
    match code.to_char() {
      Some(ch) => font_entries.push(("/\{ch}0", @pdf.PdfObject::Null))
      None => fail("expected ASCII char")
    }
  }
  font_entries.push(("/az0", @pdf.PdfObject::Null))
  font_entries.push(("", @pdf.PdfObject::Null))
  let resources = @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary(font_entries)),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  ignore(@pdf.addobj(pdf, @pdf.PdfObject::Integer(1)))
  assert_eq(@pdfpage.shortest_unused_prefix(pdf), "bz")
}

///|
test "add_prefix rewrites resources and operators" {
  let pdf0 = @pdf.empty()
  let resources = prefix_resources()
  let ops_primary : Array[@pdfops.Op] = [
    @pdfops.Op::OpTf("/F1", 12.0),
    @pdfops.Op::Opgs("/GS1"),
    @pdfops.Op::OpCS("/DeviceRGB"),
    @pdfops.Op::OpCS("/Cs1"),
    @pdfops.Op::Opcs("/DeviceRGB"),
    @pdfops.Op::Opcs("/Cs1"),
    @pdfops.Op::OpSCNName("/P1", [0.1]),
    @pdfops.Op::OpscnName("/P1", [0.2]),
    @pdfops.Op::Opsh("/S1"),
    @pdfops.Op::OpDo("/X1"),
    @pdfops.Op::OpDP("/Tag", @pdf.PdfObject::Name("/Prop1")),
    @pdfops.Op::OpBDC("/Tag", @pdf.PdfObject::Name("/Prop1")),
  ]
  let ops_secondary : Array[@pdfops.Op] = [@pdfops.Op::Opq, @pdfops.Op::OpQ]
  let page : @pdfpage.Page = {
    content: [
      @pdfops.stream_of_ops(ops_primary),
      @pdfops.stream_of_ops(ops_secondary),
    ],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let page0 = pages[0]
  match @pdf.lookup_direct(pdf, "/Font", page0.resources) {
    Some(@pdf.PdfObject::Dictionary(entries)) =>
      assert_true(entries.any(pair => pair.0 == "/pF1"))
    _ => fail("expected prefixed font resources")
  }
  match @pdf.lookup_direct(pdf, "/ColorSpace", page0.resources) {
    Some(@pdf.PdfObject::Dictionary(entries)) =>
      assert_true(entries.any(pair => pair.0 == "/pCs1"))
    _ => fail("expected prefixed colorspace resources")
  }
  let ops = @pdfops.parse_operators(pdf, page0.resources, page0.content)
  let mut saw_tf = false
  let mut saw_gs = false
  let mut saw_cs_direct = false
  let mut saw_cs_prefixed = false
  let mut saw_scs_direct = false
  let mut saw_scs_prefixed = false
  let mut saw_scn = false
  let mut saw_scn_lower = false
  let mut saw_sh = false
  let mut saw_do = false
  let mut saw_dp = false
  let mut saw_bdc = false
  for op in ops {
    match op {
      @pdfops.Op::OpTf(name, _) => {
        assert_eq(name, "/pF1")
        saw_tf = true
      }
      @pdfops.Op::Opgs(name) => {
        assert_eq(name, "/pGS1")
        saw_gs = true
      }
      @pdfops.Op::OpCS(name) =>
        if name == "/DeviceRGB" {
          saw_cs_direct = true
        } else if name == "/pCs1" {
          saw_cs_prefixed = true
        } else {
          fail("unexpected OpCS")
        }
      @pdfops.Op::Opcs(name) =>
        if name == "/DeviceRGB" {
          saw_scs_direct = true
        } else if name == "/pCs1" {
          saw_scs_prefixed = true
        } else {
          fail("unexpected Opcs")
        }
      @pdfops.Op::OpSCNName(name, _) => {
        assert_eq(name, "/pP1")
        saw_scn = true
      }
      @pdfops.Op::OpscnName(name, _) => {
        assert_eq(name, "/pP1")
        saw_scn_lower = true
      }
      @pdfops.Op::Opsh(name) => {
        assert_eq(name, "/pS1")
        saw_sh = true
      }
      @pdfops.Op::OpDo(name) => {
        assert_eq(name, "/pX1")
        saw_do = true
      }
      @pdfops.Op::OpDP(_, @pdf.PdfObject::Name(name)) => {
        assert_eq(name, "/pProp1")
        saw_dp = true
      }
      @pdfops.Op::OpBDC(_, @pdf.PdfObject::Name(name)) => {
        assert_eq(name, "/pProp1")
        saw_bdc = true
      }
      _ => ()
    }
  }
  assert_true(saw_tf && saw_gs)
  assert_true(saw_cs_direct && saw_cs_prefixed)
  assert_true(saw_scs_direct && saw_scs_prefixed)
  assert_true(saw_scn && saw_scn_lower)
  assert_true(saw_sh && saw_do)
  assert_true(saw_dp && saw_bdc)
}

///|
test "add_prefix rewrites inline image colorspace names" {
  let pdf0 = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    (
      "/ColorSpace",
      @pdf.PdfObject::Dictionary([("/CS1", @pdf.PdfObject::Name("/DeviceRGB"))]),
    ),
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    ("/CS", @pdf.PdfObject::Name("/CS1")),
  ])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_string("RGB"))),
  ]
  let page : @pdfpage.Page = {
    content: [@pdfops.stream_of_ops(ops)],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let ops_out = @pdfops.parse_operators(
    pdf,
    pages[0].resources,
    pages[0].content,
  )
  let mut saw = false
  for op in ops_out {
    match op {
      @pdfops.Op::InlineImage((inline_dict, _, _)) =>
        match @pdf.lookup_direct(pdf, "/CS", inline_dict) {
          Some(@pdf.PdfObject::Name(name)) => {
            assert_eq(name, "/pCS1")
            saw = true
          }
          _ => fail("expected prefixed inline colorspace")
        }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "add_prefix handles filtered inline images with trailing ops" {
  let pdf0 = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    (
      "/ColorSpace",
      @pdf.PdfObject::Dictionary([("/CS1", @pdf.PdfObject::Name("/DeviceRGB"))]),
    ),
  ])
  let raw = @pdfio.bytes_of_list([0x11, 0x22, 0x33])
  let encoded = @pdfcodec.encode_flate(raw)
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    ("/CS", @pdf.PdfObject::Name("/CS1")),
    ("/Filter", @pdf.PdfObject::Name("/FlateDecode")),
  ])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::InlineImage((dict, None, encoded)),
    @pdfops.Op::Opq,
    @pdfops.Op::OpQ,
  ]
  let page : @pdfpage.Page = {
    content: [@pdfops.stream_of_ops(ops)],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let ops_out = @pdfops.parse_operators(
    pdf,
    pages[0].resources,
    pages[0].content,
  )
  let mut saw_inline = false
  let mut saw_q = false
  for op in ops_out {
    match op {
      @pdfops.Op::InlineImage((inline_dict, _, _)) =>
        match @pdf.lookup_direct(pdf, "/CS", inline_dict) {
          Some(@pdf.PdfObject::Name(name)) => {
            assert_eq(name, "/pCS1")
            saw_inline = true
          }
          _ => fail("expected prefixed inline colorspace")
        }
      @pdfops.Op::Opq | @pdfops.Op::OpQ => saw_q = true
      _ => ()
    }
  }
  assert_true(saw_inline && saw_q)
}

///|
test "add_prefix rejects blank resource names" {
  let pdf0 = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("", @pdf.PdfObject::Null)])),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  let result : Result[Unit, Error] = try? @pdfpage.add_prefix(pdf, "p")
  assert_true(result is Err(_))
}

///|
test "add_prefix handles single indirect contents" {
  let pdf0 = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("/F1", @pdf.PdfObject::Null)])),
  ])
  let ops : Array[@pdfops.Op] = [@pdfops.Op::OpTf("/F1", 9.0)]
  let page : @pdfpage.Page = {
    content: [@pdfops.stream_of_ops(ops)],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  let page_num = match @pdfpage.page_object_number(pdf, 1) {
    Some(n) => n
    None => fail("expected page object number")
  }
  let page_obj = @pdf.lookup_obj(pdf, page_num)
  let first_content = match @pdf.lookup_direct(pdf, "/Contents", page_obj) {
    Some(@pdf.PdfObject::Array(contents)) => contents[0]
    _ => fail("expected contents array")
  }
  let updated = @pdf.add_dict_entry(page_obj, "/Contents", first_content)
  @pdf.addobj_given_num(pdf, (page_num, updated))
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let ops_out = @pdfops.parse_operators(
    pdf,
    pages[0].resources,
    pages[0].content,
  )
  match ops_out[0] {
    @pdfops.Op::OpTf(name, _) => assert_eq(name, "/pF1")
    _ => fail("expected prefixed font op")
  }
}

///|
test "add_prefix keeps direct inline colorspace names" {
  let pdf0 = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    ("/CS", @pdf.PdfObject::Name("/DeviceRGB")),
  ])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_string("RGB"))),
  ]
  let page : @pdfpage.Page = {
    content: [@pdfops.stream_of_ops(ops)],
    mediabox: prefix_sample_rect(),
    resources: @pdf.PdfObject::Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let ops_out = @pdfops.parse_operators(
    pdf,
    pages[0].resources,
    pages[0].content,
  )
  let mut saw = false
  for op in ops_out {
    match op {
      @pdfops.Op::InlineImage((inline_dict, _, _)) =>
        match @pdf.lookup_direct(pdf, "/CS", inline_dict) {
          Some(@pdf.PdfObject::Name(name)) => {
            assert_eq(name, "/DeviceRGB")
            saw = true
          }
          _ => fail("expected inline colorspace")
        }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "add_prefix preserves inline colorspace arrays" {
  let pdf0 = @pdf.empty()
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
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x12]))),
  ]
  let page : @pdfpage.Page = {
    content: [@pdfops.stream_of_ops(ops)],
    mediabox: prefix_sample_rect(),
    resources: @pdf.PdfObject::Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let ops_out = @pdfops.parse_operators(
    pdf,
    pages[0].resources,
    pages[0].content,
  )
  let mut saw = false
  for op in ops_out {
    match op {
      @pdfops.Op::InlineImage((inline_dict, _, _)) =>
        match @pdf.lookup_direct(pdf, "/CS", inline_dict) {
          Some(@pdf.PdfObject::Array(_)) => saw = true
          _ => fail("expected inline colorspace array")
        }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "add_prefix merges non-iso content streams" {
  let dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    ("/CS", @pdf.PdfObject::Name("/DeviceRGB")),
  ])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_string("RGB"))),
  ])
  let bytes = @pdfio.bytes_of_string(rendered)
  let mid = @pdfio.bytes_size(bytes) / 2
  let first = bytes[:mid].to_array()
  let second = bytes[mid:].to_array()
  let stream1 = @pdf.PdfObject::Stream(
    Ref::new(
      (
        @pdf.PdfObject::Dictionary([
          ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(first))),
        ]),
        @pdf.Stream::Got(first),
      ),
    ),
  )
  let stream2 = @pdf.PdfObject::Stream(
    Ref::new(
      (
        @pdf.PdfObject::Dictionary([
          ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(second))),
        ]),
        @pdf.Stream::Got(second),
      ),
    ),
  )
  let page : @pdfpage.Page = {
    content: [stream1, stream2],
    mediabox: prefix_sample_rect(),
    resources: @pdf.PdfObject::Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], @pdf.empty())
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  assert_eq(pages[0].content.length(), 1)
}
