///|
/// Font writing helpers.

///|
pub fn make_font(
  fontname : String,
  encoding : @pdffont.Encoding,
) -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Font")),
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    (
      "/Encoding",
      @pdf.PdfObject::Name("/" + @pdffont.string_of_encoding(encoding)),
    ),
    ("/BaseFont", @pdf.PdfObject::Name("/" + fontname)),
  ])
}

///|
pub fn PdfText::write_encoding(
  self : PdfText,
  encoding : @pdffont.Encoding,
) -> Int raise {
  fn encoding_name(enc : @pdffont.Encoding) -> String? {
    match enc {
      @pdffont.Encoding::StandardEncoding => Some("/StandardEncoding")
      @pdffont.Encoding::MacRomanEncoding => Some("/MacRomanEncoding")
      @pdffont.Encoding::WinAnsiEncoding => Some("/WinAnsiEncoding")
      @pdffont.Encoding::MacExpertEncoding => Some("/MacExpertEncoding")
      @pdffont.Encoding::CustomEncoding(inner, _) => encoding_name(inner)
      @pdffont.Encoding::FillUndefinedWithStandard(inner) =>
        encoding_name(inner)
      @pdffont.Encoding::ImplicitInFontFile => None
    }
  }

  match encoding {
    @pdffont.Encoding::StandardEncoding
    | @pdffont.Encoding::MacRomanEncoding
    | @pdffont.Encoding::WinAnsiEncoding
    | @pdffont.Encoding::MacExpertEncoding => {
      let name = match encoding_name(encoding) {
        Some(value) => value
        None => raise @pdf.PdfError::Msg("write_encoding: missing name")
      }
      @pdf.addobj(self.pdf, @pdf.PdfObject::Name(name))
    }
    @pdffont.Encoding::FillUndefinedWithStandard(inner) =>
      self.write_encoding(inner)
    @pdffont.Encoding::CustomEncoding(base, diffs) => {
      let diff_array = Array::new()
      for diff in diffs {
        diff_array.push(@pdf.PdfObject::Integer(diff.1))
        diff_array.push(@pdf.PdfObject::Name(diff.0))
      }
      let mut encoding_dict = @pdf.PdfObject::Dictionary([
        ("/Type", @pdf.PdfObject::Name("/Encoding")),
        ("/Differences", @pdf.PdfObject::Array(diff_array)),
      ])
      match encoding_name(base) {
        Some(name) =>
          encoding_dict = encoding_dict.add_entry(
            "/BaseEncoding",
            @pdf.PdfObject::Name(name),
          )
        None => ()
      }
      @pdf.addobj(self.pdf, encoding_dict)
    }
    @pdffont.Encoding::ImplicitInFontFile =>
      raise @pdf.PdfError::Msg("write_encoding: implicit encoding")
  }
}

///|
let tounicode_preamble : String =
  #|/CIDInit /ProcSet findresource begin
  #|12 dict begin
  #|begincmap
  #|/CIDSystemInfo <<
  #|  /Registry (Adobe)
  #|  /Ordering (UCS)
  #|  /Supplement 0
  #|>> def
  #|/CMapName /Adobe-Identity-UCS def
  #|/CMapType 2 def
  #|1 begincodespacerange
  #|<00><FF>
  #|endcodespacerange
  #|

///|
let tounicode_postamble : String =
  #|endbfrange
  #|endcmap
  #|CMapName currentdict /CMap defineresource pop
  #|end
  #|end
  #|

///|
let hex_digits_upper : Array[Char] = "0123456789ABCDEF".to_array()

///|
let hex_digits_lower : Array[Char] = "0123456789abcdef".to_array()

///|
fn hex_byte(digits : Array[Char], value : Int) -> String {
  let hi = value / 16
  let lo = value % 16
  String::from_array([digits[hi], digits[lo]])
}

///|
fn hex_byte_upper(value : Int) -> String {
  hex_byte(hex_digits_upper, value)
}

///|
fn hex_byte_lower(value : Int) -> String {
  hex_byte(hex_digits_lower, value)
}

///|
pub fn hex(u : String) -> String {
  let sb = StringBuilder::new()
  let bytes = @pdfio.bytes_of_string(u)
  for b in bytes {
    sb.write_string(hex_byte_upper(b.to_int()))
  }
  sb.to_string()
}

///|
pub fn tounicode_map(
  start_code : Int,
  us : Array[String],
) -> @pdfio.MutableBytes {
  let sb = StringBuilder::new()
  let mut code = start_code
  sb
  ..write_string(tounicode_preamble)
  ..write_string("\{us.length()} beginbfrange\n")
  for u in us {
    sb.write_string(
      "<\{hex_byte_lower(code)}><\{hex_byte_lower(code)}><\{hex(u)}>\n",
    )
    code = code + 1
  }
  sb.write_string(tounicode_postamble)
  @pdfio.bytes_of_string(sb.to_string())
}

///|
pub fn PdfText::write_tounicode(self : PdfText, u : Map[Int, String]) -> Int {
  let pairs = @pdfutil.list_of_hashtbl(u)
  pairs.sort_by((a, b) => a.0 - b.0)
  let strings = pairs.map(pair => pair.1)
  let bytes = tounicode_map(33, strings)
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(bytes))),
  ])
  @pdf.addobj(
    self.pdf,
    @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(bytes)))),
  )
}

///|
pub fn PdfText::write_font(
  self : PdfText,
  objnum? : Int,
  font : @pdffont.Font,
) -> Int raise {
  match font {
    @pdffont.Font::SimpleFont(simple) =>
      match simple.fonttype {
        @pdffont.SimpleFontType::Type3(type3) =>
          match simple.fontdescriptor {
            Some(_) => {
              let encoding_entry = match simple.encoding {
                @pdffont.Encoding::ImplicitInFontFile => []
                _ =>
                  [
                    (
                      "/Encoding",
                      @pdf.PdfObject::Indirect(
                        self.write_encoding(simple.encoding),
                      ),
                    ),
                  ]
              }
              let dict = @pdf.PdfObject::Dictionary(
                [
                  ("/Type", @pdf.PdfObject::Name("/Font")),
                  ("/Subtype", @pdf.PdfObject::Name("/Type3")),
                  (
                    "/FontBBox",
                    @pdf.PdfObject::Array([
                      @pdf.PdfObject::Real(0.0),
                      @pdf.PdfObject::Real(0.0),
                      @pdf.PdfObject::Real(0.0),
                      @pdf.PdfObject::Real(0.0),
                    ]),
                  ),
                  (
                    "/FontMatrix",
                    @pdf.PdfObject::Array([
                      @pdf.PdfObject::Real(0.0),
                      @pdf.PdfObject::Real(0.0),
                      @pdf.PdfObject::Real(0.0),
                      @pdf.PdfObject::Real(0.0),
                      @pdf.PdfObject::Real(0.0),
                      @pdf.PdfObject::Real(0.0),
                    ]),
                  ),
                  (
                    "/CharProcs",
                    @pdf.PdfObject::Dictionary(
                      type3.charprocs.map(pair => (pair.0, @pdf.PdfObject::Null)),
                    ),
                  ),
                  ("/FirstChar", @pdf.PdfObject::Integer(0)),
                  ("/LastChar", @pdf.PdfObject::Integer(0)),
                  (
                    "/Widths",
                    @pdf.PdfObject::Array([@pdf.PdfObject::Real(0.0)]),
                  ),
                ].add(encoding_entry),
              )
              @pdf.addobj(self.pdf, dict)
            }
            None => raise @pdf.PdfError::Msg("Missing font descriptor")
          }
        @pdffont.SimpleFontType::Truetype =>
          match simple.fontdescriptor {
            Some(fd) =>
              match fd.fontfile {
                Some(@pdffont.FontFile::FontFile2(ttf)) => {
                  let (minx, miny, maxx, maxy) = fd.fontbbox
                  let fontdesc = @pdf.PdfObject::Dictionary([
                    ("/Type", @pdf.PdfObject::Name("/FontDescriptor")),
                    ("/FontName", @pdf.PdfObject::Name(simple.basefont)),
                    ("/Flags", @pdf.PdfObject::Integer(fd.flags)),
                    (
                      "/FontBBox",
                      @pdf.PdfObject::Array([
                        @pdf.PdfObject::Integer(minx.to_int()),
                        @pdf.PdfObject::Integer(miny.to_int()),
                        @pdf.PdfObject::Integer(maxx.to_int()),
                        @pdf.PdfObject::Integer(maxy.to_int()),
                      ]),
                    ),
                    (
                      "/ItalicAngle",
                      @pdf.PdfObject::Integer(fd.italicangle.to_int()),
                    ),
                    ("/Ascent", @pdf.PdfObject::Integer(fd.ascent.to_int())),
                    ("/Descent", @pdf.PdfObject::Integer(fd.descent.to_int())),
                    (
                      "/CapHeight",
                      @pdf.PdfObject::Integer(fd.capheight.to_int()),
                    ),
                    ("/StemV", @pdf.PdfObject::Integer(fd.stemv.to_int())),
                    ("/XHeight", @pdf.PdfObject::Integer(fd.xheight.to_int())),
                    ("/AvgWidth", @pdf.PdfObject::Integer(fd.avgwidth.to_int())),
                    ("/MaxWidth", @pdf.PdfObject::Integer(fd.maxwidth.to_int())),
                    ("/FontFile2", @pdf.PdfObject::Indirect(ttf)),
                  ])
                  let fontdesc_num = @pdf.addobj(self.pdf, fontdesc)
                  let mut font_dict_entries : Array[(String, @pdf.PdfObject)] = [
                    ("/Type", @pdf.PdfObject::Name("/Font")),
                    ("/Subtype", @pdf.PdfObject::Name("/TrueType")),
                    ("/BaseFont", @pdf.PdfObject::Name(simple.basefont)),
                    ("/FontDescriptor", @pdf.PdfObject::Indirect(fontdesc_num)),
                    ("/FirstChar", @pdf.PdfObject::Integer(simple.firstchar)),
                    ("/LastChar", @pdf.PdfObject::Integer(simple.lastchar)),
                    (
                      "/Widths",
                      @pdf.PdfObject::Array(
                        simple.widths.map(w => @pdf.PdfObject::Integer(w)),
                      ),
                    ),
                  ]
                  font_dict_entries = match fd.tounicode {
                    None =>
                      font_dict_entries.add([
                        (
                          "/Encoding",
                          @pdf.PdfObject::Name(
                            "/" + @pdffont.string_of_encoding(simple.encoding),
                          ),
                        ),
                      ])
                    Some(u) =>
                      font_dict_entries.add([
                        (
                          "/ToUnicode",
                          @pdf.PdfObject::Indirect(self.write_tounicode(u)),
                        ),
                      ])
                  }
                  let font_obj = @pdf.PdfObject::Dictionary(font_dict_entries)
                  match objnum {
                    None => @pdf.addobj(self.pdf, font_obj)
                    Some(o) => {
                      @pdf.addobj_given_num(self.pdf, (o, font_obj))
                      o
                    }
                  }
                }
                _ => raise @pdf.PdfError::Msg("Missing FontFile2")
              }
            None => raise @pdf.PdfError::Msg("Missing font descriptor")
          }
        _ =>
          raise @pdf.PdfError::Msg(
            "Pdftext.write_font does not support this font",
          )
      }
    @pdffont.Font::StandardFont(standard, encoding) =>
      @pdf.addobj(
        self.pdf,
        make_font(@pdffont.string_of_standard_font(standard), encoding),
      )
    _ =>
      raise @pdf.PdfError::Msg("Pdftext.write_font does not support this font")
  }
}
