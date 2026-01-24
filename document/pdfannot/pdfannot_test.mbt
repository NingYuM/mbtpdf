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
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page = @pdfpage.Page::custom(rect)
  let border = @pdfannot.make_border(1.0, dasharray=[2, 3])
  let annot = @pdfannot.make(@pdfannot.Subtype::Text, border~)
  let updated = @pdfannot.add_annotation(pdf, page, annot)
  match (@pdf.lookup_direct(pdf, "/Annots", updated.rest) : @pdf.PdfObject?) {
    Some(Array([annot_obj, ..])) =>
      match (@pdf.lookup_direct(pdf, "/Border", annot_obj) : @pdf.PdfObject?) {
        Some(Array([_, _, _, Array(dash)])) => {
          assert_eq(dash.length(), 2)
          match (dash[0] : @pdf.PdfObject) {
            Integer(2) => ()
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
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(50.0),
    Real(50.0),
  ])
  let page = @pdfpage.Page::custom(rect)
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
  match (a.subtype : @pdfannot.Subtype) {
    Link => ()
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
  let pdf = @pdf.Pdf::empty()
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Rect", Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)])),
    (
      "/QuadPoints",
      Array([
        Real(0.0),
        Real(0.0),
        Real(10.0),
        Real(0.0),
        Real(10.0),
        Real(20.0),
        Real(0.0),
        Real(20.0),
      ]),
    ),
    ("/L", Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)])),
  ])
  let objnum = @pdf.addobj(pdf, annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let tr = @pdftransform.TransformMatrix::translate(10.0, 20.0)
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
  match (@pdf.lookup_direct(pdf, "/QuadPoints", updated) : @pdf.PdfObject?) {
    Some(Array(values)) => {
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
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let parent_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Text")),
    ("/Rect", rect),
  ])
  let parent_num = @pdf.addobj(pdf, parent_dict)
  let popup_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Popup")),
    ("/Rect", rect),
    ("/Parent", Indirect(parent_num)),
  ])
  let popup_num = @pdf.addobj(pdf, popup_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(parent_num), Indirect(popup_num)])),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let annots = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(annots.length(), 1)
  match (annots[0].subtype : @pdfannot.Subtype) {
    Popup(inner) =>
      match (inner.subtype : @pdfannot.Subtype) {
        Text => ()
        _ => fail("expected popup parent text subtype")
      }
    _ => fail("expected popup subtype")
  }
}

///|
test "read_annotation uses /BS style" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Rect", rect),
    (
      "/BS",
      Dictionary([
        ("/W", Real(2.0)),
        ("/S", Name("/D")),
        ("/D", Array([Integer(2), Integer(1)])),
      ]),
    ),
  ])
  let objnum = @pdf.addobj(pdf, annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let annots = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(annots.length(), 1)
  match (annots[0].border.style : @pdfannot.Style) {
    Dashed => ()
    _ => fail("expected dashed style")
  }
  assert_eq(annots[0].border.dasharray.length(), 2)
}

///|
test "read_annotation parses styles and extras" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let solid : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Highlight")),
    ("/Rect", rect),
    (
      "/BS",
      Dictionary([
        ("/S", Name("/S")),
        ("/W", Real(3.0)),
        ("/D", Array([Integer(1), Integer(2)])),
      ]),
    ),
  ])
  let underline : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Underline")),
    ("/Rect", rect),
    ("/BS", Dictionary([("/S", Name("/U"))])),
  ])
  let border : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Rect", rect),
    ("/Border", Array([Real(1.0), Real(2.0), Real(3.0)])),
  ])
  let extras : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Text")),
    ("/Rect", rect),
    ("/Contents", String("Note")),
    ("/Subj", String("Subject")),
    ("/C", Array([Integer(1), Integer(2), Integer(3)])),
    ("/Foo", Integer(7)),
  ])
  let nums = [
    @pdf.addobj(pdf, solid),
    @pdf.addobj(pdf, underline),
    @pdf.addobj(pdf, border),
    @pdf.addobj(pdf, extras),
  ]
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array(nums.map(fn(n) { Indirect(n) }))),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let annots = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(annots.length(), 4)
  match (annots[0].border.style : @pdfannot.Style) {
    Solid => ()
    _ => fail("expected solid style")
  }
  assert_eq(annots[0].border.dasharray.length(), 2)
  match (annots[1].border.style : @pdfannot.Style) {
    UnderlineStyle => ()
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
  match
    (@pdf.lookup_direct(pdf, "/Foo", annots[3].annotrest) : @pdf.PdfObject?) {
    Some(Integer(7)) => ()
    _ => fail("expected extra field")
  }
}

///|
test "read_annotation handles unknown subtype and missing strings" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Weird")),
    ("/Rect", rect),
    ("/Contents", Name("/Nope")),
    ("/Subj", Name("/Nope")),
  ])
  let objnum = @pdf.addobj(pdf, annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let annots = @pdfannot.annotations_of_page(pdf, page)
  match (annots[0].subtype : @pdfannot.Subtype) {
    Unknown("/Weird") => ()
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
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest: Dictionary([("/Annots", Null)]),
  }
  let pdf = @pdf.Pdf::empty()
  let annots = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(annots.length(), 0)
  let annot = @pdfannot.make(@pdfannot.Subtype::Text)
  assert_is_err(try? @pdfannot.add_annotation(pdf, page, annot))
}

///|
test "transform_annotations keeps malformed quadpoints" {
  let pdf = @pdf.Pdf::empty()
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Rect", Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)])),
    ("/QuadPoints", Array([Real(0.0), Real(0.0), Real(10.0), Real(0.0)])),
  ])
  let objnum = @pdf.addobj(pdf, annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let tr = @pdftransform.TransformMatrix::translate(5.0, 5.0)
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
  match (@pdf.lookup_direct(pdf, "/QuadPoints", updated) : @pdf.PdfObject?) {
    Some(Array(values)) => {
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
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annots : Array[@pdf.PdfObject] = [
    Dictionary([("/Subtype", Name("/FreeText")), ("/Rect", rect)]),
    Dictionary([("/Subtype", Name("/Stamp")), ("/Rect", rect)]),
    Dictionary([("/Subtype", Name("/Line")), ("/Rect", rect)]),
    Dictionary([("/Subtype", Name("/Squiggly")), ("/Rect", rect)]),
    Dictionary([
      ("/Subtype", Name("/Popup")),
      ("/Rect", rect),
      ("/Parent", String("nope")),
    ]),
    Dictionary([("/Rect", rect)]),
  ]
  let nums = annots.map(fn(annot) { @pdf.addobj(pdf, annot) })
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array(nums.map(fn(n) { Indirect(n) }))),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let parsed = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(parsed.length(), 6)
  match (parsed[0].subtype : @pdfannot.Subtype) {
    FreeText => ()
    _ => fail("expected freetext subtype")
  }
  match (parsed[1].subtype : @pdfannot.Subtype) {
    Stamp => ()
    _ => fail("expected stamp subtype")
  }
  match (parsed[2].subtype : @pdfannot.Subtype) {
    Line => ()
    _ => fail("expected line subtype")
  }
  match (parsed[3].subtype : @pdfannot.Subtype) {
    Squiggly => ()
    _ => fail("expected squiggly subtype")
  }
  match (parsed[4].subtype : @pdfannot.Subtype) {
    Unknown("") => ()
    _ => fail("expected popup fallback subtype")
  }
  match (parsed[5].subtype : @pdfannot.Subtype) {
    Unknown("") => ()
    _ => fail("expected missing subtype fallback")
  }
}

///|
test "read_annotation covers border styles and dash array" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annots : Array[@pdf.PdfObject] = [
    Dictionary([
      ("/Subtype", Name("/Text")),
      ("/Rect", rect),
      ("/BS", Dictionary([("/S", Name("/B"))])),
    ]),
    Dictionary([
      ("/Subtype", Name("/Text")),
      ("/Rect", rect),
      ("/BS", Dictionary([("/S", Name("/X"))])),
    ]),
    Dictionary([
      ("/Subtype", Name("/Text")),
      ("/Rect", rect),
      (
        "/Border",
        Array([Real(1.0), Real(2.0), Real(3.0), Array([Integer(4), Integer(5)])]),
      ),
    ]),
  ]
  let nums = annots.map(fn(annot) { @pdf.addobj(pdf, annot) })
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array(nums.map(fn(n) { Indirect(n) }))),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let parsed = @pdfannot.annotations_of_page(pdf, page)
  assert_eq(parsed.length(), 3)
  match (parsed[0].border.style : @pdfannot.Style) {
    Beveled => ()
    _ => fail("expected beveled style")
  }
  match (parsed[1].border.style : @pdfannot.Style) {
    NoStyle => ()
    _ => fail("expected default style")
  }
  assert_eq(parsed[2].border.dasharray.length(), 2)
  assert_eq(parsed[2].border.dasharray[0], 4)
  assert_eq(parsed[2].border.dasharray[1], 5)
}

///|
test "add_annotation merges existing annots and extras" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let existing : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Text")),
    ("/Rect", rect),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest: Dictionary([("/Annots", Array([existing]))]),
  }
  let base_annot = @pdfannot.make(@pdfannot.Subtype::FreeText)
  let annot : @pdfannot.Annotation = {
    subtype: base_annot.subtype,
    annot_contents: base_annot.annot_contents,
    subject: base_annot.subject,
    rectangle: base_annot.rectangle,
    border: base_annot.border,
    colour: base_annot.colour,
    annotrest: Dictionary([("/Foo", Integer(9))]),
  }
  let updated = @pdfannot.add_annotation(pdf, page, annot)
  match (@pdf.lookup_direct(pdf, "/Annots", updated.rest) : @pdf.PdfObject?) {
    Some(Array([first, second])) => {
      match (@pdf.lookup_direct(pdf, "/Subtype", first) : @pdf.PdfObject?) {
        Some(Name("/FreeText")) => ()
        _ => fail("expected freetext subtype")
      }
      match (@pdf.lookup_direct(pdf, "/Foo", first) : @pdf.PdfObject?) {
        Some(Integer(9)) => ()
        _ => fail("expected extra field")
      }
      match (@pdf.lookup_direct(pdf, "/Subtype", second) : @pdf.PdfObject?) {
        Some(Name("/Text")) => ()
        _ => fail("expected existing annotation")
      }
    }
    _ => fail("expected annotations array")
  }
}

///|
test "annotations_of_page errors on non-dictionary annots" {
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest: Dictionary([("/Annots", Array([Integer(1)]))]),
  }
  let pdf = @pdf.Pdf::empty()
  assert_is_err(try? @pdfannot.annotations_of_page(pdf, page))
}

///|
test "transform_annotations leaves non-array quadpoints" {
  let pdf = @pdf.Pdf::empty()
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name("/Link")),
    ("/Rect", Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)])),
    ("/QuadPoints", Name("/Bad")),
  ])
  let objnum = @pdf.addobj(pdf, annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let tr = @pdftransform.TransformMatrix::translate(5.0, 5.0)
  @pdfannot.transform_annotations(pdf, tr, rest)
  let updated = @pdf.lookup_obj(pdf, objnum)
  match (@pdf.lookup_direct(pdf, "/QuadPoints", updated) : @pdf.PdfObject?) {
    Some(Name("/Bad")) => ()
    _ => fail("expected non-array quadpoints")
  }
}
