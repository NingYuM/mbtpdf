///|
test "jbig2 pbm header parse" {
  let header = @pdfio.bytes_of_string("P4\n1 1\n")
  let pbm : Array[Byte] = Array::new()
  for b in header {
    pbm.push(b)
  }
  pbm.push((0).to_byte())
  let decoded = decode_jbig2dec_pbm(pbm)
  assert_eq(decoded.length(), 1)
  assert_eq(decoded[0].to_int(), 255)
}
