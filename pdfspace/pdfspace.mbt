///|
/// Tristimulus point.
pub type Point = (Double, Double, Double)

///|
/// ICC based colourspace details.
pub(all) struct ICCBased {
  icc_n : Int
  icc_alternate : ColourSpace
  icc_range : Array[Double]
  icc_metadata : @pdf.PdfObject?
  icc_stream : @pdf.PdfObject
}

///|
/// Colour space variants.
pub(all) enum ColourSpace {
  DeviceGray
  DeviceRGB
  DeviceCMYK
  CalGray(Point, Point, Double)
  CalRGB(Point, Point, Array[Double], Array[Double])
  Lab(Point, Point, Array[Double])
  ICCBased(ICCBased)
  Indexed(ColourSpace, Map[Int, Array[Int]])
  Pattern
  PatternWithBaseColourspace(ColourSpace)
  Separation(String, ColourSpace, @pdffun.PdfFunction)
  DeviceN(Array[String], ColourSpace, @pdffun.PdfFunction, @pdf.PdfObject)
}

///|
/// Produce a debug string.
pub fn string_of_colourspace(space : ColourSpace) -> String {
  match space {
    ColourSpace::DeviceGray => "/DeviceGray"
    ColourSpace::DeviceRGB => "/DeviceRGB"
    ColourSpace::DeviceCMYK => "/DeviceCMYK"
    ColourSpace::CalGray(_, _, _) => "/CalGray"
    ColourSpace::CalRGB(_, _, _, _) => "/CalRGB"
    ColourSpace::Lab(_, _, _) => "/Lab"
    ColourSpace::ICCBased(icc) =>
      "ICCBased (\{string_of_colourspace(icc.icc_alternate)})"
    ColourSpace::Indexed(base, _) => "Indexed (\{string_of_colourspace(base)})"
    ColourSpace::Pattern => "/Pattern"
    ColourSpace::PatternWithBaseColourspace(base) =>
      "PatternWithBaseColourspace (\{string_of_colourspace(base)})"
    ColourSpace::Separation(_, base, _) =>
      "Separation (\{string_of_colourspace(base)})"
    ColourSpace::DeviceN(_, base, _, _) =>
      "DeviceN (\{string_of_colourspace(base)})"
  }
}

///|
/// Read the name of a colour, if it has one.
pub fn name_of_colourspace(space : ColourSpace) -> String? {
  match space {
    ColourSpace::Separation(name, _, _) => Some(name)
    _ => None
  }
}

///|
fn read_point(
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
  key : String,
) -> Point raise {
  match @pdf.lookup_direct(pdf, key, dict) {
    Some(@pdf.PdfObject::Array([a, b, c])) =>
      (@pdf.getnum(pdf, a), @pdf.getnum(pdf, b), @pdf.getnum(pdf, c))
    _ => (0.0, 0.0, 0.0)
  }
}

///|
fn get_basic_table_colourspace(space : ColourSpace) -> ColourSpace {
  match space {
    ColourSpace::Indexed(base, _) => get_basic_table_colourspace(base)
    ColourSpace::DeviceN(_, base, _, _) => get_basic_table_colourspace(base)
    ColourSpace::Separation(_, base, _) => get_basic_table_colourspace(base)
    ColourSpace::ICCBased(icc) => get_basic_table_colourspace(icc.icc_alternate)
    _ => space
  }
}

///|
fn build_table(
  data : @pdfio.MutableBytes,
  hival : Int,
  components : Int,
) -> Map[Int, Array[Int]] raise {
  let total = (hival + 1) * components
  if @pdfio.bytes_size(data) < total {
    raise @pdf.PdfError::Msg("Pdfspace: bad table")
  }
  let table : Map[Int, Array[Int]] = Map::new()
  let mut offset = 0
  let mut x = 0
  while x <= hival {
    let row = Array::new(capacity=components)
    let mut i = 0
    while i < components {
      row.push(@pdfio.bget_unsafe(data, offset))
      offset = offset + 1
      i = i + 1
    }
    table.set(x, row)
    x = x + 1
  }
  table
}

///|
/// Read a colourspace from a PDF.
pub fn read_colourspace(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  space : @pdf.PdfObject,
) -> ColourSpace raise {
  let direct = match space {
    @pdf.PdfObject::Indirect(_) => @pdf.direct(pdf, space)
    _ => space
  }
  match direct {
    @pdf.PdfObject::Name("/DeviceGray") | @pdf.PdfObject::Name("/G") =>
      ColourSpace::DeviceGray
    @pdf.PdfObject::Name("/DeviceRGB") | @pdf.PdfObject::Name("/RGB") =>
      ColourSpace::DeviceRGB
    @pdf.PdfObject::Name("/DeviceCMYK") | @pdf.PdfObject::Name("/CMYK") =>
      ColourSpace::DeviceCMYK
    @pdf.PdfObject::Name("/Pattern") => ColourSpace::Pattern
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/Pattern"), base]) =>
      ColourSpace::PatternWithBaseColourspace(
        read_colourspace(pdf, resources, base),
      )
    @pdf.PdfObject::Array([one]) => read_colourspace(pdf, resources, one)
    @pdf.PdfObject::Name(name) =>
      match @pdf.lookup_direct(pdf, "/ColorSpace", resources) {
        Some(csdict) =>
          match @pdf.lookup_direct(pdf, name, csdict) {
            Some(space_obj) => read_colourspace(pdf, resources, space_obj)
            None => fail("Not_found")
          }
        None => fail("Not_found")
      }
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/CalGray"), dict]) => {
      let whitepoint = read_point(pdf, dict, "/WhitePoint")
      let blackpoint = read_point(pdf, dict, "/BlackPoint")
      let gamma = match @pdf.lookup_direct(pdf, "/Gamma", dict) {
        Some(n) => @pdf.getnum(pdf, n)
        None => 1.0
      }
      ColourSpace::CalGray(whitepoint, blackpoint, gamma)
    }
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/CalRGB"), dict]) => {
      let whitepoint = read_point(pdf, dict, "/WhitePoint")
      let blackpoint = read_point(pdf, dict, "/BlackPoint")
      let gamma = match @pdf.lookup_direct(pdf, "/Gamma", dict) {
        Some(@pdf.PdfObject::Array([a, b, c])) =>
          [@pdf.getnum(pdf, a), @pdf.getnum(pdf, b), @pdf.getnum(pdf, c)]
        _ => [1.0, 1.0, 1.0]
      }
      let matrix = match @pdf.lookup_direct(pdf, "/Matrix", dict) {
        Some(@pdf.PdfObject::Array([a, b, c, d, e, f, g, h, i])) =>
          [
            @pdf.getnum(pdf, a),
            @pdf.getnum(pdf, b),
            @pdf.getnum(pdf, c),
            @pdf.getnum(pdf, d),
            @pdf.getnum(pdf, e),
            @pdf.getnum(pdf, f),
            @pdf.getnum(pdf, g),
            @pdf.getnum(pdf, h),
            @pdf.getnum(pdf, i),
          ]
        _ => [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
      }
      ColourSpace::CalRGB(whitepoint, blackpoint, gamma, matrix)
    }
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/Lab"), dict]) => {
      let whitepoint = read_point(pdf, dict, "/WhitePoint")
      let blackpoint = read_point(pdf, dict, "/BlackPoint")
      let range = match @pdf.lookup_direct(pdf, "/Range", dict) {
        Some(@pdf.PdfObject::Array([a, b, c, d])) =>
          [
            @pdf.getnum(pdf, a),
            @pdf.getnum(pdf, b),
            @pdf.getnum(pdf, c),
            @pdf.getnum(pdf, d),
          ]
        _ => [-100.0, 100.0, -100.0, 100.0]
      }
      ColourSpace::Lab(whitepoint, blackpoint, range)
    }
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/ICCBased"), stream]) =>
      match @pdf.direct(pdf, stream) {
        @pdf.PdfObject::Stream(r) => {
          let (dict, _) = r.val
          let n = match @pdf.lookup_direct(pdf, "/N", dict) {
            Some(@pdf.PdfObject::Integer(value)) =>
              if value == 1 || value == 3 || value == 4 {
                value
              } else {
                raise @pdf.PdfError::Msg("Bad /N in ICCBased")
              }
            _ => raise @pdf.PdfError::Msg("Bad /N in ICCBased")
          }
          let alternate = match @pdf.lookup_direct(pdf, "/Alternate", dict) {
            Some(cs) => read_colourspace(pdf, resources, cs)
            _ =>
              match n {
                1 => ColourSpace::DeviceGray
                3 => ColourSpace::DeviceRGB
                4 => ColourSpace::DeviceCMYK
                _ => raise @pdf.PdfError::Msg("Bad /N in ICCBased")
              }
          }
          let range = match @pdf.lookup_direct(pdf, "/Range", dict) {
            Some(@pdf.PdfObject::Array(values)) if values.length() == 2 * n =>
              values.map(v => @pdf.getnum(pdf, v))
            _ => interleave_defaults(n)
          }
          let metadata = @pdf.lookup_direct(pdf, "/Metadata", dict)
          ColourSpace::ICCBased({
            icc_n: n,
            icc_alternate: alternate,
            icc_range: range,
            icc_metadata: metadata,
            icc_stream: stream,
          })
        }
        _ => raise @pdf.PdfError::Msg("ICCBased not a stream")
      }
    @pdf.PdfObject::Array(
      [
        @pdf.PdfObject::Name("/Indexed")
        | @pdf.PdfObject::Name("/I"),
        base,
        hival_obj,
        lookup_data,
      ]
    ) => {
      let hival = match hival_obj {
        @pdf.PdfObject::Integer(h) => h
        _ => raise @pdf.PdfError::Msg("Bad /Hival")
      }
      let base_space = read_colourspace(pdf, resources, base)
      let table = match @pdf.direct(pdf, lookup_data) {
        @pdf.PdfObject::Stream(_) as stream => {
          @pdfcodec.decode_pdfstream(pdf, stream)
          match stream {
            @pdf.PdfObject::Stream(r) =>
              match r.val {
                (_, @pdf.Stream::Got(data)) =>
                  match get_basic_table_colourspace(base_space) {
                    ColourSpace::DeviceCMYK => build_table(data, hival, 4)
                    ColourSpace::DeviceRGB
                    | ColourSpace::CalRGB(_, _, _, _)
                    | ColourSpace::Lab(_, _, _) => build_table(data, hival, 3)
                    ColourSpace::Pattern
                    | ColourSpace::PatternWithBaseColourspace(_)
                    | ColourSpace::Indexed(_, _) =>
                      raise @pdf.PdfError::Msg(
                        "Disallowed base colourspace in index colourspace",
                      )
                    _ =>
                      raise @pdf.PdfError::Msg(
                        "Unsupported base colourspace in index colourspace",
                      )
                  }
                _ => raise @pdf.PdfError::Msg("Indexed/Inconsistent")
              }
            _ => raise @pdf.PdfError::Msg("Indexed/Inconsistent")
          }
        }
        @pdf.PdfObject::String(s) => {
          let data = @pdfio.bytes_of_string(s)
          match get_basic_table_colourspace(base_space) {
            ColourSpace::DeviceRGB
            | ColourSpace::CalRGB(_, _, _, _)
            | ColourSpace::Lab(_, _, _) => build_table(data, hival, 3)
            ColourSpace::DeviceCMYK => build_table(data, hival, 4)
            ColourSpace::Pattern
            | ColourSpace::PatternWithBaseColourspace(_)
            | ColourSpace::Indexed(_, _) =>
              raise @pdf.PdfError::Msg(
                "Disallowed base colourspace in index colourspace",
              )
            _ =>
              raise @pdf.PdfError::Msg(
                "Unsupported base colourspace in index colourspace",
              )
          }
        }
        _ => raise @pdf.PdfError::Msg("Pdfspace: unknown indexed colourspace")
      }
      ColourSpace::Indexed(base_space, table)
    }
    @pdf.PdfObject::Array(
      [
        @pdf.PdfObject::Name("/Separation"),
        @pdf.PdfObject::Name(name),
        alternate,
        tint,
      ]
    ) => {
      let alt_space = read_colourspace(pdf, resources, alternate)
      let tint_transform = @pdffun.parse_function(pdf, tint)
      ColourSpace::Separation(name, alt_space, tint_transform)
    }
    @pdf.PdfObject::Array(
      [
        @pdf.PdfObject::Name("/DeviceN"),
        @pdf.PdfObject::Array(names),
        alternate,
        tint,
      ]
    ) => {
      let out_names = Array::new(capacity=names.length())
      for name in names {
        match name {
          @pdf.PdfObject::Name(value) => out_names.push(value)
          _ => fail("Not_found")
        }
      }
      let alt_space = read_colourspace(pdf, resources, alternate)
      let tint_transform = @pdffun.parse_function(pdf, tint)
      ColourSpace::DeviceN(
        out_names,
        alt_space,
        tint_transform,
        @pdf.PdfObject::Dictionary([]),
      )
    }
    @pdf.PdfObject::Array(
      [
        @pdf.PdfObject::Name("/DeviceN"),
        @pdf.PdfObject::Array(names),
        alternate,
        tint,
        attributes,
      ]
    ) => {
      let out_names = Array::new(capacity=names.length())
      for name in names {
        match name {
          @pdf.PdfObject::Name(value) => out_names.push(value)
          _ => fail("Not_found")
        }
      }
      let alt_space = read_colourspace(pdf, resources, alternate)
      let tint_transform = @pdffun.parse_function(pdf, tint)
      ColourSpace::DeviceN(out_names, alt_space, tint_transform, attributes)
    }
    _ => fail("Not_found")
  }
}

///|
fn interleave_defaults(n : Int) -> Array[Double] {
  let out = Array::new(capacity=2 * n)
  let mut i = 0
  while i < n {
    out.push(0.0)
    out.push(1.0)
    i = i + 1
  }
  out
}

///|
/// Write a colourspace to a PDF.
pub fn write_colourspace(pdf : @pdf.Pdf, space : ColourSpace) -> @pdf.PdfObject {
  let _ = pdf
  match space {
    ColourSpace::DeviceGray => @pdf.PdfObject::Name("/DeviceGray")
    ColourSpace::DeviceRGB => @pdf.PdfObject::Name("/DeviceRGB")
    ColourSpace::DeviceCMYK => @pdf.PdfObject::Name("/DeviceCMYK")
    _ => {
      @pdfe.log("write_colourspace space not supported\n")
      @pdf.PdfObject::Null
    }
  }
}
