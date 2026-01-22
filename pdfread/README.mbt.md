# pdfread

Read PDF files and construct in-memory `Pdf` documents.

## Overview

The `pdfread` package provides functions to:

- Read PDF files from disk, channels, or memory
- Parse cross-reference tables and object streams
- Handle encrypted documents with password support
- Support lazy loading for large files
- Query document revisions and encryption

## Reading PDFs

### From Input Stream

```mbt
// Read with all stream data loaded
let pdf = @pdfread.pdf_of_input!(
  user_password=None,
  owner_password=None,
  input,
)
```

### Lazy Loading

For large files, use lazy loading to defer stream data:

```mbt
// Streams loaded on-demand
let pdf = @pdfread.pdf_of_input_lazy!(
  user_password=None,
  owner_password=None,
  input,
)
```

### From File (async)

```mbt
let pdf = @pdfread.pdf_of_file(
  user_password=None,
  owner_password=None,
  filename="/path/to/document.pdf",
)
```

### From Channel (async)

```mbt
let pdf = @pdfread.pdf_of_channel(
  user_password=None,
  owner_password=None,
  channel,
)
```

## Password-Protected Documents

For encrypted PDFs:

```mbt
// With user password
let pdf = @pdfread.pdf_of_input!(
  user_password=Some("secret"),
  owner_password=None,
  input,
)

// With owner password
let pdf = @pdfread.pdf_of_input!(
  user_password=None,
  owner_password=Some("admin123"),
  input,
)
```

## Document Revisions

PDF files can have multiple revisions (incremental saves):

```mbt
// Count revisions
let num_revisions = @pdfread.revisions!(input)

// Read specific revision
let pdf = @pdfread.pdf_of_input!(
  revision=2,  // Read second revision
  user_password=None,
  owner_password=None,
  input,
)
```

## Encryption Information

### Query Encryption Method

```mbt
let method = @pdfread.what_encryption(pdf)
match method {
  None => println("Not encrypted")
  Some(AES128) => println("AES 128-bit")
  Some(AES256) => println("AES 256-bit")
  Some(ARC4(40)) => println("RC4 40-bit")
  Some(ARC4(128)) => println("RC4 128-bit")
  _ => ()
}
```

### Query Permissions

```mbt
let perms = @pdfread.permissions(pdf)
for perm in perms {
  match perm {
    Print => println("Printing allowed")
    Copy => println("Copying allowed")
    Edit => println("Editing allowed")
    _ => ()
  }
}
```

## Debug Options

```mbt
// Enable debug output
@pdfread.read_debug.val = true

// Treat all documents as malformed (for testing)
@pdfread.debug_always_treat_malformed.val = true

// Raise errors on malformed documents
@pdfread.error_on_malformed.val = true
```

## Error Handling

Reading raises `@pdf.PdfError` on parse failures:

```mbt
try {
  let pdf = @pdfread.pdf_of_input!(
    user_password=None,
    owner_password=None,
    input,
  )
  // use pdf...
} catch {
  @pdf.PdfError::Msg(msg) => println("Parse error: \{msg}")
}
```

## Internal Structure

The package handles:

- **Cross-reference tables**: Traditional `xref` tables and compressed xref streams
- **Object streams**: Compressed object storage (PDF 1.5+)
- **Linearization**: Optimized web viewing (detected and handled)
- **Encryption**: RC4 and AES decryption with key derivation
