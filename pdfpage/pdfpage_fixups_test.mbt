///|
fn fixups_sample_rect() -> @pdf.PdfObject {
  @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
}

///|
fn annot_numbers(pdf : @pdf.Pdf, page_obj : @pdf.PdfObject) -> Array[Int] {
  match @pdf.lookup_direct(pdf, "/Annots", page_obj) {
    Some(@pdf.PdfObject::Array(arr)) =>
      arr.filter_map(obj => match obj {
        @pdf.PdfObject::Indirect(i) => Some(i)
        _ => None
      })
    _ => []
  }
}

///|
test "add_pagetree handles large page sets" {
  let pages : Array[@pdfpage.Page] = []
  for _ in 0..<12 {
    pages.push(@pdfpage.custompage(fixups_sample_rect()))
  }
  let (pdf0, pageroot) = @pdfpage.add_pagetree(pages, @pdf.empty())
  let pdf = @pdfpage.add_root(pageroot, [], pdf0)
  assert_eq(@pdfpage.pages_of_pagetree(pdf).length(), 12)
}

///|
test "fixup_duplicate_annots clones duplicates and updates popup" {
  let pdf0 = @pdf.empty()
  let page = @pdfpage.custompage(fixups_sample_rect())
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page, page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  let annot_base = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Text")),
  ])
  let annot_num = @pdf.addobj(pdf, annot_base)
  let annot_with_popup = @pdf.add_dict_entry(
    annot_base,
    "/Popup",
    @pdf.PdfObject::Indirect(annot_num),
  )
  @pdf.addobj_given_num(pdf, (annot_num, annot_with_popup))
  let refs = @pdf.page_reference_numbers(pdf)
  for refnum in refs {
    let page_obj = @pdf.lookup_obj(pdf, refnum)
    let updated = @pdf.add_dict_entry(
      page_obj,
      "/Annots",
      @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(annot_num)]),
    )
    @pdf.addobj_given_num(pdf, (refnum, updated))
  }
  @pdfpage.fixup_duplicate_annots(pdf)
  let refs2 = @pdf.page_reference_numbers(pdf)
  let annots1 = annot_numbers(pdf, @pdf.lookup_obj(pdf, refs2[0]))
  let annots2 = annot_numbers(pdf, @pdf.lookup_obj(pdf, refs2[1]))
  assert_eq(annots1.length(), 1)
  assert_eq(annots2.length(), 1)
  assert_true(annots1[0] != annots2[0])
  match @pdf.lookup_obj(pdf, annots2[0]) {
    @pdf.PdfObject::Null => fail("expected copied annotation")
    _ => ()
  }
}

///|
test "fixup_destinations removes nulled entries" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let null_num = @pdf.addobj(pdf, @pdf.PdfObject::Null)
  let dead_dest = @pdf.PdfObject::Array([
    @pdf.PdfObject::Indirect(null_num),
    @pdf.PdfObject::Name("/Fit"),
  ])
  let tree = @pdftree.build_name_tree(false, pdf, [("Dead", dead_dest)])
  let names = @pdf.PdfObject::Dictionary([("/Dests", tree)])
  let catalog = @pdf.catalog_of_pdf(pdf)
  let updated_catalog = @pdf.add_dict_entry(catalog, "/Names", names)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_catalog))
  let trailerdict = @pdf.add_dict_entry(
    pdf.trailerdict,
    "/Root",
    updated_catalog,
  )
  let pdf_direct : @pdf.Pdf = {
    major: pdf.major,
    minor: pdf.minor,
    root: pdf.root,
    objects: pdf.objects,
    trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
  @pdfpage.fixup_destinations(pdf_direct)
  let updated_tree = match
    @pdf.lookup_chain(pdf_direct, pdf_direct.trailerdict, [
      "/Root", "/Names", "/Dests",
    ]) {
    Some(t) => t
    None => fail("expected destinations tree")
  }
  let entries = @pdftree.read_name_tree(pdf_direct, updated_tree)
  assert_eq(entries.length(), 0)
}

///|
test "fixup_parents raises without page tree" {
  let res : Result[Unit, Error] = try? @pdfpage.fixup_parents(@pdf.empty())
  match res {
    Err(_) => ()
    _ => fail("expected missing /Pages error")
  }
}

///|
test "fixup_parents skips direct kids" {
  let pdf0 = @pdf.empty()
  let page = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Page")),
    ("/Resources", @pdf.PdfObject::Dictionary([])),
    ("/MediaBox", fixups_sample_rect()),
  ])
  let pages = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Pages")),
    ("/Kids", @pdf.PdfObject::Array([page])),
    ("/Count", @pdf.PdfObject::Integer(1)),
  ])
  let pages_num = @pdf.addobj(pdf0, pages)
  let pdf = @pdfpage.add_root(pages_num, [], pdf0)
  @pdfpage.fixup_parents(pdf)
}
