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
pub struct PdfCodec {
  unit : Unit
}

///|
pub fn PdfCodec::new() -> PdfCodec {
  { unit: () }
}

///|
/// Predictors for decoded data.
#warnings("-unused_constructor")
enum Predictor {
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
let flate_level : Ref[Int] = { val: 6 }

///|
/// Encode data in FlateDecode.
pub fn PdfCodec::encode_flate(
  _self : PdfCodec,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes {
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
  @pdfflate.PdfFlate::new().compress(
    level=flate_level.val,
    header=true,
    input,
    output,
  )
  out
}
