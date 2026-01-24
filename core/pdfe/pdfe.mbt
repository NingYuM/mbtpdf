///|
/// Default error logger, writes the string to stderr (shim).
fn default(message : String) -> Unit {
  @pdfutil.fleprint(message)
}

///|
/// The current error logger, set to default upon startup.
pub let logger : Ref[(String) -> Unit] = { val: default }

///|
/// Log a string using the current logger.
pub fn log(message : String) -> Unit {
  (logger.val)(message)
}

///|
/// Debug flag for PDF reading operations.
pub let read_debug : Ref[Bool] = { val: false }
