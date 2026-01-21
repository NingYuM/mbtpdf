///|
fn lex_object_at(
  oneonly : Bool,
  input : @pdfio.Input,
  read_stream_data : Bool,
  lexobj : (Int) -> Array[@pdfgenlex.Token] raise,
) -> Array[@pdfgenlex.Token] raise {
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let tokens = Array::new()
  let mut done = false
  while !done {
    let t = @pdfsyntax.lex_next(
      dict_level, array_level, false, input, tokens, read_stream_data, lexobj,
    )
    match t {
      @pdfgenlex.Token::LexEndObj => {
        tokens.push(t)
        done = true
      }
      @pdfgenlex.Token::StopLexing => done = true
      @pdfgenlex.Token::LexComment(_) => tokens.push(t)
      @pdfgenlex.Token::LexRightSquare | @pdfgenlex.Token::LexRightDict =>
        if oneonly && dict_level.val == 0 && array_level.val == 0 {
          tokens.push(t)
          done = true
        } else {
          tokens.push(t)
        }
      @pdfgenlex.Token::LexNone => {
        let message = @pdf.input_pdferror(input, "Could not read object")
        raise @pdf.PdfError::Msg(message)
      }
      other => {
        tokens.push(other)
        if oneonly && dict_level.val == 0 && array_level.val == 0 {
          let is_atom = match other {
            @pdfgenlex.Token::LexBool(_)
            | @pdfgenlex.Token::LexReal(_)
            | @pdfgenlex.Token::LexString(_)
            | @pdfgenlex.Token::LexName(_)
            | @pdfgenlex.Token::LexNull
            | @pdfgenlex.Token::LexInt(_) => true
            _ => false
          }
          if is_atom {
            done = true
          }
        }
      }
    }
  }
  tokens
}

///|
fn lex_object_for_xref(
  input : @pdfio.Input,
  xrefs : Map[Int, XRef],
  read_stream_data : Bool,
  objnum : Int,
) -> Array[@pdfgenlex.Token] raise {
  let current_pos = (input.pos_in)()
  match xrefs.get(objnum) {
    Some(XRef::Plain(offset, _gen)) => {
      (input.seek_in)(offset)
      let tokens = lex_object_at(false, input, read_stream_data, fn(
        k : Int,
      ) -> Array[@pdfgenlex.Token] raise {
        lex_object_for_xref(input, xrefs, read_stream_data, k)
      })
      (input.seek_in)(current_pos)
      tokens
    }
    Some(XRef::Stream(_, _)) => {
      let message = @pdf.input_pdferror(input, "Object in object stream")
      raise @pdf.PdfError::Msg(message)
    }
    None => {
      let message = @pdf.input_pdferror(input, "Object not in xref table")
      raise @pdf.PdfError::Msg(message)
    }
  }
}

///|
/// Parse a single object from a string.
pub fn parse_single_object(s : String) -> @pdf.PdfObject raise {
  let input = @pdfio.input_of_string(s)
  let (_, obj) = @pdfsyntax.parse(
    lex_object_at(true, input, true, fn(
      _ : Int,
    ) -> Array[@pdfgenlex.Token] raise {
      Array::new()
    }),
  )
  obj
}

///|
fn trim_trailing_zeros(value : String) -> String {
  let dot = value.find(".")
  match dot {
    None => value
    Some(_) => {
      let len = value.length()
      if len == 0 {
        return value
      }
      let mut end = len - 1
      while end >= 0 {
        match value.get_char(end) {
          Some('0') => end = end - 1
          _ => break
        }
      }
      if end >= 0 {
        match value.get_char(end) {
          Some('.') => end = end - 1
          _ => ()
        }
      }
      if end < 0 {
        "0"
      } else {
        let sb = StringBuilder::new()
        let mut i = 0
        while i <= end {
          match value.get_char(i) {
            Some(ch) => sb.write_char(ch)
            None => break
          }
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
  let len = value.length()
  if len == 0 {
    return 0
  }
  let mut sign = 1
  let mut i = 0
  match value.get_char(0) {
    Some('-') => {
      sign = -1
      i = 1
    }
    Some('+') => i = 1
    _ => ()
  }
  let mut result = 0
  while i < len {
    match value.get_char(i) {
      Some(c) => {
        if c < '0' || c > '9' {
          break
        }
        result = result * 10 + (c.to_int() - '0'.to_int())
      }
      None => break
    }
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
  if value == 0.0 {
    return "0"
  }
  let raw = value.to_string()
  if raw.contains("e") || raw.contains("E") {
    expand_scientific(raw)
  } else {
    trim_trailing_zeros(raw)
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
/// String of a lexeme.
pub fn string_of_lexeme(t : @pdfgenlex.Token) -> String {
  match t {
    @pdfgenlex.Token::LexNull => "null"
    @pdfgenlex.Token::LexBool(b) => if b { "true" } else { "false" }
    @pdfgenlex.Token::LexInt(i) => i.to_string()
    @pdfgenlex.Token::LexReal(r) => format_real(r)
    @pdfgenlex.Token::LexString(s) => make_pdf_string(s)
    @pdfgenlex.Token::LexName(s) => s
    @pdfgenlex.Token::LexLeftSquare => "["
    @pdfgenlex.Token::LexRightSquare => "]"
    @pdfgenlex.Token::LexLeftDict => "<<"
    @pdfgenlex.Token::LexRightDict => ">>"
    @pdfgenlex.Token::LexStream(_) => "LexStream"
    @pdfgenlex.Token::LexEndStream => "EndStream"
    @pdfgenlex.Token::LexObj => "obj"
    @pdfgenlex.Token::LexEndObj => "endobj"
    @pdfgenlex.Token::LexR => "R"
    @pdfgenlex.Token::LexComment(c) => "\n%\{c}\n"
    @pdfgenlex.Token::StopLexing => "StopLexing"
    @pdfgenlex.Token::LexNone => "LexNone"
  }
}
