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
