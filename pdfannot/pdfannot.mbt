///|
/// Annotation helpers.

///|
pub(all) enum Style {
  NoStyle
  Solid
  Dashed
  Beveled
  Inset
  UnderlineStyle
}

///|
pub(all) struct Border {
  width : Double
  vradius : Double
  hradius : Double
  style : Style
  dasharray : Array[Int]
}

///|
pub(all) enum Subtype {
  Text
  Link
  FreeText
  Line
  Square
  Circle
  Polygon
  PolyLine
  Highlight
  Underline
  Squiggly
  StrikeOut
  Stamp
  Caret
  Ink
  Popup(Annotation)
  FileAttachment
  Sound
  Movie
  Widget
  Screen
  PrinterMark
  TrapNet
  Watermark
  ThreeDee
  Unknown(String)
}

///|
pub(all) struct Annotation {
  subtype : Subtype
  annot_contents : String?
  subject : String?
  rectangle : (Double, Double, Double, Double)
  border : Border
  colour : (Int, Int, Int)?
  annotrest : @pdf.PdfObject
}

///|
fn toint(f : Double) -> Int {
  f.to_int()
}

///|
fn fmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn fmax(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn int_array_of_numbers(
  pdf : @pdf.Pdf,
  values : Array[@pdf.PdfObject],
) -> Array[Int] raise {
  let out = Array::new(capacity=values.length())
  for v in values {
    out.push(toint(@pdf.getnum(pdf, v)))
  }
  out
}

///|
fn read_annotation(pdf : @pdf.Pdf, annot : @pdf.PdfObject) -> Annotation raise {
  let subtype = match @pdf.lookup_direct(pdf, "/Subtype", annot) {
    Some(@pdf.PdfObject::Name("/Text")) => Subtype::Text
    Some(@pdf.PdfObject::Name("/FreeText")) => Subtype::FreeText
    Some(@pdf.PdfObject::Name("/Popup")) =>
      match @pdf.direct(pdf, annot) {
        @pdf.PdfObject::Dictionary(d) =>
          match
            @pdf.lookup_immediate("/Parent", @pdf.PdfObject::Dictionary(d)) {
            Some(@pdf.PdfObject::Indirect(i)) =>
              Subtype::Popup(read_annotation(pdf, @pdf.PdfObject::Indirect(i)))
            _ => Subtype::Unknown("")
          }
        _ => raise @pdf.PdfError::Msg("read_annotation failed")
      }
    Some(@pdf.PdfObject::Name("/Stamp")) => Subtype::Stamp
    Some(@pdf.PdfObject::Name("/Link")) => Subtype::Link
    Some(@pdf.PdfObject::Name("/Line")) => Subtype::Line
    Some(@pdf.PdfObject::Name("/Square")) => Subtype::Square
    Some(@pdf.PdfObject::Name("/Circle")) => Subtype::Circle
    Some(@pdf.PdfObject::Name("/Polygon")) => Subtype::Polygon
    Some(@pdf.PdfObject::Name("/PolyLine")) => Subtype::PolyLine
    Some(@pdf.PdfObject::Name("/Highlight")) => Subtype::Highlight
    Some(@pdf.PdfObject::Name("/Underline")) => Subtype::Underline
    Some(@pdf.PdfObject::Name("/Squiggly")) => Subtype::Squiggly
    Some(@pdf.PdfObject::Name("/StrikeOut")) => Subtype::StrikeOut
    Some(@pdf.PdfObject::Name("/Caret")) => Subtype::Caret
    Some(@pdf.PdfObject::Name("/Ink")) => Subtype::Ink
    Some(@pdf.PdfObject::Name("/FileAttachment")) => Subtype::FileAttachment
    Some(@pdf.PdfObject::Name("/Sound")) => Subtype::Sound
    Some(@pdf.PdfObject::Name("/Movie")) => Subtype::Movie
    Some(@pdf.PdfObject::Name("/Widget")) => Subtype::Widget
    Some(@pdf.PdfObject::Name("/Screen")) => Subtype::Screen
    Some(@pdf.PdfObject::Name("/PrinterMark")) => Subtype::PrinterMark
    Some(@pdf.PdfObject::Name("/TrapNet")) => Subtype::TrapNet
    Some(@pdf.PdfObject::Name("/Watermark")) => Subtype::Watermark
    Some(@pdf.PdfObject::Name("/3D")) => Subtype::ThreeDee
    Some(@pdf.PdfObject::Name(name)) => Subtype::Unknown(name)
    _ => Subtype::Unknown("")
  }
  let contents = match @pdf.lookup_direct(pdf, "/Contents", annot) {
    Some(@pdf.PdfObject::String(s)) => Some(s)
    _ => None
  }
  let subject = match @pdf.lookup_direct(pdf, "/Subj", annot) {
    Some(@pdf.PdfObject::String(s)) => Some(s)
    _ => None
  }
  let rectangle = @pdf.parse_rectangle(
    pdf,
    @pdf.lookup_fail("No /rect in annot", pdf, "/Rect", annot),
  )
  let border = match @pdf.lookup_direct(pdf, "/BS", annot) {
    Some(bsdict) => {
      let width = match @pdf.lookup_direct(pdf, "/W", bsdict) {
        Some(x) => @pdf.getnum(pdf, x)
        _ => 1.0
      }
      let style = match @pdf.lookup_direct(pdf, "/S", bsdict) {
        Some(@pdf.PdfObject::Name("/S")) => Style::Solid
        Some(@pdf.PdfObject::Name("/D")) => Style::Dashed
        Some(@pdf.PdfObject::Name("/B")) => Style::Beveled
        Some(@pdf.PdfObject::Name("/I")) => Style::Inset
        Some(@pdf.PdfObject::Name("/U")) => Style::UnderlineStyle
        _ => Style::NoStyle
      }
      let dasharray = match @pdf.lookup_direct(pdf, "/D", bsdict) {
        Some(@pdf.PdfObject::Array(dash)) => int_array_of_numbers(pdf, dash)
        _ => []
      }
      { width, vradius: 0.0, hradius: 0.0, style, dasharray }
    }
    None =>
      match @pdf.lookup_direct(pdf, "/Border", annot) {
        Some(@pdf.PdfObject::Array([h, v, w])) =>
          {
            width: @pdf.getnum(pdf, w),
            vradius: @pdf.getnum(pdf, v),
            hradius: @pdf.getnum(pdf, h),
            style: Style::NoStyle,
            dasharray: [],
          }
        Some(@pdf.PdfObject::Array([h, v, w, @pdf.PdfObject::Array(dash)])) =>
          {
            width: @pdf.getnum(pdf, w),
            vradius: @pdf.getnum(pdf, v),
            hradius: @pdf.getnum(pdf, h),
            style: Style::NoStyle,
            dasharray: int_array_of_numbers(pdf, dash),
          }
        _ =>
          {
            width: 1.0,
            vradius: 0.0,
            hradius: 0.0,
            style: Style::NoStyle,
            dasharray: [],
          }
      }
  }
  let colour = match @pdf.lookup_direct(pdf, "/C", annot) {
    Some(@pdf.PdfObject::Array([r, g, b])) =>
      Some(
        (
          toint(@pdf.getnum(pdf, r)),
          toint(@pdf.getnum(pdf, g)),
          toint(@pdf.getnum(pdf, b)),
        ),
      )
    _ => None
  }
  let annotrest = match @pdf.direct(pdf, annot) {
    @pdf.PdfObject::Dictionary(entries) => {
      let filtered = entries.filter(pair => match pair.0 {
        "/Subtype"
        | "/Contents"
        | "/Rect"
        | "/Border"
        | "/Subj"
        | "/BS"
        | "/C" => false
        _ => true
      })
      @pdf.PdfObject::Dictionary(filtered)
    }
    _ => raise @pdf.PdfError::Msg("Bad annotation dictionary")
  }
  {
    subtype,
    annot_contents: contents,
    subject,
    rectangle,
    border,
    colour,
    annotrest,
  }
}

///|
fn get_popup_parent(pdf : @pdf.Pdf, annotation : @pdf.PdfObject) -> Int? raise {
  match @pdf.direct(pdf, annotation) {
    @pdf.PdfObject::Dictionary(d) =>
      match @pdf.lookup_immediate("/Parent", @pdf.PdfObject::Dictionary(d)) {
        Some(@pdf.PdfObject::Indirect(i)) => Some(i)
        _ => None
      }
    _ => raise @pdf.PdfError::Msg("Pdfannot.get_popup_parent: not a dictionary")
  }
}

///|
/// Return the annotations on a page in a document.
pub fn annotations_of_page(
  pdf : @pdf.Pdf,
  page : @pdfpage.Page,
) -> Array[Annotation] raise {
  match @pdf.lookup_direct(pdf, "/Annots", page.rest) {
    Some(@pdf.PdfObject::Array(annotations)) => {
      let popup_parents : Map[Int, Unit] = Map::new()
      for annot in annotations {
        match get_popup_parent(pdf, annot) {
          Some(i) => popup_parents.set(i, ())
          None => ()
        }
      }
      let out = Array::new()
      for annot in annotations {
        match annot {
          @pdf.PdfObject::Indirect(i) =>
            if popup_parents.get(i) == None {
              out.push(read_annotation(pdf, annot))
            }
          _ => out.push(read_annotation(pdf, annot))
        }
      }
      out
    }
    _ => []
  }
}

///|
fn string_of_subtype(subtype : Subtype) -> String {
  match subtype {
    Subtype::Text => "/Text"
    Subtype::Link => "/Link"
    Subtype::FreeText => "/FreeText"
    Subtype::Line => "/Line"
    Subtype::Square => "/Square"
    Subtype::Circle => "/Circle"
    Subtype::Polygon => "/Polygon"
    Subtype::PolyLine => "/PolyLine"
    Subtype::Highlight => "/Highlight"
    Subtype::Underline => "/Underline"
    Subtype::Squiggly => "/Squiggly"
    Subtype::StrikeOut => "/StrikeOut"
    Subtype::Stamp => "/Stamp"
    Subtype::Caret => "/Caret"
    Subtype::Ink => "/Ink"
    Subtype::FileAttachment => "/FileAttachment"
    Subtype::Sound => "/Sound"
    Subtype::Movie => "/Movie"
    Subtype::Widget => "/Widget"
    Subtype::Screen => "/Screen"
    Subtype::PrinterMark => "/PrinterMark"
    Subtype::TrapNet => "/TrapNet"
    Subtype::Watermark => "/Watermark"
    Subtype::Unknown(_) => "/Unknown"
    Subtype::Popup(_) => "/Popup"
    Subtype::ThreeDee => "/3D"
  }
}

///|
fn obj_of_annot(annot : Annotation) -> @pdf.PdfObject raise {
  let dict_entries : Array[(String, @pdf.PdfObject)] = [
    ("/Subtype", @pdf.PdfObject::Name(string_of_subtype(annot.subtype))),
    (
      "/Contents",
      match annot.annot_contents {
        None => @pdf.PdfObject::Null
        Some(s) => @pdf.PdfObject::String(s)
      },
    ),
    (
      "/Rect",
      {
        let (a, b, c, d) = annot.rectangle
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Real(a),
          @pdf.PdfObject::Real(b),
          @pdf.PdfObject::Real(c),
          @pdf.PdfObject::Real(d),
        ])
      },
    ),
    (
      "/Border",
      match annot.border.dasharray {
        [] =>
          @pdf.PdfObject::Array([
            @pdf.PdfObject::Real(annot.border.hradius),
            @pdf.PdfObject::Real(annot.border.vradius),
            @pdf.PdfObject::Real(annot.border.width),
          ])
        dash =>
          @pdf.PdfObject::Array([
            @pdf.PdfObject::Real(annot.border.hradius),
            @pdf.PdfObject::Real(annot.border.vradius),
            @pdf.PdfObject::Real(annot.border.width),
            @pdf.PdfObject::Array(
              dash.map(value => @pdf.PdfObject::Integer(value)),
            ),
          ])
      },
    ),
  ]
  let dict_entries = match annot.annotrest {
    @pdf.PdfObject::Null => dict_entries
    @pdf.PdfObject::Dictionary(extra) => dict_entries + extra
    _ => raise @pdf.PdfError::Msg("Bad annotation dictionary")
  }
  let dict_entries = match annot.colour {
    None => dict_entries
    Some((r, g, b)) =>
      [
        (
          "/C",
          @pdf.PdfObject::Array([
            @pdf.PdfObject::Integer(r),
            @pdf.PdfObject::Integer(g),
            @pdf.PdfObject::Integer(b),
          ]),
        ),
      ] +
      dict_entries
  }
  let dict_entries = match annot.subject {
    None => dict_entries
    Some(s) => [("/Subj", @pdf.PdfObject::String(s))] + dict_entries
  }
  @pdf.PdfObject::Dictionary(dict_entries)
}

///|
/// Make a border.
pub fn make_border(
  width : Double,
  vradius? : Double = 0.0,
  hradius? : Double = 0.0,
  style? : Style = Style::NoStyle,
  dasharray? : Array[Int] = [],
) -> Border {
  { width, vradius, hradius, style, dasharray }
}

///|
/// Make an annotation of a given subtype.
pub fn make(
  subtype : Subtype,
  content? : String,
  border? : Border = make_border(0.0),
  rectangle? : (Double, Double, Double, Double) = (0.0, 0.0, 0.0, 0.0),
  colour? : (Int, Int, Int),
  subject? : String,
) -> Annotation {
  {
    annot_contents: content,
    border,
    rectangle,
    colour,
    subject,
    subtype,
    annotrest: @pdf.PdfObject::Null,
  }
}

///|
/// Add an annotation to a page in a document.
pub fn add_annotation(
  pdf : @pdf.Pdf,
  page : @pdfpage.Page,
  anno : Annotation,
) -> @pdfpage.Page raise {
  let obj = obj_of_annot(anno)
  let new_rest = match @pdf.lookup_direct(pdf, "/Annots", page.rest) {
    Some(@pdf.PdfObject::Array(annotations)) =>
      @pdf.add_dict_entry(
        page.rest,
        "/Annots",
        @pdf.PdfObject::Array([obj] + annotations),
      )
    Some(_) => raise @pdf.PdfError::Msg("Bad annotation dictionary")
    None =>
      @pdf.add_dict_entry(page.rest, "/Annots", @pdf.PdfObject::Array([obj]))
  }
  {
    content: page.content,
    mediabox: page.mediabox,
    resources: page.resources,
    rotate: page.rotate,
    rest: new_rest,
  }
}

///|
fn transform_rect(
  pdf : @pdf.Pdf,
  transform : @pdftransform.TransformMatrix,
  rect : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  let (minx, miny, maxx, maxy) = @pdf.parse_rectangle(pdf, rect)
  let (x0, y0) = @pdftransform.transform_matrix(transform, (minx, miny))
  let (x1, y1) = @pdftransform.transform_matrix(transform, (maxx, maxy))
  let (x2, y2) = @pdftransform.transform_matrix(transform, (minx, maxy))
  let (x3, y3) = @pdftransform.transform_matrix(transform, (maxx, miny))
  let minx = fmin(fmin(x0, x1), fmin(x2, x3))
  let miny = fmin(fmin(y0, y1), fmin(y2, y3))
  let maxx = fmax(fmax(x0, x1), fmax(x2, x3))
  let maxy = fmax(fmax(y0, y1), fmax(y2, y3))
  @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(minx),
    @pdf.PdfObject::Real(miny),
    @pdf.PdfObject::Real(maxx),
    @pdf.PdfObject::Real(maxy),
  ])
}

///|
fn transform_quadpoint_single(
  pdf : @pdf.Pdf,
  transform : @pdftransform.TransformMatrix,
  qp : Array[@pdf.PdfObject],
) -> Array[@pdf.PdfObject] raise {
  if qp.length() != 8 {
    @pdfe.log("Malformed /QuadPoints format: must be a multiple of 8 entries\n")
    return qp
  }
  let x1 = @pdf.getnum(pdf, qp[0])
  let y1 = @pdf.getnum(pdf, qp[1])
  let x2 = @pdf.getnum(pdf, qp[2])
  let y2 = @pdf.getnum(pdf, qp[3])
  let x3 = @pdf.getnum(pdf, qp[4])
  let y3 = @pdf.getnum(pdf, qp[5])
  let x4 = @pdf.getnum(pdf, qp[6])
  let y4 = @pdf.getnum(pdf, qp[7])
  let (x1, y1) = @pdftransform.transform_matrix(transform, (x1, y1))
  let (x2, y2) = @pdftransform.transform_matrix(transform, (x2, y2))
  let (x3, y3) = @pdftransform.transform_matrix(transform, (x3, y3))
  let (x4, y4) = @pdftransform.transform_matrix(transform, (x4, y4))
  [
    @pdf.PdfObject::Real(x1),
    @pdf.PdfObject::Real(y1),
    @pdf.PdfObject::Real(x2),
    @pdf.PdfObject::Real(y2),
    @pdf.PdfObject::Real(x3),
    @pdf.PdfObject::Real(y3),
    @pdf.PdfObject::Real(x4),
    @pdf.PdfObject::Real(y4),
  ]
}

///|
fn[T] split_into(values : Array[T], size : Int) -> Array[Array[T]] {
  let out = Array::new()
  let mut i = 0
  while i < values.length() {
    let part = Array::new(capacity=size)
    let mut j = 0
    while j < size && i + j < values.length() {
      part.push(values[i + j])
      j = j + 1
    }
    out.push(part)
    i = i + size
  }
  out
}

///|
fn transform_quadpoints(
  pdf : @pdf.Pdf,
  transform : @pdftransform.TransformMatrix,
  qp : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  match qp {
    @pdf.PdfObject::Array(qps) => {
      let out = Array::new()
      for chunk in split_into(qps, 8) {
        out.append(transform_quadpoint_single(pdf, transform, chunk))
      }
      @pdf.PdfObject::Array(out)
    }
    _ => {
      @pdfe.log("Unknown or malformed /QuadPoints format\n")
      qp
    }
  }
}

///|
/// Transform all annotations in a page dictionary.
pub fn transform_annotations(
  pdf : @pdf.Pdf,
  transform : @pdftransform.TransformMatrix,
  rest : @pdf.PdfObject,
) -> Unit raise {
  match @pdf.lookup_direct(pdf, "/Annots", rest) {
    Some(@pdf.PdfObject::Array(annots)) =>
      for annot in annots {
        match annot {
          @pdf.PdfObject::Indirect(i) => {
            let annot_obj = @pdf.lookup_obj(pdf, i)
            let rect_updated = match
              @pdf.lookup_direct(pdf, "/Rect", annot_obj) {
              Some(rect) => Some(transform_rect(pdf, transform, rect))
              None => None
            }
            let quadpoints_updated = match
              @pdf.lookup_direct(pdf, "/QuadPoints", annot_obj) {
              Some(qp) => Some(transform_quadpoints(pdf, transform, qp))
              None => None
            }
            let line_updated = match @pdf.lookup_direct(pdf, "/L", annot_obj) {
              Some(line) => Some(transform_rect(pdf, transform, line))
              _ => None
            }
            let annot_obj = match rect_updated {
              None => annot_obj
              Some(rect) => @pdf.add_dict_entry(annot_obj, "/Rect", rect)
            }
            let annot_obj = match quadpoints_updated {
              Some(qp) => @pdf.add_dict_entry(annot_obj, "/QuadPoints", qp)
              None => annot_obj
            }
            let annot_obj = match line_updated {
              Some(line) => @pdf.add_dict_entry(annot_obj, "/L", line)
              None => annot_obj
            }
            @pdf.addobj_given_num(pdf, (i, annot_obj))
          }
          _ => @pdfe.log("transform_annotations: not indirect\n")
        }
      }
    _ => ()
  }
}
