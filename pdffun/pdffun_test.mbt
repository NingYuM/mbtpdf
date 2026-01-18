///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "eval calculator function" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/FunctionType", @pdf.PdfObject::Integer(4)),
    (
      "/Domain",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(10.0),
      ]),
    ),
  ])
  let data = @pdfio.bytes_of_string("{ dup mul }")
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  let fun = parse_function(pdf, stream_obj)
  let output = eval_function(fun, [2.0])
  assert_eq(output.length(), 1)
  assert_close(output[0], 4.0)
}

///|
test "eval interpolation function" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Interpolation({ c0: [0.0], c1: [1.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let output = eval_function(fun, [0.25])
  assert_eq(output.length(), 1)
  assert_close(output[0], 0.25)
}

///|
test "serialize sampled function" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Sampled({
      size: [2],
      order: 1,
      encode: [0.0, 1.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let pdf = @pdf.empty()
  let obj = pdfobject_of_function(pdf, fun)
  match obj {
    @pdf.PdfObject::Stream(_) => ()
    _ => fail("expected sampled function to be a stream")
  }
  let parsed = parse_function(pdf, obj)
  let output = eval_function(parsed, [1.0])
  assert_eq(output.length(), 1)
  assert_close(output[0], 1.0)
}

///|
test "serialize calculator function" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Calculator([Calculator::Dup, Calculator::Mul]),
    domain: [0.0, 10.0],
    range: Some([0.0, 100.0]),
  }
  let pdf = @pdf.empty()
  let obj = pdfobject_of_function(pdf, fun)
  match obj {
    @pdf.PdfObject::Stream(_) => ()
    _ => fail("expected calculator function to be a stream")
  }
  let parsed = parse_function(pdf, obj)
  let output = eval_function(parsed, [3.0])
  assert_eq(output.length(), 1)
  assert_close(output[0], 9.0)
}
