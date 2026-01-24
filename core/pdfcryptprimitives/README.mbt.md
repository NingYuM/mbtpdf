# @bobzhang/mbtpdf/core/pdfcryptprimitives

Cryptographic primitives for PDF encryption and decryption.

## Overview

This package provides cryptographic algorithms required for PDF document encryption and decryption, including symmetric ciphers (ARC4, AES), hash functions (MD5, SHA-2 family), and key derivation routines used by the PDF security handler.

## Types

### Encryption

Represents the encryption algorithm types supported by PDF:

```moonbit nocheck
///|
pub(all) enum Encryption {
  ARC4(Int, Int) // ARC4 with key length parameters
  AESV2 // AES-128 CBC (PDF 1.5+)
  AESV3(Bool) // AES-256 (PDF 2.0), Bool indicates enhanced key derivation
}
```

## Functions

### crypt

ARC4 stream cipher encryption/decryption. The same function performs both operations since ARC4 is symmetric.

```moonbit nocheck
pub fn crypt(key : Array[Int], data : @pdfio.MutableBytes) -> @pdfio.MutableBytes
```

### md5

MD5 message digest, returning 16 raw bytes.

```moonbit nocheck
pub fn md5(data : @pdfio.MutableBytes) -> @pdfio.MutableBytes
```

### sha256

SHA-256 digest of input data.

```moonbit nocheck
pub fn sha256(input : @pdfio.Input) -> String raise
```

### sha384

SHA-384 digest of input data.

```moonbit nocheck
pub fn sha384(input : @pdfio.Input) -> String raise
```

### sha512

SHA-512 digest of input data.

```moonbit nocheck
pub fn sha512(input : @pdfio.Input) -> String raise
```

### aes_encrypt_data

AES encryption in CBC mode. Returns IV concatenated with ciphertext.

```moonbit nocheck
pub fn aes_encrypt_data(
  nk : Int,
  key : Array[Int],
  data : @pdfio.MutableBytes,
  firstblock? : Array[Int]
) -> @pdfio.MutableBytes
```

- `nk`: Key length (4 for AES-128, 8 for AES-256)
- `firstblock`: Optional IV (random if not provided)

### aes_decrypt_data

AES decryption in CBC mode. Expects IV as first 16 bytes of input.

```moonbit nocheck
pub fn aes_decrypt_data(
  nk : Int,
  key : Array[Int],
  data : @pdfio.MutableBytes,
  remove_padding? : Bool
) -> @pdfio.MutableBytes
```

- `nk`: Key length (4 for AES-128, 8 for AES-256)
- `data`: IV + ciphertext
- `remove_padding`: Remove PKCS7 padding (default: true)

### aes_encrypt_data_ecb / aes_decrypt_data_ecb

AES encryption/decryption in ECB mode (used for specific PDF operations).

### find_hash

Apply PDF Algorithm 3.1 to derive the per-object encryption key.

```moonbit nocheck
pub fn find_hash(
  crypt_type : Encryption,
  obj : Int,
  gen : Int,
  key : Array[Int],
  keylength : Int
) -> Array[Int]
```

### decrypt_stream_data

Decrypt or encrypt stream data using the appropriate algorithm based on encryption settings.

```moonbit nocheck
pub fn decrypt_stream_data(
  crypt_type : Encryption,
  encrypt : Bool,
  file_encryption_key : String?,
  obj : Int,
  gen : Int,
  key : Array[Int],
  keylength : Int,
  r : Int,
  data : @pdfio.MutableBytes
) -> @pdfio.MutableBytes raise
```

- `encrypt`: true for encryption, false for decryption
- `r`: Security handler revision

## PDF Encryption Support

This package supports PDF encryption standards:
- **40-bit RC4** (PDF 1.1): `ARC4(40, ...)`
- **128-bit RC4** (PDF 1.4): `ARC4(128, ...)`
- **128-bit AES** (PDF 1.5): `AESV2`
- **256-bit AES** (PDF 1.7 Extension 3 / PDF 2.0): `AESV3`
