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
