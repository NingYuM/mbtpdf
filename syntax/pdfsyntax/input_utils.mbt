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
  c is ('\n' | '\r')
}

///|
fn is_delimiter(c : Char) -> Bool {
  c is ('(' | ')' | '<' | '>' | '[' | ']' | '{' | '}' | '%' | '/')
}

///|
pub fn is_whitespace_or_delimiter(c : Char) -> Bool {
  is_whitespace(c) || is_delimiter(c)
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

///|
/// Read chars until predicate is true, returning a string.
pub fn getuntil_string(
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
/// Read a line from input (newline not included).

///|
/// Read a line from input (newline not included).
pub fn input_line(input : @pdfio.Input) -> String {
  let sb = StringBuilder::new()
  let mut got_eol = false
  let mut finished = false
  while !finished {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      finished = true
    } else {
      let c = b.to_byte().to_char()
      if is_newline(c) {
        got_eol = true
      } else if got_eol {
        @pdfio.rewind(input)
        finished = true
      } else {
        sb.write_char(c)
      }
    }
  }
  sb.to_string()
}

///|
/// Read back until predicate is true.
fn read_back_until(pred : (Char) -> Bool, input : @pdfio.Input) -> Unit raise {
  match @pdfio.read_char_back(input) {
    Some(ch) => if !pred(ch) { read_back_until(pred, input) }
    None => fail("End_of_file")
  }
}

///|
/// Go back one line.

///|
/// Go back one line.
pub fn backline(input : @pdfio.Input) -> Unit raise {
  read_back_until(is_newline, input)
  read_back_until(c => !is_newline(c), input)
  read_back_until(is_newline, input)
  @pdfio.nudge(input)
}

///|
/// Find the EOF marker and position input there.

///|
/// Find the EOF marker and position input there.
pub fn find_eof(input : @pdfio.Input) -> Unit raise {
  fn fail_find() -> Unit raise {
    let message = @pdf.input_pdferror(input, "Could not find EOF marker")
    raise @pdf.PdfError::Msg(message)
  }

  let mut pos = input.in_channel_length - 4
  let mut tries = pos
  let mut found = false
  while !found {
    pos = pos - 1
    if pos < 0 || tries < 0 {
      fail_find()
    }
    tries = tries - 1
    (input.seek_in)(pos)
    let a = (input.input_byte)()
    let b = (input.input_byte)()
    let c = (input.input_byte)()
    let d = (input.input_byte)()
    let e = (input.input_byte)()
    if a == '%'.to_int() &&
      b == '%'.to_int() &&
      c == 'E'.to_int() &&
      d == 'O'.to_int() &&
      e == 'F'.to_int() {
      found = true
    }
  }
  (input.seek_in)(pos)
}
