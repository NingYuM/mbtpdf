///|
fn freshname(source : () -> Int) -> String {
  "/r" + source().to_string()
}

///|
let resource_keys : Array[String] = [
  "/Font", "/ExtGState", "/ColorSpace", "/Pattern", "/Shading", "/XObject", "/Properties",
]

///|
fn make_changes(
  pdf : @pdf.Pdf,
  pages : Array[Page],
) -> Map[(String, Int, String), String] {
  let src = source(0)
  fn entries_of_page(
    entry : String,
    pageseq : Int,
    page : Page,
  ) -> Array[(String, Int, String, String)] {
    let entries = match @pdf.lookup_direct(pdf, entry, page.resources) {
      Some(@pdf.PdfObject::Dictionary(es)) => es
      _ => []
    }
    entries.map(pair => (entry, pageseq, pair.0, freshname(src)))
  }

  let pagenums = Array::makei(pages.length(), i => i + 1)
  let entries : Array[(String, Int, String, String)] = Array::new()
  for name in resource_keys {
    for i, page in pages {
      entries.append(entries_of_page(name, pagenums[i], page)[:])
    }
  }
  let table : Map[(String, Int, String), String] = Map::new()
  for entry in entries {
    let (dictname, pageseq, key, name) = entry
    table.set((dictname, pageseq, key), name)
  }
  table
}

///|
fn change_operator(
  pdf : @pdf.Pdf,
  lookup : (String, Int, String) -> String raise,
  lookup_option : (String, Int, String) -> String?,
  seqnum : Int,
  op : @pdfops.Op,
) -> @pdfops.Op raise {
  match op {
    OpTf(f, size) => OpTf(lookup("/Font", seqnum, f), size)
    Opgs(n) => Opgs(lookup("/ExtGState", seqnum, n))
    OpCS(n) =>
      match lookup_option("/ColorSpace", seqnum, n) {
        Some(x) => OpCS(x)
        None => OpCS(n)
      }
    Opcs(n) =>
      match lookup_option("/ColorSpace", seqnum, n) {
        Some(x) => Opcs(x)
        None => Opcs(n)
      }
    OpSCNName(s, ns) => OpSCNName(lookup("/Pattern", seqnum, s), ns)
    OpscnName(s, ns) => OpscnName(lookup("/Pattern", seqnum, s), ns)
    Opsh(s) => Opsh(lookup("/Shading", seqnum, s))
    OpDo(x) => OpDo(lookup("/XObject", seqnum, x))
    OpDP(n, @pdf.PdfObject::Name(p)) =>
      OpDP(n, @pdf.PdfObject::Name(lookup("/Properties", seqnum, p)))
    OpBDC(n, @pdf.PdfObject::Name(p)) =>
      match lookup_option("/Properties", seqnum, p) {
        Some(x) => OpBDC(n, @pdf.PdfObject::Name(x))
        None => {
          @pdfe.log("Warning: Missing OpBDC /Properties entry\n")
          OpBDC(n, @pdf.PdfObject::Name(p))
        }
      }
    InlineImage((dict, dp, bytes)) => {
      let dict_updated = match
        @pdf.lookup_direct_orelse(pdf, "/CS", "/ColorSpace", dict) {
        Some(@pdf.PdfObject::Name("/DeviceGray"))
        | Some(@pdf.PdfObject::Name("/DeviceRGB"))
        | Some(@pdf.PdfObject::Name("/DeviceCMYK"))
        | Some(@pdf.PdfObject::Name("/G"))
        | Some(@pdf.PdfObject::Name("/RGB"))
        | Some(@pdf.PdfObject::Name("/CMYK")) => dict
        Some(@pdf.PdfObject::Name(n)) => {
          let stripped = @pdf.remove_dict_entry(
            @pdf.remove_dict_entry(dict, "/ColorSpace"),
            "/CS",
          )
          @pdf.add_dict_entry(
            stripped,
            "/CS",
            @pdf.PdfObject::Name(lookup("/ColorSpace", seqnum, n)),
          )
        }
        _ => dict
      }
      InlineImage((dict_updated, dp, bytes))
    }
    _ => op
  }
}

///|
/// Make a collection of pages capable of being merged.
pub fn renumber_pages(pdf : @pdf.Pdf, pages : Array[Page]) -> Array[Page] raise {
  if pages.length() == 0 {
    return []
  }
  let changes = make_changes(pdf, pages)
  fn lookup_option(dictname : String, page : Int, oldkey : String) -> String? {
    changes.get((dictname, page, oldkey))
  }

  fn lookup(dictname : String, page : Int, oldkey : String) -> String raise {
    match changes.get((dictname, page, oldkey)) {
      Some(value) => value
      None => raise @pdf.PdfError::Msg("Pdfpage.renumber_pages: Bad key")
    }
  }

  fn change_content(
    seqnum : Int,
    resources : @pdf.PdfObject,
    content : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] raise {
    let operators = @pdfops.parse_operators(pdf, resources, content)
    let operators_updated = operators.map(op => change_operator(
      pdf, lookup, lookup_option, seqnum, op,
    ))
    [@pdfops.stream_of_ops(operators_updated)]
  }

  fn change_resources(
    seqnum : Int,
    resources : @pdf.PdfObject,
  ) -> @pdf.PdfObject raise {
    fn newdict(name : String) -> @pdf.PdfObject raise {
      match @pdf.lookup_direct(pdf, name, resources) {
        Some(@pdf.PdfObject::Dictionary(entries)) =>
          @pdf.PdfObject::Dictionary(
            entries.map(pair => (lookup(name, seqnum, pair.0), pair.1)),
          )
        _ => @pdf.PdfObject::Dictionary([])
      }
    }

    let newdicts = resource_keys.map(newdict)
    let mut updated = resources
    for i, key in resource_keys {
      updated = @pdf.add_dict_entry(updated, key, newdicts[i])
    }
    updated
  }

  let out : Array[Page] = Array::new(capacity=pages.length())
  for i, page in pages {
    let seqnum = i + 1
    out.push({
      content: change_content(seqnum, page.resources, page.content),
      resources: change_resources(seqnum, page.resources),
      mediabox: page.mediabox,
      rotate: page.rotate,
      rest: page.rest,
    })
  }
  out
}
