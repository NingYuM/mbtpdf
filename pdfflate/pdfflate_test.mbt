///|
fn run_uncompress(
  data : @pdfio.MutableBytes,
  header : Bool,
) -> @pdfio.MutableBytes raise FlateError {
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
  let output = (buf : @pdfio.MutableBytes, length : Int) => for i = 0
                                                                i < length
                                                                i = i + 1 {
    out.push(buf[i])
  }
  uncompress(header~, input, output)
  out
}

///|
fn run_compress(
  data : @pdfio.MutableBytes,
  header : Bool,
) -> @pdfio.MutableBytes raise FlateError {
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
  let output = (buf : @pdfio.MutableBytes, length : Int) => for i = 0
                                                                i < length
                                                                i = i + 1 {
    out.push(buf[i])
  }
  compress(header~, input, output)
  out
}

///|
test "uncompress stored zlib" {
  let data : @pdfio.MutableBytes = [
    120, 1, 1, 11, 0, 244, 255, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108,
    100, 26, 11, 4, 93,
  ]
  let out = run_uncompress(data, true) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let ints = out.map(b => b.to_int())
  inspect(
    ints,
    content="[104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]",
  )
}

///|
test "uncompress fixed huffman" {
  let data : @pdfio.MutableBytes = [
    203, 72, 205, 201, 201, 87, 40, 207, 47, 202, 73, 1, 0,
  ]
  let out = run_uncompress(data, false) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let ints = out.map(b => b.to_int())
  inspect(
    ints,
    content="[104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]",
  )
}

///|
test "uncompress dynamic huffman" {
  let data : @pdfio.MutableBytes = [
    120, 156, 237, 196, 57, 1, 0, 0, 8, 4, 160, 172, 231, 211, 191, 130, 41, 220,
    96, 32, 213, 179, 145, 36, 73, 146, 36, 73, 146, 244, 217, 1, 198, 122, 142,
    2,
  ]
  let out = run_uncompress(data, true) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let expected = @pdfio.bytes_of_string("abcde".repeat(1000))
  assert_eq(out, expected)
}

///|
test "compress/uncompress roundtrip zlib" {
  let input = @pdfio.bytes_of_string("hello flate")
  let encoded = run_compress(input, true) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let decoded = run_uncompress(encoded, true) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "hello flate")
}

///|
test "compress/uncompress roundtrip raw" {
  let input = @pdfio.bytes_of_string("hello flate raw")
  let encoded = run_compress(input, false) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let decoded = run_uncompress(encoded, false) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "hello flate raw")
}
