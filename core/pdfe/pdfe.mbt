///|
/// Default error logger, writes the string to stderr (shim).
fn default(message : String) -> Unit {
  @pdfutil.PdfUtil::new().fleprint(message)
}

///|
pub type Logger = (String) -> Unit

///|
/// The current error logger, set to default upon startup.
pub let logger : Ref[Logger] = { val: default }

///|
/// Log a string using the current logger.
pub fn log(message : String) -> Unit {
  (logger.val)(message)
}

///|
/// Debug flag for PDF reading operations.
pub let read_debug : Ref[Bool] = { val: false }
