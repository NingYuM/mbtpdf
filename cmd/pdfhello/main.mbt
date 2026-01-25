///|
async fn main {
  try {
    let font = @pdf.PdfObject::Dictionary([
      ("/Type", Name("/Font")),
      ("/Subtype", Name("/Type1")),
      ("/BaseFont", Name("/Times-Italic")),
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
    let stream = @pdfops.Op::stream_of_ops(ops)
    let page : @pdfpage.Page = {
      content: [stream],
      mediabox: @pdfpage.Page::blank(@pdfpaper.a4).mediabox,
      resources: Dictionary([("/Font", Dictionary([("/F0", font)]))]),
      rotate: @pdfpage.Rotation::Rotate0,
      rest: Dictionary([]),
    }
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
        page,
      ],
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    @pdfwrite.PdfWrite::new().pdf_to_file(pdf, "hello.pdf")
  } catch {
    err => {
      println("Failed to produce output.")
      println(err)
    }
  }
}
