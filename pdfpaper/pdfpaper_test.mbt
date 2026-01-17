///|
test "landscape swaps width and height" {
  let paper = @pdfpaper.make(@pdfunits.Unit::Inch, 8.5, 11.0)
  let swapped = @pdfpaper.landscape(paper)
  assert_eq(@pdfpaper.width(swapped), 11.0)
  assert_eq(@pdfpaper.height(swapped), 8.5)
}
