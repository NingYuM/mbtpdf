#!/usr/bin/env bash
set -euo pipefail

threshold="${COVERAGE_MIN:-95}"
do_clean=1

usage() {
  cat <<'EOF'
usage: scripts/coverage_gate.sh [--threshold <percent>] [--no-clean]

Runs MoonBit coverage and fails if any non-excluded package drops below the
threshold.

Default exclusions:
  - cmd/* (executables)
  - io/*  (excluded by policy)

Env:
  COVERAGE_MIN  (default 95)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold)
      threshold="${2:-}"
      shift 2
      ;;
    --no-clean)
      do_clean=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$threshold" ]]; then
  echo "--threshold requires a value" >&2
  exit 2
fi

if [[ "$do_clean" -eq 1 ]]; then
  moon coverage clean
fi

moon coverage analyze -q -- -f summary > /dev/null
python3 scripts/coverage_gate.py "$threshold"
