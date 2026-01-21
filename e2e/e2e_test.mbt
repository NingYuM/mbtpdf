///|
const OUTPUT_DIR : String = "tmp/e2e"

///|
const MERGE_LEFT_PATH : String = "testdata/e2e/merge_dummy.pdf"

///|
const MERGE_RIGHT_PATH : String = "testdata/pdfjs_identity_tounicode.pdf"

///|
const MERGE_THIRD_PATH : String = "testdata/e2e/pdfjs_tracemonkey.pdf"

///|
const LARGE_PATH : String = "testdata/SFAA_Japanese.pdf"

///|
const BOOKMARK_PATH : String = "testdata/SFAA_Japanese.pdf"

///|
async fn assert_fixture(path : String) -> Unit {
  if !@fs.exists(path) {
    fail("missing fixture: " + path)
  }
}

///|
async fn ensure_dir(path : String) -> Unit {
  if !@fs.exists(path) {
    @fs.mkdir(path, permission=0o755, recursive=true)
  }
}

///|
async fn read_pdf(path : String) -> @pdf.Pdf {
  assert_fixture(path)
  @pdfread.pdf_of_file(None, None, path)
}

///|
async fn write_pdf(path : String, pdf : @pdf.Pdf) -> Unit {
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  @pdfwrite.pdf_to_channel(None, true, pdf, file)
}

///|
fn page_count(pdf : @pdf.Pdf) -> Int raise {
  @pdfpage.pages_of_pagetree_quick(pdf)
}

///|
fn full_range(count : Int) -> Array[Int] {
  let out = Array::new(capacity=count)
  for i in 1..<=count {
    out.push(i)
  }
  out
}

///|
fn assert_merged_label_prefixes(
  labels : Array[@pdfpagelabels.PageLabel],
  left_count : Int,
) -> Unit raise {
  let mut found_left = false
  let mut found_right = false
  for label in labels {
    match label.labelprefix {
      Some("L-") => {
        found_left = true
        assert_eq(label.startpage, 1)
      }
      Some("R-") => {
        found_right = true
        assert_eq(label.startpage, left_count + 1)
      }
      _ => ()
    }
  }
  let rendered = labels
    .map(label => @pdfpagelabels.string_of_pagelabel(label))
    .join(", ")
  if !found_left {
    fail("missing L- label: " + rendered)
  }
  if !found_right {
    fail("missing R- label: " + rendered)
  }
}

///|
fn add_named_destination(
  pdf : @pdf.Pdf,
  name : String,
  page_obj : Int,
) -> Unit raise {
  let dest = @pdfdest.Destination::Fit(
    @pdfdest.TargetPage::PageObject(page_obj),
  )
  let tree = @pdftree.build_name_tree(false, pdf, [
    (name, @pdfdest.pdfobject_of_destination(dest)),
  ])
  let tree_num = @pdf.addobj(pdf, tree)
  let rootnum = pdf.root
  let root = @pdf.lookup_obj(pdf, rootnum)
  let names = match @pdf.lookup_direct(pdf, "/Names", root) {
    Some(obj) => obj
    None => @pdf.PdfObject::Dictionary([])
  }
  let names = @pdf.add_dict_entry(
    names,
    "/Dests",
    @pdf.PdfObject::Indirect(tree_num),
  )
  let updated_root = @pdf.add_dict_entry(root, "/Names", names)
  @pdf.addobj_given_num(pdf, (rootnum, updated_root))
  pdf.trailerdict = @pdf.add_dict_entry(
    pdf.trailerdict,
    "/Root",
    @pdf.PdfObject::Indirect(rootnum),
  )
}

///|
fn add_dests_dictionary(
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)],
) -> Unit raise {
  set_catalog_entry(pdf, "/Dests", @pdf.PdfObject::Dictionary(entries))
}

///|
fn set_catalog_entry(
  pdf : @pdf.Pdf,
  key : String,
  value : @pdf.PdfObject,
) -> Unit raise {
  let rootnum = pdf.root
  let root = @pdf.lookup_obj(pdf, rootnum)
  let updated_root = @pdf.add_dict_entry(root, key, value)
  @pdf.addobj_given_num(pdf, (rootnum, updated_root))
  pdf.trailerdict = @pdf.add_dict_entry(
    pdf.trailerdict,
    "/Root",
    @pdf.PdfObject::Indirect(rootnum),
  )
}

///|
fn add_names_tree(
  pdf : @pdf.Pdf,
  key : String,
  entries : Array[(String, @pdf.PdfObject)],
) -> Unit raise {
  let tree = @pdftree.build_name_tree(false, pdf, entries)
  let tree_num = @pdf.addobj(pdf, tree)
  let rootnum = pdf.root
  let root = @pdf.lookup_obj(pdf, rootnum)
  let names = match @pdf.lookup_direct(pdf, "/Names", root) {
    Some(obj) => obj
    None => @pdf.PdfObject::Dictionary([])
  }
  let names = @pdf.add_dict_entry(
    names,
    key,
    @pdf.PdfObject::Indirect(tree_num),
  )
  let updated_root = @pdf.add_dict_entry(root, "/Names", names)
  @pdf.addobj_given_num(pdf, (rootnum, updated_root))
  pdf.trailerdict = @pdf.add_dict_entry(
    pdf.trailerdict,
    "/Root",
    @pdf.PdfObject::Indirect(rootnum),
  )
}

///|
fn add_embedded_file(
  pdf : @pdf.Pdf,
  entry_name : String,
  filename : String,
  payload : String,
) -> Unit raise {
  let bytes = @pdfio.bytes_of_string(payload)
  let stream_dict = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/EmbeddedFile")),
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(bytes))),
  ])
  let stream_obj = @pdf.PdfObject::Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(bytes))),
  )
  let stream_num = @pdf.addobj(pdf, stream_obj)
  let filespec = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Filespec")),
    ("/F", @pdf.PdfObject::String(filename)),
    ("/UF", @pdf.PdfObject::String(filename)),
    (
      "/EF",
      @pdf.PdfObject::Dictionary([("/F", @pdf.PdfObject::Indirect(stream_num))]),
    ),
  ])
  add_names_tree(pdf, "/EmbeddedFiles", [(entry_name, filespec)])
}

///|
fn read_name_tree_entries(
  pdf : @pdf.Pdf,
  key : String,
) -> Array[(String, @pdf.PdfObject)] raise {
  let catalog = @pdf.catalog_of_pdf(pdf)
  let names = match @pdf.lookup_direct(pdf, "/Names", catalog) {
    Some(obj) => obj
    None => fail("missing /Names dictionary")
  }
  let tree = match @pdf.lookup_direct(pdf, key, names) {
    Some(obj) => obj
    None => fail("missing name tree: " + key)
  }
  @pdftree.read_name_tree(pdf, tree)
}

///|
fn read_named_destination(
  pdf : @pdf.Pdf,
  name : String,
) -> @pdfdest.Destination raise {
  let catalog = @pdf.catalog_of_pdf(pdf)
  let names = match @pdf.lookup_direct(pdf, "/Names", catalog) {
    Some(obj) => obj
    None => fail("missing /Names dictionary")
  }
  let dests = match @pdf.lookup_direct(pdf, "/Dests", names) {
    Some(obj) => obj
    None => fail("missing /Dests name tree")
  }
  let entries = @pdftree.read_name_tree(pdf, dests)
  match entries.search_by(pair => pair.0 == name) {
    Some(idx) => @pdfdest.read_destination(pdf, entries[idx].1)
    None => fail("missing destination: " + name)
  }
}

///|
fn assert_embedded_file_stream(
  pdf : @pdf.Pdf,
  stream_obj : @pdf.PdfObject,
  expected_payload : String,
) -> Unit raise {
  match @pdf.lookup_direct(pdf, "/Type", stream_obj) {
    Some(@pdf.PdfObject::Name("/EmbeddedFile")) => ()
    _ => fail("expected /Type /EmbeddedFile")
  }
  let bytes = @pdf.bigarray_of_stream(stream_obj)
  let payload = @pdfio.string_of_bytes(bytes)
  assert_eq(payload, expected_payload)
  match @pdf.lookup_direct(pdf, "/Length", stream_obj) {
    Some(@pdf.PdfObject::Integer(length)) =>
      assert_eq(length, @pdfio.bytes_size(bytes))
    _ => fail("expected /Length")
  }
}

///|
fn assert_embedded_file_spec(
  pdf : @pdf.Pdf,
  filespec_obj : @pdf.PdfObject,
  expected_filename : String,
  expected_payload : String,
) -> Unit raise {
  let spec = @pdf.direct(pdf, filespec_obj)
  match @pdf.lookup_direct(pdf, "/Type", spec) {
    Some(@pdf.PdfObject::Name("/Filespec")) => ()
    _ => fail("expected /Type /Filespec")
  }
  match @pdf.lookup_direct(pdf, "/F", spec) {
    Some(@pdf.PdfObject::String(name)) => assert_eq(name, expected_filename)
    _ => fail("expected /F filename")
  }
  let ef = match @pdf.lookup_direct(pdf, "/EF", spec) {
    Some(obj) => obj
    None => fail("missing /EF dictionary")
  }
  let stream_obj = match @pdf.lookup_direct(pdf, "/F", ef) {
    Some(obj) => obj
    None => fail("missing /EF /F")
  }
  assert_embedded_file_stream(pdf, stream_obj, expected_payload)
}

///|
fn assert_embedded_file_entry(
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)],
  name : String,
  filename : String,
  payload : String,
) -> Unit raise {
  match entries.search_by(pair => pair.0 == name) {
    Some(idx) =>
      assert_embedded_file_spec(pdf, entries[idx].1, filename, payload)
    None => fail("missing embedded file: " + name)
  }
}

///|
fn assert_destination_page(
  dest : @pdfdest.Destination,
  expected_obj : Int,
) -> Unit raise {
  match dest {
    @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(obj))
    | @pdfdest.Destination::FitH(@pdfdest.TargetPage::PageObject(obj), _)
    | @pdfdest.Destination::FitV(@pdfdest.TargetPage::PageObject(obj), _)
    | @pdfdest.Destination::FitR(
      @pdfdest.TargetPage::PageObject(obj),
      _,
      _,
      _,
      _
    )
    | @pdfdest.Destination::FitB(@pdfdest.TargetPage::PageObject(obj))
    | @pdfdest.Destination::FitBH(@pdfdest.TargetPage::PageObject(obj), _)
    | @pdfdest.Destination::FitBV(@pdfdest.TargetPage::PageObject(obj), _)
    | @pdfdest.Destination::XYZ(@pdfdest.TargetPage::PageObject(obj), _, _, _) =>
      assert_eq(obj, expected_obj)
    _ => fail("unexpected destination target")
  }
}

///|
async test "e2e merge writes and reads back" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let third = read_pdf(MERGE_THIRD_PATH)
  let left_count = page_count(left)
  let right_count = page_count(right)
  let third_count = page_count(third)
  assert_true(left_count > 0)
  assert_true(right_count > 0)
  assert_true(third_count > 0)
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["merge_left", "merge_right", "merge_third"],
    [left, right, third],
    [full_range(left_count), full_range(right_count), full_range(third_count)],
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  assert_eq(page_count(parsed), left_count + right_count + third_count)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge stress repeated" {
  let base = read_pdf(MERGE_LEFT_PATH)
  let count = page_count(base)
  assert_true(count > 0)
  let copies = 8
  let names = Array::new(capacity=copies)
  let pdfs = Array::new(capacity=copies)
  let ranges = Array::new(capacity=copies)
  for i in 0..<copies {
    names.push("stress_" + i.to_string())
    pdfs.push(read_pdf(MERGE_LEFT_PATH))
    ranges.push(full_range(count))
  }
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    names,
    pdfs,
    ranges,
  )
  assert_eq(page_count(merged), count * copies)
}

///|
async test "e2e merge preserves text extraction" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let left_count = page_count(left)
  let right_count = page_count(right)
  assert_true(left_count > 0)
  assert_true(right_count > 0)
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["merge_text_left", "merge_text_right"],
    [left, right],
    [full_range(left_count), full_range(right_count)],
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merge_text.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let extracted = @pdftext.extract_text(parsed)
  assert_true(extracted.contains("ABCdef"))
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e split subset of large pdf" {
  let pdf = read_pdf(LARGE_PATH)
  let count = page_count(pdf)
  assert_true(count > 10)
  let subset = [1, 2, count]
  let split = @pdfpage.pdf_of_pages(pdf, subset)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/split.pdf"
  write_pdf(out_path, split)
  let parsed = read_pdf(out_path)
  assert_eq(page_count(parsed), subset.length())
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e split then bookmark" {
  let pdf = read_pdf(LARGE_PATH)
  let count = page_count(pdf)
  assert_true(count >= 2)
  let subset = [1, 2]
  let split = @pdfpage.pdf_of_pages(pdf, subset)
  let page1 = match @pdfpage.page_object_number(split, 1) {
    Some(objnum) => objnum
    None => fail("missing split page 1")
  }
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Split bookmark",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(page1)),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let split_with = @pdfmarks.add_bookmarks(marks, split)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/split_bookmark.pdf"
  write_pdf(out_path, split_with)
  let parsed = read_pdf(out_path)
  let parsed_marks = @pdfmarks.read_bookmarks(parsed)
  assert_eq(parsed_marks.length(), 1)
  let target_page = @pdfpage.pagenumber_of_target(
    parsed,
    parsed_marks[0].target,
  )
  assert_eq(target_page, 1)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e annotation roundtrip" {
  let pdf = read_pdf(MERGE_LEFT_PATH)
  let pages = @pdfpage.pages_of_pagetree(pdf)
  assert_true(pages.length() > 0)
  let annot = @pdfannot.make(
    @pdfannot.Subtype::Text,
    content="E2E note",
    rectangle=(10.0, 20.0, 30.0, 40.0),
  )
  let updated_page = @pdfannot.add_annotation(pdf, pages[0], annot)
  pages[0] = updated_page
  let updated_pdf = @pdfpage.change_pages(true, pdf, pages)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/annotated.pdf"
  write_pdf(out_path, updated_pdf)
  let parsed = read_pdf(out_path)
  let parsed_pages = @pdfpage.pages_of_pagetree(parsed)
  let annots = @pdfannot.annotations_of_page(parsed, parsed_pages[0])
  assert_eq(annots.length(), 1)
  match annots[0].annot_contents {
    Some("E2E note") => ()
    _ => fail("expected annotation contents")
  }
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves annotations" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let left_pages = @pdfpage.pages_of_pagetree(left)
  assert_true(left_pages.length() > 0)
  let annot = @pdfannot.make(
    @pdfannot.Subtype::Text,
    content="Merged note",
    rectangle=(15.0, 25.0, 35.0, 45.0),
  )
  let updated_page = @pdfannot.add_annotation(left, left_pages[0], annot)
  left_pages[0] = updated_page
  let updated_left = @pdfpage.change_pages(true, left, left_pages)
  let left_count = page_count(updated_left)
  let right_count = page_count(right)
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["merge_annot_left", "merge_annot_right"],
    [updated_left, right],
    [full_range(left_count), full_range(right_count)],
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_annot.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_pages = @pdfpage.pages_of_pagetree(parsed)
  let annots = @pdfannot.annotations_of_page(parsed, parsed_pages[0])
  assert_eq(annots.length(), 1)
  match annots[0].annot_contents {
    Some("Merged note") => ()
    _ => fail("expected merged annotation contents")
  }
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves page labels" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let left_count = page_count(left)
  let right_count = page_count(right)
  assert_true(left_count > 0)
  assert_true(right_count > 0)
  let left_labels = [
    @pdfpagelabels.PageLabel::{
      labelstyle: @pdfpagelabels.LabelStyle::DecimalArabic,
      labelprefix: Some("L-"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  let right_labels = [
    @pdfpagelabels.PageLabel::{
      labelstyle: @pdfpagelabels.LabelStyle::DecimalArabic,
      labelprefix: Some("R-"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.write(left, left_labels)
  @pdfpagelabels.write(right, right_labels)
  let left_read = @pdfpagelabels.read(left)
  let right_read = @pdfpagelabels.read(right)
  match left_read {
    [label, ..] =>
      match label.labelprefix {
        Some("L-") => ()
        _ => fail("expected left label prefix")
      }
    _ => fail("missing left labels")
  }
  match right_read {
    [label, ..] =>
      match label.labelprefix {
        Some("R-") => ()
        _ => fail("expected right label prefix")
      }
    _ => fail("missing right labels")
  }
  let merged_labels = @pdfpagelabels.merge_pagelabels([left, right], [
    full_range(left_count),
    full_range(right_count),
  ])
  assert_merged_label_prefixes(merged_labels, left_count)
  let merged = @pdfmerge.merge_pdfs(
    true,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["merge_labels_left", "merge_labels_right"],
    [left, right],
    [full_range(left_count), full_range(right_count)],
  )
  let in_memory_labels = @pdfpagelabels.read(merged)
  assert_merged_label_prefixes(in_memory_labels, left_count)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_labels.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let labels = @pdfpagelabels.read(parsed)
  assert_merged_label_prefixes(labels, left_count)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves named destinations" {
  let left = @pdfpage.minimum_valid_pdf()
  let right = @pdfpage.minimum_valid_pdf()
  let left_count = page_count(left)
  let right_count = page_count(right)
  assert_eq(left_count, 1)
  assert_eq(right_count, 1)
  let left_page = match @pdfpage.page_object_number(left, 1) {
    Some(objnum) => objnum
    None => fail("missing left page")
  }
  let right_page = match @pdfpage.page_object_number(right, 1) {
    Some(objnum) => objnum
    None => fail("missing right page")
  }
  add_named_destination(left, "LeftDest", left_page)
  add_named_destination(right, "RightDest", right_page)
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["named_left", "named_right"],
    [left, right],
    [full_range(left_count), full_range(right_count)],
  )
  let merged_pages = @pdf.page_reference_numbers(merged)
  let left_expected = merged_pages[0]
  let right_expected = merged_pages[left_count]
  let left_dest = read_named_destination(merged, "LeftDest")
  let right_dest = read_named_destination(merged, "RightDest")
  assert_destination_page(left_dest, left_expected)
  assert_destination_page(right_dest, right_expected)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_named_dests.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_pages = @pdf.page_reference_numbers(parsed)
  let parsed_left = parsed_pages[0]
  let parsed_right = parsed_pages[left_count]
  let parsed_left_dest = read_named_destination(parsed, "LeftDest")
  let parsed_right_dest = read_named_destination(parsed, "RightDest")
  assert_destination_page(parsed_left_dest, parsed_left)
  assert_destination_page(parsed_right_dest, parsed_right)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /Dests dictionary" {
  let left = @pdfpage.minimum_valid_pdf()
  let right = @pdfpage.minimum_valid_pdf()
  let left_count = page_count(left)
  let right_count = page_count(right)
  assert_eq(left_count, 1)
  assert_eq(right_count, 1)
  let left_page = match @pdfpage.page_object_number(left, 1) {
    Some(objnum) => objnum
    None => fail("missing left page")
  }
  let right_page = match @pdfpage.page_object_number(right, 1) {
    Some(objnum) => objnum
    None => fail("missing right page")
  }
  let left_dest = @pdfdest.pdfobject_of_destination(
    @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(left_page)),
  )
  let right_dest = @pdfdest.pdfobject_of_destination(
    @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(right_page)),
  )
  add_dests_dictionary(left, [("/LeftDest", left_dest)])
  add_dests_dictionary(right, [("/RightDest", right_dest)])
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["dests_left", "dests_right"],
    [left, right],
    [full_range(left_count), full_range(right_count)],
  )
  let merged_pages = @pdf.page_reference_numbers(merged)
  let left_expected = merged_pages[0]
  let right_expected = merged_pages[left_count]
  let left_read = @pdfdest.read_destination(
    merged,
    @pdf.PdfObject::Name("/LeftDest"),
  )
  let right_read = @pdfdest.read_destination(
    merged,
    @pdf.PdfObject::Name("/RightDest"),
  )
  assert_destination_page(left_read, left_expected)
  assert_destination_page(right_read, right_expected)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_dests_dict.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_pages = @pdf.page_reference_numbers(parsed)
  let parsed_left = parsed_pages[0]
  let parsed_right = parsed_pages[left_count]
  let parsed_left_read = @pdfdest.read_destination(
    parsed,
    @pdf.PdfObject::Name("/LeftDest"),
  )
  let parsed_right_read = @pdfdest.read_destination(
    parsed,
    @pdf.PdfObject::Name("/RightDest"),
  )
  assert_destination_page(parsed_left_read, parsed_left)
  assert_destination_page(parsed_right_read, parsed_right)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves AcroForm entries" {
  let left = @pdfpage.minimum_valid_pdf()
  let right = @pdfpage.minimum_valid_pdf()
  let left_form = @pdf.PdfObject::Dictionary([
    ("/Fields", @pdf.PdfObject::Array([@pdf.PdfObject::Null])),
    ("/NeedAppearances", @pdf.PdfObject::Boolean(true)),
  ])
  let right_form = @pdf.PdfObject::Dictionary([
    ("/Fields", @pdf.PdfObject::Array([@pdf.PdfObject::Null])),
    ("/SigFlags", @pdf.PdfObject::Integer(1)),
  ])
  set_catalog_entry(left, "/AcroForm", left_form)
  set_catalog_entry(right, "/AcroForm", right_form)
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["acro_left", "acro_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  )
  let catalog = @pdf.catalog_of_pdf(merged)
  let form = match @pdf.lookup_direct(merged, "/AcroForm", catalog) {
    Some(obj) => obj
    None => fail("missing /AcroForm")
  }
  match @pdf.lookup_direct(merged, "/Fields", form) {
    Some(@pdf.PdfObject::Array(arr)) => assert_eq(arr.length(), 2)
    _ => fail("expected /Fields array")
  }
  match @pdf.lookup_direct(merged, "/NeedAppearances", form) {
    Some(@pdf.PdfObject::Boolean(true)) => ()
    _ => fail("expected /NeedAppearances true")
  }
  match @pdf.lookup_direct(merged, "/SigFlags", form) {
    Some(@pdf.PdfObject::Integer(1)) => ()
    _ => fail("expected /SigFlags 1")
  }
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_acroform.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_catalog = @pdf.catalog_of_pdf(parsed)
  let parsed_form = match
    @pdf.lookup_direct(parsed, "/AcroForm", parsed_catalog) {
    Some(obj) => obj
    None => fail("missing parsed /AcroForm")
  }
  match @pdf.lookup_direct(parsed, "/Fields", parsed_form) {
    Some(@pdf.PdfObject::Array(arr)) => assert_eq(arr.length(), 2)
    _ => fail("expected parsed /Fields array")
  }
  match @pdf.lookup_direct(parsed, "/NeedAppearances", parsed_form) {
    Some(@pdf.PdfObject::Boolean(true)) => ()
    _ => fail("expected parsed /NeedAppearances true")
  }
  match @pdf.lookup_direct(parsed, "/SigFlags", parsed_form) {
    Some(@pdf.PdfObject::Integer(1)) => ()
    _ => fail("expected parsed /SigFlags 1")
  }
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /Names JavaScript" {
  let left = @pdfpage.minimum_valid_pdf()
  let right = @pdfpage.minimum_valid_pdf()
  let left_action = @pdf.PdfObject::Dictionary([
    ("/S", @pdf.PdfObject::Name("/JavaScript")),
    ("/JS", @pdf.PdfObject::String("app.alert('left')")),
  ])
  let right_action = @pdf.PdfObject::Dictionary([
    ("/S", @pdf.PdfObject::Name("/JavaScript")),
    ("/JS", @pdf.PdfObject::String("app.alert('right')")),
  ])
  add_names_tree(left, "/JavaScript", [("LeftScript", left_action)])
  add_names_tree(right, "/JavaScript", [("RightScript", right_action)])
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["js_left", "js_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  )
  let entries = read_name_tree_entries(merged, "/JavaScript")
  assert_true(entries.search_by(pair => pair.0 == "LeftScript") is Some(_))
  assert_true(entries.search_by(pair => pair.0 == "RightScript") is Some(_))
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_javascript_names.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_entries = read_name_tree_entries(parsed, "/JavaScript")
  assert_true(
    parsed_entries.search_by(pair => pair.0 == "LeftScript") is Some(_),
  )
  assert_true(
    parsed_entries.search_by(pair => pair.0 == "RightScript") is Some(_),
  )
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /Names /EmbeddedFiles" {
  let left = @pdfpage.minimum_valid_pdf()
  let right = @pdfpage.minimum_valid_pdf()
  add_embedded_file(left, "LeftFile", "left.txt", "left payload")
  add_embedded_file(right, "RightFile", "right.txt", "right payload")
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["embed_left", "embed_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  )
  let entries = read_name_tree_entries(merged, "/EmbeddedFiles")
  assert_embedded_file_entry(
    merged, entries, "LeftFile", "left.txt", "left payload",
  )
  assert_embedded_file_entry(
    merged, entries, "RightFile", "right.txt", "right payload",
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_embedded_files.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_entries = read_name_tree_entries(parsed, "/EmbeddedFiles")
  assert_embedded_file_entry(
    parsed, parsed_entries, "LeftFile", "left.txt", "left payload",
  )
  assert_embedded_file_entry(
    parsed, parsed_entries, "RightFile", "right.txt", "right payload",
  )
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves bookmark targets" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let left_count = page_count(left)
  let right_count = page_count(right)
  assert_true(left_count > 0)
  assert_true(right_count > 0)
  let page1 = match @pdfpage.page_object_number(left, 1) {
    Some(objnum) => objnum
    None => fail("missing page 1")
  }
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Merged bookmark",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(page1)),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let left_with = @pdfmarks.add_bookmarks(marks, left)
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["merge_marks_left", "merge_marks_right"],
    [left_with, right],
    [full_range(left_count), full_range(right_count)],
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_marks.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_marks = @pdfmarks.read_bookmarks(parsed)
  assert_eq(parsed_marks.length(), 1)
  let target_page = @pdfpage.pagenumber_of_target(
    parsed,
    parsed_marks[0].target,
  )
  assert_eq(target_page, 1)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e bookmarks roundtrip" {
  let pdf = read_pdf(BOOKMARK_PATH)
  let count = page_count(pdf)
  assert_true(count >= 2)
  let page1 = match @pdfpage.page_object_number(pdf, 1) {
    Some(objnum) => objnum
    None => fail("missing page 1")
  }
  let page2 = match @pdfpage.page_object_number(pdf, 2) {
    Some(objnum) => objnum
    None => fail("missing page 2")
  }
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "E2E Intro",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(page1)),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "E2E Details",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(page2)),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf_with = @pdfmarks.add_bookmarks(marks, pdf)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/bookmarks.pdf"
  write_pdf(out_path, pdf_with)
  let parsed = read_pdf(out_path)
  let parsed_marks = @pdfmarks.read_bookmarks(parsed)
  assert_eq(parsed_marks.length(), 2)
  assert_eq(parsed_marks[0].text, "E2E Intro")
  assert_eq(parsed_marks[1].text, "E2E Details")
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e write object streams and read back" {
  let pdf = read_pdf(MERGE_THIRD_PATH)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/objstm.pdf"
  let file = @fs.open(out_path, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  @pdfwrite.pdf_to_channel(
    generate_objstm=true,
    compress_objstm=true,
    None,
    true,
    pdf,
    file,
  )
  let parsed = read_pdf(out_path)
  assert_true(parsed.objects.object_stream_ids.length() > 0)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e encrypt pdf and require password" {
  let pdf = read_pdf(MERGE_LEFT_PATH)
  let enc = @pdfwrite.make_encryption(
    @pdfwrite.EncryptionMethod::AES256bit(true),
    "owner-pass",
    "user-pass",
    [],
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/encrypted.pdf"
  let file = @fs.open(out_path, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  @pdfwrite.pdf_to_channel(Some(enc), true, pdf, file)
  let res : Result[@pdf.Pdf, Error] = try? @pdfread.pdf_of_file(
    None,
    None,
    out_path,
  )
  match res {
    Ok(parsed) =>
      if @pdfread.what_encryption(parsed) is None {
        fail("expected encryption info")
      }
    Err(_) => fail("expected read to succeed without password")
  }
  let parsed_pw = @pdfread.pdf_of_file(Some("user-pass"), None, out_path)
  assert_eq(page_count(parsed_pw), page_count(pdf))
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge split merge pipeline" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let third = read_pdf(MERGE_THIRD_PATH)
  let left_count = page_count(left)
  let right_count = page_count(right)
  let third_count = page_count(third)
  let merged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["pipeline_left", "pipeline_right"],
    [left, right],
    [full_range(left_count), full_range(right_count)],
  )
  let merged_count = page_count(merged)
  assert_true(merged_count > 1)
  let subset = if merged_count > 2 {
    [1, merged_count / 2, merged_count]
  } else {
    [1, merged_count]
  }
  let subset_pdf = @pdfpage.pdf_of_pages(merged, subset)
  let remerged = @pdfmerge.merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
    ["pipeline_subset", "pipeline_third"],
    [subset_pdf, third],
    [full_range(subset.length()), full_range(third_count)],
  )
  assert_eq(page_count(remerged), subset.length() + third_count)
}

///|
async test "e2e page labels roundtrip" {
  let pdf = read_pdf(LARGE_PATH)
  let count = page_count(pdf)
  assert_true(count >= 3)
  let labels = [
    @pdfpagelabels.PageLabel::{
      labelstyle: @pdfpagelabels.LabelStyle::DecimalArabic,
      labelprefix: Some("E2E-"),
      startpage: 1,
      startvalue: 1,
    },
    @pdfpagelabels.PageLabel::{
      labelstyle: @pdfpagelabels.LabelStyle::LowercaseRoman,
      labelprefix: None,
      startpage: 3,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.write(pdf, labels)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/pagelabels.pdf"
  write_pdf(out_path, pdf)
  let parsed = read_pdf(out_path)
  let read_back = @pdfpagelabels.read(parsed)
  assert_eq(read_back.length(), 2)
  match read_back[0].labelprefix {
    Some("E2E-") => ()
    _ => fail("expected prefix E2E-")
  }
  assert_eq(read_back[1].startpage, 3)
  assert_eq(@pdfpagelabels.pagelabeltext_of_pagenumber(1, read_back), "E2E-1")
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e page ops roundtrip" {
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let page : @pdfpage.Page = {
    content: [@pdfops.stream_of_ops([@pdfops.Op::Opq, @pdfops.Op::OpQ])],
    mediabox: rect,
    resources: @pdf.PdfObject::Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
  let (pdf0, pageroot) = @pdfpage.add_pagetree([page], @pdf.empty())
  let pdf = @pdfpage.add_root(pageroot, [], pdf0)
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let updated = @pdfpage.postpend_operators(
    pdf,
    [@pdfops.Op::Opw(5.0)],
    pages[0],
    fast=true,
  )
  pages[0] = updated
  let updated_pdf = @pdfpage.change_pages(true, pdf, pages)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/page_ops.pdf"
  write_pdf(out_path, updated_pdf)
  let parsed = read_pdf(out_path)
  let parsed_page = @pdfpage.pages_of_pagetree(parsed)[0]
  let parsed_ops = @pdfops.parse_operators(
    parsed,
    parsed_page.resources,
    parsed_page.content,
  )
  let mut found = false
  for op in parsed_ops {
    match op {
      @pdfops.Op::Opw(5.0) => found = true
      _ => ()
    }
  }
  assert_true(found)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}
