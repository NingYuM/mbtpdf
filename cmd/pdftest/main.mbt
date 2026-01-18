///|
fn rebuild_page(pdf : @pdf.Pdf, page : @pdfpage.Page) -> @pdfpage.Page raise {
  let ops = @pdfops.parse_operators(pdf, page.resources, page.content)
  let stream = @pdfops.stream_of_ops(ops)
  {
    content: [stream],
    mediabox: page.mediabox,
    resources: page.resources,
    rotate: page.rotate,
    rest: page.rest,
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() != 3 {
    println("Syntax: pdftest <input> <output>")
    return
  }
  let in_name = args[1]
  let out_name = args[2]
  try {
    let pdf = @pdfread.pdf_of_file(None, None, in_name)
    if @pdfcrypt.is_encrypted(pdf) {
      fail("File is encrypted.")
    }
    let pages = @pdfpage.pages_of_pagetree(pdf)
    let rebuilt = Array::new()
    for page in pages {
      rebuilt.push(rebuild_page(pdf, page))
    }
    let pdf = @pdfpage.change_pages(true, pdf, rebuilt)
    @pdf.remove_unreferenced(pdf)
    @pdfwrite.pdf_to_file(pdf, out_name)
  } catch {
    err => {
      println("Test failed:")
      println(err)
    }
  }
}
