///|
test "encode/decode flate stream" {
  let pdf = @pdf.empty()
  let original = @pdfio.bytes_of_string("hello flate")
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(original))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(original)))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  encode_pdfstream(pdf, Encoding::Flate, stream_obj)
  let (encoded_dict, encoded_stream) = stream_ref.val
  let encoded_bytes = match encoded_stream {
    @pdf.Stream::Got(bytes) => bytes
    _ => fail("expected encoded stream bytes")
  }
  match @pdf.lookup_direct(pdf, "/Filter", encoded_dict) {
    Some(@pdf.PdfObject::Name(name))
    | Some(@pdf.PdfObject::Array([@pdf.PdfObject::Name(name), ..])) =>
      if name != "/FlateDecode" {
        fail("expected /FlateDecode filter")
      }
    _ => fail("expected /Filter entry")
  }
  match @pdf.lookup_direct(pdf, "/Length", encoded_dict) {
    Some(@pdf.PdfObject::Integer(len)) =>
      assert_eq(len, @pdfio.bytes_size(encoded_bytes))
    _ => fail("expected /Length entry")
  }
  decode_pdfstream_onestage(pdf, stream_obj)
  let (decoded_dict, decoded_stream) = stream_ref.val
  let decoded_bytes = match decoded_stream {
    @pdf.Stream::Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(
    @pdfio.string_of_bytes(decoded_bytes),
    @pdfio.string_of_bytes(original),
  )
  match @pdf.lookup_immediate("/Filter", decoded_dict) {
    None => ()
    _ => fail("expected /Filter removed after decode")
  }
  match @pdf.lookup_direct(pdf, "/Length", decoded_dict) {
    Some(@pdf.PdfObject::Integer(len)) =>
      assert_eq(len, @pdfio.bytes_size(original))
    _ => fail("expected /Length entry")
  }
}

///|
fn roundtrip_encoding(
  encoding : Encoding,
  original : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(original))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(original)))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  encode_pdfstream(pdf, encoding, stream_obj, only_if_smaller=false)
  decode_pdfstream_onestage(pdf, stream_obj)
  match stream_ref.val {
    (_, @pdf.Stream::Got(bytes)) => bytes
    _ => fail("expected decoded bytes")
  }
}

///|
test "encode/decode ASCIIHex stream" {
  let original = @pdfio.bytes_of_string("hello hex")
  let decoded = roundtrip_encoding(Encoding::ASCIIHex, original)
  assert_eq(@pdfio.string_of_bytes(decoded), "hello hex")
}

///|
test "encode/decode ASCII85 stream" {
  let original = @pdfio.bytes_of_string("ascii85 data")
  let decoded = roundtrip_encoding(Encoding::ASCII85, original)
  assert_eq(@pdfio.string_of_bytes(decoded), "ascii85 data")
}

///|
test "encode/decode RunLength stream" {
  let original = @pdfio.bytes_of_string("runlength data")
  let decoded = roundtrip_encoding(Encoding::RunLength, original)
  assert_eq(@pdfio.string_of_bytes(decoded), "runlength data")
}

///|
test "encode/decode LZW stream" {
  let original = @pdfio.bytes_of_string("TOBEORNOTTOBEORTOBEORNOT")
  let decoded = roundtrip_encoding(Encoding::LZW(1), original)
  assert_eq(@pdfio.string_of_bytes(decoded), "TOBEORNOTTOBEORTOBEORNOT")
}
