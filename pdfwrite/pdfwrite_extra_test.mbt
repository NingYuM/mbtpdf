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
test "string_of_pdf expands negative exponent" {
  let rendered = @pdfwrite.string_of_pdf(@pdf.PdfObject::Real(1.2e-5))
  assert_true(!rendered.contains("e") && !rendered.contains("E"))
  assert_true(rendered.has_prefix("0."))
}

///|
test "string_of_pdf encodes control and delimiter bytes" {
  let bytes = @pdfio.bytes_of_list([0x2f, 0x14, 0x28, 0x25])
  let name = @pdfio.string_of_bytes(bytes)
  let rendered = @pdfwrite.string_of_pdf(@pdf.PdfObject::Name(name))
  assert_true(rendered.contains("#14"))
  assert_true(rendered.contains("#28"))
  assert_true(rendered.contains("#25"))
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
test "pdf_to_output generates object streams with indirect lengths" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let length_obj = @pdf.addobj(pdf, @pdf.PdfObject::Integer(3))
  let data = @pdfio.bytes_of_string("abc")
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Indirect(length_obj)),
  ])
  let stream_num = @pdf.addobj(
    pdf,
    @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data)))),
  )
  let marked_obj = @pdf.addobj(pdf, @pdf.PdfObject::Integer(123))
  pdf.objects.object_stream_ids.set(marked_obj, stream_num)
  pdf.objects.object_stream_ids.set(stream_num, stream_num)
  let payload = "A".repeat(200)
  for _ in 0 ..<= 20 {
    ignore(@pdf.addobj(pdf, @pdf.PdfObject::String(payload)))
  }
  let (output, buffer) = @pdfio.input_output_of_bytes(4096)
  @pdfwrite.pdf_to_output(
    generate_objstm=true,
    preserve_objstm=false,
    compress_objstm=true,
    None,
    false,
    pdf,
    output,
  )
  let bytes = @pdfio.extract_bytes_from_input_output(output, buffer)
  let text = @pdfio.string_of_bytes(bytes)
  assert_true(text.contains("/ObjStm"))
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
