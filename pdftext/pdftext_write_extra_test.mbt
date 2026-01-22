///|
test "write_encoding covers mac and custom encodings" {
  let pdf = @pdf.empty()
  let macroman_encoding = @pdftext.read_encoding(
    pdf,
    font_with_encoding_name("/MacRomanEncoding"),
  )
  let macroman = @pdftext.write_encoding(pdf, macroman_encoding)
  match (@pdf.lookup_obj(pdf, macroman) : @pdf.PdfObject) {
    Name("/MacRomanEncoding") => ()
    _ => fail("expected /MacRomanEncoding")
  }
  let macexpert_encoding = @pdftext.read_encoding(
    pdf,
    font_with_encoding_name("/MacExpertEncoding"),
  )
  let macexpert = @pdftext.write_encoding(pdf, macexpert_encoding)
  match (@pdf.lookup_obj(pdf, macexpert) : @pdf.PdfObject) {
    Name("/MacExpertEncoding") => ()
    _ => fail("expected /MacExpertEncoding")
  }
  let filled_encoding = @pdftext.read_encoding(
    pdf,
    truetype_font_with_encoding_dict(),
  )
  let filled = @pdftext.write_encoding(pdf, filled_encoding)
  match (@pdf.lookup_obj(pdf, filled) : @pdf.PdfObject) {
    Name("/MacRomanEncoding") => ()
    _ => fail("expected filled encoding to reuse inner")
  }
  let custom_encoding = @pdftext.read_encoding(
    pdf,
    embedded_font_with_custom_encoding(),
  )
  let custom = @pdftext.write_encoding(pdf, custom_encoding)
  match (@pdf.lookup_obj(pdf, custom) : @pdf.PdfObject) {
    Dictionary(_) as dict => {
      assert_true(@pdf.lookup_direct(pdf, "/BaseEncoding", dict) is None)
      match (@pdf.lookup_direct(pdf, "/Differences", dict) : @pdf.PdfObject?) {
        Some(Array(values)) => assert_true(values.length() > 0)
        _ => fail("expected differences array")
      }
    }
    _ => fail("expected custom encoding dictionary")
  }
  let implicit_encoding = @pdftext.read_encoding(
    pdf,
    @pdf.PdfObject::Dictionary([
      ("/Subtype", Name("/Type1")),
      ("/BaseFont", Name("/CustomFont")),
    ]),
  )
  let implicit_result : Result[Int, Error] = try? @pdftext.write_encoding(
    pdf, implicit_encoding,
  )
  assert_true(implicit_result is Err(_))
}

///|
test "write_font errors on unsupported fonts" {
  let pdf = @pdf.empty()
  let simple_font = @pdftext.read_font(
    pdf,
    @pdf.PdfObject::Dictionary([
      ("/Subtype", Name("/Type1")),
      ("/BaseFont", Name("/CustomFont")),
    ]),
  )
  let simple_result : Result[Int, Error] = try? @pdftext.write_font(
    pdf, simple_font,
  )
  assert_true(simple_result is Err(_))
  let cid_font = @pdftext.read_font(pdf, cid_font_dict("/Identity-H"))
  let cid_result : Result[Int, Error] = try? @pdftext.write_font(pdf, cid_font)
  assert_true(cid_result is Err(_))
}

///|
fn add_font_descriptor(pdf : @pdf.Pdf, fontfile_obj : Int?) -> Int {
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Type", Name("/FontDescriptor")),
    ("/Ascent", Integer(700)),
    ("/Descent", Integer(-200)),
    ("/AvgWidth", Integer(500)),
    ("/MaxWidth", Integer(1000)),
  ]
  match fontfile_obj {
    Some(objnum) => entries.push(("/FontFile2", Indirect(objnum)))
    None => ()
  }
  @pdf.addobj(pdf, Dictionary(entries))
}

///|
fn add_fontfile_stream(pdf : @pdf.Pdf) -> Int {
  let data = @pdfio.bytes_of_string("ttf")
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(@pdfio.bytes_size(data)))])
  @pdf.addobj(pdf, Stream(Ref::new((dict, @pdf.Stream::Got(data)))))
}

///|
fn add_tounicode_stream(pdf : @pdf.Pdf) -> Int {
  let bytes = @pdftext.tounicode_map(33, ["A"])
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(@pdfio.bytes_size(bytes)))])
  @pdf.addobj(pdf, Stream(Ref::new((dict, @pdf.Stream::Got(bytes)))))
}

///|
fn truetype_font_dict(
  font_descriptor : Int?,
  encoding_name : String,
  tounicode_obj : Int?,
) -> @pdf.PdfObject {
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Subtype", Name("/TrueType")),
    ("/BaseFont", Name("/DummyTTF")),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(1)),
    ("/Widths", Array([Integer(500), Integer(600)])),
    ("/Encoding", Name(encoding_name)),
  ]
  match font_descriptor {
    Some(objnum) => entries.push(("/FontDescriptor", Indirect(objnum)))
    None => ()
  }
  match tounicode_obj {
    Some(objnum) => entries.push(("/ToUnicode", Indirect(objnum)))
    None => ()
  }
  Dictionary(entries)
}

///|
fn type3_font_dict_extra(font_descriptor : Int?) -> @pdf.PdfObject {
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Subtype", Name("/Type3")),
    ("/BaseFont", Name("/DummyType3")),
    ("/FontBBox", Array([Real(0.0), Real(0.0), Real(0.0), Real(0.0)])),
    (
      "/FontMatrix",
      Array([Real(1.0), Real(0.0), Real(0.0), Real(1.0), Real(0.0), Real(0.0)]),
    ),
    ("/CharProcs", Dictionary([("/A", Null)])),
    ("/Resources", Dictionary([])),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(0)),
    ("/Widths", Array([Integer(0)])),
  ]
  match font_descriptor {
    Some(objnum) => entries.push(("/FontDescriptor", Indirect(objnum)))
    None => ()
  }
  Dictionary(entries)
}

///|
test "write_font writes type3 font with encoding" {
  let pdf = @pdf.empty()
  let fd = add_font_descriptor(pdf, None)
  let font_dict = type3_font_dict_extra(Some(fd))
  let font = @pdftext.read_font(pdf, font_dict)
  let objnum = @pdftext.write_font(pdf, font)
  match (@pdf.lookup_obj(pdf, objnum) : @pdf.PdfObject) {
    Dictionary(_) as dict =>
      match (@pdf.lookup_direct(pdf, "/Subtype", dict) : @pdf.PdfObject?) {
        Some(Name("/Type3")) => ()
        _ => fail("expected Type3 subtype")
      }
    _ => fail("expected Type3 font dictionary")
  }
}

///|
test "write_font writes truetype with tounicode" {
  let pdf = @pdf.empty()
  let fontfile = add_fontfile_stream(pdf)
  let fd = add_font_descriptor(pdf, Some(fontfile))
  let tounicode = add_tounicode_stream(pdf)
  let font_dict = truetype_font_dict(
    Some(fd),
    "/WinAnsiEncoding",
    Some(tounicode),
  )
  let font = @pdftext.read_font(pdf, font_dict)
  let objnum = @pdftext.write_font(objnum=50, pdf, font)
  assert_eq(objnum, 50)
  match (@pdf.lookup_obj(pdf, objnum) : @pdf.PdfObject) {
    Dictionary(_) as dict =>
      assert_true(@pdf.lookup_direct(pdf, "/ToUnicode", dict) is Some(_))
    _ => fail("expected truetype dictionary")
  }
}

///|
test "write_font writes truetype with encoding entry" {
  let pdf = @pdf.empty()
  let fontfile = add_fontfile_stream(pdf)
  let fd = add_font_descriptor(pdf, Some(fontfile))
  let font_dict = truetype_font_dict(Some(fd), "/MacRomanEncoding", None)
  let font = @pdftext.read_font(pdf, font_dict)
  let objnum = @pdftext.write_font(pdf, font)
  match (@pdf.lookup_obj(pdf, objnum) : @pdf.PdfObject) {
    Dictionary(_) as dict =>
      assert_true(@pdf.lookup_direct(pdf, "/Encoding", dict) is Some(_))
    _ => fail("expected truetype dictionary")
  }
}

///|
test "write_font errors when truetype descriptor missing" {
  let pdf = @pdf.empty()
  let font_dict = truetype_font_dict(None, "/WinAnsiEncoding", None)
  let font = @pdftext.read_font(pdf, font_dict)
  let result : Result[Int, Error] = try? @pdftext.write_font(pdf, font)
  assert_true(result is Err(_))
}

///|
test "write_font errors when truetype fontfile missing" {
  let pdf = @pdf.empty()
  let fd = add_font_descriptor(pdf, None)
  let font_dict = truetype_font_dict(Some(fd), "/WinAnsiEncoding", None)
  let font = @pdftext.read_font(pdf, font_dict)
  let result : Result[Int, Error] = try? @pdftext.write_font(pdf, font)
  assert_true(result is Err(_))
}
