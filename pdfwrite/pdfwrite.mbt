///|
/// Debug flag for PDF writing.
pub let write_debug : Ref[Bool] = { val: false }

///|
fn format_real(value : Double) -> String {
  let truncated = value.trunc()
  if truncated == value {
    truncated.to_int().to_string()
  } else {
    value.to_string()
  }
}

///|
fn make_pdf_name(name : String) -> String {
  match name.get_char(0) {
    Some('/') => name
    _ => "/\{name}"
  }
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
/// Write a PDF to an output (placeholder).
pub fn pdf_to_output(
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  _encryption : Encryption?,
  _build_new_id : Bool,
  _pdf : @pdf.Pdf,
  _output : @pdfio.Output,
) -> Unit raise {
  let _ = preserve_objstm
  let _ = generate_objstm
  let _ = compress_objstm
  let _ = recrypt
  raise @pdf.PdfError::Msg("pdf_to_output not implemented")
}

///|
/// Write a PDF to a channel (placeholder).
pub fn pdf_to_channel(
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  _encryption : Encryption?,
  _build_new_id : Bool,
  _pdf : @pdf.Pdf,
  _channel : Unit,
) -> Unit raise {
  let _ = preserve_objstm
  let _ = generate_objstm
  let _ = compress_objstm
  let _ = recrypt
  raise @pdf.PdfError::Msg("pdf_to_channel not implemented")
}

///|
/// Write a PDF to a file (placeholder).
pub fn pdf_to_file_options(
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  _encryption : Encryption?,
  _build_new_id : Bool,
  _pdf : @pdf.Pdf,
  _filename : String,
) -> Unit raise {
  let _ = preserve_objstm
  let _ = generate_objstm
  let _ = compress_objstm
  let _ = recrypt
  raise @pdf.PdfError::Msg("pdf_to_file_options not implemented")
}

///|
/// Simple write to file (placeholder).
pub fn pdf_to_file(_pdf : @pdf.Pdf, _filename : String) -> Unit raise {
  raise @pdf.PdfError::Msg("pdf_to_file not implemented")
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
