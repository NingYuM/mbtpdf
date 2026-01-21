///|
priv suberror ReadPdfError {
  Revisions(Int)
  BadRevision
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn read_startxref(input : @pdfio.Input) -> Int raise {
  find_eof(input)
  backline(input)
  ignoreuntil(false, is_digit, input)
  let digits = getuntil_string(false, c => !is_digit(c), input)
  if digits.length() == 0 {
    let message = @pdf.input_pdferror(input, "Could not find xref pointer")
    raise @pdf.PdfError::Msg(message)
  }
  match parse_uint_string(digits) {
    Some(value) => value
    None => {
      let message = @pdf.input_pdferror(input, "Could not parse xref pointer")
      raise @pdf.PdfError::Msg(message)
    }
  }
}

///|
fn extract_trailer_dict(obj : @pdf.PdfObject) -> @pdf.PdfObject raise {
  match obj {
    @pdf.PdfObject::Dictionary(_) => obj
    @pdf.PdfObject::Stream(r) => {
      let (dict, _) = r.val
      match dict {
        @pdf.PdfObject::Dictionary(_) => dict
        _ => raise @pdf.PdfError::Msg("Malformed trailer")
      }
    }
    _ => raise @pdf.PdfError::Msg("Malformed trailer")
  }
}

///|
fn read_trailer_dict_from_table(
  input : @pdfio.Input,
  read_stream_data : Bool,
) -> @pdf.PdfObject raise {
  let lexemes = lex_object_at(true, input, read_stream_data, fn(
    _ : Int,
  ) -> Array[@pdfgenlex.Token] raise {
    Array::new()
  })
  let (_, parsed) = parse(lexemes)
  extract_trailer_dict(parsed)
}

///|
fn sanitize_trailerdict(
  object_count : Int,
  trailerdict : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  let mut cleaned = trailerdict
  let keys = [
    "/W", "/Type", "/Index", "/Prev", "/XRefStm", "/Filter", "/DecodeParms",
  ]
  for key in keys {
    if @pdf.lookup_immediate(key, cleaned) is Some(_) {
      cleaned = @pdf.remove_dict_entry(cleaned, key)
    }
  }
  @pdf.add_dict_entry(cleaned, "/Size", @pdf.PdfObject::Integer(object_count))
}

///|
fn version_from_catalog(pdf : @pdf.Pdf) -> (Int, Int)? {
  match @pdf.lookup_direct(pdf, "/Version", @pdf.lookup_obj(pdf, pdf.root)) {
    Some(@pdf.PdfObject::Name(s)) => {
      if s.length() < 2 {
        return None
      }
      let version = try s[1:] catch {
        _ => return None
      } noraise {
        view => view.to_string()
      }
      let header = "%PDF-\{version}"
      try read_header(@pdfio.input_of_string(header)) catch {
        _ => None
      } noraise {
        pair => Some(pair)
      }
    }
    _ => None
  }
}

///|
fn read_pdf_internal(
  revision : Int?,
  user_password : String?,
  owner_password : String?,
  input : @pdfio.Input,
  read_stream_data : Bool,
) -> @pdf.Pdf raise {
  let _ = user_password
  let _ = owner_password
  match revision {
    Some(r) if r < 1 && r != -1 => raise ReadPdfError::BadRevision
    _ => ()
  }
  if debug_always_treat_malformed.val && revision != Some(-1) {
    return read_malformed_pdf(
      revision, user_password, owner_password, input, read_stream_data,
    )
  }
  try {
    let was_linearized = is_linearized(input)
    (input.seek_in)(0)
    let (major_header, minor_header) = read_header(input)
    let mut revisions_count = 1
    let mut current_revision = 0
    let mut got_all_xref_sections = false
    let mut xref_offset = read_startxref(input)
    let mut first_trailer = true
    let mut trailerdict = @pdf.PdfObject::Dictionary([])
    let xrefs : Map[Int, XRef] = Map::new()
    let postdeletes : Map[Int, Bool] = Map::new()
    fn add_entries(
      entries : Array[(Int, XRef)],
      xrefs : Map[Int, XRef],
    ) -> Unit {
      for pair in entries {
        if xrefs.get(pair.0) is None {
          xrefs.set(pair.0, pair.1)
        }
      }
    }

    while !got_all_xref_sections {
      (input.seek_in)(xref_offset)
      current_revision = current_revision + 1
      dropwhite(input)
      let skip = match revision {
        None => false
        Some(r) => r > current_revision
      }
      let mut trailerdict_current = @pdf.PdfObject::Dictionary([])
      if @pdfio.peek_char(input) == Some('x') {
        let entries = read_xref(input)
        if !skip {
          add_entries(entries, xrefs)
        }
        trailerdict_current = read_trailer_dict_from_table(
          input, read_stream_data,
        )
      } else {
        let (entries, xref_objnum, stream_obj) = read_xref_stream(input)
        if !skip {
          let filtered = entries.filter(pair => pair.0 != xref_objnum)
          add_entries(filtered, xrefs)
          postdeletes.set(xref_objnum, true)
        }
        trailerdict_current = extract_trailer_dict(stream_obj)
      }
      if first_trailer {
        trailerdict = trailerdict_current
        first_trailer = false
      }
      match @pdf.lookup_immediate("/XRefStm", trailerdict_current) {
        Some(@pdf.PdfObject::Integer(n)) => {
          (input.seek_in)(n)
          dropwhite(input)
          let (entries, xref_objnum, _stream_obj) = read_xref_stream(input)
          if !skip {
            let filtered = entries.filter(pair => pair.0 != xref_objnum)
            add_entries(filtered, xrefs)
            postdeletes.set(xref_objnum, true)
          }
        }
        Some(_) =>
          raise @pdf.PdfError::Msg(
            @pdf.input_pdferror(input, "Malformed /XRefStm"),
          )
        None => ()
      }
      match @pdf.lookup_immediate("/Prev", trailerdict_current) {
        None => got_all_xref_sections = true
        Some(@pdf.PdfObject::Integer(n)) => {
          revisions_count = revisions_count + 1
          xref_offset = n
        }
        Some(_) =>
          raise @pdf.PdfError::Msg(
            @pdf.input_pdferror(input, "Malformed /Prev"),
          )
      }
    }
    if revision == Some(-1) {
      let real_revisions = if was_linearized {
        revisions_count - 1
      } else {
        revisions_count
      }
      raise ReadPdfError::Revisions(real_revisions)
    }
    if read_stream_data {
      for _key, xref in xrefs {
        match xref {
          XRef::Stream(stream_id, _) => postdeletes.set(stream_id, true)
          _ => ()
        }
      }
    }
    let root = match @pdf.lookup_immediate("/Root", trailerdict) {
      Some(@pdf.PdfObject::Indirect(i)) => i
      None => {
        let message = @pdf.input_pdferror(input, "No /Root entry")
        raise @pdf.PdfError::Msg(message)
      }
      _ => {
        let message = @pdf.input_pdferror(input, "Malformed /Root entry")
        raise @pdf.PdfError::Msg(message)
      }
    }
    let mut used_encryption_fallback = false
    let objects = build_pdf_objects(
      input,
      xrefs.to_array(),
      read_stream_data,
      trailerdict,
      user_password,
      owner_password,
    ) catch {
      err =>
        if read_stream_data && is_encryption_error(err) {
          used_encryption_fallback = true
          build_pdf_objects(
            input,
            xrefs.to_array(),
            false,
            trailerdict,
            user_password,
            owner_password,
          )
        } else {
          raise err
        }
    }
    let sanitized_trailer = sanitize_trailerdict(
      objects.objects.length(),
      trailerdict,
    )
    let pdf_tmp = @pdf.Pdf::{
      major: major_header,
      minor: minor_header,
      root,
      objects,
      trailerdict: sanitized_trailer,
      was_linearized,
      saved_encryption: None,
    }
    let (major, minor) = if used_encryption_fallback {
      (major_header, minor_header)
    } else {
      match version_from_catalog(pdf_tmp) {
        Some(pair) => pair
        None => (major_header, minor_header)
      }
    }
    let pdf_final = @pdf.Pdf::{
      major,
      minor,
      root,
      objects,
      trailerdict: sanitized_trailer,
      was_linearized,
      saved_encryption: None,
    }
    fn remove_postdelete(pdf : @pdf.Pdf, objnum : Int) -> Unit {
      match @pdf.lookup_obj(pdf, objnum) {
        @pdf.PdfObject::Stream(r) => {
          let (dict, _) = r.val
          match @pdf.lookup_direct(pdf, "/Type", dict) {
            Some(@pdf.PdfObject::Name("/XRef"))
            | Some(@pdf.PdfObject::Name("/ObjStm")) =>
              @pdf.removeobj(pdf, objnum)
            _ => ()
          }
        }
        _ => ()
      }
    }

    for objnum, _ in postdeletes {
      remove_postdelete(pdf_final, objnum)
    }
    if pdf_final.objects.object_stream_ids.length() == 0 {
      let _ = (endpage.val)(pdf_final)

    }
    pdf_final
  } catch {
    err =>
      if should_fallback_on_error(err, revision) {
        read_malformed_pdf(
          revision, user_password, owner_password, input, read_stream_data,
        )
      } else {
        raise err
      }
  }
}
