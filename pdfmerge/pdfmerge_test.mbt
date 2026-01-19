///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
fn count_streams(pdf : @pdf.Pdf) -> Int {
  let mut count = 0
  @pdf.objiter(
    (_, obj) => match obj {
      @pdf.PdfObject::Stream(_) => count = count + 1
      _ => ()
    },
    pdf,
  )
  count
}

///|
fn set_catalog_entry(
  pdf : @pdf.Pdf,
  key : String,
  value : @pdf.PdfObject,
) -> Unit raise {
  let catalog = @pdf.catalog_of_pdf(pdf)
  let updated = @pdf.add_dict_entry(catalog, key, value)
  @pdf.addobj_given_num(pdf, (pdf.root, updated))
}

///|
fn add_dest_name_tree(pdf : @pdf.Pdf, name : String) -> Unit raise {
  let child = @pdf.PdfObject::Dictionary([
    (
      "/Names",
      @pdf.PdfObject::Array([@pdf.PdfObject::String(name), @pdf.PdfObject::Null]),
    ),
    (
      "/Limits",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::String(name),
        @pdf.PdfObject::String(name),
      ]),
    ),
  ])
  let child_num = @pdf.addobj(pdf, child)
  let root_tree = @pdf.PdfObject::Dictionary([
    (
      "/Names",
      @pdf.PdfObject::Array([@pdf.PdfObject::String(name), @pdf.PdfObject::Null]),
    ),
    (
      "/Limits",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::String(name),
        @pdf.PdfObject::String(name),
      ]),
    ),
    ("/Kids", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(child_num)])),
  ])
  set_catalog_entry(
    pdf,
    "/Names",
    @pdf.PdfObject::Dictionary([("/Dests", root_tree)]),
  )
}

///|
fn add_dest_callsites(pdf : @pdf.Pdf, name : String) -> Unit {
  let dest_obj = @pdf.PdfObject::Dictionary([
    ("/Dest", @pdf.PdfObject::String(name)),
  ])
  ignore(@pdf.addobj(pdf, dest_obj))
  let action_obj = @pdf.PdfObject::Dictionary([
    ("/S", @pdf.PdfObject::Name("/GoTo")),
    ("/D", @pdf.PdfObject::String(name)),
  ])
  ignore(@pdf.addobj(pdf, action_obj))
}

///|
fn lookup_entry(
  entries : Array[(String, @pdf.PdfObject)],
  key : String,
) -> @pdf.PdfObject? {
  for entry in entries {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn collect_dest_strings(pdf : @pdf.Pdf) -> Array[String] {
  let out = Array::new()
  @pdf.objiter(
    (_, obj) => match obj {
      @pdf.PdfObject::Dictionary(entries) => {
        match lookup_entry(entries, "/Dest") {
          Some(@pdf.PdfObject::String(s)) => out.push(s)
          _ => ()
        }
        match lookup_entry(entries, "/S") {
          Some(@pdf.PdfObject::Name("/GoTo")) =>
            match lookup_entry(entries, "/D") {
              Some(@pdf.PdfObject::String(s)) => out.push(s)
              _ => ()
            }
          _ => ()
        }
      }
      _ => ()
    },
    pdf,
  )
  out
}

///|
fn read_dest_names(pdf : @pdf.Pdf) -> Array[String] raise {
  let catalog = @pdf.catalog_of_pdf(pdf)
  let names_dict = match @pdf.lookup_direct(pdf, "/Names", catalog) {
    Some(obj) => obj
    None => fail("missing /Names")
  }
  let dest_tree = match @pdf.lookup_direct(pdf, "/Dests", names_dict) {
    Some(obj) => obj
    None => fail("missing /Dests tree")
  }
  @pdftree.read_name_tree(pdf, dest_tree).map(pair => pair.0)
}

///|

///|
test "merge_pdfs combines pages" {
  let pdf1 = @pdfpage.minimum_valid_pdf()
  let pdf2 = @pdfpage.minimum_valid_pdf()
  let merged = merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
    ["one", "two"],
    [pdf1, pdf2],
    [[1], [1]],
  )
  assert_eq(@pdfpage.pages_of_pagetree_quick(merged), 2)
  remove_duplicate_fonts(merged)
}

///|
test "merge_pdfs rejects out of range" {
  let pdf = @pdfpage.minimum_valid_pdf()
  assert_is_err(
    try? merge_pdfs(
      false,
      false,
      process_struct_trees=false,
      add_toplevel_document=false,
      ["one"],
      [pdf],
      [[2]],
    ),
  )
}

///|
test "merge_pdfs retain numbering toggles path" {
  let pdf1 = @pdfpage.minimum_valid_pdf()
  let pdf2 = @pdfpage.minimum_valid_pdf()
  let merged = merge_pdfs(
    true,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
    ["one", "two"],
    [pdf1, pdf2],
    [[1], [1]],
  )
  assert_eq(@pdfpage.pages_of_pagetree_quick(merged), 2)
}

///|
test "remove_duplicate_fonts merges identical streams" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(2)),
  ])
  let data1 : Array[Byte] = [0x01, 0x02]
  let data2 : Array[Byte] = [0x01, 0x02]
  let stream1 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got(data1))),
  )
  let stream2 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got(data2))),
  )
  ignore(@pdf.addobj(pdf, stream1))
  ignore(@pdf.addobj(pdf, stream2))
  let before = count_streams(pdf)
  remove_duplicate_fonts(pdf)
  let after = count_streams(pdf)
  assert_eq(before, 2)
  assert_eq(after, 1)
}

///|
test "remove_duplicate_fonts keeps distinct streams" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(1)),
  ])
  let dict_alt = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(1)),
    ("/Subtype", @pdf.PdfObject::Name("/XObject")),
  ])
  let stream1 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got([0x01]))),
  )
  let stream2 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got([0x01, 0x02]))),
  )
  let stream3 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got([0x02]))),
  )
  let stream4 = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got([0x01]))),
  )
  let stream5 = @pdf.PdfObject::Stream(
    Ref::new((dict_alt, @pdf.Stream::Got([0x01]))),
  )
  ignore(@pdf.addobj(pdf, stream1))
  ignore(@pdf.addobj(pdf, stream2))
  ignore(@pdf.addobj(pdf, stream3))
  ignore(@pdf.addobj(pdf, stream4))
  ignore(@pdf.addobj(pdf, stream5))
  remove_duplicate_fonts(pdf)
  assert_eq(count_streams(pdf), 4)
}

///|

///|
test "merge_pdfs processes structure trees" {
  let pdf1 = @pdfpage.minimum_valid_pdf()
  let pdf2 = @pdfpage.minimum_valid_pdf()
  let merged = merge_pdfs(
    false,
    false,
    process_struct_trees=true,
    add_toplevel_document=true,
    ["one", "two"],
    [pdf1, pdf2],
    [[1], [1]],
  )
  assert_eq(@pdfpage.pages_of_pagetree_quick(merged), 2)
}

///|
test "merge_pdfs rejects length mismatch" {
  let pdf1 = @pdfpage.minimum_valid_pdf()
  let pdf2 = @pdfpage.minimum_valid_pdf()
  let result : Result[@pdf.Pdf, Error] = try? merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
    ["one"],
    [pdf1, pdf2],
    [[1], [1]],
  )
  assert_true(result is Err(_))
}

///|
test "merge_pdfs renames destination names and callsites" {
  let pdf1 = @pdfpage.minimum_valid_pdf()
  let pdf2 = @pdfpage.minimum_valid_pdf()
  add_dest_name_tree(pdf1, "dest")
  add_dest_name_tree(pdf2, "dest")
  add_dest_callsites(pdf1, "dest")
  add_dest_callsites(pdf2, "dest")
  let merged = merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
    ["one", "two"],
    [pdf1, pdf2],
    [[1], [1]],
  )
  let dest_names = read_dest_names(merged)
  assert_true(dest_names.contains("dest-f0"))
  assert_true(dest_names.contains("dest-f1"))
  let dest_strings = collect_dest_strings(merged)
  assert_true(!dest_strings.contains("dest"))
  assert_true(dest_strings.contains("dest-f0"))
  assert_true(dest_strings.contains("dest-f1"))
}

///|
test "merge_pdfs merges dests ocg and acroform" {
  let pdf1 = @pdfpage.minimum_valid_pdf()
  let pdf2 = @pdfpage.minimum_valid_pdf()
  set_catalog_entry(
    pdf1,
    "/Dests",
    @pdf.PdfObject::Dictionary([("/A", @pdf.PdfObject::Null)]),
  )
  set_catalog_entry(
    pdf2,
    "/Dests",
    @pdf.PdfObject::Dictionary([("/B", @pdf.PdfObject::Null)]),
  )
  set_catalog_entry(
    pdf1,
    "/OCProperties",
    @pdf.PdfObject::Dictionary([
      ("/OCGs", @pdf.PdfObject::Array([@pdf.PdfObject::Name("/OCG1")])),
      (
        "/D",
        @pdf.PdfObject::Dictionary([
          ("/ON", @pdf.PdfObject::Array([@pdf.PdfObject::Name("/OCG1")])),
          ("/Name", @pdf.PdfObject::String("Layer1")),
        ]),
      ),
    ]),
  )
  set_catalog_entry(
    pdf2,
    "/OCProperties",
    @pdf.PdfObject::Dictionary([
      ("/OCGs", @pdf.PdfObject::Array([@pdf.PdfObject::Name("/OCG2")])),
      (
        "/D",
        @pdf.PdfObject::Dictionary([
          ("/OFF", @pdf.PdfObject::Array([@pdf.PdfObject::Name("/OCG2")])),
          ("/BaseState", @pdf.PdfObject::Name("/OFF")),
        ]),
      ),
      (
        "/Configs",
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Dictionary([("/Name", @pdf.PdfObject::String("Cfg"))]),
        ]),
      ),
    ]),
  )
  set_catalog_entry(
    pdf1,
    "/AcroForm",
    @pdf.PdfObject::Dictionary([
      ("/Fields", @pdf.PdfObject::Array([@pdf.PdfObject::Null])),
      ("/NeedAppearances", @pdf.PdfObject::Boolean(true)),
    ]),
  )
  set_catalog_entry(
    pdf2,
    "/AcroForm",
    @pdf.PdfObject::Dictionary([
      ("/Fields", @pdf.PdfObject::Array([@pdf.PdfObject::Null])),
      ("/SigFlags", @pdf.PdfObject::Integer(1)),
    ]),
  )
  let merged = merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
    ["one", "two"],
    [pdf1, pdf2],
    [[1], [1]],
  )
  let catalog = @pdf.catalog_of_pdf(merged)
  match @pdf.lookup_direct(merged, "/Dests", catalog) {
    Some(@pdf.PdfObject::Dictionary(entries)) => {
      assert_true(lookup_entry(entries, "/A") is Some(_))
      assert_true(lookup_entry(entries, "/B") is Some(_))
    }
    _ => fail("expected /Dests dictionary")
  }
  match @pdf.lookup_direct(merged, "/OCProperties", catalog) {
    Some(ocp) =>
      match @pdf.lookup_direct(merged, "/OCGs", ocp) {
        Some(@pdf.PdfObject::Array(arr)) => assert_eq(arr.length(), 2)
        _ => fail("expected /OCGs array")
      }
    _ => fail("expected /OCProperties")
  }
  match @pdf.lookup_direct(merged, "/AcroForm", catalog) {
    Some(form) =>
      match @pdf.lookup_direct(merged, "/Fields", form) {
        Some(@pdf.PdfObject::Array(arr)) => assert_eq(arr.length(), 2)
        _ => fail("expected /Fields array")
      }
    _ => fail("expected /AcroForm")
  }
}
