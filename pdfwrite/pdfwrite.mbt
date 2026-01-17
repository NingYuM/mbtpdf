///|
/// Debug flag for PDF writing.
pub let write_debug : Ref[Bool] = { val: false }

///|
fn trim_trailing_zeros(value : String) -> String {
  let dot = value.find(".")
  match dot {
    None => value
    Some(_) => {
      let chars = value.to_array()
      let mut end = chars.length() - 1
      while end >= 0 && chars[end] == '0' {
        end = end - 1
      }
      if end >= 0 && chars[end] == '.' {
        end = end - 1
      }
      if end < 0 {
        "0"
      } else {
        let sb = StringBuilder::new()
        let mut i = 0
        while i <= end {
          sb.write_char(chars[i])
          i = i + 1
        }
        sb.to_string()
      }
    }
  }
}

///|
fn slice_from(value : String, start : Int) -> String {
  try value[start:] catch {
    _ => ""
  } noraise {
    view => view.to_string()
  }
}

///|
fn slice_range(value : String, start : Int, end : Int) -> String {
  try value[start:end] catch {
    _ => ""
  } noraise {
    view => view.to_string()
  }
}

///|
fn parse_signed_int(value : String) -> Int {
  let chars = value.to_array()
  if chars.length() == 0 {
    return 0
  }
  let mut sign = 1
  let mut i = 0
  match chars[0] {
    '-' => {
      sign = -1
      i = 1
    }
    '+' => i = 1
    _ => ()
  }
  let mut result = 0
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      break
    }
    result = result * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  sign * result
}

///|
fn expand_scientific(value : String) -> String {
  let (sign, body) = match value.get_char(0) {
    Some('-') => ("-", slice_from(value, 1))
    _ => ("", value)
  }
  let exp_index = match body.find("e") {
    Some(i) => Some(i)
    None => body.find("E")
  }
  match exp_index {
    None => sign + trim_trailing_zeros(body)
    Some(idx) => {
      let mantissa = slice_range(body, 0, idx)
      let exp_str = slice_from(body, idx + 1)
      let exp = parse_signed_int(exp_str)
      let digits = Array::new()
      let mut int_len = 0
      let mut saw_dot = false
      for ch in mantissa {
        if ch == '.' {
          saw_dot = true
        } else {
          if !saw_dot {
            int_len = int_len + 1
          }
          digits.push(ch)
        }
      }
      if digits.length() == 0 {
        sign + "0"
      } else {
        let new_pos = int_len + exp
        let sb = StringBuilder::new()
        sb.write_string(sign)
        if new_pos <= 0 {
          sb.write_string("0.")
          let mut z = 0
          while z < -new_pos {
            sb.write_char('0')
            z = z + 1
          }
          for ch in digits {
            sb.write_char(ch)
          }
        } else if new_pos >= digits.length() {
          for ch in digits {
            sb.write_char(ch)
          }
          let mut z = 0
          while z < new_pos - digits.length() {
            sb.write_char('0')
            z = z + 1
          }
        } else {
          let mut i = 0
          while i < digits.length() {
            if i == new_pos {
              sb.write_char('.')
            }
            sb.write_char(digits[i])
            i = i + 1
          }
        }
        trim_trailing_zeros(sb.to_string())
      }
    }
  }
}

///|
fn format_real(value : Double) -> String {
  let raw = value.to_string()
  if raw.contains("e") || raw.contains("E") {
    expand_scientific(raw)
  } else {
    trim_trailing_zeros(raw)
  }
}

///|
fn is_delimiter_byte(b : Int) -> Bool {
  match b {
    b if b == '('.to_int() => true
    b if b == ')'.to_int() => true
    b if b == '<'.to_int() => true
    b if b == '>'.to_int() => true
    b if b == '['.to_int() => true
    b if b == ']'.to_int() => true
    b if b == '{'.to_int() => true
    b if b == '}'.to_int() => true
    b if b == '/'.to_int() => true
    b if b == '%'.to_int() => true
    _ => false
  }
}

///|
fn hex_digit(value : Int) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'A'
    11 => 'B'
    12 => 'C'
    13 => 'D'
    14 => 'E'
    15 => 'F'
    _ => '0'
  }
}

///|
fn needs_processing_name(bytes : @pdfio.MutableBytes) -> Bool {
  if bytes.length() < 2 {
    return false
  }
  let mut i = 1
  while i < bytes.length() {
    let b = bytes[i].to_int()
    if b < 33 || b > 126 || is_delimiter_byte(b) || b == '#'.to_int() {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn make_pdf_name(name : String) -> String {
  let normalized = match name.get_char(0) {
    Some('/') => name
    _ => {
      @pdfe.log("warning: bad name |\{name}|\n")
      "/"
    }
  }
  let bytes = @pdfio.bytes_of_string(normalized)
  if !needs_processing_name(bytes) {
    return normalized
  }
  let sb = StringBuilder::new()
  sb.write_char('/')
  let mut i = 1
  while i < bytes.length() {
    let b = bytes[i].to_int()
    if b < 33 || b > 126 || is_delimiter_byte(b) || b == '#'.to_int() {
      sb.write_char('#')
      sb.write_char(hex_digit(b / 16))
      sb.write_char(hex_digit(b % 16))
    } else {
      sb.write_char(b.to_byte().to_char())
    }
    i = i + 1
  }
  sb.to_string()
}

///|
fn make_pdf_string(value : String) -> String {
  let sb = StringBuilder::new()
  sb.write_char('(')
  for ch in value {
    match ch {
      '(' | ')' | '\\' => {
        sb.write_char('\\')
        sb.write_char(ch)
      }
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      '\b' => sb.write_string("\\b")
      '\f' => sb.write_string("\\f")
      _ => sb.write_char(ch)
    }
  }
  sb.write_char(')')
  sb.to_string()
}

///|
fn pad_int(value : Int, width : Int) -> String {
  let s = value.to_string()
  if s.length() >= width {
    s
  } else {
    "0".repeat(width - s.length()) + s
  }
}

///|
fn write_header(pdf : @pdf.Pdf, output : @pdfio.Output) -> Unit {
  (output.output_string)("%PDF-\{pdf.major}.\{pdf.minor}\n%")
  let bytes = [128, 129, 130, 131]
  for b in bytes {
    (output.output_byte)(b)
  }
  (output.output_char)('\n')
}

///|
fn write_pdf_object_to_output(
  obj : @pdf.PdfObject,
  output : @pdfio.Output,
  include_stream_data : Bool,
  hex_strings : Bool,
) -> Unit raise {
  fn write_str(s : String) -> Unit {
    (output.output_string)(s)
  }

  match obj {
    @pdf.PdfObject::Null => write_str("null")
    @pdf.PdfObject::Boolean(b) => write_str(if b { "true" } else { "false" })
    @pdf.PdfObject::Integer(i) => write_str(i.to_string())
    @pdf.PdfObject::Real(r) => write_str(format_real(r))
    @pdf.PdfObject::String(s) =>
      write_str(
        if hex_strings {
          make_hex_pdf_string(s)
        } else {
          make_pdf_string(s)
        },
      )
    @pdf.PdfObject::Name(n) => write_str(make_pdf_name(n))
    @pdf.PdfObject::Array(values) => {
      write_str("[")
      for i = 0; i < values.length(); i = i + 1 {
        if i > 0 {
          write_str(" ")
        }
        write_pdf_object_to_output(
          values[i],
          output,
          include_stream_data,
          hex_strings,
        )
      }
      write_str("]")
    }
    @pdf.PdfObject::Dictionary(entries) => {
      write_str("<<")
      for i = 0; i < entries.length(); i = i + 1 {
        let (key, value) = entries[i]
        if i > 0 {
          write_str(" ")
        }
        write_str(make_pdf_name(key))
        write_str(" ")
        let value_hex = hex_strings && key == "/ID"
        write_pdf_object_to_output(
          value, output, include_stream_data, value_hex,
        )
      }
      write_str(">>")
    }
    @pdf.PdfObject::Stream(r) => {
      if include_stream_data {
        let _ = @pdf.getstream(obj) catch { _ => () }

      }
      let (dict, stream_data) = r.val
      write_pdf_object_to_output(dict, output, include_stream_data, hex_strings)
      write_str("\nstream\n")
      if include_stream_data {
        match stream_data {
          @pdf.Stream::Got(bytes) =>
            @pdfio.getinit(output, bytes, 0, @pdfio.bytes_size(bytes))
          _ => ()
        }
      }
      write_str("\nendstream")
    }
    @pdf.PdfObject::Indirect(n) => write_str("\{n} 0 R")
  }
}

///|
fn write_pdf_object(
  obj : @pdf.PdfObject,
  include_stream_data : Bool,
  sb : StringBuilder,
) -> Unit {
  match obj {
    @pdf.PdfObject::Null => sb.write_string("null")
    @pdf.PdfObject::Boolean(b) =>
      sb.write_string(if b { "true" } else { "false" })
    @pdf.PdfObject::Integer(i) => sb.write_string(i.to_string())
    @pdf.PdfObject::Real(r) => sb.write_string(format_real(r))
    @pdf.PdfObject::String(s) => sb.write_string(make_pdf_string(s))
    @pdf.PdfObject::Name(n) => sb.write_string(make_pdf_name(n))
    @pdf.PdfObject::Array(values) => {
      sb.write_char('[')
      for i = 0; i < values.length(); i = i + 1 {
        if i > 0 {
          sb.write_char(' ')
        }
        write_pdf_object(values[i], include_stream_data, sb)
      }
      sb.write_char(']')
    }
    @pdf.PdfObject::Dictionary(entries) => {
      sb.write_string("<<")
      for i = 0; i < entries.length(); i = i + 1 {
        let (key, value) = entries[i]
        if i > 0 {
          sb.write_char(' ')
        }
        sb.write_string(make_pdf_name(key))
        sb.write_char(' ')
        write_pdf_object(value, include_stream_data, sb)
      }
      sb.write_string(">>")
    }
    @pdf.PdfObject::Stream(r) => {
      let (dict, _) = r.val
      write_pdf_object(dict, include_stream_data, sb)
      sb.write_string("\nstream\n")
      if include_stream_data {
        let _ = @pdf.getstream(obj) catch { _ => () }
        match r.val {
          (_, @pdf.Stream::Got(bytes)) =>
            sb.write_string(@pdfio.string_of_bytes(bytes))
          _ => ()
        }
      }
      sb.write_string("\nendstream")
    }
    @pdf.PdfObject::Indirect(n) => sb.write_string("\{n} 0 R")
  }
}

///|
/// Encryption methods.
pub enum EncryptionMethod {
  PDF40bit
  PDF128bit
  AES128bit(Bool)
  AES256bit(Bool)
  AES256bitISO(Bool)
  AlreadyEncrypted
}

///|
/// Encryption settings (placeholder).
pub struct Encryption {
  encryption_method : EncryptionMethod
  owner_password : String
  user_password : String
  permissions : Array[String]
}

///|
/// Write a PDF to an output.
pub fn pdf_to_output(
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  _encryption : Encryption?,
  _build_new_id : Bool,
  pdf : @pdf.Pdf,
  output : @pdfio.Output,
) -> Unit raise {
  let _ = preserve_objstm
  let _ = generate_objstm
  let _ = compress_objstm
  let _ = recrypt
  write_header(pdf, output)
  let entries = @pdf.pdfobjmap_bindings(pdf.objects.objects)
  let objnums = entries.map(pair => pair.0)
  objnums.sort_by((a, b) => a - b)
  let max_obj = pdf.objects.max_obj_num
  let size = max_obj + 1
  let offsets = Array::make(size, 0)
  let gens = Array::make(size, 0)
  let used = Array::make(size, false)
  for objnum in objnums {
    if objnum == 0 {
      continue
    }
    match pdf.objects.objects.get(objnum) {
      None => ()
      Some((_obj_ref, gen)) => {
        let offset = (output.pos_out)()
        offsets[objnum] = offset
        gens[objnum] = gen
        used[objnum] = true
        (output.output_string)("\{objnum} \{gen} obj\n")
        let obj = @pdf.lookup_obj(pdf, objnum)
        write_pdf_object_to_output(obj, output, true, false)
        (output.output_string)("\nendobj\n")
      }
    }
  }
  let xref_start = (output.pos_out)()
  (output.output_string)("xref\n")
  (output.output_string)("0 \{size}\n")
  let mut i = 0
  while i < size {
    if i == 0 || !used[i] {
      (output.output_string)("0000000000 65535 f \n")
    } else {
      let line = "\{pad_int(offsets[i], 10)} \{pad_int(gens[i], 5)} n \n"
      (output.output_string)(line)
    }
    i = i + 1
  }
  (output.output_string)("trailer\n")
  let trailerdict = @pdf.add_dict_entry(
    @pdf.add_dict_entry(pdf.trailerdict, "/Size", @pdf.PdfObject::Integer(size)),
    "/Root",
    @pdf.PdfObject::Indirect(pdf.root),
  )
  write_pdf_object_to_output(trailerdict, output, false, true)
  (output.output_string)("\nstartxref\n")
  (output.output_string)("\{xref_start}\n%%EOF\n")
}

///|
/// Write a PDF to a channel.
pub fn pdf_to_channel(
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  _encryption : Encryption?,
  _build_new_id : Bool,
  pdf : @pdf.Pdf,
  channel : @fs.File,
) -> Unit raise {
  let output = @pdfio.output_of_channel(channel)
  match recrypt {
    Some(value) =>
      pdf_to_output(
        preserve_objstm~,
        generate_objstm~,
        compress_objstm~,
        recrypt=value,
        _encryption,
        _build_new_id,
        pdf,
        output,
      )
    None =>
      pdf_to_output(
        preserve_objstm~,
        generate_objstm~,
        compress_objstm~,
        _encryption,
        _build_new_id,
        pdf,
        output,
      )
  }
}

///|
/// Write a PDF to a file.
pub fn pdf_to_file_options(
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  _encryption : Encryption?,
  _build_new_id : Bool,
  pdf : @pdf.Pdf,
  filename : String,
) -> Unit raise {
  let result : Ref[Result[@fs.File, Error]] = Ref::new(
    Err(Failure::Failure("uninitialized open")),
  )
  @async.run_async_main(() => {
    let res : Result[@fs.File, Error] = try? @fs.open(
      filename,
      mode=WriteOnly,
      create=0o644,
      truncate=true,
    )
    result.val = res
  })
  let file = match result.val {
    Ok(f) => f
    Err(err) => raise err
  }
  try {
    match recrypt {
      Some(value) =>
        pdf_to_channel(
          preserve_objstm~,
          generate_objstm~,
          compress_objstm~,
          recrypt=value,
          _encryption,
          _build_new_id,
          pdf,
          file,
        )
      None =>
        pdf_to_channel(
          preserve_objstm~,
          generate_objstm~,
          compress_objstm~,
          _encryption,
          _build_new_id,
          pdf,
          file,
        )
    }
    file.close()
  } catch {
    err => {
      file.close()
      raise err
    }
  }
}

///|
/// Simple write to file.
pub fn pdf_to_file(pdf : @pdf.Pdf, filename : String) -> Unit raise {
  pdf_to_file_options(
    preserve_objstm=true,
    generate_objstm=false,
    compress_objstm=true,
    None,
    true,
    pdf,
    filename,
  )
}

///|
/// String of a PDF object.
pub fn string_of_pdf(obj : @pdf.PdfObject) -> String {
  let sb = StringBuilder::new()
  write_pdf_object(obj, false, sb)
  sb.to_string()
}

///|
/// String of a PDF object including stream data.
pub fn string_of_pdf_including_data(obj : @pdf.PdfObject) -> String {
  let sb = StringBuilder::new()
  write_pdf_object(obj, true, sb)
  sb.to_string()
}

///|
/// Debug print of a whole PDF.
pub fn debug_whole_pdf(pdf : @pdf.Pdf) -> Unit {
  println("trailerdict = \{string_of_pdf(pdf.trailerdict)}")
  for pair in @pdf.pdfobjmap_bindings(pdf.objects.objects) {
    let (objnum, entry) = pair
    let (obj_ref, _gen) = entry
    match obj_ref.val {
      @pdf.ObjectData::Parsed(obj)
      | @pdf.ObjectData::ParsedAlreadyDecrypted(obj) =>
        println("\{objnum} = \{string_of_pdf(obj)}")
      _ => ()
    }
  }
}

///|
/// Convert a PDF string to hex representation.
pub fn make_hex_pdf_string(value : String) -> String {
  let bytes = @pdfio.bytes_of_string(value)
  let sb = StringBuilder::new()
  sb.write_char('<')
  for b in bytes {
    sb.write_string(b.to_hex())
  }
  sb.write_char('>')
  sb.to_string()
}

///|
fn init {
  @pdfcodec.string_of_pdf.val = string_of_pdf
}
