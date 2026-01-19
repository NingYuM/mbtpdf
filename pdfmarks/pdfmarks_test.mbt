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
  let filename = "pdfmarks_bookmark_string_test.pdf"
  let file = @fs.open(filename, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  @pdfwrite.pdf_to_channel(None, true, pdf_with, file)
  let parsed = @pdfread.pdf_of_file(None, None, filename)
  let parsed_marks = @pdfmarks.read_bookmarks(parsed)
  assert_eq(parsed_marks.length(), 1)
  assert_eq(parsed_marks[0].text, "Café")
}

///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
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
