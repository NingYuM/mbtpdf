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
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let pages = [@pdfpage.custompage(rect), @pdfpage.custompage(rect)]
  let (pdf0, pageroot) = @pdfpage.add_pagetree(pages, @pdf.empty())
  let pdf = @pdfpage.add_root(pageroot, [], pdf0)
  assert_eq(@pdfpage.pages_of_pagetree(pdf).length(), 2)
  match @pdfpage.page_object_number(pdf, 1) {
    Some(n) => assert_true(n > 0)
    _ => fail("expected page object number")
  }
}

///|
test "pdf_of_pages extracts subset" {
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let pages = [
    @pdfpage.custompage(rect),
    @pdfpage.custompage(rect),
    @pdfpage.custompage(rect),
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
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let base_page = @pdfpage.custompage(rect)
  let base_ops = [@pdfops.Op::Opq, @pdfops.Op::OpQ]
  let page = Page::{
    content: [@pdfops.stream_of_ops(base_ops)],
    mediabox: base_page.mediabox,
    resources: base_page.resources,
    rotate: base_page.rotate,
    rest: base_page.rest,
  }
  let pre = @pdfpage.prepend_operators(pdf, [@pdfops.Op::Opw(2.0)], page)
  let ops_pre = @pdfops.parse_operators(pdf, pre.resources, pre.content)
  match ops_pre[0] {
    @pdfops.Op::Opw(2.0) => ()
    _ => fail("expected prepend to be first")
  }
  let post = @pdfpage.postpend_operators(pdf, [@pdfops.Op::Opw(3.0)], pre)
  let ops_post = @pdfops.parse_operators(pdf, post.resources, post.content)
  let last = ops_post[ops_post.length() - 1]
  match last {
    @pdfops.Op::Opw(3.0) => ()
    _ => fail("expected postpend to be last")
  }
}

///|
test "rotation_of_int rejects invalid" {
  let res : Result[@pdfpage.Rotation, Error] = try? @pdfpage.rotation_of_int(13)
  match res {
    Err(_) => ()
    _ => fail("expected error")
  }
}

///|
test "fixup_duplicate_pages creates unique refs" {
  let pdf0 = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let page = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Page")),
    ("/MediaBox", rect),
    ("/Parent", @pdf.PdfObject::Indirect(2)),
  ])
  let pages = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Pages")),
    (
      "/Kids",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Indirect(1),
        @pdf.PdfObject::Indirect(1),
      ]),
    ),
    ("/Count", @pdf.PdfObject::Integer(2)),
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
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let page = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Page")),
    ("/Parent", @pdf.PdfObject::Indirect(2)),
  ])
  let pages = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Pages")),
    ("/Kids", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(1)])),
    ("/Count", @pdf.PdfObject::Integer(1)),
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
  let resources = @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("/F1", @pdf.PdfObject::Null)])),
  ])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F1", 12.0),
    @pdfops.Op::OpTj("Hi"),
    @pdfops.Op::OpET,
  ]
  let page : @pdfpage.Page = {
    content: [@pdfops.stream_of_ops(ops)],
    mediabox: @pdf.PdfObject::Array([
      @pdf.PdfObject::Real(0.0),
      @pdf.PdfObject::Real(0.0),
      @pdf.PdfObject::Real(100.0),
      @pdf.PdfObject::Real(100.0),
    ]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let updated = @pdfpage.renumber_pages(pdf, [page])
  let renamed = updated[0]
  match @pdf.lookup_direct(pdf, "/Font", renamed.resources) {
    Some(@pdf.PdfObject::Dictionary(entries)) => {
      assert_eq(entries.length(), 1)
      assert_true(entries[0].0 != "/F1")
    }
    _ => fail("expected renamed font dictionary")
  }
  let ops_updated = @pdfops.parse_operators(
    pdf,
    renamed.resources,
    renamed.content,
  )
  match ops_updated {
    [@pdfops.Op::OpBT, @pdfops.Op::OpTf(name, _), ..] =>
      assert_true(name != "/F1")
    _ => fail("expected renamed font operator")
  }
}

///|
test "add_prefix rewrites resources and content" {
  let pdf0 = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("/F1", @pdf.PdfObject::Null)])),
  ])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F1", 12.0),
    @pdfops.Op::OpTj("Hi"),
    @pdfops.Op::OpET,
  ]
  let page : @pdfpage.Page = {
    content: [@pdfops.stream_of_ops(ops)],
    mediabox: @pdf.PdfObject::Array([
      @pdf.PdfObject::Real(0.0),
      @pdf.PdfObject::Real(0.0),
      @pdf.PdfObject::Real(100.0),
      @pdf.PdfObject::Real(100.0),
    ]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  @pdfpage.add_prefix(pdf, "p")
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let page0 = pages[0]
  match @pdf.lookup_direct(pdf, "/Font", page0.resources) {
    Some(@pdf.PdfObject::Dictionary(entries)) => {
      assert_eq(entries.length(), 1)
      assert_eq(entries[0].0, "/pF1")
    }
    _ => fail("expected prefixed font dictionary")
  }
  let ops_updated = @pdfops.parse_operators(pdf, page0.resources, page0.content)
  match ops_updated {
    [@pdfops.Op::OpBT, @pdfops.Op::OpTf(name, _), ..] => assert_eq(name, "/pF1")
    _ => fail("expected prefixed font operator")
  }
}

///|
test "shortest_unused_prefix skips used names" {
  let pdf0 = @pdf.empty()
  let resources = @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("/a1", @pdf.PdfObject::Null)])),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: @pdf.PdfObject::Array([
      @pdf.PdfObject::Real(0.0),
      @pdf.PdfObject::Real(0.0),
      @pdf.PdfObject::Real(100.0),
      @pdf.PdfObject::Real(100.0),
    ]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  assert_eq(@pdfpage.shortest_unused_prefix(pdf), "b")
}

///|
test "change_pages rewrites annotation and openaction" {
  let pdf0 = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let page = @pdfpage.custompage(rect)
  let (pdf1, pageroot) = @pdfpage.add_pagetree([page], pdf0)
  let pdf = @pdfpage.add_root(pageroot, [], pdf1)
  let refs = @pdf.page_reference_numbers(pdf)
  let dest_array = @pdf.PdfObject::Array([
    @pdf.PdfObject::Indirect(refs[0]),
    @pdf.PdfObject::Name("/XYZ"),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(20.0),
    @pdf.PdfObject::Real(1.0),
  ])
  let annot_dest = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Link")),
    ("/Dest", dest_array),
  ])
  let annot_action = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Link")),
    (
      "/A",
      @pdf.PdfObject::Dictionary([
        ("/S", @pdf.PdfObject::Name("/GoTo")),
        ("/D", dest_array),
      ]),
    ),
  ])
  let annot1 = @pdf.addobj(pdf, annot_dest)
  let annot2 = @pdf.addobj(pdf, annot_action)
  let page_obj = @pdf.lookup_obj(pdf, refs[0])
  let updated_page = @pdf.add_dict_entry(
    page_obj,
    "/Annots",
    @pdf.PdfObject::Array([
      @pdf.PdfObject::Indirect(annot1),
      @pdf.PdfObject::Indirect(annot2),
    ]),
  )
  @pdf.addobj_given_num(pdf, (refs[0], updated_page))
  let catalog = @pdf.catalog_of_pdf(pdf)
  let updated_catalog = @pdf.add_dict_entry(catalog, "/OpenAction", dest_array)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_catalog))
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let translated = @pdfpage.change_pages(true, pdf, pages, matrices=[
    (1, @pdftransform.mktranslate(5.0, -3.0)),
  ])
  let catalog2 = @pdf.catalog_of_pdf(translated)
  let openaction = match @pdf.lookup_direct(translated, "/OpenAction", catalog2) {
    Some(dest) => dest
    None => fail("expected OpenAction")
  }
  match @pdfdest.read_destination(translated, openaction) {
    @pdfdest.Destination::XYZ(_, Some(left), Some(top), _) => {
      assert_close(left, 15.0)
      assert_close(top, 17.0)
    }
    _ => fail("expected updated openaction destination")
  }
  let refs2 = @pdf.page_reference_numbers(translated)
  let page2 = @pdf.lookup_obj(translated, refs2[0])
  let annots = match @pdf.lookup_direct(translated, "/Annots", page2) {
    Some(@pdf.PdfObject::Array(arr)) => arr
    _ => fail("expected annots")
  }
  for annot in annots {
    match annot {
      @pdf.PdfObject::Indirect(i) => {
        let obj = @pdf.lookup_obj(translated, i)
        let dest = match @pdf.lookup_direct(translated, "/Dest", obj) {
          Some(d) => d
          None =>
            match @pdf.lookup_direct(translated, "/A", obj) {
              Some(@pdf.PdfObject::Dictionary(_) as act) =>
                match @pdf.lookup_direct(translated, "/D", act) {
                  Some(d) => d
                  _ => fail("expected action dest")
                }
              _ => fail("expected action")
            }
        }
        match @pdfdest.read_destination(translated, dest) {
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
