///|
/// Build a minimal PDF with a single blank page.
pub fn minimum_valid_pdf() -> @pdf.Pdf raise {
  let pages = [Page::blank(@pdfpaper.a4)]
  let (pdf, pageroot) = add_pagetree(pages, @pdf.Pdf::empty())
  add_root(pageroot, [], pdf)
}
