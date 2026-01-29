#!/usr/bin/env bash
set -euo pipefail

fail=false
if [[ "${1:-}" == "--fail" ]]; then
  fail=true
fi

violations=0

while IFS= read -r pkgfile; do
  pkgdir="$(dirname "${pkgfile}")"
  pkg="${pkgdir#./}"

  while IFS= read -r dep; do
    if [[ "${dep}" == bobzhang/mbtpdf/cmd/* ]]; then
      echo "violation: ${pkg} depends on ${dep}"
      violations=$((violations + 1))
    fi
  done < <(grep -oE '"bobzhang/mbtpdf/[^"]+"' "${pkgfile}" | tr -d '"')

  case "${pkg}" in
    cmd/* | io/* | e2e/*) continue ;;
    *) ;;
  esac

  while IFS= read -r dep; do
    if [[ "${dep}" == bobzhang/mbtpdf/io/* ]]; then
      echo "note: ${pkg} depends on IO package ${dep}"
    fi
  done < <(grep -oE '"bobzhang/mbtpdf/[^"]+"' "${pkgfile}" | tr -d '"')
done < <(
  find . -name moon.pkg \
    -not -path './_build/*' \
    -not -path './target/*' \
    -not -path './tmp/*' \
    -print | sort
)

if [[ "${fail}" == "true" && "${violations}" -gt 0 ]]; then
  exit 1
fi
