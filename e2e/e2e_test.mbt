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
