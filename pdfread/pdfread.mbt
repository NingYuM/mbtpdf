///|
/// Debug flag for PDF reading.
pub let read_debug : Ref[Bool] = { val: false }

///|
/// If true, do not attempt malformed PDF recovery.
pub let error_on_malformed : Ref[Bool] = { val: false }

///|
/// If true, always treat PDFs as malformed.
pub let debug_always_treat_malformed : Ref[Bool] = { val: false }

///|
/// Read a PDF from an input (placeholder).
pub fn pdf_of_input(
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  input : @pdfio.Input,
) -> @pdf.Pdf raise {
  let _ = revision
  let _ = user_password
  let _ = owner_password
  let _ = input
  raise @pdf.PdfError::Msg("pdf_of_input not implemented")
}

///|
/// Read a PDF from an input, lazily (placeholder).
pub fn pdf_of_input_lazy(
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  input : @pdfio.Input,
) -> @pdf.Pdf raise {
  let _ = revision
  let _ = user_password
  let _ = owner_password
  let _ = input
  raise @pdf.PdfError::Msg("pdf_of_input_lazy not implemented")
}

///|
/// Read a PDF from a channel (placeholder).
pub fn pdf_of_channel(
  revision? : Int,
  source? : String = "channel",
  user_password : String?,
  owner_password : String?,
  _channel : Unit,
) -> @pdf.Pdf raise {
  let _ = revision
  let _ = source
  let _ = user_password
  let _ = owner_password
  raise @pdf.PdfError::Msg("pdf_of_channel not implemented")
}

///|
/// Read a PDF from a channel lazily (placeholder).
pub fn pdf_of_channel_lazy(
  revision? : Int,
  source? : String = "channel",
  user_password : String?,
  owner_password : String?,
  _channel : Unit,
) -> @pdf.Pdf raise {
  let _ = revision
  let _ = source
  let _ = user_password
  let _ = owner_password
  raise @pdf.PdfError::Msg("pdf_of_channel_lazy not implemented")
}

///|
/// Read a PDF from a file (placeholder).
pub fn pdf_of_file(
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  filename : String,
) -> @pdf.Pdf raise {
  let _ = revision
  let _ = user_password
  let _ = owner_password
  let _ = filename
  raise @pdf.PdfError::Msg("pdf_of_file not implemented")
}

///|
/// Return number of revisions (placeholder).
pub fn revisions(_input : @pdfio.Input) -> Int {
  0
}

///|
/// Return encryption method in use (placeholder).
pub fn what_encryption(_pdf : @pdf.Pdf) -> Unit? {
  None
}

///|
/// Return list of permissions (placeholder).
pub fn permissions(_pdf : @pdf.Pdf) -> Array[Unit] {
  []
}

///|
/// Check if input is linearized.
pub fn is_linearized(input : @pdfio.Input) -> Bool {
  try {
    let _ = read_header(input)
    let lexemes = lex_dictionary(false, input)
    let (_, parsed) = parse(lexemes, failure_is_ok=true)
    match @pdf.lookup_direct(@pdf.empty(), "/Linearized", parsed) {
      Some(@pdf.PdfObject::Integer(_)) | Some(@pdf.PdfObject::Real(_)) => true
      _ => false
    }
  } catch {
    _ => false
  }
}

///|
/// Read a PDF header.
pub fn read_header(input : @pdfio.Input) -> (Int, Int) raise {
  fn get8chars(input : @pdfio.Input) -> Array[Char] {
    let out = Array::new(capacity=8)
    let mut ok = true
    let mut i = 0
    while ok && i < 8 {
      match (input.input_char)() {
        Some(ch) => out.push(ch)
        None => ok = false
      }
      i = i + 1
    }
    if ok {
      out
    } else {
      Array::new()
    }
  }

  fn digits_to_int(digits : Array[Char]) -> Int {
    let mut value = 0
    for d in digits {
      value = value * 10 + (d.to_int() - '0'.to_int())
    }
    value
  }

  let mut pos = 0
  while pos <= 1024 {
    (input.seek_in)(pos)
    let chars = get8chars(input)
    if chars.length() == 8 &&
      chars[0] == '%' &&
      chars[1] == 'P' &&
      chars[2] == 'D' &&
      chars[3] == 'F' &&
      chars[4] == '-' &&
      chars[6] == '.' {
      let major_char = chars[5]
      if major_char < '0' || major_char > '9' {
        return (2, 0)
      }
      let minor_digits = Array::new()
      let mut idx = 7
      while idx < chars.length() {
        let c = chars[idx]
        if c >= '0' && c <= '9' {
          minor_digits.push(c)
          idx = idx + 1
        } else {
          idx = chars.length()
        }
      }
      if minor_digits.length() == 0 {
        let message = @pdf.input_pdferror(input, "Malformed PDF header")
        raise @pdf.PdfError::Msg(message)
      }
      if read_debug.val {
        @pdfe.log("setting offset to \{pos}\n")
      }
      (input.set_offset)(pos)
      return (major_char.to_int() - '0'.to_int(), digits_to_int(minor_digits))
    }
    pos = pos + 1
  }
  (2, 0)
}

///|
/// PDF whitespace predicate.
fn is_whitespace(c : Char) -> Bool {
  let v = c.to_int()
  v == 0 || v == 9 || v == 10 || v == 12 || v == 13 || v == 32
}

///|
fn is_not_whitespace(c : Char) -> Bool {
  !is_whitespace(c)
}

///|
fn is_newline(c : Char) -> Bool {
  c == '\n' || c == '\r'
}

///|
fn is_delimiter(c : Char) -> Bool {
  match c {
    '(' | ')' | '<' | '>' | '[' | ']' | '{' | '}' | '%' | '/' => true
    _ => false
  }
}

///|
fn is_whitespace_or_delimiter(c : Char) -> Bool {
  is_whitespace(c) || is_delimiter(c)
}

///|
/// Read chars until whitespace or delimiter.
pub fn getuntil_white_or_delimiter(input : @pdfio.Input) -> Array[Char] raise {
  getuntil(true, is_whitespace_or_delimiter, input)
}

///|
/// Read chars until whitespace or delimiter.
pub fn getuntil_white_or_delimiter_string(input : @pdfio.Input) -> String raise {
  getuntil_string(true, is_whitespace_or_delimiter, input)
}

///|
/// Read chars until predicate is true.
pub fn getuntil(
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
  input : @pdfio.Input,
) -> Array[Char] raise {
  let out = Array::new()
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        @pdfio.rewind(input)
        done = true
      } else {
        out.push(c)
      }
    }
  }
  out
}

///|
fn getuntil_string(
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
  input : @pdfio.Input,
) -> String raise {
  let sb = StringBuilder::new()
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        @pdfio.rewind(input)
        done = true
      } else {
        sb.write_char(c)
      }
    }
  }
  sb.to_string()
}

///|
/// Ignore chars until predicate is true.
pub fn ignoreuntil(
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
  input : @pdfio.Input,
) -> Unit raise {
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        @pdfio.rewind(input)
        done = true
      }
    }
  }
}

///|
/// Drop whitespace.
pub fn dropwhite(input : @pdfio.Input) -> Unit raise {
  ignoreuntil(true, is_not_whitespace, input)
}

///|
/// Lex a name.
pub fn lex_name(input : @pdfio.Input) -> @pdfgenlex.Token {
  let bytes : @pdfio.MutableBytes = Array::new()
  let _ = (input.input_byte)()
  bytes.push('/'.to_int().to_byte())
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else {
      let c = b.to_byte().to_char()
      if is_whitespace_or_delimiter(c) {
        @pdfio.rewind(input)
        done = true
      } else if c == '#' {
        let h1 = (input.input_byte)()
        let h2 = (input.input_byte)()
        if h1 != @pdfio.no_more && h2 != @pdfio.no_more {
          let hex = String::from_array([
            h1.to_byte().to_char(),
            h2.to_byte().to_char(),
          ])
          match (try? @strconv.parse_int("0x\{hex}")) {
            Ok(v) => bytes.push(v.to_byte())
            Err(_) => {
              bytes.push('#'.to_int().to_byte())
              bytes.push(h1.to_byte())
              bytes.push(h2.to_byte())
            }
          }
        }
      } else {
        bytes.push(b.to_byte())
      }
    }
  }
  @pdfgenlex.Token::LexName(@pdfio.string_of_bytes(bytes))
}

///|
/// Lex a number.
pub fn lex_number(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  let s = getuntil_white_or_delimiter_string(input)
  let mut number = s
  if number.length() > 1 {
    match (number.get_char(0), number.get_char(1)) {
      (Some('-'), Some('-')) =>
        number = match (try? number[1:]) {
          Ok(view) => view.to_string()
          Err(_) => number
        }
      _ => ()
    }
  }
  let has_decimal = number.contains(".") ||
    number.contains("e") ||
    number.contains("E")
  if !has_decimal {
    match (try? @strconv.parse_int(number)) {
      Ok(i) => @pdfgenlex.Token::LexInt(i)
      Err(_) =>
        match (try? @strconv.parse_double(number)) {
          Ok(f) => @pdfgenlex.Token::LexReal(f)
          Err(_) => @pdfgenlex.Token::LexNone
        }
    }
  } else {
    match (try? @strconv.parse_double(number)) {
      Ok(f) => @pdfgenlex.Token::LexReal(f)
      Err(_) => @pdfgenlex.Token::LexNone
    }
  }
}

///|
/// Lex a string.
pub fn lex_string(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  let bytes : @pdfio.MutableBytes = Array::new()
  let mut paren = 1
  let first = (input.input_byte)()
  if first != '('.to_int() {
    raise @pdf.PdfError::Msg("lex_string: expected '('")
  }
  while paren > 0 {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      raise @pdf.PdfError::Msg("lex_string: unexpected EOF")
    }
    let c = b.to_byte().to_char()
    match c {
      '(' => {
        paren = paren + 1
        bytes.push(b.to_byte())
      }
      ')' => {
        paren = paren - 1
        if paren > 0 {
          bytes.push(b.to_byte())
        }
      }
      '\\' => {
        let esc = (input.input_byte)()
        if esc == @pdfio.no_more {
          raise @pdf.PdfError::Msg("lex_string: unexpected EOF")
        }
        match esc.to_byte().to_char() {
          'n' => bytes.push('\n'.to_int().to_byte())
          'r' => bytes.push('\r'.to_int().to_byte())
          't' => bytes.push('\t'.to_int().to_byte())
          'b' => bytes.push('\b'.to_int().to_byte())
          'f' => bytes.push('\f'.to_int().to_byte())
          '\r' => {
            let next = (input.input_byte)()
            if next != '\n'.to_int() {
              @pdfio.rewind(input)
            }
          }
          '\n' => ()
          digit if digit >= '0' && digit <= '7' => {
            let digits : Array[Char] = Array::new()
            digits.push(digit)
            let b2 = (input.input_byte)()
            if b2 != @pdfio.no_more {
              let c2 = b2.to_byte().to_char()
              if c2 >= '0' && c2 <= '7' {
                digits.push(c2)
                let b3 = (input.input_byte)()
                if b3 != @pdfio.no_more {
                  let c3 = b3.to_byte().to_char()
                  if c3 >= '0' && c3 <= '7' {
                    digits.push(c3)
                  } else {
                    @pdfio.rewind(input)
                  }
                }
              } else {
                @pdfio.rewind(input)
              }
            }
            let octal = digits.map(c => c.to_string()).join("")
            match (try? @strconv.parse_int("0o\{octal}")) {
              Ok(v) => bytes.push(v.to_byte())
              Err(_) => ()
            }
          }
          other => bytes.push(other.to_int().to_byte())
        }
      }
      _ => bytes.push(b.to_byte())
    }
  }
  @pdfgenlex.Token::LexString(@pdfio.string_of_bytes(bytes))
}

///|
/// Lex a hex string.
pub fn lex_hexstring(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  let digits = Array::new()
  let _ = (input.input_byte)()
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else {
      let c = b.to_byte().to_char()
      if c == '>' {
        done = true
      } else if is_whitespace(c) {
        ()
      } else {
        let hex = c.to_string()
        match (try? @strconv.parse_int("0x\{hex}")) {
          Ok(v) => digits.push(v)
          Err(_) => ()
        }
      }
    }
  }
  if digits.length() % 2 == 1 {
    digits.push(0)
  }
  let bytes : @pdfio.MutableBytes = Array::new()
  for i = 0; i < digits.length(); i = i + 2 {
    let hi = digits[i]
    let lo = digits[i + 1]
    bytes.push(((hi << 4) + lo).to_byte())
  }
  @pdfgenlex.Token::LexString(@pdfio.string_of_bytes(bytes))
}

///|
/// Lex a comment.
pub fn lex_comment(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  ignoreuntil(false, is_newline, input)
  @pdfgenlex.Token::LexComment("")
}

///|
fn lex_keyword(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  let kw = getuntil_white_or_delimiter_string(input)
  match kw {
    "obj" => @pdfgenlex.Token::LexObj
    "endobj" => @pdfgenlex.Token::LexEndObj
    "R" => @pdfgenlex.Token::LexR
    "null" => @pdfgenlex.Token::LexNull
    "endstream" => @pdfgenlex.Token::LexEndStream
    "true" => @pdfgenlex.Token::LexBool(true)
    "false" => @pdfgenlex.Token::LexBool(false)
    _ => @pdfgenlex.Token::LexNone
  }
}

///|
fn lex_next(
  read_stream_data : Bool,
  input : @pdfio.Input,
) -> @pdfgenlex.Token raise {
  let _ = read_stream_data
  dropwhite(input)
  match @pdfio.peek_byte(input) {
    b if b == @pdfio.no_more => @pdfgenlex.Token::StopLexing
    b if b == '%'.to_int() => lex_comment(input)
    b if b == '/'.to_int() => lex_name(input)
    b if b == '('.to_int() => lex_string(input)
    b if b == '['.to_int() => {
      @pdfio.nudge(input)
      @pdfgenlex.Token::LexLeftSquare
    }
    b if b == ']'.to_int() => {
      @pdfio.nudge(input)
      @pdfgenlex.Token::LexRightSquare
    }
    b if b == '<'.to_int() => {
      @pdfio.nudge(input)
      match @pdfio.peek_byte(input) {
        b2 if b2 == '<'.to_int() => {
          @pdfio.nudge(input)
          @pdfgenlex.Token::LexLeftDict
        }
        _ => {
          @pdfio.rewind(input)
          lex_hexstring(input)
        }
      }
    }
    b if b == '>'.to_int() => {
      @pdfio.nudge(input)
      match @pdfio.peek_byte(input) {
        b2 if b2 == '>'.to_int() => {
          @pdfio.nudge(input)
          @pdfgenlex.Token::LexRightDict
        }
        _ => @pdfgenlex.Token::LexNone
      }
    }
    b if (b >= '0'.to_int() && b <= '9'.to_int()) ||
      b == '-'.to_int() ||
      b == '+'.to_int() ||
      b == '.'.to_int() => lex_number(input)
    _ => lex_keyword(input)
  }
}

///|
/// Lex a dictionary.
pub fn lex_dictionary(
  read_stream_data : Bool,
  input : @pdfio.Input,
) -> Array[@pdfgenlex.Token] raise {
  let tokens = Array::new()
  let mut done = false
  while !done {
    let t = lex_next(read_stream_data, input)
    tokens.push(t)
    match t {
      @pdfgenlex.Token::LexRightDict | @pdfgenlex.Token::StopLexing =>
        done = true
      _ => ()
    }
  }
  tokens
}

///|
/// Lex stream data.
pub fn lex_stream_data(
  input : @pdfio.Input,
  length : Int,
  read_data : Bool,
) -> @pdfgenlex.Token raise {
  let pos = (input.pos_in)()
  let bytes = if read_data {
    @pdfio.bytes_of_input(input, pos, length)
  } else {
    @pdfio.mkbytes(0)
  }
  (input.seek_in)(pos + length)
  @pdfgenlex.Token::LexStream(@pdf.Stream::Got(bytes))
}

///|
priv enum ParseItem {
  Parsed(@pdf.PdfObject)
  Lexeme(@pdfgenlex.Token)
}

///|
fn parse_R(tokens : Array[@pdfgenlex.Token]) -> Array[ParseItem] {
  let out = Array::new()
  let mut i = 0
  while i < tokens.length() {
    if i + 2 < tokens.length() {
      match (tokens[i], tokens[i + 1], tokens[i + 2]) {
        (
          @pdfgenlex.Token::LexInt(o),
          @pdfgenlex.Token::LexInt(_),
          @pdfgenlex.Token::LexR,
        ) => {
          out.push(ParseItem::Parsed(@pdf.PdfObject::Indirect(o)))
          i = i + 3
          continue
        }
        _ => ()
      }
    }
    match tokens[i] {
      @pdfgenlex.Token::LexComment(_) => ()
      @pdfgenlex.Token::LexNull =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Null))
      @pdfgenlex.Token::LexBool(b) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Boolean(b)))
      @pdfgenlex.Token::LexInt(v) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Integer(v)))
      @pdfgenlex.Token::LexReal(v) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Real(v)))
      @pdfgenlex.Token::LexString(s) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::String(s)))
      @pdfgenlex.Token::LexName(n) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Name(n)))
      other => out.push(ParseItem::Lexeme(other))
    }
    i = i + 1
  }
  out
}

///|
fn parse_dictionary(
  items : Array[ParseItem],
  start : Int,
) -> (ParseItem, Int) raise {
  let entries = Array::new()
  let mut i = start + 1
  while i < items.length() {
    match items[i] {
      ParseItem::Lexeme(@pdfgenlex.Token::LexRightDict) =>
        return (ParseItem::Parsed(@pdf.PdfObject::Dictionary(entries)), i + 1)
      _ => {
        let (key_item, next_i) = parse_value(items, i)
        let (val_item, next_i2) = parse_value(items, next_i)
        match (key_item, val_item) {
          (ParseItem::Parsed(@pdf.PdfObject::Name(k)), ParseItem::Parsed(v)) =>
            entries.push((k, v))
          _ => raise @pdf.PdfError::Msg("parse_dictionary")
        }
        i = next_i2
      }
    }
  }
  raise @pdf.PdfError::Msg("parse_dictionary")
}

///|
fn parse_array(items : Array[ParseItem], start : Int) -> (ParseItem, Int) raise {
  let values = Array::new()
  let mut i = start + 1
  while i < items.length() {
    match items[i] {
      ParseItem::Lexeme(@pdfgenlex.Token::LexRightSquare) =>
        return (ParseItem::Parsed(@pdf.PdfObject::Array(values)), i + 1)
      _ => {
        let (val_item, next_i) = parse_value(items, i)
        match val_item {
          ParseItem::Parsed(v) => values.push(v)
          _ => raise @pdf.PdfError::Msg("parse_array")
        }
        i = next_i
      }
    }
  }
  raise @pdf.PdfError::Msg("parse_array")
}

///|
fn parse_value(items : Array[ParseItem], start : Int) -> (ParseItem, Int) raise {
  if start >= items.length() {
    raise @pdf.PdfError::Msg("parse_value")
  }
  match items[start] {
    ParseItem::Lexeme(@pdfgenlex.Token::LexLeftDict) =>
      parse_dictionary(items, start)
    ParseItem::Lexeme(@pdfgenlex.Token::LexLeftSquare) =>
      parse_array(items, start)
    other => (other, start + 1)
  }
}

///|
fn parse_to_tree(items : Array[ParseItem]) -> Array[ParseItem] raise {
  let out = Array::new()
  let mut i = 0
  while i < items.length() {
    match items[i] {
      ParseItem::Lexeme(@pdfgenlex.Token::LexLeftDict) => {
        let (parsed, next_i) = parse_dictionary(items, i)
        out.push(parsed)
        i = next_i
      }
      ParseItem::Lexeme(@pdfgenlex.Token::LexLeftSquare) => {
        let (parsed, next_i) = parse_array(items, i)
        out.push(parsed)
        i = next_i
      }
      other => {
        out.push(other)
        i = i + 1
      }
    }
  }
  out
}

///|
fn parse_finish(
  items : Array[ParseItem],
  failure_is_ok : Bool,
) -> (Int, @pdf.PdfObject) raise {
  if items.length() == 1 {
    match items[0] {
      ParseItem::Parsed(obj) => return (0, obj)
      _ => raise @pdf.PdfError::Msg("Could not extract object")
    }
  }
  if items.length() >= 5 {
    match (items[0], items[1], items[2], items[3], items[4]) {
      (
        ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
        ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
        ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
        ParseItem::Parsed(obj),
        ParseItem::Lexeme(@pdfgenlex.Token::LexEndObj),
      ) => return (o, obj)
      _ => ()
    }
  }
  if items.length() >= 4 {
    match (items[0], items[1], items[2], items[3]) {
      (
        ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
        ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
        ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
        ParseItem::Parsed(obj),
      ) => return (o, obj)
      (
        ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
        ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
        ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
        ParseItem::Lexeme(@pdfgenlex.Token::LexEndObj),
      ) => return (o, @pdf.PdfObject::Null)
      _ => ()
    }
  }
  if failure_is_ok {
    (0, @pdf.PdfObject::Null)
  } else {
    raise @pdf.PdfError::Msg("Could not extract object")
  }
}

///|
/// Parse a PDF object from tokens.
pub fn parse(
  tokens : Array[@pdfgenlex.Token],
  failure_is_ok? : Bool = false,
) -> (Int, @pdf.PdfObject) raise {
  parse_finish(parse_to_tree(parse_R(tokens)), failure_is_ok) catch {
    err => if failure_is_ok { (0, @pdf.PdfObject::Null) } else { raise err }
  }
}

///|
fn lex_object(input : @pdfio.Input) -> Array[@pdfgenlex.Token] raise {
  let tokens = Array::new()
  let mut done = false
  while !done {
    let t = lex_next(true, input)
    match t {
      @pdfgenlex.Token::StopLexing => done = true
      @pdfgenlex.Token::LexComment(_) => ()
      _ => tokens.push(t)
    }
  }
  tokens
}

///|
/// Parse a single object from a string.
pub fn parse_single_object(s : String) -> @pdf.PdfObject raise {
  let input = @pdfio.input_of_string(s)
  let (_, obj) = parse(lex_object(input))
  obj
}

///|
/// String of a lexeme.
pub fn string_of_lexeme(t : @pdfgenlex.Token) -> String {
  @pdfgenlex.string_of_token(t)
}

///|
/// Print a lexeme to stdout.
pub fn print_lexeme(t : @pdfgenlex.Token) -> Unit {
  println(@pdfgenlex.string_of_token(t))
}

///|
/// Hook for page-tree traversal (placeholder).
pub let endpage : Ref[(@pdf.Pdf) -> Int] = { val: _ => 0 }
