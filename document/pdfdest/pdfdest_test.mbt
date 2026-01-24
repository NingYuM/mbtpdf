///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "read_destination array" {
  let pdf = @pdf.Pdf::empty()
  let obj : @pdf.PdfObject = Array([Indirect(7), Name("/FitH"), Real(200.0)])
  let dest = Destination::read(pdf, obj)
  match dest {
    Destination::FitH(TargetPage::PageObject(7), Some(top)) =>
      assert_close(top, 200.0)
    _ => fail("expected FitH destination")
  }
}

///|
test "read_destination shallow name" {
  let pdf = @pdf.Pdf::empty()
  let dest = Destination::read(pdf, Name("/Chapter1"), shallow=true)
  match dest {
    Destination::NamedDestination("/Chapter1") => ()
    _ => fail("expected NamedDestination")
  }
}

///|
test "destination to_pdf_object" {
  let dest = Destination::FitR(
    TargetPage::OtherDocPageNumber(3),
    10.0,
    20.0,
    30.0,
    40.0,
  )
  let obj = dest.to_pdf_object()
  match (obj : @pdf.PdfObject) {
    Array(
      [
        Integer(3),
        Name("/FitR"),
        Real(10.0),
        Real(20.0),
        Real(30.0),
        Real(40.0),
      ]
    ) => ()
    _ => fail("unexpected pdfobject for destination")
  }
}

///|
test "transform_destination translate" {
  let pdf = @pdf.Pdf::empty()
  let dest = Destination::XYZ(
    TargetPage::PageObject(1),
    Some(10.0),
    Some(20.0),
    Some(1.0),
  )
  let tr = @pdftransform.TransformMatrix::translate(5.0, -3.0)
  let transformed = dest.transform(pdf, tr)
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
  let pdf = @pdf.Pdf::empty()
  let tr = @pdftransform.TransformMatrix::identity()
  let fitv = Destination::FitV(TargetPage::PageObject(1), Some(40000.0)).transform(
    pdf, tr,
  )
  match fitv {
    Destination::FitV(_, Some(left)) => assert_close(left, 32768.0)
    _ => fail("expected FitV clipped")
  }
  let fitbh = Destination::FitBH(TargetPage::PageObject(1), Some(-40000.0)).transform(
    pdf, tr,
  )
  match fitbh {
    Destination::FitBH(_, Some(top)) => assert_close(top, -32768.0)
    _ => fail("expected FitBH clipped")
  }
}

///|
test "transform_destination updates GoTo action" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let refs = @pdf.page_reference_numbers(pdf)
  let action : @pdf.PdfObject = Dictionary([
    ("/S", Name("/GoTo")),
    (
      "/D",
      Array([Indirect(refs[0]), Name("/XYZ"), Real(10.0), Real(20.0), Null]),
    ),
  ])
  let tr = @pdftransform.TransformMatrix::translate(5.0, -3.0)
  let updated = Destination::Action(action).transform(pdf, tr)
  match updated {
    Destination::Action(dict) =>
      match pdf.lookup_direct("/D", dict) {
        Some(Array([_, Name("/XYZ"), left, top, _])) => {
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
  let pdf = @pdf.Pdf::empty()
  let inner : @pdf.PdfObject = Array([
    Integer(0),
    Name("/XYZ"),
    Real(10.0),
    Real(20.0),
    Real(1.0),
  ])
  let obj : @pdf.PdfObject = Dictionary([("/D", inner)])
  let dest = Destination::read(pdf, obj)
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
  let pdf = @pdf.Pdf::empty()
  let fit : @pdf.PdfObject = Array([Indirect(5), Name("/Fit")])
  match Destination::read(pdf, fit) {
    Destination::Fit(TargetPage::PageObject(5)) => ()
    _ => fail("expected Fit destination")
  }
  let fitr : @pdf.PdfObject = Array([
    Indirect(7),
    Name("/FitR"),
    Real(1.0),
    Real(2.0),
    Real(3.0),
    Real(4.0),
  ])
  match Destination::read(pdf, fitr) {
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
test "read_destination array variants" {
  let pdf = @pdf.Pdf::empty()
  let xyz4 : @pdf.PdfObject = Array([
    Indirect(1),
    Name("/XYZ"),
    Real(10.0),
    Null,
  ])
  match Destination::read(pdf, xyz4) {
    Destination::XYZ(TargetPage::PageObject(1), Some(left), None, None) =>
      assert_close(left, 10.0)
    _ => fail("expected XYZ destination")
  }
  let xyz3 : @pdf.PdfObject = Array([Indirect(2), Name("/XYZ"), Null])
  match Destination::read(pdf, xyz3) {
    Destination::XYZ(TargetPage::PageObject(2), None, None, None) => ()
    _ => fail("expected XYZ destination")
  }
  let fitv : @pdf.PdfObject = Array([Indirect(3), Name("/FitV"), Real(12.0)])
  match Destination::read(pdf, fitv) {
    Destination::FitV(TargetPage::PageObject(3), Some(left)) =>
      assert_close(left, 12.0)
    _ => fail("expected FitV destination")
  }
  let fitbh : @pdf.PdfObject = Array([Indirect(4), Name("/FitBH"), Real(9.0)])
  match Destination::read(pdf, fitbh) {
    Destination::FitBH(TargetPage::PageObject(4), Some(top)) =>
      assert_close(top, 9.0)
    _ => fail("expected FitBH destination")
  }
  let fitbv : @pdf.PdfObject = Array([Indirect(5), Name("/FitBV"), Real(8.0)])
  match Destination::read(pdf, fitbv) {
    Destination::FitBV(TargetPage::PageObject(5), Some(left)) =>
      assert_close(left, 8.0)
    _ => fail("expected FitBV destination")
  }
  let fitb : @pdf.PdfObject = Array([Indirect(6), Name("/FitB")])
  match Destination::read(pdf, fitb) {
    Destination::FitB(TargetPage::PageObject(6)) => ()
    _ => fail("expected FitB destination")
  }
  let bad_target : @pdf.PdfObject = Array([
    Name("/NotPage"),
    Name("/FitH"),
    Real(1.0),
  ])
  match Destination::read(pdf, bad_target) {
    Destination::NullDestination => ()
    _ => fail("expected NullDestination for bad target")
  }
}

///|
test "read_destination handles missing and invalid objects" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([])
  match Destination::read(pdf, dict) {
    Destination::NullDestination => ()
    _ => fail("expected NullDestination for missing /D")
  }
  match Destination::read(pdf, Integer(1)) {
    Destination::NullDestination => ()
    _ => fail("expected NullDestination for invalid object")
  }
}

///|
test "read_destination name resolution" {
  let pdf_no_root = @pdf.Pdf::empty()
  pdf_no_root.trailerdict = Dictionary([])
  let no_root : Result[Destination, Error] = try? Destination::read(
    pdf_no_root,
    Name("/Missing"),
  )
  assert_true(no_root is Err(_))
  let pdf_missing_dests = @pdfpage.PdfPageDoc::minimum_valid()
  match Destination::read(pdf_missing_dests, Name("/Missing")) {
    Destination::NamedDestination("/Missing") => ()
    _ => fail("expected NamedDestination with no /Dests")
  }
  let pdf_missing_entry = @pdfpage.PdfPageDoc::minimum_valid()
  let root = pdf_missing_entry.lookup_obj(pdf_missing_entry.root)
  let dests : @pdf.PdfObject = Dictionary([("/Other", Null)])
  let root = root.add_entry("/Dests", dests)
  @pdf.addobj_given_num(pdf_missing_entry, (pdf_missing_entry.root, root))
  match Destination::read(pdf_missing_entry, Name("/Missing")) {
    Destination::NamedDestination("/Missing") => ()
    _ => fail("expected NamedDestination for missing entry")
  }
}

///|
test "read_destination string resolution" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  match Destination::read(pdf, String("Shallow"), shallow=true) {
    Destination::StringDestination("Shallow") => ()
    _ => fail("expected shallow StringDestination")
  }
  match Destination::read(pdf, String("Missing")) {
    Destination::StringDestination("Missing") => ()
    _ => fail("expected StringDestination with no /Names")
  }
  let pdf_no_dests = @pdfpage.PdfPageDoc::minimum_valid()
  let root = pdf_no_dests.lookup_obj(pdf_no_dests.root)
  let root = root.add_entry("/Names", Dictionary([]))
  @pdf.addobj_given_num(pdf_no_dests, (pdf_no_dests.root, root))
  match Destination::read(pdf_no_dests, String("Missing")) {
    Destination::StringDestination("Missing") => ()
    _ => fail("expected StringDestination with missing /Dests")
  }
  let pdf_with_tree = @pdfpage.PdfPageDoc::minimum_valid()
  let dest : @pdf.PdfObject = Array([Integer(0), Name("/Fit")])
  let dests : @pdf.PdfObject = Dictionary([
    ("/Names", Array([String("Anchor"), dest])),
  ])
  let names : @pdf.PdfObject = Dictionary([("/Dests", dests)])
  let root = pdf_with_tree.lookup_obj(pdf_with_tree.root)
  let root = root.add_entry("/Names", names)
  @pdf.addobj_given_num(pdf_with_tree, (pdf_with_tree.root, root))
  match Destination::read(pdf_with_tree, String("Anchor")) {
    Destination::Fit(TargetPage::OtherDocPageNumber(0)) => ()
    _ => fail("expected resolved StringDestination")
  }
  let pdf_no_match = @pdfpage.PdfPageDoc::minimum_valid()
  let dests : @pdf.PdfObject = Dictionary([
    ("/Names", Array([String("Other"), dest])),
  ])
  let names : @pdf.PdfObject = Dictionary([("/Dests", dests)])
  let root = pdf_no_match.lookup_obj(pdf_no_match.root)
  let root = root.add_entry("/Names", names)
  @pdf.addobj_given_num(pdf_no_match, (pdf_no_match.root, root))
  match Destination::read(pdf_no_match, String("Missing")) {
    Destination::StringDestination("Missing") => ()
    _ => fail("expected StringDestination for missing name")
  }
}

///|
test "destination to_pdf_object variants" {
  let action = Destination::Action(Name("/GoTo"))
  match (action.to_pdf_object() : @pdf.PdfObject) {
    Name("/GoTo") => ()
    _ => fail("expected action to passthrough")
  }
  let named = Destination::NamedDestination("/Dest")
  match (named.to_pdf_object() : @pdf.PdfObject) {
    Name("/Dest") => ()
    _ => fail("expected named destination name")
  }
  let fit = Destination::Fit(TargetPage::PageObject(1))
  match (fit.to_pdf_object() : @pdf.PdfObject) {
    Array([Indirect(1), Name("/Fit")]) => ()
    _ => fail("expected Fit object")
  }
  let fith = Destination::FitH(TargetPage::OtherDocPageNumber(2), None)
  match (fith.to_pdf_object() : @pdf.PdfObject) {
    Array([Integer(2), Name("/FitH"), Null]) => ()
    _ => fail("expected FitH object")
  }
  let fitv = Destination::FitV(TargetPage::PageObject(3), Some(12.0))
  match (fitv.to_pdf_object() : @pdf.PdfObject) {
    Array([Indirect(3), Name("/FitV"), Real(12.0)]) => ()
    _ => fail("expected FitV object")
  }
  let fitb = Destination::FitB(TargetPage::PageObject(4))
  match (fitb.to_pdf_object() : @pdf.PdfObject) {
    Array([Indirect(4), Name("/FitB")]) => ()
    _ => fail("expected FitB object")
  }
  let fitbh = Destination::FitBH(TargetPage::OtherDocPageNumber(5), Some(1.5))
  match (fitbh.to_pdf_object() : @pdf.PdfObject) {
    Array([Integer(5), Name("/FitBH"), Real(1.5)]) => ()
    _ => fail("expected FitBH object")
  }
  let fitbv = Destination::FitBV(TargetPage::OtherDocPageNumber(6), None)
  match (fitbv.to_pdf_object() : @pdf.PdfObject) {
    Array([Integer(6), Name("/FitBV"), Null]) => ()
    _ => fail("expected FitBV object")
  }
}

///|
test "transform_destination variants" {
  let pdf = @pdf.Pdf::empty()
  let tr = @pdftransform.TransformMatrix::translate(5.0, -3.0)
  let fith = Destination::FitH(TargetPage::PageObject(1), Some(10.0)).transform(
    pdf, tr,
  )
  match fith {
    Destination::FitH(TargetPage::PageObject(1), Some(top)) =>
      assert_close(top, 7.0)
    _ => fail("expected FitH transform")
  }
  let fitbv = Destination::FitBV(TargetPage::PageObject(2), Some(10.0)).transform(
    pdf, tr,
  )
  match fitbv {
    Destination::FitBV(TargetPage::PageObject(2), Some(left)) =>
      assert_close(left, 15.0)
    _ => fail("expected FitBV transform")
  }
  let xyz_top = Destination::XYZ(
    TargetPage::PageObject(3),
    None,
    Some(10.0),
    None,
  ).transform(pdf, tr)
  match xyz_top {
    Destination::XYZ(TargetPage::PageObject(3), None, Some(top), _) =>
      assert_close(top, 7.0)
    _ => fail("expected XYZ top transform")
  }
  let xyz_left = Destination::XYZ(
    TargetPage::PageObject(4),
    Some(10.0),
    None,
    None,
  ).transform(pdf, tr)
  match xyz_left {
    Destination::XYZ(TargetPage::PageObject(4), Some(left), None, _) =>
      assert_close(left, 15.0)
    _ => fail("expected XYZ left transform")
  }
  let fitr = Destination::FitR(TargetPage::PageObject(5), 0.0, 0.0, 10.0, 20.0).transform(
    pdf, tr,
  )
  match fitr {
    Destination::FitR(TargetPage::PageObject(5), left, bottom, right, top) => {
      assert_close(left, 5.0)
      assert_close(top, 17.0)
      assert_close(right, 15.0)
      assert_close(bottom, -3.0)
    }
    _ => fail("expected FitR transform")
  }
  let action = Destination::Action(Dictionary([("/S", Name("/URI"))]))
  match action.transform(pdf, tr) {
    Destination::Action(dict) =>
      match pdf.lookup_direct("/S", dict) {
        Some(Name("/URI")) => ()
        _ => fail("expected unchanged action")
      }
    _ => fail("expected action destination")
  }
  let named = Destination::NamedDestination("/Name")
  match named.transform(pdf, tr) {
    Destination::NamedDestination("/Name") => ()
    _ => fail("expected NamedDestination passthrough")
  }
}

///|
test "read_destination resolves named dests in catalog" {
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page = @pdfpage.Page::custom(rect)
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
      page,
    ],
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
  let refs = @pdf.page_reference_numbers(pdf)
  let dest : @pdf.PdfObject = Array([Indirect(refs[0]), Name("/Fit")])
  let dests : @pdf.PdfObject = Dictionary([("/Chapter1", dest)])
  let root_obj = pdf.lookup_obj(pdf.root)
  let updated_root = root_obj.add_entry("/Dests", dests)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_root))
  let resolved = Destination::read(pdf, Name("/Chapter1"))
  match resolved {
    Destination::Fit(TargetPage::PageObject(n)) => assert_eq(n, refs[0])
    _ => fail("expected Fit destination")
  }
}
