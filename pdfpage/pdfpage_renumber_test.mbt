///|
fn renumber_resources() -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("/F1", @pdf.PdfObject::Null)])),
    ("/ExtGState", @pdf.PdfObject::Dictionary([("/GS1", @pdf.PdfObject::Null)])),
    (
      "/ColorSpace",
      @pdf.PdfObject::Dictionary([("/CS1", @pdf.PdfObject::Name("/DeviceRGB"))]),
    ),
    ("/Pattern", @pdf.PdfObject::Dictionary([("/P1", @pdf.PdfObject::Null)])),
    ("/Shading", @pdf.PdfObject::Dictionary([("/Sh1", @pdf.PdfObject::Null)])),
    ("/XObject", @pdf.PdfObject::Dictionary([("/X1", @pdf.PdfObject::Null)])),
    (
      "/Properties",
      @pdf.PdfObject::Dictionary([("/Prop1", @pdf.PdfObject::Null)]),
    ),
  ])
}

///|
fn renumber_page(rect : @pdf.PdfObject) -> @pdfpage.Page raise {
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::OpTf("/F1", 12.0),
    @pdfops.Op::Opgs("/GS1"),
    @pdfops.Op::OpCS("/CS1"),
    @pdfops.Op::Opcs("/CS1"),
    @pdfops.Op::OpCS("/CSMissing"),
    @pdfops.Op::Opcs("/CSMissing"),
    @pdfops.Op::OpSCNName("/P1", [0.1]),
    @pdfops.Op::OpscnName("/P1", [0.2]),
    @pdfops.Op::Opsh("/Sh1"),
    @pdfops.Op::OpDo("/X1"),
    @pdfops.Op::OpDP("/Span", @pdf.PdfObject::Name("/Prop1")),
    @pdfops.Op::OpBDC("/Span", @pdf.PdfObject::Name("/Prop1")),
    @pdfops.Op::OpBDC("/Span", @pdf.PdfObject::Name("/PropMissing")),
  ]
  {
    content: [@pdfops.stream_of_ops(ops)],
    mediabox: rect,
    resources: renumber_resources(),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
}

///|
test "renumber_pages returns empty on no pages" {
  let pdf = @pdf.empty()
  let updated = @pdfpage.renumber_pages(pdf, [])
  assert_eq(updated.length(), 0)
}

///|
test "renumber_pages renames resource operators consistently" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let updated = @pdfpage.renumber_pages(pdf, [renumber_page(rect)])
  let renamed = updated[0]
  let ops = @pdfops.parse_operators(pdf, renamed.resources, renamed.content)
  assert_eq(ops.length(), 13)
  match ops[0] {
    @pdfops.Op::OpTf(name, _) => assert_true(name != "/F1")
    _ => fail("expected OpTf")
  }
  match ops[1] {
    @pdfops.Op::Opgs(name) => assert_true(name != "/GS1")
    _ => fail("expected Opgs")
  }
  match ops[2] {
    @pdfops.Op::OpCS(name) => assert_true(name != "/CS1")
    _ => fail("expected OpCS")
  }
  match ops[3] {
    @pdfops.Op::Opcs(name) => assert_true(name != "/CS1")
    _ => fail("expected Opcs")
  }
  match ops[4] {
    @pdfops.Op::OpCS(name) => assert_eq(name, "/CSMissing")
    _ => fail("expected OpCS missing")
  }
  match ops[5] {
    @pdfops.Op::Opcs(name) => assert_eq(name, "/CSMissing")
    _ => fail("expected Opcs missing")
  }
  match ops[6] {
    @pdfops.Op::OpSCNName(name, _) => assert_true(name != "/P1")
    _ => fail("expected OpSCNName")
  }
  match ops[7] {
    @pdfops.Op::OpscnName(name, _) => assert_true(name != "/P1")
    _ => fail("expected OpscnName")
  }
  match ops[8] {
    @pdfops.Op::Opsh(name) => assert_true(name != "/Sh1")
    _ => fail("expected Opsh")
  }
  match ops[9] {
    @pdfops.Op::OpDo(name) => assert_true(name != "/X1")
    _ => fail("expected OpDo")
  }
  match ops[10] {
    @pdfops.Op::OpDP(_, @pdf.PdfObject::Name(name)) =>
      assert_true(name != "/Prop1")
    _ => fail("expected OpDP")
  }
  match ops[11] {
    @pdfops.Op::OpBDC(_, @pdf.PdfObject::Name(name)) =>
      assert_true(name != "/Prop1")
    _ => fail("expected OpBDC renamed")
  }
  match ops[12] {
    @pdfops.Op::OpBDC(_, @pdf.PdfObject::Name(name)) =>
      assert_eq(name, "/PropMissing")
    _ => fail("expected OpBDC missing")
  }
}
