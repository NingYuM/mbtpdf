///|
fn build_minimal_pdf_for_encrypt() -> @pdf.Pdf {
  let pdf : @pdf.Pdf = {
    major: 2,
    minor: 0,
    root: 4,
    objects: {
      max_obj_num: 0,
      parse: None,
      objects: @pdf.pdfobjmap_empty(),
      object_stream_ids: Map::new(),
    },
    trailerdict: @pdf.PdfObject::Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
  }
  let content = "BT /F0 12 Tf (Hello) Tj ET\n"
  let stream_bytes = @pdfio.bytes_of_string(content)
  let stream_dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(stream_bytes))),
  ])
  let stream_obj = @pdf.PdfObject::Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(stream_bytes))),
  )
  let font_dict = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Font")),
    ("/Subtype", @pdf.PdfObject::Name("/Type1")),
    ("/BaseFont", @pdf.PdfObject::Name("/Times-Roman")),
  ])
  let resources = @pdf.PdfObject::Dictionary([
    ("/Font", @pdf.PdfObject::Dictionary([("/F0", font_dict)])),
  ])
  let page = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Page")),
    ("/Parent", @pdf.PdfObject::Indirect(1)),
    ("/Resources", resources),
    (
      "/MediaBox",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Integer(0),
        @pdf.PdfObject::Integer(0),
        @pdf.PdfObject::Integer(300),
        @pdf.PdfObject::Integer(300),
      ]),
    ),
    ("/Contents", @pdf.PdfObject::Indirect(2)),
  ])
  let pages = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Pages")),
    ("/Kids", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(3)])),
    ("/Count", @pdf.PdfObject::Integer(1)),
  ])
  let catalog = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Catalog")),
    ("/Pages", @pdf.PdfObject::Indirect(1)),
  ])
  @pdf.addobj_given_num(pdf, (1, pages))
  @pdf.addobj_given_num(pdf, (2, stream_obj))
  @pdf.addobj_given_num(pdf, (3, page))
  @pdf.addobj_given_num(pdf, (4, catalog))
  pdf
}

///|
fn find_subslice(
  haystack : @pdfio.MutableBytes,
  needle : @pdfio.MutableBytes,
  start? : Int = 0,
) -> Int? {
  if needle.length() == 0 {
    return Some(start)
  }
  let mut i = start
  let last = haystack.length() - needle.length()
  while i <= last {
    let mut j = 0
    while j < needle.length() && haystack[i + j] == needle[j] {
      j = j + 1
    }
    if j == needle.length() {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
test "pdf_to_output encrypts and reads with user password" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.make_encryption(
    @pdfwrite.EncryptionMethod::PDF128bit,
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.input_output_of_bytes(512)
  @pdfwrite.pdf_to_output(Some(enc), false, pdf, output)
  let pdf_bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let input = @pdfio.input_of_bytes(pdf_bytes, source="encrypt-roundtrip")
  let parsed = @pdfread.pdf_of_input(Some("user"), None, input)
  assert_eq(@pdf.objcard(parsed), 5)
  assert_eq(parsed.root, 4)
}

///|
test "pdf_to_output recrypt uses saved encryption" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.make_encryption(
    @pdfwrite.EncryptionMethod::PDF40bit,
    "owner",
    "user",
    permissions,
  )
  let (output1, buffer1) = @pdfio.input_output_of_bytes(512)
  @pdfwrite.pdf_to_output(Some(enc), false, pdf, output1)
  let bytes1 = @pdfio.extract_bytes_from_input_output(output1, buffer1)
  let input1 = @pdfio.input_of_bytes(bytes1, source="encrypt-recrypt")
  let parsed = @pdfread.pdf_of_input(Some("user"), None, input1)
  let (decrypted_opt, _) = @pdfcrypt.decrypt_pdf("user", parsed)
  let decrypted = match decrypted_opt {
    Some(value) => value
    None => fail("expected decryptable PDF")
  }
  let (output2, buffer2) = @pdfio.input_output_of_bytes(512)
  @pdfwrite.pdf_to_output(recrypt="user", None, false, decrypted, output2)
  let bytes2 = @pdfio.extract_bytes_from_input_output(output2, buffer2)
  let input2 = @pdfio.input_of_bytes(bytes2, source="recrypt-roundtrip")
  let parsed2 = @pdfread.pdf_of_input(Some("user"), None, input2)
  let (roundtrip_opt, _) = @pdfcrypt.decrypt_pdf("user", parsed2)
  match roundtrip_opt {
    Some(_) => ()
    None => fail("expected recryptable PDF")
  }
  assert_eq(@pdf.objcard(parsed2), 6)
  assert_eq(parsed2.root, 4)
}

///|
test "pdf_to_output encrypts object streams and reads with user password" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.make_encryption(
    @pdfwrite.EncryptionMethod::PDF128bit,
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.input_output_of_bytes(1024)
  @pdfwrite.pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    Some(enc),
    false,
    pdf,
    output,
  )
  let pdf_bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let input = @pdfio.input_of_bytes(pdf_bytes, source="encrypt-objstm")
  let parsed = @pdfread.pdf_of_input(Some("user"), None, input)
  assert_eq(parsed.root, 4)
}

///|
test "pdfread lazy decrypts object streams for encrypted PDFs" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.make_encryption(
    @pdfwrite.EncryptionMethod::PDF128bit,
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.input_output_of_bytes(1024)
  @pdfwrite.pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    Some(enc),
    false,
    pdf,
    output,
  )
  let pdf_bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let input = @pdfio.input_of_bytes(pdf_bytes, source="encrypt-objstm-lazy")
  let parsed = @pdfread.pdf_of_input_lazy(Some("user"), None, input)
  let objstm_entries = parsed.objects.object_stream_ids.to_array()
  if objstm_entries.length() == 0 {
    fail("expected object stream entries")
  }
  let objnum = objstm_entries[0].0
  let obj = @pdf.lookup_obj(parsed, objnum)
  match obj {
    @pdf.PdfObject::Null => fail("expected parsed object from objstm")
    _ => ()
  }
}

///|
test "pdfread returns pdf for encrypted objstm without password" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.make_encryption(
    @pdfwrite.EncryptionMethod::PDF128bit,
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.input_output_of_bytes(1024)
  @pdfwrite.pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    Some(enc),
    false,
    pdf,
    output,
  )
  let pdf_bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let input = @pdfio.input_of_bytes(pdf_bytes, source="encrypt-objstm-nopw")
  let res : Result[@pdf.Pdf, Error] = try? @pdfread.pdf_of_input(
    None,
    None,
    input,
  )
  match res {
    Ok(parsed) =>
      if @pdfread.what_encryption(parsed) is None {
        fail("expected encryption info")
      }
    Err(_) => fail("expected read to succeed without password")
  }
}

///|
test "pdfread skips malformed object stream" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.make_encryption(
    @pdfwrite.EncryptionMethod::AES128bit(true),
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.input_output_of_bytes(1024)
  @pdfwrite.pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    Some(enc),
    false,
    pdf,
    output,
  )
  let pdf_bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let objstm_marker = @pdfio.bytes_of_string("/ObjStm")
  let n_marker = @pdfio.bytes_of_string("/N ")
  let objstm_pos = match find_subslice(pdf_bytes, objstm_marker) {
    Some(pos) => pos
    None => fail("expected /ObjStm")
  }
  let n_pos = match find_subslice(pdf_bytes, n_marker, start=objstm_pos) {
    Some(pos) => pos
    None => fail("expected /N entry")
  }
  let n_value_index = n_pos + n_marker.length()
  pdf_bytes[n_value_index] = '/'.to_int().to_byte()
  let input = @pdfio.input_of_bytes(pdf_bytes, source="malformed-objstm")
  let res : Result[@pdf.Pdf, Error] = try? @pdfread.pdf_of_input(
    Some("user"),
    None,
    input,
  )
  match res {
    Ok(_) => ()
    Err(_) => fail("expected read to succeed despite malformed objstm")
  }
}
