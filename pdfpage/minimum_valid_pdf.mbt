///|
/// Build a minimal PDF with a single blank page.
pub fn minimum_valid_pdf() -> @pdf.Pdf raise {
  let pages = [blankpage(@pdfpaper.a4)]
  let (pdf, pageroot) = add_pagetree(pages, @pdf.empty())
  add_root(pageroot, [], pdf)
}
