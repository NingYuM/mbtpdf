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
