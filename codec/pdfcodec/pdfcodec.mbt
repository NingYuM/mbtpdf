///|
/// Supported stream encodings.
pub(all) enum Encoding {
  ASCIIHex
  ASCII85
  RunLength
  LZW(Int)
  Flate
  CCITT(Int, Int)
  CCITTG4(Int, Int)
} derive(Debug)

///|
/// Predictors for decoded data.
#warnings("-unused_constructor")
pub enum Predictor {
  TIFF2
  PNGNone
  PNGSub
  PNGUp
  PNGAverage
  PNGPaeth
  PNGOptimum
} derive(Debug)

///|
/// There was bad data.
pub suberror CodecError {
  CouldntDecodeStream(String)
  DecodeNotSupported(String)
}

///|
/// Setting this changes globally the FlateDecode compression level. Default 6.
pub let flate_level : Ref[Int] = { val: 6 }

///|
/// Setting this boolean prints some debug information.
pub let debug : Ref[Bool] = { val: false }

///|
/// Inter-module recursion hooks (placeholders for now).
pub let string_of_pdf : Ref[(@pdf.PdfObject) -> String] = { val: _ => "" }

///|
/// Placeholder for async Pdf.of_file (revision?, user?, owner?, filename).
#warnings("-unused_async")
async fn pdf_of_file_placeholder(
  _revision : Int?,
  _user_password : String?,
  _owner_password : String?,
  _filename : String,
) -> @pdf.Pdf {
  @pdf.empty()
}

///|
/// Async hook for Pdf.of_file (revision?, user?, owner?, filename).
pub let pdf_of_file : Ref[async (Int?, String?, String?, String) -> @pdf.Pdf] = {
  val: pdf_of_file_placeholder,
}

///|
/// Encode data in FlateDecode.
pub fn encode_flate(data : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
  let mut pos = 0
  let input = (buf : @pdfio.MutableBytes) => {
    let remaining = data.length() - pos
    if remaining <= 0 {
      0
    } else {
      let n = if remaining < buf.length() { remaining } else { buf.length() }
      for i in 0..<n {
        buf[i] = data[pos + i]
      }
      pos = pos + n
      n
    }
  }
  let out : @pdfio.MutableBytes = Array::new()
  let output = (buf : @pdfio.MutableBytes, length : Int) => for i in 0..<length {
    out.push(buf[i])
  }
  @pdfflate.compress(level=flate_level.val, header=true, input, output)
  out
}

///|
/// Decode data in FlateDecode.
pub fn decode_flate(
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let mut pos = 0
  let input = (buf : @pdfio.MutableBytes) => {
    let remaining = data.length() - pos
    if remaining <= 0 {
      0
    } else {
      let n = if remaining < buf.length() { remaining } else { buf.length() }
      for i in 0..<n {
        buf[i] = data[pos + i]
      }
      pos = pos + n
      n
    }
  }
  let out : @pdfio.MutableBytes = Array::new()
  let output = (buf : @pdfio.MutableBytes, length : Int) => for i in 0..<length {
    out.push(buf[i])
  }
  try {
    @pdfflate.uncompress(header=true, input, output)
    out
  } catch {
    @pdfflate.FlateError::Error(stage, msg) =>
      raise CodecError::CouldntDecodeStream("\{stage}: \{msg}")
  }
}

///|
fn append_bits(prefix : Array[Int], suffix : Array[Int]) -> Array[Int] {
  let out = Array::new(capacity=prefix.length() + suffix.length())
  for bit in prefix {
    out.push(bit)
  }
  for bit in suffix {
    out.push(bit)
  }
  out
}

///|
fn write_white_code(n : Int) -> Array[Int] raise CodecError {
  if n == -1 {
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  } else if n == 0 {
    [0, 0, 1, 1, 0, 1, 0, 1]
  } else if n == 1 {
    [0, 0, 0, 1, 1, 1]
  } else if n == 2 {
    [0, 1, 1, 1]
  } else if n == 3 {
    [1, 0, 0, 0]
  } else if n == 4 {
    [1, 0, 1, 1]
  } else if n == 5 {
    [1, 1, 0, 0]
  } else if n == 6 {
    [1, 1, 1, 0]
  } else if n == 7 {
    [1, 1, 1, 1]
  } else if n == 8 {
    [1, 0, 0, 1, 1]
  } else if n == 9 {
    [1, 0, 1, 0, 0]
  } else if n == 10 {
    [0, 0, 1, 1, 1]
  } else if n == 11 {
    [0, 1, 0, 0, 0]
  } else if n == 12 {
    [0, 0, 1, 0, 0, 0]
  } else if n == 13 {
    [0, 0, 0, 0, 1, 1]
  } else if n == 14 {
    [1, 1, 0, 1, 0, 0]
  } else if n == 15 {
    [1, 1, 0, 1, 0, 1]
  } else if n == 16 {
    [1, 0, 1, 0, 1, 0]
  } else if n == 17 {
    [1, 0, 1, 0, 1, 1]
  } else if n == 18 {
    [0, 1, 0, 0, 1, 1, 1]
  } else if n == 19 {
    [0, 0, 0, 1, 1, 0, 0]
  } else if n == 20 {
    [0, 0, 0, 1, 0, 0, 0]
  } else if n == 21 {
    [0, 0, 1, 0, 1, 1, 1]
  } else if n == 22 {
    [0, 0, 0, 0, 0, 1, 1]
  } else if n == 23 {
    [0, 0, 0, 0, 1, 0, 0]
  } else if n == 24 {
    [0, 1, 0, 1, 0, 0, 0]
  } else if n == 25 {
    [0, 1, 0, 1, 0, 1, 1]
  } else if n == 26 {
    [0, 0, 1, 0, 0, 1, 1]
  } else if n == 27 {
    [0, 1, 0, 0, 1, 0, 0]
  } else if n == 28 {
    [0, 0, 1, 1, 0, 0, 0]
  } else if n == 29 {
    [0, 0, 0, 0, 0, 0, 1, 0]
  } else if n == 30 {
    [0, 0, 0, 0, 0, 0, 1, 1]
  } else if n == 31 {
    [0, 0, 0, 1, 1, 0, 1, 0]
  } else if n == 32 {
    [0, 0, 0, 1, 1, 0, 1, 1]
  } else if n == 33 {
    [0, 0, 0, 1, 0, 0, 1, 0]
  } else if n == 34 {
    [0, 0, 0, 1, 0, 0, 1, 1]
  } else if n == 35 {
    [0, 0, 0, 1, 0, 1, 0, 0]
  } else if n == 36 {
    [0, 0, 0, 1, 0, 1, 0, 1]
  } else if n == 37 {
    [0, 0, 0, 1, 0, 1, 1, 0]
  } else if n == 38 {
    [0, 0, 0, 1, 0, 1, 1, 1]
  } else if n == 39 {
    [0, 0, 1, 0, 1, 0, 0, 0]
  } else if n == 40 {
    [0, 0, 1, 0, 1, 0, 0, 1]
  } else if n == 41 {
    [0, 0, 1, 0, 1, 0, 1, 0]
  } else if n == 42 {
    [0, 0, 1, 0, 1, 0, 1, 1]
  } else if n == 43 {
    [0, 0, 1, 0, 1, 1, 0, 0]
  } else if n == 44 {
    [0, 0, 1, 0, 1, 1, 0, 1]
  } else if n == 45 {
    [0, 0, 0, 0, 0, 1, 0, 0]
  } else if n == 46 {
    [0, 0, 0, 0, 0, 1, 0, 1]
  } else if n == 47 {
    [0, 0, 0, 0, 1, 0, 1, 0]
  } else if n == 48 {
    [0, 0, 0, 0, 1, 0, 1, 1]
  } else if n == 49 {
    [0, 1, 0, 1, 0, 0, 1, 0]
  } else if n == 50 {
    [0, 1, 0, 1, 0, 0, 1, 1]
  } else if n == 51 {
    [0, 1, 0, 1, 0, 1, 0, 0]
  } else if n == 52 {
    [0, 1, 0, 1, 0, 1, 0, 1]
  } else if n == 53 {
    [0, 0, 1, 0, 0, 1, 0, 0]
  } else if n == 54 {
    [0, 0, 1, 0, 0, 1, 0, 1]
  } else if n == 55 {
    [0, 1, 0, 1, 1, 0, 0, 0]
  } else if n == 56 {
    [0, 1, 0, 1, 1, 0, 0, 1]
  } else if n == 57 {
    [0, 1, 0, 1, 1, 0, 1, 0]
  } else if n == 58 {
    [0, 1, 0, 1, 1, 0, 1, 1]
  } else if n == 59 {
    [0, 1, 0, 0, 1, 0, 1, 0]
  } else if n == 60 {
    [0, 1, 0, 0, 1, 0, 1, 1]
  } else if n == 61 {
    [0, 0, 1, 1, 0, 0, 1, 0]
  } else if n == 62 {
    [0, 0, 1, 1, 0, 0, 1, 1]
  } else if n == 63 {
    [0, 0, 1, 1, 0, 1, 0, 0]
  } else if n >= 2560 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],
      write_white_code(n - 2560),
    )
  } else if n >= 2496 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0],
      write_white_code(n - 2496),
    )
  } else if n >= 2432 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1],
      write_white_code(n - 2432),
    )
  } else if n >= 2368 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0],
      write_white_code(n - 2368),
    )
  } else if n >= 2304 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1],
      write_white_code(n - 2304),
    )
  } else if n >= 2240 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0],
      write_white_code(n - 2240),
    )
  } else if n >= 2176 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1],
      write_white_code(n - 2176),
    )
  } else if n >= 2112 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0],
      write_white_code(n - 2112),
    )
  } else if n >= 2048 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1],
      write_white_code(n - 2048),
    )
  } else if n >= 1984 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0],
      write_white_code(n - 1984),
    )
  } else if n >= 1920 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1], write_white_code(n - 1920))
  } else if n >= 1856 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0], write_white_code(n - 1856))
  } else if n >= 1792 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0], write_white_code(n - 1792))
  } else if n >= 1728 {
    append_bits([0, 1, 0, 0, 1, 1, 0, 1, 1], write_white_code(n - 1728))
  } else if n >= 1664 {
    append_bits([0, 1, 1, 0, 0, 0], write_white_code(n - 1664))
  } else if n >= 1600 {
    append_bits([0, 1, 0, 0, 1, 1, 0, 1, 0], write_white_code(n - 1600))
  } else if n >= 1536 {
    append_bits([0, 1, 0, 0, 1, 1, 0, 0, 1], write_white_code(n - 1536))
  } else if n >= 1472 {
    append_bits([0, 1, 0, 0, 1, 1, 0, 0, 0], write_white_code(n - 1472))
  } else if n >= 1408 {
    append_bits([0, 1, 1, 0, 1, 1, 0, 1, 1], write_white_code(n - 1408))
  } else if n >= 1344 {
    append_bits([0, 1, 1, 0, 1, 1, 0, 1, 0], write_white_code(n - 1344))
  } else if n >= 1280 {
    append_bits([0, 1, 1, 0, 1, 1, 0, 0, 1], write_white_code(n - 1280))
  } else if n >= 1216 {
    append_bits([0, 1, 1, 0, 1, 1, 0, 0, 0], write_white_code(n - 1216))
  } else if n >= 1152 {
    append_bits([0, 1, 1, 0, 1, 0, 1, 1, 1], write_white_code(n - 1152))
  } else if n >= 1088 {
    append_bits([0, 1, 1, 0, 1, 0, 1, 1, 0], write_white_code(n - 1088))
  } else if n >= 1024 {
    append_bits([0, 1, 1, 0, 1, 0, 1, 0, 1], write_white_code(n - 1024))
  } else if n >= 960 {
    append_bits([0, 1, 1, 0, 1, 0, 1, 0, 0], write_white_code(n - 960))
  } else if n >= 896 {
    append_bits([0, 1, 1, 0, 1, 0, 0, 1, 1], write_white_code(n - 896))
  } else if n >= 832 {
    append_bits([0, 1, 1, 0, 1, 0, 0, 1, 0], write_white_code(n - 832))
  } else if n >= 768 {
    append_bits([0, 1, 1, 0, 0, 1, 1, 0, 1], write_white_code(n - 768))
  } else if n >= 704 {
    append_bits([0, 1, 1, 0, 0, 1, 1, 0, 0], write_white_code(n - 704))
  } else if n >= 640 {
    append_bits([0, 1, 1, 0, 0, 1, 1, 1], write_white_code(n - 640))
  } else if n >= 576 {
    append_bits([0, 1, 1, 0, 1, 0, 0, 0], write_white_code(n - 576))
  } else if n >= 512 {
    append_bits([0, 1, 1, 0, 0, 1, 0, 1], write_white_code(n - 512))
  } else if n >= 448 {
    append_bits([0, 1, 1, 0, 0, 1, 0, 0], write_white_code(n - 448))
  } else if n >= 384 {
    append_bits([0, 0, 1, 1, 0, 1, 1, 1], write_white_code(n - 384))
  } else if n >= 320 {
    append_bits([0, 0, 1, 1, 0, 1, 1, 0], write_white_code(n - 320))
  } else if n >= 256 {
    append_bits([0, 1, 1, 0, 1, 1, 1], write_white_code(n - 256))
  } else if n >= 192 {
    append_bits([0, 1, 0, 1, 1, 1], write_white_code(n - 192))
  } else if n >= 128 {
    append_bits([1, 0, 0, 1, 0], write_white_code(n - 128))
  } else if n >= 64 {
    append_bits([1, 1, 0, 1, 1], write_white_code(n - 64))
  } else {
    raise CodecError::DecodeNotSupported("write_white_code: unknown")
  }
}

///|
fn write_black_code(n : Int) -> Array[Int] raise CodecError {
  if n == -1 {
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  } else if n == 0 {
    [0, 0, 0, 0, 1, 1, 0, 1, 1, 1]
  } else if n == 1 {
    [0, 1, 0]
  } else if n == 2 {
    [1, 1]
  } else if n == 3 {
    [1, 0]
  } else if n == 4 {
    [0, 1, 1]
  } else if n == 5 {
    [0, 0, 1, 1]
  } else if n == 6 {
    [0, 0, 1, 0]
  } else if n == 7 {
    [0, 0, 0, 1, 1]
  } else if n == 8 {
    [0, 0, 0, 1, 0, 1]
  } else if n == 9 {
    [0, 0, 0, 1, 0, 0]
  } else if n == 10 {
    [0, 0, 0, 0, 1, 0, 0]
  } else if n == 11 {
    [0, 0, 0, 0, 1, 0, 1]
  } else if n == 12 {
    [0, 0, 0, 0, 1, 1, 1]
  } else if n == 13 {
    [0, 0, 0, 0, 0, 1, 0, 0]
  } else if n == 14 {
    [0, 0, 0, 0, 0, 1, 1, 1]
  } else if n == 15 {
    [0, 0, 0, 0, 1, 1, 0, 0, 0]
  } else if n == 16 {
    [0, 0, 0, 0, 0, 1, 0, 1, 1, 1]
  } else if n == 17 {
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 0]
  } else if n == 18 {
    [0, 0, 0, 0, 0, 0, 1, 0, 0, 0]
  } else if n == 19 {
    [0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1]
  } else if n == 20 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0]
  } else if n == 21 {
    [0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0]
  } else if n == 22 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1]
  } else if n == 23 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0]
  } else if n == 24 {
    [0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1]
  } else if n == 25 {
    [0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0]
  } else if n == 26 {
    [0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0]
  } else if n == 27 {
    [0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1]
  } else if n == 28 {
    [0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0]
  } else if n == 29 {
    [0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1]
  } else if n == 30 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0]
  } else if n == 31 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1]
  } else if n == 32 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0]
  } else if n == 33 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1]
  } else if n == 34 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0]
  } else if n == 35 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1]
  } else if n == 36 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0]
  } else if n == 37 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1]
  } else if n == 38 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0]
  } else if n == 39 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1]
  } else if n == 40 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0]
  } else if n == 41 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1]
  } else if n == 42 {
    [0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0]
  } else if n == 43 {
    [0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1]
  } else if n == 44 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0]
  } else if n == 45 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1]
  } else if n == 46 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0]
  } else if n == 47 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1]
  } else if n == 48 {
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0]
  } else if n == 49 {
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1]
  } else if n == 50 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0]
  } else if n == 51 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1]
  } else if n == 52 {
    [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0]
  } else if n == 53 {
    [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1]
  } else if n == 54 {
    [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0]
  } else if n == 55 {
    [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1]
  } else if n == 56 {
    [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0]
  } else if n == 57 {
    [0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0]
  } else if n == 58 {
    [0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1]
  } else if n == 59 {
    [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1]
  } else if n == 60 {
    [0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0]
  } else if n == 61 {
    [0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0]
  } else if n == 62 {
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0]
  } else if n == 63 {
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1]
  } else if n >= 2560 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],
      write_black_code(n - 2560),
    )
  } else if n >= 2496 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0],
      write_black_code(n - 2496),
    )
  } else if n >= 2432 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1],
      write_black_code(n - 2432),
    )
  } else if n >= 2368 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0],
      write_black_code(n - 2368),
    )
  } else if n >= 2304 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1],
      write_black_code(n - 2304),
    )
  } else if n >= 2240 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0],
      write_black_code(n - 2240),
    )
  } else if n >= 2176 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1],
      write_black_code(n - 2176),
    )
  } else if n >= 2112 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0],
      write_black_code(n - 2112),
    )
  } else if n >= 2048 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1],
      write_black_code(n - 2048),
    )
  } else if n >= 1984 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0],
      write_black_code(n - 1984),
    )
  } else if n >= 1920 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1], write_black_code(n - 1920))
  } else if n >= 1856 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0], write_black_code(n - 1856))
  } else if n >= 1792 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0], write_black_code(n - 1792))
  } else if n >= 1728 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1],
      write_black_code(n - 1728),
    )
  } else if n >= 1664 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0],
      write_black_code(n - 1664),
    )
  } else if n >= 1600 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1],
      write_black_code(n - 1600),
    )
  } else if n >= 1536 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0],
      write_black_code(n - 1536),
    )
  } else if n >= 1472 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1],
      write_black_code(n - 1472),
    )
  } else if n >= 1408 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0],
      write_black_code(n - 1408),
    )
  } else if n >= 1344 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1],
      write_black_code(n - 1344),
    )
  } else if n >= 1280 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0],
      write_black_code(n - 1280),
    )
  } else if n >= 1216 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1],
      write_black_code(n - 1216),
    )
  } else if n >= 1152 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0],
      write_black_code(n - 1152),
    )
  } else if n >= 1088 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1],
      write_black_code(n - 1088),
    )
  } else if n >= 1024 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0],
      write_black_code(n - 1024),
    )
  } else if n >= 960 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1],
      write_black_code(n - 960),
    )
  } else if n >= 896 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0],
      write_black_code(n - 896),
    )
  } else if n >= 832 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1],
      write_black_code(n - 832),
    )
  } else if n >= 768 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0],
      write_black_code(n - 768),
    )
  } else if n >= 704 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1],
      write_black_code(n - 704),
    )
  } else if n >= 640 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0],
      write_black_code(n - 640),
    )
  } else if n >= 576 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1],
      write_black_code(n - 576),
    )
  } else if n >= 512 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0],
      write_black_code(n - 512),
    )
  } else if n >= 448 {
    append_bits([0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1], write_black_code(n - 448))
  } else if n >= 384 {
    append_bits([0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0], write_black_code(n - 384))
  } else if n >= 320 {
    append_bits([0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1], write_black_code(n - 320))
  } else if n >= 256 {
    append_bits([0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1], write_black_code(n - 256))
  } else if n >= 192 {
    append_bits([0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1], write_black_code(n - 192))
  } else if n >= 128 {
    append_bits([0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0], write_black_code(n - 128))
  } else if n >= 64 {
    append_bits([0, 0, 0, 0, 0, 0, 1, 1, 1, 1], write_black_code(n - 64))
  } else {
    raise CodecError::DecodeNotSupported("write_black_code: unknown")
  }
}

///|
fn write_bits(output : @pdfio.BitstreamWrite, bits : Array[Int]) -> Unit {
  for bit in bits {
    @pdfio.putbit(output, bit)
  }
}

///|
fn read_run(maxcols : Int, input : @pdfio.Bitstream) -> (Bool, Int) raise {
  let mut nbits = 1
  let iswhite = @pdfio.getbit(input)
  let mut finished = false
  while nbits < maxcols && !finished {
    let pos = @pdfio.bitstream_pos(input)
    let newbit = @pdfio.getbit(input)
    if newbit == iswhite {
      nbits = nbits + 1
    } else {
      @pdfio.bitstream_seek(input, pos)
      finished = true
    }
  }
  (iswhite, nbits)
}

///|
/// Encode data in CCITTDecode Group 3.
pub fn encode_ccitt(
  _columns : Int,
  _rows : Int,
  _data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let columns = _columns
  let rows = _rows
  let data = _data
  let input = @pdfio.bitbytes_of_input(@pdfio.input_of_bytes(data))
  let output = @pdfio.make_write_bitstream()
  try {
    let mut rows_left = rows
    let mut cols_left = columns
    while rows_left > 0 {
      let (iswhite, length) = read_run(cols_left, input)
      let bits = if iswhite {
        write_white_code(length)
      } else {
        write_black_code(length)
      }
      if !iswhite && cols_left == columns {
        write_bits(output, write_white_code(0))
      }
      write_bits(output, bits)
      cols_left = cols_left - length
      if cols_left == 0 {
        @pdfio.align(input)
        cols_left = columns
        rows_left = rows_left - 1
      }
    }
    write_bits(output, write_white_code(-1))
    write_bits(output, write_white_code(-1))
    @pdfio.align_write(output)
    @pdfio.bytes_of_write_bitstream(output)
  } catch {
    Failure::Failure(_) =>
      raise CodecError::CouldntDecodeStream("encode_ccitt: not enough data")
    _ => raise CodecError::CouldntDecodeStream("encode_ccitt: not enough data")
  }
}

///|
async fn[T] run_async_mapped(
  context : String,
  load : async () -> T,
) -> T raise CodecError {
  let res : Result[T, Error] = try? load()
  match res {
    Ok(value) => value
    Err(err) => raise CodecError::CouldntDecodeStream("\{context}: \{err}")
  }
}

///|

///|
fn extract_ccittg4_stream(
  pdf : @pdf.Pdf,
) -> @pdfio.MutableBytes raise CodecError {
  fn fail_obj() -> @pdf.PdfObject raise CodecError {
    raise CodecError::DecodeNotSupported("malformed PDF from imagemagick")
  }

  fn fail_bytes() -> @pdfio.MutableBytes raise CodecError {
    raise CodecError::DecodeNotSupported("malformed PDF from imagemagick")
  }

  let root = match @pdf.lookup_direct(pdf, "/Root", pdf.trailerdict) {
    Some(obj) => obj
    None => fail_obj()
  }
  let pages = match @pdf.lookup_direct(pdf, "/Pages", root) {
    Some(obj) => obj
    None => fail_obj()
  }
  let kids_obj = match @pdf.lookup_direct(pdf, "/Kids", pages) {
    Some(obj) => obj
    None => fail_obj()
  }
  let kid0 = match (kids_obj : @pdf.PdfObject) {
    Array(kids) =>
      if kids.length() > 0 {
        @pdf.direct(pdf, kids[0])
      } else {
        fail_obj()
      }
    _ => fail_obj()
  }
  let resources = match @pdf.lookup_direct(pdf, "/Resources", kid0) {
    Some(obj) => obj
    None => fail_obj()
  }
  let xobject = match @pdf.lookup_direct(pdf, "/XObject", resources) {
    Some(obj) => obj
    None => fail_obj()
  }
  let im0 = match @pdf.lookup_direct(pdf, "/Im0", xobject) {
    Some(obj) => obj
    None => fail_obj()
  }
  match (im0 : @pdf.PdfObject) {
    Stream(r) => {
      ignore(@pdf.getstream(im0)) catch {
        _ =>
          raise CodecError::DecodeNotSupported("malformed PDF from imagemagick")
      }
      let (_, stream_data) = r.val
      match (stream_data : @pdf.Stream) {
        Got(data) => data
        _ => fail_bytes()
      }
    }
    _ => fail_bytes()
  }
}

///|
fn ccittg4_transitions(
  input : @pdfio.Bitstream,
  columns : Int,
) -> Array[Int] raise {
  let transitions = Array::new(capacity=columns + 2)
  transitions.push(0)
  let mut prev_white = true
  for pos = 0; pos < columns; pos = pos + 1 {
    let is_white = @pdfio.getbit(input)
    if is_white != prev_white {
      transitions.push(pos)
      prev_white = is_white
    }
  }
  transitions.push(columns)
  @pdfio.align(input)
  transitions
}

///|
fn write_ccittg4_vertical(
  output : @pdfio.BitstreamWrite,
  diff : Int,
) -> Unit raise CodecError {
  match diff {
    0 => write_bits(output, [1])
    -1 => write_bits(output, [0, 1, 1])
    -2 => write_bits(output, [0, 0, 0, 0, 1, 1])
    -3 => write_bits(output, [0, 0, 0, 0, 0, 1, 1])
    1 => write_bits(output, [0, 1, 0])
    2 => write_bits(output, [0, 0, 0, 0, 1, 0])
    3 => write_bits(output, [0, 0, 0, 0, 0, 1, 0])
    _ =>
      raise CodecError::DecodeNotSupported(
        "bad vertical mode in CCITT G4 encoding",
      )
  }
}

///|
fn encode_ccittg4_line(
  columns : Int,
  coding : Array[Int],
  reference : Array[Int],
  output : @pdfio.BitstreamWrite,
) -> Unit raise CodecError {
  let mut a0 = 0
  let mut a0_run = 0
  let mut ref_run = 0
  while a0 < columns {
    while a0_run + 1 < coding.length() && a0 >= coding[a0_run + 1] {
      a0_run = a0_run + 1
    }
    while ref_run + 1 < reference.length() && a0 >= reference[ref_run + 1] {
      ref_run = ref_run + 1
    }
    let a0_iswhite = a0_run % 2 == 0
    let a1 = if a0_run + 1 < coding.length() {
      coding[a0_run + 1]
    } else {
      columns
    }
    let a2 = if a0_run + 2 < coding.length() {
      coding[a0_run + 2]
    } else {
      columns
    }
    let b1_index = ref_run + 1
    let b1 = if b1_index < reference.length() {
      reference[b1_index]
    } else {
      columns
    }
    let b2 = if b1_index + 1 < reference.length() {
      reference[b1_index + 1]
    } else {
      columns
    }
    if b2 < a1 {
      write_bits(output, [0, 0, 0, 1])
      a0 = b2
      continue
    }
    let diff = a1 - b1
    if diff >= -3 && diff <= 3 {
      write_ccittg4_vertical(output, diff)
      a0 = a1
      continue
    }
    write_bits(output, [0, 0, 1])
    let run1 = a1 - a0
    let run2 = a2 - a1
    if a0_iswhite {
      write_bits(output, write_white_code(run1))
      write_bits(output, write_black_code(run2))
    } else {
      write_bits(output, write_black_code(run1))
      write_bits(output, write_white_code(run2))
    }
    a0 = a2
  }
}

///|
fn encode_ccittg4_pure(
  columns : Int,
  rows : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let input = @pdfio.bitbytes_of_input(@pdfio.input_of_bytes(data))
  let output = @pdfio.make_write_bitstream()
  try {
    let mut rows_left = rows
    let mut reference = Array::new(capacity=2)
    reference.push(0)
    reference.push(columns)
    while rows_left > 0 {
      let coding = ccittg4_transitions(input, columns)
      encode_ccittg4_line(columns, coding, reference, output)
      reference = coding
      rows_left = rows_left - 1
    }
    write_bits(output, [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    ])
    @pdfio.align_write(output)
    @pdfio.bytes_of_write_bitstream(output)
  } catch {
    Failure::Failure(_) =>
      raise CodecError::CouldntDecodeStream("encode_ccittg4: not enough data")
    _ =>
      raise CodecError::CouldntDecodeStream("encode_ccittg4: not enough data")
  }
}

///|
/// Encode data in CCITTDecode Group 4.
pub fn encode_ccittg4(
  _columns : Int,
  _rows : Int,
  _data : @pdfio.MutableBytes,
  im? : String,
) -> @pdfio.MutableBytes raise CodecError {
  let columns = _columns
  let rows = _rows
  let data = _data
  match im {
    None => encode_ccittg4_pure(columns, rows, data)
    Some(_) =>
      raise CodecError::DecodeNotSupported(
        "encode_ccittg4: use encode_ccittg4_async for imagemagick path",
      )
  }
}

///|
/// Encode data in CCITTDecode Group 4 via imagemagick (async I/O).
pub async fn encode_ccittg4_async(
  columns : Int,
  rows : Int,
  data : @pdfio.MutableBytes,
  im_path : String,
) -> @pdfio.MutableBytes raise CodecError {
  let dir = match @env.current_dir() {
    Some(path) => path
    None => "."
  }
  let stamp = @env.now().to_string()
  let input_path = "\{dir}/mbtpdf_ccittg4_\{stamp}.raw"
  let output_path = "\{dir}/mbtpdf_ccittg4_\{stamp}.pdf"
  let bytes = try {
    run_async_mapped("write ccittg4 input", () => @fs.write_file(
      input_path,
      Bytes::from_array(data),
    ))
    let args = [
      "-depth",
      "1",
      "-size",
      "\{columns}x\{rows}",
      input_path,
      "-compress",
      "GROUP4",
      output_path,
    ]
    let exit_code = run_async_mapped("run imagemagick", () => @process.run(
      im_path, args,
    ))
    if exit_code > 0 {
      raise CodecError::DecodeNotSupported("magick return code non-zero")
    }
    let pdf = (pdf_of_file.val)(None, None, None, output_path) catch {
      _ =>
        raise CodecError::DecodeNotSupported("malformed PDF from imagemagick")
    }
    extract_ccittg4_stream(pdf)
  } catch {
    CodecError::CouldntDecodeStream(msg) => {
      let _ : Result[Unit, Error] = try? @fs.remove(input_path)
      let _ : Result[Unit, Error] = try? @fs.remove(output_path)
      raise CodecError::CouldntDecodeStream(msg)
    }
    CodecError::DecodeNotSupported(msg) => {
      let _ : Result[Unit, Error] = try? @fs.remove(input_path)
      let _ : Result[Unit, Error] = try? @fs.remove(output_path)
      raise CodecError::DecodeNotSupported(msg)
    }
  }
  let _ : Result[Unit, Error] = try? @fs.remove(input_path)
  let _ : Result[Unit, Error] = try? @fs.remove(output_path)
  bytes
}

///|
/// Encode a PDF stream with an encoding.
pub fn encode_pdfstream(
  pdf : @pdf.Pdf,
  encoding : Encoding,
  obj : @pdf.PdfObject,
  im? : String,
  only_if_smaller? : Bool = false,
  predictor? : Predictor,
  predictor_columns? : Int,
) -> Unit raise CodecError {
  let _ = im
  let predictor_columns = match predictor_columns {
    Some(value) => value
    None => 1
  }
  let encoding_name = match encoding {
    Encoding::ASCIIHex => "/ASCIIHexDecode"
    Encoding::ASCII85 => "/ASCII85Decode"
    Encoding::RunLength => "/RunLengthDecode"
    Encoding::LZW(_) => "/LZWDecode"
    Encoding::Flate => "/FlateDecode"
    Encoding::CCITT(_, _) | Encoding::CCITTG4(_, _) => "/CCITTFaxDecode"
  }
  fn update_filter(dict : @pdf.PdfObject) -> @pdf.PdfObject raise CodecError {
    let filter_obj : @pdf.PdfObject = match
      @pdf.lookup_direct(pdf, "/Filter", dict) {
      None => Name(encoding_name)
      Some(Name(name)) =>
        Array([@pdf.PdfObject::Name(encoding_name), @pdf.PdfObject::Name(name)])
      Some(Array(filters)) => {
        let updated = Array::new(capacity=filters.length() + 1)
        updated.push(@pdf.PdfObject::Name(encoding_name))
        for f in filters {
          updated.push(f)
        }
        Array(updated)
      }
      Some(_) => raise CodecError::CouldntDecodeStream("malformed /Filter")
    }
    set_dict_entry(dict, "/Filter", filter_obj)
  }

  fn process_prediction(
    dict : @pdf.PdfObject,
    data : @pdfio.MutableBytes,
  ) -> (@pdf.PdfObject, @pdfio.MutableBytes) raise CodecError {
    match predictor {
      Some(pred) => {
        let (pred_value, colors, bpc) = match pred {
          Predictor::TIFF2 => (2, 1, 8)
          Predictor::PNGNone => (10, 1, 8)
          Predictor::PNGSub => (11, 1, 8)
          Predictor::PNGUp => (12, 1, 8)
          Predictor::PNGAverage => (13, 1, 8)
          Predictor::PNGPaeth => (14, 1, 8)
          Predictor::PNGOptimum => (15, 1, 8)
        }
        let predicted = encode_predictor(
          pred_value, colors, bpc, predictor_columns, data,
        )
        let decodeparms = @pdf.PdfObject::Dictionary([
          ("/Columns", @pdf.PdfObject::Integer(predictor_columns)),
          ("/Predictor", @pdf.PdfObject::Integer(pred_value)),
          ("/Colors", @pdf.PdfObject::Integer(colors)),
          ("/BitsPerComponent", @pdf.PdfObject::Integer(bpc)),
        ])
        let dict_with_parms = set_dict_entry(dict, "/DecodeParms", decodeparms)
        (dict_with_parms, predicted)
      }
      None => (dict, data)
    }
  }

  fn encode_stream(
    dict : @pdf.PdfObject,
    data : @pdfio.MutableBytes,
  ) -> (@pdf.PdfObject, @pdfio.MutableBytes) raise CodecError {
    let (predicted_dict, predicted_data) = process_prediction(dict, data)
    let encoded = match encoding {
      Encoding::ASCIIHex => encode_asciihex(predicted_data)
      Encoding::ASCII85 => encode_ascii85(predicted_data)
      Encoding::RunLength => encode_runlength(predicted_data)
      Encoding::LZW(early) => encode_lzw(early, predicted_data)
      Encoding::Flate => encode_flate(predicted_data)
      Encoding::CCITT(columns, rows) =>
        encode_ccitt(columns, rows, predicted_data)
      Encoding::CCITTG4(columns, rows) =>
        encode_ccittg4(columns, rows, predicted_data, im?)
    }
    let dict_with_filter = update_filter(predicted_dict)
    let dict_with_length = set_dict_entry(
      dict_with_filter,
      "/Length",
      @pdf.PdfObject::Integer(@pdfio.bytes_size(encoded)),
    )
    (dict_with_length, encoded)
  }

  match (obj : @pdf.PdfObject) {
    Stream(r) => {
      map_pdf_error("getstream", fn() raise { @pdf.getstream(obj) })
      let (dict, stream_data) = r.val
      let data = match (stream_data : @pdf.Stream) {
        Got(bytes) => bytes
        _ => raise CodecError::CouldntDecodeStream("stream data not available")
      }
      let (new_dict, new_data) = encode_stream(dict, data)
      if !only_if_smaller ||
        @pdfio.bytes_size(new_data) + 20 < @pdfio.bytes_size(data) {
        r.val = (new_dict, @pdf.Stream::Got(new_data))
      }
    }
    Indirect(i) =>
      encode_pdfstream(
        pdf,
        encoding,
        @pdf.direct(pdf, Indirect(i)),
        im?,
        only_if_smaller~,
        predictor?,
        predictor_columns~,
      )
    _ => raise CodecError::CouldntDecodeStream("malformed stream")
  }
}

///|
/// Decode a PDF stream, updating the document.
pub fn decode_pdfstream(
  _pdf : @pdf.Pdf,
  _obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  fn decode_one_stage(
    pdf : @pdf.Pdf,
    obj : @pdf.PdfObject,
  ) -> Unit raise CodecError {
    match (obj : @pdf.PdfObject) {
      Stream(r) => {
        let (dict, _stream) = r.val
        let filter_opt = @pdf.lookup_direct_orelse(pdf, "/Filter", "/F", dict)
        match filter_opt {
          None => ()
          Some(Name(_)) | Some(Array(_)) => {
            let before = (string_of_pdf.val)(dict)
            decode_pdfstream_onestage(pdf, obj, jbig2dec?)
            let (after_dict, _after_stream) = r.val
            let after = (string_of_pdf.val)(after_dict)
            if before != after {
              decode_one_stage(pdf, obj)
            }
          }
          Some(_) => raise CodecError::CouldntDecodeStream("malformed /Filter")
        }
      }
      Indirect(i) => decode_one_stage(pdf, @pdf.direct(pdf, Indirect(i)))
      _ => raise CodecError::CouldntDecodeStream("malformed stream")
    }
  }

  decode_one_stage(_pdf, _obj)
}

///|
/// Decode just one stage of a PDF stream.
pub fn decode_pdfstream_onestage(
  pdf : @pdf.Pdf,
  obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  match (obj : @pdf.PdfObject) {
    Stream(r) => {
      let (dict, _stream) = r.val
      let (filter_key, filter_opt) = match
        @pdf.lookup_immediate("/Filter", dict) {
        Some(_) => ("/Filter", @pdf.lookup_direct(pdf, "/Filter", dict))
        None =>
          match @pdf.lookup_immediate("/F", dict) {
            Some(_) => ("/F", @pdf.lookup_direct(pdf, "/F", dict))
            None => ("/Filter", None)
          }
      }
      let (parms_key, parms) = match
        @pdf.lookup_immediate("/DecodeParms", dict) {
        Some(_) =>
          ("/DecodeParms", @pdf.lookup_direct(pdf, "/DecodeParms", dict))
        None =>
          match @pdf.lookup_immediate("/DP", dict) {
            Some(_) => ("/DP", @pdf.lookup_direct(pdf, "/DP", dict))
            None => ("/DecodeParms", None)
          }
      }
      match filter_opt {
        None => raise CodecError::DecodeNotSupported("no filter")
        Some(filter_obj) => {
          let (filter_name, remaining_filters) : (
            String,
            Array[@pdf.PdfObject]?,
          ) = match (filter_obj : @pdf.PdfObject) {
            Name(name) => (name, None)
            Array([]) =>
              raise CodecError::DecodeNotSupported("empty filter array")
            Array([Name(name), .. rest]) => (name, Some(rest.to_array()))
            Array(_) =>
              raise CodecError::DecodeNotSupported("invalid filter entry")
            _ => raise CodecError::DecodeNotSupported("invalid filter")
          }
          map_pdf_error("getstream", fn() raise { @pdf.getstream(obj) })
          let data = match r.val {
            (_, @pdf.Stream::Got(bytes)) => bytes
            _ =>
              raise CodecError::CouldntDecodeStream("stream data not available")
          }
          let parms_first = match parms {
            Some(Array(arr)) =>
              if arr.length() > 0 {
                Some(arr[0])
              } else {
                None
              }
            Some(Null) => None
            Some(other) => Some(other)
            None => None
          }
          let decoded = if filter_name == "/FlateDecode" || filter_name == "/Fl" {
            let mut decoded = decode_flate(data)
            match parms_first {
              Some(Dictionary(_)) => {
                let predictor = get_int_param(pdf, parms_first, "/Predictor", 1)
                if predictor != 1 {
                  let colors = get_int_param(pdf, parms_first, "/Colors", 1)
                  let bpc = get_int_param(
                    pdf, parms_first, "/BitsPerComponent", 8,
                  )
                  let columns = get_int_param(pdf, parms_first, "/Columns", 1)
                  decoded = decode_predictor(
                    predictor, colors, bpc, columns, decoded,
                  )
                }
              }
              _ => ()
            }
            decoded
          } else if filter_name == "/ASCIIHexDecode" || filter_name == "/AHx" {
            decode_asciihex(@pdfio.input_of_bytes(data, source="asciihex"))
          } else if filter_name == "/ASCII85Decode" || filter_name == "/A85" {
            decode_ascii85(@pdfio.input_of_bytes(data, source="ascii85"))
          } else if filter_name == "/RunLengthDecode" || filter_name == "/RL" {
            decode_runlength(@pdfio.input_of_bytes(data, source="runlength"))
          } else if filter_name == "/LZWDecode" || filter_name == "/LZW" {
            let early = get_int_param(pdf, parms_first, "/EarlyChange", 1)
            decode_lzw(early, @pdfio.input_of_bytes(data, source="lzw"))
          } else if filter_name == "/Crypt" {
            data
          } else if filter_name == "/JBIG2Decode" {
            let _ = jbig2dec
            raise CodecError::DecodeNotSupported(
              "JBIG2Decode requires decode_pdfstream_async",
            )
          } else if filter_name == "/CCITTFaxDecode" || filter_name == "/CCF" {
            let k = get_int_param(pdf, parms_first, "/K", 0)
            let eol = get_bool_param(pdf, parms_first, "/EndOfLine", false)
            let eba = get_bool_param(
              pdf, parms_first, "/EncodedByteAlign", false,
            )
            let columns = get_int_param(pdf, parms_first, "/Columns", 1728)
            let rows = get_int_param(pdf, parms_first, "/Rows", 0)
            let eob = get_bool_param(pdf, parms_first, "/EndOfBlock", true)
            let bone = get_bool_param(pdf, parms_first, "/BlackIs1", false)
            let dra = get_int_param(
              pdf, parms_first, "/DamagedRowsBeforeError", 0,
            )
            decode_ccittfax(
              k,
              eol,
              eba,
              columns,
              rows,
              eob,
              bone,
              dra,
              @pdfio.input_of_bytes(data, source="ccitt"),
            )
          } else {
            raise CodecError::DecodeNotSupported(
              "filter not supported: \{filter_name}",
            )
          }
          let mut new_dict = dict
          new_dict = match remaining_filters {
            None =>
              map_pdf_error("remove filter", fn() raise {
                @pdf.remove_dict_entry(new_dict, filter_key)
              })
            Some(rest) =>
              if rest.length() == 0 {
                map_pdf_error("remove filter", fn() raise {
                  @pdf.remove_dict_entry(new_dict, filter_key)
                })
              } else {
                map_pdf_error("replace filter", fn() raise {
                  @pdf.replace_dict_entry(
                    new_dict,
                    filter_key,
                    @pdf.PdfObject::Array(rest),
                  )
                })
              }
          }
          new_dict = match parms {
            None => new_dict
            Some(Array(arr)) => {
              let rest = arr.sub(start=1).to_array()
              if rest.length() == 0 {
                map_pdf_error("remove decode parms", fn() raise {
                  @pdf.remove_dict_entry(new_dict, parms_key)
                })
              } else {
                map_pdf_error("replace decode parms", fn() raise {
                  @pdf.replace_dict_entry(
                    new_dict,
                    parms_key,
                    @pdf.PdfObject::Array(rest),
                  )
                })
              }
            }
            Some(_) =>
              map_pdf_error("remove decode parms", fn() raise {
                @pdf.remove_dict_entry(new_dict, parms_key)
              })
          }
          new_dict = set_dict_entry(
            new_dict,
            "/Length",
            @pdf.PdfObject::Integer(@pdfio.bytes_size(decoded)),
          )
          r.val = (new_dict, @pdf.Stream::Got(decoded))
        }
      }
    }
    _ => raise CodecError::DecodeNotSupported("not a stream")
  }
}

///|
/// Decode until there's an unknown decoder.
pub fn decode_pdfstream_until_unknown(
  _pdf : @pdf.Pdf,
  _obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  decode_pdfstream(_pdf, _obj, jbig2dec?) catch {
    CodecError::DecodeNotSupported(_) => ()
    err => raise err
  }
}

///|
/// Decode a PDF stream, updating the document (async variant with JBIG2).
pub async fn decode_pdfstream_async(
  _pdf : @pdf.Pdf,
  _obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  async fn decode_one_stage(
    pdf : @pdf.Pdf,
    obj : @pdf.PdfObject,
  ) -> Unit raise CodecError {
    match (obj : @pdf.PdfObject) {
      Stream(r) => {
        let (dict, _stream) = r.val
        let filter_opt = @pdf.lookup_direct_orelse(pdf, "/Filter", "/F", dict)
        match filter_opt {
          None => ()
          Some(Name(_)) | Some(Array(_)) => {
            let before = (string_of_pdf.val)(dict)
            decode_pdfstream_onestage_async(pdf, obj, jbig2dec?)
            let (after_dict, _after_stream) = r.val
            let after = (string_of_pdf.val)(after_dict)
            if before != after {
              decode_one_stage(pdf, obj)
            }
          }
          Some(_) => raise CodecError::CouldntDecodeStream("malformed /Filter")
        }
      }
      Indirect(i) => decode_one_stage(pdf, @pdf.direct(pdf, Indirect(i)))
      _ => raise CodecError::CouldntDecodeStream("malformed stream")
    }
  }

  decode_one_stage(_pdf, _obj)
}

///|
/// Decode just one stage of a PDF stream (async variant with JBIG2).
pub async fn decode_pdfstream_onestage_async(
  pdf : @pdf.Pdf,
  obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  match (obj : @pdf.PdfObject) {
    Stream(r) => {
      let (dict, _stream) = r.val
      let (filter_key, filter_opt) = match
        @pdf.lookup_immediate("/Filter", dict) {
        Some(_) => ("/Filter", @pdf.lookup_direct(pdf, "/Filter", dict))
        None =>
          match @pdf.lookup_immediate("/F", dict) {
            Some(_) => ("/F", @pdf.lookup_direct(pdf, "/F", dict))
            None => ("/Filter", None)
          }
      }
      let (parms_key, parms) = match
        @pdf.lookup_immediate("/DecodeParms", dict) {
        Some(_) =>
          ("/DecodeParms", @pdf.lookup_direct(pdf, "/DecodeParms", dict))
        None =>
          match @pdf.lookup_immediate("/DP", dict) {
            Some(_) => ("/DP", @pdf.lookup_direct(pdf, "/DP", dict))
            None => ("/DecodeParms", None)
          }
      }
      match filter_opt {
        None => raise CodecError::DecodeNotSupported("no filter")
        Some(filter_obj) => {
          let (filter_name, remaining_filters) : (
            String,
            Array[@pdf.PdfObject]?,
          ) = match (filter_obj : @pdf.PdfObject) {
            Name(name) => (name, None)
            Array([]) =>
              raise CodecError::DecodeNotSupported("empty filter array")
            Array([Name(name), .. rest]) => (name, Some(rest.to_array()))
            Array(_) =>
              raise CodecError::DecodeNotSupported("invalid filter entry")
            _ => raise CodecError::DecodeNotSupported("invalid filter")
          }
          map_pdf_error("getstream", fn() raise { @pdf.getstream(obj) })
          let data = match r.val {
            (_, @pdf.Stream::Got(bytes)) => bytes
            _ =>
              raise CodecError::CouldntDecodeStream("stream data not available")
          }
          let parms_first = match parms {
            Some(Array(arr)) =>
              if arr.length() > 0 {
                Some(arr[0])
              } else {
                None
              }
            Some(Null) => None
            Some(other) => Some(other)
            None => None
          }
          let decoded = if filter_name == "/FlateDecode" || filter_name == "/Fl" {
            let mut decoded = decode_flate(data)
            match parms_first {
              Some(Dictionary(_)) => {
                let predictor = get_int_param(pdf, parms_first, "/Predictor", 1)
                if predictor != 1 {
                  let colors = get_int_param(pdf, parms_first, "/Colors", 1)
                  let bpc = get_int_param(
                    pdf, parms_first, "/BitsPerComponent", 8,
                  )
                  let columns = get_int_param(pdf, parms_first, "/Columns", 1)
                  decoded = decode_predictor(
                    predictor, colors, bpc, columns, decoded,
                  )
                }
              }
              _ => ()
            }
            decoded
          } else if filter_name == "/ASCIIHexDecode" || filter_name == "/AHx" {
            decode_asciihex(@pdfio.input_of_bytes(data, source="asciihex"))
          } else if filter_name == "/ASCII85Decode" || filter_name == "/A85" {
            decode_ascii85(@pdfio.input_of_bytes(data, source="ascii85"))
          } else if filter_name == "/RunLengthDecode" || filter_name == "/RL" {
            decode_runlength(@pdfio.input_of_bytes(data, source="runlength"))
          } else if filter_name == "/LZWDecode" || filter_name == "/LZW" {
            let early = get_int_param(pdf, parms_first, "/EarlyChange", 1)
            decode_lzw(early, @pdfio.input_of_bytes(data, source="lzw"))
          } else if filter_name == "/Crypt" {
            data
          } else if filter_name == "/JBIG2Decode" {
            let jbig2_path = match jbig2dec {
              Some(path) => path
              None =>
                raise CodecError::DecodeNotSupported(
                  "JBIG2Decode requires jbig2dec",
                )
            }
            let globals = jbig2_globals(pdf, parms_first)
            decode_jbig2(
              globals,
              jbig2_path,
              @pdfio.input_of_bytes(data, source="jbig2"),
            )
          } else if filter_name == "/CCITTFaxDecode" || filter_name == "/CCF" {
            let k = get_int_param(pdf, parms_first, "/K", 0)
            let eol = get_bool_param(pdf, parms_first, "/EndOfLine", false)
            let eba = get_bool_param(
              pdf, parms_first, "/EncodedByteAlign", false,
            )
            let columns = get_int_param(pdf, parms_first, "/Columns", 1728)
            let rows = get_int_param(pdf, parms_first, "/Rows", 0)
            let eob = get_bool_param(pdf, parms_first, "/EndOfBlock", true)
            let bone = get_bool_param(pdf, parms_first, "/BlackIs1", false)
            let dra = get_int_param(
              pdf, parms_first, "/DamagedRowsBeforeError", 0,
            )
            decode_ccittfax(
              k,
              eol,
              eba,
              columns,
              rows,
              eob,
              bone,
              dra,
              @pdfio.input_of_bytes(data, source="ccitt"),
            )
          } else {
            raise CodecError::DecodeNotSupported(
              "filter not supported: \{filter_name}",
            )
          }
          let mut new_dict = dict
          new_dict = match remaining_filters {
            None =>
              map_pdf_error("remove filter", fn() raise {
                @pdf.remove_dict_entry(new_dict, filter_key)
              })
            Some(rest) =>
              if rest.length() == 0 {
                map_pdf_error("remove filter", fn() raise {
                  @pdf.remove_dict_entry(new_dict, filter_key)
                })
              } else {
                map_pdf_error("replace filter", fn() raise {
                  @pdf.replace_dict_entry(
                    new_dict,
                    filter_key,
                    @pdf.PdfObject::Array(rest),
                  )
                })
              }
          }
          new_dict = match parms {
            None => new_dict
            Some(Array(arr)) => {
              let rest = arr.sub(start=1).to_array()
              if rest.length() == 0 {
                map_pdf_error("remove decode parms", fn() raise {
                  @pdf.remove_dict_entry(new_dict, parms_key)
                })
              } else {
                map_pdf_error("replace decode parms", fn() raise {
                  @pdf.replace_dict_entry(
                    new_dict,
                    parms_key,
                    @pdf.PdfObject::Array(rest),
                  )
                })
              }
            }
            Some(_) =>
              map_pdf_error("remove decode parms", fn() raise {
                @pdf.remove_dict_entry(new_dict, parms_key)
              })
          }
          new_dict = set_dict_entry(
            new_dict,
            "/Length",
            @pdf.PdfObject::Integer(@pdfio.bytes_size(decoded)),
          )
          r.val = (new_dict, @pdf.Stream::Got(decoded))
        }
      }
    }
    _ => raise CodecError::DecodeNotSupported("not a stream")
  }
}

///|
/// Decode until there's an unknown decoder (async variant with JBIG2).
pub async fn decode_pdfstream_until_unknown_async(
  _pdf : @pdf.Pdf,
  _obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  decode_pdfstream_async(_pdf, _obj, jbig2dec?) catch {
    CodecError::DecodeNotSupported(_) => ()
    err => raise err
  }
}

///|
/// Decode bytes using filters in dict; returns None when decoder unsupported.
pub fn decode_from_bytes(
  bytes : @pdfio.MutableBytes,
  dict : @pdf.PdfObject,
) -> @pdfio.MutableBytes? {
  let pdf = @pdf.empty()
  let filter_opt = @pdf.lookup_direct_orelse(pdf, "/F", "/Filter", dict)
  let parms_opt = @pdf.lookup_direct_orelse(pdf, "/DP", "/DecodeParms", dict)
  fn parms_at(index : Int) -> @pdf.PdfObject? {
    match parms_opt {
      Some(Array(arr)) =>
        if index < arr.length() {
          Some(arr[index])
        } else {
          None
        }
      Some(Null) => None
      Some(other) => if index == 0 { Some(other) } else { None }
      None => None
    }
  }

  fn decode_stage(
    bytes : @pdfio.MutableBytes,
    filter_name : String,
    parms : @pdf.PdfObject?,
  ) -> @pdfio.MutableBytes? {
    if filter_name == "/FlateDecode" || filter_name == "/Fl" {
      let mut decoded = decode_flate(bytes) catch { _ => return None }
      match parms {
        Some(Dictionary(_)) => {
          let predictor = get_int_param(pdf, parms, "/Predictor", 1)
          if predictor != 1 {
            let colors = get_int_param(pdf, parms, "/Colors", 1)
            let bpc = get_int_param(pdf, parms, "/BitsPerComponent", 8)
            let columns = get_int_param(pdf, parms, "/Columns", 1)
            decoded = decode_predictor(predictor, colors, bpc, columns, decoded) catch {
              _ => return None
            }
          }
        }
        _ => ()
      }
      Some(decoded)
    } else if filter_name == "/ASCIIHexDecode" || filter_name == "/AHx" {
      let input = @pdfio.input_of_bytes(bytes, source="asciihex")
      let decoded = decode_asciihex(input) catch { _ => return None }
      Some(decoded)
    } else if filter_name == "/ASCII85Decode" || filter_name == "/A85" {
      let input = @pdfio.input_of_bytes(bytes, source="ascii85")
      let decoded = decode_ascii85(input) catch { _ => return None }
      Some(decoded)
    } else if filter_name == "/RunLengthDecode" || filter_name == "/RL" {
      let input = @pdfio.input_of_bytes(bytes, source="runlength")
      Some(decode_runlength(input))
    } else if filter_name == "/LZWDecode" || filter_name == "/LZW" {
      let early = get_int_param(pdf, parms, "/EarlyChange", 1)
      let input = @pdfio.input_of_bytes(bytes, source="lzw")
      let decoded = decode_lzw(early, input) catch { _ => return None }
      Some(decoded)
    } else if filter_name == "/Crypt" {
      Some(bytes)
    } else if filter_name == "/CCITTFaxDecode" || filter_name == "/CCF" {
      let k = get_int_param(pdf, parms, "/K", 0)
      let eol = get_bool_param(pdf, parms, "/EndOfLine", false)
      let eba = get_bool_param(pdf, parms, "/EncodedByteAlign", false)
      let columns = get_int_param(pdf, parms, "/Columns", 1728)
      let rows = get_int_param(pdf, parms, "/Rows", 0)
      let eob = get_bool_param(pdf, parms, "/EndOfBlock", true)
      let bone = get_bool_param(pdf, parms, "/BlackIs1", false)
      let dra = get_int_param(pdf, parms, "/DamagedRowsBeforeError", 0)
      let input = @pdfio.input_of_bytes(bytes, source="ccitt")
      let decoded = decode_ccittfax(
        k, eol, eba, columns, rows, eob, bone, dra, input,
      ) catch {
        _ => return None
      }
      Some(decoded)
    } else {
      None
    }
  }

  match filter_opt {
    Some(Name(name)) => decode_stage(bytes, name, parms_at(0))
    Some(Array(filters)) => {
      if filters.length() == 0 {
        return None
      }
      let mut current = bytes
      for i in 0..<filters.length() {
        let filter_name = match (filters[i] : @pdf.PdfObject) {
          Name(name) => name
          _ => return None
        }
        match decode_stage(current, filter_name, parms_at(i)) {
          Some(decoded) => current = decoded
          None => return None
        }
      }
      Some(current)
    }
    _ => None
  }
}

///|
/// Decode from input; returns None when decoder unsupported.
pub fn decode_from_input(
  input : @pdfio.Input,
  dict : @pdf.PdfObject,
) -> @pdfio.MutableBytes? {
  let start = (input.pos_in)()
  let length = input.in_channel_length - start
  if length < 0 {
    return None
  }
  let data_res : Result[@pdfio.MutableBytes, Error] = try? @pdfio.bytes_of_input(
    input, start, length,
  )
  let data = match data_res {
    Ok(bytes) => bytes
    Err(_) => return None
  }
  decode_from_bytes(data, dict)
}

///|
/// Encode predictor.
fn sub_mod(a : Int, b : Int) -> Int {
  let mut delta = a - b
  if delta < 0 {
    delta = delta + 256
  }
  delta
}

///|
fn paeth(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = (p - a).abs()
  let pb = (p - b).abs()
  let pc = (p - c).abs()
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
fn encode_png_filter(
  current : Array[Int],
  prior : Array[Int],
  bytes_per_pixel : Int,
  filter : Int,
) -> Array[Int] {
  let out = Array::new(capacity=current.length())
  for i in 0..<current.length() {
    let left = if i < bytes_per_pixel {
      0
    } else {
      current[i - bytes_per_pixel]
    }
    let up = if i < prior.length() { prior[i] } else { 0 }
    let up_left = if i < bytes_per_pixel {
      0
    } else {
      prior[i - bytes_per_pixel]
    }
    let predicted = match filter {
      0 => 0
      1 => left
      2 => up
      3 => (left + up) / 2
      4 => paeth(left, up, up_left)
      _ => 0
    }
    out.push(sub_mod(current[i], predicted))
  }
  out
}

///|
fn predictor_cost(values : Array[Int]) -> Int {
  let mut total = 0
  for v in values {
    let signed = if v > 127 { v - 256 } else { v }
    total = total + signed.abs()
  }
  total
}

///|
fn encode_png_line(
  current : Array[Int],
  prior : Array[Int],
  bytes_per_pixel : Int,
  pred : Int,
) -> (Int, Array[Int]) {
  let filter = if pred == 15 { -1 } else { pred - 10 }
  if filter >= 0 && filter <= 4 {
    let encoded = encode_png_filter(current, prior, bytes_per_pixel, filter)
    return (filter, encoded)
  }
  let mut best_filter = 0
  let mut best_encoded = encode_png_filter(current, prior, bytes_per_pixel, 0)
  let mut best_cost = predictor_cost(best_encoded)
  for f in 1..<=4 {
    let candidate = encode_png_filter(current, prior, bytes_per_pixel, f)
    let cost = predictor_cost(candidate)
    if cost < best_cost {
      best_cost = cost
      best_filter = f
      best_encoded = candidate
    }
  }
  (best_filter, best_encoded)
}

///|
fn encode_png_predictor(
  pred : Int,
  colors : Int,
  bpc : Int,
  columns : Int,
  stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  if bpc != 8 {
    raise CodecError::DecodeNotSupported("PNG predictor only supports 8bpc")
  }
  let scanline_width = (colors * bpc * columns + 7) / 8
  let bytes_per_pixel = (bpc * colors + 7) / 8
  let (output, data) = @pdfio.input_output_of_bytes(4096)
  let lines = if scanline_width == 0 {
    0
  } else {
    @pdfio.bytes_size(stream) / scanline_width
  }
  let prior = Array::make(scanline_width, 0)
  for line in 0..<lines {
    let current = Array::make(scanline_width, 0)
    for i in 0..<scanline_width {
      current[i] = @pdfio.bget(stream, line * scanline_width + i)
    }
    let (filter, encoded) = encode_png_line(
      current, prior, bytes_per_pixel, pred,
    )
    (output.output_byte)(filter)
    for v in encoded {
      (output.output_byte)(v)
    }
    for i in 0..<scanline_width {
      prior[i] = current[i]
    }
  }
  @pdfio.extract_bytes_from_input_output(output, data)
}

///|
fn encode_tiff_predictor(
  colors : Int,
  bpc : Int,
  columns : Int,
  stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  if bpc != 8 {
    raise CodecError::DecodeNotSupported("TIFF predictor only supports 8bpc")
  }
  let bytes_per_pixel = (bpc * colors + 7) / 8
  let scanline_width = (colors * bpc * columns + 7) / 8
  let out = stream.copy()
  let lines = if scanline_width == 0 {
    0
  } else {
    @pdfio.bytes_size(stream) / scanline_width
  }
  for line in 0..<lines {
    let line_start = line * scanline_width
    for p in bytes_per_pixel..<scanline_width {
      let curr = @pdfio.bget(stream, line_start + p)
      let left = @pdfio.bget(stream, line_start + p - bytes_per_pixel)
      out[line_start + p] = sub_mod(curr, left).to_byte()
    }
  }
  out
}

///|
pub fn encode_predictor(
  _pred : Int,
  _colors : Int,
  _bpc : Int,
  _columns : Int,
  _stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let pred = _pred
  let colors = _colors
  let bpc = _bpc
  let columns = _columns
  let stream = _stream
  match pred {
    2 => encode_tiff_predictor(colors, bpc, columns, stream)
    10 | 11 | 12 | 13 | 14 | 15 =>
      encode_png_predictor(pred, colors, bpc, columns, stream)
    _ =>
      raise CodecError::DecodeNotSupported(
        "encode_predictor: not supported - \{pred}",
      )
  }
}

///|
/// Decode predictor (placeholder).
pub fn decode_predictor(
  _pred : Int,
  _colors : Int,
  _bpc : Int,
  _columns : Int,
  _stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let pred = _pred
  let colors = _colors
  let bpc = _bpc
  let columns = _columns
  let stream = _stream
  if pred == 2 {
    decode_tiff_predictor(colors, bpc, columns, stream)
  } else {
    decode_png_predictor(colors, bpc, columns, stream)
  }
}

///|
fn[T] map_pdf_error(
  context : String,
  action : () -> T raise,
) -> T raise CodecError {
  action() catch {
    @pdf.PdfError::Msg(msg) =>
      raise CodecError::CouldntDecodeStream("\{context}: \{msg}")
    _ => raise CodecError::CouldntDecodeStream("\{context}: unknown error")
  }
}

///|
fn set_dict_entry(
  dict : @pdf.PdfObject,
  key : String,
  value : @pdf.PdfObject,
) -> @pdf.PdfObject raise CodecError {
  match @pdf.lookup_immediate(key, dict) {
    Some(_) =>
      map_pdf_error("replace dict entry", fn() raise {
        @pdf.replace_dict_entry(dict, key, value)
      })
    None =>
      map_pdf_error("add dict entry", fn() raise {
        @pdf.add_dict_entry(dict, key, value)
      })
  }
}

///|
fn get_int_param(
  pdf : @pdf.Pdf,
  parms : @pdf.PdfObject?,
  key : String,
  default_value : Int,
) -> Int {
  match parms {
    Some(obj) =>
      match @pdf.lookup_direct(pdf, key, obj) {
        Some(Integer(i)) => i
        Some(Real(r)) => r.to_int()
        _ => default_value
      }
    None => default_value
  }
}

///|
fn get_bool_param(
  pdf : @pdf.Pdf,
  parms : @pdf.PdfObject?,
  key : String,
  default_value : Bool,
) -> Bool {
  match parms {
    Some(obj) =>
      match @pdf.lookup_direct(pdf, key, obj) {
        Some(Boolean(b)) => b
        _ => default_value
      }
    None => default_value
  }
}

///|
fn decode_tiff_predictor(
  colors : Int,
  bpc : Int,
  columns : Int,
  stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  if bpc != 8 {
    raise CodecError::DecodeNotSupported("TIFF predictor only supports 8bpc")
  }
  let scanline_width = (colors * bpc * columns + 7) / 8
  let out = stream.copy()
  let lines = if scanline_width == 0 {
    0
  } else {
    out.length() / scanline_width
  }
  for line in 0..<lines {
    let line_start = line * scanline_width
    for p in colors..<scanline_width {
      let val = (
          out[line_start + p - colors].to_int() + out[line_start + p].to_int()
        ) %
        256
      out[line_start + p] = val.to_byte()
    }
  }
  out
}

///|
fn decode_png_predictor(
  colors : Int,
  bpc : Int,
  columns : Int,
  stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  if bpc != 8 {
    raise CodecError::DecodeNotSupported("PNG predictor only supports 8bpc")
  }
  let scanline_width = (colors * bpc * columns + 7) / 8
  let bytes_per_pixel = (bpc * colors + 7) / 8
  let mut pos = 0
  let prev_decoded = Array::make(scanline_width, 0)
  let output : @pdfio.MutableBytes = Array::new()
  while pos < stream.length() {
    let predictor = stream[pos].to_int()
    pos = pos + 1
    let curr = Array::make(scanline_width, 0)
    let mut i = 0
    while i < scanline_width && pos < stream.length() {
      curr[i] = stream[pos].to_int()
      pos = pos + 1
      i = i + 1
    }
    let decoded = decode_scanline_pair(
      prev_decoded, curr, predictor, bytes_per_pixel,
    )
    for v in decoded {
      output.push(v.to_byte())
    }
    for i in 0..<scanline_width {
      prev_decoded[i] = decoded[i]
    }
    if i < scanline_width {
      break
    }
  }
  output
}

///|
fn decode_scanline_pair(
  prior_decoded : Array[Int],
  current : Array[Int],
  pred : Int,
  bytes_per_pixel : Int,
) -> Array[Int] raise CodecError {
  let output = current.copy()
  let get0 = (arr : Array[Int], idx : Int) => if idx < 0 { 0 } else { arr[idx] }
  match pred {
    0 => ()
    1 =>
      for i in 0..<output.length() {
        output[i] = (get0(current, i) + get0(output, i - bytes_per_pixel)) % 256
      }
    2 =>
      for i in 0..<output.length() {
        output[i] = (get0(current, i) + get0(prior_decoded, i)) % 256
      }
    3 =>
      for i in 0..<output.length() {
        let left = get0(output, i - bytes_per_pixel)
        let up = get0(prior_decoded, i)
        output[i] = (get0(current, i) + (left + up) / 2) % 256
      }
    4 => {
      let paeth = (a : Int, b : Int, c : Int) => {
        let p = a + b - c
        let pa = (p - a).abs()
        let pb = (p - b).abs()
        let pc = (p - c).abs()
        if pa <= pb && pa <= pc {
          a
        } else if pb <= pc {
          b
        } else {
          c
        }
      }
      for i in 0..<output.length() {
        let curr = get0(current, i)
        let left = get0(output, i - bytes_per_pixel)
        let up = get0(prior_decoded, i)
        let up_left = get0(prior_decoded, i - bytes_per_pixel)
        output[i] = (curr + paeth(left, up, up_left)) % 256
      }
    }
    _ => raise CodecError::DecodeNotSupported("unknown PNG predictor")
  }
  output
}
