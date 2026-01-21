# End-to-end PDF tests

## Overview
The end-to-end tests live in `e2e/e2e_test.mbt`. Each test reads real PDF
fixtures from `testdata/e2e`, performs a high-level operation, writes the
result to `tmp/e2e`, then reads the output back to validate the roundtrip.

## Fixtures
- `testdata/e2e/merge_dummy.pdf`
  - Source: https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf
  - Purpose: single-page input for merge/annotation tests.
- `testdata/e2e/pdfjs_tracemonkey.pdf`
  - Source: https://github.com/mozilla/pdf.js/blob/master/test/pdfs/tracemonkey.pdf
  - Purpose: larger input for merge tests.
- `testdata/pdfjs_identity_tounicode.pdf`
  - Source: https://github.com/mozilla/pdf.js/blob/master/test/pdfs/IdentityToUnicodeMap_charCodeOf.pdf
  - Purpose: second input for merge tests (also used in text extraction tests).
- `testdata/SFAA_Japanese.pdf`
  - Source: https://web.archive.org/web/20150307061027/http://www.project2061.org/publications/sfaa/SFAA_Japanese.pdf
  - Purpose: large, multi-page input for split and bookmark tests (page count > 10).

## Test cases
- Merge roundtrip
  - Reads `merge_dummy.pdf`, `pdfjs_identity_tounicode.pdf`, and `pdfjs_tracemonkey.pdf`.
  - Merges all pages, writes to `tmp/e2e/merged.pdf`, reads back, and checks
    merged page count equals the sum of inputs.
- Split roundtrip
  - Reads `SFAA_Japanese.pdf`.
  - Extracts a subset of pages, writes to `tmp/e2e/split.pdf`, reads back, and
    checks the subset page count matches.
- Annotation roundtrip
  - Reads `merge_dummy.pdf`.
  - Adds a text annotation to the first page, writes to `tmp/e2e/annotated.pdf`,
    reads back, and checks the annotation count and contents.
- Bookmark roundtrip
  - Reads `SFAA_Japanese.pdf`.
  - Adds two bookmarks targeting pages 1 and 2, writes to `tmp/e2e/bookmarks.pdf`,
    reads back, and checks the bookmark texts.

## Running
- `moon test e2e` to run only the end-to-end tests.
- `moon test` to run the full suite, including these end-to-end checks.

## Checksums
- `scripts/e2e_checksums.sh` regenerates `testdata/e2e_checksums.txt`.
- `scripts/e2e_checksums.sh --check` verifies fixtures against the recorded hashes.

## Review notes
- Output PDFs are created in `tmp/e2e` and removed at the end of each test.
- The tests intentionally validate PDF read/write roundtrips to guard against
  regressions during refactoring.
