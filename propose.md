# Proposed Layered Architecture for mbtpdf

## Goals
- Separate concerns by layer and keep dependencies flowing downward only.
- Make package boundaries reflect data flow: bytes -> syntax -> objects -> content -> document features.
- Reduce coupling by pushing IO and CLI adapters to the top.
- Keep large packages split by responsibility (target <10k lines per package).

## Current Snapshot (from imports and sizes)

### Size hotspots (approx lines, includes tests)
- pdftext ~10.7k
- pdfafmdata ~9.0k (data tables)
- pdfcodec ~4.9k
- pdfpage ~4.3k
- pdfops ~3.0k
- pdfread ~2.5k
- pdfwrite ~1.9k

### Dependency hotspots
- pdfops depends on pdfread and pdfwrite (content ops mixed with IO).
- pdfpage depends on pdfread and pdfwrite (page ops mixed with IO).
- pdfstandard14 depends on pdftext types (font data depends on text layer).
- pdftext depends on pdfpage + pdfops + font data (expected, but becomes a hub).

These are the primary places where layer boundaries are currently blurred.

## Proposed Layered Model

Layer 0: Base utilities
- pdfutil, pdfe
- Concern: data structures, logging, low-level helpers.

Layer 1: IO primitives
- pdfio
- Concern: byte-level Input/Output, buffers, file IO.

Layer 2: Core model + geometry
- pdf, pdftransform, pdfunits, pdfpaper, pdfdate
- Concern: Pdf object graph and pure geometric/unit helpers.

Layer 3: Syntax + lexing
- pdfgenlex, pdfsyntax
- Concern: bytes <-> token/AST for PDF objects (no Pdf document logic).

Layer 4: Codecs + crypto
- pdfflate, pdfcodec, pdfjpeg, pdfcryptprimitives, pdfcrypt
- Concern: stream filters, compression, encryption/decryption.

Layer 5: Fonts + encodings data
- pdfafm, pdfafmdata, pdfglyphlist, pdfcmap, pdfstandard14, new pdffont
- Concern: font metrics, glyph maps, standard font metadata.

Layer 6: Content stream + functions
- pdfops, pdffun, pdfspace
- Concern: parse/emit content streams, function evaluation, color spaces.

Layer 7: Read/Write services
- pdfread, pdfwrite
- Concern: bytes <-> Pdf document; xref and object stream IO.

Layer 8: Document structure
- pdftree, pdfpage, pdfpagelabels, pdfdest, pdfannot, pdfocg, pdfst, pdfmarks
- Concern: page tree and document-level structures.

Layer 9: Features
- pdftext, pdfimage, pdfmerge
- Concern: higher-level behaviors (text extraction, image ops, merge).

Layer 10: CLI
- cmd/*
- Concern: binaries and end-user workflows.

## Proposed Package Adjustments

1) Introduce pdffont types
- Move StandardFont, Encoding, and related shared types out of pdftext into a
  new pdffont package (or pdftext/types split).
- pdfstandard14 depends on pdffont, pdftext depends on pdffont.
- Removes upward dependency from font data to text layer.

2) Split content ops from IO adapters
- Keep pdfops pure: content parsing/printing should depend on pdfsyntax and pdf,
  but not pdfread or pdfwrite.
- Move any functions that read streams via pdfread or write via pdfwrite into a
  new adapter package (example: pdfops_io or pdfcontent_io).

3) Split page operations from IO helpers
- Keep core page tree manipulation in pdfpage.
- Move functions that directly read/write files or call pdfread/pdfwrite into a
  new package (example: pdfpage_io).

4) Enforce downward-only dependencies
- pdfread and pdfwrite should not be imported by mid-layer packages like
  pdfops or pdfpage.
- High-level features (pdftext, pdfmerge, pdfimage) can depend on read/write
  services, but not the other way around.

5) Data-only packages remain isolated
- pdfafmdata and pdfglyphlist should not import higher layers.
- Keep them as pure data or parsing helpers.

## Migration Plan (Incremental)

Phase 1: Create new packages with re-exports
- Add pdffont with type definitions.
- Add pdfops_io and pdfpage_io and re-export legacy functions temporarily.

Phase 2: Update call sites
- Use moon ide find-references to move users to new packages.
- Replace @pdftext.StandardFont with @pdffont.StandardFont across packages.

Phase 3: Reduce public surface
- After call sites are updated, remove re-exports and drop unused pub helpers.

Phase 4: Verify layering
- Add a simple import audit script (jq over moon.pkg.json) to enforce
  no upward dependency.

## Expected Benefits
- Clear separation: parsing vs IO vs content vs features.
- Easier maintenance: smaller packages, fewer dependency surprises.
- Safer refactors: less risk of cycles and cross-layer regressions.

## Risks
- Moving shared types can cause wide ripples in imports and public APIs.
- Some tests may depend on transitive imports; update them explicitly.
- Re-exports can hide layering violations if left too long.

## Suggested Next Steps
- Decide on the pdffont package and exact type list to move.
- Identify IO-bound functions in pdfops/pdfpage and list them for migration.
- Add a small dependency audit to catch new layer violations early.
