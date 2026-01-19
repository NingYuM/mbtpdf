///|
fn type3_bbox() -> @pdf.PdfObject {
  @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(10.0),
  ])
}

///|
fn type3_matrix_ok() -> @pdf.PdfObject {
  @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(1.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(1.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
  ])
}

///|
fn type3_charprocs_ok() -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([("/A", @pdf.PdfObject::Null)])
}

///|
fn type3_font_base(
  matrix : @pdf.PdfObject,
  charprocs : @pdf.PdfObject,
) -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([
    ("/FontBBox", type3_bbox()),
    ("/FontMatrix", matrix),
    ("/CharProcs", charprocs),
  ])
}

///|
test "read_type3_data validates matrix and charprocs" {
  let pdf = @pdf.empty()
  let bad_len_matrix = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(1.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(1.0),
    @pdf.PdfObject::Real(0.0),
  ])
  let bad_len_font = type3_font_base(bad_len_matrix, type3_charprocs_ok())
  let bad_len_result : Result[@pdftext.Type3Glyphs, Error] = try? @pdftext.read_type3_data(
    pdf, bad_len_font,
  )
  assert_true(bad_len_result is Err(_))
  let bad_type_font = type3_font_base(
    @pdf.PdfObject::Name("/Bad"),
    type3_charprocs_ok(),
  )
  let bad_type_result : Result[@pdftext.Type3Glyphs, Error] = try? @pdftext.read_type3_data(
    pdf, bad_type_font,
  )
  assert_true(bad_type_result is Err(_))
  let bad_charprocs_font = type3_font_base(
    type3_matrix_ok(),
    @pdf.PdfObject::Name("/Bad"),
  )
  let bad_charprocs_result : Result[@pdftext.Type3Glyphs, Error] = try? @pdftext.read_type3_data(
    pdf, bad_charprocs_font,
  )
  assert_true(bad_charprocs_result is Err(_))
  let with_resources = @pdf.add_dict_entry(
    type3_font_base(type3_matrix_ok(), type3_charprocs_ok()),
    "/Resources",
    @pdf.PdfObject::Dictionary([("/ProcSet", @pdf.PdfObject::Array([]))]),
  )
  let good = @pdftext.read_type3_data(pdf, with_resources)
  match good.type3_resources {
    @pdf.PdfObject::Dictionary(_) => ()
    _ => fail("expected type3 resources")
  }
}

///|
test "simple_fonttype_of_string and read_basefont defaults" {
  let pdf = @pdf.empty()
  let font = @pdf.PdfObject::Dictionary([])
  assert_true(@pdftext.simple_fonttype_of_string(pdf, font, "/Unknown") is None)
  assert_eq(@pdftext.read_basefont(pdf, font), "")
}

///|
test "parse_charset handles invalid escapes" {
  let valid = @pdftext.parse_charset("/A/B/")
  assert_eq(valid.length(), 2)
  assert_eq(valid[0], "/A")
  assert_eq(valid[1], "/B")
  let invalid = @pdftext.parse_charset("/A#4")
  assert_eq(invalid.length(), 0)
}

///|
test "read_fontdescriptor reads font file references" {
  let pdf = @pdf.empty()
  let obj1 = @pdf.addobj(pdf, @pdf.PdfObject::Null)
  let obj2 = @pdf.addobj(pdf, @pdf.PdfObject::Null)
  let obj3 = @pdf.addobj(pdf, @pdf.PdfObject::Null)
  let font1 = @pdf.PdfObject::Dictionary([
    (
      "/FontDescriptor",
      @pdf.PdfObject::Dictionary([("/FontFile", @pdf.PdfObject::Indirect(obj1))]),
    ),
  ])
  match @pdftext.read_fontdescriptor(pdf, font1) {
    Some(desc) =>
      match desc.fontfile {
        Some(@pdftext.FontFile::FontFile(num)) => assert_eq(num, obj1)
        _ => fail("expected FontFile")
      }
    None => fail("expected descriptor")
  }
  let font2 = @pdf.PdfObject::Dictionary([
    (
      "/FontDescriptor",
      @pdf.PdfObject::Dictionary([
        ("/FontFile2", @pdf.PdfObject::Indirect(obj2)),
      ]),
    ),
  ])
  match @pdftext.read_fontdescriptor(pdf, font2) {
    Some(desc) =>
      match desc.fontfile {
        Some(@pdftext.FontFile::FontFile2(num)) => assert_eq(num, obj2)
        _ => fail("expected FontFile2")
      }
    None => fail("expected descriptor")
  }
  let font3 = @pdf.PdfObject::Dictionary([
    (
      "/FontDescriptor",
      @pdf.PdfObject::Dictionary([
        ("/FontFile3", @pdf.PdfObject::Indirect(obj3)),
      ]),
    ),
  ])
  match @pdftext.read_fontdescriptor(pdf, font3) {
    Some(desc) =>
      match desc.fontfile {
        Some(@pdftext.FontFile::FontFile3(num)) => assert_eq(num, obj3)
        _ => fail("expected FontFile3")
      }
    None => fail("expected descriptor")
  }
}

///|
test "read_metrics validates required keys" {
  let pdf = @pdf.empty()
  let descriptor = @pdf.PdfObject::Dictionary([])
  let missing_first = @pdf.PdfObject::Dictionary([
    ("/FontDescriptor", descriptor),
    ("/LastChar", @pdf.PdfObject::Integer(0)),
    ("/Widths", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(10)])),
  ])
  let missing_first_result : Result[@pdftext.FontMetrics?, Error] = try? @pdftext.read_metrics(
    pdf, missing_first,
  )
  assert_true(missing_first_result is Err(_))
  let bad_first = @pdf.PdfObject::Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", @pdf.PdfObject::Integer(999)),
    ("/LastChar", @pdf.PdfObject::Integer(0)),
    ("/Widths", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(10)])),
  ])
  let bad_first_result : Result[@pdftext.FontMetrics?, Error] = try? @pdftext.read_metrics(
    pdf, bad_first,
  )
  assert_true(bad_first_result is Err(_))
  let missing_last = @pdf.PdfObject::Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", @pdf.PdfObject::Integer(0)),
    ("/Widths", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(10)])),
  ])
  let missing_last_result : Result[@pdftext.FontMetrics?, Error] = try? @pdftext.read_metrics(
    pdf, missing_last,
  )
  assert_true(missing_last_result is Err(_))
  let bad_last = @pdf.PdfObject::Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", @pdf.PdfObject::Integer(0)),
    ("/LastChar", @pdf.PdfObject::Integer(999)),
    ("/Widths", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(10)])),
  ])
  let bad_last_result : Result[@pdftext.FontMetrics?, Error] = try? @pdftext.read_metrics(
    pdf, bad_last,
  )
  assert_true(bad_last_result is Err(_))
  let missing_widths = @pdf.PdfObject::Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", @pdf.PdfObject::Integer(0)),
    ("/LastChar", @pdf.PdfObject::Integer(0)),
  ])
  let missing_widths_result : Result[@pdftext.FontMetrics?, Error] = try? @pdftext.read_metrics(
    pdf, missing_widths,
  )
  assert_true(missing_widths_result is Err(_))
  let bad_widths = @pdf.PdfObject::Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", @pdf.PdfObject::Integer(0)),
    ("/LastChar", @pdf.PdfObject::Integer(1)),
    ("/Widths", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(10)])),
  ])
  let bad_widths_result : Result[@pdftext.FontMetrics?, Error] = try? @pdftext.read_metrics(
    pdf, bad_widths,
  )
  assert_true(bad_widths_result is Err(_))
}

///|
test "read_metrics accepts real widths" {
  let pdf = @pdf.empty()
  let descriptor = @pdf.PdfObject::Dictionary([
    ("/MissingWidth", @pdf.PdfObject::Real(12.5)),
  ])
  let font = @pdf.PdfObject::Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", @pdf.PdfObject::Integer(0)),
    ("/LastChar", @pdf.PdfObject::Integer(0)),
    ("/Widths", @pdf.PdfObject::Array([@pdf.PdfObject::Real(250.5)])),
  ])
  match @pdftext.read_metrics(pdf, font) {
    Some(metrics) => {
      assert_eq(metrics.length(), 256)
      assert_eq(metrics[0], 250.5)
      assert_eq(metrics[1], 12.5)
    }
    None => fail("expected metrics")
  }
}

///|
test "pairs_of_differences rejects malformed inputs" {
  let pdf = @pdf.empty()
  let not_array : Result[@pdftext.Differences, Error] = try? @pdftext.pairs_of_differences(
    pdf,
    @pdf.PdfObject::Name("/Bad"),
  )
  assert_true(not_array is Err(_))
  let bad_array : Result[@pdftext.Differences, Error] = try? @pdftext.pairs_of_differences(
    pdf,
    @pdf.PdfObject::Array([@pdf.PdfObject::Name("/A")]),
  )
  assert_true(bad_array is Err(_))
}

///|
test "is_standard14font rejects non-name basefont" {
  let pdf = @pdf.empty()
  let font = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/BaseFont", @pdf.PdfObject::Integer(1)),
  ])
  assert_true(!@pdftext.is_standard14font(pdf, font))
}
