///|
async fn main {
  let args = @env.args()
  if args.length() != 3 {
    println("Syntax: pdfdecomp <input> <output>")
    return
  }
  let in_file = args[1]
  let out_file = args[2]
  try {
    let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, in_file)
    pdf.objiter((_, obj) => match obj {
      Stream(_) =>
        @pdfcodec.PdfCodec::new().decode_pdfstream_until_unknown(pdf, obj)
      _ => ()
    })
    @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, out_file)
  } catch {
    err => {
      println("Failed to decompress file.")
      println(err)
    }
  }
}
