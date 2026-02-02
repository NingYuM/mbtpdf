///|
test "remove_duplicates keeps last entry" {
  let entries = [
    (@pdf.PdfObject::PdfString("A"), @pdf.PdfObject::Integer(1)),
    (PdfString("A"), Integer(2)),
    (PdfString("B"), Integer(3)),
    (PdfString("B"), Integer(4)),
  ]
  let deduped = remove_duplicates(entries, false)
  assert_eq(deduped.length(), 2)
  match deduped[0].1 {
    Integer(value) => assert_eq(value, 2)
    _ => fail("expected last A entry")
  }
  match deduped[1].1 {
    Integer(value) => assert_eq(value, 4)
    _ => fail("expected last B entry")
  }
}
