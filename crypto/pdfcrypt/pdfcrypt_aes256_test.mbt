///|
fn page_count(pdf : @pdf.Pdf) -> Int raise {
  @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree().length()
}

///|
test "encrypt/decrypt AES256 roundtrip" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    pdf,
  )
  assert_true(@pdfcrypt.PdfCrypt::new().is_encrypted(enc))
  let (dec, perms) = @pdfcrypt.PdfCrypt::new().decrypt_pdf(
    "user",
    @pdf.deep_copy(enc),
  )
  match dec {
    Some(pdf_dec) => assert_eq(page_count(pdf_dec), 1)
    _ => fail("expected decrypted pdf")
  }
  assert_eq(perms.length(), 0)
  let (bad, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf(
    "wrong",
    @pdf.deep_copy(enc),
  )
  match bad {
    None => ()
    _ => fail("expected wrong password to fail")
  }
  let owner = @pdfcrypt.PdfCrypt::new().decrypt_pdf_owner(
    "owner",
    @pdf.deep_copy(enc),
  )
  match owner {
    Some(_) => ()
    _ => fail("expected owner decrypt")
  }
}

///|
test "encrypt/decrypt AES256 ISO roundtrip" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256ISO(
    false,
    "user",
    "owner",
    [],
    pdf,
  )
  assert_true(@pdfcrypt.PdfCrypt::new().is_encrypted(enc))
  let (dec, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf(
    "user",
    @pdf.deep_copy(enc),
  )
  match dec {
    Some(pdf_dec) => assert_eq(page_count(pdf_dec), 1)
    _ => fail("expected decrypted pdf")
  }
}
