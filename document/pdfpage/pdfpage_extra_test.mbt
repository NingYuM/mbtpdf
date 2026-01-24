///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "minimum_valid_pdf has one page" {
  let pdf = @pdfpage.minimum_valid_pdf()
  assert_eq(@pdfpage.endpage(pdf), 1)
  assert_eq(@pdfpage.endpage_fast(pdf), 1)
  assert_eq(@pdfpage.pages_of_pagetree(pdf).length(), 1)
}

///|
test "add_pagetree builds page objects" {
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let pages = [@pdfpage.Page::custom(rect), @pdfpage.Page::custom(rect)]
  let (pdf0, pageroot) = @pdfpage.add_pagetree(pages, @pdf.empty())
  let pdf = @pdfpage.add_root(pageroot, [], pdf0)
  assert_eq(@pdfpage.pages_of_pagetree(pdf).length(), 2)
  match @pdfpage.page_object_number(pdf, 1) {
    Some(n) => assert_true(n > 0)
    _ => fail("expected page object number")
  }
}

///|
test "pages_of_pagetree handles missing mediabox and non-stream contents" {
  let rect1 : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(120.0),
  ])
  let rect2 : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(200.0),
    Real(220.0),
  ])
  let pages = [@pdfpage.Page::custom(rect1), @pdfpage.Page::custom(rect2)]
  let (pdf1, pageroot) = @pdfpage.add_pagetree(pages, @pdf.empty())
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  let page1_num = match @pdfpage.page_object_number(pdf, 1) {
    Some(n) => n
    None => fail("expected page object number")
  }
  let page2_num = match @pdfpage.page_object_number(pdf, 2) {
    Some(n) => n
    None => fail("expected page object number")
  }
  let page1_obj = @pdf.lookup_obj(pdf, page1_num)
  let page1_updated = @pdf.add_dict_entry(
    page1_obj,
    "/Contents",
    Array([Integer(1)]),
  )
  @pdf.addobj_given_num(pdf, (page1_num, page1_updated))
  let page2_obj = @pdf.lookup_obj(pdf, page2_num)
  let page2_updated = @pdf.add_dict_entry(
    @pdf.remove_dict_entry(
      @pdf.remove_dict_entry(page2_obj, "/MediaBox"),
      "/Resources",
    ),
    "/Contents",
    Integer(2),
  )
  @pdf.addobj_given_num(pdf, (page2_num, page2_updated))
  let out_pages = @pdfpage.pages_of_pagetree(pdf)
  assert_eq(out_pages.length(), 2)
  assert_eq(out_pages[0].content.length(), 0)
  assert_eq(out_pages[1].content.length(), 0)
  match (out_pages[1].mediabox : @pdf.PdfObject) {
    Array(vals) =>
      match ((vals[2], vals[3]) : (@pdf.PdfObject, _)) {
        (Real(w), Real(h)) => {
          assert_close(w, 100.0)
          assert_close(h, 120.0)
        }
        _ => fail("expected mediabox numbers")
      }
    _ => fail("expected mediabox array")
  }
  match (out_pages[1].resources : @pdf.PdfObject) {
    Dictionary(entries) => assert_eq(entries.length(), 0)
    _ => fail("expected resources dictionary")
  }
}

///|
test "change_pages rewrites bookmarks and mixed annotations" {
  let pdf0 = @pdf.empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let pages_in = [@pdfpage.Page::custom(rect), @pdfpage.Page::custom(rect)]
  let (pdf1, pageroot) = @pdfpage.add_pagetree(pages_in, pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  let refs = @pdf.page_reference_numbers(pdf)
  let dest1 : @pdf.PdfObject = Array([Indirect(refs[0]), Name("/Fit")])
  let dest2 : @pdf.PdfObject = Array([Indirect(refs[1]), Name("/Fit")])
  let annot_dest1 : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Rect", rect),
    ("/Dest", dest1),
  ])
  let annot_dest2 : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Rect", rect),
    ("/Dest", dest2),
  ])
  let annot_action_missing : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Rect", rect),
    ("/A", Dictionary([("/S", Name("/GoTo"))])),
  ])
  let annot_action_other : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Rect", rect),
    ("/A", Dictionary([("/S", Name("/URI"))])),
  ])
  let annot_action_none : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Rect", rect),
    ("/A", Dictionary([("/S", Name("/GoTo")), ("/D", dest2)])),
  ])
  let annot_nums = [
    @pdf.addobj(pdf, annot_dest1),
    @pdf.addobj(pdf, annot_dest2),
    @pdf.addobj(pdf, annot_action_missing),
    @pdf.addobj(pdf, annot_action_other),
    @pdf.addobj(pdf, annot_action_none),
  ]
  let annots : @pdf.PdfObject = Array(annot_nums.map(fn(n) { Indirect(n) }))
  let page1_obj = @pdf.lookup_obj(pdf, refs[0])
  let page1_updated = @pdf.add_dict_entry(page1_obj, "/Annots", annots)
  @pdf.addobj_given_num(pdf, (refs[0], page1_updated))
  let bookmarks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "P1",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(refs[0]),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "P2",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(refs[1]),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Missing",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(9999)),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Other",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::OtherDocPageNumber(2),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Named",
      target: @pdfdest.Destination::NamedDestination("/Named"),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf = @pdfmarks.add_bookmarks(bookmarks, pdf)
  let catalog = @pdf.catalog_of_pdf(pdf)
  let catalog = @pdf.add_dict_entry(catalog, "/OpenAction", dest1)
  @pdf.addobj_given_num(pdf, (pdf.root, catalog))
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let matrix = @pdftransform.TransformMatrix::translate(10.0, 0.0)
  let updated = @pdfpage.change_pages(true, pdf, pages, matrices=[(1, matrix)])
  assert_eq(@pdfpage.endpage(updated), 2)
}

///|
test "pdf_of_pages extracts subset" {
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let pages = [
    @pdfpage.Page::custom(rect),
    @pdfpage.Page::custom(rect),
    @pdfpage.Page::custom(rect),
  ]
  let (pdf0, pageroot) = @pdfpage.add_pagetree(pages, @pdf.empty())
  let pdf = @pdfpage.add_root(pageroot, [], pdf0)
  let subset = @pdfpage.pdf_of_pages(
    pdf,
    [2],
    retain_numbering=false,
    process_struct_tree=false,
  )
  assert_eq(@pdfpage.endpage(subset), 1)
}

///|
test "prepend/postpend operators update content" {
  let pdf = @pdf.empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let base_page = @pdfpage.Page::custom(rect)
  let base_ops : Array[@pdfops.Op] = [Opq, OpQ]
  let page = Page::{
    content: [@pdfops.Op::stream_of_ops(base_ops)],
    mediabox: base_page.mediabox,
    resources: base_page.resources,
    rotate: base_page.rotate,
    rest: base_page.rest,
  }
  let pre = page.prepend_operators(pdf, [Opw(2.0)])
  let ops_pre = @pdfops.Op::parse_operators(pdf, pre.resources, pre.content)
  match (ops_pre[0] : @pdfops.Op) {
    Opw(2.0) => ()
    _ => fail("expected prepend to be first")
  }
  let post = pre.postpend_operators(pdf, [Opw(3.0)])
  let ops_post = @pdfops.Op::parse_operators(pdf, post.resources, post.content)
  let last = ops_post[ops_post.length() - 1]
  match (last : @pdfops.Op) {
    Opw(3.0) => ()
    _ => fail("expected postpend to be last")
  }
}

///|
test "rotation_of_int rejects invalid" {
  let res : Result[@pdfpage.Rotation, Error] = try? @pdfpage.Rotation::from_int(
    13,
  )
  match res {
    Err(_) => ()
    _ => fail("expected error")
  }
}

///|
test "fixup_duplicate_pages creates unique refs" {
  let pdf0 = @pdf.empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/Page")),
    ("/MediaBox", rect),
    ("/Parent", Indirect(2)),
  ])
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/Pages")),
    ("/Kids", Array([Indirect(1), Indirect(1)])),
    ("/Count", Integer(2)),
  ])
  @pdf.addobj_given_num(pdf0, (1, page))
  @pdf.addobj_given_num(pdf0, (2, pages))
  let pdf = @pdfpage.add_root(2, [], pdf0)
  @pdfpage.fixup_duplicate_pages(pdf)
  let refs = @pdf.page_reference_numbers(pdf)
  assert_eq(refs.length(), 2)
  assert_true(refs[0] != refs[1])
}

///|
test "replace_inherit fills mediabox" {
  let pdf0 = @pdf.empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/Page")),
    ("/Parent", Indirect(2)),
  ])
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/Pages")),
    ("/Kids", Array([Indirect(1)])),
    ("/Count", Integer(1)),
    ("/MediaBox", rect),
  ])
  @pdf.addobj_given_num(pdf0, (1, page))
  @pdf.addobj_given_num(pdf0, (2, pages))
  let pdf = @pdfpage.add_root(2, [], pdf0)
  @pdfpage.replace_inherit(pdf, [1])
  let updated = @pdf.lookup_obj(pdf, 1)
  match @pdf.lookup_direct(pdf, "/MediaBox", updated) {
    Some(_) => ()
    _ => fail("expected MediaBox to be inherited")
  }
}

///|
test "renumber_pages updates resources and operators" {
  let pdf = @pdf.empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F1", Null)])),
  ])
  let ops : Array[@pdfops.Op] = [OpBT, OpTf("/F1", 12.0), OpTj("Hi"), OpET]
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let updated = @pdfpage.renumber_pages(pdf, [page])
  let renamed = updated[0]
  match @pdf.lookup_direct(pdf, "/Font", renamed.resources) {
    Some(Dictionary(entries)) => {
      assert_eq(entries.length(), 1)
      assert_true(entries[0].0 != "/F1")
    }
    _ => fail("expected renamed font dictionary")
  }
  let ops_updated = @pdfops.Op::parse_operators(
    pdf,
    renamed.resources,
    renamed.content,
  )
  match (ops_updated : Array[@pdfops.Op]) {
    [OpBT, OpTf(name, _), ..] => assert_true(name != "/F1")
    _ => fail("expected renamed font operator")
  }
}

///|
test "add_prefix rewrites resources and content" {
  let pdf0 = @pdf.empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F1", Null)])),
  ])
  let ops : Array[@pdfops.Op] = [OpBT, OpTf("/F1", 12.0), OpTj("Hi"), OpET]
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let page0 = pages[0]
  match @pdf.lookup_direct(pdf, "/Font", page0.resources) {
    Some(Dictionary(entries)) => {
      assert_eq(entries.length(), 1)
      assert_eq(entries[0].0, "/pF1")
    }
    _ => fail("expected prefixed font dictionary")
  }
  let ops_updated = @pdfops.Op::parse_operators(
    pdf,
    page0.resources,
    page0.content,
  )
  match (ops_updated : Array[@pdfops.Op]) {
    [OpBT, OpTf(name, _), ..] => assert_eq(name, "/pF1")
    _ => fail("expected prefixed font operator")
  }
}

///|
test "shortest_unused_prefix skips used names" {
  let pdf0 = @pdf.empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/a1", Null)])),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  assert_eq(@pdfpage.shortest_unused_prefix(pdf), "b")
}

///|
test "change_pages rewrites annotation and openaction" {
  let pdf0 = @pdf.empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page = @pdfpage.Page::custom(rect)
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  let refs = @pdf.page_reference_numbers(pdf)
  let dest_array : @pdf.PdfObject = Array([
    Indirect(refs[0]),
    Name("/XYZ"),
    Real(10.0),
    Real(20.0),
    Real(1.0),
  ])
  let annot_dest : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Dest", dest_array),
  ])
  let annot_action : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/A", Dictionary([("/S", Name("/GoTo")), ("/D", dest_array)])),
  ])
  let annot1 = @pdf.addobj(pdf, annot_dest)
  let annot2 = @pdf.addobj(pdf, annot_action)
  let page_obj = @pdf.lookup_obj(pdf, refs[0])
  let annots : @pdf.PdfObject = Array([Indirect(annot1), Indirect(annot2)])
  let updated_page = @pdf.add_dict_entry(page_obj, "/Annots", annots)
  @pdf.addobj_given_num(pdf, (refs[0], updated_page))
  let catalog = @pdf.catalog_of_pdf(pdf)
  let updated_catalog = @pdf.add_dict_entry(catalog, "/OpenAction", dest_array)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_catalog))
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let translated = @pdfpage.change_pages(true, pdf, pages, matrices=[
    (1, @pdftransform.TransformMatrix::translate(5.0, -3.0)),
  ])
  let catalog2 = @pdf.catalog_of_pdf(translated)
  let openaction = match
    @pdf.lookup_direct(translated, "/OpenAction", catalog2) {
    Some(dest) => dest
    None => fail("expected OpenAction")
  }
  match @pdfdest.Destination::read(translated, openaction) {
    @pdfdest.Destination::XYZ(_, Some(left), Some(top), _) => {
      assert_close(left, 15.0)
      assert_close(top, 17.0)
    }
    _ => fail("expected updated openaction destination")
  }
  let refs2 = @pdf.page_reference_numbers(translated)
  let page2 = @pdf.lookup_obj(translated, refs2[0])
  let annots = match @pdf.lookup_direct(translated, "/Annots", page2) {
    Some(Array(arr)) => arr
    _ => fail("expected annots")
  }
  for annot in annots {
    match (annot : @pdf.PdfObject) {
      Indirect(i) => {
        let obj = @pdf.lookup_obj(translated, i)
        let dest = match @pdf.lookup_direct(translated, "/Dest", obj) {
          Some(d) => d
          None =>
            match @pdf.lookup_direct(translated, "/A", obj) {
              Some(Dictionary(_) as act) =>
                match @pdf.lookup_direct(translated, "/D", act) {
                  Some(d) => d
                  _ => fail("expected action dest")
                }
              _ => fail("expected action")
            }
        }
        match @pdfdest.Destination::read(translated, dest) {
          @pdfdest.Destination::XYZ(_, Some(left), Some(top), _) => {
            assert_close(left, 15.0)
            assert_close(top, 17.0)
          }
          _ => fail("expected updated annotation destination")
        }
      }
      _ => fail("expected indirect annotation")
    }
  }
}
