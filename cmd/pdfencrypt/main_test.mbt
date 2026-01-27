///|
async fn cleanup(path : String) -> Unit {
  let _ : Result[Unit, Error] = try? @fs.remove(path)

}

///|
async test "run encrypts input pdf" {
  run(["pdfencrypt"])
  let in_file = "cmd_pdfencrypt_in.pdf"
  let out_file = "cmd_pdfencrypt_out.pdf"
  cleanup(in_file)
  cleanup(out_file)
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, in_file)
  run(["pdfencrypt", in_file, out_file, "owner"])
  assert_true(@fs.exists(out_file))
  let encrypted = @pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, out_file)
  assert_true(@pdfcrypt.PdfCrypt::new().is_encrypted(encrypted))
  cleanup(in_file)
  cleanup(out_file)
}
