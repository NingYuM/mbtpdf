///|
/// Distinguished value indicating "no more input".
pub let no_more : Int = -1

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
  bytes : Array[Int]
  bit : Int
}
