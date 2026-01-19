///|
fn mk_point(x : Double, y : Double, z : Double) -> @pdf.PdfObject {
  @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(x),
    @pdf.PdfObject::Real(y),
    @pdf.PdfObject::Real(z),
  ])
}

///|
fn stream_of_bytes(values : Array[Int]) -> @pdf.PdfObject {
  let dict = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_list(values)
  @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
}

///|
fn icc_stream_with_n(n : Int) -> @pdf.PdfObject {
  let dict = @pdf.PdfObject::Dictionary([("/N", @pdf.PdfObject::Integer(n))])
  let data = @pdfio.bytes_of_list([0, 1, 2, 3])
  @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
}

///|
test "read_colourspace resolves named entry from resources" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    (
      "/ColorSpace",
      @pdf.PdfObject::Dictionary([("/CS1", @pdf.PdfObject::Name("/DeviceCMYK"))]),
    ),
  ])
  let space = read_colourspace(pdf, resources, @pdf.PdfObject::Name("/CS1"))
  match space {
    ColourSpace::DeviceCMYK => ()
    _ => fail("expected DeviceCMYK")
  }
}

///|
test "read_colourspace uses default gamma for CalGray" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/WhitePoint", mk_point(1.0, 1.0, 1.0)),
    ("/BlackPoint", mk_point(0.0, 0.0, 0.0)),
  ])
  let space = read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/CalGray"), dict]),
  )
  match space {
    ColourSpace::CalGray(_, _, gamma) => assert_eq(gamma, 1.0)
    _ => fail("expected CalGray")
  }
}

///|
test "read_colourspace uses default gamma and matrix for CalRGB" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/WhitePoint", mk_point(1.0, 1.0, 1.0)),
    ("/BlackPoint", mk_point(0.0, 0.0, 0.0)),
  ])
  let space = read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/CalRGB"), dict]),
  )
  match space {
    ColourSpace::CalRGB(_, _, gamma, matrix) => {
      assert_eq(gamma, [1.0, 1.0, 1.0])
      assert_eq(matrix, [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0])
    }
    _ => fail("expected CalRGB")
  }
}

///|
test "read_colourspace uses default range for Lab" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/WhitePoint", mk_point(1.0, 1.0, 1.0)),
    ("/BlackPoint", mk_point(0.0, 0.0, 0.0)),
  ])
  let space = read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/Lab"), dict]),
  )
  match space {
    ColourSpace::Lab(_, _, range) =>
      assert_eq(range, [-100.0, 100.0, -100.0, 100.0])
    _ => fail("expected Lab")
  }
}

///|
test "read_colourspace Indexed parses lookup stream" {
  let pdf = @pdf.empty()
  let stream_obj = stream_of_bytes([1, 2, 3, 4, 5, 6])
  let space = read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Name("/DeviceRGB"),
      @pdf.PdfObject::Integer(1),
      stream_obj,
    ]),
  )
  match space {
    ColourSpace::Indexed(ColourSpace::DeviceRGB, table) => {
      match table.get(0) {
        Some(values) => assert_eq(values, [1, 2, 3])
        None => fail("missing table entry 0")
      }
      match table.get(1) {
        Some(values) => assert_eq(values, [4, 5, 6])
        None => fail("missing table entry 1")
      }
    }
    _ => fail("expected Indexed DeviceRGB")
  }
}

///|
test "read_colourspace Indexed handles DeviceN base" {
  let pdf = @pdf.empty()
  let tint = @pdffun.pdfobject_of_function(pdf, sample_tint_function())
  let table = @pdfio.string_of_int_array([0, 0, 0])
  let space = read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/DeviceN"),
        @pdf.PdfObject::Array([@pdf.PdfObject::Name("/C1")]),
        @pdf.PdfObject::Name("/DeviceRGB"),
        tint,
      ]),
      @pdf.PdfObject::Integer(0),
      @pdf.PdfObject::String(table),
    ]),
  )
  match space {
    ColourSpace::Indexed(ColourSpace::DeviceN(_, _, _, _), table_map) =>
      match table_map.get(0) {
        Some(values) => assert_eq(values, [0, 0, 0])
        None => fail("expected table entry")
      }
    _ => fail("expected Indexed DeviceN")
  }
}

///|
test "read_colourspace Indexed handles DeviceCMYK base" {
  let pdf = @pdf.empty()
  let stream_obj = stream_of_bytes([1, 2, 3, 4])
  let space = read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Name("/DeviceCMYK"),
      @pdf.PdfObject::Integer(0),
      stream_obj,
    ]),
  )
  match space {
    ColourSpace::Indexed(ColourSpace::DeviceCMYK, table) =>
      match table.get(0) {
        Some(values) => assert_eq(values.length(), 4)
        None => fail("expected table entry")
      }
    _ => fail("expected Indexed DeviceCMYK")
  }
}

///|
test "read_colourspace Indexed errors on invalid inputs" {
  let pdf = @pdf.empty()
  let stream_obj = stream_of_bytes([0, 0, 0])
  let bad_hival : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Name("/DeviceRGB"),
      @pdf.PdfObject::Name("/Bad"),
      @pdf.PdfObject::String(@pdfio.string_of_int_array([0, 0, 0])),
    ]),
  )
  assert_true(bad_hival is Err(_))
  let bad_base_stream : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Name("/Pattern"),
      @pdf.PdfObject::Integer(0),
      stream_obj,
    ]),
  )
  assert_true(bad_base_stream is Err(_))
  let bad_base_string : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Name("/DeviceGray"),
      @pdf.PdfObject::Integer(0),
      @pdf.PdfObject::String(@pdfio.string_of_int_array([0])),
    ]),
  )
  assert_true(bad_base_string is Err(_))
  let bad_lookup : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Name("/DeviceRGB"),
      @pdf.PdfObject::Integer(0),
      @pdf.PdfObject::Integer(5),
    ]),
  )
  assert_true(bad_lookup is Err(_))
  let toget = @pdf.toget(@pdfio.input_of_string("abc"), 0, 3)
  let bad_stream = @pdf.PdfObject::Stream(
    Ref::new((@pdf.PdfObject::Dictionary([]), @pdf.Stream::ToGet(toget))),
  )
  let bad_toget : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Name("/DeviceRGB"),
      @pdf.PdfObject::Integer(0),
      bad_stream,
    ]),
  )
  assert_true(bad_toget is Err(_))
}

///|
test "read_colourspace ICCBased invalid N errors" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([("/N", @pdf.PdfObject::Integer(2))])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream_obj = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got(data))),
  )
  let res : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/ICCBased"), stream_obj]),
  )
  match res {
    Err(_) => ()
    _ => fail("expected ICCBased /N error")
  }
}

///|
test "read_colourspace ICCBased defaults alternate by N" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let cs1 = read_colourspace(
    pdf,
    resources,
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/ICCBased"),
      icc_stream_with_n(1),
    ]),
  )
  let cs3 = read_colourspace(
    pdf,
    resources,
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/ICCBased"),
      icc_stream_with_n(3),
    ]),
  )
  let cs4 = read_colourspace(
    pdf,
    resources,
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/ICCBased"),
      icc_stream_with_n(4),
    ]),
  )
  match cs1 {
    ColourSpace::ICCBased(icc) =>
      match icc.icc_alternate {
        ColourSpace::DeviceGray => ()
        _ => fail("expected DeviceGray alternate")
      }
    _ => fail("expected ICCBased")
  }
  match cs3 {
    ColourSpace::ICCBased(icc) =>
      match icc.icc_alternate {
        ColourSpace::DeviceRGB => ()
        _ => fail("expected DeviceRGB alternate")
      }
    _ => fail("expected ICCBased")
  }
  match cs4 {
    ColourSpace::ICCBased(icc) =>
      match icc.icc_alternate {
        ColourSpace::DeviceCMYK => ()
        _ => fail("expected DeviceCMYK alternate")
      }
    _ => fail("expected ICCBased")
  }
}

///|
test "write_colourspace Indexed unsupported base returns null" {
  let pdf = @pdf.empty()
  let table : Map[Int, Array[Int]] = Map::new()
  table.set(0, [0, 0, 0])
  let space = ColourSpace::Indexed(ColourSpace::Pattern, table)
  let obj = write_colourspace(pdf, space)
  match obj {
    @pdf.PdfObject::Null => ()
    _ => fail("expected null for unsupported base")
  }
}

///|
test "write_colourspace ICCBased missing stream falls back" {
  let pdf = @pdf.empty()
  let icc = ICCBased::{
    icc_n: 3,
    icc_alternate: ColourSpace::DeviceRGB,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: None,
    icc_stream: @pdf.PdfObject::Null,
  }
  let obj = write_colourspace(pdf, ColourSpace::ICCBased(icc))
  match obj {
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/ICCBased"), alt]) =>
      match alt {
        @pdf.PdfObject::Name("/DeviceRGB") => ()
        _ => fail("expected alternate colourspace")
      }
    _ => fail("expected ICCBased array")
  }
}

///|
test "write_colourspace DeviceN omits empty attributes" {
  let pdf = @pdf.empty()
  let tint = sample_tint_function()
  let space = ColourSpace::DeviceN(
    ["C1"],
    ColourSpace::DeviceRGB,
    tint,
    @pdf.PdfObject::Dictionary([]),
  )
  let obj = write_colourspace(pdf, space)
  match obj {
    @pdf.PdfObject::Array(items) => assert_eq(items.length(), 4)
    _ => fail("expected DeviceN array")
  }
}

///|
test "write_colourspace DeviceN includes non-dict attributes" {
  let pdf = @pdf.empty()
  let tint = sample_tint_function()
  let space = ColourSpace::DeviceN(
    ["/Spot"],
    ColourSpace::DeviceRGB,
    tint,
    @pdf.PdfObject::Name("/Attrs"),
  )
  let obj = write_colourspace(pdf, space)
  match obj {
    @pdf.PdfObject::Array(items) => assert_eq(items.length(), 5)
    _ => fail("expected DeviceN array with attrs")
  }
}

///|
test "write_colourspace Indexed handles DeviceGray and DeviceCMYK" {
  let pdf = @pdf.empty()
  let table_gray : Map[Int, Array[Int]] = Map::new()
  table_gray.set(0, [0])
  let gray = write_colourspace(
    pdf,
    ColourSpace::Indexed(ColourSpace::DeviceGray, table_gray),
  )
  match gray {
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/Indexed"), _, _, _]) => ()
    _ => fail("expected indexed DeviceGray")
  }
  let table_cmyk : Map[Int, Array[Int]] = Map::new()
  table_cmyk.set(0, [0, 0, 0, 0])
  let cmyk = write_colourspace(
    pdf,
    ColourSpace::Indexed(ColourSpace::DeviceCMYK, table_cmyk),
  )
  match cmyk {
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/Indexed"), _, _, _]) => ()
    _ => fail("expected indexed DeviceCMYK")
  }
}

///|
test "write_colourspace returns pattern name" {
  let pdf = @pdf.empty()
  let obj = write_colourspace(pdf, ColourSpace::Pattern)
  match obj {
    @pdf.PdfObject::Name("/Pattern") => ()
    _ => fail("expected /Pattern name")
  }
}

///|
test "write_colourspace ICCBased preserves length and skips bad range" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/N", @pdf.PdfObject::Integer(1)),
    ("/Length", @pdf.PdfObject::Integer(3)),
  ])
  let stream_obj = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string("icc")))),
  )
  let icc = ICCBased::{
    icc_n: 3,
    icc_alternate: ColourSpace::DeviceRGB,
    icc_range: [0.0],
    icc_metadata: None,
    icc_stream: stream_obj,
  }
  let obj = write_colourspace(pdf, ColourSpace::ICCBased(icc))
  match obj {
    @pdf.PdfObject::Array(
      [@pdf.PdfObject::Name("/ICCBased"), @pdf.PdfObject::Indirect(n)]
    ) =>
      match @pdf.lookup_obj(pdf, n) {
        @pdf.PdfObject::Stream(r) => {
          let (dict_obj, _) = r.val
          assert_true(@pdf.lookup_direct(pdf, "/Length", dict_obj) is Some(_))
          assert_true(@pdf.lookup_direct(pdf, "/Range", dict_obj) is None)
        }
        _ => fail("expected ICCBased stream")
      }
    _ => fail("expected ICCBased array")
  }
}

///|
test "write_colourspace ICCBased handles non-dict stream data" {
  let pdf = @pdf.empty()
  let toget = @pdf.toget(@pdfio.input_of_string("data"), 0, 4)
  let stream_obj = @pdf.PdfObject::Stream(
    Ref::new((@pdf.PdfObject::Name("/Bad"), @pdf.Stream::ToGet(toget))),
  )
  let icc = ICCBased::{
    icc_n: 3,
    icc_alternate: ColourSpace::DeviceRGB,
    icc_range: [],
    icc_metadata: None,
    icc_stream: stream_obj,
  }
  let obj = write_colourspace(pdf, ColourSpace::ICCBased(icc))
  match obj {
    @pdf.PdfObject::Array(
      [@pdf.PdfObject::Name("/ICCBased"), @pdf.PdfObject::Indirect(_)]
    ) => ()
    _ => fail("expected ICCBased array")
  }
}

///|
test "string_of_colourspace covers variants" {
  let icc = ICCBased::{
    icc_n: 3,
    icc_alternate: ColourSpace::DeviceRGB,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: None,
    icc_stream: @pdf.PdfObject::Null,
  }
  assert_eq(string_of_colourspace(ColourSpace::DeviceGray), "/DeviceGray")
  assert_eq(string_of_colourspace(ColourSpace::DeviceCMYK), "/DeviceCMYK")
  assert_eq(
    string_of_colourspace(ColourSpace::ICCBased(icc)),
    "ICCBased (/DeviceRGB)",
  )
  assert_eq(
    string_of_colourspace(
      ColourSpace::PatternWithBaseColourspace(ColourSpace::DeviceRGB),
    ),
    "PatternWithBaseColourspace (/DeviceRGB)",
  )
  assert_eq(
    string_of_colourspace(
      ColourSpace::Separation(
        "Spot",
        ColourSpace::DeviceRGB,
        sample_tint_function(),
      ),
    ),
    "Separation (/DeviceRGB)",
  )
  let table : Map[Int, Array[Int]] = Map::new()
  table.set(0, [0, 0, 0])
  assert_eq(
    string_of_colourspace(ColourSpace::Indexed(ColourSpace::DeviceRGB, table)),
    "Indexed (/DeviceRGB)",
  )
  assert_eq(string_of_colourspace(ColourSpace::Pattern), "/Pattern")
  assert_eq(
    string_of_colourspace(
      ColourSpace::DeviceN(
        ["C1"],
        ColourSpace::DeviceRGB,
        sample_tint_function(),
        @pdf.PdfObject::Dictionary([]),
      ),
    ),
    "DeviceN (/DeviceRGB)",
  )
}

///|
test "name_of_colourspace returns none for non-separation" {
  let name = name_of_colourspace(ColourSpace::DeviceRGB)
  match name {
    None => ()
    _ => fail("expected none")
  }
}

///|
test "string_of_colourspace covers cal and lab variants" {
  let white = (1.0, 1.0, 1.0)
  let black = (0.0, 0.0, 0.0)
  assert_eq(
    string_of_colourspace(ColourSpace::CalGray(white, black, 1.0)),
    "/CalGray",
  )
  assert_eq(
    string_of_colourspace(
      ColourSpace::CalRGB(white, black, [1.0, 1.0, 1.0], [
        1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
      ]),
    ),
    "/CalRGB",
  )
  assert_eq(
    string_of_colourspace(
      ColourSpace::Lab(white, black, [-100.0, 100.0, -100.0, 100.0]),
    ),
    "/Lab",
  )
}

///|
test "read_colourspace handles indirect and singleton array" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let objnum = @pdf.addobj(pdf, @pdf.PdfObject::Name("/DeviceGray"))
  let indirect = read_colourspace(
    pdf,
    resources,
    @pdf.PdfObject::Indirect(objnum),
  )
  match indirect {
    ColourSpace::DeviceGray => ()
    _ => fail("expected DeviceGray")
  }
  let singleton = read_colourspace(
    pdf,
    resources,
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/DeviceRGB")]),
  )
  match singleton {
    ColourSpace::DeviceRGB => ()
    _ => fail("expected DeviceRGB")
  }
}

///|
test "read_colourspace errors on missing named entry" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    ("/ColorSpace", @pdf.PdfObject::Dictionary([])),
  ])
  let res : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    resources,
    @pdf.PdfObject::Name("/Missing"),
  )
  assert_true(res is Err(_))
}

///|
test "read_colourspace errors when resources lack ColorSpace" {
  let pdf = @pdf.empty()
  let res : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Name("/Missing"),
  )
  assert_true(res is Err(_))
}

///|
test "read_colourspace ICCBased errors on missing N and non-stream" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_string("icc")
  let stream_obj = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got(data))),
  )
  let missing_n : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/ICCBased"), stream_obj]),
  )
  assert_true(missing_n is Err(_))
  let non_stream : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/ICCBased"),
      @pdf.PdfObject::Integer(1),
    ]),
  )
  assert_true(non_stream is Err(_))
}

///|
test "read_colourspace errors on unsupported object" {
  let pdf = @pdf.empty()
  let res : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Integer(5),
  )
  assert_true(res is Err(_))
}

///|
test "read_colourspace rejects indexed base colourspaces" {
  let pdf = @pdf.empty()
  let res : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Name("/Pattern"),
      @pdf.PdfObject::Integer(0),
      @pdf.PdfObject::String(""),
    ]),
  )
  assert_true(res is Err(_))
}

///|
test "read_colourspace DeviceN attributes and name validation" {
  let pdf = @pdf.empty()
  let tint = @pdffun.pdfobject_of_function(pdf, sample_tint_function())
  let attrs = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/DeviceN")),
  ])
  let space = read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/DeviceN"),
      @pdf.PdfObject::Array([@pdf.PdfObject::Name("/Cyan")]),
      @pdf.PdfObject::Name("/DeviceRGB"),
      tint,
      attrs,
    ]),
  )
  match space {
    ColourSpace::DeviceN(names, _, _, attr_dict) => {
      assert_eq(names.length(), 1)
      assert_eq(names[0], "/Cyan")
      match @pdf.lookup_direct(pdf, "/Subtype", attr_dict) {
        Some(@pdf.PdfObject::Name("/DeviceN")) => ()
        _ => fail("expected DeviceN subtype")
      }
    }
    _ => fail("expected DeviceN")
  }
  let bad_names : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/DeviceN"),
      @pdf.PdfObject::Array([@pdf.PdfObject::Integer(1)]),
      @pdf.PdfObject::Name("/DeviceRGB"),
      tint,
    ]),
  )
  assert_true(bad_names is Err(_))
}

///|
test "write_colourspace writes ICCBased metadata and range" {
  let pdf = @pdf.empty()
  let metadata = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Metadata")),
  ])
  let stream_obj = @pdf.PdfObject::Stream(
    Ref::new(
      (
        @pdf.PdfObject::Dictionary([]),
        @pdf.Stream::Got(@pdfio.bytes_of_string("icc")),
      ),
    ),
  )
  let icc = ICCBased::{
    icc_n: 3,
    icc_alternate: ColourSpace::DeviceRGB,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: Some(metadata),
    icc_stream: stream_obj,
  }
  let obj = write_colourspace(pdf, ColourSpace::ICCBased(icc))
  match obj {
    @pdf.PdfObject::Array(
      [@pdf.PdfObject::Name("/ICCBased"), @pdf.PdfObject::Indirect(n)]
    ) =>
      match @pdf.lookup_obj(pdf, n) {
        @pdf.PdfObject::Stream(r) => {
          let (dict, _) = r.val
          assert_true(@pdf.lookup_direct(pdf, "/Metadata", dict) is Some(_))
          match @pdf.lookup_direct(pdf, "/Range", dict) {
            Some(@pdf.PdfObject::Array(values)) => assert_eq(values.length(), 6)
            _ => fail("expected /Range entry")
          }
        }
        _ => fail("expected ICCBased stream")
      }
    _ => fail("expected ICCBased array")
  }
}

///|
test "write_colourspace handles indexed empty table and deviceN attrs" {
  let pdf = @pdf.empty()
  let empty_table : Map[Int, Array[Int]] = Map::new()
  let indexed = write_colourspace(
    pdf,
    ColourSpace::Indexed(ColourSpace::DeviceRGB, empty_table),
  )
  match indexed {
    @pdf.PdfObject::Array(items) =>
      match items[2] {
        @pdf.PdfObject::Integer(0) => ()
        _ => fail("expected hival 0")
      }
    _ => fail("expected Indexed array")
  }
  let attrs = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/DeviceN")),
  ])
  let device_n = write_colourspace(
    pdf,
    ColourSpace::DeviceN(
      ["C1"],
      ColourSpace::DeviceRGB,
      sample_tint_function(),
      attrs,
    ),
  )
  match device_n {
    @pdf.PdfObject::Array(items) => assert_eq(items.length(), 5)
    _ => fail("expected DeviceN array with attrs")
  }
}

///|
test "write_colourspace handles Pattern with base" {
  let pdf = @pdf.empty()
  let obj = write_colourspace(
    pdf,
    ColourSpace::PatternWithBaseColourspace(ColourSpace::DeviceGray),
  )
  match obj {
    @pdf.PdfObject::Array(
      [@pdf.PdfObject::Name("/Pattern"), @pdf.PdfObject::Name("/DeviceGray")]
    ) => ()
    _ => fail("expected Pattern with base")
  }
}

///|
test "read_colourspace missing whitepoint defaults to zeros" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/BlackPoint", mk_point(0.0, 0.0, 0.0)),
  ])
  let space = read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/CalGray"), dict]),
  )
  match space {
    ColourSpace::CalGray(white, _, _) => assert_eq(white, (0.0, 0.0, 0.0))
    _ => fail("expected CalGray")
  }
}

///|
test "read_colourspace indexed handles ICCBased base" {
  let pdf = @pdf.empty()
  let icc_dict = @pdf.PdfObject::Dictionary([("/N", @pdf.PdfObject::Integer(3))])
  let icc_stream = @pdf.PdfObject::Stream(
    Ref::new((icc_dict, @pdf.Stream::Got(@pdfio.bytes_of_list([0])))),
  )
  let base = @pdf.PdfObject::Array([
    @pdf.PdfObject::Name("/ICCBased"),
    icc_stream,
  ])
  let lookup = @pdf.PdfObject::String(
    @pdfio.string_of_bytes(@pdfio.bytes_of_list([1, 2, 3])),
  )
  let space = read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      base,
      @pdf.PdfObject::Integer(0),
      lookup,
    ]),
  )
  match space {
    ColourSpace::Indexed(ColourSpace::ICCBased(_), table) =>
      match table.get(0) {
        Some(values) => assert_eq(values, [1, 2, 3])
        _ => fail("expected indexed table entry")
      }
    _ => fail("expected indexed ICCBased")
  }
}

///|
test "read_colourspace indexed rejects short table" {
  let pdf = @pdf.empty()
  let lookup = @pdf.PdfObject::String(
    @pdfio.string_of_bytes(@pdfio.bytes_of_list([1, 2, 3])),
  )
  let res : Result[ColourSpace, Error] = try? read_colourspace(
    pdf,
    @pdf.PdfObject::Dictionary([]),
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/Indexed"),
      @pdf.PdfObject::Name("/DeviceRGB"),
      @pdf.PdfObject::Integer(1),
      lookup,
    ]),
  )
  match res {
    Err(_) => ()
    _ => fail("expected short table error")
  }
}
