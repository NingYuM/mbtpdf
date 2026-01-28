# Docs

- `docs/architecture.md`: High-level package/flow overview.
- `docs/testing.md`: Test, coverage, and CI workflow (including `scripts/coverage_gate.sh`).
- `docs/logging-hygiene.md`: Keeping tests/CI quiet while exercising recovery paths.
- `docs/e2e-tests.md`: End-to-end scenarios and how to run them.
- `docs/pdf-format-tutorial.md`: PDF format notes used by this project.
- `docs/port-plan.md`: Porting notes and historical planning.

## Suggested local workflow

```sh
moon info
moon fmt
moon test
moon check
scripts/coverage_gate.sh --threshold 95
```
