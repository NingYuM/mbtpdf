///|
/// Default error logger, writes the string to stderr (shim).
fn default(message : String) -> Unit {
  @pdfutil.PdfUtil::new().fleprint(message)
}

///|
pub struct Pdfe {
  unit : Unit
}

///|
pub fn Pdfe::new() -> Pdfe {
  { unit: () }
}

///|
/// The current error logger, set to default upon startup.
pub let logger : Ref[(String) -> Unit] = { val: default }

///|
/// Log a string using the current logger.
pub fn Pdfe::log(self : Pdfe, message : String) -> Unit {
  let _ = self
  (logger.val)(message)
}

///|
/// Debug flag for PDF reading operations.
pub let read_debug : Ref[Bool] = { val: false }
