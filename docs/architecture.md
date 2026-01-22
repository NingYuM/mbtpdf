# Architecture Overview

This module implements a PDF toolchain in MoonBit, centered on an in-memory
PDF object model with packages for parsing, writing, content manipulation, and
document-level features (merge, text extraction, encryption, etc.).

## High-level Flow

```
Input bytes (pdfio)
  -> pdfread (xref + object streams + encryption)
    -> pdfsyntax/pdfgenlex (lex/parse)
      -> Pdf object graph (pdf)
        -> operations (pdfpage/pdfops/pdftext/pdfimage/...)
          -> pdfwrite (serialize + xref + filters + encryption)
            -> Output bytes (pdfio)
```

## Package Dependency Map (High Level)

```
cmd/*
  |-> pdfread -----> pdfsyntax/pdfgenlex
  |-> pdfwrite ----> pdfcodec/pdfflate (+ pdfcrypt)
  |-> pdfmerge/pdfpage/pdfops/pdftext/pdfimage/...
        |-> pdf (core object graph)
        |-> pdftransform/pdfspace/pdfunits/pdfpaper
        |-> pdfstandard14/pdfafm/pdfafmdata/pdfglyphlist/pdfcmap (via pdftext)

Base utilities used across most packages:
  pdfio + pdfutil + pdfe + pdfcryptprimitives
```

## Core Layer

- `pdf`: central data model (`Pdf`, `PdfObject`, streams, object map).
  - Supports lazy streams via `Stream::ToGet`, materialized via `Stream::Got`.
- `pdfio`: byte-level Input/Output abstractions used across the stack.
- `pdfutil`: shared helpers (hash tables, memoization, logging helpers).
- `pdfe`: logging hook for error/debug output.
  - Example:
    ```mbt
    let pdf = @pdf.empty()
    let objnum = @pdf.addobj(pdf, @pdf.PdfObject::Integer(42))
    let _ = @pdf.lookup_obj(pdf, objnum)
    ```

## Parsing and Reading

- `pdfgenlex`: token stream definition and token helpers.
- `pdfsyntax`: lexer/parser from bytes to `PdfObject`.
- `pdfread`: orchestrates header/xref parsing, object streams, encryption,
  and lazy loading; entry point for `pdf_of_file`, `pdf_of_input`, etc.
- `pdfcodec` + `pdfflate` + `pdfjpeg`: stream filter decoding and compression.
- `pdfcrypt` + `pdfcryptprimitives`: decryption and encryption primitives.
  - Example:
    ```mbt
    async fn load() -> @pdf.Pdf {
      let pdf = @pdfread.pdf_of_file(None, None, "input.pdf")
      let _ = @pdfread.what_encryption(pdf)
      pdf
    }
    ```

## Writing and Serialization

- `pdfwrite`: serializes `Pdf` to bytes, builds xref tables/streams, optional
  object stream generation, and encryption.
- `pdfcodec`/`pdfflate`: stream encoding for compressed output.
- `pdfcrypt`: encryption settings for output.
  - Example:
    ```mbt
    async fn save(pdf : @pdf.Pdf) -> Unit {
      @pdfwrite.pdf_to_file(pdf, "output.pdf")
    }
    ```

## Document Structure and Content

- `pdfpage` + `pdftree`: page tree construction/reading and page operations.
- `pdfops`: parse and emit content stream operators.
- `pdftext`: text extraction and text operators; uses `pdfops` and font data.
- `pdfimage`: image XObject extraction/decoding.
- `pdfdest`, `pdfannot`, `pdfmarks`, `pdfocg`, `pdfpagelabels`, `pdfst`:
  destinations, annotations, bookmarks, optional content, page labels,
  and structure tree support.
- `pdfmerge`: merges documents and reconciles cross-document structures.
  - Example:
    ```mbt
    let pages = @pdfpage.pages_of_pagetree(pdf)
    let text = @pdftext.extract_text(pdf)
    let _ = pages.length()
    ```

## Fonts, Encodings, and Layout Data

- `pdfstandard14`, `pdfafm`, `pdfafmdata`: built-in font metrics and AFM parsing.
- `pdfglyphlist`: glyph name to Unicode mapping.
- `pdfcmap`: CMap parsing for composite fonts.
  - Example:
    ```mbt
    let width = @pdfstandard14.textwidth(
      true,
      @pdftext.Encoding::WinAnsiEncoding,
      @pdftext.StandardFont::Helvetica,
      "Hello",
    )
    ```

## Geometry, Units, and Utilities

- `pdftransform`: affine transformation matrices.
- `pdfspace`: color space utilities.
- `pdfunits` + `pdfpaper`: unit conversion and standard paper sizes.
- `pdfdate`: PDF date parsing/formatting helpers.
  - Example:
    ```mbt
    let paper = @pdfpaper.a4
    let rect = @pdfpage.rectangle_of_paper(paper)
    ```

## Entry Points and Tests

- `cmd/*`: CLI examples (text extraction, merge, encrypt, etc.).
- `e2e/*` and per-package `_test.mbt` files: end-to-end and unit tests.
  See `docs/e2e-tests.md` for roundtrip coverage details.
