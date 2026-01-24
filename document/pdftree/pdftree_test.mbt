///|
test "build and read name tree" {
  let pdf = @pdf.Pdf::empty()
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("A", Integer(1)),
    ("B", Integer(2)),
    ("C", Integer(3)),
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
  let pdf = @pdf.Pdf::empty()
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("1", Name("/One")),
    ("3", Name("/Three")),
    ("2", Name("/Two")),
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
  let pdf = @pdf.Pdf::empty()
  let name_tree = @pdftree.build_name_tree(false, pdf, [])
  match @pdf.lookup_direct(pdf, "/Names", name_tree) {
    Some(Array(items)) => assert_eq(items.length(), 0)
    _ => fail("expected empty /Names")
  }
  let num_tree = @pdftree.build_name_tree(true, pdf, [])
  match @pdf.lookup_direct(pdf, "/Nums", num_tree) {
    Some(Array(items)) => assert_eq(items.length(), 0)
    _ => fail("expected empty /Nums")
  }
}

///|
test "build_name_tree uses kids for large inputs" {
  let pdf = @pdf.Pdf::empty()
  let entries : Array[(String, @pdf.PdfObject)] = Array::makei(11, i => (
    "Key\{i}",
    Integer(i),
  ))
  let tree = @pdftree.build_name_tree(false, pdf, entries)
  match @pdf.lookup_direct(pdf, "/Kids", tree) {
    Some(Array(kids)) => assert_true(kids.length() > 0)
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
  let pdf = @pdf.Pdf::empty()
  let tree : @pdf.PdfObject = Dictionary([
    ("/Names", Array([Integer(1), Name("/One")])),
  ])
  let read = @pdftree.read_name_tree(pdf, tree)
  assert_eq(read.length(), 0)
}

///|
test "read_number_tree handles duplicate keys" {
  let pdf = @pdf.Pdf::empty()
  let tree : @pdf.PdfObject = Dictionary([
    (
      "/Nums",
      Array([
        Integer(1),
        Name("/One"),
        Integer(1),
        Name("/Uno"),
        Integer(2),
        Name("/Two"),
      ]),
    ),
  ])
  let read = @pdftree.read_number_tree(pdf, tree)
  assert_eq(read.length(), 2)
  let mut found = false
  for pair in read {
    if pair.0 == "1" {
      match (pair.1 : @pdf.PdfObject) {
        Name("/One") | Name("/Uno") => found = true
        _ => ()
      }
    }
  }
  assert_true(found)
}

///|
test "merge name trees combines entries" {
  let pdf = @pdf.Pdf::empty()
  let tree1 = @pdftree.build_name_tree(false, pdf, [
    ("A", Integer(1)),
    ("C", Integer(3)),
  ])
  let tree2 = @pdftree.build_name_tree(false, pdf, [("B", Integer(2))])
  let merged = @pdftree.merge_name_trees_no_clash(pdf, [tree1, tree2])
  let read = @pdftree.read_name_tree(pdf, merged)
  assert_eq(read.length(), 3)
  assert_eq(read[0].0, "A")
  assert_eq(read[1].0, "B")
  assert_eq(read[2].0, "C")
}
