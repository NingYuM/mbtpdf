# @bobzhang/mbtpdf/text/pdftext

Text extraction and encoding conversions for PDF documents.

## Overview

This package handles text extraction from PDF content streams and conversion between various text encodings used in PDF (UTF-16BE, PDFDocEncoding, UTF-8). It works with font encodings and ToUnicode CMaps to properly decode text.

## Types

### TextExtractor

A text extraction context tied to a specific font.

```moonbit nocheck
///|
pub struct TextExtractor {
  convert : (Int) -> (String, Array[Int])
  tounicode : Map[String, String]?
  tounicode_lengths : Array[Int]
  font : @pdffont.Font
}
```

## Functions

### Text Extraction

#### text_extractor_of_font

Create a text extractor from a font dictionary.

```moonbit nocheck
pub fn text_extractor_of_font(pdf : @pdf.Pdf, fontdict : @pdf.PdfObject) -> TextExtractor raise
```

#### codepoints_of_text

Extract Unicode codepoints from PDF text string using a font's encoding.

```moonbit nocheck
pub fn codepoints_of_text(extractor : TextExtractor, text : String) -> Array[Int] raise
```

#### glyphnames_of_text

Extract glyph names from PDF text string.

```moonbit nocheck
pub fn glyphnames_of_text(extractor : TextExtractor, text : String) -> Array[String] raise
```

### Encoding Conversions

#### utf8_of_pdfdocstring

Convert a PDF string (UTF-16BE or PDFDocEncoding) to UTF-8.

```moonbit nocheck
pub fn utf8_of_pdfdocstring(s : String) -> String raise
```

#### pdfdocstring_of_utf8

Convert UTF-8 to a PDF string (PDFDocEncoding if possible, otherwise UTF-16BE).

```moonbit nocheck
pub fn pdfdocstring_of_utf8(s : String) -> String raise
```

#### codepoints_of_utf16be / utf16be_of_codepoints

Convert between UTF-16BE bytes and Unicode codepoints.

```moonbit nocheck
pub fn codepoints_of_utf16be(str : String) -> Array[Int] raise
pub fn utf16be_of_codepoints(codepoints : Array[Int]) -> String raise
```

#### codepoints_of_utf8 / utf8_of_codepoints

Convert between UTF-8 strings and Unicode codepoints.

```moonbit nocheck
pub fn codepoints_of_utf8(s : String) -> Array[Int] raise
pub fn utf8_of_codepoints(codepoints : Array[Int]) -> String raise
```

### Utility Functions

#### is_unicode

Check if a string starts with UTF-16BE BOM (0xFE 0xFF).

```moonbit nocheck
pub fn is_unicode(s : String) -> Bool
```

#### simplify_utf16be

Convert UTF-16BE to PDFDocEncoding if possible.

```moonbit nocheck
pub fn simplify_utf16be(s : String) -> String raise
```

## PDF String Encodings

PDF uses two string encodings:
- **PDFDocEncoding**: Single-byte encoding similar to Latin-1
- **UTF-16BE**: Prefixed with BOM (0xFE 0xFF), supports full Unicode

The functions in this package handle both transparently.
