///|
/// Debug flag for PDF reading.
pub let read_debug : Ref[Bool] = { val: false }

///|
/// If true, do not attempt malformed PDF recovery.
pub let error_on_malformed : Ref[Bool] = { val: false }

///|
/// If true, always treat PDFs as malformed.
pub let debug_always_treat_malformed : Ref[Bool] = { val: false }

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
fn digits_to_string(chars : Array[Char]) -> String {
  String::from_array(chars)
}

///|
fn read_startxref(input : @pdfio.Input) -> Int raise {
  find_eof(input)
  backline(input)
  ignoreuntil(false, is_digit, input)
  let digits = getuntil(false, c => !is_digit(c), input)
  if digits.length() == 0 {
    let message = @pdf.input_pdferror(input, "Could not find xref pointer")
    raise @pdf.PdfError::Msg(message)
  }
  match parse_uint_string(digits_to_string(digits)) {
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
      let version = match (try? s[1:]) {
        Ok(view) => view.to_string()
        Err(_) => return None
      }
      let header = "%PDF-\{version}"
      match (try? read_header(@pdfio.input_of_string(header))) {
        Ok(pair) => Some(pair)
        Err(_) => None
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
    let objects = build_pdf_objects(
      input,
      xrefs.to_array(),
      read_stream_data,
      trailerdict,
      user_password,
      owner_password,
    )
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
    let (major, minor) = match version_from_catalog(pdf_tmp) {
      Some(pair) => pair
      None => (major_header, minor_header)
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
      try {
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
      } catch {
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

///|
/// Read a PDF from an input.
pub fn pdf_of_input(
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  input : @pdfio.Input,
) -> @pdf.Pdf raise {
  read_pdf_internal(revision, user_password, owner_password, input, true)
}

///|
/// Read a PDF from an input, lazily.
pub fn pdf_of_input_lazy(
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  input : @pdfio.Input,
) -> @pdf.Pdf raise {
  read_pdf_internal(revision, user_password, owner_password, input, false)
}

///|
/// Read a PDF from a channel.
pub fn pdf_of_channel(
  revision? : Int,
  source? : String = "channel",
  user_password : String?,
  owner_password : String?,
  channel : @fs.File,
) -> @pdf.Pdf raise {
  let input = @pdfio.input_of_channel(channel, source~)
  read_pdf_internal(revision, user_password, owner_password, input, true)
}

///|
/// Read a PDF from a channel lazily.
pub fn pdf_of_channel_lazy(
  revision? : Int,
  source? : String = "channel",
  user_password : String?,
  owner_password : String?,
  channel : @fs.File,
) -> @pdf.Pdf raise {
  let input = @pdfio.input_of_channel(channel, source~)
  read_pdf_internal(revision, user_password, owner_password, input, false)
}

///|
/// Read a PDF from a file.
pub fn pdf_of_file(
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  filename : String,
) -> @pdf.Pdf raise {
  let input = @pdfio.input_of_file(filename, source=filename)
  read_pdf_internal(revision, user_password, owner_password, input, true)
}

///|
/// Return number of revisions.
pub fn revisions(input : @pdfio.Input) -> Int raise {
  try {
    let _ = read_pdf_internal(Some(-1), None, None, input, false)
    0
  } catch {
    ReadPdfError::Revisions(n) => n
    err => raise err
  }
}

///|
/// Return encryption method in use.
pub fn what_encryption(pdf : @pdf.Pdf) -> @pdfwrite.EncryptionMethod? {
  if @pdfcrypt.is_encrypted(pdf) {
    let values : Result[
      (
        @pdfcryptprimitives.Encryption,
        String,
        String,
        Int,
        String,
        String?,
        String?,
      ),
      Error,
    ] = try? @pdfcrypt.get_encryption_values(pdf)
    match values {
      Ok((crypt, _, _, _, _, _, _)) => {
        let metadata = match
          @pdf.lookup_direct(pdf, "/Encrypt", pdf.trailerdict) {
          Some(encrypt_dict) =>
            match @pdf.lookup_direct(pdf, "/EncryptMetadata", encrypt_dict) {
              Some(@pdf.PdfObject::Boolean(false)) => false
              _ => true
            }
          None => true
        }
        match crypt {
          @pdfcryptprimitives.Encryption::ARC4(bits, _) =>
            match bits {
              40 => Some(@pdfwrite.EncryptionMethod::PDF40bit)
              128 => Some(@pdfwrite.EncryptionMethod::PDF128bit)
              _ => None
            }
          @pdfcryptprimitives.Encryption::AESV2 =>
            Some(@pdfwrite.EncryptionMethod::AES128bit(metadata))
          @pdfcryptprimitives.Encryption::AESV3(is_iso) =>
            if is_iso {
              Some(@pdfwrite.EncryptionMethod::AES256bitISO(metadata))
            } else {
              Some(@pdfwrite.EncryptionMethod::AES256bit(metadata))
            }
        }
      }
      Err(_) => None
    }
  } else {
    None
  }
}

///|
/// Return list of permissions.
pub fn permissions(pdf : @pdf.Pdf) -> Array[@pdfcrypt.Permission] {
  if @pdfcrypt.is_encrypted(pdf) {
    let values : Result[
      (
        @pdfcryptprimitives.Encryption,
        String,
        String,
        Int,
        String,
        String?,
        String?,
      ),
      Error,
    ] = try? @pdfcrypt.get_encryption_values(pdf)
    match values {
      Ok((_, _, _, p, _, _, _)) => @pdfcrypt.banlist_of_p(p)
      Err(_) => []
    }
  } else {
    []
  }
}

///|
/// Check if input is linearized.
pub fn is_linearized(input : @pdfio.Input) -> Bool {
  try {
    let _ = read_header(input)
    let lexemes = lex_dictionary(false, input)
    let (_, parsed) = parse(lexemes, failure_is_ok=true)
    match @pdf.lookup_direct(@pdf.empty(), "/Linearized", parsed) {
      Some(@pdf.PdfObject::Integer(_)) | Some(@pdf.PdfObject::Real(_)) => true
      _ => false
    }
  } catch {
    _ => false
  }
}

///|
/// Read a PDF header.
pub fn read_header(input : @pdfio.Input) -> (Int, Int) raise {
  fn get8chars(input : @pdfio.Input) -> Array[Char] {
    let out = Array::new(capacity=8)
    let mut ok = true
    let mut i = 0
    while ok && i < 8 {
      match (input.input_char)() {
        Some(ch) => out.push(ch)
        None => ok = false
      }
      i = i + 1
    }
    if ok {
      out
    } else {
      Array::new()
    }
  }

  fn digits_to_int(digits : Array[Char]) -> Int {
    let mut value = 0
    for d in digits {
      value = value * 10 + (d.to_int() - '0'.to_int())
    }
    value
  }

  let mut pos = 0
  while pos <= 1024 {
    (input.seek_in)(pos)
    let chars = get8chars(input)
    if chars.length() == 8 &&
      chars[0] == '%' &&
      chars[1] == 'P' &&
      chars[2] == 'D' &&
      chars[3] == 'F' &&
      chars[4] == '-' &&
      chars[6] == '.' {
      let major_char = chars[5]
      if major_char < '0' || major_char > '9' {
        return (2, 0)
      }
      let minor_digits = Array::new()
      let mut idx = 7
      while idx < chars.length() {
        let c = chars[idx]
        if c >= '0' && c <= '9' {
          minor_digits.push(c)
          idx = idx + 1
        } else {
          idx = chars.length()
        }
      }
      if minor_digits.length() == 0 {
        let message = @pdf.input_pdferror(input, "Malformed PDF header")
        raise @pdf.PdfError::Msg(message)
      }
      if read_debug.val {
        @pdfe.log("setting offset to \{pos}\n")
      }
      (input.set_offset)(pos)
      return (major_char.to_int() - '0'.to_int(), digits_to_int(minor_digits))
    }
    pos = pos + 1
  }
  (2, 0)
}

///|
/// PDF whitespace predicate.
fn is_whitespace(c : Char) -> Bool {
  let v = c.to_int()
  v == 0 || v == 9 || v == 10 || v == 12 || v == 13 || v == 32
}

///|
fn is_not_whitespace(c : Char) -> Bool {
  !is_whitespace(c)
}

///|
fn is_newline(c : Char) -> Bool {
  c == '\n' || c == '\r'
}

///|
fn is_delimiter(c : Char) -> Bool {
  match c {
    '(' | ')' | '<' | '>' | '[' | ']' | '{' | '}' | '%' | '/' => true
    _ => false
  }
}

///|
fn is_whitespace_or_delimiter(c : Char) -> Bool {
  is_whitespace(c) || is_delimiter(c)
}

///|
/// Read chars until whitespace or delimiter.
pub fn getuntil_white_or_delimiter(input : @pdfio.Input) -> Array[Char] raise {
  getuntil(true, is_whitespace_or_delimiter, input)
}

///|
/// Read chars until whitespace or delimiter.
pub fn getuntil_white_or_delimiter_string(input : @pdfio.Input) -> String raise {
  getuntil_string(true, is_whitespace_or_delimiter, input)
}

///|
/// Read chars until predicate is true.
pub fn getuntil(
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
  input : @pdfio.Input,
) -> Array[Char] raise {
  let out = Array::new()
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        @pdfio.rewind(input)
        done = true
      } else {
        out.push(c)
      }
    }
  }
  out
}

///|
fn getuntil_string(
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
  input : @pdfio.Input,
) -> String raise {
  let sb = StringBuilder::new()
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        @pdfio.rewind(input)
        done = true
      } else {
        sb.write_char(c)
      }
    }
  }
  sb.to_string()
}

///|
/// Ignore chars until predicate is true.
pub fn ignoreuntil(
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
  input : @pdfio.Input,
) -> Unit raise {
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        @pdfio.rewind(input)
        done = true
      }
    }
  }
}

///|
/// Drop whitespace.
pub fn dropwhite(input : @pdfio.Input) -> Unit raise {
  ignoreuntil(true, is_not_whitespace, input)
}

///|
/// Read a line from input (newline not included).
fn input_line(input : @pdfio.Input) -> String {
  let sb = StringBuilder::new()
  let mut got_eol = false
  let mut finished = false
  while !finished {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      finished = true
    } else {
      let c = b.to_byte().to_char()
      if is_newline(c) {
        got_eol = true
      } else if got_eol {
        @pdfio.rewind(input)
        finished = true
      } else {
        sb.write_char(c)
      }
    }
  }
  sb.to_string()
}

///|
/// Read back until predicate is true.
fn read_back_until(pred : (Char) -> Bool, input : @pdfio.Input) -> Unit raise {
  match @pdfio.read_char_back(input) {
    Some(ch) => if !pred(ch) { read_back_until(pred, input) }
    None => fail("End_of_file")
  }
}

///|
/// Go back one line.
fn backline(input : @pdfio.Input) -> Unit raise {
  read_back_until(is_newline, input)
  read_back_until(c => !is_newline(c), input)
  read_back_until(is_newline, input)
  @pdfio.nudge(input)
}

///|
/// Find the EOF marker and position input there.
fn find_eof(input : @pdfio.Input) -> Unit raise {
  fn fail_find() -> Unit raise {
    let message = @pdf.input_pdferror(input, "Could not find EOF marker")
    raise @pdf.PdfError::Msg(message)
  }

  let mut pos = input.in_channel_length - 4
  let mut tries = pos
  let mut found = false
  while !found {
    pos = pos - 1
    if pos < 0 || tries < 0 {
      fail_find()
    }
    tries = tries - 1
    (input.seek_in)(pos)
    let a = (input.input_byte)()
    let b = (input.input_byte)()
    let c = (input.input_byte)()
    let d = (input.input_byte)()
    let e = (input.input_byte)()
    if a == '%'.to_int() &&
      b == '%'.to_int() &&
      c == 'E'.to_int() &&
      d == 'O'.to_int() &&
      e == 'F'.to_int() {
      found = true
    }
  }
  (input.seek_in)(pos)
}

///|
priv enum XRef {
  Plain(Int, Int)
  Stream(Int, Int)
}

///|
priv enum XRefLine {
  Invalid
  Section(Int, Int)
  Valid(Int, Int)
  Free(Int, Int)
  InObjectStream(Int, Int)
  StreamFree(Int, Int)
  XRefNull
  Finished
}

///|
fn parse_digits(chars : Array[Char], start : Int, len : Int) -> Int? {
  if start < 0 || len < 0 || start + len > chars.length() {
    return None
  }
  let mut value = 0
  let mut i = start
  while i < start + len {
    let c = chars[i]
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  Some(value)
}

///|
fn count_leading_spaces(chars : Array[Char]) -> Int {
  let mut i = 0
  while i < chars.length() && chars[i] == ' ' {
    i = i + 1
  }
  i
}

///|
fn split_fields(line : String) -> Array[String] {
  let parts = Array::new()
  for part in line.split(" ") {
    let s = part.to_string()
    if s != "" {
      parts.push(s)
    }
  }
  parts
}

///|
fn parse_uint_string(s : String) -> Int? {
  if s == "" {
    return None
  }
  let mut value = 0
  for c in s {
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
fn read_xref_line(input : @pdfio.Input) -> XRefLine raise {
  let pos = (input.pos_in)()
  dropwhite(input)
  let line = input_line(input)
  if line == "xref" || line == "xref " {
    return read_xref_line(input)
  }
  let chars = line.to_array()
  let offset_opt = if chars.length() >= 18 {
    parse_digits(chars, 0, 10)
  } else {
    None
  }
  let gen_opt = if chars.length() >= 18 {
    parse_digits(chars, 11, 5)
  } else {
    None
  }
  match (offset_opt, gen_opt) {
    (Some(offset), Some(gen)) =>
      match chars[17] {
        'n' => return XRefLine::Valid(offset, gen)
        'f' => return XRefLine::Free(offset, gen)
        _ => return XRefLine::Invalid
      }
    _ => ()
  }
  if chars.length() >= 18 &&
    parse_digits(chars, 0, 10) is Some(0) &&
    chars[17] == 'n' {
    return XRefLine::Free(0, 0)
  }
  if line.has_prefix("trailer") {
    let leading_spaces = count_leading_spaces(chars)
    (input.seek_in)(pos + 7 + leading_spaces)
    return XRefLine::Finished
  }
  let parts = split_fields(line)
  let mut start_index = 0
  if parts.length() >= 3 && parts[0] == "xref" {
    start_index = 1
  }
  if parts.length() - start_index >= 2 {
    match
      (
        parse_uint_string(parts[start_index]),
        parse_uint_string(parts[start_index + 1]),
      ) {
      (Some(s), Some(l)) => return XRefLine::Section(s, l)
      _ => ()
    }
  }
  XRefLine::Invalid
}

///|
fn read_xref(input : @pdfio.Input) -> Array[(Int, XRef)] raise {
  fn fail_read() -> Unit raise {
    let message = @pdf.input_pdferror(input, "Could not read x-ref table")
    raise @pdf.PdfError::Msg(message)
  }

  let xrefs = Array::new()
  let mut finished = false
  let mut objnumber = 0
  while !finished {
    match read_xref_line(input) {
      XRefLine::Invalid => fail_read()
      XRefLine::Valid(offset, gen) => {
        xrefs.push((objnumber, XRef::Plain(offset, gen)))
        objnumber = objnumber + 1
      }
      XRefLine::Free(_, _) => objnumber = objnumber + 1
      XRefLine::Section(start, _) => objnumber = start
      XRefLine::Finished => finished = true
      _ => ()
    }
  }
  xrefs
}

///|
fn read_xref_line_stream(
  input : @pdfio.Input,
  w1 : Int,
  w2 : Int,
  w3 : Int,
) -> XRefLine raise {
  fn read_field(bytes : Int) -> Int raise {
    if bytes == 0 {
      return 0
    }
    let mut value = 0
    let mut i = 0
    while i < bytes {
      let b = (input.input_byte)()
      if b == @pdfio.no_more {
        let message = @pdf.input_pdferror(input, "Bad xref stream")
        raise @pdf.PdfError::Msg(message)
      }
      value = value * 256 + b
      i = i + 1
    }
    value
  }

  let f1 = read_field(w1)
  let f2 = read_field(w2)
  let f3 = read_field(w3)
  match f1 {
    0 => XRefLine::StreamFree(f2, f3)
    1 => XRefLine::Valid(f2, f3)
    2 => XRefLine::InObjectStream(f2, f3)
    _ => XRefLine::XRefNull
  }
}

///|

///|
fn read_xref_stream(
  input : @pdfio.Input,
) -> (Array[(Int, XRef)], Int, @pdf.PdfObject) raise {
  let original_pos = (input.pos_in)()
  let err = @pdf.PdfError::Msg(@pdf.input_pdferror(input, "Bad xref stream"))
  let dummy_lexobj = fn(_ : Int) -> Array[@pdfgenlex.Token] raise {
    Array::new()
  }
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let xrefstream_objectnumber = match
    lex_next(
      dict_level,
      array_level,
      false,
      input,
      Array::new(),
      true,
      dummy_lexobj,
    ) {
    @pdfgenlex.Token::LexInt(i) => i
    _ => {
      @pdfe.log("couldn't lex object number\n")
      raise err
    }
  }
  if read_debug.val {
    @pdfe.log(
      "Object number of this xref stream is \{xrefstream_objectnumber}\n",
    )
  }
  (input.seek_in)(original_pos)
  fn lex_untilstream(
    input : @pdfio.Input,
    read_stream_data : Bool,
  ) -> Array[@pdfgenlex.Token] raise {
    let lexemes = Array::new()
    let dict_level : Ref[Int] = { val: 0 }
    let array_level : Ref[Int] = { val: 0 }
    let mut done = false
    while !done {
      let t = lex_next(
        dict_level, array_level, true, input, lexemes, read_stream_data, dummy_lexobj,
      )
      match t {
        @pdfgenlex.Token::StopLexing | @pdfgenlex.Token::LexNone => done = true
        _ => lexemes.push(t)
      }
    }
    lexemes
  }

  let dictlex = lex_untilstream(input, true)
  if dictlex.length() < 2 {
    raise err
  }
  let objnum = match dictlex[0] {
    @pdfgenlex.Token::LexInt(i) => i
    _ => raise err
  }
  let gen = match dictlex[1] {
    @pdfgenlex.Token::LexInt(i) => i
    _ => raise err
  }
  let stream_token = lex_stream(input, dictlex, dummy_lexobj, true)
  let tokens = Array::new()
  for t in dictlex {
    tokens.push(t)
  }
  tokens.push(stream_token)
  tokens.push(@pdfgenlex.Token::LexEndStream)
  tokens.push(@pdfgenlex.Token::LexEndObj)
  let (_, parsed) = parse(tokens)
  let stream_obj = match parsed {
    @pdf.PdfObject::Stream(_) => parsed
    _ => raise err
  }
  @pdfcodec.decode_pdfstream(@pdf.empty(), stream_obj)
  @pdf.getstream(stream_obj)
  let (w1, w2, w3) = match @pdf.lookup_direct(@pdf.empty(), "/W", stream_obj) {
    Some(@pdf.PdfObject::Array(elts)) => {
      if elts.length() != 3 {
        raise err
      }
      match (elts[0], elts[1], elts[2]) {
        (
          @pdf.PdfObject::Integer(a),
          @pdf.PdfObject::Integer(b),
          @pdf.PdfObject::Integer(c),
        ) => (a, b, c)
        _ => raise err
      }
    }
    _ => raise err
  }
  let raw_input = match stream_obj {
    @pdf.PdfObject::Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(bytes)) => @pdfio.input_of_bytes(bytes)
        _ => raise err
      }
    _ => raise err
  }
  let xrefs_raw = Array::new()
  try {
    while true {
      xrefs_raw.push(read_xref_line_stream(raw_input, w1, w2, w3))
    }
  } catch {
    _ => ()
  }
  let starts_and_lens = match
    @pdf.lookup_direct(@pdf.empty(), "/Index", stream_obj) {
    Some(@pdf.PdfObject::Array(elts)) => {
      if elts.length() % 2 != 0 {
        raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "Bad /Index"))
      }
      let pairs = Array::new()
      let mut i = 0
      while i < elts.length() {
        match (elts[i], elts[i + 1]) {
          (@pdf.PdfObject::Integer(s), @pdf.PdfObject::Integer(l)) =>
            pairs.push((s, l))
          _ =>
            raise @pdf.PdfError::Msg(
              @pdf.input_pdferror(input, "Bad /Index entry"),
            )
        }
        i = i + 2
      }
      pairs
    }
    Some(_) =>
      raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "Unknown /Index"))
    None => {
      let size = match @pdf.lookup_direct(@pdf.empty(), "/Size", stream_obj) {
        Some(@pdf.PdfObject::Integer(s)) => s
        _ =>
          raise @pdf.PdfError::Msg(
            @pdf.input_pdferror(input, "Missing /Size in xref dict"),
          )
      }
      [(0, size)]
    }
  }
  let xrefs = Array::new()
  let mut raw_pos = 0
  for pair in starts_and_lens {
    let (start, len) = pair
    let mut objnumber = start
    let mut i = 0
    while i < len {
      if raw_pos >= xrefs_raw.length() {
        raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "Bad xref stream"))
      }
      match xrefs_raw[raw_pos] {
        XRefLine::Valid(offset, gen) =>
          xrefs.push((objnumber, XRef::Plain(offset, gen)))
        XRefLine::InObjectStream(stream, index) =>
          xrefs.push((objnumber, XRef::Stream(stream, index)))
        _ => ()
      }
      objnumber = objnumber + 1
      raw_pos = raw_pos + 1
      i = i + 1
    }
  }
  (input.seek_in)(original_pos)
  let _ = objnum
  let _ = gen
  (xrefs, xrefstream_objectnumber, stream_obj)
}

///|
fn read_int_from_stream(input : @pdfio.Input) -> Int raise {
  dropwhite(input)
  match lex_number(input) {
    @pdfgenlex.Token::LexInt(i) => i
    _ => {
      let message = @pdf.input_pdferror(input, "objstm offset problem")
      raise @pdf.PdfError::Msg(message)
    }
  }
}

///|
fn parse_object_stream(
  input : @pdfio.Input,
  xrefs : Map[Int, XRef],
  objstm : Int,
  user_password : String?,
  owner_password : String?,
  partial_pdf : @pdf.Pdf,
  indexes? : Array[Int],
) -> Array[(Int, @pdf.PdfObject)] raise {
  let lexemes = lex_object_for_xref(input, xrefs, true, objstm)
  let (_, stmobj) = parse(lexemes)
  let gen = match xrefs.get(objstm) {
    Some(XRef::Plain(_, g)) => g
    _ => 0
  }
  let stmobj = @pdfcrypt.decrypt_single_stream(
    user_password, owner_password, partial_pdf, objstm, gen, stmobj,
  )
  match stmobj {
    @pdf.PdfObject::Stream(_) => ()
    _ => {
      let message = @pdf.input_pdferror(
        input, "lex_stream_object: not a stream",
      )
      raise @pdf.PdfError::Msg(message)
    }
  }
  @pdfcodec.decode_pdfstream(partial_pdf, stmobj)
  @pdf.getstream(stmobj)
  let (dict, stream_bytes) = match stmobj {
    @pdf.PdfObject::Stream(r) => r.val
    _ => raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "Bad objstm"))
  }
  let n = match @pdf.lookup_direct(@pdf.empty(), "/N", dict) {
    Some(@pdf.PdfObject::Integer(v)) => v
    _ => raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "malformed /N"))
  }
  let first = match @pdf.lookup_direct(@pdf.empty(), "/First", dict) {
    Some(@pdf.PdfObject::Integer(v)) => v
    _ =>
      raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "malformed /First"))
  }
  let raw = match stream_bytes {
    @pdf.Stream::Got(bytes) => bytes
    _ =>
      raise @pdf.PdfError::Msg(
        @pdf.input_pdferror(input, "couldn't decode objstream"),
      )
  }
  let stm_input = @pdfio.input_of_bytes(raw)
  let rawnums = Array::new()
  let mut i = 0
  while i < n * 2 {
    rawnums.push(read_int_from_stream(stm_input))
    i = i + 1
  }
  let (use_indexes, sorted_indexes) = match indexes {
    Some(values) => {
      let ordered = values.copy()
      ordered.sort_by((a, b) => a - b)
      (true, ordered)
    }
    None => (false, Array::new())
  }
  let objects = Array::new()
  let mut idx = 0
  let mut current_index = 0
  let mut wanted_pos = 0
  while idx < rawnums.length() {
    if use_indexes && wanted_pos >= sorted_indexes.length() {
      break
    }
    let objnum = rawnums[idx]
    let offset = rawnums[idx + 1]
    let should_parse = if use_indexes {
      let want = sorted_indexes[wanted_pos]
      if current_index == want {
        wanted_pos = wanted_pos + 1
        true
      } else {
        false
      }
    } else {
      true
    }
    if should_parse {
      (stm_input.seek_in)(offset + first)
      let lexemes = lex_object_at(true, stm_input, true, fn(
        _ : Int,
      ) -> Array[@pdfgenlex.Token] raise {
        Array::new()
      })
      let (_, obj) = parse(lexemes)
      objects.push((objnum, obj))
    }
    current_index = current_index + 1
    idx = idx + 2
  }
  objects
}

///|
fn build_pdf_objects(
  input : @pdfio.Input,
  xref_entries : Array[(Int, XRef)],
  read_stream_data : Bool,
  trailerdict : @pdf.PdfObject,
  user_password : String?,
  owner_password : String?,
) -> @pdf.PdfObjects raise {
  let xrefs : Map[Int, XRef] = Map::new()
  for pair in xref_entries {
    xrefs.set(pair.0, pair.1)
  }
  let objects : @pdf.PdfObjMap = Map::new()
  let object_stream_ids : Map[Int, Int] = Map::new()
  let stream_id_seen : Map[Int, Bool] = Map::new()
  let stream_groups : Map[Int, Array[(Int, Int)]] = Map::new()
  let mut max_obj = 0
  let stream_ids = Array::new()
  for pair in xref_entries {
    let objnum = pair.0
    let xref = pair.1
    if objnum > max_obj {
      max_obj = objnum
    }
    match xref {
      XRef::Plain(_, gen) =>
        objects.set(objnum, ({ val: @pdf.ObjectData::ToParse }, gen))
      XRef::Stream(stream_id, _index) => {
        if stream_id_seen.get(stream_id) is None {
          stream_id_seen.set(stream_id, true)
          stream_ids.push(stream_id)
        }
        object_stream_ids.set(objnum, stream_id)
        let entries = match stream_groups.get(stream_id) {
          Some(existing) => existing
          None => {
            let created = Array::new()
            stream_groups.set(stream_id, created)
            created
          }
        }
        entries.push((objnum, _index))
      }
    }
  }
  fn parse_obj(num : Int) -> @pdf.PdfObject {
    try {
      let lexemes = lex_object_for_xref(input, xrefs, read_stream_data, num)
      let (_, obj) = parse(lexemes)
      obj
    } catch {
      _ => {
        if read_debug.val {
          @pdfe.log("parse_obj failed for object \{num}\n")
        }
        @pdf.PdfObject::Null
      }
    }
  }

  let partial_pdf : @pdf.Pdf = {
    major: 0,
    minor: 0,
    root: 0,
    objects: {
      max_obj_num: max_obj,
      parse: Some(parse_obj),
      objects,
      object_stream_ids,
    },
    trailerdict,
    was_linearized: false,
    saved_encryption: None,
  }
  if read_stream_data {
    for stream_id in stream_ids {
      let parsed = parse_object_stream(
        input, xrefs, stream_id, user_password, owner_password, partial_pdf,
      )
      for pair in parsed {
        let objnum = pair.0
        let obj = pair.1
        objects.set(
          objnum,
          ({ val: @pdf.ObjectData::ParsedAlreadyDecrypted(obj) }, 0),
        )
        object_stream_ids.set(objnum, stream_id)
      }
    }
  } else {
    let themap : Map[Int, Array[Int]] = Map::new()
    for group in stream_groups.to_array() {
      let entries = group.1
      for entry in entries {
        let objnum = entry.0
        let index = entry.1
        let indexes = match themap.get(objnum) {
          Some(existing) => existing
          None => {
            let created = Array::new()
            themap.set(objnum, created)
            created
          }
        }
        indexes.push(index)
      }
    }
    fn parse_stream(
      stream_objnum : Int,
      indexes : Array[Int],
    ) -> Array[(Int, (Ref[@pdf.ObjectData], Int))] {
      try {
        let parsed = parse_object_stream(
          input,
          xrefs,
          stream_objnum,
          user_password,
          owner_password,
          partial_pdf,
          indexes~,
        )
        let out = Array::new(capacity=parsed.length())
        for pair in parsed {
          out.push(
            (
              pair.0,
              ({ val: @pdf.ObjectData::ParsedAlreadyDecrypted(pair.1) }, 0),
            ),
          )
        }
        out
      } catch {
        _ => Array::new()
      }
    }

    for group in stream_groups.to_array() {
      let stream_id = group.0
      let entries = group.1
      for entry in entries {
        let objnum = entry.0
        let index = entry.1
        objects.set(
          objnum,
          (
            {
              val: @pdf.ObjectData::ToParseFromObjectStream(
                themap, stream_id, index, parse_stream,
              ),
            },
            0,
          ),
        )
      }
    }
  }
  { max_obj_num: max_obj, parse: Some(parse_obj), objects, object_stream_ids }
}

///|
/// Lex a name.
pub fn lex_name(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  let bytes : @pdfio.MutableBytes = Array::new()
  let _ = (input.input_byte)()
  bytes.push('/'.to_int().to_byte())
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else {
      let c = b.to_byte().to_char()
      if is_whitespace_or_delimiter(c) {
        @pdfio.rewind(input)
        done = true
      } else if c == '#' {
        let h1 = (input.input_byte)()
        let h2 = (input.input_byte)()
        if h1 != @pdfio.no_more && h2 != @pdfio.no_more {
          let hex = String::from_array([
            h1.to_byte().to_char(),
            h2.to_byte().to_char(),
          ])
          match (try? @strconv.parse_int("0x\{hex}")) {
            Ok(v) => bytes.push(v.to_byte())
            Err(_) =>
              raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "lex_name"))
          }
        }
      } else {
        bytes.push(b.to_byte())
      }
    }
  }
  @pdfgenlex.Token::LexName(@pdfio.string_of_bytes(bytes))
}

///|
/// Lex a number.
pub fn lex_number(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  let s = getuntil_white_or_delimiter_string(input)
  let mut number = s
  if number.length() > 1 {
    match (number.get_char(0), number.get_char(1)) {
      (Some('-'), Some('-')) =>
        number = match (try? number[1:]) {
          Ok(view) => view.to_string()
          Err(_) => number
        }
      _ => ()
    }
  }
  let has_decimal = number.contains(".") ||
    number.contains("e") ||
    number.contains("E")
  if !has_decimal {
    match (try? @strconv.parse_int(number)) {
      Ok(i) => @pdfgenlex.Token::LexInt(i)
      Err(_) =>
        match (try? @strconv.parse_double(number)) {
          Ok(f) => @pdfgenlex.Token::LexReal(f)
          Err(_) => @pdfgenlex.Token::LexNone
        }
    }
  } else {
    match (try? @strconv.parse_double(number)) {
      Ok(f) => @pdfgenlex.Token::LexReal(f)
      Err(_) => @pdfgenlex.Token::LexNone
    }
  }
}

///|
/// Lex a string.
pub fn lex_string(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  let bytes : @pdfio.MutableBytes = Array::new()
  let mut paren = 1
  let first = (input.input_byte)()
  if first != '('.to_int() {
    raise @pdf.PdfError::Msg("lex_string: expected '('")
  }
  while paren > 0 {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      raise @pdf.PdfError::Msg("lex_string: unexpected EOF")
    }
    let c = b.to_byte().to_char()
    match c {
      '(' => {
        paren = paren + 1
        bytes.push(b.to_byte())
      }
      ')' => {
        paren = paren - 1
        if paren > 0 {
          bytes.push(b.to_byte())
        }
      }
      '\\' => {
        let esc = (input.input_byte)()
        if esc == @pdfio.no_more {
          raise @pdf.PdfError::Msg("lex_string: unexpected EOF")
        }
        match esc.to_byte().to_char() {
          'n' => bytes.push('\n'.to_int().to_byte())
          'r' => bytes.push('\r'.to_int().to_byte())
          't' => bytes.push('\t'.to_int().to_byte())
          'b' => bytes.push('\b'.to_int().to_byte())
          'f' => bytes.push('\f'.to_int().to_byte())
          '\r' => {
            let next = (input.input_byte)()
            if next != '\n'.to_int() {
              @pdfio.rewind(input)
            }
          }
          '\n' => ()
          digit if digit >= '0' && digit <= '7' => {
            let digits : Array[Char] = Array::new()
            digits.push(digit)
            let b2 = (input.input_byte)()
            if b2 != @pdfio.no_more {
              let c2 = b2.to_byte().to_char()
              if c2 >= '0' && c2 <= '7' {
                digits.push(c2)
                let b3 = (input.input_byte)()
                if b3 != @pdfio.no_more {
                  let c3 = b3.to_byte().to_char()
                  if c3 >= '0' && c3 <= '7' {
                    digits.push(c3)
                  } else {
                    @pdfio.rewind(input)
                  }
                }
              } else {
                @pdfio.rewind(input)
              }
            }
            let octal = digits.map(c => c.to_string()).join("")
            match (try? @strconv.parse_int("0o\{octal}")) {
              Ok(v) => bytes.push(v.to_byte())
              Err(_) => ()
            }
          }
          other => bytes.push(other.to_int().to_byte())
        }
      }
      _ => bytes.push(b.to_byte())
    }
  }
  @pdfgenlex.Token::LexString(@pdfio.string_of_bytes(bytes))
}

///|
/// Lex a hex string.
pub fn lex_hexstring(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  let digits = Array::new()
  let _ = (input.input_byte)()
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else {
      let c = b.to_byte().to_char()
      if c == '>' {
        done = true
      } else if is_whitespace(c) {
        ()
      } else {
        let hex = c.to_string()
        match (try? @strconv.parse_int("0x\{hex}")) {
          Ok(v) => digits.push(v)
          Err(_) =>
            raise @pdf.PdfError::Msg(
              @pdf.input_pdferror(input, "lex_hexstring"),
            )
        }
      }
    }
  }
  if digits.length() % 2 == 1 {
    digits.push(0)
  }
  let bytes : @pdfio.MutableBytes = Array::new()
  for i = 0; i < digits.length(); i = i + 2 {
    let hi = digits[i]
    let lo = digits[i + 1]
    bytes.push(((hi << 4) + lo).to_byte())
  }
  @pdfgenlex.Token::LexString(@pdfio.string_of_bytes(bytes))
}

///|
/// Lex a comment.
pub fn lex_comment(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  ignoreuntil(false, is_newline, input)
  @pdfgenlex.Token::LexComment("")
}

///|
fn ignoreuntilwhite(input : @pdfio.Input) -> Unit raise {
  ignoreuntil(true, is_whitespace, input)
}

///|
fn read_chunk(count : Int, input : @pdfio.Input) -> String raise {
  let pos = (input.pos_in)()
  let sb = StringBuilder::new()
  let mut i = 0
  while i < count {
    match (input.input_char)() {
      Some(ch) => sb.write_char(ch)
      None => {
        (input.seek_in)(pos)
        fail("read_chunk")
      }
    }
    i = i + 1
  }
  (input.seek_in)(pos)
  sb.to_string()
}

///|
fn is_malformed(input : @pdfio.Input) -> Bool {
  try {
    if read_chunk(9, input) == "endstream" {
      false
    } else if read_chunk(10, input) == "\nendstream" ||
      read_chunk(10, input) == "\rendstream" {
      false
    } else if read_chunk(11, input) == "\r\nendstream" {
      false
    } else {
      true
    }
  } catch {
    _ => true
  }
}

///|
fn skip_stream_beginning(input : @pdfio.Input) -> Unit raise {
  ignoreuntilwhite(input)
  ignoreuntil(
    true,
    c => {
      let v = c.to_int()
      v != 32 && v != 0 && v != 12 && v != 9
    },
    input,
  )
  let first = (input.input_byte)()
  if first == '\r'.to_int() {
    let second = (input.input_byte)()
    if second != '\n'.to_int() {
      @pdfio.rewind(input)
    }
  } else if first == '\n'.to_int() {
    ()
  } else {
    @pdfio.rewind(input)
  }
}

///|
fn find_endstream(input : @pdfio.Input) -> Int raise {
  fn match_chunk(s : String, input : @pdfio.Input) -> Bool raise {
    let pos = (input.pos_in)()
    let ok = read_chunk(s.length(), input) == s
    (input.seek_in)(pos)
    ok
  }

  let mut done = false
  let mut found_pos = (input.pos_in)()
  while !done {
    let pos = (input.pos_in)()
    if match_chunk("endstream", input) ||
      match_chunk("\nendstream", input) ||
      match_chunk("\r\nendstream", input) ||
      match_chunk("\rendstream", input) {
      done = true
      found_pos = pos
    } else if pos == input.in_channel_length {
      done = true
      found_pos = pos
    } else {
      @pdfio.nudge(input)
    }
  }
  found_pos
}

///|
fn lex_keyword(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  let kw = getuntil_white_or_delimiter_string(input)
  match kw {
    "obj" => @pdfgenlex.Token::LexObj
    "endobj" => @pdfgenlex.Token::LexEndObj
    "R" => @pdfgenlex.Token::LexR
    "null" => @pdfgenlex.Token::LexNull
    "endstream" => @pdfgenlex.Token::LexEndStream
    "true" => @pdfgenlex.Token::LexBool(true)
    "false" => @pdfgenlex.Token::LexBool(false)
    _ =>
      if kw.has_prefix("endobj") && kw.length() > 6 {
        let extra = kw.length() - 6
        let mut i = 0
        while i < extra {
          @pdfio.rewind(input)
          i = i + 1
        }
        @pdfgenlex.Token::LexEndObj
      } else {
        @pdfgenlex.Token::LexNone
      }
  }
}

///|
fn lex_malformed_stream_data(input : @pdfio.Input) -> @pdfgenlex.Token raise {
  skip_stream_beginning(input)
  let curr = (input.pos_in)()
  let pos = find_endstream(input)
  (input.seek_in)(curr)
  let len = pos - curr
  let bytes = @pdfio.mkbytes(len)
  for i = 0; i < len; i = i + 1 {
    bytes[i] = (input.input_byte)().to_byte()
  }
  @pdfgenlex.Token::LexStream(@pdf.Stream::Got(bytes))
}

///|
pub fn lex_stream_data(
  input : @pdfio.Input,
  length : Int,
  read_data : Bool,
) -> @pdfgenlex.Token raise {
  let original_pos = (input.pos_in)()
  skip_stream_beginning(input)
  let pos = (input.pos_in)()
  if read_data {
    let bytes = @pdfio.mkbytes(length)
    if length > 0 {
      @pdfio.setinit(input, bytes, 0, length)
    }
    (input.seek_in)(pos + length)
    if is_malformed(input) {
      (input.seek_in)(original_pos)
      lex_malformed_stream_data(input)
    } else {
      (input.seek_in)(pos + length)
      @pdfgenlex.Token::LexStream(@pdf.Stream::Got(bytes))
    }
  } else {
    (input.seek_in)(pos + length)
    if is_malformed(input) {
      (input.seek_in)(original_pos)
      lex_malformed_stream_data(input)
    } else {
      let toget : @pdf.ToGet = {
        input,
        position: pos,
        length,
        crypt: @pdf.ToGetCrypt::NoChange,
      }
      @pdfgenlex.Token::LexStream(@pdf.Stream::ToGet(toget))
    }
  }
}

///|
fn reverse_tokens(tokens : Array[@pdfgenlex.Token]) -> Array[@pdfgenlex.Token] {
  let out = Array::new(capacity=tokens.length())
  if tokens.length() == 0 {
    return out
  }
  let mut i = tokens.length() - 1
  while true {
    out.push(tokens[i])
    if i == 0 {
      break
    }
    i = i - 1
  }
  out
}

///|
fn take_dict_lexemes(
  previous_lexemes : Array[@pdfgenlex.Token],
) -> Array[@pdfgenlex.Token] {
  let collected = Array::new()
  if previous_lexemes.length() == 0 {
    return collected
  }
  let mut i = previous_lexemes.length() - 1
  while true {
    let t = previous_lexemes[i]
    if t is @pdfgenlex.Token::LexObj {
      break
    }
    collected.push(t)
    if i == 0 {
      break
    }
    i = i - 1
  }
  reverse_tokens(collected)
}

///|
fn lex_stream(
  input : @pdfio.Input,
  previous_lexemes : Array[@pdfgenlex.Token],
  lexobj : (Int) -> Array[@pdfgenlex.Token] raise,
  read_stream_data : Bool,
) -> @pdfgenlex.Token raise {
  fn fail_stream() -> @pdfgenlex.Token raise {
    let message = @pdf.input_pdferror(input, "Failure lexing stream dict")
    raise @pdf.PdfError::Msg(message)
  }

  let dictlexemes = take_dict_lexemes(previous_lexemes)
  let (_, parsed) = parse(dictlexemes)
  match parsed {
    @pdf.PdfObject::Dictionary(_) => {
      let pos = (input.pos_in)()
      fn findlength(value : @pdf.PdfObject) -> Int? raise {
        match value {
          @pdf.PdfObject::Integer(l) => Some(l)
          @pdf.PdfObject::Indirect(k) => {
            let (_, obj) = parse(lexobj(k))
            findlength(obj)
          }
          _ => None
        }
      }

      match @pdf.lookup_direct(@pdf.empty(), "/Length", parsed) {
        None => lex_malformed_stream_data(input)
        Some(v) =>
          match findlength(v) {
            Some(l) => lex_stream_data(input, l, read_stream_data)
            None => {
              (input.seek_in)(pos)
              lex_malformed_stream_data(input)
            }
          }
      }
    }
    _ => fail_stream()
  }
}

///|
fn lex_next(
  dict_level : Ref[Int],
  array_level : Ref[Int],
  end_on_stream : Bool,
  input : @pdfio.Input,
  previous_lexemes : Array[@pdfgenlex.Token],
  read_stream_data : Bool,
  lexobj : (Int) -> Array[@pdfgenlex.Token] raise,
) -> @pdfgenlex.Token raise {
  try {
    dropwhite(input)
    let raw = (input.input_byte)()
    if raw == @pdfio.no_more {
      return @pdfgenlex.Token::StopLexing
    }
    let ch = raw.to_byte().to_char()
    @pdfio.rewind(input)
    match ch {
      '%' => lex_comment(input)
      '/' => lex_name(input)
      '[' => {
        @pdfio.nudge(input)
        array_level.val = array_level.val + 1
        @pdfgenlex.Token::LexLeftSquare
      }
      ']' => {
        @pdfio.nudge(input)
        array_level.val = array_level.val - 1
        @pdfgenlex.Token::LexRightSquare
      }
      '(' => lex_string(input)
      '<' => {
        @pdfio.nudge(input)
        match @pdfio.peek_byte(input) {
          b2 if b2 == '<'.to_int() => {
            @pdfio.nudge(input)
            dict_level.val = dict_level.val + 1
            @pdfgenlex.Token::LexLeftDict
          }
          _ => {
            @pdfio.rewind(input)
            lex_hexstring(input)
          }
        }
      }
      '>' => {
        @pdfio.nudge(input)
        match @pdfio.peek_byte(input) {
          b2 if b2 == '>'.to_int() => {
            @pdfio.nudge(input)
            dict_level.val = dict_level.val - 1
            @pdfgenlex.Token::LexRightDict
          }
          _ => @pdfgenlex.Token::LexNone
        }
      }
      'R' => {
        @pdfio.nudge(input)
        @pdfgenlex.Token::LexR
      }
      's' => {
        let _ = (input.input_byte)()
        let _ = (input.input_byte)()
        let third = (input.input_byte)()
        @pdfio.rewind(input)
        @pdfio.rewind(input)
        @pdfio.rewind(input)
        if third == @pdfio.no_more {
          @pdfgenlex.Token::StopLexing
        } else {
          let c3 = third.to_byte().to_char()
          if c3 == 'a' {
            @pdfgenlex.Token::StopLexing
          } else if end_on_stream {
            @pdfgenlex.Token::StopLexing
          } else {
            lex_stream(input, previous_lexemes, lexobj, read_stream_data)
          }
        }
      }
      'I' => @pdfgenlex.Token::StopLexing
      c if (c >= '0' && c <= '9') || c == '-' || c == '+' || c == '.' =>
        lex_number(input)
      c if c >= 'a' && c <= 'z' => lex_keyword(input)
      _ => @pdfgenlex.Token::LexNone
    }
  } catch {
    err => {
      @pdfe.log("Recovering from lex error: \{err}\n")
      @pdfgenlex.Token::StopLexing
    }
  }
}

///|
/// Lex a dictionary. If minus_one is true, assume the opening << was consumed.
pub fn lex_dictionary(
  minus_one : Bool,
  input : @pdfio.Input,
) -> Array[@pdfgenlex.Token] raise {
  let tokens = Array::new()
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let mut done = false
  let dummy_lexobj = fn(_ : Int) -> Array[@pdfgenlex.Token] raise {
    Array::new()
  }
  while !done {
    let t = lex_next(
      dict_level, array_level, false, input, tokens, false, dummy_lexobj,
    )
    tokens.push(t)
    match t {
      @pdfgenlex.Token::LexRightDict =>
        if dict_level.val == (if minus_one { -1 } else { 0 }) &&
          array_level.val == 0 {
          done = true
        }
      @pdfgenlex.Token::StopLexing => done = true
      @pdfgenlex.Token::LexNone => {
        let message = @pdf.input_pdferror(input, "Could not read dictionary")
        raise @pdf.PdfError::Msg(message)
      }
      _ => ()
    }
  }
  tokens
}

///|
priv enum ParseItem {
  Parsed(@pdf.PdfObject)
  Lexeme(@pdfgenlex.Token)
}

///|
fn parse_R(tokens : Array[@pdfgenlex.Token]) -> Array[ParseItem] {
  let out = Array::new()
  let mut i = 0
  while i < tokens.length() {
    if i + 2 < tokens.length() {
      match (tokens[i], tokens[i + 1], tokens[i + 2]) {
        (
          @pdfgenlex.Token::LexInt(o),
          @pdfgenlex.Token::LexInt(_),
          @pdfgenlex.Token::LexR,
        ) => {
          out.push(ParseItem::Parsed(@pdf.PdfObject::Indirect(o)))
          i = i + 3
          continue
        }
        _ => ()
      }
    }
    match tokens[i] {
      @pdfgenlex.Token::LexComment(_) => ()
      @pdfgenlex.Token::LexNull =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Null))
      @pdfgenlex.Token::LexBool(b) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Boolean(b)))
      @pdfgenlex.Token::LexInt(v) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Integer(v)))
      @pdfgenlex.Token::LexReal(v) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Real(v)))
      @pdfgenlex.Token::LexString(s) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::String(s)))
      @pdfgenlex.Token::LexName(n) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Name(n)))
      other => out.push(ParseItem::Lexeme(other))
    }
    i = i + 1
  }
  out
}

///|
fn parse_dictionary(
  items : Array[ParseItem],
  start : Int,
) -> (ParseItem, Int) raise {
  let entries = Array::new()
  let mut i = start + 1
  while i < items.length() {
    match items[i] {
      ParseItem::Lexeme(@pdfgenlex.Token::LexRightDict) =>
        return (ParseItem::Parsed(@pdf.PdfObject::Dictionary(entries)), i + 1)
      _ => {
        let (key_item, next_i) = parse_value(items, i)
        let (val_item, next_i2) = parse_value(items, next_i)
        match (key_item, val_item) {
          (ParseItem::Parsed(@pdf.PdfObject::Name(k)), ParseItem::Parsed(v)) =>
            entries.push((k, v))
          _ => raise @pdf.PdfError::Msg("parse_dictionary")
        }
        i = next_i2
      }
    }
  }
  raise @pdf.PdfError::Msg("parse_dictionary")
}

///|
fn parse_array(items : Array[ParseItem], start : Int) -> (ParseItem, Int) raise {
  let values = Array::new()
  let mut i = start + 1
  while i < items.length() {
    match items[i] {
      ParseItem::Lexeme(@pdfgenlex.Token::LexRightSquare) =>
        return (ParseItem::Parsed(@pdf.PdfObject::Array(values)), i + 1)
      _ => {
        let (val_item, next_i) = parse_value(items, i)
        match val_item {
          ParseItem::Parsed(v) => values.push(v)
          _ => raise @pdf.PdfError::Msg("parse_array")
        }
        i = next_i
      }
    }
  }
  raise @pdf.PdfError::Msg("parse_array")
}

///|
fn parse_value(items : Array[ParseItem], start : Int) -> (ParseItem, Int) raise {
  if start >= items.length() {
    raise @pdf.PdfError::Msg("parse_value")
  }
  match items[start] {
    ParseItem::Lexeme(@pdfgenlex.Token::LexLeftDict) =>
      parse_dictionary(items, start)
    ParseItem::Lexeme(@pdfgenlex.Token::LexLeftSquare) =>
      parse_array(items, start)
    other => (other, start + 1)
  }
}

///|
fn parse_to_tree(items : Array[ParseItem]) -> Array[ParseItem] raise {
  let out = Array::new()
  let mut i = 0
  while i < items.length() {
    match items[i] {
      ParseItem::Lexeme(@pdfgenlex.Token::LexLeftDict) => {
        let (parsed, next_i) = parse_dictionary(items, i)
        out.push(parsed)
        i = next_i
      }
      ParseItem::Lexeme(@pdfgenlex.Token::LexLeftSquare) => {
        let (parsed, next_i) = parse_array(items, i)
        out.push(parsed)
        i = next_i
      }
      other => {
        out.push(other)
        i = i + 1
      }
    }
  }
  out
}

///|
fn parse_finish(
  items : Array[ParseItem],
  failure_is_ok : Bool,
) -> (Int, @pdf.PdfObject) raise {
  if items.length() == 1 {
    match items[0] {
      ParseItem::Parsed(obj) => return (0, obj)
      _ => raise @pdf.PdfError::Msg("Could not extract object")
    }
  }
  if items.length() >= 5 {
    if items.length() >= 7 {
      match
        (items[0], items[1], items[2], items[3], items[4], items[5], items[6]) {
        (
          ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
          ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
          ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
          ParseItem::Parsed(@pdf.PdfObject::Dictionary(dict)),
          ParseItem::Lexeme(@pdfgenlex.Token::LexStream(stream)),
          ParseItem::Lexeme(@pdfgenlex.Token::LexEndStream),
          ParseItem::Lexeme(@pdfgenlex.Token::LexEndObj),
        ) =>
          return (
            o,
            @pdf.PdfObject::Stream(
              Ref::new((@pdf.PdfObject::Dictionary(dict), stream)),
            ),
          )
        _ => ()
      }
    }
    match (items[0], items[1], items[2], items[3], items[4]) {
      (
        ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
        ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
        ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
        ParseItem::Parsed(obj),
        ParseItem::Lexeme(@pdfgenlex.Token::LexEndObj),
      ) => return (o, obj)
      _ => ()
    }
  }
  if items.length() >= 4 {
    match (items[0], items[1], items[2], items[3]) {
      (
        ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
        ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
        ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
        ParseItem::Parsed(obj),
      ) => return (o, obj)
      (
        ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
        ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
        ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
        ParseItem::Lexeme(@pdfgenlex.Token::LexEndObj),
      ) => return (o, @pdf.PdfObject::Null)
      _ => ()
    }
  }
  if failure_is_ok {
    (0, @pdf.PdfObject::Null)
  } else {
    raise @pdf.PdfError::Msg("Could not extract object")
  }
}

///|
/// Parse a PDF object from tokens.
pub fn parse(
  tokens : Array[@pdfgenlex.Token],
  failure_is_ok? : Bool = false,
) -> (Int, @pdf.PdfObject) raise {
  parse_finish(parse_to_tree(parse_R(tokens)), failure_is_ok) catch {
    err => if failure_is_ok { (0, @pdf.PdfObject::Null) } else { raise err }
  }
}

///|
fn lex_object_at(
  oneonly : Bool,
  input : @pdfio.Input,
  read_stream_data : Bool,
  lexobj : (Int) -> Array[@pdfgenlex.Token] raise,
) -> Array[@pdfgenlex.Token] raise {
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let tokens = Array::new()
  let mut done = false
  while !done {
    let t = lex_next(
      dict_level, array_level, false, input, tokens, read_stream_data, lexobj,
    )
    match t {
      @pdfgenlex.Token::LexEndObj => {
        tokens.push(t)
        done = true
      }
      @pdfgenlex.Token::StopLexing => done = true
      @pdfgenlex.Token::LexComment(_) => tokens.push(t)
      @pdfgenlex.Token::LexRightSquare | @pdfgenlex.Token::LexRightDict =>
        if oneonly && dict_level.val == 0 && array_level.val == 0 {
          tokens.push(t)
          done = true
        } else {
          tokens.push(t)
        }
      @pdfgenlex.Token::LexNone => {
        let message = @pdf.input_pdferror(input, "Could not read object")
        raise @pdf.PdfError::Msg(message)
      }
      other => {
        tokens.push(other)
        if oneonly && dict_level.val == 0 && array_level.val == 0 {
          let is_atom = match other {
            @pdfgenlex.Token::LexBool(_)
            | @pdfgenlex.Token::LexReal(_)
            | @pdfgenlex.Token::LexString(_)
            | @pdfgenlex.Token::LexName(_)
            | @pdfgenlex.Token::LexNull
            | @pdfgenlex.Token::LexInt(_) => true
            _ => false
          }
          if is_atom {
            done = true
          }
        }
      }
    }
  }
  tokens
}

///|
fn lex_object_for_xref(
  input : @pdfio.Input,
  xrefs : Map[Int, XRef],
  read_stream_data : Bool,
  objnum : Int,
) -> Array[@pdfgenlex.Token] raise {
  let current_pos = (input.pos_in)()
  match xrefs.get(objnum) {
    Some(XRef::Plain(offset, _gen)) => {
      (input.seek_in)(offset)
      let tokens = lex_object_at(false, input, read_stream_data, fn(
        k : Int,
      ) -> Array[@pdfgenlex.Token] raise {
        lex_object_for_xref(input, xrefs, read_stream_data, k)
      })
      (input.seek_in)(current_pos)
      tokens
    }
    Some(XRef::Stream(_, _)) => {
      let message = @pdf.input_pdferror(input, "Object in object stream")
      raise @pdf.PdfError::Msg(message)
    }
    None => {
      let message = @pdf.input_pdferror(input, "Object not in xref table")
      raise @pdf.PdfError::Msg(message)
    }
  }
}

///|
/// Parse a single object from a string.
pub fn parse_single_object(s : String) -> @pdf.PdfObject raise {
  let input = @pdfio.input_of_string(s)
  let (_, obj) = parse(
    lex_object_at(true, input, true, fn(
      _ : Int,
    ) -> Array[@pdfgenlex.Token] raise {
      Array::new()
    }),
  )
  obj
}

///|
fn trim_trailing_zeros(value : String) -> String {
  let dot = value.find(".")
  match dot {
    None => value
    Some(_) => {
      let chars = value.to_array()
      let mut end = chars.length() - 1
      while end >= 0 && chars[end] == '0' {
        end = end - 1
      }
      if end >= 0 && chars[end] == '.' {
        end = end - 1
      }
      if end < 0 {
        "0"
      } else {
        let sb = StringBuilder::new()
        let mut i = 0
        while i <= end {
          sb.write_char(chars[i])
          i = i + 1
        }
        sb.to_string()
      }
    }
  }
}

///|
fn slice_from(value : String, start : Int) -> String {
  try value[start:] catch {
    _ => ""
  } noraise {
    view => view.to_string()
  }
}

///|
fn slice_range(value : String, start : Int, end : Int) -> String {
  try value[start:end] catch {
    _ => ""
  } noraise {
    view => view.to_string()
  }
}

///|
fn parse_signed_int(value : String) -> Int {
  let chars = value.to_array()
  if chars.length() == 0 {
    return 0
  }
  let mut sign = 1
  let mut i = 0
  match chars[0] {
    '-' => {
      sign = -1
      i = 1
    }
    '+' => i = 1
    _ => ()
  }
  let mut result = 0
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      break
    }
    result = result * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  sign * result
}

///|
fn expand_scientific(value : String) -> String {
  let (sign, body) = match value.get_char(0) {
    Some('-') => ("-", slice_from(value, 1))
    _ => ("", value)
  }
  let exp_index = match body.find("e") {
    Some(i) => Some(i)
    None => body.find("E")
  }
  match exp_index {
    None => sign + trim_trailing_zeros(body)
    Some(idx) => {
      let mantissa = slice_range(body, 0, idx)
      let exp_str = slice_from(body, idx + 1)
      let exp = parse_signed_int(exp_str)
      let digits = Array::new()
      let mut int_len = 0
      let mut saw_dot = false
      for ch in mantissa {
        if ch == '.' {
          saw_dot = true
        } else {
          if !saw_dot {
            int_len = int_len + 1
          }
          digits.push(ch)
        }
      }
      if digits.length() == 0 {
        sign + "0"
      } else {
        let new_pos = int_len + exp
        let sb = StringBuilder::new()
        sb.write_string(sign)
        if new_pos <= 0 {
          sb.write_string("0.")
          let mut z = 0
          while z < -new_pos {
            sb.write_char('0')
            z = z + 1
          }
          for ch in digits {
            sb.write_char(ch)
          }
        } else if new_pos >= digits.length() {
          for ch in digits {
            sb.write_char(ch)
          }
          let mut z = 0
          while z < new_pos - digits.length() {
            sb.write_char('0')
            z = z + 1
          }
        } else {
          let mut i = 0
          while i < digits.length() {
            if i == new_pos {
              sb.write_char('.')
            }
            sb.write_char(digits[i])
            i = i + 1
          }
        }
        trim_trailing_zeros(sb.to_string())
      }
    }
  }
}

///|
fn format_real(value : Double) -> String {
  if value == 0.0 {
    return "0"
  }
  let raw = value.to_string()
  if raw.contains("e") || raw.contains("E") {
    expand_scientific(raw)
  } else {
    trim_trailing_zeros(raw)
  }
}

///|
fn make_pdf_string(value : String) -> String {
  let sb = StringBuilder::new()
  sb.write_char('(')
  for ch in value {
    match ch {
      '(' | ')' | '\\' => {
        sb.write_char('\\')
        sb.write_char(ch)
      }
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      '\b' => sb.write_string("\\b")
      '\f' => sb.write_string("\\f")
      _ => sb.write_char(ch)
    }
  }
  sb.write_char(')')
  sb.to_string()
}

///|
/// String of a lexeme.
pub fn string_of_lexeme(t : @pdfgenlex.Token) -> String {
  match t {
    @pdfgenlex.Token::LexNull => "null"
    @pdfgenlex.Token::LexBool(b) => if b { "true" } else { "false" }
    @pdfgenlex.Token::LexInt(i) => i.to_string()
    @pdfgenlex.Token::LexReal(r) => format_real(r)
    @pdfgenlex.Token::LexString(s) => make_pdf_string(s)
    @pdfgenlex.Token::LexName(s) => s
    @pdfgenlex.Token::LexLeftSquare => "["
    @pdfgenlex.Token::LexRightSquare => "]"
    @pdfgenlex.Token::LexLeftDict => "<<"
    @pdfgenlex.Token::LexRightDict => ">>"
    @pdfgenlex.Token::LexStream(_) => "LexStream"
    @pdfgenlex.Token::LexEndStream => "EndStream"
    @pdfgenlex.Token::LexObj => "obj"
    @pdfgenlex.Token::LexEndObj => "endobj"
    @pdfgenlex.Token::LexR => "R"
    @pdfgenlex.Token::LexComment(c) => "\n%\{c}\n"
    @pdfgenlex.Token::StopLexing => "StopLexing"
    @pdfgenlex.Token::LexNone => "LexNone"
  }
}

///|
/// Print a lexeme to stdout.
pub fn print_lexeme(t : @pdfgenlex.Token) -> Unit {
  @pdfutil.flprint(string_of_lexeme(t) + " ")
}

///|
/// Hook for page-tree traversal (placeholder).
pub let endpage : Ref[(@pdf.Pdf) -> Int] = { val: _ => 0 }

///|
/// Register pdf_of_file hook for decoder modules.
fn pdf_of_file_unlabeled(
  revision : Int?,
  user_password : String?,
  owner_password : String?,
  filename : String,
) -> @pdf.Pdf raise {
  match revision {
    Some(r) => pdf_of_file(revision=r, user_password, owner_password, filename)
    None => pdf_of_file(user_password, owner_password, filename)
  }
}

///|
fn init {
  @pdfcodec.pdf_of_file.val = pdf_of_file_unlabeled
}
