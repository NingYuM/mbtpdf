# pdfpage

Page manipulation for PDF documents.

## Overview

The `pdfpage` package provides operations for:

- Reading page trees and extracting pages
- Creating new pages and page trees
- Manipulating page content operators
- Combining and transforming pages
- Resource management and prefix handling

## Core Types

### Page

Represents a single PDF page:

```mbt nocheck
///|
pub(all) struct Page {
  content : @pdf.PdfObject // Page content stream
  mediabox : @pdf.PdfObject // Page dimensions
  resources : @pdf.PdfObject // Font, color, etc. resources
  rotate : Rotation // Page rotation
  rest : @pdf.PdfObject // Other page attributes
}
```

### Rotation

```mbt nocheck
///|
pub(all) enum Rotation {
  Rotate0
  Rotate90
  Rotate180
  Rotate270
}
```

## Reading Pages

### Extract All Pages

```mbt nocheck
let pages = @pdfpage.pages_of_pagetree!(pdf)
for i, page in pages {
  println("Page \{i + 1}: \{page.mediabox}")
}
```

### Count Pages (Fast)

```mbt nocheck
// Fast count without parsing all pages

///|
let count = @pdfpage.pages_of_pagetree_quick(pdf)
```

### Last Page Number

```mbt nocheck
///|
let lastpage = @pdfpage.endpage(pdf)
// Or the faster variant

///|
let lastpage = @pdfpage.endpage_fast(pdf)
```

## Creating Pages

### Blank Page

```mbt nocheck
// Create blank A4 page

///|
let page = @pdfpage.blankpage(@pdfpaper.Paper::A4Portrait)
```

### Custom Page

```mbt nocheck
// Create page with custom dimensions

///|
let rect = @pdf.PdfObject::Array([
  @pdf.PdfObject::Real(0.0),
  @pdf.PdfObject::Real(0.0),
  @pdf.PdfObject::Real(612.0),
  @pdf.PdfObject::Real(792.0),
])

///|
let page = @pdfpage.custompage(rect)
```

### Minimum Valid PDF

```mbt nocheck
// Create minimal valid PDF document

///|
let pdf = @pdfpage.minimum_valid_pdf()
```

## Building Page Trees

### Add Pages to PDF

```mbt nocheck
let (pdf, pageroot) = @pdfpage.add_pagetree!(pages, pdf)
let pdf = @pdfpage.add_root!(pageroot, [], pdf)
```

### Extract Pages by Range

```mbt nocheck
// Extract pages 1-5 from document

///|
let range = [1, 2, 3, 4, 5]

///|
let new_pdf = @pdfpage.pdf_of_pages(basepdf, range)

// With structure tree processing

///|
let new_pdf = @pdfpage.pdf_of_pages(
  basepdf,
  range,
  retain_numbering=true,
  process_struct_tree=true,
)
```

## Content Manipulation

### Prepend Operators

```mbt nocheck
// Add operators before page content

///|
let modified_page = @pdfpage.prepend_operators(pdf, ops, page)
```

### Append Operators

```mbt nocheck
// Add operators after page content

///|
let modified_page = @pdfpage.postpend_operators(pdf, ops, page)
```

### Protect Content

Wrap operators in save/restore:

```mbt nocheck
///|
let protected_ops = @pdfpage.protect(ops)
// Results in: q ... Q
```

## Page Tree Manipulation

### Change Pages

Replace pages in a document:

```mbt nocheck
///|
let new_pdf = @pdfpage.change_pages(
  true, // Change references
   basepdf, new_pages,
)
```

### Renumber Resources

Avoid name collisions when combining pages:

```mbt nocheck
///|
let renumbered = @pdfpage.renumber_pages(pdf, pages)
```

## Resource Handling

### Add Prefix

Add prefix to all resource names to avoid collisions:

```mbt nocheck
@pdfpage.add_prefix!(pdf, "P1_")
```

### Shortest Unused Prefix

Find shortest available prefix:

```mbt nocheck
///|
let prefix = @pdfpage.shortest_unused_prefix(pdf)
```

### Combine Resources

```mbt nocheck
///|
let combined = @pdfpage.combine_pdf_resources(pdf, resources_a, resources_b)
```

## XObject Processing

### Process XObjects

Apply function to all XObjects on a page:

```mbt nocheck
@pdfpage.process_xobjects!(pdf, page, fn(pdf, resources, ops) {
  // Transform content
  ops
})
```

## Fixups

### Fix Duplicate Pages

```mbt nocheck
@pdfpage.fixup_duplicate_pages!(pdf)
```

### Fix Parent References

```mbt nocheck
@pdfpage.fixup_parents!(pdf)
```

### Fix Duplicate Annotations

```mbt nocheck
@pdfpage.fixup_duplicate_annots!(pdf)
```

### Fix Destinations

```mbt nocheck
@pdfpage.fixup_destinations!(pdf)
```

## Navigation

### Page Number from Destination

```mbt nocheck
///|
let pagenum = @pdfpage.pagenumber_of_target(pdf, destination)
```

### Destination from Page Number

```mbt nocheck
///|
let dest = @pdfpage.target_of_pagenumber(pdf, 1)
```

### Page Object Number

```mbt nocheck
///|
let objnum = @pdfpage.page_object_number(pdf, 1)
```

## Rotation Utilities

```mbt check
///|
test "rotation conversions" {
  inspect(@pdfpage.int_of_rotation(@pdfpage.Rotation::Rotate90), content="90")
  guard @pdfpage.rotation_of_int(180) is Rotate180 else {
    fail("expected Rotate180")
  }
}
```
