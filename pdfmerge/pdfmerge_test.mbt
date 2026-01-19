///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
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
