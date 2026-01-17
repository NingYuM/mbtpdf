///|
/// Distinguished value indicating "no more input".
pub let no_more : Int = -1

///|
/// Mutable byte buffer used throughout the port.
pub type MutableBytes = Array[Byte]

///|
/// Immutable core bytes type.
pub type CoreBytes = Bytes

///|
/// Input abstraction (seekable stream of bytes).
pub struct Input {
  pos_in : () -> Int
  seek_in : (Int) -> Unit
  input_char : () -> Char?
  input_byte : () -> Int
  in_channel_length : Int
  set_offset : (Int) -> Unit
  source : String
}

///|
/// Output abstraction (seekable stream of bytes).
pub struct Output {
  pos_out : () -> Int
  seek_out : (Int) -> Unit
  output_char : (Char) -> Unit
  output_byte : (Int) -> Unit
  output_string : (String) -> Unit
  out_channel_length : () -> Int
}

///|
/// Build bytes with the given size, filled with zero.
pub fn mkbytes(size : Int) -> MutableBytes {
  Array::make(size, (0).to_byte())
}

///|
/// Size of bytes.
pub fn bytes_size(bytes : MutableBytes) -> Int {
  bytes.length()
}

///|
/// Fill bytes with a value.
pub fn fillbytes(value : Int, bytes : MutableBytes) -> Unit {
  bytes.fill(value.to_byte())
}

///|
/// Print bytes to standard output (debug format).
pub fn print_bytes(bytes : MutableBytes) -> Unit {
  println(bytes.map((b) => b.to_int()))
}

///|
/// Get the value at a position in bytes.
pub fn bget(bytes : MutableBytes, index : Int) -> Int {
  bytes[index].to_int()
}

///|
/// Like bget, but without bounds checking.
pub fn bget_unsafe(bytes : MutableBytes, index : Int) -> Int {
  bytes.unsafe_get(index).to_int()
}

///|
/// Set the value at a position in bytes.
pub fn bset(bytes : MutableBytes, index : Int, value : Int) -> Unit {
  bytes[index] = value.to_byte()
}

///|
/// Like bset, but without bounds checking.
pub fn bset_unsafe(bytes : MutableBytes, index : Int, value : Int) -> Unit {
  bytes.unsafe_set(index, value.to_byte())
}

///|
/// Map bytes onto itself using a function on each byte.
pub fn bytes_selfmap(f : (Int) -> Int, bytes : MutableBytes) -> Unit {
  for i, b in bytes {
    bytes[i] = f(b.to_int()).to_byte()
  }
}

///|
/// Make bytes from a string (UTF-8 encoding).
pub fn bytes_of_string(s : String) -> MutableBytes {
  @encoding/utf8.encode(s).to_array()
}

///|
/// Make bytes from core bytes.
pub fn bytes_of_caml_bytes(bytes : CoreBytes) -> MutableBytes {
  bytes.to_array()
}

///|
/// Make bytes from an array of integers (each 0..255).
pub fn bytes_of_list(values : Array[Int]) -> MutableBytes {
  let out = Array::new(capacity=values.length())
  for v in values {
    out.push(v.to_byte())
  }
  out
}

///|
/// Make bytes from a character array.
pub fn bytes_of_charlist(values : Array[Char]) -> MutableBytes {
  let out = Array::new(capacity=values.length())
  for v in values {
    out.push(v.to_int().to_byte())
  }
  out
}

///|
/// Make bytes from a list of integer arrays.
pub fn bytes_of_arraylist(values : Array[Array[Int]]) -> MutableBytes {
  let mut total = 0
  for v in values {
    total = total + v.length()
  }
  let out = Array::new(capacity=total)
  for v in values {
    for x in v {
      out.push(x.to_byte())
    }
  }
  out
}

///|
/// Make bytes from an integer array.
pub fn bytes_of_int_array(values : Array[Int]) -> MutableBytes {
  bytes_of_list(values)
}

///|
/// Integer array from bytes.
pub fn int_array_of_bytes(bytes : MutableBytes) -> Array[Int] {
  bytes.map((b) => b.to_int())
}

///|
/// Integer array from a string (UTF-8).
pub fn int_array_of_string(s : String) -> Array[Int] {
  bytes_of_string(s).map((b) => b.to_int())
}

///|
/// String from a list of integer arrays.
pub fn string_of_int_arrays(values : Array[Array[Int]]) -> String {
  string_of_int_array(values.flatten())
}

///|
/// String from a single int array.
pub fn string_of_int_array(values : Array[Int]) -> String {
  string_of_bytes(bytes_of_list(values))
}

///|
/// Make a string from bytes without validation.
pub fn string_of_bytes(bytes : MutableBytes) -> String {
  Bytes::from_array(bytes).to_unchecked_string()
}

///|
/// Make a character array from bytes.
pub fn charlist_of_bytes(bytes : MutableBytes) -> Array[Char] {
  bytes.map((b) => b.to_char())
}

///|
/// Copy bytes.
pub fn copybytes(bytes : MutableBytes) -> MutableBytes {
  bytes.copy()
}

///|
/// Build an input from bytes.
pub fn input_of_bytes(bytes : MutableBytes, source? : String = "bytes") -> Input {
  let mut pos = 0
  let mut offset = 0
  let len = bytes.length()
  let input_int = () => {
    let result =
      if pos > len - 1 {
        no_more
      } else {
        bget_unsafe(bytes, pos)
      }
    pos = pos + 1
    result
  }
  {
    pos_in : () => pos - offset,
    seek_in : (p) => { pos = p + offset },
    input_char : () => {
      let v = input_int()
      if v == no_more {
        None
      } else {
        Some(v.to_byte().to_char())
      }
    },
    input_byte : input_int,
    in_channel_length : len,
    set_offset : (o) => {
      if offset == 0 {
        offset = o
      }
    },
    source : source,
  }
}

///|
/// Build an input from a string.
pub fn input_of_string(s : String, source? : String = "string") -> Input {
  input_of_bytes(bytes_of_string(s), source=source)
}

///|
/// Build an input from a channel (native-only, placeholder).
pub fn input_of_channel(_ch : Unit, source? : String = "channel") -> Input raise {
  fail("input_of_channel not implemented yet")
}

///|
/// Build an output from a channel (native-only, placeholder).
pub fn output_of_channel(_ch : Unit) -> Output raise {
  fail("output_of_channel not implemented yet")
}

///|
/// Build an input-output, with an initial buffer size.
pub fn input_output_of_bytes(size : Int) -> (Output, Ref[MutableBytes]) {
  let data : Ref[MutableBytes] = { val: mkbytes(size) }
  (output_of_bytes(data), data)
}

///|
/// Extract the contents of an input-output in bytes.
pub fn extract_bytes_from_input_output(output : Output, data : Ref[MutableBytes]) -> MutableBytes {
  let len = (output.pos_out)()
  let out = mkbytes(len)
  for i = 0; i < len; i = i + 1 {
    bset_unsafe(out, i, bget_unsafe(data.val, i))
  }
  out
}

///|
/// Move forward one byte.
pub fn nudge(input : Input) -> Unit {
  ignore((input.input_byte)())
}

///|
/// Move backward one byte.
pub fn rewind(input : Input) -> Unit {
  (input.seek_in)((input.pos_in)() - 1)
}

///|
/// Look at the next character without advancing the pointer.
pub fn peek_char(input : Input) -> Char? {
  let r = (input.input_char)()
  rewind(input)
  r
}

///|
/// Look at the next byte without advancing the pointer.
pub fn peek_byte(input : Input) -> Int {
  let r = (input.input_byte)()
  rewind(input)
  r
}

///|
/// Read the previous character, moving the pointer back one.
pub fn read_char_back(input : Input) -> Char? {
  let pos = (input.pos_in)()
  (input.seek_in)(pos - 1)
  let chr = (input.input_char)()
  (input.seek_in)(pos - 1)
  chr
}

///|
/// Read a line from an input (newline not included).
pub fn read_line(input : Input) -> String raise {
  let sb = StringBuilder::new()
  fn read_more(sb : StringBuilder, saw_any : Bool, input : Input) -> String raise {
    match (input.input_char)() {
      None => {
        if saw_any {
          sb.to_string()
        } else {
          fail("End_of_file")
        }
      }
      Some('\n') => sb.to_string()
      Some(ch) => {
        sb.write_char(ch)
        read_more(sb, true, input)
      }
    }
  }
  read_more(sb, false, input)
}

///|
/// Read all lines from an input.
pub fn read_lines(input : Input) -> Array[String] raise {
  let lines = Array::new()
  fn read_all(lines : Array[String], input : Input) -> Array[String] raise {
    match peek_char(input) {
      None => lines
      Some(_) => {
        lines.push(read_line(input))
        read_all(lines, input)
      }
    }
  }
  read_all(lines, input)
}

///|
/// Set bytes o..o+l-1 from input.
pub fn setinit(input : Input, bytes : MutableBytes, offset : Int, length : Int) -> Unit raise {
  if length == 0 {
    return
  }
  let max = bytes.length() - 1
  let last = offset + length - 1
  if offset > max || offset < 0 || last < 0 || last > max {
    fail("setinit")
  }
  for i = offset; i < offset + length; i = i + 1 {
    bytes[i] = (input.input_byte)().to_byte()
  }
}

///|
/// Set bytes o..o+l-1 from input (alias for string-backed buffers).
pub fn setinit_string(input : Input, bytes : MutableBytes, offset : Int, length : Int) -> Unit raise {
  setinit(input, bytes, offset, length)
}

///|
/// Bytes with input o..o+l-1.
pub fn bytes_of_input(input : Input, offset : Int, length : Int) -> MutableBytes raise {
  (input.seek_in)(offset)
  let out = mkbytes(length)
  setinit(input, out, 0, length)
  out
}

///|
/// String of input contents.
pub fn string_of_input(input : Input) -> String raise {
  string_of_bytes(bytes_of_input(input, 0, input.in_channel_length))
}

///|
/// Write bytes o..o+l-1 to output.
pub fn getinit(output : Output, bytes : MutableBytes, offset : Int, length : Int) -> Unit raise {
  if length == 0 {
    return
  }
  let max = bytes.length() - 1
  let last = offset + length - 1
  if offset > max || offset < 0 || last < 0 || last > max {
    fail("getinit")
  }
  for i = offset; i < offset + length; i = i + 1 {
    (output.output_byte)(bget_unsafe(bytes, i))
  }
}

///|
/// Extract bytes from input channel (placeholder).
pub fn bytes_of_input_channel(_ch : Unit) -> MutableBytes raise {
  fail("bytes_of_input_channel not implemented yet")
}

///|
/// Write bytes to output channel (placeholder).
pub fn bytes_to_output_channel(_ch : Unit, _bytes : MutableBytes) -> Unit raise {
  fail("bytes_to_output_channel not implemented yet")
}

///|
/// Most-significant-bit-first bitstream over an Input.
pub struct Bitstream {
  input : Input
  curr_byte : Int
  bit : Int
  bits_read : Int
}

///|
/// Position token for Bitstream; details will evolve during implementation.
pub struct BitstreamPosition {
  pos : Int
  curr_byte : Int
  bit : Int
  bits_read : Int
}

///|
/// Most-significant-bit-first write bitstream (placeholder).
pub struct BitstreamWrite {
  bytes : MutableBytes
  bit : Int
}

///|
/// Internal output builder over bytes.
fn output_of_bytes(data : Ref[MutableBytes]) -> Output {
  let mut pos = 0
  let mut highest_written = -1
  let output_int = (value : Int) => {
    if pos > data.val.length() - 1 {
      let new_len = if pos * 2 > 0 { pos * 2 } else { 1 }
      let new_bytes = mkbytes(new_len)
      for i = 0; i < data.val.length(); i = i + 1 {
        bset_unsafe(new_bytes, i, bget_unsafe(data.val, i))
      }
      bset_unsafe(new_bytes, pos, value)
      highest_written = if highest_written > pos { highest_written } else { pos }
      pos = pos + 1
      data.val = new_bytes
    } else {
      highest_written = if highest_written > pos { highest_written } else { pos }
      bset_unsafe(data.val, pos, value)
      pos = pos + 1
    }
  }
  {
    pos_out : () => pos,
    seek_out : (p) => { pos = p },
    output_char : (c) => { output_int(c.to_int()) },
    output_string : (s) => {
      let bytes = bytes_of_string(s)
      for b in bytes {
        output_int(b.to_int())
      }
    },
    output_byte : output_int,
    out_channel_length : () => highest_written + 1,
  }
}
