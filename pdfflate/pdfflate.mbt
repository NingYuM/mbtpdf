///|
/// Raised on an error in either compression or decompression.
pub suberror FlateError {
  Error(String, String)
}

///|
/// Compress data using a streaming interface (not implemented yet).
pub fn compress(
  level? : Int = 6,
  header? : Bool = true,
  input : (@pdfio.MutableBytes) -> Int,
  output : (@pdfio.MutableBytes, Int) -> Unit,
) -> Unit raise FlateError {
  let _ = level
  let _ = header
  let _ = input
  let _ = output
  raise FlateError::Error("compress", "not implemented")
}

///|
/// Uncompress data using a streaming interface (not implemented yet).
pub fn uncompress(
  header? : Bool = true,
  input : (@pdfio.MutableBytes) -> Int,
  output : (@pdfio.MutableBytes, Int) -> Unit,
) -> Unit raise FlateError {
  let _ = header
  let _ = input
  let _ = output
  raise FlateError::Error("uncompress", "not implemented")
}
