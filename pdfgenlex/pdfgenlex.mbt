///|
/// Basic token stream for PDF parsing.
pub(all) enum Token {
  LexNull
  LexBool(Bool)
  LexInt(Int)
  LexReal(Double)
  LexString(String)
  LexName(String)
  LexLeftSquare
  LexRightSquare
  LexLeftDict
  LexRightDict
  LexStream(@pdf.Stream)
  LexEndStream
  LexObj
  LexEndObj
  LexR
  LexComment(String)
  StopLexing
  LexNone
}

///|
/// String representation of a token (debug only).
pub fn string_of_token(t : Token) -> String {
  match t {
    LexInt(i) => "Int \{i}"
    LexReal(r) => "Float \{r}"
    LexString(s) => "String \{s}"
    LexName(n) => "Ident \{n}"
    LexNull => "Nothing"
    _ => "GenLexNone"
  }
}

///|
/// String representation of a list of tokens (debug only).
pub fn string_of_tokens(tokens : Array[Token]) -> String {
  let parts = tokens.map(string_of_token)
  if parts.length() == 0 {
    ""
  } else {
    parts.join("\n ")
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
    b if b == '%'.to_int() => true
    b if b == '/'.to_int() => true
    _ => false
  }
}

///|
fn is_whitespace_byte(b : Int) -> Bool {
  b == 0 || b == 9 || b == 10 || b == 12 || b == 13 || b == 32
}

///|
fn is_whitespace_or_delimiter_byte(b : Int) -> Bool {
  is_whitespace_byte(b) || is_delimiter_byte(b)
}

///|
fn dropwhite(input : @pdfio.Input) -> Unit {
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else if is_whitespace_byte(b) {
      ()
    } else {
      @pdfio.rewind(input)
      done = true
    }
  }
}

///|
fn getuntil(input : @pdfio.Input) -> String {
  let bytes : Array[Byte] = Array::new()
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else if is_whitespace_or_delimiter_byte(b) {
      @pdfio.rewind(input)
      done = true
    } else {
      bytes.push(b.to_byte())
    }
  }
  @pdfio.string_of_bytes(bytes)
}

///|
fn get_string(input : @pdfio.Input) -> String {
  let bytes : Array[Byte] = Array::new()
  let mut done = false
  let _ = (input.input_byte)()
  bytes.push('"'.to_int().to_byte())
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else if b == '\\'.to_int() {
      let next = (input.input_byte)()
      if next == @pdfio.no_more {
        done = true
      } else {
        bytes.push('\\'.to_int().to_byte())
        bytes.push(next.to_byte())
      }
    } else if b == '"'.to_int() {
      bytes.push(b.to_byte())
      done = true
    } else {
      bytes.push(b.to_byte())
    }
  }
  @pdfio.string_of_bytes(bytes)
}

///|
fn get_section(input : @pdfio.Input) -> String {
  match @pdfio.peek_byte(input) {
    b if b == @pdfio.no_more => ""
    _ => {
      dropwhite(input)
      match @pdfio.peek_byte(input) {
        b if b == @pdfio.no_more => ""
        b if b == '"'.to_int() => get_string(input)
        b =>
          if is_delimiter_byte(b) {
            @pdfio.nudge(input)
            b.to_byte().to_char().to_string()
          } else {
            getuntil(input)
          }
      }
    }
  }
}

///|
fn lex_item(s : String) -> Token {
  let len = s.length()
  if len == 0 {
    LexNull
  } else {
    match s.get_char(0) {
      Some(c) if c.is_ascii_alphabetic() => LexName(s)
      Some('"') if len >= 2 => {
        let inner = match (try? s[1:len - 1]) {
          Ok(view) => view.to_string()
          Err(_) => ""
        }
        LexString(inner)
      }
      _ => {
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
            Ok(i) => LexInt(i)
            Err(_) =>
              match (try? @strconv.parse_double(number)) {
                Ok(f) => LexReal(f)
                Err(_) => LexName(s)
              }
          }
        } else {
          match (try? @strconv.parse_double(number)) {
            Ok(f) => LexReal(f)
            Err(_) => LexName(s)
          }
        }
      }
    }
  }
}

///|
/// Lex a single token from input.
pub fn lex_single(input : @pdfio.Input) -> Token {
  lex_item(get_section(input))
}

///|
/// Lex all tokens from input.
pub fn lex(input : @pdfio.Input) -> Array[Token] {
  let out = Array::new()
  let mut done = false
  while !done {
    let t = lex_single(input)
    match t {
      LexNull => done = true
      _ => out.push(t)
    }
  }
  out
}

///|
/// Lex all tokens from a string.
pub fn lex_string(s : String) -> Array[Token] {
  let input = @pdfio.input_of_string(s)
  lex(input)
}
