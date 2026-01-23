///|
fn make_basic_pdf() -> Pdf {
  let base = empty()
  let pages = PdfObject::Dictionary([
    ("/Type", PdfObject::Name("/Pages")),
    ("/Kids", PdfObject::Array([PdfObject::Indirect(2)])),
  ])
  let page = PdfObject::Dictionary([("/Type", PdfObject::Name("/Page"))])
  let catalog = PdfObject::Dictionary([
    ("/Type", PdfObject::Name("/Catalog")),
    ("/Pages", PdfObject::Indirect(1)),
  ])
  addobj_given_num(base, (1, pages))
  addobj_given_num(base, (2, page))
  addobj_given_num(base, (3, catalog))
  Pdf::{
    major: base.major,
    minor: base.minor,
    root: 3,
    objects: base.objects,
    trailerdict: PdfObject::Dictionary([("/Root", PdfObject::Indirect(3))]),
    was_linearized: base.was_linearized,
    saved_encryption: base.saved_encryption,
  }
}

///|
test "lookup helpers and catalog" {
  let pdf = empty()
  let dict = PdfObject::Dictionary([("/A", PdfObject::Integer(1))])
  assert_integer(lookup_fail("err", pdf, "/A", dict), 1)
  assert_is_err(try? lookup_fail("err", pdf, "/B", dict))
  let err = PdfError::Msg("boom")
  assert_integer(lookup_exception(err, pdf, "/A", dict), 1)
  assert_is_err(try? lookup_exception(err, pdf, "/B", dict))
  let dict_indirect = PdfObject::Dictionary([("/A", PdfObject::Indirect(5))])
  assert_eq(find_indirect("/A", dict_indirect), Some(5))
  let dict_non_indirect = PdfObject::Dictionary([("/A", PdfObject::Integer(7))])
  assert_eq(find_indirect("/A", dict_non_indirect), None)
  assert_is_err(try? find_indirect("/A", PdfObject::Integer(1)))
  let catalog_pdf = make_basic_pdf()
  match catalog_of_pdf(catalog_pdf) {
    PdfObject::Dictionary(_) => ()
    _ => fail("expected catalog")
  }
  let missing = empty()
  assert_is_err(try? catalog_of_pdf(missing))
}

///|
test "recurse and iterators" {
  let pdf = empty()
  addobj_given_num(pdf, (2, PdfObject::Integer(2)))
  addobj_given_num(pdf, (1, PdfObject::Integer(1)))
  match
    recurse_array(
      obj => match obj {
        PdfObject::Integer(v) => PdfObject::Integer(v + 1)
        _ => obj
      },
      [PdfObject::Integer(1), PdfObject::Integer(2)],
    ) {
    PdfObject::Array(values) => assert_eq(values.length(), 2)
    _ => fail("expected array")
  }
  match
    recurse_dict(
      obj => match obj {
        PdfObject::Integer(v) => PdfObject::Integer(v + 1)
        _ => obj
      },
      [("/A", PdfObject::Integer(1))],
    ) {
    PdfObject::Dictionary(entries) => assert_eq(entries.length(), 1)
    _ => fail("expected dictionary")
  }
  let seen = Ref::new(([] : Array[Int]))
  objiter((num, _obj) => seen.val.push(num), pdf)
  assert_eq(seen.val, [1, 2])
  let seen_gen = Ref::new(([] : Array[(Int, Int)]))
  objiter_gen((num, gen, _obj) => seen_gen.val.push((num, gen)), pdf)
  assert_eq(seen_gen.val, [(1, 0), (2, 0)])
  let seen_inorder = Ref::new(([] : Array[Int]))
  objiter_inorder((num, _obj) => seen_inorder.val.push(num), pdf)
  assert_eq(seen_inorder.val, [1, 2])
  pdf.objects.objects.set(
    3,
    ({ val: ObjectData::ParsedAlreadyDecrypted(PdfObject::Integer(5)) }, 0),
  )
  objselfmap(
    obj => match obj {
      PdfObject::Integer(v) => PdfObject::Integer(v + 1)
      _ => obj
    },
    pdf,
  )
  assert_integer(lookup_obj(pdf, 3), 6)
  let stream = make_stream(
    PdfObject::Dictionary([]),
    @pdfio.bytes_of_string("x"),
  )
  addobj_given_num(pdf, (4, stream))
  let stream_count = Ref::new(0)
  iter_stream(_obj => stream_count.val = stream_count.val + 1, pdf)
  assert_eq(stream_count.val, 1)
  let selected = objselect(
    obj => match obj {
      PdfObject::Integer(_) => true
      _ => false
    },
    pdf,
  )
  assert_true(selected.contains(1))
}

///|
test "references and renumbering" {
  let pdf = make_basic_pdf()
  addobj_given_num(pdf, (4, PdfObject::Integer(99)))
  let referenced = objects_referenced([], [], pdf, PdfObject::Indirect(2))
  assert_true(referenced.contains(2))
  remove_unreferenced(pdf)
  let nums = objnumbers(pdf)
  assert_true(!nums.contains(4))
  let pages = page_reference_numbers(pdf)
  assert_eq(pages, [2])
  let table = changes(pdf)
  assert_eq(table.get(2), Some(2))
  let renum_table : Map[Int, Int] = Map::new()
  renum_table.set(1, 10)
  renum_table.set(2, 11)
  renum_table.set(3, 12)
  let renumbered = renumber(renum_table, pdf)
  assert_eq(renumbered.root, 12)
  assert_eq(objnumbers(renumbered), [10, 11, 12])
  let pdfs = renumber_pdfs([make_basic_pdf(), make_basic_pdf()])
  let first_nums = objnumbers(pdfs[0])
  let second_nums = objnumbers(pdfs[1])
  assert_true(first_nums.length() > 0)
  assert_true(second_nums.length() > 0)
  assert_true(first_nums.last().unwrap() < second_nums[0])
  let copied = deep_copy(pdf)
  pdf.trailerdict = PdfObject::Dictionary([])
  match copied.trailerdict {
    PdfObject::Dictionary(entries) => assert_true(entries.length() > 0)
    _ => fail("expected dictionary")
  }
  match generate_id(pdf, "path", () => 1.0) {
    PdfObject::Array(values) => {
      assert_eq(values.length(), 2)
      match (values[0], values[1]) {
        (PdfObject::String(a), PdfObject::String(b)) => assert_eq(a, b)
        _ => fail("expected id strings")
      }
    }
    _ => fail("expected id array")
  }
  change_id(pdf, "path-")
  match lookup_immediate("/ID", pdf.trailerdict) {
    Some(PdfObject::Array(values)) => assert_eq(values.length(), 2)
    _ => fail("expected id entry")
  }
  let bad = empty()
  bad.trailerdict = PdfObject::Integer(1)
  assert_is_err(try? change_id(bad, "path-"))
}
