///|
test "string_of_ops handles comments and inline filters" {
  let old = @pdfops.write_comments.val
  @pdfops.write_comments.val = true
  let dict_filter_array = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Array([@pdf.PdfObject::Name("/ASCII85Decode")])),
  ])
  let dict_filter_name = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/FlateDecode")),
  ])
  let bytes = @pdfio.bytes_of_list([0x61, 0x62])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::OpComment("note"),
    @pdfops.Op::InlineImage((dict_filter_array, None, bytes)),
    @pdfops.Op::InlineImage((dict_filter_name, None, bytes)),
    @pdfops.Op::Opq,
  ])
  @pdfops.write_comments.val = old
  assert_true(rendered.contains("BI"))
  assert_true(rendered.contains("EI"))
  assert_true(rendered.contains("q"))
}

///|
test "string_of_op delegates to string_of_ops" {
  let rendered = @pdfops.string_of_op(@pdfops.Op::OpQ)
  assert_true(rendered.contains("Q"))
}

///|
test "parse_single_stream ignores comments and yields unknown" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_string("%c\ntrue false ZZ q Q")
  let ops = @pdfops.parse_single_stream(pdf, resources, data)
  assert_true(
    ops.exists(op => match op {
      @pdfops.Op::OpUnknown(_) => true
      _ => false
    }),
  )
  assert_true(
    ops.exists(op => match op {
      @pdfops.Op::Opq => true
      _ => false
    }),
  )
  assert_true(
    ops.exists(op => match op {
      @pdfops.Op::OpQ => true
      _ => false
    }),
  )
}

///|
test "components handles extra branches and errors" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  assert_eq(
    @pdfops.components(pdf, resources, @pdf.PdfObject::Name("/CalCMYK")),
    4,
  )
  assert_eq(
    @pdfops.components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Lab"),
        @pdf.PdfObject::Dictionary([]),
      ]),
    ),
    3,
  )
  assert_eq(
    @pdfops.components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Indexed"),
        @pdf.PdfObject::Name("/DeviceRGB"),
        @pdf.PdfObject::Integer(0),
        @pdf.PdfObject::String(""),
      ]),
    ),
    1,
  )
  let missing_dict : Result[Int, Error] = try? @pdfops.components(
    pdf,
    resources,
    @pdf.PdfObject::Name("/MyCS"),
  )
  assert_true(missing_dict is Err(_))
  let resources_empty = @pdf.PdfObject::Dictionary([
    ("/ColorSpace", @pdf.PdfObject::Dictionary([])),
  ])
  let missing_entry : Result[Int, Error] = try? @pdfops.components(
    pdf,
    resources_empty,
    @pdf.PdfObject::Name("/MyCS"),
  )
  assert_true(missing_entry is Err(_))
  let bad_icc : Result[Int, Error] = try? @pdfops.components(
    pdf,
    resources,
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/ICCBased"),
      @pdf.PdfObject::Dictionary([]),
    ]),
  )
  assert_true(bad_icc is Err(_))
  let bad_device_n : Result[Int, Error] = try? @pdfops.components(
    pdf,
    resources,
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Name("/DeviceN"),
      @pdf.PdfObject::Name("/DeviceRGB"),
    ]),
  )
  assert_true(bad_device_n is Err(_))
  let bad_other : Result[Int, Error] = try? @pdfops.components(
    pdf,
    resources,
    @pdf.PdfObject::Integer(1),
  )
  assert_true(bad_other is Err(_))
}

///|
test "string_of_ops covers operator variants" {
  let ops = [
    @pdfops.Op::Opw(1.5),
    @pdfops.Op::OpJ(1),
    @pdfops.Op::Opj(2),
    @pdfops.Op::OpM(3.0),
    @pdfops.Op::Opd([1.0, 2.0], 0.5),
    @pdfops.Op::Opri("/RelColorimetric"),
    @pdfops.Op::Opi(10),
    @pdfops.Op::Opgs("/GS1"),
    @pdfops.Op::Opq,
    @pdfops.Op::OpQ,
    @pdfops.Op::Opcm(@pdftransform.i_matrix),
    @pdfops.Op::Opm(0.0, 1.0),
    @pdfops.Op::Opl(1.0, 2.0),
    @pdfops.Op::Opc(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    @pdfops.Op::Opv(1.0, 2.0, 3.0, 4.0),
    @pdfops.Op::Opy(1.0, 2.0, 3.0, 4.0),
    @pdfops.Op::Oph,
    @pdfops.Op::Opre(0.0, 0.0, 10.0, 10.0),
    @pdfops.Op::OpS,
    @pdfops.Op::Ops,
    @pdfops.Op::Opf,
    @pdfops.Op::OpF,
    @pdfops.Op::OpfStar,
    @pdfops.Op::OpB,
    @pdfops.Op::OpBStar,
    @pdfops.Op::Opb,
    @pdfops.Op::OpbStar,
    @pdfops.Op::Opn,
    @pdfops.Op::OpW,
    @pdfops.Op::OpWStar,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpET,
    @pdfops.Op::OpTc(1.0),
    @pdfops.Op::OpTw(2.0),
    @pdfops.Op::OpTz(100.0),
    @pdfops.Op::OpTL(12.0),
    @pdfops.Op::OpTf("/F1", 10.0),
    @pdfops.Op::OpTr(1),
    @pdfops.Op::OpTs(0.5),
    @pdfops.Op::OpTd(10.0, 20.0),
    @pdfops.Op::OpTD(5.0, 6.0),
    @pdfops.Op::OpTm(@pdftransform.i_matrix),
    @pdfops.Op::OpTStar,
    @pdfops.Op::OpTj("Hi"),
    @pdfops.Op::OpTJ(
      @pdf.PdfObject::Array([
        @pdf.PdfObject::String("A"),
        @pdf.PdfObject::Real(-10.0),
        @pdf.PdfObject::String("B"),
      ]),
    ),
    @pdfops.Op::OpSingleQuote("A"),
    @pdfops.Op::OpDoubleQuote(0.1, 0.2, "B"),
    @pdfops.Op::Opd0(0.0, 0.0),
    @pdfops.Op::Opd1(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    @pdfops.Op::OpCS("/DeviceRGB"),
    @pdfops.Op::Opcs("/DeviceCMYK"),
    @pdfops.Op::OpSC([1.0, 0.0, 0.0]),
    @pdfops.Op::Opsc([0.1, 0.2, 0.3]),
    @pdfops.Op::OpSCN([0.1, 0.2]),
    @pdfops.Op::Opscn([0.3, 0.4]),
    @pdfops.Op::OpSCNName("/Pattern", [0.1, 0.2]),
    @pdfops.Op::OpscnName("/Pattern", [0.3]),
    @pdfops.Op::OpG(0.0),
    @pdfops.Op::Opg(0.5),
    @pdfops.Op::OpRG(1.0, 0.0, 0.0),
    @pdfops.Op::Oprg(0.0, 1.0, 0.0),
    @pdfops.Op::OpK(0.0, 0.0, 0.0, 1.0),
    @pdfops.Op::Opk(0.0, 0.0, 0.0, 0.0),
    @pdfops.Op::Opsh("/Sh1"),
    @pdfops.Op::OpDo("/X1"),
    @pdfops.Op::OpMP("/Tag"),
    @pdfops.Op::OpDP("/Tag", @pdf.PdfObject::Dictionary([])),
    @pdfops.Op::OpBMC("/Span"),
    @pdfops.Op::OpBDC("/Span", @pdf.PdfObject::Dictionary([])),
    @pdfops.Op::OpEMC,
    @pdfops.Op::OpBX,
    @pdfops.Op::OpEX,
    @pdfops.Op::OpUnknown("ZZ"),
    @pdfops.Op::OpComment("note"),
  ]
  let rendered = @pdfops.string_of_ops(ops)
  assert_true(rendered.contains("q"))
  assert_true(rendered.contains("cm"))
  assert_true(rendered.contains("TJ"))
  assert_true(rendered.contains("BDC"))
}
