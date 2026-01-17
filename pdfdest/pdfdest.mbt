///|
/// Target pages for destinations.
pub(all) enum TargetPage {
  PageObject(Int)
  OtherDocPageNumber(Int)
}

///|
/// Destinations (and actions).
pub(all) enum Destination {
  Action(@pdf.PdfObject)
  NullDestination
  NamedDestination(String)
  StringDestination(String)
  XYZ(TargetPage, Double?, Double?, Double?)
  Fit(TargetPage)
  FitH(TargetPage, Double?)
  FitV(TargetPage, Double?)
  FitR(TargetPage, Double, Double, Double, Double)
  FitB(TargetPage)
  FitBH(TargetPage, Double?)
  FitBV(TargetPage, Double?)
}

///|
fn read_targetpage(obj : @pdf.PdfObject) -> TargetPage? {
  match obj {
    @pdf.PdfObject::Indirect(i) => Some(TargetPage::PageObject(i))
    @pdf.PdfObject::Integer(i) => Some(TargetPage::OtherDocPageNumber(i))
    _ => None
  }
}

///|
fn option_getnum(pdf : @pdf.Pdf, obj : @pdf.PdfObject) -> Double? raise {
  match obj {
    @pdf.PdfObject::Null => None
    _ => Some(@pdf.getnum(pdf, obj))
  }
}

///|
fn read_array_destination(
  pdf : @pdf.Pdf,
  arr : Array[@pdf.PdfObject],
) -> Destination? raise {
  if arr.length() == 5 {
    match arr[1] {
      @pdf.PdfObject::Name("/XYZ") =>
        match read_targetpage(arr[0]) {
          Some(p) =>
            return Some(
              Destination::XYZ(
                p,
                option_getnum(pdf, arr[2]),
                option_getnum(pdf, arr[3]),
                option_getnum(pdf, arr[4]),
              ),
            )
          None => ()
        }
      _ => ()
    }
  }
  if arr.length() == 4 {
    match arr[1] {
      @pdf.PdfObject::Name("/XYZ") =>
        match read_targetpage(arr[0]) {
          Some(p) =>
            return Some(
              Destination::XYZ(
                p,
                option_getnum(pdf, arr[2]),
                option_getnum(pdf, arr[3]),
                None,
              ),
            )
          None => ()
        }
      _ => ()
    }
  }
  if arr.length() == 3 {
    match arr[1] {
      @pdf.PdfObject::Name("/XYZ") =>
        match read_targetpage(arr[0]) {
          Some(p) =>
            return Some(
              Destination::XYZ(p, option_getnum(pdf, arr[2]), None, None),
            )
          None => ()
        }
      @pdf.PdfObject::Name("/FitH") =>
        match read_targetpage(arr[0]) {
          Some(p) =>
            return Some(Destination::FitH(p, option_getnum(pdf, arr[2])))
          None => ()
        }
      @pdf.PdfObject::Name("/FitV") =>
        match read_targetpage(arr[0]) {
          Some(p) =>
            return Some(Destination::FitV(p, option_getnum(pdf, arr[2])))
          None => ()
        }
      @pdf.PdfObject::Name("/FitBH") =>
        match read_targetpage(arr[0]) {
          Some(p) =>
            return Some(Destination::FitBH(p, option_getnum(pdf, arr[2])))
          None => ()
        }
      @pdf.PdfObject::Name("/FitBV") =>
        match read_targetpage(arr[0]) {
          Some(p) =>
            return Some(Destination::FitBV(p, option_getnum(pdf, arr[2])))
          None => ()
        }
      _ => ()
    }
  }
  if arr.length() == 2 {
    match arr[1] {
      @pdf.PdfObject::Name("/Fit") =>
        match read_targetpage(arr[0]) {
          Some(p) => return Some(Destination::Fit(p))
          None => ()
        }
      @pdf.PdfObject::Name("/FitB") =>
        match read_targetpage(arr[0]) {
          Some(p) => return Some(Destination::FitB(p))
          None => ()
        }
      _ => ()
    }
  }
  if arr.length() == 6 {
    match arr[1] {
      @pdf.PdfObject::Name("/FitR") =>
        match read_targetpage(arr[0]) {
          Some(p) =>
            return Some(
              Destination::FitR(
                p,
                @pdf.getnum(pdf, arr[2]),
                @pdf.getnum(pdf, arr[3]),
                @pdf.getnum(pdf, arr[4]),
                @pdf.getnum(pdf, arr[5]),
              ),
            )
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
/// Read a destination given a PDF and destination object.
pub fn read_destination(
  pdf : @pdf.Pdf,
  pdfobject : @pdf.PdfObject,
  shallow? : Bool = false,
) -> Destination raise {
  let resolved = @pdf.direct(pdf, pdfobject)
  match resolved {
    @pdf.PdfObject::Dictionary(_) =>
      match @pdf.lookup_direct(pdf, "/D", resolved) {
        Some(dest) => read_destination(pdf, dest, shallow~)
        None => Destination::NullDestination
      }
    @pdf.PdfObject::Array(arr) =>
      match read_array_destination(pdf, arr) {
        Some(dest) => dest
        None => {
          @pdfe.log(
            "Warning: Could not read destination \{@pdfwrite.string_of_pdf(resolved)}\n",
          )
          Destination::NullDestination
        }
      }
    @pdf.PdfObject::Name(name) =>
      if shallow {
        Destination::NamedDestination(name)
      } else {
        match @pdf.lookup_direct(pdf, "/Root", pdf.trailerdict) {
          Some(catalog) =>
            match @pdf.lookup_direct(pdf, "/Dests", catalog) {
              Some(dests) =>
                match @pdf.lookup_direct(pdf, name, dests) {
                  Some(dest) => read_destination(pdf, dest, shallow~)
                  None => Destination::NamedDestination(name)
                }
              None => Destination::NamedDestination(name)
            }
          None => raise @pdf.PdfError::Msg("read_destination: no catalog")
        }
      }
    @pdf.PdfObject::String(s) =>
      if shallow {
        Destination::StringDestination(s)
      } else {
        let rootdict = @pdf.lookup_obj(pdf, pdf.root)
        match @pdf.lookup_direct(pdf, "/Names", rootdict) {
          Some(namedict) =>
            match @pdf.lookup_direct(pdf, "/Dests", namedict) {
              Some(destsdict) =>
                match
                  @pdf.nametree_lookup(
                    pdf,
                    @pdf.PdfObject::String(s),
                    destsdict,
                  ) {
                  None => Destination::StringDestination(s)
                  Some(dest) => read_destination(pdf, dest, shallow~)
                }
              _ => Destination::StringDestination(s)
            }
          _ => Destination::StringDestination(s)
        }
      }
    _ => {
      @pdfe.log(
        "Warning: Could not read destination \{@pdfwrite.string_of_pdf(resolved)}\n",
      )
      Destination::NullDestination
    }
  }
}

///|
fn pdf_of_targetpage(target : TargetPage) -> @pdf.PdfObject {
  match target {
    TargetPage::PageObject(i) => @pdf.PdfObject::Indirect(i)
    TargetPage::OtherDocPageNumber(i) => @pdf.PdfObject::Integer(i)
  }
}

///|
fn pos_null(value : Double?) -> @pdf.PdfObject {
  match value {
    None => @pdf.PdfObject::Null
    Some(v) => @pdf.PdfObject::Real(v)
  }
}

///|
/// Write a destination to a PdfObject.
pub fn pdfobject_of_destination(dest : Destination) -> @pdf.PdfObject {
  match dest {
    Destination::Action(a) => a
    Destination::NullDestination => @pdf.PdfObject::Null
    Destination::NamedDestination(s) => @pdf.PdfObject::Name(s)
    Destination::StringDestination(s) => @pdf.PdfObject::String(s)
    Destination::XYZ(p, left, top, zoom) =>
      @pdf.PdfObject::Array([
        pdf_of_targetpage(p),
        @pdf.PdfObject::Name("/XYZ"),
        pos_null(left),
        pos_null(top),
        pos_null(zoom),
      ])
    Destination::Fit(p) =>
      @pdf.PdfObject::Array([pdf_of_targetpage(p), @pdf.PdfObject::Name("/Fit")])
    Destination::FitH(p, top) =>
      @pdf.PdfObject::Array([
        pdf_of_targetpage(p),
        @pdf.PdfObject::Name("/FitH"),
        pos_null(top),
      ])
    Destination::FitV(p, left) =>
      @pdf.PdfObject::Array([
        pdf_of_targetpage(p),
        @pdf.PdfObject::Name("/FitV"),
        pos_null(left),
      ])
    Destination::FitR(p, left, bottom, right, top) =>
      @pdf.PdfObject::Array([
        pdf_of_targetpage(p),
        @pdf.PdfObject::Name("/FitR"),
        @pdf.PdfObject::Real(left),
        @pdf.PdfObject::Real(bottom),
        @pdf.PdfObject::Real(right),
        @pdf.PdfObject::Real(top),
      ])
    Destination::FitB(p) =>
      @pdf.PdfObject::Array([
        pdf_of_targetpage(p),
        @pdf.PdfObject::Name("/FitB"),
      ])
    Destination::FitBH(p, top) =>
      @pdf.PdfObject::Array([
        pdf_of_targetpage(p),
        @pdf.PdfObject::Name("/FitBH"),
        pos_null(top),
      ])
    Destination::FitBV(p, left) =>
      @pdf.PdfObject::Array([
        pdf_of_targetpage(p),
        @pdf.PdfObject::Name("/FitBV"),
        pos_null(left),
      ])
  }
}

///|
fn clip_pair(pair : (Double, Double)) -> (Double, Double) {
  let (a, b) = pair
  let clip = fn(v : Double) -> Double {
    if v < -32768.0 {
      -32768.0
    } else if v > 32768.0 {
      32768.0
    } else {
      v
    }
  }
  (clip(a), clip(b))
}

///|
/// Transform a destination by a matrix.
pub fn transform_destination(
  pdf : @pdf.Pdf,
  t : @pdftransform.TransformMatrix,
  dest : Destination,
) -> Destination raise {
  match dest {
    Destination::FitH(TargetPage::PageObject(i), Some(top)) => {
      let (_, top) = clip_pair(@pdftransform.transform_matrix(t, (0.0, top)))
      Destination::FitH(TargetPage::PageObject(i), Some(top))
    }
    Destination::FitV(TargetPage::PageObject(i), Some(left)) => {
      let (left, _) = clip_pair(@pdftransform.transform_matrix(t, (left, 0.0)))
      Destination::FitV(TargetPage::PageObject(i), Some(left))
    }
    Destination::FitBH(TargetPage::PageObject(i), Some(top)) => {
      let (_, top) = clip_pair(@pdftransform.transform_matrix(t, (0.0, top)))
      Destination::FitBH(TargetPage::PageObject(i), Some(top))
    }
    Destination::FitBV(TargetPage::PageObject(i), Some(left)) => {
      let (left, _) = clip_pair(@pdftransform.transform_matrix(t, (left, 0.0)))
      Destination::FitBV(TargetPage::PageObject(i), Some(left))
    }
    Destination::XYZ(TargetPage::PageObject(i), Some(left), Some(top), zoom) => {
      let (left, top) = clip_pair(
        @pdftransform.transform_matrix(t, (left, top)),
      )
      Destination::XYZ(TargetPage::PageObject(i), Some(left), Some(top), zoom)
    }
    Destination::XYZ(TargetPage::PageObject(i), None, Some(top), zoom) => {
      let (_, top) = clip_pair(@pdftransform.transform_matrix(t, (0.0, top)))
      Destination::XYZ(TargetPage::PageObject(i), None, Some(top), zoom)
    }
    Destination::XYZ(TargetPage::PageObject(i), Some(left), None, zoom) => {
      let (left, _) = clip_pair(@pdftransform.transform_matrix(t, (left, 0.0)))
      Destination::XYZ(TargetPage::PageObject(i), Some(left), None, zoom)
    }
    Destination::FitR(TargetPage::PageObject(i), left, bottom, right, top) => {
      let (left, top) = clip_pair(
        @pdftransform.transform_matrix(t, (left, top)),
      )
      let (right, bottom) = clip_pair(
        @pdftransform.transform_matrix(t, (right, bottom)),
      )
      Destination::FitR(TargetPage::PageObject(i), left, bottom, right, top)
    }
    Destination::Action(a) =>
      match
        (@pdf.lookup_direct(pdf, "/S", a), @pdf.lookup_direct(pdf, "/D", a)) {
        (Some(@pdf.PdfObject::Name("/GoTo")), Some(d)) => {
          let transformed = transform_destination(
            pdf,
            t,
            read_destination(pdf, d, shallow=true),
          )
          Destination::Action(
            @pdf.add_dict_entry(a, "/D", pdfobject_of_destination(transformed)),
          )
        }
        _ => Destination::Action(a)
      }
    _ => dest
  }
}
