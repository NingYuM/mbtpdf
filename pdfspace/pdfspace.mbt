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
  for x in 0..<=hival {
    let row = Array::new(capacity=components)
    for _ in 0..<components {
      row.push(@pdfio.bget_unsafe(data, offset))
      offset = offset + 1
    }
    table.set(x, row)
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
  for _ in 0..<n {
    out.push(0.0)
    out.push(1.0)
  }
  out
}

///|
fn mkreal(x : Double) -> @pdf.PdfObject {
  @pdf.PdfObject::Real(x)
}

///|
fn mkint(x : Int) -> @pdf.PdfObject {
  @pdf.PdfObject::Integer(x)
}

///|
fn normalize_name(name : String) -> String {
  if name.has_prefix("/") {
    name
  } else {
    "/\{name}"
  }
}

///|
fn array_of_point(point : Point) -> @pdf.PdfObject {
  @pdf.PdfObject::Array([mkreal(point.0), mkreal(point.1), mkreal(point.2)])
}

///|
fn dict_entries(obj : @pdf.PdfObject) -> Array[(String, @pdf.PdfObject)] {
  match obj {
    @pdf.PdfObject::Dictionary(entries) => entries
    _ => []
  }
}

///|
fn dict_has_key(
  entries : Array[(String, @pdf.PdfObject)],
  key : String,
) -> Bool {
  entries.search_by(pair => pair.0 == key) is Some(_)
}

///|
fn dict_set(
  entries : Array[(String, @pdf.PdfObject)],
  key : String,
  value : @pdf.PdfObject,
) -> Array[(String, @pdf.PdfObject)] {
  let out = Array::new(capacity=entries.length() + 1)
  let mut found = false
  for pair in entries {
    if pair.0 == key {
      out.push((key, value))
      found = true
    } else {
      out.push(pair)
    }
  }
  if !found {
    out.push((key, value))
  }
  out
}

///|
fn ensure_length(
  entries : Array[(String, @pdf.PdfObject)],
  stream_data : @pdf.Stream,
) -> Array[(String, @pdf.PdfObject)] {
  if dict_has_key(entries, "/Length") {
    return entries
  }
  match stream_data {
    @pdf.Stream::Got(bytes) =>
      dict_set(entries, "/Length", mkint(@pdfio.bytes_size(bytes)))
    _ => entries
  }
}

///|
fn is_empty_dict(obj : @pdf.PdfObject) -> Bool {
  match obj {
    @pdf.PdfObject::Dictionary(entries) => entries.length() == 0
    _ => false
  }
}

///|
fn components_of_colourspace(space : ColourSpace) -> Int {
  match get_basic_table_colourspace(space) {
    ColourSpace::DeviceGray | ColourSpace::CalGray(_, _, _) => 1
    ColourSpace::DeviceRGB
    | ColourSpace::CalRGB(_, _, _, _)
    | ColourSpace::Lab(_, _, _) => 3
    ColourSpace::DeviceCMYK => 4
    _ => 0
  }
}

///|
fn table_bytes(
  table : Map[Int, Array[Int]],
  hival : Int,
  components : Int,
) -> @pdfio.MutableBytes {
  let total = if hival >= 0 { (hival + 1) * components } else { 0 }
  let data = @pdfio.mkbytes(total)
  let mut offset = 0
  let mut i = 0
  while i <= hival {
    let row = match table.get(i) {
      Some(values) => values
      None => Array::make(components, 0)
    }
    let mut j = 0
    while j < components {
      let value = if j < row.length() { row[j] } else { 0 }
      if offset < data.length() {
        data[offset] = value.to_byte()
      }
      offset = offset + 1
      j = j + 1
    }
    i = i + 1
  }
  data
}

///|
fn write_iccbased(pdf : @pdf.Pdf, icc : ICCBased) -> @pdf.PdfObject {
  match icc.icc_stream {
    @pdf.PdfObject::Stream(r) => {
      let (dict_obj, stream_data) = r.val
      let entries = dict_entries(dict_obj)
      let entries = dict_set(entries, "/N", mkint(icc.icc_n))
      let entries = dict_set(
        entries,
        "/Alternate",
        write_colourspace(pdf, icc.icc_alternate),
      )
      let entries = if icc.icc_range.length() == 2 * icc.icc_n {
        dict_set(
          entries,
          "/Range",
          @pdf.PdfObject::Array(icc.icc_range.map(mkreal)),
        )
      } else {
        entries
      }
      let entries = match icc.icc_metadata {
        Some(metadata) => dict_set(entries, "/Metadata", metadata)
        None => entries
      }
      let entries = ensure_length(entries, stream_data)
      let stream_obj = @pdf.PdfObject::Stream(
        Ref::new((@pdf.PdfObject::Dictionary(entries), stream_data)),
      )
      let objnum = @pdf.addobj(pdf, stream_obj)
      @pdf.PdfObject::Indirect(objnum)
    }
    _ => {
      @pdfe.log("write_colourspace: ICCBased stream missing\n")
      write_colourspace(pdf, icc.icc_alternate)
    }
  }
}

///|
/// Write a colourspace to a PDF.
pub fn write_colourspace(pdf : @pdf.Pdf, space : ColourSpace) -> @pdf.PdfObject {
  let _ = pdf
  match space {
    ColourSpace::DeviceGray => @pdf.PdfObject::Name("/DeviceGray")
    ColourSpace::DeviceRGB => @pdf.PdfObject::Name("/DeviceRGB")
    ColourSpace::DeviceCMYK => @pdf.PdfObject::Name("/DeviceCMYK")
    ColourSpace::CalGray(white, black, gamma) =>
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/CalGray"),
        @pdf.PdfObject::Dictionary([
          ("/WhitePoint", array_of_point(white)),
          ("/BlackPoint", array_of_point(black)),
          ("/Gamma", mkreal(gamma)),
        ]),
      ])
    ColourSpace::CalRGB(white, black, gamma, matrix) =>
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/CalRGB"),
        @pdf.PdfObject::Dictionary([
          ("/WhitePoint", array_of_point(white)),
          ("/BlackPoint", array_of_point(black)),
          ("/Gamma", @pdf.PdfObject::Array(gamma.map(mkreal))),
          ("/Matrix", @pdf.PdfObject::Array(matrix.map(mkreal))),
        ]),
      ])
    ColourSpace::Lab(white, black, range) =>
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Lab"),
        @pdf.PdfObject::Dictionary([
          ("/WhitePoint", array_of_point(white)),
          ("/BlackPoint", array_of_point(black)),
          ("/Range", @pdf.PdfObject::Array(range.map(mkreal))),
        ]),
      ])
    ColourSpace::ICCBased(icc) =>
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/ICCBased"),
        write_iccbased(pdf, icc),
      ])
    ColourSpace::Indexed(base, table) => {
      let components = components_of_colourspace(base)
      if components == 0 {
        @pdfe.log("write_colourspace: Indexed base not supported\n")
        @pdf.PdfObject::Null
      } else {
        let mut hival = -1
        for pair in table.to_array() {
          if pair.0 > hival {
            hival = pair.0
          }
        }
        if hival < 0 {
          hival = 0
        }
        let data = table_bytes(table, hival, components)
        let lookup = @pdfio.string_of_bytes(data)
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Name("/Indexed"),
          write_colourspace(pdf, base),
          @pdf.PdfObject::Integer(hival),
          @pdf.PdfObject::String(lookup),
        ])
      }
    }
    ColourSpace::Pattern => @pdf.PdfObject::Name("/Pattern")
    ColourSpace::PatternWithBaseColourspace(base) =>
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Pattern"),
        write_colourspace(pdf, base),
      ])
    ColourSpace::Separation(name, alternate, tint) =>
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Separation"),
        @pdf.PdfObject::Name(normalize_name(name)),
        write_colourspace(pdf, alternate),
        @pdffun.pdfobject_of_function(pdf, tint),
      ])
    ColourSpace::DeviceN(names, alternate, tint, attrs) => {
      let names_obj = @pdf.PdfObject::Array(
        names.map(name => @pdf.PdfObject::Name(normalize_name(name))),
      )
      let base = [
        @pdf.PdfObject::Name("/DeviceN"),
        names_obj,
        write_colourspace(pdf, alternate),
        @pdffun.pdfobject_of_function(pdf, tint),
      ]
      if is_empty_dict(attrs) {
        @pdf.PdfObject::Array(base)
      } else {
        let with_attrs = Array::new(capacity=base.length() + 1)
        for item in base {
          with_attrs.push(item)
        }
        with_attrs.push(attrs)
        @pdf.PdfObject::Array(with_attrs)
      }
    }
  }
}
