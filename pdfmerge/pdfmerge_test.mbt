///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
fn count_streams(pdf : @pdf.Pdf) -> Int {
  let mut count = 0
  @pdf.objiter(
    (_, obj) => match obj {
      @pdf.PdfObject::Stream(_) => count = count + 1
      _ => ()
    },
    pdf,
  )
  count
}

///|
test "merge_pdfs combines pages" {
  let pdf1 = @pdfpage.minimum_valid_pdf()
  let pdf2 = @pdfpage.minimum_valid_pdf()
  let merged = merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
    ["one", "two"],
    [pdf1, pdf2],
    [[1], [1]],
  )
  assert_eq(@pdfpage.pages_of_pagetree_quick(merged), 2)
  remove_duplicate_fonts(merged)
}

///|
test "merge_pdfs rejects out of range" {
  let pdf = @pdfpage.minimum_valid_pdf()
  assert_is_err(
    try? merge_pdfs(
      false,
      false,
      process_struct_trees=false,
      add_toplevel_document=false,
      ["one"],
      [pdf],
      [[2]],
    ),
  )
}

///|
test "merge_pdfs retain numbering toggles path" {
  let pdf1 = @pdfpage.minimum_valid_pdf()
  let pdf2 = @pdfpage.minimum_valid_pdf()
  let merged = merge_pdfs(
    true,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
    ["one", "two"],
    [pdf1, pdf2],
    [[1], [1]],
  )
  assert_eq(@pdfpage.pages_of_pagetree_quick(merged), 2)
}

///|
test "remove_duplicate_fonts merges identical streams" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(2)),
  ])
  let data1 : Array[Byte] = [0x01, 0x02]
  let data2 : Array[Byte] = [0x01, 0x02]
  let stream1 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got(data1))),
  )
  let stream2 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got(data2))),
  )
  ignore(@pdf.addobj(pdf, stream1))
  ignore(@pdf.addobj(pdf, stream2))
  let before = count_streams(pdf)
  remove_duplicate_fonts(pdf)
  let after = count_streams(pdf)
  assert_eq(before, 2)
  assert_eq(after, 1)
}
