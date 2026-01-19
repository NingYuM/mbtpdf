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
