///|
fn rebuild_page(pdf : @pdf.Pdf, page : @pdfpage.Page) -> @pdfpage.Page raise {
  let ops = @pdfops.Op::parse_operators(pdf, page.resources, page.content)
  let stream = @pdfops.Op::stream_of_ops(ops)
  {
    content: [stream],
    mediabox: page.mediabox,
    resources: page.resources,
    rotate: page.rotate,
    rest: page.rest,
  }
}

///|
async fn main {
  let args = @env.args()
  if args.length() != 3 {
    println("Syntax: pdftest <input> <output>")
    return
  }
  let in_name = args[1]
  let out_name = args[2]
  try {
    let file = @fs.open(in_name, mode=ReadOnly)
    let size = file.size().to_int()
    let data = file.read_exactly(size)
    file.close()
    let bytes = data.to_array()
    let input = @pdfio.input_of_bytes(bytes, source=in_name)
    let pdf = @pdfread.pdf_of_input(None, None, input)
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
    let (output, buffer) = @pdfio.input_output_of_bytes(1024)
    @pdfwrite.pdf_to_output(None, true, pdf, output)
    let out_bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
    @fs.write_file(out_name, Bytes::from_array(out_bytes))
  } catch {
    err => {
      println("Test failed:")
      println(err)
    }
  }
}
