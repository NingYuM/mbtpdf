# bobzhang/mbtpdf

PDF toolchain implemented in [MoonBit](https://docs.moonbitlang.com), centered on an in-memory PDF object model plus packages for parsing, writing, and document-level operations (merge, text extraction, encryption, etc.).

## Packages

- Libraries live under `core/`, `syntax/`, `codec/`, `crypto/`, `font/`, `graphics/`, `document/`, `text/`, `io/`.
- CLI entry points live under `cmd/` (e.g. `cmd/pdfhello`, `cmd/pdfextracttext`, `cmd/pdfmergeexample`).

## Documentation

- `docs/README.md`
- `docs/architecture.md`
- `docs/e2e-tests.md`
- `docs/pdf-format-tutorial.md`
- `docs/testing.md`
- `docs/logging-hygiene.md`

## Quick start

```sh
# Run the "hello world" PDF generator.
moon run cmd/pdfhello

# Run a multi-page interactive showcase PDF (art + layers + links).
moon run cmd/pdfshowcase

# Run a clickable "escape maze" PDF (links + layers + map).
moon run cmd/pdfmaze

# Run a beamer-ish slide deck generator (links + bookmarks + speaker notes layer).
moon run cmd/pdfbeamer

# Run a choose-your-own-adventure storybook (interactive buttons + spoilers layer).
moon run cmd/pdfstorybook

# Run a birthday card generator (balloons + party mode + secret layer).
moon run cmd/pdfbirthday
```

## Testing

```sh
moon test
moon check
moon coverage analyze
```

## Local CI gate

```sh
# Format check + lint + tests + per-package coverage gate (default 95%).
scripts/devcheck.sh
```

## Coverage gate

CI enforces minimum per-package coverage (excluding `cmd/*` and `io/*`):

```sh
scripts/coverage_gate.sh --threshold 95
```

## Logging hygiene (tests)

Many packages emit *expected* warnings when fuzzing malformed inputs. Tests should keep output quiet:

```mbt nocheck
// Prefer scoped suppression so state is restored even on failure.
@pdfe.with_logger(_ => (), fn() { ... })
@pdfe.with_silenced_logs(fn() { ... })

// Some code paths print via PdfUtil; you can silence those too:
@pdfutil.quiet.val = true
```
