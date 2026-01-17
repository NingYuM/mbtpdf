# Camlpdf -> MoonBit port plan (Phase 0)

## Scope and constraints
- Feature parity with the camlpdf sources under `camlpdf/`.
- Native target only.
- Prefer pure MoonBit implementations for compression and crypto.
- API parity is not required, but naming should stay close to camlpdf where practical.

## Package layout (1:1 with camlpdf modules)

This layout keeps each OCaml module as its own MoonBit package. It minimizes
cross-module renaming pressure and keeps dependencies clear.

| MoonBit package | camlpdf module(s) | Notes |
| --- | --- | --- |
| `pdf` | `pdf` | Core object model, document type, object map, lookup helpers |
| `pdfutil` | `pdfutil` | List/string helpers used across the codebase |
| `pdfio` | `pdfio` | Input/output abstractions, byte helpers |
| `pdfcodec` | `pdfcodec` | Stream decode/encode dispatch |
| `pdfflate` | `pdfflate` | Flate (zlib/deflate) codec, pure implementation |
| `pdfgenlex` | `pdfgenlex` | PDF lexical scanner |
| `pdfread` | `pdfread` | Parser, xref, object streams |
| `pdfe` | `pdfe` | Error logging hook |
| `pdfwrite` | `pdfwrite` | Serialization and xref writing |
| `pdftree` | `pdftree` | Page tree operations |
| `pdfpage` | `pdfpage` | Page manipulation helpers |
| `pdfpagelabels` | `pdfpagelabels` | Page labels |
| `pdfdest` | `pdfdest` | Destinations |
| `pdfpaper` | `pdfpaper` | Paper sizes |
| `pdfunits` | `pdfunits` | Unit conversions |
| `pdfops` | `pdfops` | Content stream operators |
| `pdfspace` | `pdfspace` | Color spaces |
| `pdftransform` | `pdftransform` | Matrices and transforms |
| `pdftext` | `pdftext` | Text extraction/layout helpers |
| `pdffun` | `pdffun` | PDF function objects |
| `pdfafm` | `pdfafm` | AFM parsing |
| `pdfafmdata` | `pdfafmdata` | Built-in AFM data tables |
| `pdfglyphlist` | `pdfglyphlist` | Glyph name to Unicode mapping |
| `pdfcmap` | `pdfcmap` | CMap parsing |
| `pdfstandard14` | `pdfstandard14` | Standard 14 fonts |
| `pdfimage` | `pdfimage` | Image XObjects |
| `pdfjpeg` | `pdfjpeg` | JPEG support |
| `pdfannot` | `pdfannot` | Annotations |
| `pdfmarks` | `pdfmarks` | Bookmarks/marks |
| `pdfocg` | `pdfocg` | Optional content groups |
| `pdfmerge` | `pdfmerge` | Merge/split helpers |
| `pdfst` | `pdfst` | Structure tree |
| `pdfcryptprimitives` | `pdfcryptprimitives` | AES/SHA2/etc primitives |
| `pdfcrypt` | `pdfcrypt` | Encryption/decryption |
| `pdfdate` | `pdfdate` | PDF date parsing/formatting |

## Dependency notes (high level)
- Almost everything depends on `pdfutil`, many depend on `pdfio`.
- `pdfread` depends on `pdfgenlex` and codec packages.
- `pdfwrite` depends on core + io + util + codec.
- `pdfcrypt` depends on `pdfcryptprimitives` plus core/io/util.
- Font/text packages are mostly independent once core object access is in place.

## Naming and compatibility notes

MoonBit types must be UpperCamel. The plan is to keep package names close to
OCaml module names, and apply light renaming for types.

Examples (proposed):
- `Pdf.t` -> `@pdf.Pdf`
- `pdfobject` -> `@pdf.PdfObject`
- `stream` -> `@pdf.Stream`
- `PDFError` -> `suberror PdfError String`
- `Pdfio.input` -> `@pdfio.Input`
- `Pdfio.bytes` -> `@pdfio.Bytes`

Function names should stay close to camlpdf where possible, using MoonBit
snake_case. Optional arguments map to labeled optional parameters.

## Data-only modules

`pdfafmdata`, `pdfglyphlist`, and `pdfstandard14` embed large tables. These
should be generated or stored as dedicated MoonBit data files to keep the main
logic readable and to avoid huge diffs during refactors.

## Open questions (Phase 0)
- How much of `pdfutil` should be exposed publicly vs kept internal helpers?
- Do we want a small "compat" package that re-exports common names for easier
  cross-language porting?
- Should we preserve lazy stream fetching (`Got`/`ToGet`) as-is, or normalize
  into an explicit stream handle abstraction in `pdfio`?
