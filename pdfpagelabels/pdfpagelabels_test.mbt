///|
test "pagelabeltext roman" {
  let labels = [
    PageLabel::{
      labelstyle: LabelStyle::LowercaseRoman,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
  ]
  let text = pagelabeltext_of_pagenumber(4, labels)
  assert_eq(text, "iv")
}

///|
test "pagelabel_of_pagenumber" {
  let labels = [
    PageLabel::{
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
  ]
  let label = pagelabel_of_pagenumber(5, labels)
  assert_eq(label.startpage, 5)
  assert_eq(label.startvalue, 5)
}

///|
fn make_pdf_with_pages(count : Int) -> @pdf.Pdf raise {
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let pages = Array::new(capacity=count)
  let mut i = 0
  while i < count {
    pages.push(@pdfpage.custompage(rect))
    i = i + 1
  }
  let (pdf0, pageroot) = @pdfpage.add_pagetree(pages, @pdf.empty())
  @pdfpage.add_root(pageroot, [], pdf0)
}

///|
test "coalesce labels" {
  let labels = [
    PageLabel::{
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
    PageLabel::{
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: None,
      startpage: 3,
      startvalue: 3,
    },
    PageLabel::{
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: Some("A"),
      startpage: 5,
      startvalue: 5,
    },
  ]
  let merged = coalesce(labels)
  assert_eq(merged.length(), 2)
  assert_eq(merged[0].startpage, 1)
  match merged[1].labelprefix {
    Some("A") => ()
    _ => fail("expected prefix A")
  }
}

///|
test "complete labels" {
  let labels = [
    PageLabel::{
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: None,
      startpage: 3,
      startvalue: 1,
    },
  ]
  let completed = complete(labels)
  assert_eq(completed.length(), 2)
  assert_eq(completed[0].startpage, 1)
}

///|
test "string_of_labelstyle and pagelabel string" {
  assert_eq(
    string_of_labelstyle(LabelStyle::UppercaseLetters),
    "UppercaseLetters",
  )
  let label = PageLabel::{
    labelstyle: LabelStyle::LowercaseRoman,
    labelprefix: Some("P"),
    startpage: 2,
    startvalue: 5,
  }
  let text = string_of_pagelabel(label)
  assert_true(text.contains("LowercaseRoman"))
  assert_true(text.contains("labelprefix: P"))
}

///|
test "pagelabeltext with prefix and letters" {
  let labels = [
    PageLabel::{
      labelstyle: LabelStyle::UppercaseLetters,
      labelprefix: Some("Sec-"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  assert_eq(pagelabeltext_of_pagenumber(1, labels), "Sec-A")
  assert_eq(pagelabeltext_of_pagenumber(27, labels), "Sec-AA")
}

///|
test "add_label inserts replica" {
  let labels = [
    PageLabel::{
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
  ]
  let inserted = add_label(
    6,
    labels,
    PageLabel::{
      labelstyle: LabelStyle::UppercaseRoman,
      labelprefix: None,
      startpage: 3,
      startvalue: 1,
    },
    4,
  )
  assert_eq(inserted.length(), 3)
  assert_eq(inserted[1].startpage, 3)
  assert_eq(inserted[2].startpage, 5)
  assert_eq(inserted[2].startvalue, 5)
}

///|
test "merge_pagelabels combines ranges" {
  let pdf1 = make_pdf_with_pages(2)
  let pdf2 = make_pdf_with_pages(1)
  let labels1 = [
    PageLabel::{
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: Some("A"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  let labels2 = [
    PageLabel::{
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: Some("B"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.write(pdf1, labels1)
  @pdfpagelabels.write(pdf2, labels2)
  let merged = merge_pagelabels([pdf1, pdf2], [[1, 2], [1]])
  assert_eq(merged.length(), 2)
  match merged[0].labelprefix {
    Some("A") => ()
    _ => fail("expected prefix A")
  }
  assert_eq(merged[0].startpage, 1)
  match merged[1].labelprefix {
    Some("B") => ()
    _ => fail("expected prefix B")
  }
  assert_eq(merged[1].startpage, 3)
}

///|
test "write/read pagelabels roundtrip" {
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
  let labels = [
    PageLabel::{
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: Some("A"),
      startpage: 1,
      startvalue: 1,
    },
    PageLabel::{
      labelstyle: LabelStyle::LowercaseRoman,
      labelprefix: None,
      startpage: 3,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.write(pdf, labels)
  let read_back = @pdfpagelabels.read(pdf)
  assert_eq(read_back.length(), 2)
  match read_back[0].labelprefix {
    Some("A") => ()
    _ => fail("expected prefix A")
  }
  assert_eq(read_back[1].startpage, 3)
  @pdfpagelabels.remove(pdf)
  assert_eq(@pdfpagelabels.read(pdf).length(), 0)
}
