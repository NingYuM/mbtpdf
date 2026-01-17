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
pub let string_of_pdf : Ref[(@pdf.PdfObject) -> String] = { val: _ => "" }

///|
/// Placeholder for Pdf.of_file (revision?, user?, owner?, filename).
pub let pdf_of_file : Ref[(Int?, String?, String?, String) -> @pdf.Pdf raise] = {
  val: (_, _, _, _) => @pdf.empty(),
}

///|
/// Encode data in FlateDecode.
pub fn encode_flate(
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
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
  try {
    @pdfflate.compress(level=flate_level.val, header=true, input, output)
    out
  } catch {
    @pdfflate.FlateError::Error(stage, msg) =>
      raise CodecError::CouldntDecodeStream("\{stage}: \{msg}")
  }
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
pub fn encode_ccitt(
  _columns : Int,
  _rows : Int,
  _data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
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
  fn decode_one_stage(
    pdf : @pdf.Pdf,
    obj : @pdf.PdfObject,
  ) -> Unit raise CodecError {
    match obj {
      @pdf.PdfObject::Stream(r) => {
        let (dict, _stream) = r.val
        let filter_opt = @pdf.lookup_direct_orelse(pdf, "/Filter", "/F", dict)
        match filter_opt {
          None => ()
          Some(@pdf.PdfObject::Name(_)) | Some(@pdf.PdfObject::Array(_)) => {
            let before = (string_of_pdf.val)(dict)
            decode_pdfstream_onestage(pdf, obj)
            let (after_dict, _after_stream) = r.val
            let after = (string_of_pdf.val)(after_dict)
            if before != after {
              decode_one_stage(pdf, obj)
            }
          }
          Some(_) => raise CodecError::CouldntDecodeStream("malformed /Filter")
        }
      }
      @pdf.PdfObject::Indirect(i) =>
        decode_one_stage(pdf, @pdf.direct(pdf, @pdf.PdfObject::Indirect(i)))
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
  let _ = jbig2dec
  match obj {
    @pdf.PdfObject::Stream(r) => {
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
          ) = match filter_obj {
            @pdf.PdfObject::Name(name) => (name, None)
            @pdf.PdfObject::Array(filters) => {
              if filters.length() == 0 {
                raise CodecError::DecodeNotSupported("empty filter array")
              }
              match filters[0] {
                @pdf.PdfObject::Name(name) => {
                  let rest = filters.sub(start=1).to_array()
                  (name, Some(rest))
                }
                _ =>
                  raise CodecError::DecodeNotSupported("invalid filter entry")
              }
            }
            _ => raise CodecError::DecodeNotSupported("invalid filter")
          }
          if filter_name != "/FlateDecode" && filter_name != "/Fl" {
            raise CodecError::DecodeNotSupported(
              "filter not supported: \{filter_name}",
            )
          }
          map_pdf_error("getstream", fn() raise { @pdf.getstream(obj) })
          let data = match r.val {
            (_, @pdf.Stream::Got(bytes)) => bytes
            _ =>
              raise CodecError::CouldntDecodeStream("stream data not available")
          }
          let mut decoded = decode_flate(data)
          let parms_first = match parms {
            Some(@pdf.PdfObject::Array(arr)) =>
              if arr.length() > 0 {
                Some(arr[0])
              } else {
                None
              }
            Some(@pdf.PdfObject::Null) => None
            Some(other) => Some(other)
            None => None
          }
          match parms_first {
            Some(@pdf.PdfObject::Dictionary(_)) => {
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
            Some(@pdf.PdfObject::Array(arr)) => {
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
  let _ = jbig2dec
  decode_pdfstream(_pdf, _obj) catch {
    CodecError::DecodeNotSupported(_) => ()
    err => raise err
  }
}

///|
/// Decode from input; returns None when decoder unsupported.
pub fn decode_from_input(
  input : @pdfio.Input,
  dict : @pdf.PdfObject,
) -> @pdfio.MutableBytes? {
  let pdf = @pdf.empty()
  let filter_opt = @pdf.lookup_direct_orelse(pdf, "/F", "/Filter", dict)
  let parms_opt = @pdf.lookup_direct_orelse(pdf, "/DP", "/DecodeParms", dict)
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
  fn parms_at(index : Int) -> @pdf.PdfObject? {
    match parms_opt {
      Some(@pdf.PdfObject::Array(arr)) =>
        if index < arr.length() {
          Some(arr[index])
        } else {
          None
        }
      Some(@pdf.PdfObject::Null) => None
      Some(other) => if index == 0 { Some(other) } else { None }
      None => None
    }
  }

  fn decode_stage(
    bytes : @pdfio.MutableBytes,
    filter_name : String,
    parms : @pdf.PdfObject?,
  ) -> @pdfio.MutableBytes? {
    if filter_name != "/FlateDecode" && filter_name != "/Fl" {
      return None
    }
    let mut decoded = decode_flate(bytes) catch { _ => return None }
    match parms {
      Some(@pdf.PdfObject::Dictionary(_)) => {
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
  }

  match filter_opt {
    Some(@pdf.PdfObject::Name(name)) => decode_stage(data, name, parms_at(0))
    Some(@pdf.PdfObject::Array(filters)) => {
      if filters.length() == 0 {
        return None
      }
      let mut current = data
      for i = 0; i < filters.length(); i = i + 1 {
        let filter_name = match filters[i] {
          @pdf.PdfObject::Name(name) => name
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
        Some(@pdf.PdfObject::Integer(i)) => i
        Some(@pdf.PdfObject::Real(r)) => r.to_int()
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
  for line = 0; line < lines; line = line + 1 {
    let line_start = line * scanline_width
    let mut p = colors
    while p < scanline_width {
      let val = (
          out[line_start + p - colors].to_int() + out[line_start + p].to_int()
        ) %
        256
      out[line_start + p] = val.to_byte()
      p = p + 1
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
    for i = 0; i < scanline_width; i = i + 1 {
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
      for i = 0; i < output.length(); i = i + 1 {
        output[i] = (get0(current, i) + get0(output, i - bytes_per_pixel)) % 256
      }
    2 =>
      for i = 0; i < output.length(); i = i + 1 {
        output[i] = (get0(current, i) + get0(prior_decoded, i)) % 256
      }
    3 =>
      for i = 0; i < output.length(); i = i + 1 {
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
      for i = 0; i < output.length(); i = i + 1 {
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
