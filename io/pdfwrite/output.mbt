///|
/// Write a PDF to a channel.
pub async fn PdfWrite::pdf_to_channel(
  self : PdfWrite,
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  encryption : Encryption?,
  build_new_id : Bool,
  pdf : @pdf.Pdf,
  channel : @fs.File,
) -> Unit {
  let output = @pdfio.Output::of_channel(channel)
  match recrypt {
    Some(value) =>
      self.pdf_to_output(
        preserve_objstm~,
        generate_objstm~,
        compress_objstm~,
        recrypt=value,
        encryption,
        build_new_id,
        pdf,
        output,
      )
    None =>
      self.pdf_to_output(
        preserve_objstm~,
        generate_objstm~,
        compress_objstm~,
        encryption,
        build_new_id,
        pdf,
        output,
      )
  }
  (output.flush)()
}

///|
/// Write a PDF to a file.
pub async fn PdfWrite::pdf_to_file_options(
  self : PdfWrite,
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  encryption : Encryption?,
  build_new_id : Bool,
  pdf : @pdf.Pdf,
  filename : String,
) -> Unit {
  let file = @fs.open(filename, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  match recrypt {
    Some(value) =>
      self.pdf_to_channel(
        preserve_objstm~,
        generate_objstm~,
        compress_objstm~,
        recrypt=value,
        encryption,
        build_new_id,
        pdf,
        file,
      )
    None =>
      self.pdf_to_channel(
        preserve_objstm~,
        generate_objstm~,
        compress_objstm~,
        encryption,
        build_new_id,
        pdf,
        file,
      )
  }
}

///|
/// Simple write to file.
pub async fn PdfWrite::pdf_to_file(
  self : PdfWrite,
  pdf : @pdf.Pdf,
  filename : String,
) -> Unit {
  self.pdf_to_file_options(
    preserve_objstm=true,
    generate_objstm=false,
    compress_objstm=true,
    None,
    true,
    pdf,
    filename,
  )
}
