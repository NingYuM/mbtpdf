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

///|
test "build_name_tree handles empty input" {
  let pdf = @pdf.empty()
  let name_tree = @pdftree.build_name_tree(false, pdf, [])
  match @pdf.lookup_direct(pdf, "/Names", name_tree) {
    Some(@pdf.PdfObject::Array(items)) => assert_eq(items.length(), 0)
    _ => fail("expected empty /Names")
  }
  let num_tree = @pdftree.build_name_tree(true, pdf, [])
  match @pdf.lookup_direct(pdf, "/Nums", num_tree) {
    Some(@pdf.PdfObject::Array(items)) => assert_eq(items.length(), 0)
    _ => fail("expected empty /Nums")
  }
}

///|
test "build_name_tree uses kids for large inputs" {
  let pdf = @pdf.empty()
  let entries = Array::makei(11, i => ("Key\{i}", @pdf.PdfObject::Integer(i)))
  let tree = @pdftree.build_name_tree(false, pdf, entries)
  match @pdf.lookup_direct(pdf, "/Kids", tree) {
    Some(@pdf.PdfObject::Array(kids)) => assert_true(kids.length() > 0)
    _ => fail("expected /Kids on large tree")
  }
  let read = @pdftree.read_name_tree(pdf, tree)
  assert_eq(read.length(), 11)
  assert_eq(read[0].0, "Key0")
  let mut found = false
  for pair in read {
    if pair.0 == "Key10" {
      found = true
    }
  }
  assert_true(found)
}

///|
test "read_name_tree skips malformed keys" {
  let pdf = @pdf.empty()
  let tree = @pdf.PdfObject::Dictionary([
    (
      "/Names",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Integer(1),
        @pdf.PdfObject::Name("/One"),
      ]),
    ),
  ])
  let read = @pdftree.read_name_tree(pdf, tree)
  assert_eq(read.length(), 0)
}

///|
test "read_number_tree handles duplicate keys" {
  let pdf = @pdf.empty()
  let tree = @pdf.PdfObject::Dictionary([
    (
      "/Nums",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Integer(1),
        @pdf.PdfObject::Name("/One"),
        @pdf.PdfObject::Integer(1),
        @pdf.PdfObject::Name("/Uno"),
        @pdf.PdfObject::Integer(2),
        @pdf.PdfObject::Name("/Two"),
      ]),
    ),
  ])
  let read = @pdftree.read_number_tree(pdf, tree)
  assert_eq(read.length(), 2)
  let mut found = false
  for pair in read {
    if pair.0 == "1" {
      match pair.1 {
        @pdf.PdfObject::Name("/One") | @pdf.PdfObject::Name("/Uno") =>
          found = true
        _ => ()
      }
    }
  }
  assert_true(found)
}

///|
test "merge name trees combines entries" {
  let pdf = @pdf.empty()
  let tree1 = @pdftree.build_name_tree(false, pdf, [
    ("A", @pdf.PdfObject::Integer(1)),
    ("C", @pdf.PdfObject::Integer(3)),
  ])
  let tree2 = @pdftree.build_name_tree(false, pdf, [
    ("B", @pdf.PdfObject::Integer(2)),
  ])
  let merged = @pdftree.merge_name_trees_no_clash(pdf, [tree1, tree2])
  let read = @pdftree.read_name_tree(pdf, merged)
  assert_eq(read.length(), 3)
  assert_eq(read[0].0, "A")
  assert_eq(read[1].0, "B")
  assert_eq(read[2].0, "C")
}
