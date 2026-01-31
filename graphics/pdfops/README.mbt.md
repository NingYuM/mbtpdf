# pdfops

PDF content stream operators for graphics and text.

## Overview

The `pdfops` package provides:

- The `Op` enum representing all PDF content stream operators
- Parsing PDF content streams into operator sequences
- Serializing operators back to content streams
- Utilities for manipulating / rewriting operator sequences

In PDFs, **content streams** are where page graphics live (paths, text, images,
marked content, etc.). The most common place you’ll see them is the page
dictionary’s `/Contents`, but they can also appear in XObjects (e.g. form
XObjects) and other places that use the same operator language.

## Is It “Standalone”?

`pdfops` is a **package** inside the `@bobzhang/mbtpdf` module (not a separate
MoonBit module), but it *can* be developed and tested largely in isolation:

```sh
moon check graphics/pdfops
moon test graphics/pdfops
```

It depends on lower-level `mbtpdf` packages like `core/pdf` (types), `core/pdfio`
(byte I/O), `codec/pdfcodec` (stream decoding), and `syntax/pdfsyntax` (token
parsing).

## Use Cases

Typical uses of `pdfops`:

- **Inspection / analysis**: parse `/Contents` into typed operators to find
  text draws, images (`Do` / inline images), marked content tags, etc.
- **Rewriting / normalization**: read operators, transform them (e.g. rename
  resource keys, drop images, add watermarks, apply transforms), and write them
  back.
- **Generation**: build new pages or overlays by constructing `Array[Op]` and
  turning it into a stream.

If you’re looking for concrete examples in this repo:

- Generating a PDF from operators: `cmd/pdfhello/main.mbt`
- Parsing and rewriting streams: `cmd/pdfdraft/main.mbt`, `cmd/pdftest/main.mbt`

## Op Enum

The `Op` enum represents PDF graphics operators:

### Graphics State

- `Opq` - Save graphics state
- `OpQ` - Restore graphics state
- `Opcm(TransformMatrix)` - Concatenate matrix
- `Opw(Double)` - Line width
- `OpJ(Int)` - Line cap style
- `Opj(Int)` - Line join style
- `OpM(Double)` - Miter limit
- `Opd(Array[Double], Double)` - Dash pattern
- `Opri(String)` - Rendering intent
- `Opi(Int)` - Flatness
- `Opgs(String)` - Graphics state dictionary

### Path Construction

- `Opm(Double, Double)` - Move to
- `Opl(Double, Double)` - Line to
- `Opc(...)` - Curve (Bezier)
- `Opv(...)` - Curve (v variant)
- `Opy(...)` - Curve (y variant)
- `Oph` - Close path
- `Opre(Double, Double, Double, Double)` - Rectangle

### Path Painting

- `OpS` - Stroke path
- `Ops` - Close and stroke
- `Opf` - Fill (non-zero winding)
- `OpF` - Fill (same as f)
- `OpfStar` - Fill (even-odd rule)
- `OpB` - Fill and stroke (non-zero)
- `OpBStar` - Fill and stroke (even-odd)
- `Opb` - Close, fill and stroke
- `OpbStar` - Close, fill and stroke (even-odd)
- `Opn` - End path (no-op)

### Clipping

- `OpW` - Clip (non-zero winding)
- `OpWStar` - Clip (even-odd)

### Text State

- `OpBT` - Begin text object
- `OpET` - End text object
- `OpTc(Double)` - Character spacing
- `OpTw(Double)` - Word spacing
- `OpTz(Double)` - Horizontal scaling
- `OpTL(Double)` - Leading
- `OpTf(String, Double)` - Font and size
- `OpTr(Int)` - Rendering mode
- `OpTs(Double)` - Text rise

### Text Positioning

- `OpTd(Double, Double)` - Move text position
- `OpTD(Double, Double)` - Move and set leading
- `OpTm(TransformMatrix)` - Set text matrix
- `OpTStar` - Move to next line

### Text Showing

- `OpTj(String)` - Show string
- `OpTJ(PdfObject)` - Show strings with positioning
- `OpSingleQuote(String)` - Move and show
- `OpDoubleQuote(Double, Double, String)` - Set spacing, move and show

### Color

- `OpCS(String)` - Set stroke color space
- `Opcs(String)` - Set fill color space
- `OpSC(Array[Double])` - Set stroke color
- `Opsc(Array[Double])` - Set fill color
- `OpSCN(Array[Double])` - Set stroke color (extended)
- `Opscn(Array[Double])` - Set fill color (extended)
- `OpSCNName(String, Array[Double])` - With pattern name
- `OpscnName(String, Array[Double])` - With pattern name
- `OpG(Double)` - Stroke gray
- `Opg(Double)` - Fill gray
- `OpRG(Double, Double, Double)` - Stroke RGB
- `Oprg(Double, Double, Double)` - Fill RGB
- `OpK(Double, Double, Double, Double)` - Stroke CMYK
- `Opk(Double, Double, Double, Double)` - Fill CMYK

### Shading and XObjects

- `Opsh(String)` - Paint shading
- `OpDo(String)` - Paint XObject
- `InlineImage(...)` - Inline image data

### Marked Content

- `OpMP(String)` - Marked content point
- `OpDP(String, PdfObject)` - Marked content with properties
- `OpBMC(String)` - Begin marked content
- `OpBDC(String, PdfObject)` - Begin with properties
- `OpEMC` - End marked content

### Compatibility

- `OpBX` - Begin compatibility section
- `OpEX` - End compatibility section

### Other

- `OpUnknown(String)` - Unrecognized operator
- `OpComment(String)` - PDF comment

## Parsing Content Streams

### Parse to Operators

In many PDFs, a page’s `/Contents` is an array of streams. Use `parse_operators`
to handle that common case (including decoding compressed streams):

```mbt nocheck
///|
let ops = @pdfops.Op::parse_operators(pdf, page.resources, page.content)
```

If you already have decoded stream bytes, use `parse_stream` / `parse_single_stream`:

```mbt nocheck
///|
let ops = @pdfops.Op::parse_stream(pdf, resources, content_stream)
```

## Serializing Operators

### To String

`string_of_ops` and `to_string` are primarily intended for logging / debugging
and test assertions. For producing a real PDF stream object, prefer
`stream_of_ops`.

```mbt check
///|
test "string_of_op" {
  let op = @pdfops.Op::Opq
  let s = op.to_string()
  inspect(s, content="q")
}
```

```mbt check
///|
test "string_of_ops" {
  let ops = [@pdfops.Op::Opq, Opm(10.0, 20.0), OpQ]
  let s = @pdfops.Op::string_of_ops(ops)
  assert_true(s.contains("q"))
  assert_true(s.contains("Q"))
}
```

### Concatenate Bytes

```mbt nocheck
///|
let bytes = @pdfops.Op::concat_bytess(byte_arrays)
```

### To PDF Stream

```mbt nocheck
///|
let stream_obj = @pdfops.Op::stream_of_ops(ops)
```

## Common Patterns

### Save/Restore Graphics State

```mbt nocheck
let ops = [Opq, /* drawing operations */, OpQ]
```

### Set Color and Draw

```mbt nocheck
///|
let ops = [
  Oprg(1.0, 0.0, 0.0), // Set fill to red
  Opre(100.0, 100.0, 200.0, 150.0), // Rectangle
  Opf,
] // Fill
```

### Text Operations

```mbt nocheck
///|
let ops = [
  OpBT, // Begin text
  OpTf("/F1", 12.0), // Font F1, size 12
  OpTd(100.0, 700.0), // Position
  OpTj("Hello, World!"), // Show text
  OpET, // End text
]
```

## Artifact Markers

Pre-defined operators for marking artifacts:

```mbt nocheck
///|
pub let begin_artifact : Op = OpBMC("/Artifact")

///|
pub let end_artifact : Op = OpEMC
```

## Debug Options

```mbt nocheck
// Enable debug output
@pdfe.read_debug.val = true

// Include comments in output
@pdfops.write_comments.val = true

// Control whitespace
@pdfops.whitespace.val = " "
@pdfops.always_add_whitespace.val = false
```
