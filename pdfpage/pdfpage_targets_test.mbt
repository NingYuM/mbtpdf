///|
test "pagenumber_of_target handles non-page targets" {
  let pdf = @pdfpage.minimum_valid_pdf()
  assert_eq(
    @pdfpage.pagenumber_of_target(pdf, @pdfdest.Destination::NullDestination),
    0,
  )
  assert_eq(
    @pdfpage.pagenumber_of_target(
      pdf,
      @pdfdest.Destination::NamedDestination("/Name"),
    ),
    0,
  )
  assert_eq(
    @pdfpage.pagenumber_of_target(
      pdf,
      @pdfdest.Destination::StringDestination("Name"),
    ),
    0,
  )
}

///|
test "pagenumber_of_target follows GoTo action and fastrefnums" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let refs = @pdf.page_reference_numbers(pdf)
  let dest_array = @pdf.PdfObject::Array([
    @pdf.PdfObject::Indirect(refs[0]),
    @pdf.PdfObject::Name("/Fit"),
  ])
  let action = @pdf.PdfObject::Dictionary([
    ("/S", @pdf.PdfObject::Name("/GoTo")),
    ("/D", dest_array),
  ])
  let table : Map[Int, Int] = Map::new()
  table.set(refs[0], 7)
  let dest = @pdfdest.Destination::Action(action)
  assert_eq(@pdfpage.pagenumber_of_target(pdf, dest, fastrefnums=table), 7)
}

///|
test "pagenumber_of_target handles action edge cases" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let action_missing = @pdf.PdfObject::Dictionary([
    ("/S", @pdf.PdfObject::Name("/GoTo")),
  ])
  let action_other = @pdf.PdfObject::Dictionary([
    ("/S", @pdf.PdfObject::Name("/URI")),
  ])
  assert_eq(
    @pdfpage.pagenumber_of_target(
      pdf,
      @pdfdest.Destination::Action(action_missing),
    ),
    0,
  )
  assert_eq(
    @pdfpage.pagenumber_of_target(
      pdf,
      @pdfdest.Destination::Action(action_other),
    ),
    0,
  )
}

///|
test "pagenumber_of_target follows GoTo action without fastrefnums" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let refs = @pdf.page_reference_numbers(pdf)
  let dest_array = @pdf.PdfObject::Array([
    @pdf.PdfObject::Indirect(refs[0]),
    @pdf.PdfObject::Name("/Fit"),
  ])
  let action = @pdf.PdfObject::Dictionary([
    ("/S", @pdf.PdfObject::Name("/GoTo")),
    ("/D", dest_array),
  ])
  let dest = @pdfdest.Destination::Action(action)
  assert_eq(@pdfpage.pagenumber_of_target(pdf, dest), 1)
}

///|
test "pagenumber_of_target handles target page variants" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let other = @pdfdest.Destination::Fit(
    @pdfdest.TargetPage::OtherDocPageNumber(2),
  )
  assert_eq(@pdfpage.pagenumber_of_target(pdf, other), 3)
  let refs = @pdf.page_reference_numbers(pdf)
  let dest = @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(refs[0]))
  let table : Map[Int, Int] = Map::new()
  table.set(refs[0] + 100, 9)
  assert_eq(@pdfpage.pagenumber_of_target(pdf, dest, fastrefnums=table), 0)
  let missing = @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(9999))
  assert_eq(@pdfpage.pagenumber_of_target(pdf, missing), 0)
}

///|
test "page_object_number and target_of_pagenumber handle out of range" {
  let pdf = @pdfpage.minimum_valid_pdf()
  match @pdfpage.page_object_number(pdf, 1) {
    Some(_) => ()
    _ => fail("expected page object number")
  }
  match @pdfpage.page_object_number(pdf, 0) {
    None => ()
    _ => fail("expected None for page 0")
  }
  match @pdfpage.page_object_number(pdf, 2) {
    None => ()
    _ => fail("expected None for page 2")
  }
  match @pdfpage.target_of_pagenumber(pdf, 2) {
    @pdfdest.Destination::NullDestination => ()
    _ => fail("expected NullDestination")
  }
}
