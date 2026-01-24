///|
/// Debug flag for PDF reading (re-exported from pdfe).
let read_debug : Ref[Bool] = @pdfe.read_debug

///|
/// If true, do not attempt malformed PDF recovery.
let error_on_malformed : Ref[Bool] = { val: false }

///|
/// If true, always treat PDFs as malformed.
let debug_always_treat_malformed : Ref[Bool] = { val: false }

///|
pub struct PdfRead {
  unit : Unit
}

///|
pub fn PdfRead::new() -> PdfRead {
  { unit: () }
}

///|
/// Read a PDF from an input.
#as_free_fn(pdf_of_input, deprecated="Use `PdfRead::pdf_of_input`")
pub fn PdfRead::pdf_of_input(
  _self : PdfRead,
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  input : @pdfio.Input,
) -> @pdf.Pdf raise {
  read_pdf_internal(revision, user_password, owner_password, input, true)
}

///|
/// Read a PDF from an input, lazily.
#as_free_fn(pdf_of_input_lazy, deprecated="Use `PdfRead::pdf_of_input_lazy`")
pub fn PdfRead::pdf_of_input_lazy(
  _self : PdfRead,
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  input : @pdfio.Input,
) -> @pdf.Pdf raise {
  read_pdf_internal(revision, user_password, owner_password, input, false)
}

///|
/// Read a PDF from a channel.
#as_free_fn(pdf_of_channel, deprecated="Use `PdfRead::pdf_of_channel`")
pub async fn PdfRead::pdf_of_channel(
  _self : PdfRead,
  revision? : Int,
  source? : String = "channel",
  user_password : String?,
  owner_password : String?,
  channel : @fs.File,
) -> @pdf.Pdf {
  let input = @pdfio.Input::of_channel(channel, source~)
  read_pdf_internal(revision, user_password, owner_password, input, true)
}

///|
/// Read a PDF from a channel lazily.
#as_free_fn(pdf_of_channel_lazy, deprecated="Use `PdfRead::pdf_of_channel_lazy`")
pub async fn PdfRead::pdf_of_channel_lazy(
  _self : PdfRead,
  revision? : Int,
  source? : String = "channel",
  user_password : String?,
  owner_password : String?,
  channel : @fs.File,
) -> @pdf.Pdf {
  let input = @pdfio.Input::of_channel(channel, source~)
  read_pdf_internal(revision, user_password, owner_password, input, false)
}

///|
/// Read a PDF from a file.
#as_free_fn(pdf_of_file, deprecated="Use `PdfRead::pdf_of_file`")
pub async fn PdfRead::pdf_of_file(
  _self : PdfRead,
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  filename : String,
) -> @pdf.Pdf {
  let input = @pdfio.Input::of_file(filename, source=filename)
  read_pdf_internal(revision, user_password, owner_password, input, true)
}

///|
/// Return number of revisions.
#as_free_fn(revisions, deprecated="Use `PdfRead::revisions`")
pub fn PdfRead::revisions(_self : PdfRead, input : @pdfio.Input) -> Int raise {
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
#as_free_fn(what_encryption, deprecated="Use `PdfRead::what_encryption`")
pub fn PdfRead::what_encryption(
  _self : PdfRead,
  pdf : @pdf.Pdf,
) -> @pdfcrypt.EncryptionMethod? {
  if !@pdfcrypt.PdfCrypt::new().is_encrypted(pdf) {
    return None
  }
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
  ] = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  match values {
    Ok((crypt, _, _, _, _, _, _)) => {
      let metadata = match pdf.lookup_direct("/Encrypt", pdf.trailerdict) {
        Some(encrypt_dict) =>
          match pdf.lookup_direct("/EncryptMetadata", encrypt_dict) {
            Some(@pdf.PdfObject::Boolean(false)) => false
            _ => true
          }
        None => true
      }
      match crypt {
        @pdfcryptprimitives.Encryption::ARC4(bits, _) =>
          match bits {
            40 => Some(@pdfcrypt.EncryptionMethod::PDF40bit)
            128 => Some(@pdfcrypt.EncryptionMethod::PDF128bit)
            _ => None
          }
        @pdfcryptprimitives.Encryption::AESV2 =>
          Some(@pdfcrypt.EncryptionMethod::AES128bit(metadata))
        @pdfcryptprimitives.Encryption::AESV3(is_iso) =>
          if is_iso {
            Some(@pdfcrypt.EncryptionMethod::AES256bitISO(metadata))
          } else {
            Some(@pdfcrypt.EncryptionMethod::AES256bit(metadata))
          }
      }
    }
    Err(_) => None
  }
}

///|
/// Return list of permissions.
#as_free_fn(permissions, deprecated="Use `PdfRead::permissions`")
pub fn PdfRead::permissions(
  _self : PdfRead,
  pdf : @pdf.Pdf,
) -> Array[@pdfcrypt.Permission] {
  if !@pdfcrypt.PdfCrypt::new().is_encrypted(pdf) {
    return []
  }
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
  ] = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  match values {
    Ok((_, _, _, p, _, _, _)) => @pdfcrypt.PdfCrypt::new().banlist_of_p(p)
    Err(_) => []
  }
}

///|
/// Check if input is linearized.
#as_free_fn(is_linearized, deprecated="Use `PdfRead::is_linearized`")
pub fn PdfRead::is_linearized(_self : PdfRead, input : @pdfio.Input) -> Bool {
  try {
    let _ = read_header(input)
    let lexemes = @pdfsyntax.PdfSyntax::new().lex_dictionary(false, input)
    let (_, parsed) = @pdfsyntax.PdfSyntax::new().parse(
      lexemes,
      failure_is_ok=true,
    )
    match @pdf.Pdf::empty().lookup_direct("/Linearized", parsed) {
      Some(@pdf.PdfObject::Integer(_)) | Some(@pdf.PdfObject::Real(_)) => true
      _ => false
    }
  } catch {
    _ => false
  }
}

///|
/// Read a PDF header.
fn read_header(input : @pdfio.Input) -> (Int, Int) raise {
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
        @pdfe.Pdfe::new().log("setting offset to \{pos}\n")
      }
      (input.set_offset)(pos)
      return (major_char.to_int() - '0'.to_int(), digits_to_int(minor_digits))
    }
    pos = pos + 1
  }
  (2, 0)
}
