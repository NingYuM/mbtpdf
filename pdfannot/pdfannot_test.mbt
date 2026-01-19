///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "annotation border dash array" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(100.0),
    @pdf.PdfObject::Real(100.0),
  ])
  let page = @pdfpage.custompage(rect)
  let border = @pdfannot.make_border(1.0, dasharray=[2, 3])
  let annot = @pdfannot.make(@pdfannot.Subtype::Text, border~)
  let updated = @pdfannot.add_annotation(pdf, page, annot)
  match @pdf.lookup_direct(pdf, "/Annots", updated.rest) {
    Some(@pdf.PdfObject::Array([annot_obj, ..])) =>
      match @pdf.lookup_direct(pdf, "/Border", annot_obj) {
        Some(@pdf.PdfObject::Array([_, _, _, @pdf.PdfObject::Array(dash)])) => {
          assert_eq(dash.length(), 2)
          match dash[0] {
            @pdf.PdfObject::Integer(2) => ()
            _ => fail("expected dash value 2")
          }
        }
        _ => fail("expected border dash array")
      }
    _ => fail("expected /Annots array")
  }
}

///|
test "add_annotation and read back" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(50.0),
    @pdf.PdfObject::Real(50.0),
  ])
  let page = @pdfpage.custompage(rect)
  let border = @pdfannot.make_border(2.0)
  let annot = @pdfannot.make(
    @pdfannot.Subtype::Link,
    content="Go",
    border~,
    rectangle=(1.0, 2.0, 3.0, 4.0),
    colour=(10, 20, 30),
    subject="Subject",
  )
  let updated = @pdfannot.add_annotation(pdf, page, annot)
  let annots = @pdfannot.annotations_of_page(pdf, updated)
  assert_eq(annots.length(), 1)
  let a = annots[0]
  match a.subtype {
    @pdfannot.Subtype::Link => ()
    _ => fail("expected Link subtype")
  }
  match a.annot_contents {
    Some("Go") => ()
    _ => fail("expected contents")
  }
  assert_close(a.rectangle.0, 1.0)
  assert_close(a.rectangle.1, 2.0)
  assert_close(a.rectangle.2, 3.0)
  assert_close(a.rectangle.3, 4.0)
  match a.colour {
    Some((10, 20, 30)) => ()
    _ => fail("expected color")
  }
}

///|
test "transform_annotations updates rect and quadpoints" {
  let pdf = @pdf.empty()
  let annot_dict = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Link")),
    (
      "/Rect",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(10.0),
        @pdf.PdfObject::Real(20.0),
      ]),
    ),
    (
      "/QuadPoints",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(10.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(10.0),
        @pdf.PdfObject::Real(20.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(20.0),
      ]),
    ),
    (
      "/L",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(0.0),
        @pdf.PdfObject::Real(10.0),
        @pdf.PdfObject::Real(20.0),
      ]),
    ),
  ])
  let objnum = @pdf.addobj(pdf, annot_dict)
  let rest = @pdf.PdfObject::Dictionary([
    ("/Annots", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(objnum)])),
  ])
  let tr = @pdftransform.mktranslate(10.0, 20.0)
  @pdfannot.transform_annotations(pdf, tr, rest)
  let updated = @pdf.lookup_obj(pdf, objnum)
  match @pdf.lookup_direct(pdf, "/Rect", updated) {
    Some(rect) => {
      let (x0, y0, x1, y1) = @pdf.parse_rectangle(pdf, rect)
      assert_close(x0, 10.0)
      assert_close(y0, 20.0)
      assert_close(x1, 20.0)
      assert_close(y1, 40.0)
    }
    _ => fail("expected updated rect")
  }
  match @pdf.lookup_direct(pdf, "/QuadPoints", updated) {
    Some(@pdf.PdfObject::Array(values)) => {
      assert_close(@pdf.getnum(pdf, values[0]), 10.0)
      assert_close(@pdf.getnum(pdf, values[1]), 20.0)
    }
    _ => fail("expected quadpoints")
  }
  match @pdf.lookup_direct(pdf, "/L", updated) {
    Some(line) => {
      let (x0, y0, x1, y1) = @pdf.parse_rectangle(pdf, line)
      assert_close(x0, 10.0)
      assert_close(y0, 20.0)
      assert_close(x1, 20.0)
      assert_close(y1, 40.0)
    }
    _ => fail("expected line updated")
  }
}

///|
test "annotations_of_page skips popup parent" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(10.0),
  ])
  let parent_dict = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Text")),
    ("/Rect", rect),
  ])
  let parent_num = @pdf.addobj(pdf, parent_dict)
  let popup_dict = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Popup")),
    ("/Rect", rect),
    ("/Parent", @pdf.PdfObject::Indirect(parent_num)),
  ])
  let popup_num = @pdf.addobj(pdf, popup_dict)
  let rest = @pdf.PdfObject::Dictionary([
    (
      "/Annots",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Indirect(parent_num),
        @pdf.PdfObject::Indirect(popup_num),
      ]),
    ),
  ])
  let base = @pdfpage.custompage(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let annots = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(annots.length(), 1)
  match annots[0].subtype {
    @pdfannot.Subtype::Popup(inner) =>
      match inner.subtype {
        @pdfannot.Subtype::Text => ()
        _ => fail("expected popup parent text subtype")
      }
    _ => fail("expected popup subtype")
  }
}

///|
test "read_annotation uses /BS style" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(10.0),
  ])
  let annot_dict = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Link")),
    ("/Rect", rect),
    (
      "/BS",
      @pdf.PdfObject::Dictionary([
        ("/W", @pdf.PdfObject::Real(2.0)),
        ("/S", @pdf.PdfObject::Name("/D")),
        (
          "/D",
          @pdf.PdfObject::Array([
            @pdf.PdfObject::Integer(2),
            @pdf.PdfObject::Integer(1),
          ]),
        ),
      ]),
    ),
  ])
  let objnum = @pdf.addobj(pdf, annot_dict)
  let rest = @pdf.PdfObject::Dictionary([
    ("/Annots", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(objnum)])),
  ])
  let base = @pdfpage.custompage(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let annots = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(annots.length(), 1)
  match annots[0].border.style {
    @pdfannot.Style::Dashed => ()
    _ => fail("expected dashed style")
  }
  assert_eq(annots[0].border.dasharray.length(), 2)
}
