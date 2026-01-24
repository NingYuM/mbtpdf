# @bobzhang/mbtpdf/font/pdfafmdata

Compressed AFM data for the 14 standard PDF fonts.

## Overview

This package contains FLATE-compressed Adobe Font Metrics (AFM) data for all 14 standard PDF fonts. The data includes character widths and kerning information needed for text layout calculations.

## Functions

Each function returns the compressed AFM data as a byte array. Decompress with FLATE to get the AFM text.

### Times Family

```moonbit nocheck
pub fn times_roman_afm() -> Array[Byte]
pub fn times_bold_afm() -> Array[Byte]
pub fn times_italic_afm() -> Array[Byte]
pub fn times_bold_italic_afm() -> Array[Byte]
```

### Helvetica Family

```moonbit nocheck
pub fn helvetica_afm() -> Array[Byte]
pub fn helvetica_bold_afm() -> Array[Byte]
pub fn helvetica_oblique_afm() -> Array[Byte]
pub fn helvetica_bold_oblique_afm() -> Array[Byte]
```

### Courier Family

```moonbit nocheck
pub fn courier_afm() -> Array[Byte]
pub fn courier_bold_afm() -> Array[Byte]
pub fn courier_oblique_afm() -> Array[Byte]
pub fn courier_bold_oblique_afm() -> Array[Byte]
```

### Symbol Fonts

```moonbit nocheck
pub fn symbol_afm() -> Array[Byte]
pub fn zapf_dingbats_afm() -> Array[Byte]
```

## Data Format

The compressed data contains standard AFM file content including:
- Font header information (FontName, FullName, etc.)
- Character metrics (width by code and name)
- Kerning pairs for typography
