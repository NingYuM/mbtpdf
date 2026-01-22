///|
fn already_decrypted(pdf : @pdf.Pdf, objnum : Int) -> Bool {
  try {
    let entry = @pdf.pdfobjmap_find(objnum, pdf.objects.objects)
    match entry.0.val {
      @pdf.ObjectData::ParsedAlreadyDecrypted(_) => true
      _ => false
    }
  } catch {
    _ => false
  }
}

///|
fn is_identity(
  no_encrypt_metadata : Bool,
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
) -> Bool {
  let identity_crypt_filter_present = match
    @pdf.lookup_direct(pdf, "/Filter", dict) {
    Some(Name("/Crypt")) => true
    Some(Array([Name("/Crypt"), ..])) => true
    _ => false
  }
  let identity_param = if identity_crypt_filter_present {
    match @pdf.lookup_direct(pdf, "/DecodeParms", dict) {
      Some(Dictionary(decodeparms)) =>
        match
          @pdf.lookup_direct(pdf, "/Name", @pdf.PdfObject::Dictionary(decodeparms)) {
          Some(Name("/Identity")) | None => true
          _ => false
        }
      Some(Array([Dictionary(decodeparms), ..])) =>
        match
          @pdf.lookup_direct(pdf, "/Name", @pdf.PdfObject::Dictionary(decodeparms)) {
          Some(Name("/Identity")) | None => true
          _ => false
        }
      Some(Array(_)) => true
      _ => true
    }
  } else {
    false
  }
  let is_metadata = if no_encrypt_metadata {
    match @pdf.lookup_direct(pdf, "/Type", dict) {
      Some(Name("/Metadata")) => true
      _ => false
    }
  } else {
    false
  }
  is_metadata || identity_param
}

///|
fn decrypt_stream(
  decrypt_obj : (@pdf.PdfObject) -> @pdf.PdfObject raise,
  crypt_type : @pdfcryptprimitives.Encryption,
  pdf : @pdf.Pdf,
  no_encrypt_metadata : Bool,
  encrypt : Bool,
  obj : Int,
  gen : Int,
  key : Array[Int],
  keylength : Int,
  r : Int,
  file_encryption_key : String?,
  stream : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  match (stream : @pdf.PdfObject) {
    Stream(rf) =>
      match rf.val {
        (dict, data) =>
          if is_identity(no_encrypt_metadata, pdf, dict) {
            stream
          } else {
            let crypt = @pdf.ToGetCrypt::ToDecrypt(@pdf.DeferredEncryption::{
              crypt_type,
              file_encryption_key,
              obj,
              gen,
              key,
              keylength,
              r,
            })
            let apply_bytes = fn(
              key_used : Array[Int],
              bytes : @pdfio.MutableBytes,
            ) -> @pdfio.MutableBytes {
              match (crypt_type : @pdfcryptprimitives.Encryption) {
                AESV2 =>
                  if encrypt {
                    @pdfcryptprimitives.aes_encrypt_data(4, key_used, bytes)
                  } else {
                    @pdfcryptprimitives.aes_decrypt_data(4, key_used, bytes)
                  }
                AESV3(_) =>
                  if encrypt {
                    @pdfcryptprimitives.aes_encrypt_data(8, key_used, bytes)
                  } else {
                    @pdfcryptprimitives.aes_decrypt_data(8, key_used, bytes)
                  }
                ARC4(_, _) => @pdfcryptprimitives.crypt(key_used, bytes)
              }
            }
            let data_out : @pdf.Stream = if r == 5 || r == 6 {
              let key_bytes = match file_encryption_key {
                Some(k) => @pdfio.int_array_of_string(k)
                None => raise @pdf.PdfError::Msg("decrypt: no key C")
              }
              match data {
                Got(bytes) => Got(apply_bytes(key_bytes, bytes))
                ToGet(toget) =>
                  if encrypt {
                    @pdf.getstream(@pdf.PdfObject::Stream(rf))
                    match rf.val {
                      (_, Got(got_bytes)) => Got(apply_bytes(key_bytes, got_bytes))
                      _ => data
                    }
                  } else {
                    ToGet(@pdf.ToGet::{
                      input: toget.input,
                      position: toget.position,
                      length: toget.length,
                      crypt,
                    })
                  }
              }
            } else {
              let hash = @pdfcryptprimitives.find_hash(
                crypt_type, obj, gen, key, keylength,
              )
              match data {
                Got(bytes) => Got(apply_bytes(hash, bytes))
                ToGet(toget) =>
                  if encrypt {
                    @pdf.getstream(@pdf.PdfObject::Stream(rf))
                    match rf.val {
                      (_, Got(got_bytes)) => Got(apply_bytes(hash, got_bytes))
                      _ => data
                    }
                  } else {
                    ToGet(@pdf.ToGet::{
                      input: toget.input,
                      position: toget.position,
                      length: toget.length,
                      crypt,
                    })
                  }
              }
            }
            let dict_out : @pdf.PdfObject = match (dict : @pdf.PdfObject) {
              Dictionary(entries) => {
                let out = Array::new(capacity=entries.length())
                for entry in entries {
                  out.push((entry.0, decrypt_obj(entry.1)))
                }
                Dictionary(out)
              }
              _ => dict
            }
            let dict_updated = match data_out {
              Got(bytes) =>
                @pdf.replace_dict_entry(
                  dict_out,
                  "/Length",
                  @pdf.PdfObject::Integer(bytes.length()),
                )
              _ => dict_out
            }
            rf.val = (dict_updated, data_out)
            Stream(rf)
          }
      }
    _ => stream
  }
}

///|
fn decrypt(
  crypt_type : @pdfcryptprimitives.Encryption,
  pdf : @pdf.Pdf,
  no_encrypt_metadata : Bool,
  encrypt : Bool,
  obj : Int,
  gen : Int,
  key : Array[Int],
  keylength : Int,
  r : Int,
  file_encryption_key : String?,
  objval : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  let decrypt_obj = fn(value : @pdf.PdfObject) -> @pdf.PdfObject raise {
    decrypt(
      crypt_type, pdf, no_encrypt_metadata, encrypt, obj, gen, key, keylength, r,
      file_encryption_key, value,
    )
  }
  match objval {
    String(s) =>
      if already_decrypted(pdf, obj) {
        objval
      } else {
        let s_bytes = @pdfio.bytes_of_string(s)
        let out_bytes = if r == 5 || r == 6 {
          let key_bytes = match file_encryption_key {
            Some(k) => @pdfio.int_array_of_string(k)
            None => raise @pdf.PdfError::Msg("decrypt: no key B")
          }
          match (crypt_type : @pdfcryptprimitives.Encryption) {
            AESV2 =>
              if encrypt {
                @pdfcryptprimitives.aes_encrypt_data(4, key_bytes, s_bytes)
              } else {
                @pdfcryptprimitives.aes_decrypt_data(4, key_bytes, s_bytes)
              }
            AESV3(_) =>
              if encrypt {
                @pdfcryptprimitives.aes_encrypt_data(8, key_bytes, s_bytes)
              } else {
                @pdfcryptprimitives.aes_decrypt_data(8, key_bytes, s_bytes)
              }
            ARC4(_, _) => @pdfcryptprimitives.crypt(key_bytes, s_bytes)
          }
        } else {
          let hash = @pdfcryptprimitives.find_hash(
            crypt_type, obj, gen, key, keylength,
          )
          match (crypt_type : @pdfcryptprimitives.Encryption) {
            AESV2 =>
              if encrypt {
                @pdfcryptprimitives.aes_encrypt_data(4, hash, s_bytes)
              } else {
                @pdfcryptprimitives.aes_decrypt_data(4, hash, s_bytes)
              }
            AESV3(_) =>
              if encrypt {
                @pdfcryptprimitives.aes_encrypt_data(8, hash, s_bytes)
              } else {
                @pdfcryptprimitives.aes_decrypt_data(8, hash, s_bytes)
              }
            ARC4(_, _) => @pdfcryptprimitives.crypt(hash, s_bytes)
          }
        }
        String(@pdfio.string_of_bytes(out_bytes))
      }
    Stream(_) =>
      decrypt_stream(
        decrypt_obj, crypt_type, pdf, no_encrypt_metadata, encrypt, obj, gen, key,
        keylength, r, file_encryption_key, objval,
      )
    Array(values) =>
      if already_decrypted(pdf, obj) {
        objval
      } else {
        let out = Array::new(capacity=values.length())
        for value in values {
          out.push(decrypt_obj(value))
        }
        Array(out)
      }
    Dictionary(values) =>
      if already_decrypted(pdf, obj) {
        objval
      } else {
        let out = Array::new(capacity=values.length())
        for entry in values {
          out.push((entry.0, decrypt_obj(entry.1)))
        }
        Dictionary(out)
      }
    _ => objval
  }
}

///|
fn process_cryption(
  no_encrypt_metadata : Bool,
  encrypt : Bool,
  pdf : @pdf.Pdf,
  crypt_type : @pdfcryptprimitives.Encryption,
  user_pw : String,
  r : Int,
  u : String,
  o : String,
  p : Int,
  id : String,
  keylength : Int,
  file_encryption_key : String?,
) -> @pdf.Pdf? raise {
  let mut encryption_object_number = -1
  match (pdf.trailerdict : @pdf.PdfObject) {
    Dictionary(entries) => {
      let mut i = 0
      while i < entries.length() {
        let (k, v) = entries[i]
        if k == "/Encrypt" {
          match (v : @pdf.PdfObject) {
            Indirect(n) => encryption_object_number = n
            _ => ()
          }
          i = entries.length()
        } else {
          i = i + 1
        }
      }
    }
    _ => ()
  }
  let do_encryption = fn(key : Array[Int]) -> @pdf.Pdf? raise {
    let entries = pdf.objects.objects.to_array()
    entries.sort_by((a, b) => a.0 - b.0)
    for entry in entries {
      let objnum = entry.0
      let gennum = entry.1.1
      if objnum != encryption_object_number {
        let obj = @pdf.lookup_obj(pdf, objnum)
        let new_obj = decrypt(
          crypt_type, pdf, no_encrypt_metadata, encrypt, objnum, gennum, key, keylength,
          r, file_encryption_key, obj,
        ) catch {
          _ => {
            @pdfe.log("Warning: unable to decrypt object \{objnum}\n")
            obj
          }
        }
        @pdf.addobj_given_num(pdf, (objnum, new_obj))
      }
    }
    pdf.trailerdict = @pdf.remove_dict_entry(pdf.trailerdict, "/Encrypt")
    Some(pdf)
  }
  if r == 5 || r == 6 {
    match file_encryption_key {
      Some(k) => do_encryption(@pdfio.int_array_of_string(k))
      None => None
    }
  } else if authenticate_user(
      no_encrypt_metadata, user_pw, r, u, o, p, id, keylength,
    ) {
    do_encryption(
      find_key(no_encrypt_metadata, user_pw, r, o, p, id, keylength),
    )
  } else {
    None
  }
}

///|
/// Read encryption parameters from an encrypted PDF.
pub fn get_encryption_values(
  pdf : @pdf.Pdf,
) -> (
  @pdfcryptprimitives.Encryption,
  String,
  String,
  Int,
  String,
  String?,
  String?,
) raise {
  let encryptdict = match @pdf.lookup_direct(pdf, "/Encrypt", pdf.trailerdict) {
    Some(value) => value
    None => raise @pdf.PdfError::Msg("get_encryption_values: unencrypted pdf")
  }
  let filter = @pdf.lookup_direct(pdf, "/Filter", encryptdict)
  let v_val = @pdf.lookup_direct(pdf, "/V", encryptdict)
  let length_val = @pdf.lookup_direct(pdf, "/Length", encryptdict)
  let r_val = @pdf.lookup_direct(pdf, "/R", encryptdict)
  let crypt_type = match (filter, v_val, length_val, r_val) {
    (
      Some(@pdf.PdfObject::Name("/Standard")),
      Some(@pdf.PdfObject::Integer(1)),
      _,
      Some(@pdf.PdfObject::Integer(r)),
    ) => Some(@pdfcryptprimitives.Encryption::ARC4(40, r))
    (
      Some(@pdf.PdfObject::Name("/Standard")),
      Some(@pdf.PdfObject::Integer(2)),
      None,
      Some(@pdf.PdfObject::Integer(r)),
    ) => Some(@pdfcryptprimitives.Encryption::ARC4(40, r))
    (
      Some(@pdf.PdfObject::Name("/Standard")),
      Some(@pdf.PdfObject::Integer(2)),
      Some(@pdf.PdfObject::Integer(n)),
      _,
    ) =>
      if n % 8 == 0 && n >= 40 && n <= 128 {
        Some(@pdfcryptprimitives.Encryption::ARC4(n, 3))
      } else {
        None
      }
    (
      Some(@pdf.PdfObject::Name("/Standard")),
      Some(@pdf.PdfObject::Integer(v)),
      length,
      Some(@pdf.PdfObject::Integer(r)),
    ) =>
      if v == 4 || v == 5 {
        match @pdf.lookup_direct(pdf, "/CF", encryptdict) {
          Some(cfdict) =>
            match @pdf.lookup_direct(pdf, "/StdCF", cfdict) {
              Some(stdcfdict) =>
                match @pdf.lookup_direct(pdf, "/CFM", stdcfdict) {
                  Some(@pdf.PdfObject::Name("/V2")) =>
                    match length {
                      Some(@pdf.PdfObject::Integer(i)) =>
                        Some(@pdfcryptprimitives.Encryption::ARC4(i, 4))
                      _ =>
                        match @pdf.lookup_direct(pdf, "/Length", cfdict) {
                          Some(@pdf.PdfObject::Integer(i)) =>
                            Some(@pdfcryptprimitives.Encryption::ARC4(i, 4))
                          _ => None
                        }
                    }
                  Some(@pdf.PdfObject::Name("/AESV2")) =>
                    Some(@pdfcryptprimitives.Encryption::AESV2)
                  Some(@pdf.PdfObject::Name("/AESV3")) =>
                    Some(@pdfcryptprimitives.Encryption::AESV3(r == 6))
                  _ => None
                }
              _ => None
            }
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
  let chop_string3248 = fn(name : String, s : String) -> String raise {
    let need = match crypt_type {
      Some(@pdfcryptprimitives.Encryption::AESV3(_)) => 48
      _ => 32
    }
    if s.length() < need {
      raise @pdf.PdfError::Msg("\{name}: too small in get_encryption_values")
    } else {
      s[0:need].to_string()
    }
  }
  match crypt_type {
    None => raise @pdf.PdfError::Msg("No encryption method")
    Some(ct) => {
      let o = match @pdf.lookup_direct(pdf, "/O", encryptdict) {
        Some(String(o)) => chop_string3248("/O", o)
        _ => raise @pdf.PdfError::Msg("Bad or missing /O entry")
      }
      let u = match @pdf.lookup_direct(pdf, "/U", encryptdict) {
        Some(String(u)) => chop_string3248("/U", u)
        _ => raise @pdf.PdfError::Msg("Bad or missing /U entry")
      }
      let p = match @pdf.lookup_direct(pdf, "/P", encryptdict) {
        Some(Integer(flags)) => flags
        _ => raise @pdf.PdfError::Msg("Bad or missing /P entry")
      }
      let id = match @pdf.lookup_direct(pdf, "/ID", pdf.trailerdict) {
        Some(Array([String(s), _])) => s
        _ => raise @pdf.PdfError::Msg("Bad or missing /ID element")
      }
      let oe = match @pdf.lookup_direct(pdf, "/OE", encryptdict) {
        Some(String(s)) => Some(s)
        _ => None
      }
      let ue = match @pdf.lookup_direct(pdf, "/UE", encryptdict) {
        Some(String(s)) => Some(s)
        _ => None
      }
      (ct, u, o, p, id, ue, oe)
    }
  }
}

///|
/// Decrypt a PDF document using the user password.
pub fn decrypt_pdf(
  user_pw : String,
  pdf : @pdf.Pdf,
  keyfromowner? : String,
) -> (@pdf.Pdf?, Array[Permission]) raise {
  match @pdf.lookup_direct(pdf, "/Encrypt", pdf.trailerdict) {
    None => (Some(pdf), [])
    Some(encrypt_dict) => {
      let (crypt_type, u, o, p, id, ue, oe) = get_encryption_values(pdf)
      let (r, keylength, file_encryption_key) = match (crypt_type : @pdfcryptprimitives.Encryption) {
        AESV2 => (4, 128, None)
        AESV3(iso) =>
          match (oe, ue) {
            (Some(_), Some(ue_val)) =>
              match keyfromowner {
                Some(k) => (5, 256, Some(k))
                None => {
                  let perms = match @pdf.lookup_direct(pdf, "/Perms", encrypt_dict) {
                    Some(String(s)) => s
                    _ =>
                      raise @pdf.PdfError::Msg(
                        "Missing /Perms in encryption dictionary",
                      )
                  }
                  let auth = authenticate_user_password_aesv3(
                    iso,
                    make_utf8(user_pw),
                    u,
                  )
                  if !auth {
                    (5, 256, None)
                  } else {
                    let key = file_encryption_key_aesv3_user(
                      iso,
                      make_utf8(user_pw),
                      u,
                      ue_val,
                    )
                    match p_of_perms(key, perms) {
                      None =>
                        raise Failure::Failure(
                          "/Perms file permissions corrupted",
                        )
                      Some(x) if x == p =>
                        (5, 256, Some(@pdfio.string_of_bytes(key)))
                      Some(_) =>
                        raise Failure::Failure(
                          "Mismatched /Perms and /P permissions",
                        )
                    }
                  }
                }
              }
            _ => raise Failure::Failure("decrypt_pdf: no oe")
          }
        ARC4(k, r_val) => (r_val, k, None)
      }
      let encrypt_metadata = match @pdf.lookup_direct(pdf, "/EncryptMetadata", encrypt_dict) {
        Some(Boolean(false)) => false
        _ => true
      }
      let perms = match @pdf.lookup_direct(pdf, "/Perms", encrypt_dict) {
        Some(String(s)) => s
        _ => ""
      }
      pdf.saved_encryption = Some(@pdf.SavedEncryption::{
        from_get_encryption_values: (crypt_type, u, o, p, id, ue, oe),
        encrypt_metadata,
        perms,
      })
      (
        process_cryption(
          !encrypt_metadata,
          false,
          pdf,
          crypt_type,
          user_pw,
          r,
          u,
          o,
          p,
          id,
          keylength,
          file_encryption_key,
        ),
        banlist_of_p(p),
      )
    }
  }
}

///|
fn key_or_user_password_from_owner(
  owner_pw : String,
  pdf : @pdf.Pdf,
  encryption_values? : (@pdfcryptprimitives.Encryption, String, String, String?),
) -> (String, String)? raise {
  let padded_owner = pad_password(@pdfio.int_array_of_string(owner_pw))
  let (crypt_type, u, o, oe) = match encryption_values {
    Some(values) => values
    None => {
      let (crypt_type, u, o, _, _, _, oe) = get_encryption_values(pdf)
      (crypt_type, u, o, oe)
    }
  }
  let (r, keylength) = match crypt_type {
    @pdfcryptprimitives.Encryption::AESV2 => (4, 128)
    @pdfcryptprimitives.Encryption::AESV3(iso) => (if iso { 6 } else { 5 }, 256)
    @pdfcryptprimitives.Encryption::ARC4(k, r_val) => (r_val, k)
  }
  if r == 5 || r == 6 {
    if authenticate_owner_password_aesv3(r == 6, make_utf8(owner_pw), u, o) {
      match oe {
        Some(oe_val) => {
          let key = @pdfio.string_of_bytes(
            file_encryption_key_aesv3(r == 6, make_utf8(owner_pw), o, oe_val, u),
          )
          Some((key, ""))
        }
        None =>
          raise @pdf.PdfError::Msg("decrypt_pdf_owner: No /OE entry found")
      }
    } else {
      None
    }
  } else {
    let user_pw = {
      let key = owner_key(padded_owner, keylength, r)
      if r == 2 {
        @pdfio.string_of_bytes(
          @pdfcryptprimitives.crypt(key, @pdfio.bytes_of_string(o)),
        )
      } else {
        let mut acc = @pdfcryptprimitives.crypt(key, @pdfio.bytes_of_string(o))
        let mut x = 19
        while x >= 0 {
          acc = @pdfcryptprimitives.crypt(mkkey(key, x), acc)
          x = x - 1
        }
        @pdfio.string_of_bytes(acc)
      }
    }
    Some(("", user_pw))
  }
}

///|
/// Decrypt a PDF document using the owner password.
pub fn decrypt_pdf_owner(owner_pw : String, pdf : @pdf.Pdf) -> @pdf.Pdf? raise {
  match @pdf.lookup_direct(pdf, "/Encrypt", pdf.trailerdict) {
    None => Some(pdf)
    Some(_) =>
      match key_or_user_password_from_owner(owner_pw, pdf) {
        None => None
        Some((key, user_pw)) => {
          let (pdf_opt, _) = decrypt_pdf(user_pw, pdf, keyfromowner=key)
          pdf_opt
        }
      }
  }
}

///|
/// Just decrypt a single stream, given the user password and pdf.
pub fn decrypt_single_stream(
  user_pw : String?,
  owner_pw : String?,
  pdf : @pdf.Pdf,
  obj : Int,
  gen : Int,
  stream : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  match @pdf.lookup_direct(pdf, "/Encrypt", pdf.trailerdict) {
    None => stream
    Some(encrypt_dict) => {
      let (crypt_type, u, o, p, id, ue, oe) = get_encryption_values(pdf)
      let (r, keylength) = match crypt_type {
        @pdfcryptprimitives.Encryption::AESV2 => (4, 128)
        @pdfcryptprimitives.Encryption::AESV3(iso) =>
          (if iso { 6 } else { 5 }, 256)
        @pdfcryptprimitives.Encryption::ARC4(k, r_val) => (r_val, k)
      }
      let no_encrypt_metadata = match
        @pdf.lookup_direct(pdf, "/EncryptMetadata", encrypt_dict) {
        Some(@pdf.PdfObject::Boolean(false)) => true
        _ => false
      }
      match (r, keylength, ue, oe) {
        (5 | 6, 256, Some(ue_val), Some(oe_val)) => {
          let owner_pw_val = match owner_pw {
            Some(value) => value
            None => ""
          }
          let user_pw_val = match user_pw {
            Some(value) => value
            None => ""
          }
          let file_encryption_key = if authenticate_user_password_aesv3(
              r == 6,
              make_utf8(user_pw_val),
              u,
            ) {
            file_encryption_key_aesv3_user(
              r == 6,
              make_utf8(user_pw_val),
              u,
              ue_val,
            )
          } else if authenticate_owner_password_aesv3(
              r == 6,
              make_utf8(owner_pw_val),
              u,
              o,
            ) {
            file_encryption_key_aesv3(
              r == 6,
              make_utf8(owner_pw_val),
              o,
              oe_val,
              u,
            )
          } else {
            raise @pdf.PdfError::Msg(
              "Encryption: Could not decrypt single stream: Bad or not supplied AESV3 user or owner password",
            )
          }
          decrypt_stream(
            value => decrypt(
              crypt_type,
              pdf,
              no_encrypt_metadata,
              false,
              obj,
              gen,
              @pdfio.int_array_of_bytes(file_encryption_key),
              keylength,
              r,
              Some(@pdfio.string_of_bytes(file_encryption_key)),
              value,
            ),
            crypt_type,
            pdf,
            no_encrypt_metadata,
            false,
            obj,
            gen,
            @pdfio.int_array_of_bytes(file_encryption_key),
            keylength,
            r,
            Some(@pdfio.string_of_bytes(file_encryption_key)),
            stream,
          )
        }
        _ =>
          match owner_pw {
            Some(owner_string) => {
              let padded_owner = pad_password(
                @pdfio.int_array_of_string(owner_string),
              )
              let key = owner_key(padded_owner, keylength, r)
              let user_pw_string = if r == 2 {
                @pdfio.string_of_bytes(
                  @pdfcryptprimitives.crypt(key, @pdfio.bytes_of_string(o)),
                )
              } else {
                let mut acc = @pdfcryptprimitives.crypt(
                  key,
                  @pdfio.bytes_of_string(o),
                )
                let mut x = 19
                while x >= 0 {
                  acc = @pdfcryptprimitives.crypt(mkkey(key, x), acc)
                  x = x - 1
                }
                @pdfio.string_of_bytes(acc)
              }
              if authenticate_user(
                  no_encrypt_metadata, user_pw_string, r, u, o, p, id, keylength,
                ) {
                let user_key = find_key(
                  no_encrypt_metadata, user_pw_string, r, o, p, id, keylength,
                )
                decrypt_stream(
                  value => decrypt(
                    crypt_type,
                    pdf,
                    no_encrypt_metadata,
                    false,
                    obj,
                    gen,
                    user_key,
                    keylength,
                    r,
                    None,
                    value,
                  ),
                  crypt_type,
                  pdf,
                  no_encrypt_metadata,
                  false,
                  obj,
                  gen,
                  user_key,
                  keylength,
                  r,
                  None,
                  stream,
                )
              } else {
                raise @pdf.PdfError::Msg(
                  "Encryption: Bad or not supplied owner password when decrypting single stream",
                )
              }
            }
            None => {
              let user_pw_string = match user_pw {
                Some(value) => value
                None => ""
              }
              if authenticate_user(
                  no_encrypt_metadata, user_pw_string, r, u, o, p, id, keylength,
                ) {
                let user_key = find_key(
                  no_encrypt_metadata, user_pw_string, r, o, p, id, keylength,
                )
                decrypt_stream(
                  value => decrypt(
                    crypt_type,
                    pdf,
                    no_encrypt_metadata,
                    false,
                    obj,
                    gen,
                    user_key,
                    keylength,
                    r,
                    None,
                    value,
                  ),
                  crypt_type,
                  pdf,
                  no_encrypt_metadata,
                  false,
                  obj,
                  gen,
                  user_key,
                  keylength,
                  r,
                  None,
                  stream,
                )
              } else {
                raise @pdf.PdfError::Msg(
                  "Encryption: Bad or not supplied password when decrypting single stream",
                )
              }
            }
          }
      }
    }
  }
}

///|
/// Is a PDF encrypted?
pub fn is_encrypted(pdf : @pdf.Pdf) -> Bool {
  @pdf.lookup_direct(pdf, "/Encrypt", pdf.trailerdict) is Some(_)
}

///|
fn get_or_add_id(pdf : @pdf.Pdf) -> (String, @pdf.Pdf) raise {
  match @pdf.lookup_direct(pdf, "/ID", pdf.trailerdict) {
    Some(@pdf.PdfObject::Array([@pdf.PdfObject::String(s), _])) => (s, pdf)
    _ => {
      let stamp = @env.now().to_string()
      let id = stamp
      let idobj = @pdf.PdfObject::Array([
        @pdf.PdfObject::String(id),
        @pdf.PdfObject::String(id),
      ])
      pdf.trailerdict = @pdf.add_dict_entry(pdf.trailerdict, "/ID", idobj)
      (id, pdf)
    }
  }
}

///|
fn encrypt_pdf_40bit_inner(
  owner : String,
  user : String,
  p : Int,
  user_pw : String,
  id : String,
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/Standard")),
    ("/V", @pdf.PdfObject::Integer(1)),
    ("/R", @pdf.PdfObject::Integer(2)),
    ("/O", @pdf.PdfObject::String(owner)),
    ("/U", @pdf.PdfObject::String(user)),
    ("/P", @pdf.PdfObject::Integer(p)),
  ])
  match
    process_cryption(
      false,
      true,
      pdf,
      @pdfcryptprimitives.Encryption::ARC4(40, 2),
      user_pw,
      2,
      user,
      owner,
      p,
      id,
      40,
      None,
    ) {
    Some(pdf_val) => {
      let crypt_dict_num = @pdf.addobj(pdf_val, crypt_dict)
      pdf_val.trailerdict = @pdf.add_dict_entry(
        pdf_val.trailerdict,
        "/Encrypt",
        @pdf.PdfObject::Indirect(crypt_dict_num),
      )
      pdf_val
    }
    None => raise @pdf.PdfError::Msg("Encryption 40 failed")
  }
}

///|
/// Encrypt a PDF document using 40-bit encryption.
pub fn encrypt_pdf_40bit(
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let p = p_of_banlist(banlist)
  let owner = mk_owner(2, owner_pw, user_pw, 40)
  let (id, pdf_updated) = get_or_add_id(pdf)
  let user = mk_user(false, user_pw, owner, p, id, 2, 40)
  encrypt_pdf_40bit_inner(owner, user, p, user_pw, id, pdf_updated)
}

///|
fn encrypt_pdf_128bit_inner(
  owner : String,
  user : String,
  p : Int,
  user_pw : String,
  id : String,
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/Standard")),
    ("/V", @pdf.PdfObject::Integer(2)),
    ("/R", @pdf.PdfObject::Integer(3)),
    ("/O", @pdf.PdfObject::String(owner)),
    ("/U", @pdf.PdfObject::String(user)),
    ("/Length", @pdf.PdfObject::Integer(128)),
    ("/P", @pdf.PdfObject::Integer(p)),
  ])
  match
    process_cryption(
      false,
      true,
      pdf,
      @pdfcryptprimitives.Encryption::ARC4(128, 3),
      user_pw,
      3,
      user,
      owner,
      p,
      id,
      128,
      None,
    ) {
    Some(pdf_val) => {
      let crypt_dict_num = @pdf.addobj(pdf_val, crypt_dict)
      pdf_val.trailerdict = @pdf.add_dict_entry(
        pdf_val.trailerdict,
        "/Encrypt",
        @pdf.PdfObject::Indirect(crypt_dict_num),
      )
      pdf_val
    }
    None => raise @pdf.PdfError::Msg("Encryption 128 failed")
  }
}

///|
fn encrypt_pdf_128bit_inner_r4(
  owner : String,
  user : String,
  p : Int,
  user_pw : String,
  id : String,
  pdf : @pdf.Pdf,
  encrypt_metadata : Bool,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/Standard")),
    ("/V", @pdf.PdfObject::Integer(4)),
    (
      "/CF",
      @pdf.PdfObject::Dictionary([
        (
          "/StdCF",
          @pdf.PdfObject::Dictionary([
            ("/Length", @pdf.PdfObject::Integer(16)),
            ("/AuthEvent", @pdf.PdfObject::Name("/DocOpen")),
            ("/CFM", @pdf.PdfObject::Name("/V2")),
          ]),
        ),
      ]),
    ),
    ("/EncryptMetadata", @pdf.PdfObject::Boolean(encrypt_metadata)),
    ("/Length", @pdf.PdfObject::Integer(128)),
    ("/R", @pdf.PdfObject::Integer(4)),
    ("/O", @pdf.PdfObject::String(owner)),
    ("/U", @pdf.PdfObject::String(user)),
    ("/P", @pdf.PdfObject::Integer(p)),
    ("/StrF", @pdf.PdfObject::Name("/StdCF")),
    ("/StmF", @pdf.PdfObject::Name("/StdCF")),
  ])
  match
    process_cryption(
      !encrypt_metadata,
      true,
      pdf,
      @pdfcryptprimitives.Encryption::ARC4(128, 4),
      user_pw,
      4,
      user,
      owner,
      p,
      id,
      128,
      None,
    ) {
    Some(pdf_val) => {
      let crypt_dict_num = @pdf.addobj(pdf_val, crypt_dict)
      pdf_val.trailerdict = @pdf.add_dict_entry(
        pdf_val.trailerdict,
        "/Encrypt",
        @pdf.PdfObject::Indirect(crypt_dict_num),
      )
      pdf_val
    }
    None => raise @pdf.PdfError::Msg("Encryption 128 r4 failed")
  }
}

///|
/// Encrypt a PDF document using 128-bit encryption.
pub fn encrypt_pdf_128bit(
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let p = p_of_banlist(banlist)
  let owner = mk_owner(3, owner_pw, user_pw, 128)
  let (id, pdf_updated) = get_or_add_id(pdf)
  let user = mk_user(false, user_pw, owner, p, id, 3, 128)
  encrypt_pdf_128bit_inner(owner, user, p, user_pw, id, pdf_updated)
}

///|
fn encrypt_pdf_AES_inner(
  owner : String,
  user : String,
  p : Int,
  user_pw : String,
  id : String,
  encrypt_metadata : Bool,
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/Standard")),
    ("/V", @pdf.PdfObject::Integer(4)),
    (
      "/CF",
      @pdf.PdfObject::Dictionary([
        (
          "/StdCF",
          @pdf.PdfObject::Dictionary([
            ("/Length", @pdf.PdfObject::Integer(16)),
            ("/AuthEvent", @pdf.PdfObject::Name("/DocOpen")),
            ("/CFM", @pdf.PdfObject::Name("/AESV2")),
          ]),
        ),
      ]),
    ),
    ("/EncryptMetadata", @pdf.PdfObject::Boolean(encrypt_metadata)),
    ("/Length", @pdf.PdfObject::Integer(128)),
    ("/R", @pdf.PdfObject::Integer(4)),
    ("/O", @pdf.PdfObject::String(owner)),
    ("/U", @pdf.PdfObject::String(user)),
    ("/P", @pdf.PdfObject::Integer(p)),
    ("/StrF", @pdf.PdfObject::Name("/StdCF")),
    ("/StmF", @pdf.PdfObject::Name("/StdCF")),
  ])
  match
    process_cryption(
      !encrypt_metadata,
      true,
      pdf,
      @pdfcryptprimitives.Encryption::AESV2,
      user_pw,
      4,
      user,
      owner,
      p,
      id,
      128,
      None,
    ) {
    Some(pdf_val) => {
      let crypt_dict_num = @pdf.addobj(pdf_val, crypt_dict)
      pdf_val.trailerdict = @pdf.add_dict_entry(
        pdf_val.trailerdict,
        "/Encrypt",
        @pdf.PdfObject::Indirect(crypt_dict_num),
      )
      pdf_val
    }
    None => raise @pdf.PdfError::Msg("Encryption AES failed")
  }
}

///|
/// Encrypt a PDF document using AES V2.
pub fn encrypt_pdf_AES(
  encrypt_metadata : Bool,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let p = p_of_banlist(banlist)
  let owner = mk_owner(4, owner_pw, user_pw, 128)
  let (id, pdf_updated) = get_or_add_id(pdf)
  let user = mk_user(!encrypt_metadata, user_pw, owner, p, id, 4, 128)
  encrypt_pdf_AES_inner(
    owner, user, p, user_pw, id, encrypt_metadata, pdf_updated,
  )
}

///|
fn encrypt_pdf_AES256_inner(
  iso : Bool,
  encrypt_metadata : Bool,
  owner : String,
  user : String,
  p : Int,
  perms : String,
  oe : String,
  ue : String,
  id : String,
  key : String,
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name("/Standard")),
    ("/V", @pdf.PdfObject::Integer(5)),
    (
      "/CF",
      @pdf.PdfObject::Dictionary([
        (
          "/StdCF",
          @pdf.PdfObject::Dictionary([
            ("/Length", @pdf.PdfObject::Integer(32)),
            ("/AuthEvent", @pdf.PdfObject::Name("/DocOpen")),
            ("/CFM", @pdf.PdfObject::Name("/AESV3")),
          ]),
        ),
      ]),
    ),
    ("/EncryptMetadata", @pdf.PdfObject::Boolean(encrypt_metadata)),
    ("/Length", @pdf.PdfObject::Integer(256)),
    ("/R", @pdf.PdfObject::Integer(if iso { 6 } else { 5 })),
    ("/O", @pdf.PdfObject::String(owner)),
    ("/U", @pdf.PdfObject::String(user)),
    ("/P", @pdf.PdfObject::Integer(p)),
    ("/StrF", @pdf.PdfObject::Name("/StdCF")),
    ("/StmF", @pdf.PdfObject::Name("/StdCF")),
    ("/Perms", @pdf.PdfObject::String(perms)),
    ("/OE", @pdf.PdfObject::String(oe)),
    ("/UE", @pdf.PdfObject::String(ue)),
  ])
  match
    process_cryption(
      !encrypt_metadata,
      true,
      pdf,
      @pdfcryptprimitives.Encryption::AESV3(iso),
      "",
      if iso {
        6
      } else {
        5
      },
      user,
      owner,
      p,
      id,
      256,
      Some(key),
    ) {
    Some(pdf_val) => {
      let crypt_dict_num = @pdf.addobj(pdf_val, crypt_dict)
      pdf_val.trailerdict = @pdf.add_dict_entry(
        pdf_val.trailerdict,
        "/Encrypt",
        @pdf.PdfObject::Indirect(crypt_dict_num),
      )
      pdf_val
    }
    None => raise @pdf.PdfError::Msg("256 bit Encryption AES failed")
  }
}

///|
fn encrypt_pdf_AES256_call(
  iso : Bool,
  encrypt_metadata : Bool,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let user_pw_utf8 = make_utf8(user_pw)
  let owner_pw_utf8 = make_utf8(owner_pw)
  let user_validation_salt = mksalt()
  let user_key_salt = mksalt()
  let owner_validation_salt = mksalt()
  let owner_key_salt = mksalt()
  let file_encryption_key = @pdfio.bytes_of_string(mkfilekey())
  let p = p_of_banlist(banlist)
  let (u, ue) = make_ue(
    iso, file_encryption_key, user_pw_utf8, user_validation_salt, user_key_salt,
  )
  let (o, oe, digest) = make_oe(
    iso, file_encryption_key, owner_pw_utf8, owner_validation_salt, owner_key_salt,
    u,
  )
  let (id, pdf_updated) = get_or_add_id(pdf)
  let perms = perms_of_p(
    iso, encrypt_metadata, p, owner_pw_utf8, o, oe, u, digest,
  )
  encrypt_pdf_AES256_inner(
    iso,
    encrypt_metadata,
    o,
    u,
    p,
    @pdfio.string_of_bytes(perms),
    oe,
    ue,
    id,
    @pdfio.string_of_bytes(file_encryption_key),
    pdf_updated,
  )
}

///|
/// Encrypt a PDF document using AESV3 (non-ISO).
pub fn encrypt_pdf_AES256(
  encrypt_metadata : Bool,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  encrypt_pdf_AES256_call(
    false, encrypt_metadata, user_pw, owner_pw, banlist, pdf,
  )
}

///|
/// Encrypt a PDF document using AESV3 (ISO).
pub fn encrypt_pdf_AES256ISO(
  encrypt_metadata : Bool,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  encrypt_pdf_AES256_call(
    true, encrypt_metadata, user_pw, owner_pw, banlist, pdf,
  )
}

///|
fn load_saved_encryption_from_pdf(pdf : @pdf.Pdf) -> @pdf.SavedEncryption raise {
  let (crypt_type, u, o, p, id, ue, oe) = get_encryption_values(pdf)
  let encrypt_dict = match
    @pdf.lookup_direct(pdf, "/Encrypt", pdf.trailerdict) {
    Some(value) => value
    None => raise @pdf.PdfError::Msg("recrypt_pdf: unencrypted pdf")
  }
  let encrypt_metadata = match
    @pdf.lookup_direct(pdf, "/EncryptMetadata", encrypt_dict) {
    Some(@pdf.PdfObject::Boolean(false)) => false
    _ => true
  }
  let perms = match @pdf.lookup_direct(pdf, "/Perms", encrypt_dict) {
    Some(@pdf.PdfObject::String(s)) => s
    _ => ""
  }
  {
    from_get_encryption_values: (crypt_type, u, o, p, id, ue, oe),
    encrypt_metadata,
    perms,
  }
}

///|
fn recrypt_pdf_user(pdf : @pdf.Pdf, pw : String) -> @pdf.Pdf raise {
  let saved = match pdf.saved_encryption {
    Some(value) => value
    None => {
      let saved = load_saved_encryption_from_pdf(pdf)
      pdf.saved_encryption = Some(saved)
      saved
    }
  }
  let (crypt_type, u, o, p, id, ue, oe) = saved.from_get_encryption_values
  let encrypt_metadata = saved.encrypt_metadata
  let perms = saved.perms
  match crypt_type {
    @pdfcryptprimitives.Encryption::AESV3(iso) => {
      let oe_val = match oe {
        Some(val) => val
        None => raise @pdf.PdfError::Msg("recrypt_pdf: bad /oe")
      }
      let ue_val = match ue {
        Some(val) => val
        None => raise @pdf.PdfError::Msg("recrypt_pdf: bad /ue")
      }
      let key = if authenticate_user_password_aesv3(iso, make_utf8(pw), u) {
        file_encryption_key_aesv3_user(iso, make_utf8(pw), u, ue_val)
      } else {
        raise @pdf.PdfError::Msg("recrypt_pdf: failed AESV3 fek.")
      }
      encrypt_pdf_AES256_inner(
        iso,
        encrypt_metadata,
        o,
        u,
        p,
        perms,
        oe_val,
        ue_val,
        id,
        @pdfio.string_of_bytes(key),
        pdf,
      )
    }
    @pdfcryptprimitives.Encryption::AESV2 =>
      encrypt_pdf_AES_inner(o, u, p, pw, id, encrypt_metadata, pdf)
    @pdfcryptprimitives.Encryption::ARC4(40, _) =>
      encrypt_pdf_40bit_inner(o, u, p, pw, id, pdf)
    @pdfcryptprimitives.Encryption::ARC4(128, 4) =>
      encrypt_pdf_128bit_inner_r4(o, u, p, pw, id, pdf, encrypt_metadata)
    @pdfcryptprimitives.Encryption::ARC4(128, _) =>
      encrypt_pdf_128bit_inner(o, u, p, pw, id, pdf)
    _ => raise @pdf.PdfError::Msg("recrypt_pdf: bad encryption")
  }
}

///|
fn recrypt_pdf_owner(pdf : @pdf.Pdf, owner_pw : String) -> @pdf.Pdf raise {
  let saved = match pdf.saved_encryption {
    Some(value) => value
    None => {
      let saved = load_saved_encryption_from_pdf(pdf)
      pdf.saved_encryption = Some(saved)
      saved
    }
  }
  let (crypt_type, u, o, p, id, ue, oe) = saved.from_get_encryption_values
  let encrypt_metadata = saved.encrypt_metadata
  let perms = saved.perms
  let key_and_pw = match
    key_or_user_password_from_owner(
      owner_pw,
      pdf,
      encryption_values=(crypt_type, u, o, oe),
    ) {
    None => raise @pdf.PdfError::Msg("Recrypt with owner password failed.")
    Some(pair) => pair
  }
  let key = key_and_pw.0
  let pw = key_and_pw.1
  match crypt_type {
    @pdfcryptprimitives.Encryption::AESV3(iso) => {
      let oe_val = match oe {
        Some(val) => val
        None => raise @pdf.PdfError::Msg("recrypt_pdf: bad /oe")
      }
      let ue_val = match ue {
        Some(val) => val
        None => raise @pdf.PdfError::Msg("recrypt_pdf: bad /ue")
      }
      encrypt_pdf_AES256_inner(
        iso, encrypt_metadata, o, u, p, perms, oe_val, ue_val, id, key, pdf,
      )
    }
    @pdfcryptprimitives.Encryption::AESV2 =>
      encrypt_pdf_AES_inner(o, u, p, pw, id, encrypt_metadata, pdf)
    @pdfcryptprimitives.Encryption::ARC4(40, _) =>
      encrypt_pdf_40bit_inner(o, u, p, pw, id, pdf)
    @pdfcryptprimitives.Encryption::ARC4(128, 4) =>
      encrypt_pdf_128bit_inner_r4(o, u, p, pw, id, pdf, encrypt_metadata)
    @pdfcryptprimitives.Encryption::ARC4(128, _) =>
      encrypt_pdf_128bit_inner(o, u, p, pw, id, pdf)
    _ => raise @pdf.PdfError::Msg("recrypt_pdf_owner: bad encryption")
  }
}

///|
/// Re-encrypt a PDF document, using the saved encryption metadata.
pub fn recrypt_pdf(
  pdf : @pdf.Pdf,
  pw : String,
  renumber? : Bool = true,
) -> @pdf.Pdf raise {
  let mut pdf = pdf
  if pdf.saved_encryption is None && is_encrypted(pdf) {
    let saved_result : Result[@pdf.SavedEncryption, Error] = try? load_saved_encryption_from_pdf(
      pdf,
    )
    match saved_result {
      Ok(saved) => pdf.saved_encryption = Some(saved)
      Err(_) => ()
    }
    let dec_result : Result[(@pdf.Pdf?, Array[Permission]), Error] = try? decrypt_pdf(
      pw,
      @pdf.deep_copy(pdf),
    )
    match dec_result {
      Ok((Some(pdf_dec), _)) => pdf = pdf_dec
      _ => {
        let owner_result : Result[@pdf.Pdf?, Error] = try? decrypt_pdf_owner(
          pw,
          @pdf.deep_copy(pdf),
        )
        match owner_result {
          Ok(Some(pdf_dec)) => pdf = pdf_dec
          _ => ()
        }
      }
    }
  }
  if renumber {
    let nums = @pdf.objnumbers(pdf)
    let changes : Map[Int, Int] = Map::new(capacity=nums.length())
    let mut i = 1
    for n in nums {
      changes.set(n, i)
      i = i + 1
    }
    pdf = @pdf.renumber(changes, pdf)
  }
  recrypt_pdf_user(pdf, pw) catch {
    _ =>
      recrypt_pdf_owner(pdf, pw) catch {
        _ => raise @pdf.PdfError::Msg("recrypt_pdf failed. Wrong password?")
      }
  }
}
