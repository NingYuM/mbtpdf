///|
/// Deferred stringification hook.
pub let string_of_pdf : Ref[(PdfObject) -> String] = Ref::new((_ : PdfObject) => "")

///|
/// Hook called after reading each page during PDF parsing.
pub let endpage : Ref[(Pdf) -> Int] = { val: _ => 0 }
