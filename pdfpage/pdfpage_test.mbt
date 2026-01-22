///|
test "pagenumber_of_target on page object" {
  let pdf = minimum_valid_pdf()
  let refs = @pdf.page_reference_numbers(pdf)
  let dest = @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(refs[0]))
  assert_eq(pagenumber_of_target(pdf, dest), 1)
}

///|
test "ppstub returns identity matrix" {
  let (value, n, matrix) = ppstub((x, y) => x + y, 2, 3)
  assert_eq(value, 5)
  assert_eq(n, 2)
  assert_eq(
    @pdftransform.string_of_matrix(matrix),
    @pdftransform.string_of_matrix(@pdftransform.i_matrix),
  )
}

///|
test "pages_of_pagetree_quick detects cycle" {
  let pdf0 = @pdf.empty()
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/Pages")),
    ("/Kids", Array([Indirect(1)])),
  ])
  @pdf.addobj_given_num(pdf0, (1, pages))
  let pdf = add_root(1, [], pdf0)
  let res : Result[Int, Error] = try? pages_of_pagetree_quick(pdf)
  match res {
    Err(_) => ()
    _ => fail("expected cycle detection")
  }
}
