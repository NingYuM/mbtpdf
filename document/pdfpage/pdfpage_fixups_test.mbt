///|
fn fixups_sample_rect() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)])
}

///|
fn annot_numbers(pdf : @pdf.Pdf, page_obj : @pdf.PdfObject) -> Array[Int] {
  match (pdf.lookup_direct("/Annots", page_obj) : @pdf.PdfObject?) {
    Some(Array(arr)) =>
      arr.filter_map(fn(obj) {
        match (obj : @pdf.PdfObject) {
          Indirect(i) => Some(i)
          _ => None
        }
      })
    _ => []
  }
}

///|
test "add_pagetree handles large page sets" {
  let pages : Array[@pdfpage.Page] = []
  for _ in 0..<12 {
    pages.push(@pdfpage.Page::custom(fixups_sample_rect()))
  }
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
    pages,
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree().length(), 12)
}

///|
test "fixup_duplicate_annots clones duplicates and updates popup" {
  let pdf0 = @pdf.Pdf::empty()
  let page = @pdfpage.Page::custom(fixups_sample_rect())
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([
    page, page,
  ])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  let annot_base : @pdf.PdfObject = Dictionary([("/Subtype", Name("/Text"))])
  let annot_num = pdf.addobj(annot_base)
  let annot_with_popup = annot_base.add_entry("/Popup", Indirect(annot_num))
  pdf.addobj_given_num((annot_num, annot_with_popup))
  let refs = pdf.page_reference_numbers()
  for refnum in refs {
    let page_obj = pdf.lookup_obj(refnum)
    let annots : @pdf.PdfObject = Array([Indirect(annot_num)])
    let updated = page_obj.add_entry("/Annots", annots)
    pdf.addobj_given_num((refnum, updated))
  }
  @pdfpage.PdfPageDoc::new(pdf).fixup_duplicate_annots()
  let refs2 = pdf.page_reference_numbers()
  let annots1 = annot_numbers(pdf, pdf.lookup_obj(refs2[0]))
  let annots2 = annot_numbers(pdf, pdf.lookup_obj(refs2[1]))
  assert_eq(annots1.length(), 1)
  assert_eq(annots2.length(), 1)
  assert_true(annots1[0] != annots2[0])
  match (pdf.lookup_obj(annots2[0]) : @pdf.PdfObject) {
    Null => fail("expected copied annotation")
    _ => ()
  }
}

///|
test "fixup_destinations removes nulled entries" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let null_num = pdf.addobj(Null)
  let dead_dest : @pdf.PdfObject = Array([Indirect(null_num), Name("/Fit")])
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  let tree = tree_ctx.build_name_tree(false, [("Dead", dead_dest)])
  let names : @pdf.PdfObject = Dictionary([("/Dests", tree)])
  let catalog = pdf.catalog_of_pdf()
  let updated_catalog = catalog.add_entry("/Names", names)
  pdf.addobj_given_num((pdf.root, updated_catalog))
  let trailerdict = pdf.trailerdict.add_entry("/Root", updated_catalog)
  let pdf_direct : @pdf.Pdf = {
    major: pdf.major,
    minor: pdf.minor,
    root: pdf.root,
    objects: pdf.objects,
    trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
  @pdfpage.PdfPageDoc::new(pdf_direct).fixup_destinations()
  let updated_tree = match
    pdf_direct.lookup_chain(pdf_direct.trailerdict, [
      "/Root", "/Names", "/Dests",
    ]) {
    Some(t) => t
    None => fail("expected destinations tree")
  }
  let entries = @pdftree.PdfTree::new(pdf_direct).read_name_tree(updated_tree)
  assert_eq(entries.length(), 0)
}

///|
test "fixup_parents raises without page tree" {
  let res : Result[Unit, Error] = try? @pdfpage.PdfPageDoc::new(
    @pdf.Pdf::empty(),
  ).fixup_parents()
  match res {
    Err(_) => ()
    _ => fail("expected missing /Pages error")
  }
}

///|
test "fixup_parents skips direct kids" {
  let pdf0 = @pdf.Pdf::empty()
  let page : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/Page")),
    ("/Resources", Dictionary([])),
    ("/MediaBox", fixups_sample_rect()),
  ])
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/Pages")),
    ("/Kids", Array([page])),
    ("/Count", Integer(1)),
  ])
  let pages_num = pdf0.addobj(pages)
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pages_num, [])
  @pdfpage.PdfPageDoc::new(pdf).fixup_parents()
}
