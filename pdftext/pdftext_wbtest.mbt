///|
test "write_encoding predefined encodings" {
  let pdf = @pdf.empty()
  let objnum = write_encoding(pdf, @pdffont.Encoding::WinAnsiEncoding)
  let obj = @pdf.lookup_obj(pdf, objnum)
  match obj {
    @pdf.PdfObject::Name(name) => assert_eq(name, "/WinAnsiEncoding")
    _ => fail("expected encoding name")
  }
}

///|
test "write_encoding custom encoding base and differences" {
  let pdf = @pdf.empty()
  let diffs : @pdffont.Differences = [("/A", 65), ("/B", 66)]
  let objnum = write_encoding(
    pdf,
    @pdffont.Encoding::CustomEncoding(
      @pdffont.Encoding::StandardEncoding,
      diffs,
    ),
  )
  let obj = @pdf.lookup_obj(pdf, objnum)
  match obj {
    @pdf.PdfObject::Dictionary(entries) => {
      let base_idx = entries.search_by(pair => pair.0 == "/BaseEncoding")
      let diff_idx = entries.search_by(pair => pair.0 == "/Differences")
      match (base_idx, diff_idx) {
        (Some(bi), Some(di)) => {
          match entries[bi].1 {
            @pdf.PdfObject::Name(name) => assert_eq(name, "/StandardEncoding")
            _ => fail("expected /BaseEncoding name")
          }
          match entries[di].1 {
            @pdf.PdfObject::Array(elts) => {
              assert_eq(elts.length(), 4)
              match (elts[0], elts[1], elts[2], elts[3]) {
                (
                  @pdf.PdfObject::Integer(a),
                  @pdf.PdfObject::Name(n1),
                  @pdf.PdfObject::Integer(b),
                  @pdf.PdfObject::Name(n2),
                ) => {
                  assert_eq(a, 65)
                  assert_eq(n1, "/A")
                  assert_eq(b, 66)
                  assert_eq(n2, "/B")
                }
                _ => fail("unexpected /Differences entries")
              }
            }
            _ => fail("expected /Differences array")
          }
        }
        _ => fail("missing encoding dictionary entries")
      }
    }
    _ => fail("expected encoding dictionary")
  }
}
