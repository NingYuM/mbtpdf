///|
/// Hook for page-tree traversal (re-exported from pdf).
let endpage : Ref[(@pdf.Pdf) -> Int] = @pdf.endpage

///|
/// Register pdf_of_file hook for decoder modules.
async fn pdf_of_file_unlabeled(
  revision : Int?,
  user_password : String?,
  owner_password : String?,
  filename : String,
) -> @pdf.Pdf {
  match revision {
    Some(r) => pdf_of_file(revision=r, user_password, owner_password, filename)
    None => pdf_of_file(user_password, owner_password, filename)
  }
}

///|
fn init {
  @pdfcodec.pdf_of_file.val = pdf_of_file_unlabeled
}
