///|
/// Filesystem/channel adapters for `@pdfio`.
///
/// This package exists to keep `core/pdfio` mostly pure (in-memory inputs and
/// outputs), while concentrating native-only `@fs.File` helpers under `io/`.
///
/// These helpers currently read the whole file/channel into memory.

///|
pub async fn input_of_file(
  filename : String,
  source? : String = "file",
) -> @pdfio.Input {
  @pdfio.Input::of_file(filename, source~)
}

///|
pub async fn input_of_channel(
  ch : @fs.File,
  source? : String = "channel",
) -> @pdfio.Input {
  @pdfio.Input::of_channel(ch, source~)
}

///|
pub fn output_of_channel(ch : @fs.File) -> @pdfio.Output {
  @pdfio.Output::of_channel(ch)
}

///|
pub async fn bytes_of_input_channel(ch : @fs.File) -> @pdfio.MutableBytes {
  @pdfio.bytes_of_input_channel(ch)
}

///|
pub async fn bytes_to_output_channel(
  ch : @fs.File,
  bytes : @pdfio.MutableBytes,
) -> Unit {
  @pdfio.bytes_to_output_channel(ch, bytes)
}
