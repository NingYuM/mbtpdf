///|
fn page_objnum(pdf : @pdf.Pdf, index : Int) -> Int raise {
  match @pdfpage.PdfPageDoc::new(pdf).page_object_number(index) {
    Some(objnum) => objnum
    None => raise @pdf.PdfError::Msg("missing page")
  }
}

///|
fn build_two_page_pdf() -> @pdf.Pdf raise {
  let pdf = @pdf.Pdf::empty()
  let pages = [
    @pdfpage.Page::blank(@pdfpaper.a4),
    @pdfpage.Page::blank(@pdfpaper.a4),
  ]
  let (pdf, pagetree) = @pdfpage.PdfPageDoc::new(pdf).add_pagetree(pages)
  @pdfpage.PdfPageDoc::new(pdf).add_root(pagetree, [])
}

///|
fn set_catalog_entry(
  pdf : @pdf.Pdf,
  key : String,
  value : @pdf.PdfObject,
) -> Unit raise {
  let catalog = @pdf.catalog_of_pdf(pdf)
  let updated = catalog.add_entry(key, value)
  pdf.addobj_given_num((pdf.root, updated))
}

///|
fn dest_for_page(page_objnum : Int) -> @pdf.PdfObject {
  Array([Indirect(page_objnum), Name("/Fit")])
}

///|
fn xyz_dest_for_page(page_objnum : Int) -> @pdf.PdfObject {
  @pdfdest.Destination::XYZ(
    @pdfdest.TargetPage::PageObject(page_objnum),
    Some(0.0),
    Some(0.0),
    Some(1.0),
  ).to_pdf_object()
}

///|
fn action_for_dest(dest : @pdf.PdfObject) -> @pdf.PdfObject {
  Dictionary([("/S", Name("/GoTo")), ("/D", dest)])
}

///|
fn update_page_annots(
  pdf : @pdf.Pdf,
  page_objnum : Int,
  annots : Array[@pdf.PdfObject],
) -> Unit raise {
  let page_obj = pdf.lookup_obj(page_objnum)
  match (page_obj : @pdf.PdfObject) {
    Dictionary(_) => {
      let updated = page_obj.add_entry("/Annots", Array(annots))
      pdf.addobj_given_num((page_objnum, updated))
    }
    _ => raise @pdf.PdfError::Msg("page object not a dictionary")
  }
}

///|
fn add_bookmarks_for_pages(
  pdf : @pdf.Pdf,
  page1 : Int,
  page2 : Int,
) -> @pdf.Pdf raise {
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 1,
      text: "Page 1",
      target: @pdfdest.Destination::XYZ(
        @pdfdest.TargetPage::PageObject(page1),
        Some(0.0),
        Some(0.0),
        Some(1.0),
      ),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "Page 2",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(page2)),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
}

///|
test "pagenumber_of_target resolves action destinations" {
  let pdf = build_two_page_pdf()
  let page1 = page_objnum(pdf, 1)
  let dest = dest_for_page(page1)
  let action = action_for_dest(dest)
  let target = @pdfdest.Destination::Action(action)
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(target), 1)
}

///|
test "change_pages returns pdf when references are unchanged" {
  let pdf = build_two_page_pdf()
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  let updated = @pdfpage.PdfPageDoc::new(pdf).change_pages(false, pages)
  assert_eq(@pdfpage.PdfPageDoc::new(updated).pages_of_pagetree_quick(), 2)
}

///|
test "change_pages with references and no matrices" {
  let pdf = build_two_page_pdf()
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  let updated = @pdfpage.PdfPageDoc::new(pdf).change_pages(true, pages)
  assert_eq(@pdfpage.PdfPageDoc::new(updated).pages_of_pagetree_quick(), 2)
}

///|
test "change_pages rewrites bookmarks annotations and openaction" {
  let mut pdf = build_two_page_pdf()
  let page1 = page_objnum(pdf, 1)
  let page2 = page_objnum(pdf, 2)
  pdf.objects.object_stream_ids.set(page1, page1)
  pdf = add_bookmarks_for_pages(pdf, page1, page2)
  let dest_page2 = dest_for_page(page2)
  let annot_dest : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Dest", dest_page2),
  ])
  let annot_dest_num = pdf.addobj(annot_dest)
  let annot_action : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/A", action_for_dest(dest_page2)),
  ])
  let annot_action_num = pdf.addobj(annot_action)
  let annot_action_invalid : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/A", Null),
  ])
  let annot_action_invalid_num = pdf.addobj(annot_action_invalid)
  let annot_not_link : @pdf.PdfObject = Dictionary([("/Subtype", Name("/Text"))])
  let annot_not_link_num = pdf.addobj(annot_not_link)
  let annots : Array[@pdf.PdfObject] = [
    Indirect(annot_dest_num),
    Indirect(annot_action_num),
    Indirect(annot_action_invalid_num),
    Indirect(annot_not_link_num),
    Null,
  ]
  update_page_annots(pdf, page1, annots)
  set_catalog_entry(
    pdf,
    "/OpenAction",
    action_for_dest(xyz_dest_for_page(page1)),
  )
  let scale : @pdftransform.TransformMatrix = {
    a: 2.0,
    b: 0.0,
    c: 0.0,
    d: 2.0,
    e: 0.0,
    f: 0.0,
  }
  let matrices = [(1, scale), (2, @pdftransform.TransformMatrix::identity())]
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  let updated = @pdfpage.PdfPageDoc::new(pdf).change_pages(
    true,
    pages,
    matrices~,
  )
  assert_eq(@pdfpage.PdfPageDoc::new(updated).pages_of_pagetree_quick(), 2)
  let catalog = @pdf.catalog_of_pdf(updated)
  match (updated.lookup_direct("/OpenAction", catalog) : @pdf.PdfObject?) {
    Some(Dictionary(entries)) =>
      match entries.search_by(pair => pair.0 == "/D") {
        Some(idx) =>
          match (entries[idx].1 : @pdf.PdfObject) {
            Indirect(_) => ()
            _ => fail("expected indirect /D in /OpenAction")
          }
        None => fail("missing /D in /OpenAction")
      }
    _ => fail("expected /OpenAction dictionary")
  }
}

///|
test "change_pages keeps array openaction for identity matrices" {
  let pdf = build_two_page_pdf()
  let page1 = page_objnum(pdf, 1)
  set_catalog_entry(pdf, "/OpenAction", dest_for_page(page1))
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  let matrices = [
    (1, @pdftransform.TransformMatrix::identity()),
    (2, @pdftransform.TransformMatrix::identity()),
  ]
  let updated = @pdfpage.PdfPageDoc::new(pdf).change_pages(
    true,
    pages,
    matrices~,
  )
  let catalog = @pdf.catalog_of_pdf(updated)
  match (updated.lookup_direct("/OpenAction", catalog) : @pdf.PdfObject?) {
    Some(Array(_)) => ()
    _ => fail("expected array /OpenAction")
  }
}

///|
test "change_pages logs when lengths differ with matrices" {
  let pdf = build_two_page_pdf()
  let pages = [@pdfpage.Page::blank(@pdfpaper.a4)]
  let matrices = [(1, @pdftransform.TransformMatrix::identity())]
  let updated = @pdfpage.PdfPageDoc::new(pdf).change_pages(
    true,
    pages,
    matrices~,
  )
  assert_eq(@pdfpage.PdfPageDoc::new(updated).pages_of_pagetree_quick(), 1)
}

///|
test "change_pages rejects invalid change indices" {
  let pdf = build_two_page_pdf()
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  let res : Result[@pdf.Pdf, Error] = try? @pdfpage.PdfPageDoc::new(pdf).change_pages(
    true,
    pages,
    changes=[(0, 1)],
  )
  assert_true(res is Err(_))
}

///|
test "target_of_pagenumber returns fit destination" {
  let pdf = build_two_page_pdf()
  let dest = @pdfpage.PdfPageDoc::new(pdf).target_of_pagenumber(1)
  match dest {
    @pdfdest.Destination::Fit(_) => ()
    _ => fail("expected Fit destination")
  }
}
