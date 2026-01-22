# pdfcodec

Stream encoding and decoding for PDF compression.

## Overview

The `pdfcodec` package provides:

- Flate (zlib) compression/decompression
- ASCII85 encoding/decoding
- Run-length encoding
- Predictor filters for images
- Stream decoding pipelines

## Encoding Types

```mbt
pub(all) enum Encoding {
  ASCIIHex
  ASCII85
  RunLength
  Flate
  LZW
}
```

## Predictor Filters

Used with Flate and LZW for improved image compression:

```mbt
pub enum Predictor {
  None
  TIFF2
  PNGNone
  PNGSub
  PNGUp
  PNGAverage
  PNGPaeth
  PNGOptimum
}
```

## Flate Compression

### Encode

```mbt
let compressed = @pdfcodec.encode_flate(data)
```

### Decode

```mbt
let decompressed = @pdfcodec.decode_flate!(input)
```

### Compression Level

```mbt
// Set flate compression level (0-9, default 6)
@pdfcodec.flate_level.val = 9  // Maximum compression
```

## ASCII85 Encoding

### Encode

```mbt
let encoded = @pdfcodec.encode_ascii85(data)
```

### Decode

```mbt
let decoded = @pdfcodec.decode_ascii85!(input)
```

## Stream Decoding

Decode stream data based on its /Filter entry:

```mbt
let decoded = @pdfcodec.decode_pdfstream_until_unknown!(pdf, stream)
```

## Error Handling

```mbt
pub suberror CodecError {
  BadLength
  Unknown(String)
}
```

## Debug Options

```mbt
// Enable debug output
@pdfcodec.debug.val = true
```
