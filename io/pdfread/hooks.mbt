///|
/// Register pdf_of_file hook for decoder modules.
async fn pdf_of_file_unlabeled(
  revision : Int?,
  user_password : String?,
  owner_password : String?,
  filename : String,
) -> @pdf.Pdf {
  let reader = PdfRead::new()
  match revision {
    Some(r) =>
      reader.pdf_of_file(revision=r, user_password, owner_password, filename)
    None => reader.pdf_of_file(user_password, owner_password, filename)
  }
}

///|
fn init {
  @pdfcodec.pdf_of_file.val = pdf_of_file_unlabeled
}
