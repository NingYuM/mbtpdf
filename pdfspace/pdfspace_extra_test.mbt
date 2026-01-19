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
