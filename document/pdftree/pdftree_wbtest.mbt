///|
test "remove_duplicates keeps last entry" {
  let entries = [
    (@pdf.PdfObject::String("A"), @pdf.PdfObject::Integer(1)),
    (String("A"), Integer(2)),
    (String("B"), Integer(3)),
    (String("B"), Integer(4)),
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
