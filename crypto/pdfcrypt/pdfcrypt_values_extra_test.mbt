///|
fn bytes_string(len : Int, value : Int) -> String {
  @pdfio.string_of_int_array(Array::make(len, value))
}

///|
fn add_id(pdf : @pdf.Pdf) -> Unit raise {
  let id : @pdf.PdfObject = Array([String("id"), String("id")])
  pdf.trailerdict = @pdf.add_dict_entry(pdf.trailerdict, "/ID", id)
}

///|
fn attach_encrypt(pdf : @pdf.Pdf, encrypt_dict : @pdf.PdfObject) -> Unit raise {
  pdf.trailerdict = @pdf.add_dict_entry(
    pdf.trailerdict,
    "/Encrypt",
    encrypt_dict,
  )
}

///|
test "get_encryption_values handles V2 without length" {
  let pdf = @pdfpage.minimum_valid_pdf()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name("/Standard")),
    ("/V", Integer(2)),
    ("/R", Integer(3)),
    ("/O", String(bytes_string(32, 65))),
    ("/U", String(bytes_string(32, 66))),
    ("/P", Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let (crypt_type, _, _, _, _, _, _) = @pdfcrypt.get_encryption_values(pdf)
  match crypt_type {
    @pdfcryptprimitives.Encryption::ARC4(40, 3) => ()
    _ => fail("expected ARC4 40 r3")
  }
}

///|
test "get_encryption_values rejects invalid length" {
  let pdf = @pdfpage.minimum_valid_pdf()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name("/Standard")),
    ("/V", Integer(2)),
    ("/R", Integer(3)),
    ("/Length", Integer(42)),
    ("/O", String(bytes_string(32, 65))),
    ("/U", String(bytes_string(32, 66))),
    ("/P", Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values handles V4 CF V2 length" {
  let pdf = @pdfpage.minimum_valid_pdf()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name("/Standard")),
    ("/V", Integer(4)),
    ("/R", Integer(4)),
    ("/Length", Integer(64)),
    ("/CF", Dictionary([("/StdCF", Dictionary([("/CFM", Name("/V2"))]))])),
    ("/O", String(bytes_string(32, 65))),
    ("/U", String(bytes_string(32, 66))),
    ("/P", Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let (crypt_type, _, _, _, _, _, _) = @pdfcrypt.get_encryption_values(pdf)
  match crypt_type {
    @pdfcryptprimitives.Encryption::ARC4(64, 4) => ()
    _ => fail("expected ARC4 64 r4")
  }
}

///|
test "get_encryption_values rejects missing stdcf" {
  let pdf = @pdfpage.minimum_valid_pdf()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name("/Standard")),
    ("/V", Integer(4)),
    ("/R", Integer(4)),
    ("/CF", Dictionary([("/Other", Dictionary([]))])),
    ("/O", String(bytes_string(32, 65))),
    ("/U", String(bytes_string(32, 66))),
    ("/P", Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values rejects unknown cfm" {
  let pdf = @pdfpage.minimum_valid_pdf()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name("/Standard")),
    ("/V", Integer(4)),
    ("/R", Integer(4)),
    ("/CF", Dictionary([("/StdCF", Dictionary([("/CFM", Name("/Unknown"))]))])),
    ("/O", String(bytes_string(32, 65))),
    ("/U", String(bytes_string(32, 66))),
    ("/P", Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values rejects missing id entry" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let encrypt_dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name("/Standard")),
    ("/V", Integer(2)),
    ("/R", Integer(3)),
    ("/O", String(bytes_string(32, 65))),
    ("/U", String(bytes_string(32, 66))),
    ("/P", Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "encrypt AES V2 without metadata and AES256 with long passwords" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_AES(false, "user", "owner", [], pdf)
  let (dec, _) = @pdfcrypt.decrypt_pdf("user", @pdf.deep_copy(enc))
  assert_true(dec is Some(_))
  let string_obj : @pdf.PdfObject = String("secret")
  @pdf.addobj_given_num(pdf, (10, string_obj))
  let stream_dict : @pdf.PdfObject = Dictionary([("/Length", Integer(4))])
  let got_stream : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(@pdfio.bytes_of_string("data")))),
  )
  @pdf.addobj_given_num(pdf, (11, got_stream))
  let input = @pdfio.input_of_string("data", source="stream")
  let toget = @pdf.ToGet::new(input, 0, 4)
  let toget_stream : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::ToGet(toget))),
  )
  @pdf.addobj_given_num(pdf, (12, toget_stream))
  let long_pw = "a".repeat(130)
  let enc256 = @pdfcrypt.encrypt_pdf_AES256(true, long_pw, long_pw, [], pdf)
  let (dec256, _) = @pdfcrypt.decrypt_pdf(long_pw, @pdf.deep_copy(enc256))
  assert_true(dec256 is Some(_))
}
