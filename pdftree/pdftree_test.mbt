///|
test "build and read name tree" {
  let pdf = @pdf.empty()
  let entries = [
    ("A", @pdf.PdfObject::Integer(1)),
    ("B", @pdf.PdfObject::Integer(2)),
    ("C", @pdf.PdfObject::Integer(3)),
  ]
  let tree = @pdftree.build_name_tree(false, pdf, entries)
  let read = @pdftree.read_name_tree(pdf, tree)
  assert_eq(read.length(), 3)
  assert_eq(read[0].0, "A")
  assert_eq(read[1].0, "B")
  assert_eq(read[2].0, "C")
}

///|
test "build and read number tree" {
  let pdf = @pdf.empty()
  let entries = [
    ("1", @pdf.PdfObject::Name("/One")),
    ("3", @pdf.PdfObject::Name("/Three")),
    ("2", @pdf.PdfObject::Name("/Two")),
  ]
  let tree = @pdftree.build_name_tree(true, pdf, entries)
  let read = @pdftree.read_number_tree(pdf, tree)
  assert_eq(read.length(), 3)
  assert_eq(read[0].0, "1")
  assert_eq(read[1].0, "2")
  assert_eq(read[2].0, "3")
}
