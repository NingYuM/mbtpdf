///|
/// Annotation helpers.

///|
type PdfObject = @pdf.PdfObject

///|
pub struct PdfAnnot {
  pdf : @pdf.Pdf
}

///|
pub fn PdfAnnot::new(pdf : @pdf.Pdf) -> PdfAnnot {
  { pdf, }
}

///|
pub(all) enum Style {
  NoStyle
  Solid
  Dashed
  Beveled
  Inset
  UnderlineStyle
} derive(Debug)

///|
pub(all) struct Border {
  width : Double
  vradius : Double
  hradius : Double
  style : Style
  dasharray : Array[Int]
} derive(Debug)

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
  annotrest : PdfObject
}

///|
fn toint(f : Double) -> Int {
  f.to_int()
}

///|
fn int_array_of_numbers(
  pdf : @pdf.Pdf,
  values : Array[PdfObject],
) -> Array[Int] raise {
  let out = Array::new(capacity=values.length())
  for v in values {
    out.push(toint(pdf.getnum(v)))
  }
  out
}

///|
fn read_annotation(pdf : @pdf.Pdf, annot : PdfObject) -> Annotation raise {
  let subtype : Subtype = match pdf.lookup_direct("/Subtype", annot) {
    Some(Name("/Text")) => Text
    Some(Name("/FreeText")) => FreeText
    Some(Name("/Popup")) =>
      match pdf.direct(annot) {
        Dictionary(d) =>
          match PdfObject::Dictionary(d).lookup_immediate("/Parent") {
            Some(Indirect(i)) => Popup(read_annotation(pdf, Indirect(i)))
            _ => Unknown("")
          }
        _ => raise @pdf.PdfError::Msg("read_annotation failed")
      }
    Some(Name("/Stamp")) => Stamp
    Some(Name("/Link")) => Link
    Some(Name("/Line")) => Line
    Some(Name("/Square")) => Square
    Some(Name("/Circle")) => Circle
    Some(Name("/Polygon")) => Polygon
    Some(Name("/PolyLine")) => PolyLine
    Some(Name("/Highlight")) => Highlight
    Some(Name("/Underline")) => Underline
    Some(Name("/Squiggly")) => Squiggly
    Some(Name("/StrikeOut")) => StrikeOut
    Some(Name("/Caret")) => Caret
    Some(Name("/Ink")) => Ink
    Some(Name("/FileAttachment")) => FileAttachment
    Some(Name("/Sound")) => Sound
    Some(Name("/Movie")) => Movie
    Some(Name("/Widget")) => Widget
    Some(Name("/Screen")) => Screen
    Some(Name("/PrinterMark")) => PrinterMark
    Some(Name("/TrapNet")) => TrapNet
    Some(Name("/Watermark")) => Watermark
    Some(Name("/3D")) => ThreeDee
    Some(Name(name)) => Unknown(name)
    _ => Unknown("")
  }
  let contents = match pdf.lookup_direct("/Contents", annot) {
    Some(String(s)) => Some(s)
    _ => None
  }
  let subject = match pdf.lookup_direct("/Subj", annot) {
    Some(String(s)) => Some(s)
    _ => None
  }
  let rectangle = pdf.parse_rectangle(
    pdf.lookup_fail("No /rect in annot", "/Rect", annot),
  )
  let border = match pdf.lookup_direct("/BS", annot) {
    Some(bsdict) => {
      let width = match pdf.lookup_direct("/W", bsdict) {
        Some(x) => pdf.getnum(x)
        _ => 1.0
      }
      let style : Style = match pdf.lookup_direct("/S", bsdict) {
        Some(Name("/S")) => Solid
        Some(Name("/D")) => Dashed
        Some(Name("/B")) => Beveled
        Some(Name("/I")) => Inset
        Some(Name("/U")) => UnderlineStyle
        _ => NoStyle
      }
      let dasharray = match pdf.lookup_direct("/D", bsdict) {
        Some(Array(dash)) => int_array_of_numbers(pdf, dash)
        _ => []
      }
      { width, vradius: 0.0, hradius: 0.0, style, dasharray }
    }
    None =>
      match pdf.lookup_direct("/Border", annot) {
        Some(Array([h, v, w])) =>
          {
            width: pdf.getnum(w),
            vradius: pdf.getnum(v),
            hradius: pdf.getnum(h),
            style: NoStyle,
            dasharray: [],
          }
        Some(Array([h, v, w, Array(dash)])) =>
          {
            width: pdf.getnum(w),
            vradius: pdf.getnum(v),
            hradius: pdf.getnum(h),
            style: NoStyle,
            dasharray: int_array_of_numbers(pdf, dash),
          }
        _ =>
          {
            width: 1.0,
            vradius: 0.0,
            hradius: 0.0,
            style: NoStyle,
            dasharray: [],
          }
      }
  }
  let colour = match pdf.lookup_direct("/C", annot) {
    Some(Array([r, g, b])) =>
      Some((toint(pdf.getnum(r)), toint(pdf.getnum(g)), toint(pdf.getnum(b))))
    _ => None
  }
  let annotrest : PdfObject = match pdf.direct(annot) {
    Dictionary(entries) => {
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
      Dictionary(filtered)
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
fn get_popup_parent(pdf : @pdf.Pdf, annotation : PdfObject) -> Int? raise {
  match pdf.direct(annotation) {
    Dictionary(d) =>
      match PdfObject::Dictionary(d).lookup_immediate("/Parent") {
        Some(Indirect(i)) => Some(i)
        _ => None
      }
    _ => raise @pdf.PdfError::Msg("Pdfannot.get_popup_parent: not a dictionary")
  }
}

///|
/// Return the annotations on a page in a document.
#as_free_fn(annotations_of_page, deprecated="Use `PdfAnnot::annotations_of_page`")
pub fn PdfAnnot::annotations_of_page(
  self : PdfAnnot,
  page : @pdfpage.Page,
) -> Array[Annotation] raise {
  match self.pdf.lookup_direct("/Annots", page.rest) {
    Some(Array(annotations)) => {
      let popup_parents : Map[Int, Unit] = Map::new()
      for annot in annotations {
        match get_popup_parent(self.pdf, annot) {
          Some(i) => popup_parents.set(i, ())
          None => ()
        }
      }
      let out = Array::new()
      for annot in annotations {
        match (annot : PdfObject) {
          Indirect(i) =>
            if popup_parents.get(i) is None {
              out.push(read_annotation(self.pdf, annot))
            }
          _ => out.push(read_annotation(self.pdf, annot))
        }
      }
      out
    }
    _ => []
  }
}

///|

///|
#as_free_fn(string_of_subtype, deprecated="Use `Subtype::to_string` instead")
fn Subtype::to_string(self : Subtype) -> String {
  match self {
    Text => "/Text"
    Link => "/Link"
    FreeText => "/FreeText"
    Line => "/Line"
    Square => "/Square"
    Circle => "/Circle"
    Polygon => "/Polygon"
    PolyLine => "/PolyLine"
    Highlight => "/Highlight"
    Underline => "/Underline"
    Squiggly => "/Squiggly"
    StrikeOut => "/StrikeOut"
    Stamp => "/Stamp"
    Caret => "/Caret"
    Ink => "/Ink"
    FileAttachment => "/FileAttachment"
    Sound => "/Sound"
    Movie => "/Movie"
    Widget => "/Widget"
    Screen => "/Screen"
    PrinterMark => "/PrinterMark"
    TrapNet => "/TrapNet"
    Watermark => "/Watermark"
    Unknown(_) => "/Unknown"
    Popup(_) => "/Popup"
    ThreeDee => "/3D"
  }
}

///|

///|
#as_free_fn(obj_of_annot, deprecated="Use `Annotation::to_pdf_object` instead")
fn Annotation::to_pdf_object(self : Annotation) -> PdfObject raise {
  let dict_entries : Array[(String, PdfObject)] = [
    ("/Subtype", PdfObject::Name(self.subtype.to_string())),
    (
      "/Contents",
      match self.annot_contents {
        None => PdfObject::Null
        Some(s) => PdfObject::String(s)
      },
    ),
    (
      "/Rect",
      {
        let (a, b, c, d) = self.rectangle
        PdfObject::Array([
          PdfObject::Real(a),
          PdfObject::Real(b),
          PdfObject::Real(c),
          PdfObject::Real(d),
        ])
      },
    ),
    (
      "/Border",
      match self.border.dasharray {
        [] =>
          PdfObject::Array([
            PdfObject::Real(self.border.hradius),
            PdfObject::Real(self.border.vradius),
            PdfObject::Real(self.border.width),
          ])
        dash =>
          PdfObject::Array([
            PdfObject::Real(self.border.hradius),
            PdfObject::Real(self.border.vradius),
            PdfObject::Real(self.border.width),
            PdfObject::Array(dash.map(value => PdfObject::Integer(value))),
          ])
      },
    ),
  ]
  let dict_entries = match (self.annotrest : PdfObject) {
    Null => dict_entries
    Dictionary(extra) => dict_entries + extra
    _ => raise @pdf.PdfError::Msg("Bad annotation dictionary")
  }
  let dict_entries = match self.colour {
    None => dict_entries
    Some((r, g, b)) =>
      [
        (
          "/C",
          PdfObject::Array([
            PdfObject::Integer(r),
            PdfObject::Integer(g),
            PdfObject::Integer(b),
          ]),
        ),
      ] +
      dict_entries
  }
  let dict_entries = match self.subject {
    None => dict_entries
    Some(s) => [("/Subj", PdfObject::String(s))] + dict_entries
  }
  PdfObject::Dictionary(dict_entries)
}

///|
/// Make a border.
#as_free_fn(make_border, deprecated="Use `Border::new` instead")
pub fn Border::new(
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
#as_free_fn(make, deprecated="Use `Annotation::new` instead")
pub fn Annotation::new(
  subtype : Subtype,
  content? : String,
  border? : Border = Border::new(0.0),
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
    annotrest: PdfObject::Null,
  }
}

///|
/// Add an annotation to a page in a document.
#as_free_fn(add_annotation, deprecated="Use `PdfAnnot::add_annotation`")
pub fn PdfAnnot::add_annotation(
  self : PdfAnnot,
  page : @pdfpage.Page,
  anno : Annotation,
) -> @pdfpage.Page raise {
  let obj = anno.to_pdf_object()
  let new_rest = match self.pdf.lookup_direct("/Annots", page.rest) {
    Some(Array(annotations)) =>
      page.rest.add_entry("/Annots", PdfObject::Array([obj] + annotations))
    Some(_) => raise @pdf.PdfError::Msg("Bad annotation dictionary")
    None => page.rest.add_entry("/Annots", PdfObject::Array([obj]))
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
/// Transform all annotations in a page dictionary.
#as_free_fn(transform_annotations, deprecated="Use `PdfAnnot::transform_annotations`")
pub fn PdfAnnot::transform_annotations(
  self : PdfAnnot,
  transform : @pdftransform.TransformMatrix,
  rest : PdfObject,
) -> Unit raise {
  match self.pdf.lookup_direct("/Annots", rest) {
    Some(Array(annots)) =>
      for annot in annots {
        match (annot : PdfObject) {
          Indirect(i) => {
            let annot_obj = self.pdf.lookup_obj(i)
            let rect_updated = match
              self.pdf.lookup_direct("/Rect", annot_obj) {
              Some(rect) => Some(self.pdf.transform_rect(transform, rect))
              None => None
            }
            let quadpoints_updated = match
              self.pdf.lookup_direct("/QuadPoints", annot_obj) {
              Some(qp) => Some(self.pdf.transform_quadpoints(transform, qp))
              None => None
            }
            let line_updated = match self.pdf.lookup_direct("/L", annot_obj) {
              Some(line) => Some(self.pdf.transform_rect(transform, line))
              _ => None
            }
            let annot_obj = match rect_updated {
              None => annot_obj
              Some(rect) => annot_obj.add_entry("/Rect", rect)
            }
            let annot_obj = match quadpoints_updated {
              Some(qp) => annot_obj.add_entry("/QuadPoints", qp)
              None => annot_obj
            }
            let annot_obj = match line_updated {
              Some(line) => annot_obj.add_entry("/L", line)
              None => annot_obj
            }
            self.pdf.addobj_given_num((i, annot_obj))
          }
          _ => @pdfe.Pdfe::new().log("transform_annotations: not indirect\n")
        }
      }
    _ => ()
  }
}
