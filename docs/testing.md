# Testing & Coverage

## Run tests

```sh
# Run all tests.
moon test

# Lint/type-check quickly (recommended in CI too).
moon check

# Run one package.
moon test document/pdfpage

# Run formatting + tests (useful before pushing).
moon fmt
moon test
```

## Logging hygiene in tests

Some packages emit *expected* warnings when exercising malformed inputs. Tests
should keep output quiet (especially in CI) by using scoped suppression helpers.

See `docs/logging-hygiene.md`.

## Coverage

```sh
# Full-module coverage summary.
moon coverage clean
moon coverage analyze -- -f summary
```

### Coverage policy

- `io/*` is excluded from coverage targets (policy).
- `cmd/*` is executable-only; coverage can be skipped.

### Coverage gate script

This repo ships a small gate that enforces a minimum per-package coverage
percentage (excluding `cmd/*` and `io/*`):

```sh
# Default is 95% (override with COVERAGE_MIN).
scripts/coverage_gate.sh

scripts/coverage_gate.sh --threshold 95
COVERAGE_MIN=97 scripts/coverage_gate.sh
```

## CI

GitHub Actions runs `moon fmt --check`, `moon test`, `moon check`, and the
coverage gate. See `.github/workflows/ci.yml`.

## Troubleshooting

See `docs/troubleshooting.md` (snapshots, noisy logs, coverage gate, build lock).
