# @bobzhang/mbtpdf/document/pdfmarks

PDF bookmarks (document outline) reading and writing.

## Overview

This package handles PDF bookmarks (also known as outlines), which provide a hierarchical table of contents for PDF documents. It supports reading, writing, and transforming bookmarks.

## Types

### Bookmark

A single bookmark entry in the document outline.

```moonbit nocheck
///|
pub(all) struct Bookmark {
  level : Int
  text : String
  target : @pdfdest.Destination
  isopen : Bool
  colour : (Double, Double, Double)
  flags : Int
}
```

- `level`: Nesting level (0 = top level)
- `colour`: RGB color (0.0-1.0)
- `flags`: Style flags (bit 0 = italic, bit 1 = bold)

## Functions

### read_bookmarks

Read all bookmarks from a PDF document.

```moonbit nocheck
pub fn read_bookmarks(pdf : @pdf.Pdf, preserve_actions? : Bool) -> Array[Bookmark] raise
```

- `preserve_actions`: Keep action dictionaries as-is (default: false)

### add_bookmarks

Add bookmarks to a document, replacing any existing bookmarks.

```moonbit nocheck
pub fn add_bookmarks(parsed : Array[Bookmark], pdf : @pdf.Pdf) -> @pdf.Pdf raise
```

### remove_bookmarks

Remove all bookmarks from the document.

```moonbit nocheck
pub fn remove_bookmarks(pdf : @pdf.Pdf) -> @pdf.Pdf raise
```

### transform_bookmark

Apply a transformation matrix to a bookmark's destination coordinates.

```moonbit nocheck
pub fn transform_bookmark(
  pdf : @pdf.Pdf,
  tr : @pdftransform.TransformMatrix,
  mark : Bookmark
) -> Bookmark raise
```

### string_of_bookmark

Pretty-print a bookmark for debugging.

```moonbit nocheck
pub fn string_of_bookmark(mark : Bookmark) -> String
```
