///|
fn decode_stream(
  filter : @pdf.PdfObject,
  data : @pdfio.MutableBytes,
  parms? : @pdf.PdfObject,
) -> @pdfio.MutableBytes raise {
  let pdf = @pdf.empty()
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(data))),
    ("/Filter", filter),
  ]
  let entries = match parms {
    Some(p) => entries + [("/DecodeParms", p)]
    None => entries
  }
  let dict = @pdf.PdfObject::Dictionary(entries)
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  decode_pdfstream_onestage(pdf, stream_obj)
  match stream_ref.val {
    (_, @pdf.Stream::Got(bytes)) => bytes
    _ => fail("expected decoded bytes")
  }
}

///|
test "decode ASCIIHex stream" {
  let data = @pdfio.bytes_of_string("48656c6c6f>")
  let decoded = decode_stream(@pdf.PdfObject::Name("/ASCIIHexDecode"), data)
  assert_eq(@pdfio.string_of_bytes(decoded), "Hello")
}

///|
test "decode ASCII85 stream" {
  let data = @pdfio.bytes_of_string("z~>")
  let decoded = decode_stream(@pdf.PdfObject::Name("/ASCII85Decode"), data)
  assert_eq(decoded.length(), 4)
  assert_eq(decoded[0].to_int(), 0)
  assert_eq(decoded[3].to_int(), 0)
}

///|
test "decode RunLength stream" {
  let data = @pdfio.bytes_of_list([2, 65, 66, 67, 255, 90, 128])
  let decoded = decode_stream(@pdf.PdfObject::Name("/RunLengthDecode"), data)
  assert_eq(@pdfio.string_of_bytes(decoded), "ABCZZ")
}

///|
test "decode Flate stream with TIFF predictor" {
  let raw = @pdfio.bytes_of_list([1, 2, 3, 4, 5, 6])
  let encoded = encode_predictor(2, 1, 8, 6, raw)
  let compressed = encode_flate(encoded)
  let parms_dict = @pdf.PdfObject::Dictionary([
    ("/Predictor", @pdf.PdfObject::Integer(2)),
    ("/Colors", @pdf.PdfObject::Integer(1)),
    ("/BitsPerComponent", @pdf.PdfObject::Integer(8)),
    ("/Columns", @pdf.PdfObject::Integer(6)),
  ])
  let decoded = decode_stream(
    @pdf.PdfObject::Name("/FlateDecode"),
    compressed,
    parms=parms_dict,
  )
  assert_eq(@pdfio.int_array_of_bytes(decoded), @pdfio.int_array_of_bytes(raw))
}

///|
test "encode/decode PNG predictor roundtrip" {
  let raw = @pdfio.bytes_of_list([10, 20, 30, 40])
  let encoded = encode_predictor(10, 1, 8, 4, raw)
  let decoded = decode_predictor(10, 1, 8, 4, encoded)
  assert_eq(@pdfio.int_array_of_bytes(decoded), @pdfio.int_array_of_bytes(raw))
}
