# @bobzhang/mbtpdf/document/pdfannot

PDF annotation reading, writing, and transformation.

## Overview

This package handles PDF annotations, which are interactive elements overlaid on page content. Annotations include links, text notes, highlights, stamps, form fields, and more.

## Types

### Subtype

Annotation types supported by PDF.

```moonbit nocheck
///|
pub(all) enum Subtype {
  Text // Text note (sticky note)
  Link // Hyperlink
  FreeText // Free text annotation
  Line // Line annotation
  Square // Rectangle annotation
  Circle // Ellipse annotation
  Polygon // Polygon annotation
  PolyLine // Polyline annotation
  Highlight // Text highlight
  Underline // Text underline
  Squiggly // Squiggly underline
  StrikeOut // Strikethrough
  Stamp // Rubber stamp
  Caret // Caret (insertion point)
  Ink // Freehand drawing
  Popup(Annotation) // Popup window (attached to parent)
  FileAttachment // Attached file
  Sound // Sound annotation
  Movie // Movie annotation
  Widget // Form field
  Screen // Screen annotation
  PrinterMark // Printer's mark
  TrapNet // Trap network
  Watermark // Watermark annotation
  ThreeDee // 3D annotation
  Unknown(String) // Unknown type
}
```

### Style

Border styles.

```moonbit nocheck
///|
pub(all) enum Style {
  NoStyle
  Solid
  Dashed
  Beveled
  Inset
  UnderlineStyle
}
```

### Border

Annotation border properties.

```moonbit nocheck
///|
pub(all) struct Border {
  width : Double
  vradius : Double
  hradius : Double
  style : Style
  dasharray : Array[Int]
}
```

### Annotation

A complete annotation definition.

```moonbit nocheck
///|
pub(all) struct Annotation {
  subtype : Subtype
  annot_contents : String?
  subject : String?
  rectangle : (Double, Double, Double, Double)
  border : Border
  colour : (Int, Int, Int)?
  annotrest : @pdf.PdfObject
}
```

## Functions

### annotations_of_page

Get all annotations on a page.

```moonbit nocheck
pub fn annotations_of_page(pdf : @pdf.Pdf, page : @pdfpage.Page) -> Array[Annotation] raise
```

### add_annotation

Add an annotation to a page.

```moonbit nocheck
pub fn add_annotation(pdf : @pdf.Pdf, page : @pdfpage.Page, anno : Annotation) -> @pdfpage.Page raise
```

### make

Create a new annotation.

```moonbit nocheck
pub fn make(
  subtype : Subtype,
  content? : String,
  border? : Border,
  rectangle? : (Double, Double, Double, Double),
  colour? : (Int, Int, Int),
  subject? : String
) -> Annotation
```

### make_border

Create a border specification.

```moonbit nocheck
pub fn make_border(
  width : Double,
  vradius? : Double,
  hradius? : Double,
  style? : Style,
  dasharray? : Array[Int]
) -> Border
```

### transform_annotations

Apply a transformation matrix to all annotations in a page.

```moonbit nocheck
pub fn transform_annotations(
  pdf : @pdf.Pdf,
  transform : @pdftransform.TransformMatrix,
  rest : @pdf.PdfObject
) -> Unit raise
```
