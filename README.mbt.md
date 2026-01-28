# bobzhang/mbtpdf

PDF toolchain implemented in [MoonBit](https://docs.moonbitlang.com), centered on an in-memory PDF object model plus packages for parsing, writing, and document-level operations (merge, text extraction, encryption, etc.).

## Packages

- Libraries live under `core/`, `syntax/`, `codec/`, `crypto/`, `font/`, `graphics/`, `document/`, `text/`, `io/`.
- CLI entry points live under `cmd/` (e.g. `cmd/pdfhello`, `cmd/pdfextracttext`, `cmd/pdfmergeexample`).

## Documentation

- `docs/architecture.md`
- `docs/e2e-tests.md`
- `docs/pdf-format-tutorial.md`

## Quick start

```mbt nocheck
// Run the "hello world" PDF generator.
// moon run cmd/pdfhello
```

## Testing

```mbt nocheck
// moon test
// moon check
// moon coverage analyze
```

## Logging hygiene (tests)

Many packages emit *expected* warnings when fuzzing malformed inputs. Tests should keep output quiet:

```mbt nocheck
// Prefer scoped suppression so state is restored even on failure.
// @pdfe.with_logger(_ => (), fn() { ... })
// @pdfe.with_silenced_logs(fn() { ... })
//
// Some code paths print via PdfUtil; you can silence those too:
// @pdfutil.quiet.val = true
```
