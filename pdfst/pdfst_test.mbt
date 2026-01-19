///|
fn build_two_page_pdf() -> @pdf.Pdf raise {
  let pages = [
    @pdfpage.blankpage(@pdfpaper.a4),
    @pdfpage.blankpage(@pdfpaper.a4),
  ]
  let (pdf, pageroot) = @pdfpage.add_pagetree(pages, @pdf.empty())
  @pdfpage.add_root(pageroot, [], pdf)
}

///|
fn add_struct_tree(pdf : @pdf.Pdf) -> (Int, Int) raise {
  let page_refs = @pdf.page_reference_numbers(pdf)
  let struct1 = @pdf.PdfObject::Dictionary([
    ("/Pg", @pdf.PdfObject::Indirect(page_refs[0])),
  ])
  let struct2 = @pdf.PdfObject::Dictionary([
    ("/Pg", @pdf.PdfObject::Indirect(page_refs[1])),
  ])
  let struct1_num = @pdf.addobj(pdf, struct1)
  let struct2_num = @pdf.addobj(pdf, struct2)
  let root = @pdf.PdfObject::Dictionary([
    (
      "/K",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Indirect(struct1_num),
        @pdf.PdfObject::Indirect(struct2_num),
      ]),
    ),
  ])
  let root_num = @pdf.addobj(pdf, root)
  let catalog_num = match @pdf.lookup_immediate("/Root", pdf.trailerdict) {
    Some(@pdf.PdfObject::Indirect(i)) => i
    _ => raise @pdf.PdfError::Msg("missing root")
  }
  let catalog = @pdf.lookup_obj(pdf, catalog_num)
  let updated = @pdf.add_dict_entry(
    catalog,
    "/StructTreeRoot",
    @pdf.PdfObject::Indirect(root_num),
  )
  @pdf.addobj_given_num(pdf, (catalog_num, updated))
  (root_num, struct2_num)
}

///|
test "trim_structure_tree removes entries" {
  let pdf = build_two_page_pdf()
  let (root_num, removed_num) = add_struct_tree(pdf)
  let previous = endpage.val
  endpage.val = p => @pdfpage.pages_of_pagetree_quick(p) catch { _ => 0 }
  trim_structure_tree(pdf, [1])
  endpage.val = previous
  assert_true(!@pdf.objnumbers(pdf).contains(removed_num))
  let root = @pdf.lookup_obj(pdf, root_num)
  match @pdf.lookup_immediate("/K", root) {
    Some(@pdf.PdfObject::Array(items)) => assert_eq(items.length(), 1)
    Some(@pdf.PdfObject::Indirect(_)) => ()
    _ => fail("expected updated /K")
  }
}

///|
test "renumber_parent_trees with empty parents" {
  let pdf1 = build_two_page_pdf()
  let pdf2 = build_two_page_pdf()
  renumber_parent_trees([pdf1, pdf2])
}

///|
test "merge_structure_trees returns none" {
  let pdf = @pdf.empty()
  let input = build_two_page_pdf()
  match merge_structure_trees(pdf, [input]) {
    None => ()
    _ => fail("expected none")
  }
}
