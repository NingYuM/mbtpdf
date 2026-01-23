///|
fn is_whitespace_byte(value : Int) -> Bool {
  value == 0 ||
  value == 9 ||
  value == 10 ||
  value == 12 ||
  value == 13 ||
  value == 32
}

///|
fn decode_jbig2dec_pbm(
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let mut pos = 0
  let mut remaining = 3
  while remaining > 0 {
    if pos >= data.length() {
      raise CodecError::CouldntDecodeStream("JBIG2")
    }
    if is_whitespace_byte(data[pos].to_int()) {
      remaining = remaining - 1
    }
    pos = pos + 1
  }
  let out = Array::new(capacity=data.length() - pos)
  for i = pos; i < data.length(); i = i + 1 {
    out.push((data[i].to_int() ^ 0xff).to_byte())
  }
  out
}

///|
fn jbig2_globals(
  pdf : @pdf.Pdf,
  parms : @pdf.PdfObject?,
) -> @pdfio.MutableBytes? {
  match parms {
    Some(obj) =>
      match @pdf.lookup_direct(pdf, "/JBIG2Globals", obj) {
        Some(stream_obj) => {
          let direct = @pdf.direct(pdf, stream_obj)
          let _ = @pdf.getstream(direct) catch { _ => return None }
          match direct {
            @pdf.PdfObject::Stream(r) =>
              match r.val {
                (_, @pdf.Stream::Got(bytes)) => Some(bytes)
                _ => None
              }
            _ => None
          }
        }
        None => None
      }
    None => None
  }
}

///|
async fn decode_jbig2(
  globals : @pdfio.MutableBytes?,
  jbig2dec : String,
  input : @pdfio.Input,
) -> @pdfio.MutableBytes raise CodecError {
  let dir = match @env.current_dir() {
    Some(path) => path
    None => "."
  }
  let stamp = @env.now().to_string()
  let input_path = "\{dir}/mbtpdf_jbig2_\{stamp}.jb2"
  let globals_path = match globals {
    Some(_) => "\{dir}/mbtpdf_jbig2_globals_\{stamp}.jb2"
    None => ""
  }
  let output_path = "\{dir}/mbtpdf_jbig2_\{stamp}.pbm"
  let decoded = try {
    let input_bytes = @pdfio.bytes_of_input(input, 0, input.in_channel_length)
    run_async_mapped("write jbig2 input", () => @fs.write_file(
      input_path,
      Bytes::from_array(input_bytes),
    ))
    match globals {
      Some(bytes) =>
        run_async_mapped("write jbig2 globals", () => @fs.write_file(
          globals_path,
          Bytes::from_array(bytes),
        ))
      None => ()
    }
    let args : Array[String] = Array::new()
    args.push("-e")
    if globals_path != "" {
      args.push(globals_path)
    }
    args.push(input_path)
    args.push("-o")
    args.push(output_path)
    let exit_code = run_async_mapped("run jbig2dec", () => @process.run(
      jbig2dec, args,
    ))
    if exit_code > 0 {
      raise CodecError::DecodeNotSupported("jbig2dec return code non-zero")
    }
    let output_bytes = run_async_mapped("read jbig2 output", () => {
      let data = @fs.read_file(output_path)
      data.binary().to_array()
    })
    decode_jbig2dec_pbm(output_bytes)
  } catch {
    CodecError::CouldntDecodeStream(msg) => {
      let _ : Result[Unit, Error] = try? @fs.remove(input_path)
      if globals_path != "" {
        let _ : Result[Unit, Error] = try? @fs.remove(globals_path)

      }
      let _ : Result[Unit, Error] = try? @fs.remove(output_path)
      raise CodecError::CouldntDecodeStream(msg)
    }
    CodecError::DecodeNotSupported(msg) => {
      let _ : Result[Unit, Error] = try? @fs.remove(input_path)
      if globals_path != "" {
        let _ : Result[Unit, Error] = try? @fs.remove(globals_path)

      }
      let _ : Result[Unit, Error] = try? @fs.remove(output_path)
      raise CodecError::DecodeNotSupported(msg)
    }
    _ => {
      let _ : Result[Unit, Error] = try? @fs.remove(input_path)
      if globals_path != "" {
        let _ : Result[Unit, Error] = try? @fs.remove(globals_path)

      }
      let _ : Result[Unit, Error] = try? @fs.remove(output_path)
      raise CodecError::CouldntDecodeStream("decode_jbig2 failed")
    }
  }
  let _ : Result[Unit, Error] = try? @fs.remove(input_path)
  if globals_path != "" {
    let _ : Result[Unit, Error] = try? @fs.remove(globals_path)

  }
  let _ : Result[Unit, Error] = try? @fs.remove(output_path)
  decoded
}
