///|
/// Debug flag for PDF reading (re-exported from pdfe).
pub let read_debug : Ref[Bool] = @pdfe.read_debug

///|
/// If true, do not attempt malformed PDF recovery.
pub let error_on_malformed : Ref[Bool] = { val: false }

///|
/// If true, always treat PDFs as malformed.
pub let debug_always_treat_malformed : Ref[Bool] = { val: false }

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
pub async fn pdf_of_channel(
  revision? : Int,
  source? : String = "channel",
  user_password : String?,
  owner_password : String?,
  channel : @fs.File,
) -> @pdf.Pdf {
  let input = @pdfio.input_of_channel(channel, source~)
  read_pdf_internal(revision, user_password, owner_password, input, true)
}

///|
/// Read a PDF from a channel lazily.
pub async fn pdf_of_channel_lazy(
  revision? : Int,
  source? : String = "channel",
  user_password : String?,
  owner_password : String?,
  channel : @fs.File,
) -> @pdf.Pdf {
  let input = @pdfio.input_of_channel(channel, source~)
  read_pdf_internal(revision, user_password, owner_password, input, false)
}

///|
/// Read a PDF from a file.
pub async fn pdf_of_file(
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  filename : String,
) -> @pdf.Pdf {
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
pub fn what_encryption(pdf : @pdf.Pdf) -> @pdfcrypt.EncryptionMethod? {
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
    let lexemes = @pdfsyntax.lex_dictionary(false, input)
    let (_, parsed) = @pdfsyntax.parse(lexemes, failure_is_ok=true)
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
