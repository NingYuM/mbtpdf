///|
fn page_count(pdf : @pdf.Pdf) -> Int raise {
  @pdfpage.pages_of_pagetree(pdf).length()
}

///|
test "encrypt/decrypt AES256 roundtrip" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_AES256(true, "user", "owner", [], pdf)
  assert_true(@pdfcrypt.is_encrypted(enc))
  let (dec, perms) = @pdfcrypt.decrypt_pdf("user", @pdf.deep_copy(enc))
  match dec {
    Some(pdf_dec) => assert_eq(page_count(pdf_dec), 1)
    _ => fail("expected decrypted pdf")
  }
  assert_eq(perms.length(), 0)
  let (bad, _) = @pdfcrypt.decrypt_pdf("wrong", @pdf.deep_copy(enc))
  match bad {
    None => ()
    _ => fail("expected wrong password to fail")
  }
  let owner = @pdfcrypt.decrypt_pdf_owner("owner", @pdf.deep_copy(enc))
  match owner {
    Some(_) => ()
    _ => fail("expected owner decrypt")
  }
}

///|
test "encrypt/decrypt AES256 ISO roundtrip" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_AES256ISO(false, "user", "owner", [], pdf)
  assert_true(@pdfcrypt.is_encrypted(enc))
  let (dec, _) = @pdfcrypt.decrypt_pdf("user", @pdf.deep_copy(enc))
  match dec {
    Some(pdf_dec) => assert_eq(page_count(pdf_dec), 1)
    _ => fail("expected decrypted pdf")
  }
}
