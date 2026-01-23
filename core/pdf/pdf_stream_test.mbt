///|
test "streams and transforms" {
  let pdf = empty()
  addobj_given_num(pdf, (1, PdfObject::Integer(7)))
  let input = @pdfio.input_of_string("abcd", source="stream")
  let t = toget(input, 0, 4)
  let dict = PdfObject::Dictionary([("/Length", PdfObject::Integer(0))])
  let stream_ref = Ref::new((dict, Stream::ToGet(t)))
  let stream_obj = PdfObject::Stream(stream_ref)
  getstream(stream_obj)
  match stream_ref.val {
    (PdfObject::Dictionary(entries), Stream::Got(bytes)) => {
      assert_eq(@pdfio.bytes_size(bytes), 4)
      match entries.search_by(pair => pair.0 == "/Length") {
        Some(i) => assert_integer(entries[i].1, 4)
        None => fail("expected /Length")
      }
    }
    _ => fail("expected got stream")
  }
  let bytes = bigarray_of_stream(stream_obj)
  assert_eq(@pdfio.bytes_size(bytes), 4)
  assert_is_err(try? getstream(PdfObject::Integer(1)))
  assert_is_err(try? bigarray_of_stream(PdfObject::Integer(1)))
  assert_eq(getnum(pdf, PdfObject::Real(3.5)), 3.5)
  assert_eq(getnum(pdf, PdfObject::Integer(4)), 4.0)
  assert_eq(getnum(pdf, PdfObject::Indirect(1)), 7.0)
  assert_is_err(try? getnum(pdf, PdfObject::Name("/A")))
  assert_eq(
    parse_rectangle(
      pdf,
      PdfObject::Array([
        PdfObject::Integer(2),
        PdfObject::Integer(1),
        PdfObject::Integer(4),
        PdfObject::Integer(3),
      ]),
    ),
    (2.0, 1.0, 4.0, 3.0),
  )
  assert_is_err(
    try? parse_rectangle(pdf, PdfObject::Array([PdfObject::Integer(1)])),
  )
  assert_is_err(try? parse_rectangle(pdf, PdfObject::Integer(1)))
  let dict_matrix = PdfObject::Dictionary([
    (
      "/Matrix",
      PdfObject::Array([
        PdfObject::Integer(1),
        PdfObject::Integer(0),
        PdfObject::Integer(0),
        PdfObject::Integer(1),
        PdfObject::Integer(2),
        PdfObject::Integer(3),
      ]),
    ),
  ])
  let matrix = parse_matrix(pdf, "/Matrix", dict_matrix)
  assert_eq(matrix.a, 1.0)
  assert_eq(matrix.d, 1.0)
  assert_eq(matrix.e, 2.0)
  assert_eq(matrix.f, 3.0)
  let identity = parse_matrix(pdf, "/Missing", dict_matrix)
  assert_eq(identity.a, @pdftransform.i_matrix.a)
  assert_eq(identity.d, @pdftransform.i_matrix.d)
  assert_is_err(
    try? parse_matrix(
      pdf,
      "/Matrix",
      PdfObject::Dictionary([
        ("/Matrix", PdfObject::Array([PdfObject::Integer(1)])),
      ]),
    ),
  )
  assert_is_err(
    try? parse_matrix(
      pdf,
      "/Matrix",
      PdfObject::Dictionary([("/Matrix", PdfObject::Integer(1))]),
    ),
  )
  match make_matrix(@pdftransform.i_matrix) {
    PdfObject::Array(values) => assert_eq(values.length(), 6)
    _ => fail("expected matrix array")
  }
  let rect = PdfObject::Array([
    PdfObject::Integer(0),
    PdfObject::Integer(0),
    PdfObject::Integer(2),
    PdfObject::Integer(3),
  ])
  match transform_rect(pdf, @pdftransform.i_matrix, rect) {
    PdfObject::Array(values) => {
      assert_eq(values.length(), 4)
      match values[0] {
        PdfObject::Real(value) => assert_eq(value, 0.0)
        _ => fail("expected real")
      }
      match values[2] {
        PdfObject::Real(value) => assert_eq(value, 2.0)
        _ => fail("expected real")
      }
      match values[3] {
        PdfObject::Real(value) => assert_eq(value, 3.0)
        _ => fail("expected real")
      }
    }
    _ => fail("expected transformed rect")
  }
  let qp = PdfObject::Array([
    PdfObject::Real(0.0),
    PdfObject::Real(0.0),
    PdfObject::Real(1.0),
    PdfObject::Real(0.0),
    PdfObject::Real(1.0),
    PdfObject::Real(1.0),
    PdfObject::Real(0.0),
    PdfObject::Real(1.0),
    PdfObject::Real(0.0),
    PdfObject::Real(0.0),
    PdfObject::Real(2.0),
    PdfObject::Real(0.0),
    PdfObject::Real(2.0),
    PdfObject::Real(2.0),
    PdfObject::Real(0.0),
    PdfObject::Real(2.0),
  ])
  match transform_quadpoints(pdf, @pdftransform.i_matrix, qp) {
    PdfObject::Array(values) => assert_eq(values.length(), 16)
    _ => fail("expected quadpoints")
  }
  let qp_mixed = PdfObject::Array([
    PdfObject::Real(0.0),
    PdfObject::Real(1.0),
    PdfObject::Real(2.0),
    PdfObject::Real(3.0),
    PdfObject::Real(4.0),
    PdfObject::Real(5.0),
    PdfObject::Real(6.0),
    PdfObject::Real(7.0),
    PdfObject::Real(8.0),
    PdfObject::Real(9.0),
  ])
  match transform_quadpoints(pdf, @pdftransform.i_matrix, qp_mixed) {
    PdfObject::Array(values) => assert_eq(values.length(), 10)
    _ => fail("expected quadpoints")
  }
  let qp_bad = PdfObject::Array([PdfObject::Real(0.0), PdfObject::Real(1.0)])
  match transform_quadpoints(pdf, @pdftransform.i_matrix, qp_bad) {
    PdfObject::Array(values) => assert_eq(values.length(), 2)
    _ => fail("expected quadpoints")
  }
  match
    transform_quadpoints(pdf, @pdftransform.i_matrix, PdfObject::Integer(1)) {
    PdfObject::Integer(1) => ()
    _ => fail("expected passthrough")
  }
}

///|
test "getstream error cases" {
  let input = @pdfio.input_of_string("abc", source="crypt")
  let crypt = ToGetCrypt::ToDecrypt(DeferredEncryption::{
    crypt_type: @pdfcryptprimitives.Encryption::AESV2,
    file_encryption_key: None,
    obj: 1,
    gen: 0,
    key: [1],
    keylength: 40,
    r: 5,
  })
  let toget_crypt = toget(input, 0, 3, crypt~)
  let crypt_ref = Ref::new(
    (PdfObject::Dictionary([]), Stream::ToGet(toget_crypt)),
  )
  let crypt_stream = PdfObject::Stream(crypt_ref)
  assert_is_err(try? getstream(crypt_stream))
  let plain = @pdfio.input_of_string("abc", source="plain")
  let toget_plain = toget(plain, 0, 3)
  let plain_ref = Ref::new((PdfObject::Integer(9), Stream::ToGet(toget_plain)))
  let plain_stream = PdfObject::Stream(plain_ref)
  getstream(plain_stream)
  match plain_ref.val {
    (PdfObject::Integer(9), Stream::Got(bytes)) =>
      assert_eq(@pdfio.bytes_size(bytes), 3)
    _ => fail("expected stream data")
  }
}
