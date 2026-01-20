///|
async test "bookmark string roundtrip through file output" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Café",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf_with = @pdfmarks.add_bookmarks(marks, pdf)
  let dir = "tmp/pdfmarks"
  if !@fs.exists(dir) {
    @fs.mkdir(dir, permission=0o755, recursive=true)
  }
  let filename = dir + "/bookmark_string_test.pdf"
  let file = @fs.open(filename, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  @pdfwrite.pdf_to_channel(None, true, pdf_with, file)
  let parsed = @pdfread.pdf_of_file(None, None, filename)
  let parsed_marks = @pdfmarks.read_bookmarks(parsed)
  assert_eq(parsed_marks.length(), 1)
  assert_eq(parsed_marks[0].text, "Café")
  let _ : Result[Unit, Error] = try? @fs.remove(filename)

}

///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
fn outlines_root(pdf : @pdf.Pdf) -> @pdf.PdfObject raise {
  let catalog = @pdf.catalog_of_pdf(pdf)
  match @pdf.lookup_direct(pdf, "/Outlines", catalog) {
    Some(obj) => obj
    None => fail("expected /Outlines")
  }
}

///|
test "string_of_bookmark includes text" {
  let mark : @pdfmarks.Bookmark = {
    level: 1,
    text: "Chapter",
    target: @pdfdest.Destination::NullDestination,
    isopen: true,
    colour: (0.1, 0.2, 0.3),
    flags: 0,
  }
  let text = @pdfmarks.string_of_bookmark(mark)
  assert_true(text.contains("Chapter"))
  assert_true(text.contains("true"))
}

///|
test "remove_bookmarks clears outlines" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Intro",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf_with = @pdfmarks.add_bookmarks(marks, pdf)
  assert_eq(@pdfmarks.read_bookmarks(pdf_with).length(), 1)
  let removed = @pdfmarks.remove_bookmarks(pdf_with)
  assert_eq(@pdfmarks.read_bookmarks(removed).length(), 0)
}

///|
test "transform_bookmark translates destination" {
  let pdf = @pdf.empty()
  let mark : @pdfmarks.Bookmark = {
    level: 0,
    text: "Move",
    target: @pdfdest.Destination::XYZ(
      @pdfdest.TargetPage::PageObject(1),
      Some(10.0),
      Some(20.0),
      Some(1.0),
    ),
    isopen: false,
    colour: (0.0, 0.0, 0.0),
    flags: 0,
  }
  let tr = @pdftransform.mktranslate(5.0, -3.0)
  let moved = @pdfmarks.transform_bookmark(pdf, tr, mark)
  match moved.target {
    @pdfdest.Destination::XYZ(_, Some(left), Some(top), Some(zoom)) => {
      assert_close(left, 15.0)
      assert_close(top, 17.0)
      assert_close(zoom, 1.0)
    }
    _ => fail("expected transformed XYZ destination")
  }
}

///|
test "add_bookmarks links siblings and counts" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "A",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "A1",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "B",
      target: @pdfdest.Destination::NullDestination,
      isopen: true,
      colour: (0.1, 0.2, 0.3),
      flags: 2,
    },
    {
      level: 1,
      text: "B1",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "B2",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf_with = @pdfmarks.add_bookmarks(marks, pdf)
  let outlines = outlines_root(pdf_with)
  match @pdf.lookup_direct(pdf_with, "/Count", outlines) {
    Some(@pdf.PdfObject::Integer(i)) => assert_eq(i, 4)
    _ => fail("expected /Count on outlines")
  }
  let first = match @pdf.lookup_direct(pdf_with, "/First", outlines) {
    Some(obj) => obj
    None => fail("expected /First")
  }
  let last = match @pdf.lookup_direct(pdf_with, "/Last", outlines) {
    Some(obj) => obj
    None => fail("expected /Last")
  }
  match
    (
      @pdf.lookup_direct(pdf_with, "/Title", first),
      @pdf.lookup_direct(pdf_with, "/Title", last),
    ) {
    (Some(@pdf.PdfObject::String(a)), Some(@pdf.PdfObject::String(b))) => {
      assert_eq(a, "A")
      assert_eq(b, "B")
    }
    _ => fail("expected titles")
  }
  match @pdf.lookup_direct(pdf_with, "/Next", first) {
    Some(next) =>
      match @pdf.lookup_direct(pdf_with, "/Title", next) {
        Some(@pdf.PdfObject::String(s)) => assert_eq(s, "B")
        _ => fail("expected /Next title")
      }
    None => fail("expected /Next")
  }
  match @pdf.lookup_direct(pdf_with, "/Prev", last) {
    Some(prev) =>
      match @pdf.lookup_direct(pdf_with, "/Title", prev) {
        Some(@pdf.PdfObject::String(s)) => assert_eq(s, "A")
        _ => fail("expected /Prev title")
      }
    None => fail("expected /Prev")
  }
  match @pdf.lookup_direct(pdf_with, "/Count", first) {
    Some(@pdf.PdfObject::Integer(i)) => assert_eq(i, -1)
    _ => fail("expected negative /Count for closed node")
  }
  match @pdf.lookup_direct(pdf_with, "/Count", last) {
    Some(@pdf.PdfObject::Integer(i)) => assert_eq(i, 2)
    _ => fail("expected positive /Count for open node")
  }
  let marks_read = @pdfmarks.read_bookmarks(pdf_with)
  assert_eq(marks_read.length(), 5)
  match marks_read[2] {
    { text: "B", colour: (r, g, b), flags: f, .. } => {
      assert_close(r, 0.1)
      assert_close(g, 0.2)
      assert_close(b, 0.3)
      assert_eq(f, 2)
    }
    _ => fail("expected mark B")
  }
}

///|
test "read_bookmarks toggles action preservation" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let action = @pdf.PdfObject::Dictionary([
    ("/S", @pdf.PdfObject::Name("/GoTo")),
    ("/D", @pdf.PdfObject::String("dest")),
  ])
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Action",
      target: @pdfdest.Destination::Action(action),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf_with = @pdfmarks.add_bookmarks(marks, pdf)
  let preserved = @pdfmarks.read_bookmarks(pdf_with, preserve_actions=true)
  match preserved[0].target {
    @pdfdest.Destination::Action(_) => ()
    _ => fail("expected action preserved")
  }
  let resolved = @pdfmarks.read_bookmarks(pdf_with, preserve_actions=false)
  match resolved[0].target {
    @pdfdest.Destination::StringDestination("dest") => ()
    _ => fail("expected string destination")
  }
}
