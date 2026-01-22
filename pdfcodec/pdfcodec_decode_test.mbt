///|
fn decode_stream(
  filter : @pdf.PdfObject,
  data : @pdfio.MutableBytes,
  parms? : @pdf.PdfObject,
) -> @pdfio.MutableBytes raise {
  let pdf = @pdf.empty()
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", filter),
  ]
  let entries = match parms {
    Some(p) => entries + [("/DecodeParms", p)]
    None => entries
  }
  let dict : @pdf.PdfObject = Dictionary(entries)
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_pdfstream_onestage(pdf, stream_obj)
  match stream_ref.val {
    (_, @pdf.Stream::Got(bytes)) => bytes
    _ => fail("expected decoded bytes")
  }
}

///|
test "decode ASCIIHex stream" {
  let data = @pdfio.bytes_of_string("48656c6c6f>")
  let decoded = decode_stream(Name("/ASCIIHexDecode"), data)
  assert_eq(@pdfio.string_of_bytes(decoded), "Hello")
}

///|
test "decode ASCIIHex stream skips whitespace" {
  let data = @pdfio.bytes_of_string("48 65 6c 6c 6f >")
  let decoded = decode_stream(Name("/ASCIIHexDecode"), data)
  assert_eq(@pdfio.string_of_bytes(decoded), "Hello")
}

///|
test "decode ASCIIHex stream rejects invalid char" {
  let data = @pdfio.bytes_of_string("GG>")
  let res : Result[@pdfio.MutableBytes, Error] = try? decode_stream(
    Name("/ASCIIHexDecode"),
    data,
  )
  assert_true(res is Err(_))
}

///|
test "decode ASCIIHex stream rejects invalid second char" {
  let data = @pdfio.bytes_of_string("4G>")
  let res : Result[@pdfio.MutableBytes, Error] = try? decode_stream(
    Name("/ASCIIHexDecode"),
    data,
  )
  assert_true(res is Err(_))
}

///|
test "decode ASCIIHex stream ends on leading terminator" {
  let data = @pdfio.bytes_of_string(">0")
  let decoded = decode_stream(Name("/ASCIIHexDecode"), data)
  assert_eq(decoded.length(), 0)
}

///|
test "decode ASCII85 stream" {
  let data = @pdfio.bytes_of_string("z~>")
  let decoded = decode_stream(Name("/ASCII85Decode"), data)
  assert_eq(decoded.length(), 4)
  assert_eq(decoded[0].to_int(), 0)
  assert_eq(decoded[3].to_int(), 0)
}

///|
test "decode ASCII85 stream rejects invalid char" {
  let data = @pdfio.bytes_of_string("v~>")
  let res : Result[@pdfio.MutableBytes, Error] = try? decode_stream(
    Name("/ASCII85Decode"),
    data,
  )
  assert_true(res is Err(_))
}

///|
test "decode RunLength stream" {
  let data = @pdfio.bytes_of_list([2, 65, 66, 67, 255, 90, 128])
  let decoded = decode_stream(Name("/RunLengthDecode"), data)
  assert_eq(@pdfio.string_of_bytes(decoded), "ABCZZ")
}

///|
test "decode Flate stream with TIFF predictor" {
  let raw = @pdfio.bytes_of_list([1, 2, 3, 4, 5, 6])
  let encoded = encode_predictor(2, 1, 8, 6, raw)
  let compressed = encode_flate(encoded)
  let parms_dict : @pdf.PdfObject = Dictionary([
    ("/Predictor", Integer(2)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/Columns", Integer(6)),
  ])
  let decoded = decode_stream(
    Name("/FlateDecode"),
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

///|
test "decode_from_input handles filter array" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Array([Name("/ASCIIHexDecode")])),
  ])
  let input = @pdfio.input_of_bytes(@pdfio.bytes_of_string("4869>"))
  match decode_from_input(input, dict) {
    Some(decoded) => assert_eq(@pdfio.string_of_bytes(decoded), "Hi")
    None => fail("expected array filter decode")
  }
}

///|
test "decode_from_input rejects non-name filters" {
  let dict : @pdf.PdfObject = Dictionary([("/Filter", Array([Integer(1)]))])
  let input = @pdfio.input_of_bytes(@pdfio.bytes_of_string("4869>"))
  let res = decode_from_input(input, dict)
  assert_true(res is None)
}

///|
test "decode_from_input handles Crypt filter" {
  let dict : @pdf.PdfObject = Dictionary([("/Filter", Name("/Crypt"))])
  let input = @pdfio.input_of_bytes(@pdfio.bytes_of_string("hi"))
  match decode_from_input(input, dict) {
    Some(decoded) => assert_eq(@pdfio.string_of_bytes(decoded), "hi")
    None => fail("expected Crypt passthrough")
  }
}

///|
test "decode_pdfstream_onestage rejects missing filter" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage rejects empty filter array" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Array([])),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage rejects invalid filter entry" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Array([Integer(1)])),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage rejects invalid filter type" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Integer(1)),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage handles /F and /DP keys" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/F", Name("/ASCIIHexDecode")),
    ("/DP", Array([Null, Null])),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_pdfstream_onestage(pdf, stream_obj)
  let (updated_dict, _) = stream_ref.val
  assert_true(@pdf.lookup_direct(pdf, "/F", updated_dict) is None)
  match (@pdf.lookup_direct(pdf, "/DP", updated_dict) : @pdf.PdfObject?) {
    Some(Array(values)) => assert_eq(values.length(), 1)
    _ => fail("expected trimmed /DP array")
  }
}

///|
test "decode_pdfstream_onestage trims filter and decode parms arrays" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Array([Name("/ASCIIHexDecode"), Name("/ASCIIHexDecode")])),
    ("/DecodeParms", Array([Null, Null])),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_pdfstream_onestage(pdf, stream_obj)
  let (updated_dict, _) = stream_ref.val
  match (@pdf.lookup_direct(pdf, "/Filter", updated_dict) : @pdf.PdfObject?) {
    Some(Array(filters)) => assert_eq(filters.length(), 1)
    _ => fail("expected updated filter array")
  }
  match
    (@pdf.lookup_direct(pdf, "/DecodeParms", updated_dict) : @pdf.PdfObject?) {
    Some(Array(parms)) => assert_eq(parms.length(), 1)
    _ => fail("expected updated decode parms array")
  }
}

///|
test "decode_pdfstream_onestage handles Crypt filter" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("plain")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Name("/Crypt")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_pdfstream_onestage(pdf, stream_obj)
  let (updated_dict, stream_data) = stream_ref.val
  assert_true(@pdf.lookup_direct(pdf, "/Filter", updated_dict) is None)
  match stream_data {
    @pdf.Stream::Got(bytes) => assert_eq(@pdfio.string_of_bytes(bytes), "plain")
    _ => fail("expected got bytes")
  }
}

///|
test "decode_pdfstream_onestage rejects JBIG2 in sync path" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Name("/JBIG2Decode")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage reports CCITT errors" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Name("/CCITTFaxDecode")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage reports LZW errors" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Name("/LZWDecode")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
async test "decode_pdfstream_onestage_async handles filter arrays" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Array([Name("/ASCIIHexDecode"), Name("/ASCIIHexDecode")])),
    ("/DecodeParms", Array([Null, Null])),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_pdfstream_onestage_async(pdf, stream_obj)
  let (updated_dict, _) = stream_ref.val
  match (@pdf.lookup_direct(pdf, "/Filter", updated_dict) : @pdf.PdfObject?) {
    Some(Array(filters)) => assert_eq(filters.length(), 1)
    _ => fail("expected updated filter array")
  }
}

///|
async test "decode_pdfstream_onestage_async rejects missing jbig2dec" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Name("/JBIG2Decode")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_pdfstream_onestage_async(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_until_unknown ignores unsupported filters" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Name("/JBIG2Decode")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_pdfstream_until_unknown(pdf, stream_obj)
}

///|
test "pdfcodec uses placeholder string_of_pdf" {
  let rendered = (@pdfcodec.string_of_pdf.val)(Null)
  assert_eq(rendered, "")
}

///|
async test "pdfcodec uses placeholder pdf_of_file" {
  let pdf = (@pdfcodec.pdf_of_file.val)(None, None, None, "missing.pdf")
  assert_eq(pdf.root, 0)
}

///|
async test "decode_pdfstream_async reports JBIG2 error with globals" {
  let pdf = @pdf.empty()
  let globals_bytes = @pdfio.bytes_of_string("globals")
  let globals_dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(globals_bytes))),
  ])
  let globals_stream : @pdf.PdfObject = Stream(
    Ref::new((globals_dict, @pdf.Stream::Got(globals_bytes))),
  )
  let globals_id = @pdf.addobj(pdf, globals_stream)
  let parms : @pdf.PdfObject = Dictionary([
    ("/JBIG2Globals", Indirect(globals_id)),
  ])
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name("/JBIG2Decode")),
    ("/DecodeParms", parms),
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let res : Result[Unit, Error] = try? decode_pdfstream_async(
    pdf,
    stream,
    jbig2dec="/usr/bin/false",
  )
  assert_true(res is Err(_))
}

///|
async test "decode_pdfstream_async reports JBIG2 error without globals" {
  let pdf = @pdf.empty()
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name("/JBIG2Decode")),
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let res : Result[Unit, Error] = try? decode_pdfstream_async(
    pdf,
    stream,
    jbig2dec="/usr/bin/false",
  )
  assert_true(res is Err(_))
}
