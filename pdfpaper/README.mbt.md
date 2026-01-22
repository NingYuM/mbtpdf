# pdfpaper

Standard paper sizes for PDF documents.

## Overview

The `pdfpaper` package provides predefined paper sizes in standard formats (ISO A-series, US Letter/Legal) with support for portrait and landscape orientations.

## Paper Struct

```mbt nocheck
///|
pub struct Paper {
  unit : @pdfunits.LengthUnit
  width : Double
  height : Double
}
```

## Predefined Sizes

### ISO A-Series

```mbt nocheck
@pdfpaper.a0   // 841 x 1189 mm
@pdfpaper.a1   // 594 x 841 mm
@pdfpaper.a2   // 420 x 594 mm
@pdfpaper.a3   // 297 x 420 mm
@pdfpaper.a4   // 210 x 297 mm (most common)
@pdfpaper.a5   // 148 x 210 mm
@pdfpaper.a6   // 105 x 148 mm
@pdfpaper.a7   // 74 x 105 mm
@pdfpaper.a8   // 52 x 74 mm
@pdfpaper.a9   // 37 x 52 mm
@pdfpaper.a10  // 26 x 37 mm
```

### US Sizes

```mbt nocheck
@pdfpaper.usletter  // 8.5 x 11 inches
@pdfpaper.uslegal   // 8.5 x 14 inches
```

## Orientation

### Landscape

Convert any paper to landscape orientation:

```mbt check
///|
test "landscape swaps dimensions" {
  let portrait = @pdfpaper.a4
  let landscape = @pdfpaper.landscape(portrait)
  // Width and height are swapped
  assert_true(@pdfpaper.width(landscape) > @pdfpaper.height(landscape))
}
```

## Accessors

```mbt check
///|
test "paper accessors" {
  let paper = @pdfpaper.a4
  // Get unit (millimeters for ISO sizes)
  let u = @pdfpaper.unit(paper)
  // Get dimensions
  let w = @pdfpaper.width(paper)
  let h = @pdfpaper.height(paper)
  assert_true(w < h) // Portrait
}
```

## Creating Custom Sizes

```mbt nocheck
///|
let custom = @pdfpaper.make(
  @pdfunits.Inch,
  8.5, // width
  11.0, // height
)
```

## Usage with Pages

```mbt nocheck
// Create blank page with A4 size

///|
let page = @pdfpage.blankpage(@pdfpaper.a4)

// Get rectangle for paper

///|
let rect = @pdfpage.rectangle_of_paper(@pdfpaper.usletter)
```
