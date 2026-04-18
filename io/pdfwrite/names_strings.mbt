///|
fn is_delimiter_byte(b : Int) -> Bool {
  match b {
    b if b == '(' => true
    b if b == ')' => true
    b if b == '<' => true
    b if b == '>' => true
    b if b == '[' => true
    b if b == ']' => true
    b if b == '{' => true
    b if b == '}' => true
    b if b == '/' => true
    b if b == '%' => true
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
fn make_pdf_name(ctx : PdfWrite, name : String) -> String {
  let normalized = match name.get_char(0) {
    Some('/') => name
    _ => {
      (ctx.logger)("warning: bad name |\{name}|\n")
      "/" + name
    }
  }
  let mut needs_processing = false
  for i in 1..<normalized.length() {
    let b = normalized[i].to_int()
    if b < 33 || b > 126 || is_delimiter_byte(b) || b == '#' {
      needs_processing = true
      break
    }
  }
  if !needs_processing {
    return normalized
  }
  let bytes = @pdfio.bytes_of_string(normalized)
  let sb = StringBuilder::new()
  sb.write_char('/')
  for i in 1..<bytes.length() {
    let b = bytes[i].to_int()
    if b < 33 || b > 126 || is_delimiter_byte(b) || b == '#' {
      sb.write_char('#')
      sb.write_char(hex_digit(b / 16))
      sb.write_char(hex_digit(b % 16))
    } else {
      sb.write_char(b.to_byte().to_char())
    }
  }
  sb.to_string()
}

///|
fn make_pdf_string(value : String) -> String {
  let bytes = @pdfio.bytes_of_string(value)
  let sb = StringBuilder::new()
  sb.write_char('(')
  for byte in bytes {
    let b = byte.to_int()
    match b {
      0x28 | 0x29 | 0x5C => {
        sb.write_char('\\')
        sb.write_char(byte.to_char())
      }
      0x0A => sb.write_string("\\n")
      0x0D => sb.write_string("\\r")
      0x09 => sb.write_string("\\t")
      0x08 => sb.write_string("\\b")
      0x0C => sb.write_string("\\f")
      _ =>
        if b < 0x20 || b >= 0x7F {
          sb.write_char('\\')
          sb.write_char((((b >> 6) & 0x07) + 48).to_byte().to_char())
          sb.write_char((((b >> 3) & 0x07) + 48).to_byte().to_char())
          sb.write_char(((b & 0x07) + 48).to_byte().to_char())
        } else {
          sb.write_char(byte.to_char())
        }
    }
  }
  sb.write_char(')')
  sb.to_string()
}

///|
/// Convert a PDF string to hex representation.
fn make_hex_pdf_string(value : String) -> String {
  let bytes = @pdfio.bytes_of_string(value)
  let sb = StringBuilder::new()
  sb.write_char('<')
  for b in bytes {
    sb.write_string(b.to_hex())
  }
  sb.write_char('>')
  sb.to_string()
}
