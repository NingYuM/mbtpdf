///|
test "encode/decode flate stream with predictor" {
  let pdf = @pdf.empty()
  let original = @pdfio.bytes_of_string("abcdef")
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(original))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(original)))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  encode_pdfstream(
    pdf,
    Encoding::Flate,
    stream_obj,
    predictor=Predictor::PNGUp,
    predictor_columns=3,
  )
  let (encoded_dict, _encoded_stream) = stream_ref.val
  match @pdf.lookup_direct(pdf, "/DecodeParms", encoded_dict) {
    Some(@pdf.PdfObject::Dictionary(entries)) => {
      let pred = entries.search_by(pair => pair.0 == "/Predictor")
      let cols = entries.search_by(pair => pair.0 == "/Columns")
      match (pred, cols) {
        (Some(pi), Some(ci)) =>
          match (entries[pi].1, entries[ci].1) {
            (@pdf.PdfObject::Integer(p), @pdf.PdfObject::Integer(c)) => {
              assert_eq(p, 12)
              assert_eq(c, 3)
            }
            _ => fail("unexpected decode parms entries")
          }
        _ => fail("missing decode parms entries")
      }
    }
    _ => fail("expected /DecodeParms dictionary")
  }
  decode_pdfstream_onestage(pdf, stream_obj)
  let (_decoded_dict, decoded_stream) = stream_ref.val
  let decoded_bytes = match decoded_stream {
    @pdf.Stream::Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(
    @pdfio.string_of_bytes(decoded_bytes),
    @pdfio.string_of_bytes(original),
  )
}
