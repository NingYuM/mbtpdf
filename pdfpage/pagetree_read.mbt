///|
fn remove_dict_entries(
  entries : Array[(String, @pdf.PdfObject)],
) -> Array[(String, @pdf.PdfObject)] {
  entries.filter(entry => {
    let key = entry.0
    let keep = key != "/Resources" &&
      key != "/Contents" &&
      key != "/MediaBox" &&
      key != "/Rotate" &&
      key != "/Parent" &&
      key != "/Type"
    keep
  })
}

///|
let last_mediabox_seen : Ref[@pdf.PdfObject] = {
  val: @pdf.PdfObject::Array([
    @pdf.PdfObject::Integer(0),
    @pdf.PdfObject::Integer(0),
    @pdf.PdfObject::Integer(612),
    @pdf.PdfObject::Integer(792),
  ]),
}

///|
fn find_pages(
  pages : @pdf.PdfObject,
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject?,
  mediabox : @pdf.PdfObject?,
  rotate : Rotation,
) -> Array[Page] raise {
  match pages {
    @pdf.PdfObject::Null => []
    _ => {
      let typ = @pdf.lookup_direct(pdf, "/Type", pages)
      match typ {
        Some(@pdf.PdfObject::Name("/Pages")) | None => {
          let kids = match
            @pdf.lookup_fail("No /Kids in page tree", pdf, "/Kids", pages) {
            @pdf.PdfObject::Array(values) => values
            _ => raise @pdf.PdfError::Msg("Malformed /Kids in page tree node")
          }
          let kid_objects = Array::new(capacity=kids.length())
          for kid in kids {
            match kid {
              @pdf.PdfObject::Indirect(k) => {
                let obj = @pdf.lookup_obj(pdf, k)
                match obj {
                  @pdf.PdfObject::Null =>
                    raise @pdf.PdfError::Msg("missing kid")
                  _ => kid_objects.push(obj)
                }
              }
              @pdf.PdfObject::Dictionary(d) =>
                kid_objects.push(@pdf.PdfObject::Dictionary(d))
              _ => raise @pdf.PdfError::Msg("malformed kid")
            }
          }
          let resources = match @pdf.lookup_direct(pdf, "/Resources", pages) {
            Some(x) => Some(x)
            None => resources
          }
          let mediabox = match @pdf.lookup_direct(pdf, "/MediaBox", pages) {
            Some(x) => Some(x)
            None => mediabox
          }
          let rotate = match @pdf.lookup_direct(pdf, "/Rotate", pages) {
            Some(@pdf.PdfObject::Integer(r)) => rotation_of_int(r)
            _ => rotate
          }
          let out = Array::new()
          for kid_obj in kid_objects {
            out.append(find_pages(kid_obj, pdf, resources, mediabox, rotate)[:])
          }
          out
        }
        _ => {
          let resources = match @pdf.lookup_direct(pdf, "/Resources", pages) {
            Some(x) => Some(x)
            None => resources
          }
          let mediabox = match @pdf.lookup_direct(pdf, "/MediaBox", pages) {
            Some(x) => Some(x)
            None => mediabox
          }
          let contents = match pages {
            @pdf.PdfObject::Dictionary(_) =>
              match @pdf.lookup_immediate("/Contents", pages) {
                Some(@pdf.PdfObject::Indirect(i)) =>
                  match @pdf.lookup_obj(pdf, i) {
                    @pdf.PdfObject::Array(a) => Some(@pdf.PdfObject::Array(a))
                    _ =>
                      Some(@pdf.PdfObject::Array([@pdf.PdfObject::Indirect(i)]))
                  }
                _ => @pdf.lookup_direct(pdf, "/Contents", pages)
              }
            _ => raise @pdf.PdfError::Msg("Pages not a dictionary")
          }
          let rotate = match @pdf.lookup_direct(pdf, "/Rotate", pages) {
            Some(@pdf.PdfObject::Integer(r)) => rotation_of_int(r)
            _ => rotate
          }
          let content = match contents {
            None => []
            Some(@pdf.PdfObject::Array(cs)) =>
              cs.filter_map(c => match @pdf.direct(pdf, c) {
                @pdf.PdfObject::Stream(_) => Some(c)
                _ => {
                  @pdfe.log("Page /Contents not a stream: ignoring.\n")
                  None
                }
              })
            Some(obj) =>
              match @pdf.direct(pdf, obj) {
                @pdf.PdfObject::Stream(_) => [obj]
                _ => {
                  @pdfe.log("Page /Contents not a stream: ignoring.\n")
                  []
                }
              }
          }
          let mediabox = match mediabox {
            Some(m) => {
              last_mediabox_seen.val = m
              m
            }
            None => {
              @pdfe.log(
                "Warning: missing mediabox. Using most recently seen.\n",
              )
              last_mediabox_seen.val
            }
          }
          let resources = match resources {
            Some(r) => r
            None => @pdf.PdfObject::Dictionary([])
          }
          let rest = match pages {
            @pdf.PdfObject::Dictionary(d) =>
              @pdf.PdfObject::Dictionary(remove_dict_entries(d))
            _ => raise @pdf.PdfError::Msg("Bad /Pages")
          }
          [{ resources, content, mediabox, rotate, rest }]
        }
      }
    }
  }
}

///|
/// Given a pdf, return a list of page objects.
pub fn pages_of_pagetree(pdf : @pdf.Pdf) -> Array[Page] raise {
  let document_catalog = @pdf.lookup_obj(pdf, pdf.root)
  match document_catalog {
    @pdf.PdfObject::Null => raise @pdf.PdfError::Msg("/Root entry is incorrect")
    _ => {
      let pages = @pdf.lookup_fail(
        "No or malformed /Pages", pdf, "/Pages", document_catalog,
      )
      find_pages(pages, pdf, None, None, Rotation::Rotate0)
    }
  }
}

///|
fn find_pages_quick(
  count : Int,
  pages : @pdf.PdfObject,
  pdf : @pdf.Pdf,
) -> Int raise {
  if count == 10000 {
    raise @pdf.PdfError::Msg("cycle in page tree")
  }
  match pages {
    @pdf.PdfObject::Null => 0
    _ => {
      let typ = @pdf.lookup_direct(pdf, "/Type", pages)
      match typ {
        Some(@pdf.PdfObject::Name("/Pages")) | None => {
          let kids = match
            @pdf.lookup_fail("No /Kids in page tree", pdf, "/Kids", pages) {
            @pdf.PdfObject::Array(values) => values
            _ => raise @pdf.PdfError::Msg("Malformed /Kids in page tree node")
          }
          let mut total = 0
          for kid in kids {
            let obj = match kid {
              @pdf.PdfObject::Indirect(k) => {
                let kid_obj = @pdf.lookup_obj(pdf, k)
                match kid_obj {
                  @pdf.PdfObject::Null =>
                    raise @pdf.PdfError::Msg("missing kid")
                  _ => kid_obj
                }
              }
              @pdf.PdfObject::Dictionary(d) => @pdf.PdfObject::Dictionary(d)
              _ => raise @pdf.PdfError::Msg("malformed kid")
            }
            total = total + find_pages_quick(count + 1, obj, pdf)
          }
          total
        }
        _ => 1
      }
    }
  }
}

///|
/// Count pages in the page tree quickly.
pub fn pages_of_pagetree_quick(pdf : @pdf.Pdf) -> Int raise {
  let document_catalog = @pdf.lookup_obj(pdf, pdf.root)
  match document_catalog {
    @pdf.PdfObject::Null => raise @pdf.PdfError::Msg("/Root entry is incorrect")
    _ => {
      let pages = @pdf.lookup_fail(
        "No or malformed /Pages", pdf, "/Pages", document_catalog,
      )
      find_pages_quick(0, pages, pdf)
    }
  }
}

///|
/// The last page number.
pub fn endpage(pdf : @pdf.Pdf) -> Int raise {
  pages_of_pagetree_quick(pdf)
}

///|
fn endpage_safe(pdf : @pdf.Pdf) -> Int {
  endpage(pdf) catch {
    _ => 0
  }
}

///|
/// Fast page count from the top /Count.
pub fn endpage_fast(pdf : @pdf.Pdf) -> Int raise {
  let document_catalog = @pdf.lookup_obj(pdf, pdf.root)
  match document_catalog {
    @pdf.PdfObject::Null => raise @pdf.PdfError::Msg("/Root entry is incorrect")
    _ => {
      let pages = @pdf.lookup_fail(
        "No or malformed /Pages", pdf, "/Pages", document_catalog,
      )
      match @pdf.lookup_direct(pdf, "/Count", pages) {
        Some(@pdf.PdfObject::Integer(i)) => i
        _ => 0
      }
    }
  }
}

///|
let _register_endpage : Unit = {
  @pdfread.endpage.val = endpage_safe
}
