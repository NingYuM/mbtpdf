///|
/// Extract text from PDFs using content stream operators.

///|
pub fn extract_text(
  pdf : @pdf.Pdf,
  page_break? : String = "\n\n",
) -> String raise {
  join_pages(extract_text_by_page(pdf), page_break)
}

///|
pub fn extract_text_by_page(pdf : @pdf.Pdf) -> Array[String] raise {
  let pages = @pdfpage.pages_of_pagetree(pdf)
  let out : Array[String] = Array::new()
  for page in pages {
    out.push(extract_text_from_page(pdf, page))
  }
  out
}

///|
fn join_pages(pages : Array[String], page_break : String) -> String {
  let builder = StringBuilder::new()
  let mut first = true
  for page_text in pages {
    if first {
      first = false
    } else {
      builder.write_string(page_break)
    }
    builder.write_string(page_text)
  }
  builder.to_string()
}

///|
fn extract_text_from_page(pdf : @pdf.Pdf, page : @pdfpage.Page) -> String raise {
  let builder = StringBuilder::new()
  let visited : Map[Int, Bool] = Map::new()
  append_text_from_streams(builder, pdf, page.resources, page.content, visited)
  builder.to_string()
}

///|
fn append_text_from_streams(
  builder : StringBuilder,
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  streams : Array[@pdf.PdfObject],
  visited : Map[Int, Bool],
) -> Unit raise {
  let ops = @pdfops.parse_operators(pdf, resources, streams)
  let mut in_text = false
  let mut current_extractor : TextExtractor? = None
  let mut last_newline = false
  let extractor_cache : Map[String, TextExtractor] = Map::new()
  fn append_newline() -> Unit {
    if !builder.is_empty() && !last_newline {
      builder.write_char('\n')
      last_newline = true
    }
  }

  fn append_text_piece(value : String) -> Unit {
    if value.length() == 0 {
      return
    }
    builder.write_string(value)
    last_newline = false
  }

  fn decode_pdfdoc(value : String) -> String {
    utf8_of_pdfdocstring(value) catch {
      _ => value
    }
  }

  fn decode_text(value : String) -> String {
    match current_extractor {
      Some(extractor) =>
        utf8_of_codepoints(codepoints_of_text(extractor, value)) catch {
          _ => decode_pdfdoc(value)
        }
      None => decode_pdfdoc(value)
    }
  }

  fn append_text_value(value : String) -> Unit {
    append_text_piece(decode_text(value))
  }

  fn append_text_array(obj : @pdf.PdfObject) -> Unit {
    match obj {
      @pdf.PdfObject::Array(values) =>
        for value in values {
          match value {
            @pdf.PdfObject::String(text) => append_text_value(text)
            _ => ()
          }
        }
      @pdf.PdfObject::String(text) => append_text_value(text)
      _ => ()
    }
  }

  fn maybe_update_font(name : String) -> Unit {
    current_extractor = lookup_text_extractor(
      pdf, resources, name, extractor_cache,
    )
  }

  fn mark_visited(obj_num : Int?) -> Bool {
    match obj_num {
      Some(i) =>
        match visited.get(i) {
          Some(true) => false
          _ => {
            visited.set(i, true)
            true
          }
        }
      None => true
    }
  }

  fn append_text_from_xobject(name : String) -> Unit raise {
    match @pdf.lookup_direct(pdf, "/XObject", resources) {
      Some(@pdf.PdfObject::Dictionary(entries)) =>
        match entries.search_by(pair => pair.0 == name) {
          Some(idx) => {
            let obj_ref = entries[idx].1
            let obj_num = match obj_ref {
              @pdf.PdfObject::Indirect(i) => Some(i)
              _ => None
            }
            if mark_visited(obj_num) {
              let xobj = @pdf.direct(pdf, obj_ref)
              match @pdf.lookup_direct(pdf, "/Subtype", xobj) {
                Some(@pdf.PdfObject::Name("/Form")) => {
                  let xresources = match
                    @pdf.lookup_direct(pdf, "/Resources", xobj) {
                    Some(res) => res
                    None => resources
                  }
                  append_text_from_streams(
                    builder,
                    pdf,
                    xresources,
                    [xobj],
                    visited,
                  )
                }
                _ => ()
              }
            }
          }
          None => ()
        }
      _ => ()
    }
  }

  for op in ops {
    match op {
      @pdfops.Op::OpBT => {
        in_text = true
        current_extractor = None
      }
      @pdfops.Op::OpET => {
        in_text = false
        current_extractor = None
      }
      @pdfops.Op::OpTf(name, _) => if in_text { maybe_update_font(name) }
      @pdfops.Op::OpTj(text) => if in_text { append_text_value(text) }
      @pdfops.Op::OpTJ(obj) => if in_text { append_text_array(obj) }
      @pdfops.Op::OpSingleQuote(text) =>
        if in_text {
          append_newline()
          append_text_value(text)
        }
      @pdfops.Op::OpDoubleQuote(_, _, text) =>
        if in_text {
          append_newline()
          append_text_value(text)
        }
      @pdfops.Op::OpTStar => if in_text { append_newline() }
      @pdfops.Op::OpTd(_, ty) => if in_text && ty != 0.0 { append_newline() }
      @pdfops.Op::OpTD(_, ty) => if in_text && ty != 0.0 { append_newline() }
      @pdfops.Op::OpDo(name) => append_text_from_xobject(name)
      _ => ()
    }
  }
}

///|
fn lookup_text_extractor(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  font_name : String,
  cache : Map[String, TextExtractor],
) -> TextExtractor? {
  match cache.get(font_name) {
    Some(extractor) => Some(extractor)
    None => {
      let font_obj = match @pdf.lookup_direct(pdf, "/Font", resources) {
        Some(fonts) => @pdf.lookup_direct(pdf, font_name, fonts)
        None => None
      }
      match font_obj {
        Some(obj) =>
          try {
            let extractor = text_extractor_of_font(pdf, obj)
            cache.set(font_name, extractor)
            Some(extractor)
          } catch {
            _ => None
          }
        None => None
      }
    }
  }
}
