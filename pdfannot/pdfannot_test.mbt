///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
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

///|
test "read_annotation parses styles and extras" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(10.0),
  ])
  let solid = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Highlight")),
    ("/Rect", rect),
    (
      "/BS",
      @pdf.PdfObject::Dictionary([
        ("/S", @pdf.PdfObject::Name("/S")),
        ("/W", @pdf.PdfObject::Real(3.0)),
        (
          "/D",
          @pdf.PdfObject::Array([
            @pdf.PdfObject::Integer(1),
            @pdf.PdfObject::Integer(2),
          ]),
        ),
      ]),
    ),
  ])
  let underline = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Underline")),
    ("/Rect", rect),
    ("/BS", @pdf.PdfObject::Dictionary([("/S", @pdf.PdfObject::Name("/U"))])),
  ])
  let border = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Link")),
    ("/Rect", rect),
    (
      "/Border",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Real(1.0),
        @pdf.PdfObject::Real(2.0),
        @pdf.PdfObject::Real(3.0),
      ]),
    ),
  ])
  let extras = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Text")),
    ("/Rect", rect),
    ("/Contents", @pdf.PdfObject::String("Note")),
    ("/Subj", @pdf.PdfObject::String("Subject")),
    (
      "/C",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Integer(1),
        @pdf.PdfObject::Integer(2),
        @pdf.PdfObject::Integer(3),
      ]),
    ),
    ("/Foo", @pdf.PdfObject::Integer(7)),
  ])
  let nums = [
    @pdf.addobj(pdf, solid),
    @pdf.addobj(pdf, underline),
    @pdf.addobj(pdf, border),
    @pdf.addobj(pdf, extras),
  ]
  let rest = @pdf.PdfObject::Dictionary([
    (
      "/Annots",
      @pdf.PdfObject::Array(nums.map(n => @pdf.PdfObject::Indirect(n))),
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
  assert_eq(annots.length(), 4)
  match annots[0].border.style {
    @pdfannot.Style::Solid => ()
    _ => fail("expected solid style")
  }
  assert_eq(annots[0].border.dasharray.length(), 2)
  match annots[1].border.style {
    @pdfannot.Style::UnderlineStyle => ()
    _ => fail("expected underline style")
  }
  assert_close(annots[2].border.hradius, 1.0)
  assert_close(annots[2].border.vradius, 2.0)
  assert_close(annots[2].border.width, 3.0)
  match annots[3].annot_contents {
    Some("Note") => ()
    _ => fail("expected contents")
  }
  match annots[3].subject {
    Some("Subject") => ()
    _ => fail("expected subject")
  }
  match annots[3].colour {
    Some((1, 2, 3)) => ()
    _ => fail("expected colour")
  }
  match @pdf.lookup_direct(pdf, "/Foo", annots[3].annotrest) {
    Some(@pdf.PdfObject::Integer(7)) => ()
    _ => fail("expected extra field")
  }
}

///|
test "read_annotation handles unknown subtype and missing strings" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(10.0),
  ])
  let annot_dict = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Weird")),
    ("/Rect", rect),
    ("/Contents", @pdf.PdfObject::Name("/Nope")),
    ("/Subj", @pdf.PdfObject::Name("/Nope")),
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
  match annots[0].subtype {
    @pdfannot.Subtype::Unknown("/Weird") => ()
    _ => fail("expected unknown subtype")
  }
  match annots[0].annot_contents {
    None => ()
    _ => fail("expected no contents")
  }
  match annots[0].subject {
    None => ()
    _ => fail("expected no subject")
  }
}

///|
test "annotations_of_page handles non-array and add_annotation rejects" {
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(10.0),
  ])
  let base = @pdfpage.custompage(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest: @pdf.PdfObject::Dictionary([("/Annots", @pdf.PdfObject::Null)]),
  }
  let pdf = @pdf.empty()
  let annots = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(annots.length(), 0)
  let annot = @pdfannot.make(@pdfannot.Subtype::Text)
  assert_is_err(try? @pdfannot.add_annotation(pdf, page, annot))
}

///|
test "transform_annotations keeps malformed quadpoints" {
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
      ]),
    ),
  ])
  let objnum = @pdf.addobj(pdf, annot_dict)
  let rest = @pdf.PdfObject::Dictionary([
    ("/Annots", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(objnum)])),
  ])
  let tr = @pdftransform.mktranslate(5.0, 5.0)
  @pdfannot.transform_annotations(pdf, tr, rest)
  let updated = @pdf.lookup_obj(pdf, objnum)
  match @pdf.lookup_direct(pdf, "/Rect", updated) {
    Some(rect) => {
      let (x0, y0, x1, y1) = @pdf.parse_rectangle(pdf, rect)
      assert_close(x0, 5.0)
      assert_close(y0, 5.0)
      assert_close(x1, 15.0)
      assert_close(y1, 25.0)
    }
    _ => fail("expected rect update")
  }
  match @pdf.lookup_direct(pdf, "/QuadPoints", updated) {
    Some(@pdf.PdfObject::Array(values)) => {
      assert_close(@pdf.getnum(pdf, values[0]), 0.0)
      assert_close(@pdf.getnum(pdf, values[1]), 0.0)
      assert_close(@pdf.getnum(pdf, values[2]), 10.0)
      assert_close(@pdf.getnum(pdf, values[3]), 0.0)
    }
    _ => fail("expected quadpoints")
  }
}

///|
test "read_annotation handles more subtypes and popup fallback" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(10.0),
  ])
  let annots = [
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/FreeText")),
      ("/Rect", rect),
    ]),
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/Stamp")),
      ("/Rect", rect),
    ]),
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/Line")),
      ("/Rect", rect),
    ]),
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/Squiggly")),
      ("/Rect", rect),
    ]),
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/Popup")),
      ("/Rect", rect),
      ("/Parent", @pdf.PdfObject::String("nope")),
    ]),
    @pdf.PdfObject::Dictionary([("/Rect", rect)]),
  ]
  let nums = annots.map(annot => @pdf.addobj(pdf, annot))
  let rest = @pdf.PdfObject::Dictionary([
    (
      "/Annots",
      @pdf.PdfObject::Array(nums.map(n => @pdf.PdfObject::Indirect(n))),
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
  let parsed = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(parsed.length(), 6)
  match parsed[0].subtype {
    @pdfannot.Subtype::FreeText => ()
    _ => fail("expected freetext subtype")
  }
  match parsed[1].subtype {
    @pdfannot.Subtype::Stamp => ()
    _ => fail("expected stamp subtype")
  }
  match parsed[2].subtype {
    @pdfannot.Subtype::Line => ()
    _ => fail("expected line subtype")
  }
  match parsed[3].subtype {
    @pdfannot.Subtype::Squiggly => ()
    _ => fail("expected squiggly subtype")
  }
  match parsed[4].subtype {
    @pdfannot.Subtype::Unknown("") => ()
    _ => fail("expected popup fallback subtype")
  }
  match parsed[5].subtype {
    @pdfannot.Subtype::Unknown("") => ()
    _ => fail("expected missing subtype fallback")
  }
}

///|
test "read_annotation covers border styles and dash array" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(10.0),
  ])
  let annots = [
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/Text")),
      ("/Rect", rect),
      ("/BS", @pdf.PdfObject::Dictionary([("/S", @pdf.PdfObject::Name("/B"))])),
    ]),
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/Text")),
      ("/Rect", rect),
      ("/BS", @pdf.PdfObject::Dictionary([("/S", @pdf.PdfObject::Name("/X"))])),
    ]),
    @pdf.PdfObject::Dictionary([
      ("/Subtype", @pdf.PdfObject::Name("/Text")),
      ("/Rect", rect),
      (
        "/Border",
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Real(1.0),
          @pdf.PdfObject::Real(2.0),
          @pdf.PdfObject::Real(3.0),
          @pdf.PdfObject::Array([
            @pdf.PdfObject::Integer(4),
            @pdf.PdfObject::Integer(5),
          ]),
        ]),
      ),
    ]),
  ]
  let nums = annots.map(annot => @pdf.addobj(pdf, annot))
  let rest = @pdf.PdfObject::Dictionary([
    (
      "/Annots",
      @pdf.PdfObject::Array(nums.map(n => @pdf.PdfObject::Indirect(n))),
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
  let parsed = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(parsed.length(), 3)
  match parsed[0].border.style {
    @pdfannot.Style::Beveled => ()
    _ => fail("expected beveled style")
  }
  match parsed[1].border.style {
    @pdfannot.Style::NoStyle => ()
    _ => fail("expected default style")
  }
  assert_eq(parsed[2].border.dasharray.length(), 2)
  assert_eq(parsed[2].border.dasharray[0], 4)
  assert_eq(parsed[2].border.dasharray[1], 5)
}

///|
test "add_annotation merges existing annots and extras" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(10.0),
  ])
  let existing = @pdf.PdfObject::Dictionary([
    ("/Subtype", @pdf.PdfObject::Name("/Text")),
    ("/Rect", rect),
  ])
  let base = @pdfpage.custompage(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest: @pdf.PdfObject::Dictionary([
      ("/Annots", @pdf.PdfObject::Array([existing])),
    ]),
  }
  let base_annot = @pdfannot.make(@pdfannot.Subtype::FreeText)
  let annot : @pdfannot.Annotation = {
    subtype: base_annot.subtype,
    annot_contents: base_annot.annot_contents,
    subject: base_annot.subject,
    rectangle: base_annot.rectangle,
    border: base_annot.border,
    colour: base_annot.colour,
    annotrest: @pdf.PdfObject::Dictionary([("/Foo", @pdf.PdfObject::Integer(9))]),
  }
  let updated = @pdfannot.add_annotation(pdf, page, annot)
  match @pdf.lookup_direct(pdf, "/Annots", updated.rest) {
    Some(@pdf.PdfObject::Array([first, second])) => {
      match @pdf.lookup_direct(pdf, "/Subtype", first) {
        Some(@pdf.PdfObject::Name("/FreeText")) => ()
        _ => fail("expected freetext subtype")
      }
      match @pdf.lookup_direct(pdf, "/Foo", first) {
        Some(@pdf.PdfObject::Integer(9)) => ()
        _ => fail("expected extra field")
      }
      match @pdf.lookup_direct(pdf, "/Subtype", second) {
        Some(@pdf.PdfObject::Name("/Text")) => ()
        _ => fail("expected existing annotation")
      }
    }
    _ => fail("expected annotations array")
  }
}

///|
test "annotations_of_page errors on non-dictionary annots" {
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(10.0),
    @pdf.PdfObject::Real(10.0),
  ])
  let base = @pdfpage.custompage(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest: @pdf.PdfObject::Dictionary([
      ("/Annots", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(1)])),
    ]),
  }
  let pdf = @pdf.empty()
  assert_is_err(try? @pdfannot.annotations_of_page(pdf, page))
}

///|
test "transform_annotations leaves non-array quadpoints" {
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
    ("/QuadPoints", @pdf.PdfObject::Name("/Bad")),
  ])
  let objnum = @pdf.addobj(pdf, annot_dict)
  let rest = @pdf.PdfObject::Dictionary([
    ("/Annots", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(objnum)])),
  ])
  let tr = @pdftransform.mktranslate(5.0, 5.0)
  @pdfannot.transform_annotations(pdf, tr, rest)
  let updated = @pdf.lookup_obj(pdf, objnum)
  match @pdf.lookup_direct(pdf, "/QuadPoints", updated) {
    Some(@pdf.PdfObject::Name("/Bad")) => ()
    _ => fail("expected non-array quadpoints")
  }
}
