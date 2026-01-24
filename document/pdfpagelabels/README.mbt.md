# @bobzhang/mbtpdf/document/pdfpagelabels

Page label handling for PDF documents.

## Overview

This package handles PDF page labels, which define how page numbers are displayed. Page labels support different numbering styles (arabic, roman, letters) and can include prefixes.

## Types

### LabelStyle

Page numbering styles.

```moonbit nocheck
///|
pub(all) enum LabelStyle {
  DecimalArabic // 1, 2, 3, ...
  UppercaseRoman // I, II, III, ...
  LowercaseRoman // i, ii, iii, ...
  UppercaseLetters // A, B, C, ...
  LowercaseLetters // a, b, c, ...
  NoLabelPrefixOnly // Prefix only, no number
}
```

### PageLabel

A page label definition.

```moonbit nocheck
///|
pub(all) struct PageLabel {
  labelstyle : LabelStyle
  labelprefix : String?
  startpage : Int
  startvalue : Int
}
```

- `labelprefix`: Optional prefix (e.g., "Chapter ")
- `startpage`: First page this label applies to
- `startvalue`: Starting number value

## Variables

### basic_label

Default page label starting at page 1 with decimal arabic numbering.

```moonbit nocheck
pub let basic_label : PageLabel
```

## Functions

### read

Read page labels from a document.

```moonbit nocheck
pub fn read(pdf : @pdf.Pdf) -> Array[PageLabel] raise
```

### write

Write page labels to a document, replacing any existing labels.

```moonbit nocheck
pub fn write(pdf : @pdf.Pdf, labels : Array[PageLabel]) -> Unit raise
```

### remove

Remove all page labels from a document.

```moonbit nocheck
pub fn remove(pdf : @pdf.Pdf) -> Unit raise
```

### complete

Ensure the label array covers all pages (adds a default label at page 1 if needed).

```moonbit nocheck
pub fn complete(labels : Array[PageLabel]) -> Array[PageLabel]
```

### coalesce

Optimize page labels by removing redundant entries.

```moonbit nocheck
pub fn coalesce(labels : Array[PageLabel]) -> Array[PageLabel]
```

### pagelabeltext_of_pagenumber

Get the display text for a specific page number.

```moonbit nocheck
pub fn pagelabeltext_of_pagenumber(n : Int, labels : Array[PageLabel]) -> String raise
```

### pagelabel_of_pagenumber

Get the page label definition for a specific page.

```moonbit nocheck
pub fn pagelabel_of_pagenumber(n : Int, labels : Array[PageLabel]) -> PageLabel raise
```

### add_label

Add a label range, properly handling overlaps with existing labels.

```moonbit nocheck
pub fn add_label(
  endpage : Int,
  labels : Array[PageLabel],
  label : PageLabel,
  range_end : Int
) -> Array[PageLabel]
```

### merge_pagelabels

Merge page labels when combining multiple PDFs.

```moonbit nocheck
pub fn merge_pagelabels(
  pdfs : Array[@pdf.Pdf],
  ranges : Array[Array[Int]]
) -> Array[PageLabel] raise
```

### LabelStyle::to_string / PageLabel::to_string

Debug string representations.
