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
            Some(@pdf.PdfObject::Integer(r)) => Rotation::from_int(r)
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
            Some(@pdf.PdfObject::Integer(r)) => Rotation::from_int(r)
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
#as_free_fn(pages_of_pagetree, deprecated="Use `PdfPageDoc::pages_of_pagetree`")
pub fn PdfPageDoc::pages_of_pagetree(self : PdfPageDoc) -> Array[Page] raise {
  let pdf = self.pdf
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
  stack : Map[Int, Bool],
) -> Int raise {
  if count == 10000 {
    raise @pdf.PdfError::Msg("cycle in page tree")
  }
  let mut resolved = pages
  let mut objnum : Int? = None
  match pages {
    @pdf.PdfObject::Indirect(k) => {
      if stack.contains(k) {
        raise @pdf.PdfError::Msg("cycle in page tree")
      }
      stack.set(k, true)
      objnum = Some(k)
      let resolved_obj = @pdf.lookup_obj(pdf, k)
      match resolved_obj {
        @pdf.PdfObject::Null => raise @pdf.PdfError::Msg("missing kid")
        _ => resolved = resolved_obj
      }
    }
    _ => ()
  }
  let total = match resolved {
    @pdf.PdfObject::Null => 0
    _ => {
      let typ = @pdf.lookup_direct(pdf, "/Type", resolved)
      match typ {
        Some(@pdf.PdfObject::Name("/Pages")) | None => {
          let kids = match
            @pdf.lookup_fail("No /Kids in page tree", pdf, "/Kids", resolved) {
            @pdf.PdfObject::Array(values) => values
            _ => raise @pdf.PdfError::Msg("Malformed /Kids in page tree node")
          }
          let mut total = 0
          for kid in kids {
            match kid {
              @pdf.PdfObject::Indirect(_) | @pdf.PdfObject::Dictionary(_) =>
                total = total + find_pages_quick(count + 1, kid, pdf, stack)
              _ => raise @pdf.PdfError::Msg("malformed kid")
            }
          }
          total
        }
        _ => 1
      }
    }
  }
  match objnum {
    Some(k) => stack.remove(k)
    None => ()
  }
  total
}

///|
/// Count pages in the page tree quickly.
#as_free_fn(pages_of_pagetree_quick, deprecated="Use `PdfPageDoc::pages_of_pagetree_quick`")
pub fn PdfPageDoc::pages_of_pagetree_quick(self : PdfPageDoc) -> Int raise {
  let pdf = self.pdf
  let document_catalog = @pdf.lookup_obj(pdf, pdf.root)
  match document_catalog {
    @pdf.PdfObject::Null => raise @pdf.PdfError::Msg("/Root entry is incorrect")
    _ => {
      let pages = @pdf.lookup_fail(
        "No or malformed /Pages", pdf, "/Pages", document_catalog,
      )
      let stack : Map[Int, Bool] = Map::new()
      find_pages_quick(0, pages, pdf, stack)
    }
  }
}

///|
/// The last page number.
#as_free_fn(endpage, deprecated="Use `PdfPageDoc::endpage`")
pub fn PdfPageDoc::endpage(self : PdfPageDoc) -> Int raise {
  self.pages_of_pagetree_quick()
}

///|
fn endpage_safe(pdf : @pdf.Pdf) -> Int {
  PdfPageDoc::new(pdf).endpage() catch {
    _ => 0
  }
}

///|
/// Fast page count from the top /Count.
#as_free_fn(endpage_fast, deprecated="Use `PdfPageDoc::endpage_fast`")
pub fn PdfPageDoc::endpage_fast(self : PdfPageDoc) -> Int raise {
  let pdf = self.pdf
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
  @pdf.endpage.val = endpage_safe
}
