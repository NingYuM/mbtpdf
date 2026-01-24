///|
/// Types of encryption.
pub(all) enum Encryption {
  ARC4(Int, Int)
  AESV2
  AESV3(Bool)
} derive(Debug)

///|
pub struct PdfCryptPrimitives {
  unit : Unit
}

///|
pub fn PdfCryptPrimitives::new() -> PdfCryptPrimitives {
  { unit: () }
}

///|
fn bytes_of_int_arrays(values : Array[Array[Int]]) -> @pdfio.MutableBytes {
  let mut total = 0
  for v in values {
    total = total + v.length()
  }
  let out = @pdfio.mkbytes(total)
  let mut pos = 0
  for v in values {
    let mut i = 0
    while i < v.length() {
      @pdfio.bset(out, pos, v[i])
      pos = pos + 1
      i = i + 1
    }
  }
  out
}

///|
/// Given an object number, generation number, input key and key length in bits,
/// apply Algorithm 3.1 to obtain the hash to be used by the encryption function.
#as_free_fn(find_hash, deprecated="Use `PdfCryptPrimitives::find_hash`")
pub fn PdfCryptPrimitives::find_hash(
  self : PdfCryptPrimitives,
  crypt_type : Encryption,
  obj : Int,
  gen : Int,
  key : Array[Int],
  keylength : Int,
) -> Array[Int] {
  let from_obj = [
    Int::land(obj, 0xff),
    Int::land(obj >> 8, 0xff),
    Int::land(obj >> 16, 0xff),
  ]
  let from_gen = [Int::land(gen, 0xff), Int::land(gen >> 8, 0xff)]
  let extra = match crypt_type {
    AESV2 => [0x73, 0x41, 0x6c, 0x54]
    _ => []
  }
  let digest_input = bytes_of_int_arrays([key, from_obj, from_gen, extra])
  let digest = self.md5(digest_input)
  let out_len = Int::min(16, keylength / 8 + 5)
  let out = Array::make(out_len, 0)
  let mut i = 0
  while i < out_len {
    out[i] = @pdfio.bget(digest, i)
    i = i + 1
  }
  out
}

///|
/// Decrypt or encrypt stream data using the active crypt settings.
#as_free_fn(decrypt_stream_data, deprecated="Use `PdfCryptPrimitives::decrypt_stream_data`")
pub fn PdfCryptPrimitives::decrypt_stream_data(
  self : PdfCryptPrimitives,
  crypt_type : Encryption,
  encrypt : Bool,
  file_encryption_key : String?,
  obj : Int,
  gen : Int,
  key : Array[Int],
  keylength : Int,
  r : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  if r == 5 || r == 6 {
    let key_bytes = match file_encryption_key {
      Some(k) => @pdfio.int_array_of_string(k)
      None => fail("decrypt_stream_data: missing file encryption key")
    }
    match crypt_type {
      AESV2 =>
        if encrypt {
          self.aes_encrypt_data(4, key_bytes, data)
        } else {
          self.aes_decrypt_data(4, key_bytes, data)
        }
      AESV3(_) =>
        if encrypt {
          self.aes_encrypt_data(8, key_bytes, data)
        } else {
          self.aes_decrypt_data(8, key_bytes, data)
        }
      ARC4(_, _) => self.crypt(key_bytes, data)
    }
  } else {
    let hash = self.find_hash(crypt_type, obj, gen, key, keylength)
    match crypt_type {
      AESV2 =>
        if encrypt {
          self.aes_encrypt_data(4, hash, data)
        } else {
          self.aes_decrypt_data(4, hash, data)
        }
      AESV3(_) =>
        if encrypt {
          self.aes_encrypt_data(8, hash, data)
        } else {
          self.aes_decrypt_data(8, hash, data)
        }
      ARC4(_, _) => self.crypt(hash, data)
    }
  }
}
