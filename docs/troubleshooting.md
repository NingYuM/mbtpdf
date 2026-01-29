# Troubleshooting

## Tests are noisy (expected warnings)

Many tests intentionally exercise malformed PDFs and recovery paths.

- Prefer scoped suppression:
  ```mbt nocheck
  @pdfe.with_silenced_logs(fn() {
    // code that calls @pdfe.log(...)
  })
  ```
- For debug-only traces, enable `@pdfe.read_debug.val = true` and use `@pdfe.debug(...)`.
- Some paths print via `@pdfutil`; silence with `@pdfutil.quiet.val = true`.

More: `docs/logging-hygiene.md`.

## Snapshot tests changed

This repo prefers snapshot-style assertions (via `inspect`).

- Update snapshots:
  ```sh
  moon test --update
  ```
- Review diffs in `*_test.mbt` / `*.mbt.md` files and commit the updated `content=...`.

## Coverage gate fails

The CI gate enforces per-package coverage (excluding `io/*` and `cmd/*`).

```sh
scripts/coverage_gate.sh --threshold 95
```

If a small helper is untested, add a focused black-box test in the relevant package’s `*_test.mbt`.

## `moon` blocks on `_build/.moon-lock`

You may see:
`Blocking waiting for file lock ... _build/.moon-lock ...`

- Wait for the other `moon` process to finish, or stop it.
- Avoid running multiple `moon ...` commands concurrently in the same workspace.
