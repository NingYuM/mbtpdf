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
} derive(Debug)

///|
fn is_delimiter_byte(b : Int) -> Bool {
  match b {
    '(' | ')' | '<' | '>' | '[' | ']' | '{' | '}' | '%' | '/' => true
    _ => false
  }
}

///|
fn is_whitespace_byte(b : Int) -> Bool {
  match b {
    0 | 9 | 10 | 12 | 13 | 32 => true
    _ => false
  }
}

///|
fn is_whitespace_or_delimiter_byte(b : Int) -> Bool {
  is_whitespace_byte(b) || is_delimiter_byte(b)
}

///|
fn dropwhite(input : @pdfio.Input) -> Unit {
  while true {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      break
    } else if is_whitespace_byte(b) {
      continue
    } else {
      input.rewind()
      break
    }
  }
}

///|
fn getuntil(input : @pdfio.Input) -> String {
  let bytes : Array[Byte] = Array::new()
  while true {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      break
    } else if is_whitespace_or_delimiter_byte(b) {
      input.rewind()
      break
    } else {
      bytes.push(b.to_byte())
    }
  }
  @pdfio.string_of_bytes(bytes)
}

///|
fn get_string(input : @pdfio.Input) -> String {
  let bytes : Array[Byte] = Array::new()
  let _ = (input.input_byte)()
  bytes.push('"'.to_int().to_byte())
  while true {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      break
    } else if b == '\\' {
      let next = (input.input_byte)()
      if next == @pdfio.no_more {
        break
      } else if next == '"' {
        bytes.push('"'.to_int().to_byte())
      } else {
        bytes.push('\\'.to_int().to_byte())
        bytes.push(next.to_byte())
      }
    } else if b == '"' {
      bytes.push(b.to_byte())
      break
    } else {
      bytes.push(b.to_byte())
    }
  }
  @pdfio.string_of_bytes(bytes)
}

///|
fn get_section(input : @pdfio.Input) -> String {
  match input.peek_byte() {
    b if b == @pdfio.no_more => ""
    _ => {
      dropwhite(input)
      match input.peek_byte() {
        b if b == @pdfio.no_more => ""
        '"' => get_string(input)
        b if is_delimiter_byte(b) => {
          input.nudge()
          b.to_byte().to_char().to_string()
        }
        _ => getuntil(input)
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
        let inner = try s[1:len - 1] catch {
          _ => ""
        } noraise {
          view => view.to_string()
        }
        LexString(inner)
      }
      _ => {
        let mut number = s
        if number.length() > 1 {
          match (number.get_char(0), number.get_char(1)) {
            (Some('-'), Some('-')) =>
              number = try number[1:] catch {
                _ => number
              } noraise {
                view => view.to_string()
              }
            _ => ()
          }
        }
        let has_decimal = number.contains(".") ||
          number.contains("e") ||
          number.contains("E")
        if !has_decimal {
          try @strconv.parse_int(number) catch {
            _ =>
              try @strconv.parse_double(number) catch {
                _ => LexName(s)
              } noraise {
                f => LexReal(f)
              }
          } noraise {
            i => LexInt(i)
          }
        } else {
          try @strconv.parse_double(number) catch {
            _ => LexName(s)
          } noraise {
            f => LexReal(f)
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
  while true {
    let t = lex_single(input)
    match t {
      LexNull => break
      _ => out.push(t)
    }
  }
  out
}

///|
/// Lex all tokens from a string.
pub fn lex_string(s : String) -> Array[Token] {
  lex(@pdfio.Input::of_string(s))
}
