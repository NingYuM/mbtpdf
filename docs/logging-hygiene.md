# Logging hygiene

This repo has a lot of tests that intentionally feed malformed PDFs into the parser, writer, and higher-level features. Those code paths may emit *expected* warnings (e.g. “bad name”, malformed xref/object stream recovery, missing ToUnicode, etc.).

For CI and for local developer experience, tests should avoid printing expected warnings to stdout/stderr unless the test is explicitly asserting on them.

See `docs/testing.md` for the recommended test/coverage commands and the CI coverage gate.

## Use `core/pdfe` for scoped log control

Most warnings go through `@pdfe.log` (see `core/pdfe`).

- Debug-only logs:
  ```mbt nocheck
  @pdfe.read_debug.val = true
  @pdfe.debug("...") // only logs when read_debug is enabled
  ```
- Silence logs in a scope:
  ```mbt nocheck
  @pdfe.with_silenced_logs(fn() {
    // code that calls @pdfe.log(...)
  })
  ```
- Override the logger in a scope (e.g. capture into an array, or discard):
  ```mbt nocheck
  @pdfe.with_logger(_ => (), fn() {
    // code that calls @pdfe.log(...)
  })
  ```

Both helpers restore the previous state even if the action raises.

## `PdfRead` has its own logger

`io/pdfread.PdfRead::new` accepts a `logger?` argument. Prefer setting this to `_ => ()` in tests that intentionally trigger recovery paths.

```mbt nocheck
let reader = @pdfread.PdfRead::new(logger=_ => ())
let pdf = reader.pdf_of_input(None, None, input)
```

## `core/pdfutil` print shims

Some internal paths print via `@pdfutil.PdfUtil::flprint` / `fleprint`. In tests, you can suppress those with:

```mbt nocheck
@pdfutil.with_quiet(true, fn() {
  // ...
})
```

If you need to assert on printed lines, override the printer:

```mbt nocheck
let lines : Array[String] = []
@pdfutil.with_printer(s => lines.push(s), fn() {
  // ... run code ...
})
```

## CLI packages: prefer `run(..., quiet=true)` in tests

CLI `cmd/*` packages may print usage/errors. Their tests should call `run(..., quiet=true)` when exercising invalid argument handling or expected failures.
