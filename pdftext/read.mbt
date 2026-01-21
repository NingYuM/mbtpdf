///|
/// Font parsing helpers.

///|
fn find_indirect(pdf : @pdf.Pdf, key : String, dict : @pdf.PdfObject) -> Int? {
  let dict_obj = @pdf.direct(pdf, dict)
  match @pdf.lookup_immediate(key, dict_obj) {
    Some(@pdf.PdfObject::Indirect(i)) => Some(i)
    _ => None
  }
}

///|
fn parse_matrix(
  pdf : @pdf.Pdf,
  key : String,
  dict : @pdf.PdfObject,
) -> @pdftransform.TransformMatrix raise {
  let obj = @pdf.lookup_fail("No matrix", pdf, key, dict)
  match obj {
    @pdf.PdfObject::Array(vals) =>
      if vals.length() != 6 {
        raise @pdf.PdfError::Msg("Bad matrix")
      } else {
        let a = @pdf.getnum(pdf, vals[0])
        let b = @pdf.getnum(pdf, vals[1])
        let c = @pdf.getnum(pdf, vals[2])
        let d = @pdf.getnum(pdf, vals[3])
        let e = @pdf.getnum(pdf, vals[4])
        let f = @pdf.getnum(pdf, vals[5])
        { a, b, c, d, e, f }
      }
    _ => raise @pdf.PdfError::Msg("Bad matrix")
  }
}

///|
pub fn read_type3_data(
  pdf : @pdf.Pdf,
  font : @pdf.PdfObject,
) -> Type3Glyphs raise {
  {
    fontbbox: @pdf.parse_rectangle(
      pdf,
      @pdf.lookup_fail("No fontbbox", pdf, "/FontBBox", font),
    ),
    fontmatrix: parse_matrix(pdf, "/FontMatrix", font),
    charprocs: match
      @pdf.lookup_fail("Bad Charprocs", pdf, "/CharProcs", font) {
      @pdf.PdfObject::Dictionary(l) => l
      _ => raise @pdf.PdfError::Msg("Bad charprocs")
    },
    type3_resources: match @pdf.lookup_direct(pdf, "/Resources", font) {
      None => @pdf.PdfObject::Dictionary([])
      Some(d) => d
    },
  }
}

///|
pub fn simple_fonttype_of_string(
  pdf : @pdf.Pdf,
  font : @pdf.PdfObject,
  subtype : String,
) -> SimpleFontType? raise {
  match subtype {
    "/Type1" => Some(SimpleFontType::Type1)
    "/MMType1" => Some(SimpleFontType::MMType1)
    "/Type3" => Some(SimpleFontType::Type3(read_type3_data(pdf, font)))
    "/TrueType" => Some(SimpleFontType::Truetype)
    _ => None
  }
}

///|
pub fn read_basefont(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> String {
  match @pdf.lookup_direct(pdf, "/BaseFont", font) {
    Some(@pdf.PdfObject::Name(n)) => n
    _ => ""
  }
}

///|
pub fn parse_charset(s : String) -> Array[String] {
  let input = @pdfio.input_of_string(s)
  let out = Array::new()
  while true {
    try {
      @pdfsyntax.dropwhite(input)
      match @pdfsyntax.lex_name(input) {
        @pdfgenlex.Token::LexName(name) =>
          if name == "/" {
            break
          } else {
            out.push(name)
          }
        _ => break
      }
    } catch {
      _ => break
    }
  }
  out
}

///|
pub fn read_fontdescriptor(
  pdf : @pdf.Pdf,
  font : @pdf.PdfObject,
) -> FontDescriptor? raise {
  match @pdf.lookup_direct(pdf, "/FontDescriptor", font) {
    None => None
    Some(fontdescriptor) => {
      let ascent = match @pdf.lookup_direct(pdf, "/Ascent", fontdescriptor) {
        Some(x) => @pdf.getnum(pdf, x)
        None => 0.0
      }
      let descent = match @pdf.lookup_direct(pdf, "/Descent", fontdescriptor) {
        Some(x) => @pdf.getnum(pdf, x)
        None => 0.0
      }
      let avgwidth = match
        @pdf.lookup_direct(pdf, "/AvgWidth", fontdescriptor) {
        Some(x) => @pdf.getnum(pdf, x)
        None => 0.0
      }
      let maxwidth = match
        @pdf.lookup_direct(pdf, "/MaxWidth", fontdescriptor) {
        Some(x) => @pdf.getnum(pdf, x)
        None => 0.0
      }
      let fontfile = match find_indirect(pdf, "/FontFile", fontdescriptor) {
        Some(i) => Some(FontFile::FontFile(i))
        None =>
          match find_indirect(pdf, "/FontFile2", fontdescriptor) {
            Some(i) => Some(FontFile::FontFile2(i))
            None =>
              match find_indirect(pdf, "/FontFile3", fontdescriptor) {
                Some(i) => Some(FontFile::FontFile3(i))
                None => None
              }
          }
      }
      let charset = match @pdf.lookup_direct(pdf, "/CharSet", fontdescriptor) {
        Some(@pdf.PdfObject::String(s)) => Some(parse_charset(s))
        _ => None
      }
      Some({
        ascent,
        descent,
        avgwidth,
        maxwidth,
        fontfile,
        charset,
        flags: 0,
        fontbbox: (0.0, 0.0, 0.0, 0.0),
        italicangle: 0.0,
        capheight: 0.0,
        xheight: 0.0,
        stemv: 0.0,
        tounicode: None,
        tounicode_bytes: None,
      })
    }
  }
}

///|
fn repeat_double(value : Double, count : Int) -> Array[Double] {
  let out = Array::new(capacity=if count > 0 { count } else { 0 })
  for _ in 0..<count {
    out.push(value)
  }
  out
}

///|
pub fn read_metrics(
  pdf : @pdf.Pdf,
  font : @pdf.PdfObject,
) -> FontMetrics? raise {
  let fontdescriptor = match @pdf.lookup_direct(pdf, "/Subtype", font) {
    Some(@pdf.PdfObject::Name("/Type3")) => Some(font)
    _ => @pdf.lookup_direct(pdf, "/FontDescriptor", font)
  }
  match fontdescriptor {
    None => None
    Some(descriptor) => {
      let firstchar = match @pdf.lookup_direct(pdf, "/FirstChar", font) {
        Some(@pdf.PdfObject::Integer(i)) =>
          if i <= 255 && i >= 0 {
            i
          } else {
            raise @pdf.PdfError::Msg("Bad /Firstchar")
          }
        _ => raise @pdf.PdfError::Msg("No /FirstChar")
      }
      let lastchar = match @pdf.lookup_direct(pdf, "/LastChar", font) {
        Some(@pdf.PdfObject::Integer(i)) =>
          if i <= 255 && i >= 0 {
            i
          } else {
            raise @pdf.PdfError::Msg("Bad /Lastchar")
          }
        _ => raise @pdf.PdfError::Msg("No /LastChar")
      }
      let missingwidth = match
        @pdf.lookup_direct(pdf, "/MissingWidth", descriptor) {
        Some(@pdf.PdfObject::Integer(w)) => Double::from_int(w)
        Some(@pdf.PdfObject::Real(w)) => w
        _ => 0.0
      }
      let elts = match @pdf.lookup_direct(pdf, "/Widths", font) {
        Some(@pdf.PdfObject::Array(values)) => values
        _ => raise @pdf.PdfError::Msg("No /Widths")
      }
      if elts.length() != lastchar - firstchar + 1 {
        raise @pdf.PdfError::Msg("Bad /Widths")
      }
      let before = repeat_double(missingwidth, firstchar)
      let given = elts.map(elt => match @pdf.direct(pdf, elt) {
        @pdf.PdfObject::Integer(i) => Double::from_int(i)
        @pdf.PdfObject::Real(f) => f
        _ => raise @pdf.PdfError::Msg("Bad /Width entry")
      })
      let after = repeat_double(missingwidth, 255 - lastchar)
      let metrics = Array::new(
        capacity=before.length() + given.length() + after.length(),
      )
      metrics.append(before)
      metrics.append(given)
      metrics.append(after)
      Some(metrics)
    }
  }
}

///|
pub fn pairs_of_differences(
  pdf : @pdf.Pdf,
  differences : @pdf.PdfObject,
) -> Differences raise {
  match differences {
    @pdf.PdfObject::Array(elts) => {
      let direct = elts.map(obj => @pdf.direct(pdf, obj))
      let out = Array::new()
      let mut i = 0
      while i < direct.length() {
        match direct[i] {
          @pdf.PdfObject::Integer(n) => {
            i = i + 1
            let names = Array::new()
            while i < direct.length() {
              match direct[i] {
                @pdf.PdfObject::Name(name) => {
                  names.push(name)
                  i = i + 1
                }
                _ => break
              }
            }
            for idx in 0..<names.length() {
              out.push((names[idx], n + idx))
            }
          }
          _ => raise @pdf.PdfError::Msg("Malformed /Differences")
        }
      }
      out
    }
    _ => raise @pdf.PdfError::Msg("Bad /Differences")
  }
}

///|
pub fn standard_font_of_name(name : String) -> StandardFont? {
  match name {
    "/Times-Roman" | "/TimesNewRoman" => Some(StandardFont::TimesRoman)
    "/Times-Bold" | "/TimesNewRoman,Bold" => Some(StandardFont::TimesBold)
    "/Times-Italic" | "/TimesNewRoman,Italic" => Some(StandardFont::TimesItalic)
    "/Times-BoldItalic" | "/TimesNewRoman,BoldItalic" =>
      Some(StandardFont::TimesBoldItalic)
    "/Helvetica" | "/Arial" => Some(StandardFont::Helvetica)
    "/Helvetica-Bold" | "/Arial,Bold" => Some(StandardFont::HelveticaBold)
    "/Helvetica-Oblique" | "/Arial,Italic" =>
      Some(StandardFont::HelveticaOblique)
    "/Helvetica-BoldOblique" | "/Arial,BoldItalic" =>
      Some(StandardFont::HelveticaBoldOblique)
    "/Courier" | "/CourierNew" => Some(StandardFont::Courier)
    "/Courier-Bold" | "/CourierNew,Bold" => Some(StandardFont::CourierBold)
    "/Courier-Oblique" | "/CourierNew,Italic" =>
      Some(StandardFont::CourierOblique)
    "/Courier-BoldOblique" | "/CourierNew,BoldItalic" =>
      Some(StandardFont::CourierBoldOblique)
    "/Symbol" => Some(StandardFont::Symbol)
    "/ZapfDingbats" => Some(StandardFont::ZapfDingbats)
    _ => None
  }
}

///|
pub fn is_standard14font(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> Bool {
  match @pdf.lookup_direct(pdf, "/Subtype", font) {
    Some(@pdf.PdfObject::Name("/Type1")) =>
      match @pdf.lookup_direct(pdf, "/BaseFont", font) {
        Some(@pdf.PdfObject::Name(name)) =>
          match standard_font_of_name(name) {
            None => false
            Some(_) =>
              match @pdf.lookup_direct(pdf, "/Widths", font) {
                None => true
                Some(_) => false
              }
          }
        _ => false
      }
    _ => false
  }
}

///|
pub fn is_embedded(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> Bool {
  match @pdf.lookup_direct(pdf, "/FontDescriptor", font) {
    None => false
    Some(fontdescriptor) =>
      match
        @pdf.lookup_direct_orelse(
          pdf, "/FontFile", "/FontFile2", fontdescriptor,
        ) {
        Some(_) => true
        None =>
          match @pdf.lookup_direct(pdf, "/FontFile3", fontdescriptor) {
            Some(_) => true
            None => false
          }
      }
  }
}

///|
pub fn is_symbolic(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> Bool raise {
  match @pdf.lookup_direct(pdf, "/FontDescriptor", font) {
    None => false
    Some(fontdescriptor) =>
      match @pdf.lookup_direct(pdf, "/Flags", fontdescriptor) {
        Some(@pdf.PdfObject::Integer(flags)) => (flags & (1 << 3)) > 0
        _ => raise @pdf.PdfError::Msg("No /Flags in font descriptor")
      }
  }
}

///|
pub fn read_encoding(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> Encoding raise {
  match @pdf.lookup_direct(pdf, "/Encoding", font) {
    Some(@pdf.PdfObject::Name("/MacRomanEncoding")) =>
      Encoding::MacRomanEncoding
    Some(@pdf.PdfObject::Name("/MacExpertEncoding")) =>
      Encoding::MacExpertEncoding
    Some(@pdf.PdfObject::Name("/WinAnsiEncoding")) => Encoding::WinAnsiEncoding
    Some(encdict) =>
      match encdict {
        @pdf.PdfObject::Dictionary(_) =>
          match @pdf.lookup_direct(pdf, "/Subtype", font) {
            Some(@pdf.PdfObject::Name(fonttype)) =>
              if fonttype == "/Type1" ||
                fonttype == "/MMType1" ||
                fonttype == "/Type3" ||
                fonttype == "/TrueType" {
                let base_encoding = match
                  @pdf.lookup_direct(pdf, "/BaseEncoding", encdict) {
                  Some(@pdf.PdfObject::Name("/MacRomanEncoding")) =>
                    Encoding::MacRomanEncoding
                  Some(@pdf.PdfObject::Name("/MacExpertEncoding")) =>
                    Encoding::MacExpertEncoding
                  Some(@pdf.PdfObject::Name("/WinAnsiEncoding")) =>
                    Encoding::WinAnsiEncoding
                  None =>
                    if is_embedded(pdf, font) {
                      Encoding::ImplicitInFontFile
                    } else if is_symbolic(pdf, font) {
                      Encoding::ImplicitInFontFile
                    } else {
                      Encoding::StandardEncoding
                    }
                  _ => raise @pdf.PdfError::Msg("unknown /BaseEncoding")
                }
                let encoding = match
                  @pdf.lookup_direct(pdf, "/Differences", encdict) {
                  Some(differences) =>
                    Encoding::CustomEncoding(
                      base_encoding,
                      pairs_of_differences(pdf, differences),
                    )
                  _ => base_encoding
                }
                if fonttype == "/TrueType" {
                  Encoding::FillUndefinedWithStandard(encoding)
                } else {
                  encoding
                }
              } else {
                raise @pdf.PdfError::Msg("Bad font /Subtype")
              }
            _ => raise @pdf.PdfError::Msg("Bad font /Subtype")
          }
        _ => Encoding::ImplicitInFontFile
      }
    _ => Encoding::ImplicitInFontFile
  }
}

///|
pub fn read_simple_font(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> Font raise {
  match @pdf.lookup_direct(pdf, "/Subtype", font) {
    Some(@pdf.PdfObject::Name(n)) =>
      match simple_fonttype_of_string(pdf, font, n) {
        Some(fonttype) => {
          let fontdescriptor = read_fontdescriptor(pdf, font)
          let fontmetrics = read_metrics(pdf, font)
          Font::SimpleFont({
            fonttype,
            basefont: read_basefont(pdf, font),
            fontmetrics,
            firstchar: 0,
            lastchar: 0,
            widths: [],
            fontdescriptor,
            encoding: read_encoding(pdf, font),
          })
        }
        None => raise @pdf.PdfError::Msg("Not a simple font")
      }
    _ => raise @pdf.PdfError::Msg("No font /Subtype")
  }
}

///|
pub fn read_standard14font(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> Font raise {
  match @pdf.lookup_direct(pdf, "/BaseFont", font) {
    Some(@pdf.PdfObject::Name(name)) =>
      match standard_font_of_name(name) {
        None => raise @pdf.PdfError::Msg("Not a base 14 font")
        Some(f) => Font::StandardFont(f, read_encoding(pdf, font))
      }
    _ => raise @pdf.PdfError::Msg("Bad base 14 font")
  }
}

///|
pub fn is_simple_font(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> Bool {
  match @pdf.lookup_direct(pdf, "/Subtype", font) {
    Some(@pdf.PdfObject::Name(name)) =>
      name == "/Type1" ||
      name == "/MMType1" ||
      name == "/Type3" ||
      name == "/TrueType"
    _ => false
  }
}

///|
pub fn is_cidkeyed_font(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> Bool {
  match @pdf.lookup_direct(pdf, "/Subtype", font) {
    Some(@pdf.PdfObject::Name("/Type0")) => true
    _ => false
  }
}

///|
pub fn read_cid_system_info(
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
) -> CIDSystemInfo raise {
  let registry = match @pdf.lookup_direct(pdf, "/Registry", dict) {
    Some(@pdf.PdfObject::String(s)) => s
    _ => raise @pdf.PdfError::Msg("No /Registry")
  }
  let ordering = match @pdf.lookup_direct(pdf, "/Ordering", dict) {
    Some(@pdf.PdfObject::String(s)) => s
    _ => raise @pdf.PdfError::Msg("No /Ordering")
  }
  let supplement = match @pdf.lookup_direct(pdf, "/Supplement", dict) {
    Some(@pdf.PdfObject::Integer(i)) => i
    _ => raise @pdf.PdfError::Msg("No /Supplement")
  }
  { registry, ordering, supplement }
}

///|
pub fn read_cid_widths(
  elts : Array[@pdf.PdfObject],
) -> Array[(Int, Double)] raise {
  let out = Array::new()
  let mut i = 0
  while i < elts.length() {
    match elts[i] {
      @pdf.PdfObject::Integer(c) =>
        if i + 1 >= elts.length() {
          raise @pdf.PdfError::Msg("Bad /W array")
        } else {
          match elts[i + 1] {
            @pdf.PdfObject::Array(ws) => {
              let nums = ws.map(w => match w {
                @pdf.PdfObject::Integer(n) => Double::from_int(n)
                @pdf.PdfObject::Real(r) => r
                _ => raise @pdf.PdfError::Msg("Bad /W array")
              })
              for j in 0..<nums.length() {
                out.push((c + j, nums[j]))
              }
              i = i + 2
            }
            @pdf.PdfObject::Integer(c_last) => {
              if i + 2 >= elts.length() {
                raise @pdf.PdfError::Msg("Bad /W array")
              }
              let w = match elts[i + 2] {
                @pdf.PdfObject::Integer(n) => Double::from_int(n)
                @pdf.PdfObject::Real(r) => r
                _ => raise @pdf.PdfError::Msg("Bad /W array")
              }
              if c_last < c {
                raise @pdf.PdfError::Msg("Bad /W array")
              }
              for code in c..<=c_last {
                out.push((code, w))
              }
              i = i + 3
            }
            _ => raise @pdf.PdfError::Msg("Bad /W array")
          }
        }
      _ => raise @pdf.PdfError::Msg("Malformed /W in CIDfont")
    }
  }
  out
}

///|
pub fn read_descendant(
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
) -> CompositeCIDFont raise {
  let cid_system_info = match @pdf.lookup_direct(pdf, "/CIDSystemInfo", dict) {
    Some(cid_dict) => read_cid_system_info(pdf, cid_dict)
    None => raise @pdf.PdfError::Msg("No CIDSystemInfo")
  }
  let cid_basefont = match @pdf.lookup_direct(pdf, "/BaseFont", dict) {
    Some(@pdf.PdfObject::Name(n)) => n
    _ => raise @pdf.PdfError::Msg("No /BaseFont")
  }
  let cid_fontdescriptor = match read_fontdescriptor(pdf, dict) {
    Some(f) => f
    None => raise @pdf.PdfError::Msg("No FontDescriptor in CIDkeyed font")
  }
  let cid_widths = match @pdf.lookup_direct(pdf, "/W", dict) {
    Some(@pdf.PdfObject::Array(ws)) => read_cid_widths(ws)
    _ => []
  }
  let default_width = match @pdf.lookup_direct(pdf, "/DW", dict) {
    Some(@pdf.PdfObject::Integer(d)) => d
    _ => 1000
  }
  {
    cid_system_info,
    cid_basefont,
    cid_fontdescriptor,
    cid_widths,
    cid_default_width: default_width,
  }
}

///|
pub fn read_cidkeyed_font(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> Font raise {
  let basefont = match @pdf.lookup_direct(pdf, "/BaseFont", font) {
    Some(@pdf.PdfObject::Name(b)) => b
    _ => raise @pdf.PdfError::Msg("Bad /BaseFont")
  }
  let composite = match @pdf.lookup_direct(pdf, "/DescendantFonts", font) {
    Some(@pdf.PdfObject::Array(elts)) =>
      if elts.length() == 1 {
        read_descendant(pdf, @pdf.direct(pdf, elts[0]))
      } else {
        raise @pdf.PdfError::Msg("Bad descendant font")
      }
    _ => raise @pdf.PdfError::Msg("Bad descendant font")
  }
  let encoding = match @pdf.lookup_direct(pdf, "/Encoding", font) {
    Some(@pdf.PdfObject::Name(e)) => CMapEncoding::Predefined(e)
    Some(@pdf.PdfObject::Stream(_)) =>
      match find_indirect(pdf, "/Encoding", font) {
        Some(n) => CMapEncoding::CMap(n)
        None => raise @pdf.PdfError::Msg("malformed /Encoding")
      }
    _ => raise @pdf.PdfError::Msg("malformed or missing /Encoding")
  }
  Font::CIDKeyedFont(basefont, composite, encoding)
}

///|
pub fn add_tounicode(
  pdf : @pdf.Pdf,
  font : Font,
  fontdict : @pdf.PdfObject,
) -> Font {
  fn code_int_of_string(code : String) -> Int {
    let bytes = @pdfio.bytes_of_string(code)
    let mut value = 0
    for b in bytes {
      value = (value << 8) | b.to_int()
    }
    value
  }

  let (tounicode, tounicode_bytes) = match
    @pdf.lookup_direct(pdf, "/ToUnicode", fontdict) {
    Some(tounicode) =>
      try {
        let parsed = @pdfcmap.parse_cmap(pdf, tounicode)
        let bytes_map = @pdfutil.hashtable_of_dictionary(parsed.map)
        let int_pairs = parsed.map.map(pair => (
          code_int_of_string(pair.0),
          pair.1,
        ))
        let int_map = @pdfutil.hashtable_of_dictionary(int_pairs)
        (Some(int_map), Some(bytes_map))
      } catch {
        err => {
          @pdfe.log("bad tounicode\n")
          let _ = err
          (None, None)
        }
      }
    None => (None, None)
  }
  match font {
    Font::SimpleFont(simple) =>
      match simple.fontdescriptor {
        Some(fd) => {
          let updated_fd : FontDescriptor = {
            ascent: fd.ascent,
            descent: fd.descent,
            avgwidth: fd.avgwidth,
            maxwidth: fd.maxwidth,
            flags: fd.flags,
            fontbbox: fd.fontbbox,
            italicangle: fd.italicangle,
            capheight: fd.capheight,
            xheight: fd.xheight,
            stemv: fd.stemv,
            fontfile: fd.fontfile,
            charset: fd.charset,
            tounicode,
            tounicode_bytes,
          }
          Font::SimpleFont({
            fonttype: simple.fonttype,
            basefont: simple.basefont,
            firstchar: simple.firstchar,
            lastchar: simple.lastchar,
            widths: simple.widths,
            fontdescriptor: Some(updated_fd),
            fontmetrics: simple.fontmetrics,
            encoding: simple.encoding,
          })
        }
        None => {
          let default_fd : FontDescriptor = {
            ascent: 0.0,
            descent: 0.0,
            avgwidth: 0.0,
            maxwidth: 0.0,
            flags: 0,
            fontbbox: (0.0, 0.0, 0.0, 0.0),
            italicangle: 0.0,
            capheight: 0.0,
            xheight: 0.0,
            stemv: 0.0,
            fontfile: None,
            charset: None,
            tounicode,
            tounicode_bytes,
          }
          Font::SimpleFont({
            fonttype: simple.fonttype,
            basefont: simple.basefont,
            firstchar: simple.firstchar,
            lastchar: simple.lastchar,
            widths: simple.widths,
            fontdescriptor: Some(default_fd),
            fontmetrics: simple.fontmetrics,
            encoding: simple.encoding,
          })
        }
      }
    Font::CIDKeyedFont(name, composite, encoding) => {
      let updated_cid_fd : FontDescriptor = {
        ascent: composite.cid_fontdescriptor.ascent,
        descent: composite.cid_fontdescriptor.descent,
        avgwidth: composite.cid_fontdescriptor.avgwidth,
        maxwidth: composite.cid_fontdescriptor.maxwidth,
        flags: composite.cid_fontdescriptor.flags,
        fontbbox: composite.cid_fontdescriptor.fontbbox,
        italicangle: composite.cid_fontdescriptor.italicangle,
        capheight: composite.cid_fontdescriptor.capheight,
        xheight: composite.cid_fontdescriptor.xheight,
        stemv: composite.cid_fontdescriptor.stemv,
        fontfile: composite.cid_fontdescriptor.fontfile,
        charset: composite.cid_fontdescriptor.charset,
        tounicode,
        tounicode_bytes,
      }
      let updated_composite : CompositeCIDFont = {
        cid_system_info: composite.cid_system_info,
        cid_basefont: composite.cid_basefont,
        cid_fontdescriptor: updated_cid_fd,
        cid_widths: composite.cid_widths,
        cid_default_width: composite.cid_default_width,
      }
      Font::CIDKeyedFont(name, updated_composite, encoding)
    }
    other => other
  }
}

///|
pub fn find_tounicode(font : Font) -> Map[Int, String]? {
  match font {
    Font::SimpleFont(simple) =>
      match simple.fontdescriptor {
        Some(fd) => fd.tounicode
        None => None
      }
    Font::CIDKeyedFont(_, composite, _) =>
      composite.cid_fontdescriptor.tounicode
    _ => None
  }
}

///|
pub fn find_tounicode_bytes(font : Font) -> Map[String, String]? {
  match font {
    Font::SimpleFont(simple) =>
      match simple.fontdescriptor {
        Some(fd) => fd.tounicode_bytes
        None => None
      }
    Font::CIDKeyedFont(_, composite, _) =>
      composite.cid_fontdescriptor.tounicode_bytes
    _ => None
  }
}

///|
pub fn read_font(pdf : @pdf.Pdf, fontdict : @pdf.PdfObject) -> Font raise {
  let without_tounicode = if is_standard14font(pdf, fontdict) {
    read_standard14font(pdf, fontdict)
  } else if is_simple_font(pdf, fontdict) {
    read_simple_font(pdf, fontdict)
  } else if is_cidkeyed_font(pdf, fontdict) {
    read_cidkeyed_font(pdf, fontdict)
  } else {
    raise @pdf.PdfError::Msg("Unknown font type")
  }
  add_tounicode(pdf, without_tounicode, fontdict)
}
