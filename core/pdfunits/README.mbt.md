# @bobzhang/mbtpdf/core/pdfunits

Unit conversions for PDF measurements.

## Overview

This package provides utilities for converting between common length units used in PDF documents. PDF uses points as its native unit (72 points = 1 inch).

## Types

### LengthUnit

Supported length units:

```moonbit nocheck
///|
pub(all) enum LengthUnit {
  PdfPoint // 1/72 inch (PDF native unit)
  Inch // 1 inch = 72 points
  Centimetre // 1 cm = 28.3465 points
  Millimetre // 1 mm = 2.83465 points
}
```

## Functions

### points

Convert a measurement to PDF points.

```moonbit check
///|
test "points: convert to PDF points" {
  // 1 inch = 72 points
  inspect(@pdfunits.points(1.0, Inch), content="72")
  // 2.54 cm ≈ 72 points (1 inch)
  inspect(@pdfunits.points(2.54, Centimetre).to_int(), content="72")
  // 25.4 mm ≈ 72 points (1 inch)
  inspect(@pdfunits.points(25.4, Millimetre).to_int(), content="72")
}
```

### inches

Convert a measurement to inches.

```moonbit check
///|
test "inches: convert to inches" {
  // 72 points = 1 inch
  inspect(@pdfunits.inches(72.0, PdfPoint), content="1")
  // 2.54 cm = 1 inch
  inspect(@pdfunits.inches(2.54, Centimetre), content="1")
  // 25.4 mm = 1 inch
  inspect(@pdfunits.inches(25.4, Millimetre), content="1")
}
```

### centimetres

Convert a measurement to centimetres.

```moonbit check
///|
test "centimetres: convert to cm" {
  // 1 inch = 2.54 cm
  inspect(@pdfunits.centimetres(1.0, Inch), content="2.54")
  // 10 mm = 1 cm
  inspect(@pdfunits.centimetres(10.0, Millimetre), content="1")
}
```

### millimetres

Convert a measurement to millimetres.

```moonbit check
///|
test "millimetres: convert to mm" {
  // 1 cm = 10 mm
  inspect(@pdfunits.millimetres(1.0, Centimetre), content="10")
  // 1 inch = 25.4 mm
  inspect(@pdfunits.millimetres(1.0, Inch), content="25.4")
}
```

## Unit Relationships

The fundamental relationships are:
- 1 inch = 72 PDF points
- 1 inch = 2.54 centimetres
- 1 centimetre = 10 millimetres

```moonbit check
///|
test "unit relationships" {
  // Roundtrip: inches -> points -> inches
  let original = 2.5
  let in_points = @pdfunits.points(original, Inch)
  let back = @pdfunits.inches(in_points, PdfPoint)
  inspect(back, content="2.5")
}
```
