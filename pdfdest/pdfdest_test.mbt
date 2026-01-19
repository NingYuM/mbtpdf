///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "read_destination array" {
  let pdf = @pdf.empty()
  let obj = @pdf.PdfObject::Array([
    @pdf.PdfObject::Indirect(7),
    @pdf.PdfObject::Name("/FitH"),
    @pdf.PdfObject::Real(200.0),
  ])
  let dest = read_destination(pdf, obj)
  match dest {
    Destination::FitH(TargetPage::PageObject(7), Some(top)) =>
      assert_close(top, 200.0)
    _ => fail("expected FitH destination")
  }
}

///|
test "read_destination shallow name" {
  let pdf = @pdf.empty()
  let dest = read_destination(
    pdf,
    @pdf.PdfObject::Name("/Chapter1"),
    shallow=true,
  )
  match dest {
    Destination::NamedDestination("/Chapter1") => ()
    _ => fail("expected NamedDestination")
  }
}

///|
test "pdfobject_of_destination" {
  let dest = Destination::FitR(
    TargetPage::OtherDocPageNumber(3),
    10.0,
    20.0,
    30.0,
    40.0,
  )
  let obj = pdfobject_of_destination(dest)
  match obj {
    @pdf.PdfObject::Array(
      [
        @pdf.PdfObject::Integer(3),
        @pdf.PdfObject::Name("/FitR"),
        @pdf.PdfObject::Real(10.0),
        @pdf.PdfObject::Real(20.0),
        @pdf.PdfObject::Real(30.0),
        @pdf.PdfObject::Real(40.0),
      ]
    ) => ()
    _ => fail("unexpected pdfobject for destination")
  }
}

///|
test "transform_destination translate" {
  let pdf = @pdf.empty()
  let dest = Destination::XYZ(
    TargetPage::PageObject(1),
    Some(10.0),
    Some(20.0),
    Some(1.0),
  )
  let tr = @pdftransform.mktranslate(5.0, -3.0)
  let transformed = transform_destination(pdf, tr, dest)
  match transformed {
    Destination::XYZ(
      TargetPage::PageObject(1),
      Some(left),
      Some(top),
      Some(zoom)
    ) => {
      assert_close(left, 15.0)
      assert_close(top, 17.0)
      assert_close(zoom, 1.0)
    }
    _ => fail("expected transformed XYZ destination")
  }
}

///|
test "read_destination from dictionary /D" {
  let pdf = @pdf.empty()
  let inner = @pdf.PdfObject::Array([
    @pdf.PdfObject::Integer(0),
    @pdf.PdfObject::Name("/XYZ"),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(20.0),
    @pdf.PdfObject::Real(1.0),
  ])
  let obj = @pdf.PdfObject::Dictionary([("/D", inner)])
  let dest = read_destination(pdf, obj)
  match dest {
    Destination::XYZ(
      TargetPage::OtherDocPageNumber(0),
      Some(left),
      Some(top),
      Some(zoom)
    ) => {
      assert_close(left, 10.0)
      assert_close(top, 20.0)
      assert_close(zoom, 1.0)
    }
    _ => fail("expected XYZ destination")
  }
}

///|
test "read_destination resolves named dests in catalog" {
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let page = @pdfpage.custompage(rect)
  let (pdf0, pageroot) = @pdfpage.add_pagetree([page], @pdf.empty())
  let pdf = @pdfpage.add_root(pageroot, [], pdf0)
  let refs = @pdf.page_reference_numbers(pdf)
  let dest = @pdf.PdfObject::Array([
    @pdf.PdfObject::Indirect(refs[0]),
    @pdf.PdfObject::Name("/Fit"),
  ])
  let dests = @pdf.PdfObject::Dictionary([("/Chapter1", dest)])
  let root_obj = @pdf.lookup_obj(pdf, pdf.root)
  let updated_root = @pdf.add_dict_entry(root_obj, "/Dests", dests)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_root))
  let resolved = read_destination(pdf, @pdf.PdfObject::Name("/Chapter1"))
  match resolved {
    Destination::Fit(TargetPage::PageObject(n)) => assert_eq(n, refs[0])
    _ => fail("expected Fit destination")
  }
}
