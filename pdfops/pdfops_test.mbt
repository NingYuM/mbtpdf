///|
test "string_of_ops renders basic operators" {
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::Opw(2.0),
    @pdfops.Op::Opq,
    @pdfops.Op::OpQ,
  ])
  assert_true(rendered.contains("w"))
  assert_true(rendered.contains("q"))
  assert_true(rendered.contains("Q"))
}

///|
test "stream_of_ops builds a stream" {
  let stream = @pdfops.stream_of_ops([@pdfops.Op::Opq, @pdfops.Op::OpQ])
  match stream {
    @pdf.PdfObject::Stream(r) => {
      let (dict, contents) = r.val
      match @pdf.lookup_direct(@pdf.empty(), "/Length", dict) {
        Some(@pdf.PdfObject::Integer(length)) => assert_true(length > 0)
        _ => fail("expected /Length")
      }
      match contents {
        @pdf.Stream::Got(bytes) => {
          let text = @pdfio.string_of_bytes(bytes)
          assert_true(text.contains("q"))
          assert_true(text.contains("Q"))
        }
        _ => fail("expected stream bytes")
      }
    }
    _ => fail("expected stream object")
  }
}

///|
test "components resolves color spaces" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    (
      "/ColorSpace",
      @pdf.PdfObject::Dictionary([
        ("/MyCS", @pdf.PdfObject::Name("/DeviceGray")),
      ]),
    ),
  ])
  assert_eq(
    @pdfops.components(pdf, resources, @pdf.PdfObject::Name("/DeviceRGB")),
    3,
  )
  assert_eq(
    @pdfops.components(pdf, resources, @pdf.PdfObject::Name("/MyCS")),
    1,
  )
  assert_eq(
    @pdfops.components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Pattern"),
        @pdf.PdfObject::Name("/DeviceRGB"),
      ]),
    ),
    3,
  )
  assert_eq(
    @pdfops.components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/ICCBased"),
        @pdf.PdfObject::Dictionary([("/N", @pdf.PdfObject::Integer(4))]),
      ]),
    ),
    4,
  )
  assert_eq(
    @pdfops.components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/DeviceN"),
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Name("/A"),
          @pdf.PdfObject::Name("/B"),
        ]),
      ]),
    ),
    2,
  )
  assert_eq(
    @pdfops.components(
      pdf,
      resources,
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/Separation"),
        @pdf.PdfObject::Name("/Spot"),
        @pdf.PdfObject::Name("/DeviceRGB"),
        @pdf.PdfObject::Dictionary([]),
      ]),
    ),
    1,
  )
  let pattern_err : Result[Int, Error] = try? @pdfops.components(
    pdf,
    resources,
    @pdf.PdfObject::Name("/Pattern"),
  )
  assert_true(pattern_err is Err(_))
}

///|
test "parse_single_stream reads basic ops" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_string("1 w q 0 0 m 10 0 l S Q")
  let ops = @pdfops.parse_single_stream(pdf, resources, data)
  match ops[0] {
    @pdfops.Op::Opw(value) => assert_eq(value, 1.0)
    _ => fail("expected Opw")
  }
  match ops[1] {
    @pdfops.Op::Opq => ()
    _ => fail("expected Opq")
  }
  assert_true(ops.exists(fn(op) { op is @pdfops.Op::OpS }))
}

///|
test "parse_operators roundtrips stream_of_ops" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let ops_in = [@pdfops.Op::Opq, @pdfops.Op::Opw(2.0), @pdfops.Op::OpQ]
  let stream = @pdfops.stream_of_ops(ops_in)
  let ops = @pdfops.parse_operators(pdf, resources, [stream])
  assert_true(ops.length() >= 3)
  match ops[0] {
    @pdfops.Op::Opq => ()
    _ => fail("expected Opq")
  }
  match ops[1] {
    @pdfops.Op::Opw(value) => assert_eq(value, 2.0)
    _ => fail("expected Opw")
  }
  match ops[2] {
    @pdfops.Op::OpQ => ()
    _ => fail("expected OpQ")
  }
}

///|
test "parse_stream concatenates multiple streams" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let ops = @pdfops.parse_stream(pdf, resources, [
    @pdfio.bytes_of_string("q"),
    @pdfio.bytes_of_string("Q"),
  ])
  assert_true(ops.length() >= 2)
  match ops[0] {
    @pdfops.Op::Opq => ()
    _ => fail("expected Opq")
  }
  match ops[1] {
    @pdfops.Op::OpQ => ()
    _ => fail("expected OpQ")
  }
}

///|
test "parse_operators handles diverse ops" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::Opw(2.0),
    @pdfops.Op::OpJ(1),
    @pdfops.Op::Opj(2),
    @pdfops.Op::OpM(10.0),
    @pdfops.Op::Opd([1.0, 2.0], 0.5),
    @pdfops.Op::Opri("/RelativeColorimetric"),
    @pdfops.Op::Opi(1),
    @pdfops.Op::Opgs("/GS1"),
    @pdfops.Op::Opq,
    @pdfops.Op::OpQ,
    @pdfops.Op::Opcm(@pdftransform.TransformMatrix::{
      a: 1.0,
      b: 0.0,
      c: 0.0,
      d: 1.0,
      e: 10.0,
      f: 20.0,
    }),
    @pdfops.Op::Opm(10.0, 20.0),
    @pdfops.Op::Opl(30.0, 40.0),
    @pdfops.Op::Opc(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    @pdfops.Op::Opv(1.0, 2.0, 3.0, 4.0),
    @pdfops.Op::Opy(1.0, 2.0, 3.0, 4.0),
    @pdfops.Op::Oph,
    @pdfops.Op::Opre(0.1, 0.2, 0.3, 0.4),
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
    @pdfops.Op::OpTz(120.0),
    @pdfops.Op::OpTL(14.0),
    @pdfops.Op::OpTf("/F1", 12.0),
    @pdfops.Op::OpTr(1),
    @pdfops.Op::OpTs(3.0),
    @pdfops.Op::OpTd(10.0, 20.0),
    @pdfops.Op::OpTD(10.0, 20.0),
    @pdfops.Op::OpTm(@pdftransform.TransformMatrix::{
      a: 1.0,
      b: 0.0,
      c: 0.0,
      d: 1.0,
      e: 0.0,
      f: 0.0,
    }),
    @pdfops.Op::OpTStar,
    @pdfops.Op::OpTj("Hello"),
    @pdfops.Op::OpTJ(
      @pdf.PdfObject::Array([
        @pdf.PdfObject::String("A"),
        @pdf.PdfObject::Integer(-120),
        @pdf.PdfObject::String("B"),
      ]),
    ),
    @pdfops.Op::OpSingleQuote("World"),
    @pdfops.Op::OpDoubleQuote(1.0, 2.0, "Quote"),
    @pdfops.Op::Opd0(0.0, 1.0),
    @pdfops.Op::Opd1(0.0, 0.0, 1.0, 1.0, 2.0, 2.0),
    @pdfops.Op::OpCS("/DeviceRGB"),
    @pdfops.Op::Opcs("/DeviceCMYK"),
    @pdfops.Op::OpSC([0.1, 0.2, 0.3]),
    @pdfops.Op::Opsc([0.1, 0.2, 0.3]),
    @pdfops.Op::OpSCN([0.2, 0.4, 0.6]),
    @pdfops.Op::Opscn([0.2, 0.4, 0.6]),
    @pdfops.Op::OpSCNName("/Pattern", [0.1]),
    @pdfops.Op::OpscnName("/Pattern", [0.2]),
    @pdfops.Op::OpG(0.5),
    @pdfops.Op::Opg(0.6),
    @pdfops.Op::OpRG(0.1, 0.2, 0.3),
    @pdfops.Op::Oprg(0.4, 0.5, 0.6),
    @pdfops.Op::OpK(0.1, 0.2, 0.3, 0.4),
    @pdfops.Op::Opk(0.2, 0.3, 0.4, 0.5),
    @pdfops.Op::Opsh("/Sh1"),
    @pdfops.Op::OpDo("/X1"),
    @pdfops.Op::OpMP("/Tag"),
    @pdfops.Op::OpDP(
      "/Tag",
      @pdf.PdfObject::Dictionary([("/K", @pdf.PdfObject::Integer(1))]),
    ),
    @pdfops.Op::OpBMC("/Span"),
    @pdfops.Op::OpBDC(
      "/Span",
      @pdf.PdfObject::Dictionary([("/Lang", @pdf.PdfObject::String("en"))]),
    ),
    @pdfops.Op::OpEMC,
    @pdfops.Op::OpBX,
    @pdfops.Op::OpEX,
  ]
  let rendered = @pdfops.string_of_ops(ops)
  assert_true(rendered.contains("TJ"))
  let stream = @pdfops.stream_of_ops(ops)
  let parsed = @pdfops.parse_operators(pdf, resources, [stream])
  assert_true(
    parsed.exists(op => match op {
      @pdfops.Op::OpTJ(_) => true
      _ => false
    }),
  )
  assert_true(
    parsed.exists(op => match op {
      @pdfops.Op::OpSCNName(_, _) => true
      _ => false
    }),
  )
  assert_true(
    parsed.exists(op => match op {
      @pdfops.Op::OpBDC(_, _) => true
      _ => false
    }),
  )
  assert_true(
    parsed.exists(op => match op {
      @pdfops.Op::OpDo(_) => true
      _ => false
    }),
  )
}

///|
test "string_of_ops renders inline image" {
  let inline_dict = @pdf.PdfObject::Dictionary([
    ("/W", @pdf.PdfObject::Integer(1)),
    ("/H", @pdf.PdfObject::Integer(1)),
    ("/BPC", @pdf.PdfObject::Integer(8)),
    ("/CS", @pdf.PdfObject::Name("/DeviceGray")),
  ])
  let inline_data = @pdfio.bytes_of_list([128])
  let rendered = @pdfops.string_of_ops([
    @pdfops.Op::InlineImage((inline_dict, None, inline_data)),
  ])
  assert_true(rendered.contains("BI"))
  assert_true(rendered.contains("ID"))
  assert_true(rendered.contains("EI"))
}

///|
test "parse_single_stream returns OpUnknown for bad ops" {
  let pdf = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_string("1 2 ZZ")
  let ops = @pdfops.parse_single_stream(pdf, resources, data)
  assert_true(
    ops.exists(op => match op {
      @pdfops.Op::OpUnknown(_) => true
      _ => false
    }),
  )
}
