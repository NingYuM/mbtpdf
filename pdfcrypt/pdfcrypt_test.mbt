///|
test "banlist_of_p returns all permissions for zero" {
  let perms = @pdfcrypt.banlist_of_p(0)
  assert_eq(perms.length(), 8)
}

///|
test "encrypt/decrypt 40bit roundtrip" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_40bit("user", "owner", [], pdf)
  assert_true(@pdfcrypt.is_encrypted(enc))
  let (dec, perms) = @pdfcrypt.decrypt_pdf("user", enc)
  match dec {
    Some(_) => ()
    _ => fail("expected decrypted pdf")
  }
  assert_eq(perms.length(), 0)
  let owner = @pdfcrypt.decrypt_pdf_owner("owner", enc)
  match owner {
    Some(_) => ()
    _ => fail("expected owner decrypt")
  }
}
