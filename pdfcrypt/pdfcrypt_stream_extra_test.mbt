///|
fn replace_encrypt_entry(
  pdf : @pdf.Pdf,
  updated : @pdf.PdfObject,
) -> Unit raise {
  match @pdf.lookup_immediate("/Encrypt", pdf.trailerdict) {
    Some(@pdf.PdfObject::Indirect(n)) =>
      @pdf.addobj_given_num(pdf, (n, updated))
    _ => fail("expected /Encrypt indirect reference")
  }
}

///|
fn update_perms(pdf : @pdf.Pdf, perms : String) -> Unit raise {
  match @pdf.lookup_immediate("/Encrypt", pdf.trailerdict) {
    Some(@pdf.PdfObject::Indirect(n)) => {
      let dict = @pdf.lookup_obj(pdf, n)
      let updated = @pdf.add_dict_entry(
        dict,
        "/Perms",
        @pdf.PdfObject::String(perms),
      )
      replace_encrypt_entry(pdf, updated)
    }
    _ => fail("expected /Encrypt indirect reference")
  }
}

///|
test "decrypt_single_stream skips metadata when EncryptMetadata is false" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_AES(false, "user", "owner", [], pdf)
  let dict = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Metadata")),
    ("/Length", @pdf.PdfObject::Integer(4)),
  ])
  let data = @pdfio.bytes_of_string("meta")
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let out = @pdfcrypt.decrypt_single_stream(
    Some("user"),
    None,
    enc,
    1,
    0,
    stream,
  )
  match out {
    @pdf.PdfObject::Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(bytes)) => assert_eq(@pdfio.bytes_size(bytes), 4)
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
}

///|
test "decrypt_single_stream skips identity crypt filters" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_AES(true, "user", "owner", [], pdf)
  let dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/Crypt")),
    (
      "/DecodeParms",
      @pdf.PdfObject::Dictionary([("/Name", @pdf.PdfObject::Name("/Identity"))]),
    ),
    ("/Length", @pdf.PdfObject::Integer(3)),
  ])
  let data = @pdfio.bytes_of_string("abc")
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let out = @pdfcrypt.decrypt_single_stream(
    Some("user"),
    None,
    enc,
    2,
    0,
    stream,
  )
  match out {
    @pdf.PdfObject::Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(bytes)) => assert_eq(@pdfio.bytes_size(bytes), 3)
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
  let dict_array = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Array([@pdf.PdfObject::Name("/Crypt")])),
    (
      "/DecodeParms",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Dictionary([
          ("/Name", @pdf.PdfObject::Name("/Identity")),
        ]),
      ]),
    ),
    ("/Length", @pdf.PdfObject::Integer(3)),
  ])
  let stream_array = @pdf.PdfObject::Stream(
    Ref::new((dict_array, @pdf.Stream::Got(@pdfio.bytes_of_string("abc")))),
  )
  let out_array = @pdfcrypt.decrypt_single_stream(
    Some("user"),
    None,
    enc,
    3,
    0,
    stream_array,
  )
  match out_array {
    @pdf.PdfObject::Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(bytes)) => assert_eq(@pdfio.bytes_size(bytes), 3)
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
}

///|
test "decrypt_single_stream handles AES256 streams" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_AES256(true, "user", "owner", [], pdf)
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(4)),
  ])
  let got_stream = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string("data")))),
  )
  let got_out = @pdfcrypt.decrypt_single_stream(
    Some("user"),
    None,
    enc,
    4,
    0,
    got_stream,
  )
  match got_out {
    @pdf.PdfObject::Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(_)) => ()
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
  let input = @pdfio.input_of_string("data", source="stream")
  let toget = @pdf.toget(input, 0, 4)
  let toget_stream = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::ToGet(toget))),
  )
  let toget_out = @pdfcrypt.decrypt_single_stream(
    Some("user"),
    None,
    enc,
    5,
    0,
    toget_stream,
  )
  match toget_out {
    @pdf.PdfObject::Stream(r) =>
      match r.val {
        (_, @pdf.Stream::ToGet(_)) => ()
        _ => fail("expected ToGet stream")
      }
    _ => fail("expected stream")
  }
}

///|
test "decrypt_pdf fails with short perms" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_AES256(true, "user", "owner", [], pdf)
  update_perms(enc, "short")
  let result = try? @pdfcrypt.decrypt_pdf("user", enc)
  assert_true(result is Err(_))
}

///|
test "decrypt_pdf fails with corrupted perms marker" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let enc = @pdfcrypt.encrypt_pdf_AES256(true, "user", "owner", [], pdf)
  let bad_perms = @pdfio.string_of_int_array(Array::make(16, 0))
  update_perms(enc, bad_perms)
  let result = try? @pdfcrypt.decrypt_pdf("user", enc)
  assert_true(result is Err(_))
}
