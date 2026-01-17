///|
fn run_uncompress(data : @pdfio.MutableBytes, header : Bool) -> @pdfio.MutableBytes raise FlateError {
  let mut pos = 0
  let input = (buf : @pdfio.MutableBytes) => {
    let remaining = data.length() - pos
    if remaining <= 0 {
      0
    } else {
      let n = if remaining < buf.length() { remaining } else { buf.length() }
      for i = 0; i < n; i = i + 1 {
        buf[i] = data[pos + i]
      }
      pos = pos + n
      n
    }
  }
  let out : @pdfio.MutableBytes = Array::new()
  let output = (buf : @pdfio.MutableBytes, length : Int) => {
    for i = 0; i < length; i = i + 1 {
      out.push(buf[i])
    }
  }
  uncompress(header=header, input, output)
  out
}

///|
test "uncompress stored zlib" {
  let data : @pdfio.MutableBytes = [
    120, 1, 1, 11, 0, 244, 255, 104, 101, 108, 108, 111, 32, 119, 111, 114,
    108, 100, 26, 11, 4, 93,
  ]
  let out = try run_uncompress(data, true) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let ints = out.map((b) => b.to_int())
  inspect(ints, content="[104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]")
}

///|
test "uncompress fixed huffman" {
  let data : @pdfio.MutableBytes = [
    203, 72, 205, 201, 201, 87, 40, 207, 47, 202, 73, 1, 0,
  ]
  let out = try run_uncompress(data, false) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let ints = out.map((b) => b.to_int())
  inspect(ints, content="[104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]")
}
