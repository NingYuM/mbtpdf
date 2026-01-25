///|
test "landscape swaps width and height" {
  let paper : @pdfpaper.Paper = Paper(unit=Inch, width=8.5, height=11.0)
  let swapped = paper.landscape()
  assert_eq(swapped.width(), 11.0)
  assert_eq(swapped.height(), 8.5)
}

///|
test "paper accessors return values" {
  let paper : @pdfpaper.Paper = Paper(unit=Centimetre, width=10.0, height=20.0)
  match paper.unit() {
    Centimetre => ()
    _ => fail("expected centimetre unit")
  }
  assert_eq(paper.width(), 10.0)
  assert_eq(paper.height(), 20.0)
}

///|
test "paper constants match expected sizes" {
  match @pdfpaper.a4.unit() {
    Millimetre => ()
    _ => fail("expected millimetre unit")
  }
  assert_eq(@pdfpaper.a4.width(), 210.0)
  assert_eq(@pdfpaper.a4.height(), 297.0)
  match @pdfpaper.usletter.unit() {
    Inch => ()
    _ => fail("expected inch unit")
  }
  assert_eq(@pdfpaper.usletter.width(), 8.5)
  assert_eq(@pdfpaper.usletter.height(), 11.0)
  match @pdfpaper.uslegal.unit() {
    Inch => ()
    _ => fail("expected inch unit")
  }
  assert_eq(@pdfpaper.uslegal.width(), 8.5)
  assert_eq(@pdfpaper.uslegal.height(), 14.0)
}
