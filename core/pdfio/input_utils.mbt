///|
/// PDF whitespace predicate.
pub fn is_whitespace(c : Char) -> Bool {
  let v = c.to_int()
  v == 0 || v == 9 || v == 10 || v == 12 || v == 13 || v == 32
}

///|
fn is_not_whitespace(c : Char) -> Bool {
  !is_whitespace(c)
}

///|
pub fn is_newline(c : Char) -> Bool {
  c is ('\n' | '\r')
}

///|
pub fn is_delimiter(c : Char) -> Bool {
  c is ('(' | ')' | '<' | '>' | '[' | ']' | '{' | '}' | '%' | '/')
}

///|
pub fn is_whitespace_or_delimiter(c : Char) -> Bool {
  is_whitespace(c) || is_delimiter(c)
}

///|
/// Read chars until whitespace or delimiter.
pub fn getuntil_white_or_delimiter_string(input : Input) -> String raise {
  getuntil_string(true, c => is_whitespace_or_delimiter(c), input)
}

///|
/// Read chars until predicate is true.
pub fn getuntil(
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
  input : Input,
) -> Array[Char] raise {
  let out = Array::new()
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        input.rewind()
        done = true
      } else {
        out.push(c)
      }
    }
  }
  out
}

///|
/// Read chars until predicate is true, returning a string.
pub fn getuntil_string(
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
  input : Input,
) -> String raise {
  let sb = StringBuilder::new()
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        input.rewind()
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
  input : Input,
) -> Unit raise {
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        input.rewind()
        done = true
      }
    }
  }
}

///|
/// Drop PDF whitespace.
pub fn dropwhite(input : Input) -> Unit raise {
  ignoreuntil(true, is_not_whitespace, input)
}

///|
/// Read a line from input (newline not included).
///
/// Unlike `Input::read_line`, this returns `""` at EOF instead of raising.
pub fn input_line(input : Input) -> String {
  let sb = StringBuilder::new()
  let mut got_eol = false
  let mut finished = false
  while !finished {
    let b = (input.input_byte)()
    if b == no_more {
      finished = true
    } else {
      let c = b.to_byte().to_char()
      if is_newline(c) {
        got_eol = true
      } else if got_eol {
        input.rewind()
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
fn read_back_until(pred : (Char) -> Bool, input : Input) -> Unit raise {
  match input.read_char_back() {
    Some(ch) => if !pred(ch) { read_back_until(pred, input) }
    None => fail("End_of_file")
  }
}

///|
/// Go back one line.
pub fn backline(input : Input) -> Unit raise {
  read_back_until(is_newline, input)
  read_back_until(c => !is_newline(c), input)
  read_back_until(is_newline, input)
  input.nudge()
}

///|
/// Read `count` characters from `input` without advancing the cursor.
pub fn read_chunk(count : Int, input : Input) -> String raise {
  let pos = (input.pos_in)()
  let sb = StringBuilder::new()
  let mut i = 0
  while i < count {
    match (input.input_char)() {
      Some(ch) => sb.write_char(ch)
      None => {
        (input.seek_in)(pos)
        fail("read_chunk")
      }
    }
    i = i + 1
  }
  (input.seek_in)(pos)
  sb.to_string()
}
