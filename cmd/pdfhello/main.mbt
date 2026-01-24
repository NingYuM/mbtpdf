///|
async fn main {
  try {
    let font = @pdf.PdfObject::Dictionary([
      ("/Type", @pdf.PdfObject::Name("/Font")),
      ("/Subtype", @pdf.PdfObject::Name("/Type1")),
      ("/BaseFont", @pdf.PdfObject::Name("/Times-Italic")),
    ])
    let ops : Array[@pdfops.Op] = [
      Opcm(
        @pdftransform.Transform::new([
          @pdftransform.TransformOp::Translate(50.0, 770.0),
        ]).to_matrix(),
      ),
      OpBT,
      OpTf("/F0", 36.0),
      OpTj("Hello, World!"),
      OpET,
    ]
    let stream = @pdfops.stream_of_ops(ops)
    let page : @pdfpage.Page = {
      content: [stream],
      mediabox: @pdfpage.Page::blank(@pdfpaper.a4).mediabox,
      resources: @pdf.PdfObject::Dictionary([
        ("/Font", @pdf.PdfObject::Dictionary([("/F0", font)])),
      ]),
      rotate: @pdfpage.Rotation::Rotate0,
      rest: @pdf.PdfObject::Dictionary([]),
    }
    let (pdf, pageroot) = @pdfpage.add_pagetree([page], @pdf.empty())
    let pdf = @pdfpage.add_root(pageroot, [], pdf)
    @pdfwrite.pdf_to_file(pdf, "hello.pdf")
  } catch {
    err => {
      println("Failed to produce output.")
      println(err)
    }
  }
}
