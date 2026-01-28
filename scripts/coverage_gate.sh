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

moon coverage analyze -q -- -f summary | python3 - "$threshold" <<'PY'
import re
import sys
from collections import defaultdict

threshold = float(sys.argv[1])

line_re = re.compile(r"^(?P<path>[^:]+):\s+(?P<hit>\d+)/(?P<tot>\d+)\s*$")

pkg_cov: dict[str, list[int]] = defaultdict(lambda: [0, 0])

for raw in sys.stdin:
    line = raw.strip()
    if not line or line.startswith("Total:"):
        continue
    m = line_re.match(line)
    if not m:
        continue
    path = m.group("path")
    hit = int(m.group("hit"))
    tot = int(m.group("tot"))
    parts = path.split("/")
    pkg = "/".join(parts[:2]) if len(parts) >= 2 else parts[0]
    pkg_cov[pkg][0] += hit
    pkg_cov[pkg][1] += tot

def pct(hit: int, tot: int) -> float:
    return 100.0 if tot == 0 else 100.0 * hit / tot

def excluded(pkg: str) -> bool:
    return pkg.startswith("cmd/") or pkg.startswith("io/")

rows: list[tuple[float, str, int, int]] = []
failing: list[tuple[float, str, int, int]] = []

for pkg, (hit, tot) in pkg_cov.items():
    if excluded(pkg):
        continue
    p = pct(hit, tot)
    rows.append((p, pkg, hit, tot))
    if p + 1e-9 < threshold:
        failing.append((p, pkg, hit, tot))

rows.sort(key=lambda r: (r[0], r[1]))
failing.sort(key=lambda r: (r[0], r[1]))

print(f"coverage threshold: {threshold:.2f}% (excluding cmd/* and io/*)")
for p, pkg, hit, tot in rows:
    print(f"{pkg:20s} {hit:5d}/{tot:<5d} {p:6.2f}%")

if failing:
    print("\nFAILED packages:")
    for p, pkg, hit, tot in failing:
        print(f"  {pkg} {hit}/{tot} {p:.2f}%")
    sys.exit(1)
PY

