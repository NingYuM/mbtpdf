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
/// Raw bytes for FFI-style access (alias in MoonBit).
pub type RawBytes = MutableBytes

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
  flush : async () -> Unit
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
  let sb = StringBuilder::new()
  sb.write_char('[')
  for i, value in bytes {
    if i > 0 {
      sb.write_string(", ")
    }
    sb.write_object(value.to_int())
  }
  sb.write_char(']')
  @pdfe.log(sb.to_string() + "\n")
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
/// Make bytes from a string by taking the low 8 bits of each character.
pub fn bytes_of_string(s : String) -> MutableBytes {
  let chars = s.to_array()
  let out = Array::new(capacity=chars.length())
  for c in chars {
    out.push(c.to_int().to_byte())
  }
  out
}

///|
/// Make bytes from core bytes.
pub fn bytes_of_caml_bytes(bytes : CoreBytes) -> MutableBytes {
  bytes.to_array()
}

///|
/// Expose raw bytes for interop (identity in MoonBit).
pub fn raw_of_bytes(bytes : MutableBytes) -> RawBytes {
  bytes
}

///|
/// Convert raw bytes back to mutable bytes (identity in MoonBit).
pub fn bytes_of_raw(raw : RawBytes) -> MutableBytes {
  raw
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
  bytes.map(b => b.to_int())
}

///|
/// Integer array from a string (byte-wise).
pub fn int_array_of_string(s : String) -> Array[Int] {
  bytes_of_string(s).map(b => b.to_int())
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
/// Make a string by mapping each byte to a single character.
pub fn string_of_bytes(bytes : MutableBytes) -> String {
  let chars = Array::new(capacity=bytes.length())
  for b in bytes {
    chars.push(b.to_char())
  }
  String::from_array(chars)
}

///|
/// Make a character array from bytes.
pub fn charlist_of_bytes(bytes : MutableBytes) -> Array[Char] {
  bytes.map(b => b.to_char())
}

///|
/// Copy bytes.
pub fn copybytes(bytes : MutableBytes) -> MutableBytes {
  bytes.copy()
}

///|
/// Build an input from bytes.
pub fn input_of_bytes(
  bytes : MutableBytes,
  source? : String = "bytes",
) -> Input {
  let mut pos = 0
  let mut offset = 0
  let len = bytes.length()
  let input_int = () => {
    let result = if pos > len - 1 { no_more } else { bget_unsafe(bytes, pos) }
    pos = pos + 1
    result
  }
  {
    pos_in: () => pos - offset,
    seek_in: p => pos = p + offset,
    input_char: () => {
      let v = input_int()
      if v == no_more {
        None
      } else {
        Some(v.to_byte().to_char())
      }
    },
    input_byte: input_int,
    in_channel_length: len,
    set_offset: o => if offset == 0 { offset = o },
    source,
  }
}

///|
/// Build an input from a string.
pub fn input_of_string(s : String, source? : String = "string") -> Input {
  input_of_bytes(bytes_of_string(s), source~)
}

///|
async fn read_data_to_bytes(load : async () -> &@io.Data) -> MutableBytes {
  let data = load()
  data.binary().to_array()
}

///|
async fn run_async_unit(load : async () -> Unit) -> Unit {
  load()
}

///|
/// Build an input from a file path (native-only, reads entire file).
pub async fn input_of_file(
  filename : String,
  source? : String = "file",
) -> Input {
  let bytes = read_data_to_bytes(() => @fs.read_file(filename))
  input_of_bytes(bytes, source~)
}

///|
/// Build an input from a channel (native-only, reads entire stream).
pub async fn input_of_channel(
  ch : @fs.File,
  source? : String = "channel",
) -> Input {
  let bytes = read_data_to_bytes(() => ch.read_all())
  input_of_bytes(bytes, source~)
}

///|
/// Build an output from a channel (native-only).
pub fn output_of_channel(ch : @fs.File) -> Output {
  let mut pos = 0
  let mut highest_written = -1
  let single : MutableBytes = mkbytes(1)
  let buffer : Ref[MutableBytes] = { val: mkbytes(4096) }
  let output_bytes = (bytes : Bytes) => {
    for b in bytes {
      if pos > buffer.val.length() - 1 {
        let new_len = if pos * 2 > 0 { pos * 2 } else { 1 }
        let new_bytes = mkbytes(new_len)
        for i in 0..<buffer.val.length() {
          bset_unsafe(new_bytes, i, bget_unsafe(buffer.val, i))
        }
        buffer.val = new_bytes
      }
      bset_unsafe(buffer.val, pos, b.to_int())
      pos = pos + 1
    }
    let last = pos - 1
    highest_written = if highest_written > last {
      highest_written
    } else {
      last
    }
  }
  async fn flush_output() -> Unit {
    let out = mkbytes(pos)
    for i in 0..<pos {
      bset_unsafe(out, i, bget_unsafe(buffer.val, i))
    }
    let bytes = Bytes::from_array(out)
    ch.write_at(bytes[:], position=0)
  }

  let output = {
    pos_out: () => pos,
    seek_out: p => pos = p,
    output_char: c => {
      single[0] = c.to_int().to_byte()
      output_bytes(Bytes::from_array(single))
    },
    output_byte: b => {
      single[0] = b.to_byte()
      output_bytes(Bytes::from_array(single))
    },
    output_string: s => output_bytes(Bytes::from_array(bytes_of_string(s))),
    out_channel_length: () => highest_written + 1,
    flush: flush_output,
  }
  output
}

///|
/// Build an input-output, with an initial buffer size.
pub fn input_output_of_bytes(size : Int) -> (Output, Ref[MutableBytes]) {
  let data : Ref[MutableBytes] = { val: mkbytes(size) }
  (output_of_bytes(data), data)
}

///|
/// Extract the contents of an input-output in bytes.
pub fn extract_bytes_from_input_output(
  output : Output,
  data : Ref[MutableBytes],
) -> MutableBytes {
  let len = (output.pos_out)()
  let out = mkbytes(len)
  for i in 0..<len {
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
  fn read_more(
    sb : StringBuilder,
    saw_any : Bool,
    input : Input,
  ) -> String raise {
    match (input.input_char)() {
      None => if saw_any { sb.to_string() } else { fail("End_of_file") }
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
pub fn setinit(
  input : Input,
  bytes : MutableBytes,
  offset : Int,
  length : Int,
) -> Unit raise {
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
pub fn setinit_string(
  input : Input,
  bytes : MutableBytes,
  offset : Int,
  length : Int,
) -> Unit raise {
  setinit(input, bytes, offset, length)
}

///|
/// Bytes with input o..o+l-1.
pub fn bytes_of_input(
  input : Input,
  offset : Int,
  length : Int,
) -> MutableBytes raise {
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
pub fn getinit(
  output : Output,
  bytes : MutableBytes,
  offset : Int,
  length : Int,
) -> Unit raise {
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
/// Extract bytes from input channel.
pub async fn bytes_of_input_channel(ch : @fs.File) -> MutableBytes {
  read_data_to_bytes(() => ch.read_all())
}

///|
/// Write bytes to output channel.
pub async fn bytes_to_output_channel(
  ch : @fs.File,
  bytes : MutableBytes,
) -> Unit {
  let payload = Bytes::from_array(bytes)
  run_async_unit(() => ch.write(payload))
}

///|
/// Most-significant-bit-first bitstream over an Input.
pub struct Bitstream {
  input : Input
  mut curr_byte : Int
  mut bit : Int
  mut bits_read : Int
}

///|
/// Position token for Bitstream; details will evolve during implementation.
pub struct BitstreamPosition {
  pos : Int
  curr_byte : Int
  bit : Int
  bits_read : Int
} derive(Debug)

///|
/// Most-significant-bit-first write bitstream (placeholder).
pub struct BitstreamWrite {
  bytes : MutableBytes
  mut bit : Int
} derive(Debug)

///|
/// Build a bitstream from an input.
pub fn bitbytes_of_input(input : Input) -> Bitstream {
  { input, curr_byte: 0, bit: 0, bits_read: 0 }
}

///|
/// Get the current position of a bitstream.
pub fn bitstream_pos(b : Bitstream) -> BitstreamPosition {
  {
    pos: (b.input.pos_in)(),
    curr_byte: b.curr_byte,
    bit: b.bit,
    bits_read: b.bits_read,
  }
}

///|
/// Seek to a previous bitstream position.
pub fn bitstream_seek(b : Bitstream, pos : BitstreamPosition) -> Unit {
  (b.input.seek_in)(pos.pos)
  b.curr_byte = pos.curr_byte
  b.bit = pos.bit
  b.bits_read = pos.bits_read
}

///|
/// Read the next bit from a bitstream.
pub fn getbit(b : Bitstream) -> Bool raise {
  if b.bit == 0 {
    let value = (b.input.input_byte)()
    if value == no_more {
      fail("End_of_file")
    }
    b.curr_byte = value
    b.bit = 128
  }
  let result = (b.curr_byte & b.bit) > 0
  b.bits_read = b.bits_read + 1
  b.bit = b.bit / 2
  result
}

///|
/// Read the next bit as an integer, 0 or 1.
pub fn getbitint(b : Bitstream) -> Int raise {
  if getbit(b) {
    1
  } else {
    0
  }
}

///|
fn getbitsint(b : Bitstream, n : Int) -> Int raise {
  if n < 0 {
    fail("getbitsint")
  }
  let mut value = 0
  for _ in 0..<n {
    value = (value << 1) | getbitint(b)
  }
  value
}

///|
/// Align a bitstream to the next byte boundary.
pub fn align(b : Bitstream) -> Unit {
  if b.bit > 0 {
    b.bits_read = (b.bits_read / 8 + 1) * 8
    b.bit = 0
  }
}

///|
/// Read up to 32 bits as an integer.
pub fn getval_32(b : Bitstream, n : Int) -> Int raise {
  if n < 0 {
    fail("Pdfio.getval_32 - n < 0")
  }
  getbitsint(b, n)
}

///|
/// Read up to 31 bits as an integer.
pub fn getval_31(b : Bitstream, n : Int) -> Int raise {
  if n < 0 {
    fail("Pdfio.getval_31 - n < 0")
  }
  getbitsint(b, n)
}

///|
/// Make a new write bitstream.
pub fn make_write_bitstream() -> BitstreamWrite {
  { bytes: Array::new(), bit: 0 }
}

///|
fn bitstream_bits(b : BitstreamWrite) -> Int {
  let count = b.bytes.length()
  if count == 0 {
    0
  } else if b.bit == 0 {
    count * 8
  } else {
    (count - 1) * 8 + b.bit
  }
}

///|
/// Put a single bit into a write bitstream.
pub fn putbit(b : BitstreamWrite, bit : Int) -> Unit {
  if b.bit == 0 {
    b.bytes.push((0).to_byte())
  }
  let idx = b.bytes.length() - 1
  if bit == 1 {
    let curr = b.bytes[idx].to_int()
    let mask = 1 << (7 - b.bit)
    b.bytes[idx] = (curr | mask).to_byte()
  }
  b.bit = b.bit + 1
  if b.bit == 8 {
    b.bit = 0
  }
}

///|
/// Put a multi-bit value into a write bitstream.
pub fn putval(b : BitstreamWrite, bits : Int, value : Int) -> Unit raise {
  if bits < 0 || bits > 32 {
    fail("putval")
  }
  let mut i = bits - 1
  while i >= 0 {
    let bit = (value >> i) & 1
    putbit(b, bit)
    i = i - 1
  }
}

///|
/// Align a write bitstream to the next byte boundary.
pub fn align_write(b : BitstreamWrite) -> Unit {
  if b.bit > 0 {
    while b.bit != 0 {
      putbit(b, 0)
    }
  }
}

///|
/// Extract bytes from a write bitstream, padding with zeros.
pub fn bytes_of_write_bitstream(b : BitstreamWrite) -> MutableBytes {
  align_write(b)
  b.bytes.copy()
}

///|
fn append_bits(dest : BitstreamWrite, src : BitstreamWrite) -> Unit {
  let total = bitstream_bits(src)
  if total == 0 {
    return
  }
  for i in 0..<total {
    let byte_index = i / 8
    let bit_index = i % 8
    let curr = src.bytes[byte_index].to_int()
    let mask = 1 << (7 - bit_index)
    let bit = if (curr & mask) > 0 { 1 } else { 0 }
    putbit(dest, bit)
  }
}

///|
/// Append two write bitstreams, aligning at the join.
pub fn write_bitstream_append_aligned(
  a : BitstreamWrite,
  b : BitstreamWrite,
) -> BitstreamWrite {
  let out = { bytes: a.bytes.copy(), bit: a.bit }
  align_write(out)
  append_bits(out, b)
  out
}

///|
/// Internal output builder over bytes.
fn output_of_bytes(data : Ref[MutableBytes]) -> Output {
  let mut pos = 0
  let mut highest_written = -1
  let output_int = (value : Int) => if pos > data.val.length() - 1 {
    let new_len = if pos * 2 > 0 { pos * 2 } else { 1 }
    let new_bytes = mkbytes(new_len)
    for i in 0..<data.val.length() {
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
  {
    pos_out: () => pos,
    seek_out: p => pos = p,
    output_char: c => output_int(c.to_int()),
    output_string: s => {
      let bytes = bytes_of_string(s)
      for b in bytes {
        output_int(b.to_int())
      }
    },
    output_byte: output_int,
    out_channel_length: () => highest_written + 1,
    flush: noop_flush,
  }
}

///|
/// No-op flush for in-memory outputs.
#warnings("-unused_async")
async fn noop_flush() -> Unit {
  ()
}

///|
fn debug_next_char(input : Input) -> Unit {
  match (input.input_char)() {
    Some(chr) => @pdfe.log("\{chr} = \{chr.to_int()}\n")
    None => ()
  }
}

///|
/// Debug the next `count` characters to the log and rewind.
pub fn debug_next_n_chars(count : Int, input : Input) -> Unit {
  let mut i = 0
  while i < count {
    debug_next_char(input)
    i = i + 1
  }
  @pdfe.log("\n")
  let mut rewind_count = 0
  while rewind_count < count {
    rewind(input)
    rewind_count = rewind_count + 1
  }
}
