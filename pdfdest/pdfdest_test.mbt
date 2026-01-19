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
test "transform_destination clips FitV/FitBH" {
  let pdf = @pdf.empty()
  let tr = @pdftransform.i_matrix
  let fitv = transform_destination(
    pdf,
    tr,
    Destination::FitV(TargetPage::PageObject(1), Some(40000.0)),
  )
  match fitv {
    Destination::FitV(_, Some(left)) => assert_close(left, 32768.0)
    _ => fail("expected FitV clipped")
  }
  let fitbh = transform_destination(
    pdf,
    tr,
    Destination::FitBH(TargetPage::PageObject(1), Some(-40000.0)),
  )
  match fitbh {
    Destination::FitBH(_, Some(top)) => assert_close(top, -32768.0)
    _ => fail("expected FitBH clipped")
  }
}

///|
test "transform_destination updates GoTo action" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let refs = @pdf.page_reference_numbers(pdf)
  let action = @pdf.PdfObject::Dictionary([
    ("/S", @pdf.PdfObject::Name("/GoTo")),
    (
      "/D",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Indirect(refs[0]),
        @pdf.PdfObject::Name("/XYZ"),
        @pdf.PdfObject::Real(10.0),
        @pdf.PdfObject::Real(20.0),
        @pdf.PdfObject::Null,
      ]),
    ),
  ])
  let tr = @pdftransform.mktranslate(5.0, -3.0)
  let updated = transform_destination(pdf, tr, Destination::Action(action))
  match updated {
    Destination::Action(dict) =>
      match @pdf.lookup_direct(pdf, "/D", dict) {
        Some(
          @pdf.PdfObject::Array([_, @pdf.PdfObject::Name("/XYZ"), left, top, _])
        ) => {
          assert_close(@pdf.getnum(pdf, left), 15.0)
          assert_close(@pdf.getnum(pdf, top), 17.0)
        }
        _ => fail("expected updated action destination")
      }
    _ => fail("expected action destination")
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
test "read_destination array Fit and FitR" {
  let pdf = @pdf.empty()
  let fit = @pdf.PdfObject::Array([
    @pdf.PdfObject::Indirect(5),
    @pdf.PdfObject::Name("/Fit"),
  ])
  match read_destination(pdf, fit) {
    Destination::Fit(TargetPage::PageObject(5)) => ()
    _ => fail("expected Fit destination")
  }
  let fitr = @pdf.PdfObject::Array([
    @pdf.PdfObject::Indirect(7),
    @pdf.PdfObject::Name("/FitR"),
    @pdf.PdfObject::Real(1.0),
    @pdf.PdfObject::Real(2.0),
    @pdf.PdfObject::Real(3.0),
    @pdf.PdfObject::Real(4.0),
  ])
  match read_destination(pdf, fitr) {
    Destination::FitR(TargetPage::PageObject(7), left, top, right, bottom) => {
      assert_close(left, 1.0)
      assert_close(top, 2.0)
      assert_close(right, 3.0)
      assert_close(bottom, 4.0)
    }
    _ => fail("expected FitR destination")
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
