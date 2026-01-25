///|
/// Deferred stringification hook.
pub let string_of_pdf : Ref[(PdfObject) -> String] = Ref::new((_ : PdfObject) => "")
