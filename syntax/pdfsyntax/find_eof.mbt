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
    if [a, b, c, d, e] is ['%', '%', 'E', 'O', 'F'] {
      found = true
    }
  }
  (input.seek_in)(pos)
}
