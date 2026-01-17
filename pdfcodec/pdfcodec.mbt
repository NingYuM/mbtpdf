///|
/// Supported stream encodings.
pub enum Encoding {
  ASCIIHex
  ASCII85
  RunLength
  Flate
  CCITT(Int, Int)
  CCITTG4(Int, Int)
}

///|
/// Predictors for decoded data.
pub enum Predictor {
  TIFF2
  PNGNone
  PNGSub
  PNGUp
  PNGAverage
  PNGPaeth
  PNGOptimum
}

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
pub let string_of_pdf : Ref[(@pdf.PdfObject) -> String] = { val: (_) => "" }

///|
/// Placeholder for Pdf.of_file (revision?, owner?, user?, filename).
pub let pdf_of_file : Ref[(Int?, String?, String?, String) -> @pdf.Pdf] = {
  val: (_, _, _, _) => @pdf.empty()
}

///|
/// Encode data in FlateDecode.
pub fn encode_flate(data : @pdfio.MutableBytes) -> @pdfio.MutableBytes raise CodecError {
  let _ = data
  raise CodecError::DecodeNotSupported("encode_flate not implemented")
}

///|
/// Decode data in FlateDecode.
pub fn decode_flate(data : @pdfio.MutableBytes) -> @pdfio.MutableBytes raise CodecError {
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
  try {
    @pdfflate.uncompress(header=true, input, output)
    out
  } catch {
    @pdfflate.FlateError::Error(stage, msg) =>
      raise CodecError::CouldntDecodeStream("\{stage}: \{msg}")
  }
}

///|
/// Encode data in CCITTDecode Group 3.
pub fn encode_ccitt(_columns : Int, _rows : Int, _data : @pdfio.MutableBytes) -> @pdfio.MutableBytes raise CodecError {
  raise CodecError::DecodeNotSupported("encode_ccitt not implemented")
}

///|
/// Encode data in CCITTDecode Group 4.
pub fn encode_ccittg4(
  _columns : Int,
  _rows : Int,
  _data : @pdfio.MutableBytes,
  im? : String,
) -> @pdfio.MutableBytes raise CodecError {
  let _ = im
  raise CodecError::DecodeNotSupported("encode_ccittg4 not implemented")
}

///|
/// Encode a PDF stream with an encoding.
pub fn encode_pdfstream(
  _pdf : @pdf.Pdf,
  _encoding : Encoding,
  _obj : @pdf.PdfObject,
  im? : String,
  only_if_smaller? : Bool = false,
  predictor? : Predictor,
  predictor_columns? : Int,
) -> Unit raise CodecError {
  let _ = im
  let _ = only_if_smaller
  let _ = predictor
  let _ = predictor_columns
  raise CodecError::DecodeNotSupported("encode_pdfstream not implemented")
}

///|
/// Decode a PDF stream, updating the document.
pub fn decode_pdfstream(
  _pdf : @pdf.Pdf,
  _obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  let _ = jbig2dec
  raise CodecError::DecodeNotSupported("decode_pdfstream not implemented")
}

///|
/// Decode just one stage of a PDF stream.
pub fn decode_pdfstream_onestage(
  _pdf : @pdf.Pdf,
  _obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  let _ = jbig2dec
  raise CodecError::DecodeNotSupported("decode_pdfstream_onestage not implemented")
}

///|
/// Decode until there's an unknown decoder.
pub fn decode_pdfstream_until_unknown(
  _pdf : @pdf.Pdf,
  _obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  let _ = jbig2dec
  raise CodecError::DecodeNotSupported("decode_pdfstream_until_unknown not implemented")
}

///|
/// Decode from input; returns None when decoder unsupported.
pub fn decode_from_input(
  _input : @pdfio.Input,
  _dict : @pdf.PdfObject,
) -> @pdfio.MutableBytes? {
  None
}

///|
/// Encode predictor (placeholder).
pub fn encode_predictor(
  _pred : Int,
  _colors : Int,
  _bpc : Int,
  _columns : Int,
  _stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  raise CodecError::DecodeNotSupported("encode_predictor not implemented")
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
  raise CodecError::DecodeNotSupported("decode_predictor not implemented")
}
