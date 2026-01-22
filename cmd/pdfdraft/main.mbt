///|
fn isimage(pdf : @pdf.Pdf, xobj : @pdf.PdfObject) -> Bool {
  @pdf.lookup_direct(pdf, "/Subtype", xobj)
  is Some(@pdf.PdfObject::Name("/Image"))
}

///|
fn xobject_isimage(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  name : String,
) -> Bool raise {
  match resources {
    Dictionary(_) =>
      match @pdf.lookup_direct(pdf, "/XObject", resources) {
        Some(xobjects) => {
          let xobj = @pdf.lookup_fail("xobject not there", pdf, name, xobjects)
          isimage(pdf, xobj)
        }
        _ => false
      }
    _ => raise @pdf.PdfError::Msg("bad resources")
  }
}

///|
fn remove_image_xobjects(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  match resources {
    Dictionary(_) =>
      match @pdf.lookup_direct(pdf, "/XObject", resources) {
        Some(Dictionary(xobjects)) => {
          let out = Array::new(capacity=xobjects.length())
          for entry in xobjects {
            if !isimage(pdf, entry.1) {
              out.push(entry)
            }
          }
          @pdf.replace_dict_entry(resources, "/XObject", Dictionary(out))
        }
        _ => resources
      }
    _ => raise @pdf.PdfError::Msg("bad resources")
  }
}

///|
let substitute : Array[@pdfops.Op] = [
  Opq,
  Opw(0.0),
  OpG(0.0),
  Opre(0.0, 0.0, 1.0, 1.0),
  Opm(0.0, 0.0),
  Opl(1.0, 1.0),
  Opm(0.0, 1.0),
  Opl(1.0, 0.0),
  OpS,
  OpQ,
]

///|
fn append_ops(out : Array[@pdfops.Op], ops : Array[@pdfops.Op]) -> Unit {
  for op in ops {
    out.push(op)
  }
}

///|
fn remove_images_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  ops : Array[@pdfops.Op],
) -> Array[@pdfops.Op] raise {
  let out = Array::new(capacity=ops.length())
  for op in ops {
    match (op : @pdfops.Op) {
      OpDo(name) =>
        if xobject_isimage(pdf, resources, name) {
          append_ops(out, substitute)
        } else {
          out.push(op)
        }
      InlineImage(_) => append_ops(out, substitute)
      _ => out.push(op)
    }
  }
  out
}

///|
fn remove_images_page(
  pdf : @pdf.Pdf,
  page : @pdfpage.Page,
) -> @pdfpage.Page raise {
  let content = remove_images_stream(
    pdf,
    page.resources,
    @pdfops.parse_operators(pdf, page.resources, page.content),
  )
  let stream = @pdfops.stream_of_ops(content)
  @pdfcodec.encode_pdfstream(pdf, @pdfcodec.Encoding::Flate, stream)
  {
    content: [stream],
    mediabox: page.mediabox,
    resources: remove_image_xobjects(pdf, page.resources),
    rotate: page.rotate,
    rest: page.rest,
  }
}

///|
fn remove_images(pdf : @pdf.Pdf) -> @pdf.Pdf raise {
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let pages_out = Array::new(capacity=pages.length())
  for page in pages {
    pages_out.push(remove_images_page(pdf, page))
  }
  let (pdf, pagetree_num) = @pdfpage.add_pagetree(pages_out, pdf)
  @pdfpage.add_root(pagetree_num, [], pdf)
}

///|
async fn main {
  let args = @env.args()
  if args.length() != 3 {
    println("Syntax: pdfdraft <input> <output>")
    return
  }
  let in_file = args[1]
  let out_file = args[2]
  try {
    let pdf = @pdfread.pdf_of_file(None, None, in_file)
    @pdfwrite.pdf_to_file(remove_images(pdf), out_file)
  } catch {
    err => {
      println("Failed to produce output.")
      println(err)
    }
  }
}
