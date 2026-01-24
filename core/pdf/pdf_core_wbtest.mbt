///|
test "toget and predicates" {
  assert_true(is_whitespace(' '))
  assert_true(is_whitespace('\n'))
  assert_true(!is_whitespace('A'))
  let input = @pdfio.input_of_string("abc", source="test")
  let t = ToGet::new(input, 1, 2)
  assert_eq(ToGet::length(t), 2)
}

///|
test "objmap basics" {
  let map0 = pdfobjmap_empty()
  assert_eq(pdfobjmap_bindings(map0).length(), 0)
  // Basic map operations are tested via the Pdf structure
  let pdf = Pdf::empty()
  addobj_given_num(pdf, (1, PdfObject::Null))
  addobj_given_num(pdf, (2, PdfObject::Integer(42)))
  assert_eq(objnumbers(pdf).length(), 2)
}

///|
fn make_stream(dict : PdfObject, data : @pdfio.MutableBytes) -> PdfObject {
  PdfObject::Stream(Ref::new((dict, Stream::Got(data))))
}

///|
fn assert_integer(obj : PdfObject, expected : Int) -> Unit raise {
  match obj {
    PdfObject::Integer(value) => assert_eq(value, expected)
    _ => fail("expected integer")
  }
}

///|
fn assert_some_integer(obj : PdfObject?, expected : Int) -> Unit raise {
  match obj {
    Some(PdfObject::Integer(value)) => assert_eq(value, expected)
    Some(_) => fail("expected integer")
    None => fail("expected some")
  }
}

///|
test "dictionary helpers" {
  let dict = PdfObject::Dictionary([
    ("/A", PdfObject::Integer(1)),
    ("/B", PdfObject::Integer(2)),
  ])
  match remove_dict_entry(dict, "/A") {
    PdfObject::Dictionary(entries) => assert_eq(entries.length(), 1)
    _ => fail("expected dictionary")
  }
  let data = @pdfio.bytes_of_string("hi")
  let stream_dict = PdfObject::Dictionary([
    ("/Length", PdfObject::Integer(2)),
    ("/A", PdfObject::Integer(1)),
  ])
  let stream_obj = make_stream(stream_dict, data)
  match remove_dict_entry(stream_obj, "/A") {
    PdfObject::Stream(r) =>
      match r.val {
        (PdfObject::Dictionary(entries), _) =>
          assert_true(entries.search_by(pair => pair.0 == "/A") is None)
        _ => fail("expected stream dictionary")
      }
    _ => fail("expected stream")
  }
  assert_is_err(try? remove_dict_entry(PdfObject::Integer(1), "/A"))
  match replace_dict_entry(PdfObject::Null, "/A", PdfObject::Integer(1)) {
    PdfObject::Dictionary(entries) => assert_eq(entries.length(), 1)
    _ => fail("expected dictionary from null")
  }
  assert_is_err(
    try? replace_dict_entry(
      PdfObject::Dictionary([("/B", PdfObject::Integer(2))]),
      "/A",
      PdfObject::Integer(1),
    ),
  )
  let stream_obj2 = make_stream(
    PdfObject::Dictionary([("/A", PdfObject::Integer(1))]),
    data,
  )
  match replace_dict_entry(stream_obj2, "/A", PdfObject::Integer(9)) {
    PdfObject::Stream(r) =>
      match r.val {
        (PdfObject::Dictionary(entries), _) =>
          match entries.search_by(pair => pair.0 == "/A") {
            Some(i) => assert_integer(entries[i].1, 9)
            None => fail("expected replaced key")
          }
        _ => fail("expected stream dictionary")
      }
    _ => fail("expected stream")
  }
  assert_is_err(
    try? replace_dict_entry(PdfObject::Integer(1), "/A", PdfObject::Integer(2)),
  )
  match add_dict_entry(PdfObject::Null, "/A", PdfObject::Integer(1)) {
    PdfObject::Dictionary(entries) => assert_eq(entries.length(), 1)
    _ => fail("expected dictionary from null")
  }
  match
    add_dict_entry(
      PdfObject::Dictionary([("/A", PdfObject::Integer(1))]),
      "/A",
      PdfObject::Integer(2),
    ) {
    PdfObject::Dictionary(entries) =>
      match entries.search_by(pair => pair.0 == "/A") {
        Some(i) => assert_integer(entries[i].1, 2)
        None => fail("expected updated key")
      }
    _ => fail("expected dictionary")
  }
  let stream_obj3 = make_stream(
    PdfObject::Dictionary([("/A", PdfObject::Integer(1))]),
    data,
  )
  match add_dict_entry(stream_obj3, "/B", PdfObject::Integer(3)) {
    PdfObject::Stream(r) =>
      match r.val {
        (PdfObject::Dictionary(entries), _) =>
          assert_true(entries.search_by(pair => pair.0 == "/B") is Some(_))
        _ => fail("expected stream dictionary")
      }
    _ => fail("expected stream")
  }
  assert_is_err(
    try? add_dict_entry(PdfObject::Integer(1), "/A", PdfObject::Integer(2)),
  )
}

///|
test "lookup and chains" {
  let pdf = Pdf::empty()
  addobj_given_num(pdf, (1, PdfObject::Integer(99)))
  addobj_given_num(
    pdf,
    (
      2,
      PdfObject::Dictionary([
        ("/A", PdfObject::Indirect(1)),
        ("/B", PdfObject::Integer(5)),
      ]),
    ),
  )
  assert_integer(lookup_obj(pdf, 1), 99)
  assert_integer(direct(pdf, PdfObject::Indirect(1)), 99)
  assert_some_integer(
    lookup_direct(
      pdf,
      "/A",
      PdfObject::Dictionary([("/A", PdfObject::Indirect(1))]),
    ),
    99,
  )
  match
    lookup_immediate(
      "/A",
      PdfObject::Dictionary([("/A", PdfObject::Indirect(1))]),
    ) {
    Some(PdfObject::Indirect(1)) => ()
    _ => fail("expected indirect")
  }
  let data = @pdfio.bytes_of_string("ok")
  let stream_obj = make_stream(
    PdfObject::Dictionary([("/A", PdfObject::Integer(7))]),
    data,
  )
  assert_some_integer(lookup_direct(pdf, "/A", stream_obj), 7)
  assert_some_integer(lookup_immediate("/A", stream_obj), 7)
  match lookup_immediate("/Missing", stream_obj) {
    None => ()
    _ => fail("expected none")
  }
  match lookup_direct(pdf, "/A", PdfObject::Integer(1)) {
    None => ()
    _ => fail("expected none")
  }
  let bad_stream = make_stream(PdfObject::Integer(1), data)
  match lookup_direct(pdf, "/A", bad_stream) {
    None => ()
    _ => fail("expected none")
  }
  match lookup_immediate("/A", bad_stream) {
    None => ()
    _ => fail("expected none")
  }
  match lookup_immediate("/A", PdfObject::Integer(1)) {
    None => ()
    _ => fail("expected none")
  }
  let arr_dict = PdfObject::Dictionary([
    ("/Arr", PdfObject::Array([PdfObject::Integer(1), PdfObject::Integer(2)])),
  ])
  assert_some_integer(lookup_chain(pdf, arr_dict, ["/Arr", "/[1]"][:]), 2)
  match lookup_chain(pdf, arr_dict, ["/[x]"][:]) {
    None => ()
    _ => fail("expected none")
  }
  match lookup_chain(pdf, PdfObject::Integer(1), ["/[0]"][:]) {
    None => ()
    _ => fail("expected none")
  }
  let pdf2 = Pdf::empty()
  pdf2.trailerdict = PdfObject::Dictionary([
    ("/A", PdfObject::Array([PdfObject::Integer(1), PdfObject::Integer(2)])),
  ])
  replace_chain(pdf2, ["/A", "/[1]"][:], PdfObject::Integer(9))
  assert_some_integer(
    lookup_chain(pdf2, pdf2.trailerdict, ["/A", "/[1]"][:]),
    9,
  )
  assert_is_err(
    try? replace_chain(pdf2, ["/A", "/[5]"][:], PdfObject::Integer(3)),
  )
  assert_is_err(
    try? replace_chain(pdf2, ["/A", "/[0]", "/B"][:], PdfObject::Integer(3)),
  )
  assert_is_err(try? replace_chain(pdf2, ["/[0]"][:], PdfObject::Integer(1)))
  let dict_chain = ["/X", "/Y"]
  replace_chain(pdf2, dict_chain[:], PdfObject::Integer(7))
  assert_some_integer(lookup_chain(pdf2, pdf2.trailerdict, dict_chain[:]), 7)
  let pdf_null = Pdf::empty()
  pdf_null.trailerdict = PdfObject::Null
  replace_chain(pdf_null, ["/A", "/B"][:], PdfObject::Integer(1))
  assert_some_integer(
    lookup_chain(pdf_null, pdf_null.trailerdict, ["/A", "/B"][:]),
    1,
  )
  let pdf_stream_replace = Pdf::empty()
  pdf_stream_replace.trailerdict = make_stream(
    PdfObject::Dictionary([("/A", PdfObject::Integer(1))]),
    data,
  )
  replace_chain(pdf_stream_replace, ["/A"][:], PdfObject::Integer(2))
  match pdf_stream_replace.trailerdict {
    PdfObject::Stream(r) =>
      match r.val {
        (PdfObject::Dictionary(entries), _) =>
          match entries.search_by(pair => pair.0 == "/A") {
            Some(i) => assert_integer(entries[i].1, 2)
            None => fail("expected updated /A")
          }
        _ => fail("expected stream dictionary")
      }
    _ => fail("expected stream")
  }
  let dict_indirect = PdfObject::Dictionary([("/A", PdfObject::Indirect(1))])
  assert_eq(indirect_number(pdf, "/A", dict_indirect), Some(1))
  assert_eq(indirect_number(pdf, "/B", dict_indirect), None)
  let dict_direct = PdfObject::Dictionary([("/A", PdfObject::Integer(2))])
  assert_eq(indirect_number(pdf, "/A", dict_direct), None)
  let stream_indirect = make_stream(dict_indirect, data)
  assert_eq(indirect_number(pdf, "/A", stream_indirect), Some(1))
  assert_eq(indirect_number(pdf, "/A", PdfObject::Integer(1)), None)
  let dict_alt = PdfObject::Dictionary([("/Alt", PdfObject::Integer(3))])
  assert_some_integer(
    lookup_direct_orelse(pdf, "/Missing", "/Alt", dict_alt),
    3,
  )
  let pdf_parse = Pdf::empty()
  pdf_parse.objects.objects.set(10, (Ref::new(ObjectData::ToParse), 0))
  match lookup_obj(pdf_parse, 10) {
    PdfObject::Null => ()
    _ => fail("expected null")
  }
  let map_none : Map[Int, Array[Int]] = Map::new()
  let ref_none = Ref::new(
    ObjectData::ToParseFromObjectStream(map_none, 5, 0, (_stream, _idx) => []),
  )
  pdf_parse.objects.objects.set(11, (ref_none, 0))
  match lookup_obj(pdf_parse, 11) {
    PdfObject::Null => ()
    _ => fail("expected null")
  }
  let map_missing : Map[Int, Array[Int]] = Map::new()
  map_missing.set(12, [0])
  let ref_missing = Ref::new(
    ObjectData::ToParseFromObjectStream(map_missing, 6, 0, (_stream, _idx) => [
      (13, (Ref::new(ObjectData::Parsed(PdfObject::Integer(7))), 0)),
    ]),
  )
  pdf_parse.objects.objects.set(12, (ref_missing, 0))
  match lookup_obj(pdf_parse, 12) {
    PdfObject::Null => ()
    _ => fail("expected null")
  }
  let map_found : Map[Int, Array[Int]] = Map::new()
  map_found.set(14, [0])
  let ref_found = Ref::new(
    ObjectData::ToParseFromObjectStream(map_found, 7, 0, (_stream, _idx) => [
      (14, (Ref::new(ObjectData::Parsed(PdfObject::Integer(8))), 0)),
    ]),
  )
  pdf_parse.objects.objects.set(14, (ref_found, 0))
  assert_integer(lookup_obj(pdf_parse, 14), 8)
}
