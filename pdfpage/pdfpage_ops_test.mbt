///|
fn ops_sample_rect() -> @pdf.PdfObject {
  @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
}

///|
fn ops_page_with_ops(ops : Array[@pdfops.Op]) -> @pdfpage.Page raise {
  {
    content: [@pdfops.stream_of_ops(ops)],
    mediabox: ops_sample_rect(),
    resources: @pdf.PdfObject::Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: @pdf.PdfObject::Dictionary([]),
  }
}

///|
test "prepend_operators fast path inserts ops" {
  let pdf = @pdf.empty()
  let base_ops = [@pdfops.Op::Opq, @pdfops.Op::OpQ]
  let page = ops_page_with_ops(base_ops)
  let updated = @pdfpage.prepend_operators(
    pdf,
    [@pdfops.Op::Opw(2.0)],
    page,
    fast=true,
  )
  let ops = @pdfops.parse_operators(pdf, updated.resources, updated.content)
  match ops[0] {
    @pdfops.Op::Opw(2.0) => ()
    _ => fail("expected prepended op")
  }
}

///|
test "postpend_operators fast path wraps ops" {
  let pdf = @pdf.empty()
  let base_ops = [@pdfops.Op::OpBT, @pdfops.Op::OpET]
  let page = ops_page_with_ops(base_ops)
  let updated = @pdfpage.postpend_operators(
    pdf,
    [@pdfops.Op::Opw(3.0)],
    page,
    fast=true,
  )
  let ops = @pdfops.parse_operators(pdf, updated.resources, updated.content)
  let len = ops.length()
  match (ops[len - 3], ops[len - 2], ops[len - 1]) {
    (@pdfops.Op::Opq, @pdfops.Op::Opw(3.0), @pdfops.Op::OpQ) => ()
    _ => fail("expected wrapped ops at end")
  }
}

///|
test "postpend_operators handles empty content" {
  let pdf = @pdf.empty()
  let page = @pdfpage.custompage(ops_sample_rect())
  let updated = @pdfpage.postpend_operators(pdf, [@pdfops.Op::Opw(1.0)], page)
  let ops = @pdfops.parse_operators(pdf, updated.resources, updated.content)
  match ops {
    [@pdfops.Op::Opw(1.0)] => ()
    _ => fail("expected single op")
  }
}

///|
test "protect adds missing Q operators" {
  let fixed = @pdfpage.protect([@pdfops.Op::Opq, @pdfops.Op::Opq])
  assert_eq(fixed.length(), 2)
  match fixed {
    [@pdfops.Op::OpQ, @pdfops.Op::OpQ] => ()
    _ => fail("expected OpQ fixes")
  }
}
