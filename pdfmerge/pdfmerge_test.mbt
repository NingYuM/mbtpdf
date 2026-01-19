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

///|
test "remove_duplicate_fonts keeps distinct streams" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(1)),
  ])
  let dict_alt = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(1)),
    ("/Subtype", @pdf.PdfObject::Name("/XObject")),
  ])
  let stream1 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got([0x01]))),
  )
  let stream2 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got([0x01, 0x02]))),
  )
  let stream3 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got([0x02]))),
  )
  let stream4 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got([0x01]))),
  )
  let stream5 = @pdf.PdfObject::Stream(
    Ref::new((dict_alt, @pdf.Stream::Got([0x01]))),
  )
  ignore(@pdf.addobj(pdf, stream1))
  ignore(@pdf.addobj(pdf, stream2))
  ignore(@pdf.addobj(pdf, stream3))
  ignore(@pdf.addobj(pdf, stream4))
  ignore(@pdf.addobj(pdf, stream5))
  remove_duplicate_fonts(pdf)
  assert_eq(count_streams(pdf), 4)
}

///|

///|
test "merge_pdfs processes structure trees" {
  let pdf1 = @pdfpage.minimum_valid_pdf()
  let pdf2 = @pdfpage.minimum_valid_pdf()
  let merged = merge_pdfs(
    false,
    false,
    process_struct_trees=true,
    add_toplevel_document=true,
    ["one", "two"],
    [pdf1, pdf2],
    [[1], [1]],
  )
  assert_eq(@pdfpage.pages_of_pagetree_quick(merged), 2)
}

///|
test "merge_pdfs rejects length mismatch" {
  let pdf1 = @pdfpage.minimum_valid_pdf()
  let pdf2 = @pdfpage.minimum_valid_pdf()
  let result : Result[@pdf.Pdf, Error] = try? merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
    ["one"],
    [pdf1, pdf2],
    [[1], [1]],
  )
  assert_true(result is Err(_))
}
