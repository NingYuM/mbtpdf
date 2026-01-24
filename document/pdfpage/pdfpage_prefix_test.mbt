///|
fn prefix_sample_rect() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)])
}

///|
fn prefix_resources() -> @pdf.PdfObject {
  Dictionary([
    ("/Font", Dictionary([("/F1", Null)])),
    ("/ExtGState", Dictionary([("/GS1", Null)])),
    ("/ColorSpace", Dictionary([("/Cs1", Name("/DeviceRGB"))])),
    ("/Pattern", Dictionary([("/P1", Null)])),
    ("/Shading", Dictionary([("/S1", Null)])),
    ("/XObject", Dictionary([("/X1", Null)])),
    ("/Properties", Dictionary([("/Prop1", Null)])),
  ])
}

///|
test "shortest_unused_prefix handles dense prefixes" {
  let pdf0 = @pdf.Pdf::empty()
  let font_entries : Array[(String, @pdf.PdfObject)] = []
  for code in 'a'.to_int()..<='z'.to_int() {
    match code.to_char() {
      Some(ch) => font_entries.push(("/\{ch}0", Null))
      None => fail("expected ASCII char")
    }
  }
  font_entries.push(("/az0", Null))
  font_entries.push(("", Null))
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary(font_entries)),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  ignore(@pdf.addobj(pdf, Integer(1)))
  assert_eq(@pdfpage.shortest_unused_prefix(pdf), "bz")
}

///|
test "add_prefix rewrites resources and operators" {
  let pdf0 = @pdf.Pdf::empty()
  let resources = prefix_resources()
  let ops_primary : Array[@pdfops.Op] = [
    OpTf("/F1", 12.0),
    Opgs("/GS1"),
    OpCS("/DeviceRGB"),
    OpCS("/Cs1"),
    Opcs("/DeviceRGB"),
    Opcs("/Cs1"),
    OpSCNName("/P1", [0.1]),
    OpscnName("/P1", [0.2]),
    Opsh("/S1"),
    OpDo("/X1"),
    OpDP("/Tag", Name("/Prop1")),
    OpBDC("/Tag", Name("/Prop1")),
  ]
  let ops_secondary : Array[@pdfops.Op] = [Opq, OpQ]
  let page : @pdfpage.Page = {
    content: [
      @pdfops.Op::stream_of_ops(ops_primary),
      @pdfops.Op::stream_of_ops(ops_secondary),
    ],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let page0 = pages[0]
  match @pdf.lookup_direct(pdf, "/Font", page0.resources) {
    Some(Dictionary(entries)) =>
      assert_true(entries.any(pair => pair.0 == "/pF1"))
    _ => fail("expected prefixed font resources")
  }
  match @pdf.lookup_direct(pdf, "/ColorSpace", page0.resources) {
    Some(Dictionary(entries)) =>
      assert_true(entries.any(pair => pair.0 == "/pCs1"))
    _ => fail("expected prefixed colorspace resources")
  }
  let ops = @pdfops.Op::parse_operators(pdf, page0.resources, page0.content)
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
    match (op : @pdfops.Op) {
      OpTf(name, _) => {
        assert_eq(name, "/pF1")
        saw_tf = true
      }
      Opgs(name) => {
        assert_eq(name, "/pGS1")
        saw_gs = true
      }
      OpCS(name) =>
        if name == "/DeviceRGB" {
          saw_cs_direct = true
        } else if name == "/pCs1" {
          saw_cs_prefixed = true
        } else {
          fail("unexpected OpCS")
        }
      Opcs(name) =>
        if name == "/DeviceRGB" {
          saw_scs_direct = true
        } else if name == "/pCs1" {
          saw_scs_prefixed = true
        } else {
          fail("unexpected Opcs")
        }
      OpSCNName(name, _) => {
        assert_eq(name, "/pP1")
        saw_scn = true
      }
      OpscnName(name, _) => {
        assert_eq(name, "/pP1")
        saw_scn_lower = true
      }
      Opsh(name) => {
        assert_eq(name, "/pS1")
        saw_sh = true
      }
      OpDo(name) => {
        assert_eq(name, "/pX1")
        saw_do = true
      }
      OpDP(_, Name(name)) => {
        assert_eq(name, "/pProp1")
        saw_dp = true
      }
      OpBDC(_, Name(name)) => {
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
  let pdf0 = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/ColorSpace", Dictionary([("/CS1", Name("/DeviceRGB"))])),
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name("/CS1")),
  ])
  let ops : Array[@pdfops.Op] = [
    InlineImage((dict, None, @pdfio.bytes_of_string("RGB"))),
  ]
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let ops_out = @pdfops.Op::parse_operators(
    pdf,
    pages[0].resources,
    pages[0].content,
  )
  let mut saw = false
  for op in ops_out {
    match (op : @pdfops.Op) {
      InlineImage((inline_dict, _, _)) =>
        match @pdf.lookup_direct(pdf, "/CS", inline_dict) {
          Some(Name(name)) => {
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
  let pdf0 = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/ColorSpace", Dictionary([("/CS1", Name("/DeviceRGB"))])),
  ])
  let raw = @pdfio.bytes_of_list([0x11, 0x22, 0x33])
  let encoded = @pdfcodec.encode_flate(raw)
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name("/CS1")),
    ("/Filter", Name("/FlateDecode")),
  ])
  let ops : Array[@pdfops.Op] = [InlineImage((dict, None, encoded)), Opq, OpQ]
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let ops_out = @pdfops.Op::parse_operators(
    pdf,
    pages[0].resources,
    pages[0].content,
  )
  let mut saw_inline = false
  let mut saw_q = false
  for op in ops_out {
    match (op : @pdfops.Op) {
      InlineImage((inline_dict, _, _)) =>
        match @pdf.lookup_direct(pdf, "/CS", inline_dict) {
          Some(Name(name)) => {
            assert_eq(name, "/pCS1")
            saw_inline = true
          }
          _ => fail("expected prefixed inline colorspace")
        }
      Opq | OpQ => saw_q = true
      _ => ()
    }
  }
  assert_true(saw_inline && saw_q)
}

///|
test "add_prefix rejects blank resource names" {
  let pdf0 = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("", Null)])),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  let result : Result[Unit, Error] = try? @pdfpage.add_prefix(pdf, "p")
  assert_true(result is Err(_))
}

///|
test "add_prefix handles single indirect contents" {
  let pdf0 = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F1", Null)])),
  ])
  let ops : Array[@pdfops.Op] = [OpTf("/F1", 9.0)]
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: prefix_sample_rect(),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  let page_num = match @pdfpage.page_object_number(pdf, 1) {
    Some(n) => n
    None => fail("expected page object number")
  }
  let page_obj = @pdf.lookup_obj(pdf, page_num)
  let first_content = match @pdf.lookup_direct(pdf, "/Contents", page_obj) {
    Some(Array(contents)) => contents[0]
    _ => fail("expected contents array")
  }
  let updated = @pdf.add_dict_entry(page_obj, "/Contents", first_content)
  @pdf.addobj_given_num(pdf, (page_num, updated))
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let ops_out = @pdfops.Op::parse_operators(
    pdf,
    pages[0].resources,
    pages[0].content,
  )
  match (ops_out[0] : @pdfops.Op) {
    OpTf(name, _) => assert_eq(name, "/pF1")
    _ => fail("expected prefixed font op")
  }
}

///|
test "add_prefix keeps direct inline colorspace names" {
  let pdf0 = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name("/DeviceRGB")),
  ])
  let ops : Array[@pdfops.Op] = [
    InlineImage((dict, None, @pdfio.bytes_of_string("RGB"))),
  ]
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: prefix_sample_rect(),
    resources: Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let ops_out = @pdfops.Op::parse_operators(
    pdf,
    pages[0].resources,
    pages[0].content,
  )
  let mut saw = false
  for op in ops_out {
    match (op : @pdfops.Op) {
      InlineImage((inline_dict, _, _)) =>
        match @pdf.lookup_direct(pdf, "/CS", inline_dict) {
          Some(Name(name)) => {
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
  let pdf0 = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    (
      "/CS",
      Array([Name("/Indexed"), Name("/DeviceRGB"), Integer(1), String("")]),
    ),
  ])
  let ops : Array[@pdfops.Op] = [
    InlineImage((dict, None, @pdfio.bytes_of_list([0x12]))),
  ]
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: prefix_sample_rect(),
    resources: Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let ops_out = @pdfops.Op::parse_operators(
    pdf,
    pages[0].resources,
    pages[0].content,
  )
  let mut saw = false
  for op in ops_out {
    match (op : @pdfops.Op) {
      InlineImage((inline_dict, _, _)) =>
        match @pdf.lookup_direct(pdf, "/CS", inline_dict) {
          Some(Array(_)) => saw = true
          _ => fail("expected inline colorspace array")
        }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "add_prefix merges non-iso content streams" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name("/DeviceRGB")),
  ])
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_string("RGB"))),
  ])
  let bytes = @pdfio.bytes_of_string(rendered)
  let mid = @pdfio.bytes_size(bytes) / 2
  let first = bytes[:mid].to_array()
  let second = bytes[mid:].to_array()
  let stream1 : @pdf.PdfObject = Stream(
    Ref::new(
      (
        Dictionary([("/Length", Integer(@pdfio.bytes_size(first)))]),
        @pdf.Stream::Got(first),
      ),
    ),
  )
  let stream2 : @pdf.PdfObject = Stream(
    Ref::new(
      (
        Dictionary([("/Length", Integer(@pdfio.bytes_size(second)))]),
        @pdf.Stream::Got(second),
      ),
    ),
  )
  let page : @pdfpage.Page = {
    content: [stream1, stream2],
    mediabox: prefix_sample_rect(),
    resources: Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], @pdf.Pdf::empty())
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  assert_eq(pages[0].content.length(), 1)
}
