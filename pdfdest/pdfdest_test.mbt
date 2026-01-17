///|
fn assert_close(a : Double, b : Double) -> Unit {
  let diff = (a - b).abs()
  assert_true(diff < 1e-6)
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
