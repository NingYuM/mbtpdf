///|
async fn main {
  let args = @env.args()
  if args.length() != 4 {
    println("Syntax: pdfencrypt <input> <output> <owner-password>")
    return
  }
  let in_file = args[1]
  let out_file = args[2]
  let owner_pw = args[3]
  try {
    let pdf = @pdfread.PdfRead::new().pdf_of_file(None, None, in_file)
    let banlist = [@pdfcrypt.Permission::NoEdit, @pdfcrypt.Permission::NoPrint]
    let encrypted = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES(
      false, "", owner_pw, banlist, pdf,
    )
    @pdfwrite.PdfWrite::new().pdf_to_file(encrypted, out_file)
  } catch {
    err => {
      println("Failed to produce output.")
      println(err)
    }
  }
}
