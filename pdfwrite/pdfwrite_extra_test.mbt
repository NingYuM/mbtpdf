///|
test "string_of_pdf_including_data includes stream bytes" {
  let data = @pdfio.bytes_of_string("abc")
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(data))),
  ])
  let stream = @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let rendered = @pdfwrite.string_of_pdf_including_data(stream)
  assert_true(rendered.contains("stream"))
  assert_true(rendered.contains("abc"))
}

///|
test "string_of_pdf escapes carriage return and form feed" {
  let obj = @pdf.PdfObject::String("a\r\f")
  let rendered = @pdfwrite.string_of_pdf(obj)
  assert_true(rendered.contains("\\r"))
  assert_true(rendered.contains("\\f"))
}

///|
test "string_of_pdf expands scientific notation" {
  let rendered = @pdfwrite.string_of_pdf(@pdf.PdfObject::Real(1.2e20))
  assert_true(!rendered.contains("e") && !rendered.contains("E"))
}

///|
test "string_of_pdf handles short names" {
  let rendered = @pdfwrite.string_of_pdf(@pdf.PdfObject::Name("/"))
  assert_eq(rendered, "/")
}

///|
test "make_hex_pdf_string encodes bytes" {
  assert_eq(@pdfwrite.make_hex_pdf_string("Hi"), "<4869>")
}

///|
test "debug_whole_pdf runs" {
  let pdf = @pdfpage.minimum_valid_pdf()
  @pdfwrite.debug_whole_pdf(pdf)
}

///|
async test "pdf_to_file writes output" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let path = "pdfwrite_async_test.pdf"
  @pdfwrite.pdf_to_file(pdf, path)
  let file = @fs.open(path, mode=ReadOnly)
  let bytes = @pdfio.bytes_of_input_channel(file)
  assert_true(bytes.length() > 0)
  file.close()
  @fs.remove(path)
}

///|
async test "pdf_to_file_options supports recrypt" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let path = "pdfwrite_async_recrypt.pdf"
  let res : Result[Unit, Error] = try? @pdfwrite.pdf_to_file_options(
    preserve_objstm=false,
    generate_objstm=false,
    compress_objstm=false,
    recrypt="pass",
    None,
    true,
    pdf,
    path,
  )
  assert_true(res is Err(_))
  let _ : Result[Unit, Error] = try? @fs.remove(path)

}
