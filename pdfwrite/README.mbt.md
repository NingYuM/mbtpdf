# pdfwrite

Write PDF documents to files, channels, or memory buffers.

## Overview

The `pdfwrite` package provides functions to:

- Serialize `Pdf` documents to byte streams
- Write to files, channels, or in-memory buffers
- Optionally encrypt output with passwords
- Generate object streams for compression
- Convert PDF objects to string representation

## Writing PDFs

### To File (Simple)

```mbt nocheck
@pdfwrite.pdf_to_file(pdf, "/path/to/output.pdf")
```

### To File (With Options)

```mbt nocheck
@pdfwrite.pdf_to_file_options(
  preserve_objstm=false,    // Keep existing object streams
  generate_objstm=true,     // Create new object streams
  compress_objstm=true,     // Compress object streams
  encryption=None,          // Optional encryption
  build_new_id=true,        // Generate new /ID entry
  pdf~,
  filename="/path/to/output.pdf",
)
```

### To Channel (async)

```mbt nocheck
@pdfwrite.pdf_to_channel(
  encryption=None,
  build_new_id=true,
  pdf~,
  channel,
)
```

### To Output Stream

```mbt nocheck
let (output, data) = @pdfio.input_output_of_bytes(65536)
@pdfwrite.pdf_to_output!(
  encryption=None,
  build_new_id=true,
  pdf~,
  output~,
)
let bytes = @pdfio.extract_bytes_from_input_output(output, data)
```

## Encryption

### Creating Encryption Settings

```mbt nocheck
///|
let encryption = @pdfwrite.make_encryption(
  @pdfcrypt.EncryptionMethod::AES256,
  user_password="user",
  owner_password="owner",
  permissions=[@pdfcrypt.Permission::Print, @pdfcrypt.Permission::Copy],
)
```

### Writing Encrypted PDF

```mbt nocheck
@pdfwrite.pdf_to_file_options(
  encryption=Some(encryption),
  build_new_id=true,
  pdf~,
  filename="/path/to/encrypted.pdf",
)
```

### Re-encryption

To preserve encryption from the original file:

```mbt nocheck
@pdfwrite.pdf_to_file_options(
  recrypt="/path/to/original.pdf",  // Path for ID preservation
  encryption=None,                   // Uses saved encryption
  build_new_id=false,
  pdf~,
  filename="/path/to/output.pdf",
)
```

## Object Streams

PDF 1.5+ supports object streams for compression:

```mbt nocheck
// Generate compressed object streams
@pdfwrite.pdf_to_file_options(
  generate_objstm=true,   // Create object streams
  compress_objstm=true,   // Compress with deflate
  encryption=None,
  build_new_id=true,
  pdf~,
  filename="/path/to/compressed.pdf",
)

// Preserve existing object streams
@pdfwrite.pdf_to_file_options(
  preserve_objstm=true,
  encryption=None,
  build_new_id=true,
  pdf~,
  filename="/path/to/output.pdf",
)
```

## Object Serialization

### Convert Object to String

```mbt check
///|
test "string_of_pdf serializes objects" {
  let obj = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Page")),
  ])
  let s = @pdfwrite.string_of_pdf(obj)
  assert_true(s.contains("/Type"))
  assert_true(s.contains("/Page"))
}
```

### Including Stream Data

```mbt nocheck
// Includes stream content in output

///|
let s = @pdfwrite.string_of_pdf_including_data(stream_obj)
```

### Hex String Encoding

```mbt check
///|
test "make_hex_pdf_string" {
  let hex = @pdfwrite.make_hex_pdf_string("Hi")
  inspect(hex, content="<4869>")
}
```

## Debug Options

```mbt nocheck
// Enable debug output during writing
@pdfwrite.write_debug.val = true
```

### Debug Whole Document

```mbt nocheck
// Print all objects to debug log
@pdfwrite.debug_whole_pdf(pdf)
```

## Encryption Methods

```mbt nocheck
///|
pub type EncryptionMethod = @pdfcrypt.EncryptionMethod

// Available methods:
// AES256       - AES 256-bit (PDF 2.0, recommended)
// AES128       - AES 128-bit (PDF 1.6+)
// ARC4(Int)    - RC4 with key length (legacy)
```

## Encryption Struct

```mbt nocheck
///|
pub struct Encryption {
  encryption_method : EncryptionMethod
  user_password : String
  owner_password : String
  permissions : Array[@pdfcrypt.Permission]
}
```
