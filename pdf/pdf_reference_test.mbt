///|
test "objects_referenced skips entries" {
  let pdf = empty()
  let obj = PdfObject::Dictionary([
    ("/Skip", PdfObject::Indirect(1)),
    ("/Keep", PdfObject::Integer(2)),
  ])
  let referenced = objects_referenced(["/Skip"], [], pdf, obj)
  assert_eq(referenced.length(), 0)
}

///|
test "objects_referenced no_follow_contains non-name" {
  let pdf = empty()
  let obj = PdfObject::Dictionary([
    ("/Other", PdfObject::Integer(3)),
    ("/Kid", PdfObject::Indirect(2)),
  ])
  addobj_given_num(pdf, (1, obj))
  addobj_given_num(pdf, (2, PdfObject::Integer(9)))
  let referenced = objects_referenced(
    [],
    [("/Other", PdfObject::Integer(3))],
    pdf,
    PdfObject::Indirect(1),
  )
  assert_true(referenced.contains(2))
}

///|
test "objects_referenced no_follow_contains name match" {
  let pdf = empty()
  let dict = PdfObject::Dictionary([
    ("/Other", PdfObject::Name("/Other")),
    ("/Type", PdfObject::Name("/Page")),
    ("/Kid", PdfObject::Indirect(2)),
  ])
  addobj_given_num(pdf, (1, dict))
  addobj_given_num(pdf, (2, PdfObject::Integer(9)))
  let referenced = objects_referenced(
    [],
    [("/Type", PdfObject::Name("/Page"))],
    pdf,
    PdfObject::Indirect(1),
  )
  assert_eq(referenced.length(), 0)
}

///|
test "objects_referenced indirect and stream targets" {
  let pdf = empty()
  addobj_given_num(pdf, (5, PdfObject::Integer(99)))
  let stream = make_stream(
    PdfObject::Dictionary([("/Ref", PdfObject::Indirect(5))]),
    @pdfio.bytes_of_string("x"),
  )
  addobj_given_num(pdf, (6, stream))
  let indirect_refs = objects_referenced([], [], pdf, PdfObject::Indirect(5))
  assert_true(indirect_refs.contains(5))
  let stream_refs = objects_referenced([], [], pdf, lookup_obj(pdf, 6))
  assert_true(stream_refs.contains(5))
}
