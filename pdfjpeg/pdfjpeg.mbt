///|
/// JPEG data extraction helpers.

///|
/// Return JPEG data starting at the current input position, leaving the input
/// ready at the byte following the JPEG data.
pub fn get_jpeg_data(input : @pdfio.Input) -> @pdfio.MutableBytes raise {
  let (output, data) = @pdfio.input_output_of_bytes(4096)
  let mut fin = false
  let mut last = 0
  while !fin {
    let x = (input.input_byte)()
    if x == @pdfio.no_more {
      raise Failure::Failure("Could not read JPEG data - end of stream")
    }
    if x == 0xD9 {
      if last == 0xFF {
        fin = true
      } else {
        last = 0xD9
      }
      (output.output_byte)(0xD9)
    } else {
      last = x
      (output.output_byte)(x)
    }
  }
  @pdfio.extract_bytes_from_input_output(output, data)
}
