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

///|
test "encrypt/decrypt 128bit roundtrip" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_128bit("user", "owner", [], pdf)
  assert_true(@pdfcrypt.is_encrypted(enc))
  let (dec, perms) = @pdfcrypt.decrypt_pdf("user", @pdf.deep_copy(enc))
  match dec {
    Some(pdf_dec) => assert_eq(@pdfpage.pages_of_pagetree(pdf_dec).length(), 1)
    _ => fail("expected decrypted pdf")
  }
  assert_eq(perms.length(), 0)
  let (bad, _) = @pdfcrypt.decrypt_pdf("wrong", @pdf.deep_copy(enc))
  match bad {
    None => ()
    _ => fail("expected wrong password to fail")
  }
  let (crypt_type, _, _, _, _, _, _) = @pdfcrypt.get_encryption_values(enc)
  match crypt_type {
    @pdfcryptprimitives.Encryption::ARC4(128, 3) => ()
    _ => fail("expected ARC4 128 r3")
  }
}

///|
test "encrypt/decrypt AES V2 roundtrip" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_AES(true, "user", "owner", [], pdf)
  assert_true(@pdfcrypt.is_encrypted(enc))
  let (dec, perms) = @pdfcrypt.decrypt_pdf("user", @pdf.deep_copy(enc))
  match dec {
    Some(pdf_dec) => assert_eq(@pdfpage.pages_of_pagetree(pdf_dec).length(), 1)
    _ => fail("expected decrypted pdf")
  }
  assert_eq(perms.length(), 0)
  let (bad, _) = @pdfcrypt.decrypt_pdf("wrong", @pdf.deep_copy(enc))
  match bad {
    None => ()
    _ => fail("expected wrong password to fail")
  }
  let (crypt_type, _, _, _, _, _, _) = @pdfcrypt.get_encryption_values(enc)
  match crypt_type {
    @pdfcryptprimitives.Encryption::AESV2 => ()
    _ => fail("expected AESV2")
  }
}

///|
test "decrypt_pdf returns original when unencrypted" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let (dec, perms) = @pdfcrypt.decrypt_pdf("user", pdf)
  match dec {
    Some(_) => ()
    _ => fail("expected unencrypted pdf to pass through")
  }
  assert_eq(perms.length(), 0)
  let missing : Result[
    (
      @pdfcryptprimitives.Encryption,
      String,
      String,
      Int,
      String,
      String?,
      String?,
    ),
    Error,
  ] = try? @pdfcrypt.get_encryption_values(pdf)
  assert_true(missing is Err(_))
}

///|
test "recrypt_pdf requires correct password" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_AES256(true, "user", "owner", [], pdf)
  let reenc : Result[@pdf.Pdf, Error] = try? @pdfcrypt.recrypt_pdf(
    @pdf.deep_copy(enc),
    "user",
    renumber=false,
  )
  assert_true(reenc is Err(_))
  let bad : Result[@pdf.Pdf, Error] = try? @pdfcrypt.recrypt_pdf(
    @pdf.deep_copy(enc),
    "wrong",
    renumber=false,
  )
  assert_true(bad is Err(_))
}
