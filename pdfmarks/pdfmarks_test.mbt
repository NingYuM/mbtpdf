///|
fn open_write_file(filename : String) -> @fs.File raise {
  let result : Ref[Result[@fs.File, Error]] = Ref::new(
    Err(Failure::Failure("uninitialized open")),
  )
  @async.run_async_main(() => {
    let res : Result[@fs.File, Error] = try? @fs.open(
      filename,
      mode=WriteOnly,
      create=0o644,
      truncate=true,
    )
    result.val = res
  })
  match result.val {
    Ok(file) => file
    Err(err) => raise err
  }
}

///|
fn close_file(file : @fs.File) -> Unit {
  @async.run_async_main(() => file.close())
}

///|
test "bookmark string roundtrip through file output" {
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
  let file = open_write_file(filename)
  @pdfwrite.pdf_to_channel(None, true, pdf_with, file) catch {
    err => {
      close_file(file)
      raise err
    }
  }
  close_file(file)
  let parsed = @pdfread.pdf_of_file(None, None, filename)
  let parsed_marks = @pdfmarks.read_bookmarks(parsed)
  assert_eq(parsed_marks.length(), 1)
  assert_eq(parsed_marks[0].text, "Café")
}
