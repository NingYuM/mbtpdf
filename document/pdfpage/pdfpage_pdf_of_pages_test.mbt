///|
fn pdf_of_pages_rect() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)])
}

///|
fn pdf_of_pages_make_pdf(count : Int) -> @pdf.Pdf raise {
  let rect = pdf_of_pages_rect()
  let pages = Array::new(capacity=count)
  for _ in 0..<count {
    pages.push(@pdfpage.Page::custom(rect))
  }
  let (pdf0, pageroot) = @pdfpage.add_pagetree(pages, @pdf.Pdf::empty())
  @pdfpage.add_root(pageroot, [], pdf0)
}

///|
fn pdf_of_pages_with_bookmarks(count : Int) -> @pdf.Pdf raise {
  let pdf = pdf_of_pages_make_pdf(count)
  let refs = @pdf.page_reference_numbers(pdf)
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Root",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(refs[0]),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "Child",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(refs[1]),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "Other",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(refs[2]),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
}

///|
test "pdf_of_pages rejects empty range" {
  let pdf = pdf_of_pages_make_pdf(1)
  let res : Result[@pdf.Pdf, Error] = try? @pdfpage.pdf_of_pages(pdf, [])
  match res {
    Err(_) => ()
    _ => fail("expected error for empty range")
  }
}

///|
test "pdf_of_pages errors on invalid page index" {
  let pdf = pdf_of_pages_make_pdf(2)
  let res : Result[@pdf.Pdf, Error] = try? @pdfpage.pdf_of_pages(pdf, [3])
  match res {
    Err(_) => ()
    _ => fail("expected invalid page error")
  }
}

///|
test "pdf_of_pages builds pagetree for many pages" {
  let pdf = pdf_of_pages_make_pdf(12)
  let subset = @pdfpage.pdf_of_pages(pdf, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
  let root = @pdf.catalog_of_pdf(subset)
  let pages = match @pdf.lookup_direct(subset, "/Pages", root) {
    Some(obj) => obj
    None => fail("expected /Pages")
  }
  match (@pdf.lookup_direct(subset, "/Type", pages) : @pdf.PdfObject?) {
    Some(Name("/Pages")) => ()
    _ => fail("expected /Type /Pages")
  }
  let count = match
    (@pdf.lookup_direct(subset, "/Count", pages) : @pdf.PdfObject?) {
    Some(Integer(n)) => n
    _ => fail("expected /Count")
  }
  assert_eq(count, 11)
}

///|
test "pdf_of_pages keeps bookmark prefix chain" {
  let pdf = pdf_of_pages_with_bookmarks(3)
  let subset = @pdfpage.pdf_of_pages(pdf, [2])
  let marks = @pdfmarks.PdfMarks::new(subset).read_bookmarks()
  assert_eq(marks.length(), 2)
  assert_eq(marks[0].text, "Root")
  assert_eq(marks[1].text, "Child")
}

///|
test "pdf_of_pages retains page labels when requested" {
  let pdf = pdf_of_pages_make_pdf(3)
  let labels = [
    @pdfpagelabels.PageLabel::{
      labelstyle: @pdfpagelabels.LabelStyle::DecimalArabic,
      labelprefix: Some("A"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.PageLabel::write_all(labels, pdf)
  let subset = @pdfpage.pdf_of_pages(pdf, [1, 2], retain_numbering=true)
  let read_back = @pdfpagelabels.PageLabel::read_all(subset)
  assert_true(read_back.length() > 0)
}

///|
test "pdf_of_pages trims structure tree" {
  let pdf = pdf_of_pages_make_pdf(2)
  let struct_tree : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/StructTreeRoot")),
  ])
  let struct_num = @pdf.addobj(pdf, struct_tree)
  let root = @pdf.catalog_of_pdf(pdf)
  let updated_root = root.add_entry("/StructTreeRoot", Indirect(struct_num))
  @pdf.addobj_given_num(pdf, (pdf.root, updated_root))
  let subset = @pdfpage.pdf_of_pages(pdf, [1], process_struct_tree=true)
  let root2 = @pdf.catalog_of_pdf(subset)
  match @pdf.lookup_direct(subset, "/StructTreeRoot", root2) {
    Some(_) => ()
    None => fail("expected StructTreeRoot to remain")
  }
}

///|
test "pdf_of_pages fails without root" {
  let pdf = @pdf.Pdf::empty()
  let res : Result[@pdf.Pdf, Error] = try? @pdfpage.pdf_of_pages(pdf, [1])
  match res {
    Err(_) => ()
    _ => fail("expected missing /Root error")
  }
}

///|
test "endpage_fast handles missing count" {
  let pdf0 = @pdf.Pdf::empty()
  let rect = pdf_of_pages_rect()
  let page : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/Page")),
    ("/MediaBox", rect),
  ])
  let page_num = @pdf.addobj(pdf0, page)
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name("/Pages")),
    ("/Kids", Array([Indirect(page_num)])),
  ])
  let pages_num = @pdf.addobj(pdf0, pages)
  let pdf = @pdfpage.add_root(pages_num, [], pdf0)
  assert_eq(@pdfpage.endpage_fast(pdf), 0)
}
