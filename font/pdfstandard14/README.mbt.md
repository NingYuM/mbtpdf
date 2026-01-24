# @bobzhang/mbtpdf/font/pdfstandard14

The 14 Standard PDF Fonts (widths, kerns, and metrics).

## Overview

This package provides font metrics for the 14 standard PDF fonts that must be available in all PDF readers. These fonts can be used without embedding, making them ideal for reducing file size.

## Standard 14 Fonts

- **Times**: TimesRoman, TimesBold, TimesItalic, TimesBoldItalic
- **Helvetica**: Helvetica, HelveticaBold, HelveticaOblique, HelveticaBoldOblique
- **Courier**: Courier, CourierBold, CourierOblique, CourierBoldOblique
- **Symbol**: Symbol
- **ZapfDingbats**: ZapfDingbats

## Types

### AfmTables

Font metrics tables from AFM (Adobe Font Metrics) data.

```moonbit nocheck
///|
type AfmTables = (
  Map[String, String], // Header values
  Map[Int, Int], // Character code to width
  Map[(Int, Int), Int], // Kerning pairs (char1, char2) -> adjustment
  Map[String, Int], // Glyph name to width
)
```

## Functions

### textwidth

Calculate the width of a text string in font units (1/1000 of point size).

```moonbit nocheck
pub fn textwidth(
  dokern : Bool,
  encoding : @pdffont.Encoding,
  font : @pdffont.StandardFont,
  s : String
) -> Int raise
```

### baseline_adjustment

Get the baseline adjustment (half cap height) for a font.

```moonbit nocheck
pub fn baseline_adjustment(font : @pdffont.StandardFont) -> Int
```

### stemv_of_standard_font

Get the vertical stem width for a font (used in font descriptors).

```moonbit nocheck
pub fn stemv_of_standard_font(font : @pdffont.StandardFont) -> Int
```

### flags_of_standard_font

Get the font descriptor flags for a font.

```moonbit nocheck
pub fn flags_of_standard_font(font : @pdffont.StandardFont) -> Int
```

### afm_data

Get the full AFM tables for a font.

```moonbit nocheck
pub fn afm_data(font : @pdffont.StandardFont) -> AfmTables raise
```

## Usage

Font metrics are lazy-loaded and cached on first access. Use `textwidth` to calculate string widths for text layout. The result is in font units where 1000 units = 1 point at the given font size.
